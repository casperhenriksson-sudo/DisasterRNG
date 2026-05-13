local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local DataManager = {}
local PlayerStore = DataStoreService:GetDataStore("DisasterRNG_v1")
local playerData = {}    -- Cache medan spelaren är online
local savedOnLeave = {}  -- tracks players already saved by PlayerRemoving (prevents BindToClose double-write)

-- Standardvärden för ny spelare
local DEFAULT_DATA = {
    money = 0,
    luck = 1,
    rebirth = 0,
    activeBrainrots = {}, -- Brainrots spelaren har equipat
    index = {},           -- Alla upplåsta brainrots någonsin
    -- DisasterCoins economy
    disasterCoins = 0,
    totalWins = 0,
    totalRoundsPlayed = 0,
    lastLoginTimestamp = 0,
    loginStreak = 0,
    milestonesClaimed = {},
    inventory = {},
    -- XP / Level progression
    xp = 0,
    level = 1,
    achievements = {},   -- {achievementId = true}
}

-- Ladda data när spelare går med
function DataManager.LoadData(player)
    local key = "Player_" .. player.UserId
    local success, data = pcall(function()
        return PlayerStore:GetAsync(key)
    end)

    if success and data then
        -- Slå ihop med default ifall nya fält lagts till
        for k, v in pairs(DEFAULT_DATA) do
            if data[k] == nil then
                data[k] = v
            end
        end
        playerData[player.UserId] = data
    else
        -- Ny spelare — copy of DEFAULT_DATA
        local newData = {}
        for k, v in pairs(DEFAULT_DATA) do
            if type(v) == "table" then
                newData[k] = {}
            else
                newData[k] = v
            end
        end
        playerData[player.UserId] = newData
    end

    print("✅ Data laddad för " .. player.Name)
    return playerData[player.UserId]
end

-- Spara data
function DataManager.SaveData(player)
    local key = "Player_" .. player.UserId
    local data = playerData[player.UserId]
    if not data then return end

    local success, err = pcall(function()
        PlayerStore:SetAsync(key, data)
    end)

    if success then
        print("✅ Data sparad för " .. player.Name)
    else
        warn("❌ Kunde inte spara data för " .. player.Name .. ": " .. err)
    end
end

-- Hämta spelarens data (från cache)
function DataManager.GetData(player)
    return playerData[player.UserId]
end

-- Uppdatera ett värde
function DataManager.Set(player, key, value)
    local data = playerData[player.UserId]
    if data then
        data[key] = value
    end
end

-- Lägg till pengar
function DataManager.AddMoney(player, amount)
    local data = playerData[player.UserId]
    if data then
        data.money = data.money + amount
        return data.money
    end
end

-- Dra av pengar (returnerar false om inte råd)
function DataManager.SpendMoney(player, amount)
    local data = playerData[player.UserId]
    if data and data.money >= amount then
        data.money = data.money - amount
        return true
    end
    return false
end

-- Lägg till brainrot i index
function DataManager.UnlockBrainrot(player, brainrotName)
    local data = playerData[player.UserId]
    if data then
        data.index[brainrotName] = true
    end
end

-- Kolla om brainrot är upplåst
function DataManager.HasBrainrot(player, brainrotName)
    local data = playerData[player.UserId]
    return data and data.index[brainrotName] == true
end

-- Rensa aktiva brainrots vid rebirth
function DataManager.Rebirth(player)
    local data = playerData[player.UserId]
    if data then
        data.rebirth = data.rebirth + 1
        data.activeBrainrots = {}
        data.money = 0
        -- Index bevaras!
        print("✅ " .. player.Name .. " har rebirthat! Nivå: " .. data.rebirth)
    end
end

-- XP thresholds: cumulative XP required for each level
local XP_LEVELS = {100, 250, 500, 900, 1400, 2100, 3000, 4200, 5800, 8000, 11000, 15000, 20000, 27000, 36000}

-- Add XP, handle level-up, return {xpGained, newXP, newLevel, didLevelUp}
function DataManager.AddXP(player, amount)
    local data = playerData[player.UserId]
    if not data then return {xpGained=0, newXP=0, newLevel=1, didLevelUp=false} end
    local oldLevel = data.level or 1
    data.xp = (data.xp or 0) + amount
    -- Level up
    local newLevel = oldLevel
    for i, threshold in ipairs(XP_LEVELS) do
        if data.xp >= threshold then
            newLevel = i + 1
        else
            break
        end
    end
    local didLevelUp = newLevel > oldLevel
    data.level = newLevel
    return {xpGained = amount, newXP = data.xp, newLevel = newLevel, didLevelUp = didLevelUp}
end

-- Lägg till DisasterCoins
function DataManager.AddCoins(player, amount)
    local data = playerData[player.UserId]
    if data then
        data.disasterCoins = (data.disasterCoins or 0) + amount
        return data.disasterCoins
    end
end

-- Hämta spelarens DisasterCoins
function DataManager.GetCoins(player)
    local data = playerData[player.UserId]
    return data and (data.disasterCoins or 0) or 0
end

-- Auto-spara var 60:e sekund
task.spawn(function()
    while true do
        task.wait(60)
        for _, player in ipairs(Players:GetPlayers()) do
            DataManager.SaveData(player)
        end
    end
end)

-- Spara när spelare lämnar
Players.PlayerRemoving:Connect(function(player)
    DataManager.SaveData(player)
    savedOnLeave[player.UserId] = true
    playerData[player.UserId] = nil
end)

-- Spara vid server-shutdown (skip players already saved by PlayerRemoving to avoid concurrent SetAsync on same key)
game:BindToClose(function()
    for _, player in ipairs(Players:GetPlayers()) do
        if not savedOnLeave[player.UserId] then
            DataManager.SaveData(player)
        end
    end
end)

return DataManager
