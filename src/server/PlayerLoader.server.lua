local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataManager = require(game.ServerScriptService.DataManager)
local PerkManager = require(game.ServerScriptService.PerkManager)
local CurrencyManager = require(game.ServerScriptService.CurrencyManager)

-- GetData RemoteFunction so clients can request their stats (money, luck, rebirth)
local GetData = ReplicatedStorage:FindFirstChild("GetData")
if not GetData then
    GetData = Instance.new("RemoteFunction")
    GetData.Name = "GetData"
    GetData.Parent = ReplicatedStorage
end

GetData.OnServerInvoke = function(player)
    local data = DataManager.GetData(player)
    if data then
        return {
            money = data.money,
            luck = data.luck,
            rebirth = data.rebirth,
            disasterCoins = data.disasterCoins or 0,
        }
    end
    return {money = 0, luck = 1, rebirth = 0, disasterCoins = 0}
end

local function applyActiveBrainrotPerks(player)
    local data = DataManager.GetData(player)
    if not data then return end
    for _, brainrot in ipairs(data.activeBrainrots) do
        if brainrot.perk and brainrot.perk ~= "???" then
            PerkManager.ApplyPerk(player, brainrot.perk)
        end
    end
end

Players.PlayerAdded:Connect(function(player)
    DataManager.LoadData(player)
    CurrencyManager.ProcessDailyLogin(player)

    -- Re-apply active brainrot perks whenever the character spawns
    player.CharacterAdded:Connect(function()
        task.wait(1) -- Wait for character to fully load
        applyActiveBrainrotPerks(player)
    end)
end)

-- Om spelare redan är med när scriptet startar
for _, player in ipairs(Players:GetPlayers()) do
    DataManager.LoadData(player)
    CurrencyManager.ProcessDailyLogin(player)
    player.CharacterAdded:Connect(function()
        task.wait(1)
        applyActiveBrainrotPerks(player)
    end)
end

print("✅ PlayerLoader aktiv!")
