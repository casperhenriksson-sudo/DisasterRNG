-- HUDController LocalScript
-- Manages Countdown TextLabel text and visibility in response to RoundEvent.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local gameUI    = playerGui:WaitForChild("GameUI")

local Countdown  = gameUI:WaitForChild("Countdown")
local RoundEvent = ReplicatedStorage:WaitForChild("RoundEvent")

-- Keep hidden by default until LobbyCountdown fires
Countdown.Visible = false

RoundEvent.OnClientEvent:Connect(function(eventName, data)
	if eventName == "LobbyCountdown" then
		local secondsLeft = tonumber(data) or 0
		Countdown.Text    = "Next round in: " .. secondsLeft .. "s"
		Countdown.Visible = true

	elseif eventName == "RoundStart" then
		Countdown.Visible = false

	elseif eventName == "RoundEnd" then
		Countdown.Visible = false
	end
end)
