-- AchievementManager (ModuleScript — ServerScriptService)
-- Checks and awards achievements server-side, fires notifications to clients.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create AchievementEvent remote if it doesn't exist
local AchievementEvent = ReplicatedStorage:FindFirstChild("AchievementEvent")
if not AchievementEvent then
    AchievementEvent = Instance.new("RemoteEvent")
    AchievementEvent.Name = "AchievementEvent"
    AchievementEvent.Parent = ReplicatedStorage
end

local AchievementManager = {}

-- Achievement definitions
local ACHIEVEMENTS = {
    {id = "first_survive",    name = "Survivor",           desc = "Survive your first disaster",            icon = "🛡️"},
    {id = "survive_10",       name = "Veteran",            desc = "Survive 10 disasters",                   icon = "⚔️"},
    {id = "survive_50",       name = "Seasoned",           desc = "Survive 50 disasters",                   icon = "🏆"},
    {id = "first_win",        name = "Champion",           desc = "Be the last survivor",                   icon = "👑"},
    {id = "wins_5",           name = "Untouchable",        desc = "Win 5 rounds",                           icon = "💎"},
    {id = "wins_25",          name = "Legend",             desc = "Win 25 rounds",                          icon = "🌟"},
    {id = "tornado_survive",  name = "Wind Walker",        desc = "Survive a Tornado",                      icon = "🌪️"},
    {id = "tsunami_survive",  name = "Floater",            desc = "Survive a Tsunami",                      icon = "🌊"},
    {id = "blizzard_survive", name = "Ice Cold",           desc = "Survive a Blizzard",                     icon = "❄️"},
    {id = "lightning_survive",name = "Conductor",          desc = "Survive a Lightning Storm",              icon = "⚡"},
    {id = "volcano_survive",  name = "Lava Walker",        desc = "Survive a Volcanic Eruption",            icon = "🌋"},
    {id = "meteor_survive",   name = "Shooting Star",      desc = "Survive a Meteor Strike",                icon = "☄️"},
    {id = "all_disasters",    name = "Master of Disaster", desc = "Survive all 10 disaster types",          icon = "🎖️"},
    {id = "perfect_round",    name = "Untouched",          desc = "Survive a round without taking damage",  icon = "✨"},
    {id = "level_5",          name = "Rising Star",        desc = "Reach level 5",                          icon = "⭐"},
    {id = "level_10",         name = "Elite",              desc = "Reach level 10",                         icon = "🔥"},
}

-- Disaster id → achievement id
local DISASTER_ACHIEVEMENTS = {
    ["Tornado"]           = "tornado_survive",
    ["Tsunami"]           = "tsunami_survive",
    ["Blizzard"]          = "blizzard_survive",
    ["Lightning Storm"]   = "lightning_survive",
    ["Volcanic Eruption"] = "volcano_survive",
    ["Meteor Strike"]     = "meteor_survive",
    ["Flood"]             = "flood_survive",
    ["Earthquake"]        = "earthquake_survive",
    ["Acid Rain"]         = "acidrain_survive",
    ["Sandstorm"]         = "sandstorm_survive",
}

-- All 10 disaster survivor achievement IDs (for Master of Disaster check)
local ALL_DISASTER_IDS = {
    "tornado_survive", "tsunami_survive", "blizzard_survive", "lightning_survive",
    "volcano_survive", "meteor_survive", "flood_survive", "earthquake_survive",
    "acidrain_survive", "sandstorm_survive",
}

-- Build a lookup for quick access
local achievementMap = {}
for _, a in ipairs(ACHIEVEMENTS) do
    achievementMap[a.id] = a
end

-- Award an achievement to a player (idempotent)
local function award(player, achievementId, DataManager)
    local data = DataManager.GetData(player)
    if not data then return end
    if data.achievements[achievementId] then return end  -- already earned

    data.achievements[achievementId] = true

    local ach = achievementMap[achievementId]
    if ach then
        AchievementEvent:FireClient(player, "earned", {
            id   = achievementId,
            name = ach.name,
            desc = ach.desc,
            icon = ach.icon,
        })
    end
end

-- Check achievements after a round for a player
-- params: {player, survived, isWinner, disaster, noDamage, DataManager}
function AchievementManager.CheckRound(params)
    local player     = params.player
    local survived   = params.survived
    local isWinner   = params.isWinner
    local disaster   = params.disaster
    local noDamage   = params.noDamage
    local DataManager = params.DataManager

    local data = DataManager.GetData(player)
    if not data then return end

    if survived then
        -- Survival count
        data.totalRoundsPlayed = data.totalRoundsPlayed or 0
        local survives = (data.totalRoundsPlayed or 0)
        if survives >= 1  then award(player, "first_survive", DataManager) end
        if survives >= 10 then award(player, "survive_10",    DataManager) end
        if survives >= 50 then award(player, "survive_50",    DataManager) end

        -- Disaster-specific
        local disAch = DISASTER_ACHIEVEMENTS[disaster]
        if disAch then
            award(player, disAch, DataManager)
        end

        -- Master of Disaster
        local allDone = true
        for _, id in ipairs(ALL_DISASTER_IDS) do
            if not data.achievements[id] then
                allDone = false
                break
            end
        end
        if allDone then award(player, "all_disasters", DataManager) end

        -- Perfect round
        if noDamage then
            award(player, "perfect_round", DataManager)
        end
    end

    if isWinner then
        award(player, "first_win", DataManager)
        local wins = data.totalWins or 0
        if wins >= 5  then award(player, "wins_5",  DataManager) end
        if wins >= 25 then award(player, "wins_25", DataManager) end
    end

    -- Level achievements
    local level = data.level or 1
    if level >= 5  then award(player, "level_5",  DataManager) end
    if level >= 10 then award(player, "level_10", DataManager) end
end

return AchievementManager
