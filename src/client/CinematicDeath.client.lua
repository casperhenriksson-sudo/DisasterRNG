-- CinematicDeath: slow-motion visual effect on player death
-- Blur ramp 0→24 + FOV zoom 70→30 over 1.5s, then restore after 2.5s total
-- Uses CameraStateManager priority 2 (highest camera priority)

local Players        = game:GetService("Players")
local TweenService   = game:GetService("TweenService")
local Lighting       = game:GetService("Lighting")
local RunService     = game:GetService("RunService")

local CameraStateManager = require(script.Parent.CameraStateManager)

local localPlayer = Players.LocalPlayer

-- Ensure a BlurEffect exists in Lighting
local blur = Lighting:FindFirstChildOfClass("BlurEffect")
if not blur then
    blur = Instance.new("BlurEffect")
    blur.Size = 0
    blur.Parent = Lighting
end

local deathActive = false

local function playDeathCinematic(character)
    if deathActive then return end
    deathActive = true

    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        deathActive = false
        return
    end

    -- 1. Take camera ownership
    CameraStateManager.push("CinematicDeath", 2)
    local cam = workspace.CurrentCamera

    -- Snapshot starting position/focus
    local startCFrame = cam.CFrame
    local targetOffset = hrp.Position + Vector3.new(0, 2, 0)
    local startFOV = cam.FieldOfView

    -- 2. Ramp blur 0→24 over 0.5s
    local blurTween = TweenService:Create(blur, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = 24})
    blurTween:Play()

    -- 3. Lerp camera FOV and position toward character over 1.5s
    local elapsed = 0
    local zoomDuration = 1.5
    local conn
    conn = RunService.Heartbeat:Connect(function(dt)
        if not deathActive then
            conn:Disconnect()
            return
        end
        elapsed = elapsed + dt
        local t = math.min(elapsed / zoomDuration, 1)
        local ease = 1 - (1 - t)^3  -- cubic ease out

        -- FOV lerp 70→30
        local targetFOV = 30
        cam.FieldOfView = startFOV + (targetFOV - startFOV) * ease

        -- Camera position: move inward toward HRP
        if hrp.Parent then
            local hrpPos = hrp.Position + Vector3.new(0, 2, 0)
            local direction = (startCFrame.Position - hrpPos).Unit
            local startDist = (startCFrame.Position - hrpPos).Magnitude
            local targetDist = math.max(startDist * 0.3, 5)
            local newDist = startDist + (targetDist - startDist) * ease
            local newPos = hrpPos + direction * newDist
            cam.CFrame = CFrame.new(newPos, hrpPos)
        end

        if t >= 1 then
            conn:Disconnect()
        end
    end)

    -- 4. After 2.5s total: fade blur back, restore camera
    task.delay(2.5, function()
        if not deathActive then return end

        local blurFade = TweenService:Create(blur, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = 0})
        blurFade:Play()

        -- Reset FOV
        TweenService:Create(cam, TweenInfo.new(0.5), {FieldOfView = 70}):Play()

        task.delay(0.5, function()
            CameraStateManager.pop("CinematicDeath")
            cam.FieldOfView = 70
            deathActive = false
        end)
    end)
end

local function connectCharacter(character)
    deathActive = false  -- reset on new character
    CameraStateManager.pop("CinematicDeath")  -- ensure clean state

    local humanoid = character:WaitForChild("Humanoid")
    humanoid.Died:Connect(function()
        playDeathCinematic(character)
    end)
end

-- Connect to current character and future respawns
if localPlayer.Character then
    connectCharacter(localPlayer.Character)
end
localPlayer.CharacterAdded:Connect(connectCharacter)
