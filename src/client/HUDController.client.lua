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

-- ── Idle / default state ──────────────────────────────────────────────────────
showMessage("Waiting for players...")

-- ── Event handler ─────────────────────────────────────────────────────────────
RoundEvent.OnClientEvent:Connect(function(eventName, data)

	if eventName == "LobbyWaiting" then
		-- Server is waiting for minimum player count
		local min = (type(data) == "table" and data.min) or 2
		showMessage("Waiting for players... (" .. min .. " needed)")

	elseif eventName == "LobbyCountdown" then
		local secondsLeft = tonumber(data) or 0
		showMessage("Round starts in: " .. secondsLeft .. "s")

	elseif eventName == "RoundStart" then
		-- Show briefly then hide
		local roundNum = (type(data) == "table" and data.round) or ""
		local roundText = roundNum ~= "" and ("Round " .. roundNum .. " — Active") or "Round Active"
		showMessage(roundText, 3)

	elseif eventName == "RoundInProgress" then
		showMessage("Round in progress — wait for next round", 8)

	elseif eventName == "RoundEnd" then
		-- Show briefly then revert to waiting message
		showMessage("Round ended!", 4)
		task.delay(4, function()
			-- Only restore "Waiting" if nothing else has written to Countdown yet
			if not Countdown.Visible then
				showMessage("Waiting for players...")
			end
		end)

	end
end)
