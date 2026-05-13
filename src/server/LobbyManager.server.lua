-- LobbyManager (ServerScriptService)
-- Handles: lobby spawning, join hype messages, leaderboard, practice mode, fun zones.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

-- Require DataManager (loaded by PlayerLoader before this runs)
local DataManager = require(game.ServerScriptService.DataManager)

-- Create lobby remotes
local LobbyEvent = ReplicatedStorage:FindFirstChild("LobbyEvent")
if not LobbyEvent then
    LobbyEvent = Instance.new("RemoteEvent")
    LobbyEvent.Name = "LobbyEvent"
    LobbyEvent.Parent = ReplicatedStorage
end

local LobbyRequest = ReplicatedStorage:FindFirstChild("LobbyRequest")
if not LobbyRequest then
    LobbyRequest = Instance.new("RemoteEvent")
    LobbyRequest.Name = "LobbyRequest"
    LobbyRequest.Parent = ReplicatedStorage
end

-- ── Lobby spawn helpers ───────────────────────────────────────────────────────
local function getSpawns(folderName)
    local folder = workspace:FindFirstChild(folderName)
    return folder and folder:GetChildren() or {}
end

local function spawnInLobby(player)
    local spawns = getSpawns("LobbySpawns")
    if #spawns == 0 then
        warn("LobbyManager: LobbySpawns folder empty or missing")
        return
    end
    local char = player.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local spawn = spawns[math.random(1, #spawns)]
        char.HumanoidRootPart.CFrame = CFrame.new(spawn.Position + Vector3.new(0, 3, 0))
    end
end

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

    -- Hype message on join
    task.wait(1.5)
    local count = #Players:GetPlayers()
    LobbyEvent:FireAllClients("playerJoined", {name = player.Name, count = count})
    if count >= 2 then
        task.delay(0.6, function()
            LobbyEvent:FireAllClients("roundSoon", {})
        end)
    end
end

for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(onPlayerAdded, player)
end
Players.PlayerAdded:Connect(onPlayerAdded)

-- ── Leaderboard broadcast (every 5s) ─────────────────────────────────────────
task.spawn(function()
    while true do
        task.wait(5)
        local entries = {}
        for _, player in ipairs(Players:GetPlayers()) do
            local data = DataManager.GetData(player)
            if data then
                table.insert(entries, {
                    name  = player.Name,
                    wins  = data.totalWins or 0,
                    level = data.level or 1,
                })
            end
        end
        table.sort(entries, function(a, b) return a.wins > b.wins end)
        local top = {}
        for i = 1, math.min(10, #entries) do
            table.insert(top, entries[i])
        end
        LobbyEvent:FireAllClients("leaderboard", top)
    end
end)

-- ── Practice Mode ─────────────────────────────────────────────────────────────
local practiceActive = {}

local MILD_DISASTERS = {
    -- Mini tornado with mild suction
    function(player)
        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then return end
        local pos = char.HumanoidRootPart.Position

        local tornado = Instance.new("Part")
        tornado.Name = "PracticeTornado"
        tornado.Size = Vector3.new(8, 30, 8)
        tornado.Shape = Enum.PartType.Cylinder
        tornado.Position = pos + Vector3.new(40, 15, 0)
        tornado.Anchored = true
        tornado.CanCollide = false
        tornado.Material = Enum.Material.Neon
        tornado.Color = Color3.fromRGB(150, 200, 255)
        tornado.Transparency = 0.6
        tornado.Parent = workspace

        local p = Instance.new("ParticleEmitter")
        p.Color = ColorSequence.new(Color3.fromRGB(200, 200, 255))
        p.Size = NumberSequence.new(0.3)
        p.Speed = NumberRange.new(5, 15)
        p.Rate = 40
        p.Parent = tornado

        TweenService:Create(tornado, TweenInfo.new(15, Enum.EasingStyle.Linear),
            {Position = pos + Vector3.new(-40, 15, 0)}
        ):Play()

        task.spawn(function()
            for i = 1, 150 do
                task.wait(0.1)
                if not tornado.Parent or not practiceActive[player.UserId] then break end
                local c = player.Character
                if c and c:FindFirstChild("HumanoidRootPart") then
                    local hrp = c.HumanoidRootPart
                    local dist = (hrp.Position - tornado.Position).Magnitude
                    if dist < 25 and dist > 2 then
                        local dir = (tornado.Position - hrp.Position).Unit
                        hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity + dir * (1 - dist/25) * 12
                    end
                end
            end
        end)
        task.wait(15)
        if tornado.Parent then tornado:Destroy() end
    end,

    -- Mini meteor shower (3 meteors with warning circles)
    function(player)
        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then return end
        local pos = char.HumanoidRootPart.Position

        for i = 1, 3 do
            task.wait(4)
            if not practiceActive[player.UserId] then break end
            local ox, oz = math.random(-20, 20), math.random(-20, 20)
            local landPos = Vector3.new(pos.X + ox, pos.Y, pos.Z + oz)

            local marker = Instance.new("Part")
            marker.Shape = Enum.PartType.Cylinder
            marker.Size = Vector3.new(0.5, 16, 16)
            marker.CFrame = CFrame.new(landPos.X, landPos.Y + 0.3, landPos.Z) * CFrame.Angles(0, 0, math.pi/2)
            marker.Anchored = true
            marker.CanCollide = false
            marker.Material = Enum.Material.Neon
            marker.Color = Color3.fromRGB(255, 80, 0)
            marker.Transparency = 0.4
            marker.Parent = workspace
            Debris:AddItem(marker, 2)

            task.wait(1.5)
            local meteor = Instance.new("Part")
            meteor.Shape = Enum.PartType.Ball
            meteor.Size = Vector3.new(5, 5, 5)
            meteor.Position = landPos + Vector3.new(0, 80, 0)
            meteor.Anchored = true
            meteor.Color = Color3.fromRGB(200, 80, 20)
            meteor.Parent = workspace
            TweenService:Create(meteor, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                {Position = landPos}
            ):Play()
            Debris:AddItem(meteor, 2.5)
        end
    end,

    -- Mini lightning (5 strikes with yellow markers)
    function(player)
        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then return end
        local pos = char.HumanoidRootPart.Position

        for i = 1, 5 do
            task.wait(3)
            if not practiceActive[player.UserId] then break end
            local strikePos = Vector3.new(
                pos.X + math.random(-20, 20), pos.Y,
                pos.Z + math.random(-20, 20)
            )
            local marker = Instance.new("Part")
            marker.Shape = Enum.PartType.Cylinder
            marker.Size = Vector3.new(0.5, 8, 8)
            marker.CFrame = CFrame.new(strikePos.X, strikePos.Y + 0.3, strikePos.Z) * CFrame.Angles(0, 0, math.pi/2)
            marker.Anchored = true
            marker.CanCollide = false
            marker.Material = Enum.Material.Neon
            marker.Color = Color3.fromRGB(255, 255, 0)
            marker.Transparency = 0.3
            marker.Parent = workspace
            Debris:AddItem(marker, 1.2)

            task.wait(1)
            local bolt = Instance.new("Part")
            bolt.Size = Vector3.new(0.5, 60, 0.5)
            bolt.Position = strikePos + Vector3.new(0, 30, 0)
            bolt.Anchored = true
            bolt.CanCollide = false
            bolt.Material = Enum.Material.Neon
            bolt.Color = Color3.fromRGB(255, 255, 100)
            bolt.Parent = workspace
            Debris:AddItem(bolt, 0.15)

            local c = player.Character
            if c and c:FindFirstChild("HumanoidRootPart") then
                if (c.HumanoidRootPart.Position - strikePos).Magnitude < 10 then
                    local h = c:FindFirstChild("Humanoid")
                    if h then h:TakeDamage(15) end
                end
            end
        end
    end,
}

LobbyRequest.OnServerEvent:Connect(function(player, requestType)
    if requestType == "startPractice" then
        if practiceActive[player.UserId] then
            LobbyEvent:FireClient(player, "practiceError", "Already practicing!")
            return
        end
        practiceActive[player.UserId] = true
        LobbyEvent:FireClient(player, "practiceStart", {})

        local fn = MILD_DISASTERS[math.random(1, #MILD_DISASTERS)]
        task.spawn(function()
            pcall(fn, player)
        end)

        task.delay(30, function()
            practiceActive[player.UserId] = nil
            if player and player.Parent then
                LobbyEvent:FireClient(player, "practiceEnd", {})
            end
        end)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    practiceActive[player.UserId] = nil
end)

-- ── Fun zone interactables ────────────────────────────────────────────────────
-- These activate on lobby Parts named: TrampolinePad, TeleporterPad_A/B, SlidePad, ParkourRing
-- Place these parts in the lobby via Studio; this script wires them up.

local function setupInteractables()
    -- Trampolines
    for _, part in ipairs(workspace:GetDescendants()) do
        if part:IsA("BasePart") and part.Name == "TrampolinePad" then
            part.Touched:Connect(function(hit)
                local hrp = hit.Parent and hit.Parent:FindFirstChild("HumanoidRootPart")
                local h   = hit.Parent and hit.Parent:FindFirstChild("Humanoid")
                if hrp and h and h.Health > 0 then
                    hrp.AssemblyLinearVelocity = Vector3.new(
                        hrp.AssemblyLinearVelocity.X * 0.2, 60,
                        hrp.AssemblyLinearVelocity.Z * 0.2
                    )
                end
            end)
        end
    end

    -- Teleporter pair
    local padA = workspace:FindFirstChild("TeleporterPad_A", true)
    local padB = workspace:FindFirstChild("TeleporterPad_B", true)
    if padA and padB then
        local debA, debB = {}, {}
        padA.Touched:Connect(function(hit)
            local hrp = hit.Parent and hit.Parent:FindFirstChild("HumanoidRootPart")
            if hrp and not debA[hit.Parent] then
                debA[hit.Parent] = true
                hrp.CFrame = CFrame.new(padB.Position + Vector3.new(0, 5, 0))
                task.delay(1, function() debA[hit.Parent] = nil end)
            end
        end)
        padB.Touched:Connect(function(hit)
            local hrp = hit.Parent and hit.Parent:FindFirstChild("HumanoidRootPart")
            if hrp and not debB[hit.Parent] then
                debB[hit.Parent] = true
                hrp.CFrame = CFrame.new(padA.Position + Vector3.new(0, 5, 0))
                task.delay(1, function() debB[hit.Parent] = nil end)
            end
        end)
    end

    -- Slides
    for _, part in ipairs(workspace:GetDescendants()) do
        if part:IsA("BasePart") and part.Name == "SlidePad" then
            local dir = part.CFrame.LookVector
            part.Touched:Connect(function(hit)
                local hrp = hit.Parent and hit.Parent:FindFirstChild("HumanoidRootPart")
                if hrp then
                    hrp.AssemblyLinearVelocity = dir * 40 + Vector3.new(0, 5, 0)
                end
            end)
        end
    end

    -- Parkour rings
    for _, part in ipairs(workspace:GetDescendants()) do
        if part:IsA("BasePart") and part.Name == "ParkourRing" then
            local origColor = part.Color
            part.Touched:Connect(function(hit)
                local char = hit.Parent
                if char and char:FindFirstChild("Humanoid") then
                    part.Color = Color3.fromRGB(80, 255, 80)
                    task.delay(0.5, function()
                        if part.Parent then part.Color = origColor end
                    end)
                end
            end)
        end
    end
end

task.delay(5, setupInteractables)
