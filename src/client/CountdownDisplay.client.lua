-- CountdownDisplay LocalScript
-- Shows large center-screen countdown during lobby phase

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local RoundEvent = ReplicatedStorage:WaitForChild("RoundEvent")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "CountdownDisplayGui"
gui.DisplayOrder = 15
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Enabled = false
gui.Parent = playerGui

local label = Instance.new("TextLabel")
label.Size = UDim2.new(0, 200, 0, 200)
label.AnchorPoint = Vector2.new(0.5, 0.5)
label.Position = UDim2.new(0.5, 0, 0.45, 0)
label.BackgroundTransparency = 1
label.Text = ""
label.TextColor3 = Color3.fromRGB(255, 255, 255)
label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
label.TextStrokeTransparency = 0.3
label.Font = Enum.Font.GothamBlack
label.TextSize = 140
label.ZIndex = 15
label.Parent = gui

RoundEvent.OnClientEvent:Connect(function(event, data)
	if event == "LobbyCountdown" then
		local t = tonumber(data) or 0
		gui.Enabled = true
		label.Text = tostring(t)
		label.TextColor3 = t <= 3 and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(255, 255, 255)
		label.TextSize = 140
		TweenService:Create(label,
			TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{TextSize = 100}
		):Play()
	elseif event == "RoundStart" or event == "LobbyWaiting" then
		gui.Enabled = false
	end
end)
