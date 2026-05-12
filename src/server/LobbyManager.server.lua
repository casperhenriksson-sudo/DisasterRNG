-- LobbyManager
-- Responsibility: send players to a lobby spawn when they join or respawn.
-- The round loop (countdown, teleport to map, etc.) lives entirely in RoundManager.

local Players = game:GetService("Players")

local function getSpawns(folderName)
	local folder = workspace:FindFirstChild(folderName)
	return folder and folder:GetChildren() or {}
end

local function teleportPlayerTo(player, spawnPart)
	local char = player.Character
	if char and char:FindFirstChild("HumanoidRootPart") then
		char.HumanoidRootPart.CFrame = CFrame.new(spawnPart.Position + Vector3.new(0, 3, 0))
	end
end

local function spawnInLobby(player)
	local spawns = getSpawns("LobbySpawns")
	if #spawns == 0 then
		warn("LobbyManager: LobbySpawns folder is empty or missing")
		return
	end
	local spawn = spawns[math.random(1, #spawns)]
	teleportPlayerTo(player, spawn)
end

-- Send a player (and future respawns) to the lobby island
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

-- Handle players already in-game when this script starts
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end
Players.PlayerAdded:Connect(onPlayerAdded)
