-- SpectatorCamera: orbit camera around the last survivor for all other players
-- Activates when "LastSurvivor" event fires and it's NOT the local player.
-- One Highlight at a time (GPU constraint): deleted on round end.

local Players        = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService     = game:GetService("RunService")

local CameraStateManager = require(script.Parent.CameraStateManager)

local localPlayer = Players.LocalPlayer
local RoundEvent  = ReplicatedStorage:WaitForChild("RoundEvent")

-- Orbit state
local orbitConn      = nil
local orbitAngle     = 0   -- degrees, accumulated
local survivorHRP    = nil -- HumanoidRootPart of last survivor
local activeHighlight = nil

local ORBIT_RADIUS   = 15
local ORBIT_HEIGHT   = 5
local ORBIT_SPEED    = 30  -- degrees per second

local function clearHighlight()
    if activeHighlight then
        activeHighlight:Destroy()
        activeHighlight = nil
    end
end

local function stopSpectator()
    if orbitConn then
        orbitConn:Disconnect()
        orbitConn = nil
    end
    survivorHRP = nil
    CameraStateManager.pop("SpectatorCamera")
    clearHighlight()
    workspace.CurrentCamera.FieldOfView = 70
end

local function startSpectating(targetPlayer)
    local char = targetPlayer.Character
    if not char then
        -- wait for character to load
        char = targetPlayer.CharacterAdded:Wait()
    end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    survivorHRP = hrp
    orbitAngle  = 0

    -- Add Highlight — only ONE at a time (rule: delete old first)
    clearHighlight()
    local hl = Instance.new("Highlight")
    hl.FillColor         = Color3.fromRGB(255, 255, 255)
    hl.OutlineColor      = Color3.fromRGB(255, 215, 0)   -- gold
    hl.FillTransparency  = 0.5
    hl.OutlineTransparency = 0
    hl.Adornee           = char
    hl.Parent            = char
    activeHighlight       = hl

    -- Push camera ownership (priority 1)
    CameraStateManager.push("SpectatorCamera", 1)
    local cam = workspace.CurrentCamera

    orbitConn = RunService.Heartbeat:Connect(function(dt)
        if not survivorHRP or not survivorHRP.Parent then
            stopSpectator()
            return
        end

        orbitAngle = orbitAngle + ORBIT_SPEED * dt
        local rad = math.rad(orbitAngle)

        local center = survivorHRP.Position
        local camX   = center.X + math.cos(rad) * ORBIT_RADIUS
        local camZ   = center.Z + math.sin(rad) * ORBIT_RADIUS
        local camPos = Vector3.new(camX, center.Y + ORBIT_HEIGHT, camZ)

        cam.CFrame = CFrame.new(camPos, center + Vector3.new(0, 1, 0))
    end)
end

RoundEvent.OnClientEvent:Connect(function(event, data)
    if event == "LastSurvivor" then
        -- If it's the local player, they're alive — don't orbit self
        if data and data.name == localPlayer.Name then return end

        -- Find the survivor player object
        local targetPlayer = Players:FindFirstChild(data and data.name or "")
        if not targetPlayer then return end

        startSpectating(targetPlayer)

    elseif event == "RoundEnd" or event == "RoundResult" then
        stopSpectator()
    end
end)
