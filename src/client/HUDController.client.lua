-- HUDController LocalScript
-- Displays round state messages using the Countdown TextLabel in GameUI.
-- Also displays the player's DisasterCoins (DC) balance.

local Players        = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local gameUI    = playerGui:WaitForChild("GameUI")
local Countdown = gameUI:WaitForChild("Countdown")
local RoundEvent = ReplicatedStorage:WaitForChild("RoundEvent")

-- ── DC Label (top-right coin display) ────────────────────────────────────────
local dcLabel = Instance.new("TextLabel")
dcLabel.Name = "DCLabel"
dcLabel.Size = UDim2.new(0, 200, 0, 40)
dcLabel.Position = UDim2.new(1, -210, 0, 10)
dcLabel.BackgroundTransparency = 1
dcLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
dcLabel.TextScaled = true
dcLabel.Font = Enum.Font.GothamBold
dcLabel.Text = "DC: 0"
dcLabel.Parent = gameUI

-- Listen for server-pushed balance updates
local CurrencyUpdate = ReplicatedStorage:WaitForChild("CurrencyUpdate")
CurrencyUpdate.OnClientEvent:Connect(function(newBalance)
    dcLabel.Text = "DC: " .. tostring(newBalance)
end)

-- Fetch initial balance on load
local GetData = ReplicatedStorage:WaitForChild("GetData")
task.spawn(function()
    local ok, result = pcall(function()
        return GetData:InvokeServer()
    end)
    if ok and result then
        local coins = result.disasterCoins or 0
        dcLabel.Text = "DC: " .. tostring(coins)
    end
end)

-- ── Helpers ───────────────────────────────────────────────────────────────────
local hideTask  -- handle for auto-hide delayed tasks

local function showMessage(text, autoHideAfter)
	if hideTask then
		task.cancel(hideTask)
		hideTask = nil
	end
	Countdown.Text    = text
	Countdown.Visible = true
	if autoHideAfter then
		hideTask = task.delay(autoHideAfter, function()
			Countdown.Visible = false
			hideTask = nil
		end)
	end
end

local function hideNow()
	if hideTask then
		task.cancel(hideTask)
		hideTask = nil
	end
	Countdown.Visible = false
end

-- ── Alive counter (shown during rounds) ──────────────────────────────────────
local aliveLabel = Instance.new("TextLabel")
aliveLabel.Name = "AliveLabel"
aliveLabel.Size = UDim2.new(0, 180, 0, 36)
aliveLabel.Position = UDim2.new(0.5, -90, 0, 10)
aliveLabel.BackgroundTransparency = 1
aliveLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
aliveLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
aliveLabel.TextStrokeTransparency = 0.3
aliveLabel.Font = Enum.Font.GothamBold
aliveLabel.TextSize = 20
aliveLabel.Text = ""
aliveLabel.Visible = false
aliveLabel.Parent = gameUI

local aliveCount = 0

local function setAliveCount(n)
	aliveCount = n
	aliveLabel.Text = "👤 " .. n .. " alive"
	aliveLabel.Visible = n > 0
end

-- ── Idle / default state ──────────────────────────────────────────────────────
showMessage("Waiting for players...")

-- ── Event handler ─────────────────────────────────────────────────────────────
RoundEvent.OnClientEvent:Connect(function(eventName, data)

	if eventName == "LobbyWaiting" then
		local min = (type(data) == "table" and data.min) or 2
		showMessage("Waiting for players... (" .. min .. " needed)")
		aliveLabel.Visible = false

	elseif eventName == "LobbyCountdown" then
		local secondsLeft = tonumber(data) or 0
		showMessage("Round starts in: " .. secondsLeft .. "s")

	elseif eventName == "RoundStart" then
		local roundNum = (type(data) == "table" and data.round) or ""
		local roundText = roundNum ~= "" and ("Round " .. roundNum .. " — Active") or "Round Active"
		showMessage(roundText, 3)
		-- Snapshot alive count from current players
		setAliveCount(#game:GetService("Players"):GetPlayers())

	elseif eventName == "PlayerDied" then
		setAliveCount(math.max(0, aliveCount - 1))

	elseif eventName == "LastSurvivor" then
		local name = (type(data) == "table" and data.name) or "Someone"
		aliveLabel.Text = "⭐ Last survivor: " .. name
		aliveLabel.TextColor3 = Color3.fromRGB(255, 215, 60)

	elseif eventName == "RoundInProgress" then
		showMessage("Round in progress — wait for next round", 8)

	elseif eventName == "RoundEnd" then
		aliveLabel.Visible = false
		aliveLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		showMessage("Round ended!", 4)
		task.delay(4, function()
			if not Countdown.Visible then
				showMessage("Waiting for players...")
			end
		end)

	end
end)
