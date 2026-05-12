-- LobbyManager
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RoundEvent = ReplicatedStorage:WaitForChild("RoundEvent")
local LOBBY_TIME = 15
local ROUND_TIME = 60

local function getSpawns(folderName)
	local folder = workspace:FindFirstChild(folderName)
	return folder and folder:GetChildren() or {}
end

local function shuffle(t)
	local copy = table.clone(t)
	for i = #copy, 2, -1 do
		local j = math.random(1, i)
		copy[i], copy[j] = copy[j], copy[i]
	end
	return copy
end

local function teleportPlayerTo(player, spawnPart)
	local char = player.Character
	if char and char:FindFirstChild("HumanoidRootPart") then
		char.HumanoidRootPart.CFrame = CFrame.new(spawnPart.Position + Vector3.new(0, 3, 0))
	end
end

local function teleportAllTo(players, spawns)
	if #spawns == 0 then return end
	local shuffledSpawns = shuffle(spawns)
	for i, player in ipairs(players) do
		local spawn = shuffledSpawns[((i - 1) % #shuffledSpawns) + 1]
		teleportPlayerTo(player, spawn)
	end
end

local function setLobbySpawnsEnabled(enabled)
	for _, sp in ipairs(getSpawns("LobbySpawns")) do
		if sp:IsA("SpawnLocation") then
			sp.Enabled = enabled
		end
	end
end

local function spawnInLobby(player)
	local spawns = getSpawns("LobbySpawns")
	if #spawns == 0 then return end
	local spawn = spawns[math.random(1, #spawns)]
	teleportPlayerTo(player, spawn)
end

-- PlayerAdded: send new players to lobby
local function onPlayerAdded(player)
	local function onCharacterAdded(char)
		char:WaitForChild("HumanoidRootPart", 10)
		task.wait()
		spawnInLobby(player)
	end
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
	player.CharacterAdded:Connect(onCharacterAdded)
end

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end
Players.PlayerAdded:Connect(onPlayerAdded)

-- Main round loop
task.spawn(function()
	while true do
		local ok, err = pcall(function()
			-- LOBBY PHASE
			setLobbySpawnsEnabled(true)
			for t = LOBBY_TIME, 1, -1 do
				RoundEvent:FireAllClients("LobbyCountdown", t)
				task.wait(1)
			end

			-- TELEPORT TO GAME ISLAND
			teleportAllTo(Players:GetPlayers(), getSpawns("GameSpawns"))
			RoundEvent:FireAllClients("RoundStart", {})

			-- ROUND PHASE
			task.wait(ROUND_TIME)

			-- TELEPORT BACK TO LOBBY
			teleportAllTo(Players:GetPlayers(), getSpawns("LobbySpawns"))
			RoundEvent:FireAllClients("RoundEnd", {})
			setLobbySpawnsEnabled(true)
		end)
		if not ok then
			warn("LobbyManager loop error: " .. tostring(err))
			task.wait(2)
		end
	end
end)
