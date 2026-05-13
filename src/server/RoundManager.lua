local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataManager  = require(game.ServerScriptService.DataManager)
local PerkManager  = require(game.ServerScriptService.PerkManager)
local DisasterManager = require(game.ServerScriptService.DisasterManager)
local CurrencyManager = require(game.ServerScriptService.CurrencyManager)

local RoundManager = {}

-- Set DEBUG_MODE = true to enable debug prints
local DEBUG_MODE = false
local function dprint(...)
    if DEBUG_MODE then print("[RoundManager]", ...) end
end

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
local roundCount    = 0       -- increments each round
local roundTimer    = 0       -- seconds elapsed in current round (for GetTimeLeft)
local damageTaken   = {}      -- [player] = total damage taken this round (for perfect-run XP)

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

-- PlayerAdded: notify late joiners that a round is already in progress
Players.PlayerAdded:Connect(function(player)
	if not roundActive then return end
	player.CharacterAdded:Connect(function()
		task.wait(1)
		if roundActive then
			RoundEvent:FireClient(player, "RoundInProgress", {})
		end
	end)
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
	roundCount   = roundCount + 1
	roundActive  = true
	roundEnding  = false
	teleportToMap()

	-- Snapshot alive players AFTER teleport
	alivePlayers = {}
	damageTaken = {}
	for _, p in ipairs(Players:GetPlayers()) do
		table.insert(alivePlayers, p)
		damageTaken[p] = 0
		-- Track damage taken via health change
		local char = p.Character
		if char then
			local humanoid = char:FindFirstChild("Humanoid")
			if humanoid then
				local prevHealth = humanoid.Health
				humanoid.HealthChanged:Connect(function(newHealth)
					if newHealth < prevHealth then
						damageTaken[p] = (damageTaken[p] or 0) + (prevHealth - newHealth)
					end
					prevHealth = newHealth
				end)
			end
		end
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
		round    = roundCount,
	})

	dprint("Disaster =", currentDisaster)

	local ok, runErr = pcall(DisasterManager.Run, currentDisaster)
	if not ok then
		warn("DisasterManager.Run error: " .. tostring(runErr))
	end

	-- ── 5. Wait ROUND_LENGTH, but allow early exit via roundEndSignal ────────
	roundTimer = 0
	local conn = roundEndSignal.Event:Connect(function()
		roundTimer = ROUND_LENGTH   -- jump the counter to the end
	end)
	while roundTimer < ROUND_LENGTH do
		task.wait(1)
		roundTimer += 1
	end
	conn:Disconnect()

	-- ── 6. Rewards ───────────────────────────────────────────────────────────
	if roundEnding then return end  -- another code path already handling end
	roundEnding = true

	-- Determine if there is exactly one winner (last survivor)
	local winner = nil
	if #alivePlayers == 1 then
		winner = alivePlayers[1]
	end

	-- Build survivor name list for result screen (top 3)
	local survivorNames = {}
	for _, p in ipairs(alivePlayers) do
		table.insert(survivorNames, p.Name)
	end

	for _, player in ipairs(Players:GetPlayers()) do
		local survived = false
		for _, p in ipairs(alivePlayers) do
			if p == player then
				survived = true
				break
			end
		end

		local data = DataManager.GetData(player)

		-- XP awards (server-authoritative)
		local xpEarned = 0
		if survived then
			xpEarned = xpEarned + 30  -- survived
			if player == winner then
				xpEarned = xpEarned + 50  -- last survivor bonus
			end
			-- Perfect run: check damageTaken table
			if damageTaken[player] and damageTaken[player] == 0 then
				xpEarned = xpEarned + 25
			end
		end

		local xpResult = DataManager.AddXP(player, xpEarned)

		if survived then
			CurrencyManager.AwardSurviveBonus(player)
			if player == winner then
				CurrencyManager.AwardWinBonus(player)
			end
			dprint(player.Name, "survived" .. (player == winner and " (WINNER)" or ""))
		else
			dprint(player.Name, "eliminated")
		end

		-- Increment rounds played for everyone
		if data then
			data.totalRoundsPlayed = (data.totalRoundsPlayed or 0) + 1
		end

		-- Fire round result to each player individually
		RoundEvent:FireClient(player, "RoundResult", {
			survived    = survived,
			isWinner    = (player == winner),
			xpEarned    = xpEarned,
			newXP       = xpResult.newXP,
			newLevel    = xpResult.newLevel,
			didLevelUp  = xpResult.didLevelUp,
			survivors   = survivorNames,
			disaster    = currentDisaster,
		})
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
	dprint("started")
	while true do
		local ok, err = pcall(runRound)
		if not ok then
			warn("RoundManager: round error — " .. tostring(err))
			roundActive = false
		end
		task.wait(2)
	end
end

function RoundManager.SkipRound()
	if roundActive and not roundEnding then
		roundEndSignal:Fire()
	end
end

function RoundManager.GetTimeLeft()
	return math.max(0, ROUND_LENGTH - roundTimer)
end

return RoundManager
