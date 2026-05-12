-- ChatCommands Server Script
-- Registers /skip, /timeleft, /players via TextChatService

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local RoundManager = require(game.ServerScriptService.RoundManager)

-- Admin whitelist — UserId numbers
local ADMINS = {
	-- Add admin UserIds here: e.g. [12345678] = true
}

local function isAdmin(player)
	return ADMINS[player.UserId] == true
end

local function getChannel()
	local channels = TextChatService:FindFirstChild("TextChannels")
	return channels and channels:FindFirstChild("RBXGeneral")
end

local function sendSystemMsg(text)
	local ch = getChannel()
	if ch then
		ch:DisplaySystemMessage(text)
	end
end

-- /skip command (admin only)
local skipCmd = Instance.new("TextChatCommand")
skipCmd.Name = "SkipCommand"
skipCmd.PrimaryAlias = "/skip"
skipCmd.SecondaryAlias = "/s"
skipCmd.Parent = TextChatService

skipCmd.Triggered:Connect(function(originTextSource, unfilteredText)
	local player = Players:GetPlayerByUserId(originTextSource.UserId)
	if not player then return end
	if not isAdmin(player) then
		sendSystemMsg("[Server] /skip is admin-only.")
		return
	end
	RoundManager.SkipRound()
	sendSystemMsg("[Server] Round skipped by " .. player.Name .. ".")
end)

-- /timeleft command
local timeCmd = Instance.new("TextChatCommand")
timeCmd.Name = "TimeLeftCommand"
timeCmd.PrimaryAlias = "/timeleft"
timeCmd.SecondaryAlias = "/tl"
timeCmd.Parent = TextChatService

timeCmd.Triggered:Connect(function(originTextSource, unfilteredText)
	local t = RoundManager.GetTimeLeft()
	sendSystemMsg("[Server] Time left: " .. math.floor(t) .. " seconds.")
end)

-- /players command
local playersCmd = Instance.new("TextChatCommand")
playersCmd.Name = "PlayersCommand"
playersCmd.PrimaryAlias = "/players"
playersCmd.SecondaryAlias = "/pl"
playersCmd.Parent = TextChatService

playersCmd.Triggered:Connect(function(originTextSource, unfilteredText)
	local names = {}
	for _, p in ipairs(Players:GetPlayers()) do
		table.insert(names, p.Name)
	end
	sendSystemMsg("[Server] Players: " .. table.concat(names, ", "))
end)
