local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SpinEvent = ReplicatedStorage:WaitForChild("SpinEvent")
local SpinHandler = require(game.ServerScriptService.SpinHandler)
local PerkManager = require(game.ServerScriptService.PerkManager)

SpinEvent.OnServerEvent:Connect(function(player, luckMultiplier)
    local results = SpinHandler.DoSpin(player, math.clamp(tonumber(luckMultiplier) or 1, 1, 5))
    SpinEvent:FireClient(player, results)

    -- Applicera perk från senaste brainrot
    local latest = results[#results]
    if latest and latest.perk ~= "???" then
        PerkManager.ApplyPerk(player, latest.perk)
    end

    print("🎰 " .. player.Name .. " fick: " .. results[#results].brainrot .. " (" .. results[#results].rarity .. ")")
end)

print("✅ SpinConnector aktiv!")
