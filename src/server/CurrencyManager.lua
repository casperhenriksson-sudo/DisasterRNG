-- CurrencyManager ModuleScript
-- Manages DisasterCoins (DC) awards, daily login streaks, and win milestones.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataManager = require(game.ServerScriptService.DataManager)

-- Lazy QuestManager require to avoid circular dependency (QuestManager requires CurrencyManager)
local _QuestManager
local function getQuestManager()
    if _QuestManager == nil then
        local ok, mod = pcall(require, game.ServerScriptService.QuestManager)
        if ok then _QuestManager = mod else _QuestManager = false end
    end
    return _QuestManager or nil
end

-- Ensure CurrencyUpdate RemoteEvent exists
local CurrencyUpdate = ReplicatedStorage:FindFirstChild("CurrencyUpdate")
if not CurrencyUpdate then
    CurrencyUpdate = Instance.new("RemoteEvent")
    CurrencyUpdate.Name = "CurrencyUpdate"
    CurrencyUpdate.Parent = ReplicatedStorage
end

local CurrencyManager = {}

-- Milestone win counts -> bonus DC awarded once per threshold
local WIN_MILESTONES = {5, 10, 25, 50, 100}
local MILESTONE_BONUS = 500

-- Streak bonuses: index = day streak (capped at table length for larger streaks)
local STREAK_BONUSES = {25, 30, 40, 50, 60, 75, 100}

-- ── Core award function ───────────────────────────────────────────────────────

function CurrencyManager.AwardCoins(player, amount, reason)
    if type(amount) ~= "number" or amount <= 0 or amount ~= amount or amount >= math.huge then
        warn("[CurrencyManager] AwardCoins: invalid amount " .. tostring(amount) .. " for " .. player.Name)
        return
    end

    local data = DataManager.GetData(player)
    if not data then
        warn("[CurrencyManager] AwardCoins: no data for " .. player.Name)
        return
    end

    if amount > 1000 then
        warn("[CurrencyManager] SUSPICIOUS: awarding " .. amount .. " DC to " .. player.Name .. " (reason: " .. tostring(reason) .. ")")
    end

    local newTotal = DataManager.AddCoins(player, amount)
    if newTotal then
        CurrencyUpdate:FireClient(player, newTotal)
        print("[CurrencyManager] +" .. amount .. " DC to " .. player.Name .. " (reason: " .. tostring(reason) .. ") — total: " .. newTotal)
    end

    -- Quest tracking: only count gameplay DC (exclude quest rewards & admin to prevent loops)
    if reason ~= "quest_complete" and reason ~= "admin" then
        local qm = getQuestManager()
        if qm then qm.TrackProgress(player, "dcEarned", amount) end
    end
end

-- ── Survive / win bonuses ─────────────────────────────────────────────────────

function CurrencyManager.AwardSurviveBonus(player)
    CurrencyManager.AwardCoins(player, 50, "survive")
end

function CurrencyManager.AwardWinBonus(player)
    CurrencyManager.AwardCoins(player, 100, "win")

    local data = DataManager.GetData(player)
    if data then
        data.totalWins = (data.totalWins or 0) + 1
        CurrencyManager.CheckMilestone(player)
    end
end

-- ── Milestone check ───────────────────────────────────────────────────────────

function CurrencyManager.CheckMilestone(player)
    local data = DataManager.GetData(player)
    if not data then return end

    local wins = data.totalWins or 0
    if not data.milestonesClaimed then
        data.milestonesClaimed = {}
    end

    for _, threshold in ipairs(WIN_MILESTONES) do
        local key = tostring(threshold)
        if wins >= threshold and not data.milestonesClaimed[key] then
            data.milestonesClaimed[key] = true
            CurrencyManager.AwardCoins(player, MILESTONE_BONUS, "milestone_" .. threshold .. "_wins")
            print("[CurrencyManager] " .. player.Name .. " hit " .. threshold .. "-win milestone!")
        end
    end
end

-- ── Daily login / streak ──────────────────────────────────────────────────────

function CurrencyManager.ProcessDailyLogin(player)
    local data = DataManager.GetData(player)
    if not data then
        warn("[CurrencyManager] ProcessDailyLogin: no data for " .. player.Name)
        return
    end

    local now = os.time()
    local todayDay  = math.floor(now / 86400)
    local lastDay   = math.floor((data.lastLoginTimestamp or 0) / 86400)

    if todayDay == lastDay then
        -- Already logged in today, no bonus
        return
    end

    local streak = data.loginStreak or 0

    if todayDay == lastDay + 1 then
        -- Consecutive day
        streak = streak + 1
    else
        -- Streak broken (missed at least one day)
        streak = 1
    end

    data.loginStreak = streak
    data.lastLoginTimestamp = now

    -- Pick streak bonus (cap at table length for higher streaks)
    local bonusIndex = math.min(streak, #STREAK_BONUSES)
    local bonus = STREAK_BONUSES[bonusIndex]

    CurrencyManager.AwardCoins(player, bonus, "daily_login_streak_" .. streak)
    print("[CurrencyManager] " .. player.Name .. " daily login — streak: " .. streak .. " days, bonus: " .. bonus .. " DC")
end

function CurrencyManager.SpendCoins(player, amount)
    local success = DataManager.SpendCoins(player, amount)  -- atomic
    if success then
        local newTotal = DataManager.GetCoins(player)
        CurrencyUpdate:FireClient(player, newTotal)
    end
    return success
end

return CurrencyManager
