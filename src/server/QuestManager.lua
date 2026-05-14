-- QuestManager: server-authoritative daily quest tracking
-- Pure ModuleScript: do not perform service calls at top level beyond requires.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataManager     = require(game.ServerScriptService.DataManager)
local CurrencyManager = require(game.ServerScriptService.CurrencyManager)
local QuestData       = require(game.ReplicatedStorage.QuestData)

local QuestManager = {}

-- ── Module-level state ─────────────────────────────────────────────────────────
local claimInFlight   = {}  -- [userId][questIdx] = true
local processedRounds = {}  -- [userId][roundCount] = true (per-round dedup)
local sessionStart    = {}  -- [userId] = os.time() — for timeInGame tracking
local lastClaim       = {}  -- [userId] = os.clock() (1s rate-limit)

local MAX_QUESTS = 3
local CLAIM_COOLDOWN = 1.0

-- ── Helpers ─────────────────────────────────────────────────────────────────────
local function dayBucket(t)
    return math.floor((t or os.time()) / 86400) * 86400
end

local function pushUpdate(player)
    local QuestUpdateEvent = ReplicatedStorage:FindFirstChild("QuestUpdateEvent")
    if QuestUpdateEvent and player and player.Parent then
        QuestUpdateEvent:FireClient(player, QuestManager.GetQuests(player))
    end
end

-- Weighted random tier pick (currently unused — we deterministically pick one per tier)
local function pickFromTier(tier)
    local pool = QuestData.ByTier[tier]
    if not pool or #pool == 0 then return nil end
    local choice = pool[math.random(1, #pool)]
    -- deep-ish copy so we never mutate the template
    return {
        id = choice.id,
        tier = choice.tier,
        type = choice.type,
        goal = choice.goal,
        reward = choice.reward,
        label = choice.label,
        progress = 0,
        claimed = false,
    }
end

local function assignDailyQuests(data)
    local quests = {}
    -- 1 quest per tier in order: Easy, Medium, Hard
    for _, tier in ipairs({"Easy","Medium","Hard"}) do
        local q = pickFromTier(tier)
        if q then table.insert(quests, q) end
    end
    -- cap at MAX_QUESTS
    assert(#quests <= MAX_QUESTS, "QuestManager: quest array exceeds MAX_QUESTS")
    data.dailyQuests.quests = quests
    data.dailyQuests.lastReset = dayBucket(os.time())
    -- Note: streakCount intentionally NOT reset on day reset (carries across days).
end

local function validateQuestData(data)
    if type(data.dailyQuests) ~= "table" then
        data.dailyQuests = { lastReset = 0, quests = {}, streakCount = 0 }
        return
    end
    local dq = data.dailyQuests
    if type(dq.lastReset) ~= "number" then dq.lastReset = 0 end
    if type(dq.streakCount) ~= "number" then dq.streakCount = 0 end
    if type(dq.quests) ~= "table" then
        dq.quests = {}
    else
        -- Validate each quest entry
        local valid = {}
        for i, q in ipairs(dq.quests) do
            if i > MAX_QUESTS then break end
            if type(q) == "table"
               and type(q.id) == "string"
               and QuestData.ById[q.id]
               and type(q.type) == "string"
               and type(q.goal) == "number"
               and type(q.reward) == "number"
               and type(q.progress) == "number"
               and type(q.claimed) == "boolean"
               and type(q.tier) == "string"
               and type(q.label) == "string"
            then
                -- clamp progress
                q.progress = math.clamp(math.floor(q.progress), 0, q.goal * 2)
                table.insert(valid, q)
            end
        end
        dq.quests = valid
    end
end

local function resetIfNewDay(player)
    local data = DataManager.GetData(player)
    if not data then return end
    validateQuestData(data)
    local today = dayBucket(os.time())
    if data.dailyQuests.lastReset < today or #data.dailyQuests.quests == 0 then
        assignDailyQuests(data)
        pushUpdate(player)
    end
end

local function incrementProgress(data, questType, delta)
    local completed = {}
    if not data.dailyQuests or not data.dailyQuests.quests then return completed end
    for idx, q in ipairs(data.dailyQuests.quests) do
        if q.type == questType and not q.claimed then
            local wasComplete = q.progress >= q.goal
            q.progress = math.clamp(q.progress + delta, 0, q.goal * 2)
            local nowComplete = q.progress >= q.goal
            if nowComplete and not wasComplete then
                table.insert(completed, idx)
            end
        end
    end
    return completed
end

-- ── Public API ─────────────────────────────────────────────────────────────────

function QuestManager.OnPlayerAdded(player)
    -- Ensure data is loaded; if PlayerLoader hasn't yet, retry briefly
    local data = DataManager.GetData(player)
    if not data then
        -- Brief wait — DataManager.LoadData is synchronous in PlayerLoader; this is defensive
        for _ = 1, 10 do
            task.wait(0.2)
            data = DataManager.GetData(player)
            if data then break end
        end
    end
    if not data then return end

    validateQuestData(data)
    resetIfNewDay(player)
    sessionStart[player.UserId] = os.time()
    processedRounds[player.UserId] = {}
    claimInFlight[player.UserId] = {}
end

function QuestManager.OnPlayerRemoving(player)
    local uid = player.UserId
    sessionStart[uid] = nil
    processedRounds[uid] = nil
    claimInFlight[uid] = nil
    lastClaim[uid] = nil
end

function QuestManager.GetQuests(player)
    local data = DataManager.GetData(player)
    if not data then return { quests = {}, resetTimestamp = dayBucket(os.time()) + 86400 } end
    validateQuestData(data)
    -- Return copy (not live ref)
    local copy = {}
    for _, q in ipairs(data.dailyQuests.quests) do
        table.insert(copy, {
            id = q.id, tier = q.tier, type = q.type, goal = q.goal,
            reward = q.reward, label = q.label, progress = q.progress,
            claimed = q.claimed,
        })
    end
    return {
        quests = copy,
        resetTimestamp = (data.dailyQuests.lastReset or 0) + 86400,
        streakCount = data.dailyQuests.streakCount or 0,
    }
end

-- Server-only progress tracking. roundId optional for dedup on round-tied events.
function QuestManager.TrackProgress(player, eventType, value, roundId)
    if not player or not player.Parent then return end
    local data = DataManager.GetData(player)
    if not data then return end

    -- Validate delta
    if type(value) ~= "number" then return end
    value = math.floor(value)
    if value <= 0 then return end

    validateQuestData(data)
    resetIfNewDay(player)
    -- After possible reset, refetch data ref (still same since GetData returns live ref)
    data = DataManager.GetData(player)
    if not data then return end

    local uid = player.UserId

    -- Round dedup
    if roundId ~= nil then
        processedRounds[uid] = processedRounds[uid] or {}
        local key = eventType .. ":" .. tostring(roundId)
        if processedRounds[uid][key] then return end
        processedRounds[uid][key] = true
    end

    -- Special: surviveDied resets the streak counter, doesn't increment quests
    if eventType == "surviveDied" then
        data.dailyQuests.streakCount = 0
        -- Reset progress on surviveStreak quests (they re-count from current streak)
        for _, q in ipairs(data.dailyQuests.quests) do
            if q.type == "surviveStreak" and not q.claimed then
                q.progress = 0
            end
        end
        pushUpdate(player)
        return
    end

    -- equipRarePlus: one-time-per-day flag, only increment if not already complete
    if eventType == "equipRarePlus" then
        for _, q in ipairs(data.dailyQuests.quests) do
            if q.type == "equipRarePlus" and not q.claimed and q.progress >= q.goal then
                return -- already done today
            end
        end
    end

    -- surviveStreak special handling: also increment global streak counter
    if eventType == "disasterSurvived" then
        data.dailyQuests.streakCount = (data.dailyQuests.streakCount or 0) + value
        -- Mirror streak to surviveStreak quests: set progress to min(streak, goal*2)
        for _, q in ipairs(data.dailyQuests.quests) do
            if q.type == "surviveStreak" and not q.claimed then
                local newProgress = math.clamp(data.dailyQuests.streakCount, 0, q.goal * 2)
                q.progress = math.max(q.progress, newProgress)
            end
        end
    end

    incrementProgress(data, eventType, value)
    pushUpdate(player)
end

function QuestManager.ClaimQuest(player, questIndex)
    if not player or not player.Parent then return { ok = false, error = "no player" } end
    local data = DataManager.GetData(player)
    if not data then return { ok = false, error = "no data" } end

    if type(questIndex) ~= "number" then return { ok = false, error = "bad index" } end
    questIndex = math.floor(questIndex)
    if questIndex < 1 or questIndex > MAX_QUESTS then
        return { ok = false, error = "index out of range" }
    end

    local uid = player.UserId

    -- Rate limit
    local now = os.clock()
    if lastClaim[uid] and now - lastClaim[uid] < CLAIM_COOLDOWN then
        return { ok = false, error = "claim cooldown" }
    end
    lastClaim[uid] = now

    validateQuestData(data)
    local quest = data.dailyQuests.quests[questIndex]
    if not quest then return { ok = false, error = "no quest at index" } end

    if quest.claimed then return { ok = false, error = "already claimed" } end
    if quest.progress < quest.goal then return { ok = false, error = "not complete" } end

    -- Double-claim lock
    claimInFlight[uid] = claimInFlight[uid] or {}
    if claimInFlight[uid][questIndex] then
        return { ok = false, error = "claim in flight" }
    end
    claimInFlight[uid][questIndex] = true

    -- Mark claimed FIRST so any concurrent attempt sees it
    quest.claimed = true

    -- Grant reward via CurrencyManager (excluded from dcEarned via reason whitelist)
    CurrencyManager.AwardCoins(player, quest.reward, "quest_complete")

    claimInFlight[uid][questIndex] = nil

    local newBalance = (DataManager.GetData(player) or {}).disasterCoins or 0
    pushUpdate(player)
    return { ok = true, newBalance = newBalance, reward = quest.reward }
end

-- ── Init ───────────────────────────────────────────────────────────────────────
local initialized = false
function QuestManager.Init()
    if initialized then return end
    initialized = true

    -- Ensure QuestUpdateEvent exists
    if not ReplicatedStorage:FindFirstChild("QuestUpdateEvent") then
        local e = Instance.new("RemoteEvent")
        e.Name = "QuestUpdateEvent"
        e.Parent = ReplicatedStorage
    end

    Players.PlayerAdded:Connect(function(p)
        task.spawn(function()
            QuestManager.OnPlayerAdded(p)
        end)
    end)
    Players.PlayerRemoving:Connect(function(p)
        QuestManager.OnPlayerRemoving(p)
    end)
    for _, p in ipairs(Players:GetPlayers()) do
        task.spawn(function() QuestManager.OnPlayerAdded(p) end)
    end

    -- timeInGame loop: every 60s, give all online players +60s session progress
    task.spawn(function()
        while true do
            task.wait(60)
            for _, p in ipairs(Players:GetPlayers()) do
                if sessionStart[p.UserId] and DataManager.GetData(p) then
                    QuestManager.TrackProgress(p, "timeInGame", 60)
                end
            end
        end
    end)

    -- Daily reset poll: check every 60s if a new day rolled over for online players
    task.spawn(function()
        while true do
            task.wait(60)
            for _, p in ipairs(Players:GetPlayers()) do
                if DataManager.GetData(p) then
                    resetIfNewDay(p)
                end
            end
        end
    end)

    print("[QuestManager] Initialized")
end

return QuestManager
