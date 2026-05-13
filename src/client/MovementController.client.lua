-- MovementController: Dive (Q), Climb (Space near wall), Wall Slide
local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local camera    = workspace.CurrentCamera
local playerGui = player:WaitForChild("PlayerGui")

local DiveRequest     = ReplicatedStorage:WaitForChild("DiveRequest",     15)
local DiveGranted     = ReplicatedStorage:WaitForChild("DiveGranted",     15)
local ClimbStartEvent = ReplicatedStorage:WaitForChild("ClimbStartEvent", 15)
local ClimbHeartbeat  = ReplicatedStorage:WaitForChild("ClimbHeartbeat",  15)
local ClimbStopReq    = ReplicatedStorage:WaitForChild("ClimbStopReq",    15)
local ClimbStopEvent  = ReplicatedStorage:WaitForChild("ClimbStopEvent",  15)

-- ── State ─────────────────────────────────────────────────────────────────────
local isDiving    = false
local isClimbing  = false
local isWallSlide = false
local diveCooldownEnd = 0  -- client-side tracking for UI only

-- ── Dive visual: FOV pulse + dust particles ────────────────────────────────────
local function doDiveVisual()
    -- FOV pulse: zoom in slightly then snap back
    local origFOV = camera.FieldOfView
    TweenService:Create(camera, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {FieldOfView = origFOV + 12}):Play()
    task.wait(0.08)
    TweenService:Create(camera, TweenInfo.new(0.4, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
        {FieldOfView = origFOV}):Play()

    -- Dust particles at character feet
    local char = player.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        local att = Instance.new("Attachment")
        att.Position = Vector3.new(0, -3, 0)
        att.Parent   = hrp

        local dust = Instance.new("ParticleEmitter")
        dust.Parent    = att
        dust.Color     = ColorSequence.new(Color3.fromRGB(200, 190, 170))
        dust.LightEmission = 0
        dust.Transparency  = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.4),
            NumberSequenceKeypoint.new(1, 1),
        })
        dust.Size     = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.8),
            NumberSequenceKeypoint.new(1, 0),
        })
        dust.Speed    = NumberRange.new(3, 8)
        dust.Lifetime = NumberRange.new(0.3, 0.6)
        dust.Rate     = 60
        dust.SpreadAngle = Vector2.new(60, 60)

        task.wait(0.15)
        dust.Rate = 0
        task.delay(0.8, function() att:Destroy() end)
    end
end

-- ── Dive ──────────────────────────────────────────────────────────────────────
local function tryDive()
    if isDiving then return end
    if tick() < diveCooldownEnd then return end
    local char = player.Character
    local hum  = char and char:FindFirstChild("Humanoid")
    if not hum or hum.Health <= 0 then return end

    isDiving = true
    DiveRequest:FireServer()
    task.spawn(doDiveVisual)

    -- Temporary roll: push character forward
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then
        local fwd = hrp.CFrame.LookVector
        hrp.AssemblyLinearVelocity = fwd * 28 + Vector3.new(0, 4, 0)
    end
end

DiveGranted.OnClientEvent:Connect(function(cooldown)
    diveCooldownEnd = tick() + cooldown
    task.delay(0.6, function() isDiving = false end)
end)

-- ── Climb helpers ─────────────────────────────────────────────────────────────
local function isNearWall()
    local char = player.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {char}
    params.FilterType = Enum.RaycastFilterType.Exclude

    local dirs = {
        hrp.CFrame.LookVector,
        hrp.CFrame.RightVector,
        -hrp.CFrame.RightVector,
    }
    for _, d in ipairs(dirs) do
        if workspace:Raycast(hrp.Position, d * 3.5, params) then
            return true
        end
    end
    return false
end

local function isGrounded()
    local char = player.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return true end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    return workspace:Raycast(hrp.Position, Vector3.new(0, -4, 0), params) ~= nil
end

-- ── Climb state machine ───────────────────────────────────────────────────────
local climbHeartbeatThread = nil

local function startClimb()
    if isClimbing then return end
    if not isNearWall() then return end
    local char = player.Character
    local hum  = char and char:FindFirstChild("Humanoid")
    if not hum or hum.Health <= 0 then return end

    isClimbing = true
    ClimbStartEvent:FireServer()

    -- Climbing: cancel gravity, move vertically with W/S
    hum.PlatformStand = true

    climbHeartbeatThread = task.spawn(function()
        local t = 0
        while isClimbing do
            task.wait(0.05)  -- 20 Hz movement loop
            t = t + 0.05
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if not hrp then break end

            -- Vertical input
            local up = 0
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then up = 1
            elseif UserInputService:IsKeyDown(Enum.KeyCode.S) then up = -1 end

            hrp.AssemblyLinearVelocity = Vector3.new(0, up * 10, 0)

            -- Send heartbeat to server every 0.5s
            if t >= 0.5 then
                t = 0
                ClimbHeartbeat:FireServer(hrp.Position)
            end
        end
        -- Restore physics
        local hum2 = char:FindFirstChild("Humanoid")
        if hum2 then hum2.PlatformStand = false end
    end)
end

local function stopClimb(reason)
    if not isClimbing then return end
    isClimbing = false
    ClimbStopReq:FireServer()

    local char = player.Character
    local hum  = char and char:FindFirstChild("Humanoid")
    if hum then hum.PlatformStand = false end
end

ClimbStopEvent.OnClientEvent:Connect(function(reason)
    stopClimb(reason)
end)

-- ── Wall Slide ────────────────────────────────────────────────────────────────
local WALL_SLIDE_GRAVITY_SCALE = 0.4  -- reduce gravity to 40%
local wallSlideBV = nil

local function updateWallSlide()
    local char = player.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    local hum  = char and char:FindFirstChild("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then return end

    local falling = hrp.AssemblyLinearVelocity.Y < -2
    local nearWall = isNearWall()
    local moving = UserInputService:IsKeyDown(Enum.KeyCode.W) or
                   UserInputService:IsKeyDown(Enum.KeyCode.A) or
                   UserInputService:IsKeyDown(Enum.KeyCode.S) or
                   UserInputService:IsKeyDown(Enum.KeyCode.D)

    local shouldSlide = falling and nearWall and moving and not isClimbing and not isGrounded()

    if shouldSlide and not isWallSlide then
        isWallSlide = true
        -- Apply constant upward force to reduce effective gravity
        if not wallSlideBV then
            wallSlideBV = Instance.new("VectorForce")
            wallSlideBV.Name  = "WallSlideForce"
            wallSlideBV.Force = Vector3.new(0, workspace.Gravity * hrp.AssemblyMass * (1 - WALL_SLIDE_GRAVITY_SCALE), 0)
            wallSlideBV.RelativeTo = Enum.ActuatorRelativeTo.World
            local att = Instance.new("Attachment")
            att.Parent = hrp
            wallSlideBV.Attachment0 = att
            wallSlideBV.Parent = hrp
        end
    elseif not shouldSlide and isWallSlide then
        isWallSlide = false
        if wallSlideBV then
            if wallSlideBV.Attachment0 then wallSlideBV.Attachment0:Destroy() end
            wallSlideBV:Destroy()
            wallSlideBV = nil
        end
    end
end

-- ── Input bindings ────────────────────────────────────────────────────────────
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.Q then
        tryDive()
    elseif input.KeyCode == Enum.KeyCode.Space then
        if isNearWall() and not isGrounded() then
            startClimb()
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.Space then
        if isClimbing then stopClimb("released") end
    end
end)

-- Wall slide checked every frame
RunService.Heartbeat:Connect(function()
    updateWallSlide()
end)

-- Cleanup on respawn
player.CharacterAdded:Connect(function()
    isDiving    = false
    isClimbing  = false
    isWallSlide = false
    diveCooldownEnd = 0
    if climbHeartbeatThread then
        task.cancel(climbHeartbeatThread)
        climbHeartbeatThread = nil
    end
    if wallSlideBV then
        if wallSlideBV.Attachment0 then wallSlideBV.Attachment0:Destroy() end
        pcall(function() wallSlideBV:Destroy() end)
        wallSlideBV = nil
    end
end)

print("[MovementController] Loaded (Dive=Q, Climb=Space+Wall, WallSlide=auto)")
