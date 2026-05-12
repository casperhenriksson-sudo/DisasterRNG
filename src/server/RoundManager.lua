local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataManager  = require(game.ServerScriptService.DataManager)
local PerkManager  = require(game.ServerScriptService.PerkManager)
local DisasterManager = require(game.ServerScriptService.DisasterManager)

local RoundManager = {}

-- ── Constants ────────────────────────────────────────────────────────────────
local MIN_PLAYERS      = 2
local LOBBY_COUNTDOWN  = 10
local ROUND_LENGTH     = 120
local INTERMISSION     = 8

-- ── RemoteEvent ──────────────────────────────────────────────────────────────
local RoundEvent = ReplicatedStorage:WaitForChild("RoundEvent")

-- ── Module-level state ───────────────────────────────────────────────────────
local alivePlayers  = {}
local roundActive   = false   -- true while players are on the map
local roundEnding   = false   -- guard: prevents double endRound

local roundEndSignal = Instance.new("BindableEvent") -- fired to cut ROUND_LENGTH short

-- ── Disaster / mutation tables ───────────────────────────────────────────────
local disasters = {
	"Tornado", "Flood", "Meteor Strike", "Lightning Storm",
	"Volcanic Eruption", "Blizzard", "Earthquake", "Tsunami",
	"Acid Rain", "Sandstorm"
}

local mutations = {
	{name = "Low Gravity",   effect = "LowGravity"},
	{name = "Big Players",   effect = "BigPlayers"},
	{name = "Small Players", effect = "SmallPlayers"},
	{name = "Speed Run",     effect = "SpeedRun"},
	{name = "Blind",         effect = "Blind"},
	{name = "Chaos",         effect = "Chaos"},
}

-- ── Helpers ───────────────────────────────────────────────────────────────────
local function notifyAll(event, data)
	RoundEvent:FireAllClients(event, data)
end

local function pickDisaster()
	return disasters[math.random(1, #disasters)]
end

local function pickMutation()
	if math.random(1, 100) <= 20 then
		return mutations[math.random(1, #mutations)]
	end
	return nil
end

local function teleportToMap()
	local gameSpawnsFolder = workspace:FindFirstChild("GameSpawns")
	if not gameSpawnsFolder then
		warn("RoundManager: GameSpawns folder not found — using fallback position")
	end
	local spawns  = gameSpawnsFolder and gameSpawnsFolder:GetChildren() or {}
	local players = Players:GetPlayers()
	for i, player in ipairs(players) do
		local char = player.Character
		if char and char:FindFirstChild("HumanoidRootPart") then
			local spawn = #spawns > 0 and spawns[((i - 1) % #spawns) + 1] or nil
			local pos   = spawn and spawn.Position or Vector3.new(-432, 45, 42)
			char.HumanoidRootPart.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
		end
	end
end

local function teleportToLobby()
	local lobbySpawnsFolder = workspace:FindFirstChild("LobbySpawns")
	local spawns = lobbySpawnsFolder and lobbySpawnsFolder:GetChildren() or {}
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		if char and char:FindFirstChild("HumanoidRootPart") then
			local spawn = #spawns > 0 and spawns[math.random(1, #spawns)] or nil
			local pos   = spawn and spawn.Position or Vector3.new(0, 107, 0)
			char.HumanoidRootPart.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
		end
	end
end

-- ── Death / removal handlers ──────────────────────────────────────────────────
local function removeFromAlive(player)
	for i, p in ipairs(alivePlayers) do
		if p == player then
			table.remove(alivePlayers, i)
			break
		end
	end
end

local function onPlayerDied(player)
	removeFromAlive(player)
	notifyAll("PlayerDied", {name = player.Name})

	if #alivePlayers == 1 then
		notifyAll("LastSurvivor", {name = alivePlayers[1].Name})
	end

	-- All players eliminated → end round early
	if #alivePlayers == 0 then
		roundEndSignal:Fire()
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

-- PlayerRemoving: if a player disconnects mid-round, remove them from alive list
Players.PlayerRemoving:Connect(function(player)
	if not roundActive then return end
	removeFromAlive(player)
	if #alivePlayers == 0 then
		roundEndSignal:Fire()
	end
end)

-- ── Core round logic ───────────────────────────────────────────────────────────
local function runRound()
	-- ── 1. Wait for minimum players ──────────────────────────────────────────
	notifyAll("LobbyWaiting", {min = MIN_PLAYERS})
	while #Players:GetPlayers() < MIN_PLAYERS do
		task.wait(1)
	end

	-- ── 2. Lobby countdown ───────────────────────────────────────────────────
	for t = LOBBY_COUNTDOWN, 1, -1 do
		notifyAll("LobbyCountdown", t)
		task.wait(1)
	end

	-- ── 3. Teleport to map ───────────────────────────────────────────────────
	roundActive  = true
	roundEnding  = false
	teleportToMap()

	-- Snapshot alive players AFTER teleport
	alivePlayers = {}
	for _, p in ipairs(Players:GetPlayers()) do
		table.insert(alivePlayers, p)
	end

	connectDeathEvents()

	-- ── 4. Pick disaster / mutation ──────────────────────────────────────────
	if #disasters == 0 then
		warn("RoundManager: No disasters configured")
		return
	end

	local currentDisaster = pickDisaster()
	local currentMutation = pickMutation()

	notifyAll("DisasterWarning", {stage = 1, disaster = currentDisaster})
	task.wait(4)
	notifyAll("DisasterWarning", {stage = 2, disaster = currentDisaster})
	task.wait(1)

	notifyAll("RoundStart", {
		disaster = currentDisaster,
		mutation = currentMutation and currentMutation.name or nil,
		duration = ROUND_LENGTH,
	})

	print("RoundManager: Disaster = " .. currentDisaster)

	local ok, runErr = pcall(DisasterManager.Run, currentDisaster)
	if not ok then
		warn("DisasterManager.Run error: " .. tostring(runErr))
	end

	-- ── 5. Wait ROUND_LENGTH, but allow early exit via roundEndSignal ────────
	local t    = 0
	local conn = roundEndSignal.Event:Connect(function()
		t = ROUND_LENGTH   -- jump the counter to the end
	end)
	while t < ROUND_LENGTH do
		task.wait(1)
		t += 1
	end
	conn:Disconnect()

	-- ── 6. Rewards ───────────────────────────────────────────────────────────
	if roundEnding then return end  -- another code path already handling end
	roundEnding = true

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

	-- ── 7. Perks + luck bonus ────────────────────────────────────────────────
	for _, p in ipairs(Players:GetPlayers()) do
		PerkManager.ClearPerks(p)
	end

	local luckBonus = 1
	if currentMutation then
		luckBonus = currentMutation.effect == "Chaos" and 3 or 2
	end

	-- ── 8. Cleanup and notify ────────────────────────────────────────────────
	DisasterManager.cleanupDisasters()
	notifyAll("RoundEnd", {
		luckBonus = luckBonus,
		mutation  = currentMutation and currentMutation.name or nil,
	})

	task.wait(INTERMISSION)

	teleportToLobby()
	roundActive = false
end

-- ── Public API ────────────────────────────────────────────────────────────────
function RoundManager.Start()
	print("RoundManager: started")
	while true do
		local ok, err = pcall(runRound)
		if not ok then
			warn("RoundManager: round error — " .. tostring(err))
			roundActive = false
		end
		task.wait(2)
	end
end

return RoundManager
