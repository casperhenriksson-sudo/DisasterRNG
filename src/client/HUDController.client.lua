-- HUDController LocalScript
-- Displays round state messages using the Countdown TextLabel in GameUI.

local Players        = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local gameUI    = playerGui:WaitForChild("GameUI")
local Countdown = gameUI:WaitForChild("Countdown")
local RoundEvent = ReplicatedStorage:WaitForChild("RoundEvent")

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
