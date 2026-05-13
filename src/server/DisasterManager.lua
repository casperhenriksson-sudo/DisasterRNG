local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RoundEvent = ReplicatedStorage:WaitForChild("RoundEvent")
local DisasterEvent = ReplicatedStorage:FindFirstChild("DisasterEvent")
if not DisasterEvent then
    DisasterEvent = Instance.new("RemoteEvent")
    DisasterEvent.Name = "DisasterEvent"
    DisasterEvent.Parent = ReplicatedStorage
end

local DisasterManager = {}

local DEBUG_MODE = false
local function dprint(...)
    if DEBUG_MODE then print("[DisasterManager]", ...) end
end

-- ============================================
-- 🔧 HELPER FUNCTIONS
-- ============================================

local function getMapCenter()
    local map = workspace:FindFirstChild("CurrentMap") or workspace:FindFirstChild("Model")
    if map then
        local cf, size = map:GetBoundingBox()
        return cf.Position
    end
    return Vector3.new(-432, 10, 42)
end

local function getAllPlayers()
    return Players:GetPlayers()
end

local function damagePlayer(player, amount)
    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChild("Humanoid")
    if humanoid and humanoid.Health > 0 then
        humanoid:TakeDamage(amount)
    end
end

local function getBreakableParts()
    local map = workspace:FindFirstChild("CurrentMap") or workspace:FindFirstChild("Model")
    if not map then return {} end
    local parts = {}
    for _, part in ipairs(map:GetDescendants()) do
        if part:IsA("BasePart") and part.Anchored then
            local name = part.Name:lower()
            if (not string.find(name, "ground") and
               not string.find(name, "floor") and
               not string.find(name, "base") and
               not string.find(name, "terrain")) and
               (part.Size.Y < 5 or (part.Size.X < 100 and part.Size.Z < 100)) then
                table.insert(parts, part)
            end
        end
    end
    return parts
end

local function breakPart(part, force, lifetime)
    if not part or not part.Parent then return end
    part.Anchored = false
    part.AssemblyLinearVelocity = force
    part.AssemblyAngularVelocity = Vector3.new(
        math.random(-5, 5),
        math.random(-5, 5),
        math.random(-5, 5)
    )
    local conn
    local actualLifetime = lifetime or 15
    conn = part.Touched:Connect(function(hit)
        local char = hit.Parent
        local humanoid = char and char:FindFirstChild("Humanoid")
        if humanoid and humanoid.Health > 0 then
            humanoid:TakeDamage(12)
            conn:Disconnect()
        end
    end)
    task.delay(actualLifetime, function()
        conn:Disconnect()
    end)
    Debris:AddItem(part, actualLifetime)
end

local function createFire(pos, lifetime)
    local fire = Instance.new("Part")
    fire.Name = "FirePart"
    fire.Size = Vector3.new(3, 1, 3)
    fire.Position = pos
    fire.Anchored = true
    fire.CanCollide = false
    fire.Transparency = 1
    fire.Parent = workspace

    local flame = Instance.new("Fire")
    flame.Size = 8
    flame.Heat = 10
    flame.Parent = fire

    fire.Touched:Connect(function(hit)
        local char = hit.Parent
        local humanoid = char and char:FindFirstChild("Humanoid")
        if humanoid then
            humanoid:TakeDamage(5)
        end
    end)

    Debris:AddItem(fire, lifetime or 12)
end

local function breakPercentage(parts, percent, forceFunc, lifetime)
    for _, part in ipairs(parts) do
        if math.random(1, 100) <= percent then
            local force = forceFunc(part)
            task.spawn(function()
                task.wait(math.random() * 2)
                breakPart(part, force, lifetime)
            end)
        end
    end
end

-- Spawn a ground warning marker (circle) at a position
local function spawnWarningMarker(pos, radius, color, lifetime)
    local marker = Instance.new("Part")
    marker.Name = "WarningMarker"
    marker.Shape = Enum.PartType.Cylinder
    marker.Size = Vector3.new(0.5, radius * 2, radius * 2)
    marker.CFrame = CFrame.new(pos.X, pos.Y + 0.3, pos.Z) * CFrame.Angles(0, 0, math.pi / 2)
    marker.Anchored = true
    marker.CanCollide = false
    marker.Material = Enum.Material.Neon
    marker.Color = color
    marker.Transparency = 0.3
    marker.Parent = workspace
    -- Pulse transparency
    local tween = TweenService:Create(marker,
        TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        {Transparency = 0.7}
    )
    tween:Play()
    Debris:AddItem(marker, lifetime)
    return marker
end

-- ============================================
-- 🌪️ TORNADO  —  suction mechanic
-- ============================================
function DisasterManager.Tornado()
    local center = getMapCenter()
    local parts = getBreakableParts()

    local tornado = Instance.new("Part")
    tornado.Name = "Tornado"
    tornado.Size = Vector3.new(15, 60, 15)
    tornado.Shape = Enum.PartType.Cylinder
    tornado.Position = center + Vector3.new(80, 30, 0)
    tornado.Anchored = true
    tornado.CanCollide = false
    tornado.Material = Enum.Material.Neon
    tornado.Color = Color3.fromRGB(150, 150, 200)
    tornado.Transparency = 0.5
    tornado.Parent = workspace

    local debrisParticle = Instance.new("ParticleEmitter")
    debrisParticle.Color = ColorSequence.new(Color3.fromRGB(140, 140, 140))
    debrisParticle.Size = NumberSequence.new(0.5)
    debrisParticle.Speed = NumberRange.new(10, 25)
    debrisParticle.Rate = 80
    debrisParticle.SpreadAngle = Vector2.new(60, 60)
    debrisParticle.Parent = tornado

    local tween = TweenService:Create(tornado,
        TweenInfo.new(10, Enum.EasingStyle.Linear),
        {Position = center + Vector3.new(-80, 30, 0)}
    )
    tween:Play()

    -- Suction loop — runs parallel to the main loop
    local tornadoActive = true
    task.spawn(function()
        while tornadoActive do
            task.wait(0.1)
            if not tornado or not tornado.Parent then break end
            for _, player in ipairs(getAllPlayers()) do
                local char = player.Character
                if char and char:FindFirstChild("HumanoidRootPart") then
                    local hrp = char.HumanoidRootPart
                    local dist = (hrp.Position - tornado.Position).Magnitude
                    if dist < 40 and dist > 2 then
                        local dir = (tornado.Position - hrp.Position).Unit
                        local strength = (1 - dist / 40) * 28
                        -- Clamp to avoid catapulting players into orbit
                        hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity + dir * strength
                    end
                    -- Touch = instant lethal throw
                    if dist < 8 then
                        local humanoid = char:FindFirstChild("Humanoid")
                        if humanoid then humanoid.Health = 0 end
                    end
                end
            end
        end
    end)

    local elapsed = 0
    while elapsed < 20 do
        task.wait(0.4)
        elapsed = elapsed + 0.4

        for _, part in ipairs(parts) do
            if part.Anchored then
                local dist = (part.Position - tornado.Position).Magnitude
                if dist < 25 and math.random(1, 100) <= 20 then
                    local dir = (part.Position - tornado.Position).Unit
                    breakPart(part, Vector3.new(
                        dir.X * math.random(20, 50),
                        math.random(10, 40),
                        dir.Z * math.random(20, 50)
                    ), 12)
                end
            end
        end
    end

    tornadoActive = false
    tornado:Destroy()
end

-- ============================================
-- 🌊 FLOOD  —  60-second vertical survival
-- ============================================
function DisasterManager.Flood()
    local center = getMapCenter()
    local parts = getBreakableParts()

    local water = Instance.new("Part")
    water.Name = "FloodWater"
    water.Size = Vector3.new(400, 2, 400)
    water.Position = Vector3.new(center.X, center.Y - 20, center.Z)
    water.Anchored = true
    water.CanCollide = true
    water.Material = Enum.Material.Water
    water.Color = Color3.fromRGB(0, 100, 200)
    water.Transparency = 0.4
    water.Parent = workspace

    -- Water rises 55 studs over 60 seconds (center.Y-20 to center.Y+35)
    local tween = TweenService:Create(water,
        TweenInfo.new(60, Enum.EasingStyle.Linear),
        {Position = Vector3.new(center.X, center.Y + 35, center.Z)}
    )
    tween:Play()

    local elapsed = 0
    while elapsed < 60 do
        task.wait(1)
        elapsed = elapsed + 1

        for _, part in ipairs(parts) do
            if part.Anchored and part.Position.Y < water.Position.Y then
                if math.random(1, 100) <= 15 then
                    breakPart(part, Vector3.new(
                        math.random(-20, 20),
                        math.random(5, 20),
                        math.random(-20, 20)
                    ), 15)
                end
            end
        end

        for _, player in ipairs(getAllPlayers()) do
            local char = player.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                if char.HumanoidRootPart.Position.Y < water.Position.Y then
                    damagePlayer(player, 8)
                end
            end
        end
    end

    water:Destroy()
end

-- ============================================
-- ☄️ METEOR STRIKE  —  ground warning circles
-- ============================================
function DisasterManager.Meteor()
    local center = getMapCenter()
    local parts = getBreakableParts()

    local function spawnMeteor()
        local offsetX = math.random(-70, 70)
        local offsetZ = math.random(-70, 70)
        local landPos = Vector3.new(center.X + offsetX, center.Y, center.Z + offsetZ)

        -- Red warning circle on the ground
        local marker = spawnWarningMarker(landPos, 10, Color3.fromRGB(255, 40, 0), 3)
        -- Whistle sound effect via event
        DisasterEvent:FireAllClients("meteorWarning", {x = landPos.X, z = landPos.Z})

        task.wait(1.5)  -- Warning period
        if marker and marker.Parent then marker:Destroy() end

        local meteor = Instance.new("Part")
        meteor.Name = "Meteor"
        meteor.Shape = Enum.PartType.Ball
        meteor.Size = Vector3.new(8, 8, 8)
        meteor.Position = landPos + Vector3.new(0, 130, 0)
        meteor.Anchored = true
        meteor.Material = Enum.Material.Plastic
        meteor.Color = Color3.fromRGB(200, 80, 20)
        meteor.Parent = workspace

        local glow = Instance.new("PointLight")
        glow.Brightness = 5
        glow.Range = 20
        glow.Color = Color3.fromRGB(255, 100, 0)
        glow.Parent = meteor

        local tween = TweenService:Create(meteor,
            TweenInfo.new(2.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {Position = landPos}
        )
        tween:Play()
        tween.Completed:Connect(function()
            local explosion = Instance.new("Explosion")
            explosion.Position = landPos
            explosion.BlastRadius = 18
            explosion.BlastPressure = 400000
            explosion.Parent = workspace

            for _, part in ipairs(parts) do
                if part.Anchored then
                    local dist = (part.Position - landPos).Magnitude
                    if dist < 25 and math.random(1, 100) <= 40 then
                        local dir = (part.Position - landPos).Unit
                        breakPart(part, Vector3.new(
                            dir.X * math.random(30, 80),
                            math.random(20, 60),
                            dir.Z * math.random(30, 80)
                        ), 12)
                    end
                end
            end

            for i = 1, 4 do
                createFire(landPos + Vector3.new(
                    math.random(-10, 10), 1, math.random(-10, 10)
                ), 15)
            end

            meteor:Destroy()
        end)
    end

    for i = 1, 10 do
        task.spawn(spawnMeteor)
        task.wait(1.8)
    end
end

-- ============================================
-- ⚡ LIGHTNING STORM  —  prediction markers
-- ============================================
function DisasterManager.Lightning()
    local center = getMapCenter()
    local parts = getBreakableParts()

    for i = 1, 15 do
        task.wait(1.2)
        local offsetX = math.random(-70, 70)
        local offsetZ = math.random(-70, 70)
        local strikePos = Vector3.new(center.X + offsetX, center.Y, center.Z + offsetZ)

        -- Yellow prediction marker, 1 second before strike
        local marker = spawnWarningMarker(strikePos, 6, Color3.fromRGB(255, 255, 0), 1.2)
        DisasterEvent:FireAllClients("lightningWarning", {x = strikePos.X, z = strikePos.Z})

        task.wait(1.0)
        if marker and marker.Parent then marker:Destroy() end

        local bolt = Instance.new("Part")
        bolt.Name = "Lightning"
        bolt.Size = Vector3.new(1, 100, 1)
        bolt.Position = strikePos + Vector3.new(0, 50, 0)
        bolt.Anchored = true
        bolt.CanCollide = false
        bolt.Material = Enum.Material.Neon
        bolt.Color = Color3.fromRGB(255, 255, 100)
        bolt.Parent = workspace
        Debris:AddItem(bolt, 0.15)

        for _, part in ipairs(parts) do
            if part.Anchored then
                local dist = (part.Position - strikePos).Magnitude
                if dist < 15 and math.random(1, 100) <= 10 then
                    breakPart(part, Vector3.new(
                        math.random(-30, 30),
                        math.random(15, 45),
                        math.random(-30, 30)
                    ), 10)
                end
            end
        end

        if math.random(1, 100) <= 30 then
            createFire(strikePos + Vector3.new(0, 1, 0), 10)
        end

        for _, player in ipairs(getAllPlayers()) do
            local char = player.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local dist = (char.HumanoidRootPart.Position - strikePos).Magnitude
                if dist < 14 then
                    damagePlayer(player, 35)
                end
            end
        end
    end
end

-- ============================================
-- 🌋 VOLCANIC ERUPTION  —  expanding lava rings
-- ============================================
function DisasterManager.Volcano()
    local center = getMapCenter()
    local parts = getBreakableParts()

    local function spawnLavaBomb()
        local offsetX = math.random(-80, 80)
        local offsetZ = math.random(-80, 80)
        local landPos = Vector3.new(center.X + offsetX, center.Y, center.Z + offsetZ)

        local bomb = Instance.new("Part")
        bomb.Name = "LavaBomb"
        bomb.Shape = Enum.PartType.Ball
        bomb.Size = Vector3.new(6, 6, 6)
        bomb.Position = Vector3.new(center.X, center.Y + 100, center.Z)
        bomb.Anchored = false
        bomb.Material = Enum.Material.Neon
        bomb.Color = Color3.fromRGB(255, 100, 0)
        bomb.Parent = workspace

        local lavFire = Instance.new("Fire")
        lavFire.Size = 5
        lavFire.Heat = 8
        lavFire.Color = Color3.fromRGB(255, 80, 0)
        lavFire.SecondaryColor = Color3.fromRGB(180, 40, 0)
        lavFire.Parent = bomb

        bomb.AssemblyLinearVelocity = Vector3.new(offsetX * 1.8, math.random(60, 100), offsetZ * 1.8)

        task.delay(4, function()
            if not bomb or not bomb.Parent then return end
            local pos = bomb.Position

            local explosion = Instance.new("Explosion")
            explosion.Position = pos
            explosion.BlastRadius = 22
            explosion.BlastPressure = 600000
            explosion.Parent = workspace

            for _, part in ipairs(parts) do
                if part.Anchored then
                    local dist = (part.Position - pos).Magnitude
                    if dist < 28 and math.random(1, 100) <= 50 then
                        local dir = (part.Position - pos).Unit
                        breakPart(part, Vector3.new(
                            dir.X * math.random(40, 90),
                            math.random(30, 70),
                            dir.Z * math.random(40, 90)
                        ), 14)
                    end
                end
            end

            for i = 1, 5 do
                createFire(pos + Vector3.new(math.random(-12, 12), 1, math.random(-12, 12)), 18)
            end

            bomb:Destroy()
        end)
    end

    -- Lava bombs phase (first 15s)
    for i = 1, 12 do
        task.spawn(spawnLavaBomb)
        task.wait(1.2)
    end

    -- Expanding lava rings phase — 3 rings expanding from center
    task.wait(2)
    for ringIdx = 1, 3 do
        task.spawn(function()
            task.wait((ringIdx - 1) * 2.5)
            local ring = Instance.new("Part")
            ring.Name = "LavaRing"
            ring.Shape = Enum.PartType.Cylinder
            ring.Size = Vector3.new(0.8, 10, 10)
            ring.CFrame = CFrame.new(center.X, center.Y + 0.5, center.Z) * CFrame.Angles(0, 0, math.pi / 2)
            ring.Anchored = true
            ring.CanCollide = false
            ring.Material = Enum.Material.Neon
            ring.Color = Color3.fromRGB(255, 60, 0)
            ring.Transparency = 0.2
            ring.Parent = workspace

            local lavRingFire = Instance.new("Fire")
            lavRingFire.Size = 6
            lavRingFire.Heat = 12
            lavRingFire.Parent = ring

            -- Damage players who touch the ring
            local ringConn
            ringConn = ring.Touched:Connect(function(hit)
                local char = hit.Parent
                local humanoid = char and char:FindFirstChild("Humanoid")
                if humanoid and humanoid.Health > 0 then
                    humanoid:TakeDamage(20)
                end
            end)

            -- Expand from 10 to 80 studs over 8 seconds
            TweenService:Create(ring,
                TweenInfo.new(8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                {Size = Vector3.new(0.8, 80, 80)}
            ):Play()

            task.wait(8)
            ringConn:Disconnect()
            if ring and ring.Parent then ring:Destroy() end
        end)
    end

    task.wait(12)  -- Wait for rings to finish
end

-- ============================================
-- ❄️ BLIZZARD  —  fog + cold damage when still
-- ============================================
function DisasterManager.Blizzard()
    local center = getMapCenter()
    local parts = getBreakableParts()

    local ice = Instance.new("Part")
    ice.Name = "IceLayer"
    ice.Size = Vector3.new(300, 0.5, 300)
    ice.Position = Vector3.new(center.X, center.Y + 0.3, center.Z)
    ice.Anchored = true
    ice.Material = Enum.Material.Ice
    ice.Color = Color3.fromRGB(180, 220, 255)
    ice.Transparency = 0.3
    ice.Parent = workspace

    local snowEmitter = Instance.new("Part")
    snowEmitter.Name = "BlizzardSnow"
    snowEmitter.Size = Vector3.new(300, 1, 300)
    snowEmitter.Position = Vector3.new(center.X, center.Y + 60, center.Z)
    snowEmitter.Anchored = true
    snowEmitter.CanCollide = false
    snowEmitter.Transparency = 1
    snowEmitter.Parent = workspace
    local snow = Instance.new("ParticleEmitter")
    snow.Color = ColorSequence.new(Color3.fromRGB(220, 235, 255))
    snow.Size = NumberSequence.new(0.25)
    snow.Speed = NumberRange.new(20, 40)
    snow.Rate = 200
    snow.SpreadAngle = Vector2.new(180, 180)
    snow.Parent = snowEmitter
    Debris:AddItem(snowEmitter, 55)

    -- Signal clients to apply blizzard fog (near-zero visibility)
    DisasterEvent:FireAllClients("fog", {near = 0, far = 280, r = 200, g = 215, b = 255, duration = 55})

    local windDir = Vector3.new(1, 0, 0)
    local elapsed = 0

    breakPercentage(parts, 5, function(part)
        return Vector3.new(math.random(10, 30), math.random(5, 20), math.random(-10, 10))
    end, 12)

    -- Track last-known positions to detect stillness (cold damage)
    local lastPositions = {}

    while elapsed < 50 do
        task.wait(0.3)
        elapsed = elapsed + 0.3
        for _, player in ipairs(getAllPlayers()) do
            local char = player.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local hrp = char.HumanoidRootPart
                -- Wind push
                hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity + windDir * 10

                local uid = player.UserId
                local currPos = hrp.Position

                -- Cold damage if player is barely moving (still in blizzard = freeze)
                if lastPositions[uid] then
                    local moved = (currPos - lastPositions[uid]).Magnitude
                    if moved < 1.5 then
                        damagePlayer(player, 3)
                    end
                end
                lastPositions[uid] = currPos

                -- Standard cold exposure damage outdoors
                if currPos.Y > center.Y + 5 then
                    if elapsed % 2 < 0.35 then
                        damagePlayer(player, 2)
                    end
                end
            end
        end
    end

    -- Clear fog on all clients
    DisasterEvent:FireAllClients("fog", {near = 0, far = 10000, r = 199, g = 170, b = 120, duration = 3})
    ice:Destroy()
end

-- ============================================
-- 🏔️ EARTHQUAKE  —  collapsing platforms
-- ============================================
function DisasterManager.Earthquake()
    local RunService = game:GetService("RunService")
    local map = workspace:FindFirstChild("CurrentMap") or workspace:FindFirstChild("Model")
    local parts = getBreakableParts()
    local elapsed = 0

    -- Flag anchored "platform" parts (flat, walkable) for collapse
    local platforms = {}
    for _, part in ipairs(parts) do
        if part.Size.X > 8 and part.Size.Z > 8 and part.Size.Y < 4 then
            table.insert(platforms, part)
        end
    end

    local shakeConn = RunService.Heartbeat:Connect(function(dt)
        elapsed = elapsed + dt

        if map then
            map:PivotTo(map:GetPivot() * CFrame.new(
                math.random(-3, 3), 0, math.random(-3, 3)
            ))
        end

        if elapsed % 4 < 0.2 then
            -- Standard debris collapse
            for _, part in ipairs(parts) do
                if part.Anchored and math.random(1, 100) <= 70 then
                    breakPart(part, Vector3.new(
                        math.random(-40, 40),
                        math.random(10, 50),
                        math.random(-40, 40)
                    ), 15)
                end
            end
        end

        -- Collapse random platforms with a tilt-then-fall
        if elapsed % 6 < 0.2 and #platforms > 0 then
            local idx = math.random(1, #platforms)
            local platform = platforms[idx]
            table.remove(platforms, idx)
            if platform and platform.Parent and platform.Anchored then
                task.spawn(function()
                    -- Tilt warning
                    TweenService:Create(platform,
                        TweenInfo.new(0.8, Enum.EasingStyle.Quad),
                        {CFrame = platform.CFrame * CFrame.Angles(
                            math.rad(math.random(-15, 15)),
                            0,
                            math.rad(math.random(-15, 15))
                        )}
                    ):Play()
                    task.wait(0.9)
                    -- Fall
                    if platform and platform.Parent then
                        breakPart(platform, Vector3.new(
                            math.random(-20, 20),
                            math.random(-5, 10),
                            math.random(-20, 20)
                        ), 15)
                    end
                end)
            end
        end

        if elapsed % 2 < 0.2 then
            for _, player in ipairs(getAllPlayers()) do
                damagePlayer(player, 6)
            end
        end
    end)

    task.delay(30, function()
        shakeConn:Disconnect()
    end)
end

-- ============================================
-- 🌊 TSUNAMI  —  5-second siren + big wave
-- ============================================
function DisasterManager.Tsunami()
    local center = getMapCenter()
    local parts = getBreakableParts()

    -- 5-second siren warning before the wave arrives
    DisasterEvent:FireAllClients("tsunamiWarning", {})
    task.wait(5)

    local wave = Instance.new("Part")
    wave.Name = "TsunamiWave"
    wave.Size = Vector3.new(12, 60, 500)
    wave.Position = Vector3.new(center.X - 180, center.Y + 30, center.Z)
    wave.Anchored = true
    wave.Material = Enum.Material.Water
    wave.Color = Color3.fromRGB(0, 80, 180)
    wave.Transparency = 0.25
    wave.Parent = workspace

    local foam = Instance.new("ParticleEmitter")
    foam.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
    foam.Size = NumberSequence.new(2)
    foam.Speed = NumberRange.new(5, 15)
    foam.Rate = 80
    foam.SpreadAngle = Vector2.new(30, 30)
    foam.Parent = wave

    local tween = TweenService:Create(wave,
        TweenInfo.new(7, Enum.EasingStyle.Linear),
        {Position = Vector3.new(center.X + 180, center.Y + 30, center.Z)}
    )
    tween:Play()

    local elapsed = 0
    while elapsed < 7 do
        task.wait(0.3)
        elapsed = elapsed + 0.3

        for _, part in ipairs(parts) do
            if part.Anchored then
                local dist = math.abs(part.Position.X - wave.Position.X)
                if dist < 20 and math.random(1, 100) <= 35 then
                    breakPart(part, Vector3.new(
                        math.random(30, 80),
                        math.random(10, 40),
                        math.random(-20, 20)
                    ), 12)
                end
            end
        end

        for _, player in ipairs(getAllPlayers()) do
            local char = player.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local hrp = char.HumanoidRootPart
                local dist = math.abs(hrp.Position.X - wave.Position.X)
                if dist < 18 then
                    -- Instant death if below wave height
                    if hrp.Position.Y < center.Y + 50 then
                        local humanoid = char:FindFirstChild("Humanoid")
                        if humanoid then humanoid.Health = 0 end
                    end
                    hrp.AssemblyLinearVelocity = Vector3.new(
                        70, math.random(20, 50), math.random(-20, 20)
                    )
                end
            end
        end
    end

    wave:Destroy()
end

-- ============================================
-- ☠️ ACID RAIN  —  shelter mechanic
-- ============================================
function DisasterManager.AcidRain()
    local center = getMapCenter()
    local parts = getBreakableParts()
    local elapsed = 0

    while elapsed < 60 do
        task.wait(0.5)
        elapsed = elapsed + 0.5

        for _, part in ipairs(parts) do
            if part.Anchored and math.random(1, 100) <= 3 then
                part.Size = part.Size * 0.97
                if part.Size.Y < 0.3 then
                    breakPart(part, Vector3.new(
                        math.random(-15, 15),
                        math.random(5, 20),
                        math.random(-15, 15)
                    ), 8)
                end
            end
        end

        -- Acid drops
        for i = 1, 4 do
            local drop = Instance.new("Part")
            drop.Name = "AcidDrop"
            drop.Shape = Enum.PartType.Ball
            drop.Size = Vector3.new(1.2, 1.2, 1.2)
            drop.Position = Vector3.new(
                center.X + math.random(-80, 80),
                center.Y + 70,
                center.Z + math.random(-80, 80)
            )
            drop.Anchored = false
            drop.Material = Enum.Material.Neon
            drop.Color = Color3.fromRGB(80, 255, 30)
            drop.Parent = workspace

            local dropConn
            dropConn = drop.Touched:Connect(function(hit)
                local char = hit.Parent
                local humanoid = char and char:FindFirstChild("Humanoid")
                if humanoid then
                    humanoid:TakeDamage(12)
                    dropConn:Disconnect()
                    drop:Destroy()
                end
            end)
            task.delay(6, function()
                dropConn:Disconnect()
            end)
            Debris:AddItem(drop, 6)
        end

        -- Shelter check: damage players outdoors (no roof above them)
        for _, player in ipairs(getAllPlayers()) do
            local char = player.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local hrp = char.HumanoidRootPart
                -- Raycast straight up to check for shelter
                local rayOrigin = hrp.Position
                local rayDir = Vector3.new(0, 50, 0)
                local raycastParams = RaycastParams.new()
                raycastParams.FilterType = Enum.RaycastFilterType.Exclude
                raycastParams.FilterDescendantsInstances = {char}
                local result = workspace:Raycast(rayOrigin, rayDir, raycastParams)
                -- No roof above = take acid damage
                if not result then
                    damagePlayer(player, 5)
                end
            end
        end
    end
end

-- ============================================
-- 🏜️ SANDSTORM  —  slow + vision reduction
-- ============================================
function DisasterManager.Sandstorm()
    local parts = getBreakableParts()
    local windDir = Vector3.new(1, 0, 0)
    local elapsed = 0

    -- Slow all players by 30%
    local function setAllWalkSpeed(speed)
        for _, player in ipairs(getAllPlayers()) do
            local char = player.Character
            if char and char:FindFirstChild("Humanoid") then
                char.Humanoid.WalkSpeed = speed
            end
        end
    end
    setAllWalkSpeed(11)  -- 16 * 0.7

    -- Signal clients for sandy fog
    DisasterEvent:FireAllClients("fog", {near = 0, far = 150, r = 200, g = 170, b = 100, duration = 45})

    breakPercentage(parts, 8, function(part)
        return Vector3.new(math.random(20, 50), math.random(5, 25), math.random(-10, 10))
    end, 10)

    while elapsed < 40 do
        task.wait(0.2)
        elapsed = elapsed + 0.2
        for _, player in ipairs(getAllPlayers()) do
            local char = player.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local hrp = char.HumanoidRootPart
                hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity + windDir * 14
                if elapsed % 3 < 0.25 then
                    damagePlayer(player, 4)
                end
            end
        end
    end

    -- Restore WalkSpeed
    setAllWalkSpeed(16)
    -- Clear fog
    DisasterEvent:FireAllClients("fog", {near = 0, far = 10000, r = 199, g = 170, b = 120, duration = 3})
end

-- ============================================
-- 🎯 Run disaster
-- ============================================
local disasterMap = {
    ["Tornado"]           = DisasterManager.Tornado,
    ["Flood"]             = DisasterManager.Flood,
    ["Meteor Strike"]     = DisasterManager.Meteor,
    ["Lightning Storm"]   = DisasterManager.Lightning,
    ["Volcanic Eruption"] = DisasterManager.Volcano,
    ["Blizzard"]          = DisasterManager.Blizzard,
    ["Earthquake"]        = DisasterManager.Earthquake,
    ["Tsunami"]           = DisasterManager.Tsunami,
    ["Acid Rain"]         = DisasterManager.AcidRain,
    ["Sandstorm"]         = DisasterManager.Sandstorm,
}

function DisasterManager.Run(disasterName)
    local fn = disasterMap[disasterName]
    if fn then
        dprint("Running disaster:", disasterName)
        task.wait(3)
        DisasterEvent:FireAllClients(disasterName)
        task.spawn(fn)
    else
        warn("❌ Unknown disaster: " .. disasterName)
    end
end

function DisasterManager.cleanupDisasters()
    local names = {
        FloodWater=true, TsunamiWave=true, IceLayer=true, Tornado=true,
        FirePart=true, LavaBomb=true, Meteor=true, AcidDrop=true, Lightning=true,
        WarningMarker=true, LavaRing=true, BlizzardSnow=true
    }
    for _, child in ipairs(workspace:GetDescendants()) do
        if names[child.Name] and child.Parent then
            pcall(function() child:Destroy() end)
        end
    end
    -- Clear all client visual effects
    DisasterEvent:FireAllClients("clearEffects")
    -- Restore WalkSpeed in case Sandstorm didn't finish cleanly
    for _, player in ipairs(Players:GetPlayers()) do
        local char = player.Character
        if char and char:FindFirstChild("Humanoid") then
            char.Humanoid.WalkSpeed = 16
        end
    end
end

return DisasterManager
