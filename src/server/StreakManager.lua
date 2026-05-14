-- StreakManager: tracks win/survival streaks per player, persisted in DataManager
-- Batched into the existing DataStore save — no separate key.
-- Called from RoundManager reward loop and GameManager.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataManager       = require(game.ServerScriptService.DataManager)

local StreakManager = {}

local StreakUpdateEvent  -- RemoteEvent, created in Init()

-- Lazy-create helper for RemoteEvents
local function getOrCreate(name)
    local existing = ReplicatedStorage:FindFirstChild(name)
    if existing then return existing end
    local r = Instance.new("RemoteEvent")
    r.Name   = name
    r.Parent = ReplicatedStorage
    return r
end

function StreakManager.Init()
    StreakUpdateEvent = getOrCreate("StreakUpdateEvent")
    print("[StreakManager] Initialized")
end

-- Called from RoundManager reward loop for each player.
-- survived = bool (player is still alive at round end)
-- won      = bool (player == winner, i.e., last survivor)
function StreakManager.OnRoundEnd(player, survived, won)
    local data = DataManager.GetData(player)
    if not data then return end

    -- Ensure streak fields exist (default 0)
    data.winStreak        = data.winStreak        or 0
    data.survivalStreak   = data.survivalStreak   or 0
    data.bestWinStreak    = data.bestWinStreak    or 0
    data.bestSurvivalStreak = data.bestSurvivalStreak or 0

    local newRecord = false
    local recordType = nil
    local recordCount = 0

    if survived then
        data.survivalStreak = data.survivalStreak + 1
        if won then
            data.winStreak = data.winStreak + 1
        end
        -- Check for new best win streak
        if data.winStreak > data.bestWinStreak then
            data.bestWinStreak = data.winStreak
            if won and data.winStreak > 1 then
                newRecord = true
                recordType  = "Win Streak"
                recordCount = data.winStreak
            end
        end
        -- Check for new best survival streak
        if data.survivalStreak > data.bestSurvivalStreak then
            data.bestSurvivalStreak = data.survivalStreak
            if data.survivalStreak > 1 then
                newRecord  = true
                recordType  = recordType or "Survival Streak"
                recordCount = recordCount > 0 and recordCount or data.survivalStreak
            end
        end
    else
        -- Eliminated: reset both streaks
        data.winStreak      = 0
        data.survivalStreak = 0
    end

    -- No explicit SaveData call needed — DataManager auto-saves every 60s
    -- and on PlayerRemoving. The data reference is mutated in-place.

    -- Fire update to this player's client
    if StreakUpdateEvent then
        StreakUpdateEvent:FireClient(player, {
            winStreak        = data.winStreak,
            survivalStreak   = data.survivalStreak,
            bestWinStreak    = data.bestWinStreak,
            bestSurvivalStreak = data.bestSurvivalStreak,
        })
    end

    return newRecord, recordType, recordCount
end

return StreakManager
