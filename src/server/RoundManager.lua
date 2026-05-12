local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataManager = require(game.ServerScriptService.DataManager)
local PerkManager = require(game.ServerScriptService.PerkManager)
local DisasterManager = require(game.ServerScriptService.DisasterManager)

local RoundManager = {}

local LOBBY_COUNTDOWN = 10
local ROUND_LENGTH = 120
local INTERMISSION = 8

local alivePlayers = {}
local currentDisaster = nil
local currentMutation = nil

local RoundEvent = ReplicatedStorage:WaitForChild("RoundEvent")
local SpinEvent = ReplicatedStorage:WaitForChild("SpinEvent")

local disasters = {
	"Tornado", "Flood", "Meteor Strike", "Lightning Storm",
	"Volcanic Eruption", "Blizzard", "Earthquake", "Tsunami",
	"Acid Rain", "Sandstorm"
}

local mutations = {
	{name = "Low Gravity", effect = "LowGravity"},
	{name = "Big Players", effect = "BigPlayers"},
	{name = "Small Players", effect = "SmallPlayers"},
	{name = "Speed Run", effect = "SpeedRun"},
	{name = "Blind", effect = "Blind"},
	{name = "Chaos", effect = "Chaos"},
}

local function pickDisaster()
	return disasters[math.random(1, #disasters)]
end

local function pickMutation()
	if math.random(1, 100) <= 20 then
		return mutations[math.random(1, #mutations)]
	end
	return nil
end

local function notifyAll(event, data)
	RoundEvent:FireAllClients(event, data)
end

local function teleportToMap()
	alivePlayers = {}
	local gameSpawnsFolder = workspace:FindFirstChild("GameSpawns")
	if not gameSpawnsFolder then warn("GameSpawns folder not found — using fallback position") end
	local spawns = gameSpawnsFolder and gameSpawnsFolder:GetChildren() or {}
	local players = Players:GetPlayers()
	for i, player in ipairs(players) do
		local char = player.Character
		if char and char:FindFirstChild("HumanoidRootPart") then
			local spawn = #spawns > 0 and spawns[((i - 1) % #spawns) + 1] or nil
			local pos = spawn and spawn.Position or Vector3.new(-432, 45, 42)
			char.HumanoidRootPart.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
		end
		table.insert(alivePlayers, player)
	end
end

local function teleportToLobby()
	local lobbySpawnsFolder = workspace:FindFirstChild("LobbySpawns")
	local spawns = lobbySpawnsFolder and lobbySpawnsFolder:GetChildren() or {}
	local fallback = workspace:FindFirstChildOfClass("SpawnLocation")
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		if char and char:FindFirstChild("HumanoidRootPart") then
			local spawn = #spawns > 0 and spawns[math.random(1, #spawns)] or fallback
			local pos = spawn and spawn.Position or Vector3.new(0, 107, 0)
			char.HumanoidRootPart.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
		end
	end
end

local function onPlayerDied(player)
	for i, p in ipairs(alivePlayers) do
		if p == player then
			table.remove(alivePlayers, i)
			notifyAll("PlayerDied", {name = player.Name})
			break
		end
	end
	if #alivePlayers == 1 then
		notifyAll("LastSurvivor", {name = alivePlayers[1].Name})
	end
end

local function connectDeathEvents()
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		if char then
			local humanoid = char:FindFirstChild("Humanoid")
			if humanoid then
				humanoid.Died:Connect(function()
					onPlayerDied(player)
				end)
			end
		end
	end
end

local function runRound()
	-- Lobby countdown: fires a plain integer each second so clients can display a ticker
	for t = LOBBY_COUNTDOWN, 1, -1 do
		notifyAll("LobbyCountdown", t)
		task.wait(1)
	end

	teleportToMap()
	connectDeathEvents()

	-- Guard: nothing to do if no disasters are configured
	if #disasters == 0 then
		warn("No disasters configured")
		return
	end

	currentDisaster = pickDisaster()
	currentMutation = pickMutation()

	-- Warn clients which disaster is coming, then give them 5 seconds to react
	notifyAll("DisasterWarning", currentDisaster)
	task.wait(5)

	notifyAll("RoundStart", {
		disaster = currentDisaster,
		mutation = currentMutation and currentMutation.name or nil,
		duration = ROUND_LENGTH
	})

	print("🌪️ Disaster: " .. currentDisaster)

	-- DisasterManager.Run() fires a second DisasterWarning internally after ~3s (accepted behavior)
	local ok, runErr = pcall(DisasterManager.Run, currentDisaster)
	if not ok then
		warn("DisasterManager.Run error: " .. tostring(runErr))
	end

	task.wait(ROUND_LENGTH)

	-- Award money based on survival
	for _, player in ipairs(Players:GetPlayers()) do
		local survived = false
		for _, p in ipairs(alivePlayers) do
			if p == player then
				survived = true
				break
			end
		end
		local reward = survived and 100 or 25
		DataManager.AddMoney(player, reward)
		print(player.Name .. " earned $" .. reward .. (survived and " (survived)" or " (eliminated)"))
	end

	for _, p in ipairs(Players:GetPlayers()) do
		PerkManager.ClearPerks(p)
	end

	local luckBonus = 1
	if currentMutation then
		luckBonus = currentMutation.effect == "Chaos" and 3 or 2
	end

	DisasterManager.cleanupDisasters()
	notifyAll("RoundEnd", {
		luckBonus = luckBonus,
		mutation = currentMutation and currentMutation.name or nil
	})

	task.wait(INTERMISSION)
	teleportToLobby()
end

function RoundManager.Start()
	print("✅ RoundManager started!")
	while true do
		local ok, err = pcall(runRound)
		if not ok then
			warn("❌ Round error: " .. err)
		end
		task.wait(2)
	end
end

return RoundManager
