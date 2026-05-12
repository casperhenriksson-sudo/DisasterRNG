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

-- Get all breakable parts (not ground/floor)
local function getBreakableParts()
    local map = workspace:FindFirstChild("CurrentMap") or workspace:FindFirstChild("Model")
    if not map then return {} end
    local parts = {}
    for _, part in ipairs(map:GetDescendants()) do
        if part:IsA("BasePart") and part.Anchored then
            local name = part.Name:lower()
            -- Skip ground and floor
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

-- Break a part with force
local function breakPart(part, force, lifetime)
    if not part or not part.Parent then return end
    part.Anchored = false
    part.AssemblyLinearVelocity = force
    part.AssemblyAngularVelocity = Vector3.new(
        math.random(-5, 5),
        math.random(-5, 5),
        math.random(-5, 5)
    )
    -- Damage player on collision (one-shot, disconnects after hit)
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

-- Create fire at a position
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

-- Break a random percentage of parts
local function breakPercentage(parts, percent, forceFunc, lifetime)
    for _, part in ipairs(parts) do
        if math.random(1, 100) <= percent then
            local force = forceFunc(part)
            task.spawn(function()
                task.wait(math.random() * 2) -- Small delay so it doesn't all happen at once
                breakPart(part, force, lifetime)
            end)
        end
    end
end

-- ============================================
-- 🌪️ TORNADO
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

    local elapsed = 0
    while elapsed < 20 do
        task.wait(0.4)
        elapsed = elapsed + 0.4

        -- Break 20% of parts near the tornado's position
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

        -- Damage and throw players near tornado
        for _, player in ipairs(getAllPlayers()) do
            local char = player.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local dist = (char.HumanoidRootPart.Position - tornado.Position).Magnitude
                if dist < 22 then
                    damagePlayer(player, 8)
                    local hrp = char.HumanoidRootPart
                    hrp.AssemblyLinearVelocity = Vector3.new(
                        math.random(-60, 60),
                        math.random(30, 70),
                        math.random(-60, 60)
                    )
                end
            end
        end
    end

    tornado:Destroy()
end

-- ============================================
-- 🌊 FLOOD
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

    local tween = TweenService:Create(water,
        TweenInfo.new(20, Enum.EasingStyle.Linear),
        {Position = Vector3.new(center.X, center.Y + 35, center.Z)}
    )
    tween:Play()

    local elapsed = 0
    while elapsed < 20 do
        task.wait(1)
        elapsed = elapsed + 1

        -- Break parts the water has reached
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

        -- Damage players under the water
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
-- ☄️ METEOR STRIKE + FIRE
-- ============================================
function DisasterManager.Meteor()
    local center = getMapCenter()
    local parts = getBreakableParts()

    local function spawnMeteor()
        local offsetX = math.random(-70, 70)
        local offsetZ = math.random(-70, 70)
        local landPos = Vector3.new(center.X + offsetX, center.Y, center.Z + offsetZ)

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
            -- Explosion
            local explosion = Instance.new("Explosion")
            explosion.Position = landPos
            explosion.BlastRadius = 18
            explosion.BlastPressure = 400000
            explosion.Parent = workspace

            -- Break 40% of parts near the impact
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

            -- Create fire
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
-- ⚡ LIGHTNING STORM + FIRE
-- ============================================
function DisasterManager.Lightning()
    local center = getMapCenter()
    local parts = getBreakableParts()

    for i = 1, 15 do
        task.wait(1.2)
        local offsetX = math.random(-70, 70)
        local offsetZ = math.random(-70, 70)
        local strikePos = Vector3.new(center.X + offsetX, center.Y, center.Z + offsetZ)

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

        -- Break 10% of parts near the lightning
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

        -- 30% chance of fire
        if math.random(1, 100) <= 30 then
            createFire(strikePos + Vector3.new(0, 1, 0), 10)
        end

        -- Damage nearby players
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
-- 🌋 VOLCANIC ERUPTION
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

            -- Large explosion
            local explosion = Instance.new("Explosion")
            explosion.Position = pos
            explosion.BlastRadius = 22
            explosion.BlastPressure = 600000
            explosion.Parent = workspace

            -- Break 50% of nearby parts
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

            -- Lava fire
            for i = 1, 5 do
                createFire(pos + Vector3.new(math.random(-12, 12), 1, math.random(-12, 12)), 18)
            end

            bomb:Destroy()
        end)
    end

    for i = 1, 12 do
        task.spawn(spawnLavaBomb)
        task.wait(1.2)
    end
end

-- ============================================
-- ❄️ BLIZZARD
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
    Debris:AddItem(snowEmitter, 22)

    local windDir = Vector3.new(1, 0, 0)
    local elapsed = 0

    -- Break 5% of outdoor parts (tall parts)
    breakPercentage(parts, 5, function(part)
        return Vector3.new(math.random(10, 30), math.random(5, 20), math.random(-10, 10))
    end, 12)

    while elapsed < 20 do
        task.wait(0.3)
        elapsed = elapsed + 0.3
        for _, player in ipairs(getAllPlayers()) do
            local char = player.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                -- Wind
                local hrp = char.HumanoidRootPart
                hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity + windDir * 10

                -- Damage if outdoors (high Y-position = exposed)
                local hrpY = char.HumanoidRootPart.Position.Y
                if hrpY > center.Y + 5 then
                    if elapsed % 2 < 0.35 then
                        damagePlayer(player, 4)
                    end
                end
            end
        end
    end

    ice:Destroy()
end

-- ============================================
-- 🏔️ EARTHQUAKE
-- ============================================
function DisasterManager.Earthquake()
    local RunService = game:GetService("RunService")
    local map = workspace:FindFirstChild("CurrentMap")
    local parts = getBreakableParts()
    local elapsed = 0
    local wave = 1

    -- Shake the map via Heartbeat (more efficient than task.wait-loop)
    local shakeConn = RunService.Heartbeat:Connect(function(dt)
        elapsed = elapsed + dt

        -- Shake the map every frame
        if map then
            map:PivotTo(map:GetPivot() * CFrame.new(
                math.random(-3, 3), 0, math.random(-3, 3)
            ))
        end

        -- Break parts in waves every 4 seconds
        if elapsed % 4 < 0.2 then
            for _, part in ipairs(parts) do
                if part.Anchored and math.random(1, 100) <= 70 then
                    breakPart(part, Vector3.new(
                        math.random(-40, 40),
                        math.random(10, 50),
                        math.random(-40, 40)
                    ), 15)
                end
            end
            wave = wave + 1
        end

        -- Damage players
        if elapsed % 2 < 0.2 then
            for _, player in ipairs(getAllPlayers()) do
                damagePlayer(player, 6)
            end
        end
    end)

    -- Disconnect Heartbeat after 20 seconds
    task.delay(20, function()
        shakeConn:Disconnect()
    end)
end

-- ============================================
-- 🌊 TSUNAMI
-- ============================================
function DisasterManager.Tsunami()
    local center = getMapCenter()
    local parts = getBreakableParts()

    local wave = Instance.new("Part")
    wave.Name = "TsunamiWave"
    wave.Size = Vector3.new(12, 50, 400)
    wave.Position = Vector3.new(center.X - 180, center.Y + 25, center.Z)
    wave.Anchored = true
    wave.Material = Enum.Material.Water
    wave.Color = Color3.fromRGB(0, 80, 180)
    wave.Transparency = 0.3
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
        {Position = Vector3.new(center.X + 180, center.Y + 25, center.Z)}
    )
    tween:Play()

    local elapsed = 0
    while elapsed < 7 do
        task.wait(0.3)
        elapsed = elapsed + 0.3

        -- Break 35% of parts near the wave
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

        -- Throw players
        for _, player in ipairs(getAllPlayers()) do
            local char = player.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local dist = math.abs(char.HumanoidRootPart.Position.X - wave.Position.X)
                if dist < 18 then
                    damagePlayer(player, 15)
                    local hrp = char.HumanoidRootPart
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
-- ☠️ ACID RAIN
-- ============================================
function DisasterManager.AcidRain()
    local center = getMapCenter()
    local parts = getBreakableParts()
    local elapsed = 0

    while elapsed < 20 do
        task.wait(0.5)
        elapsed = elapsed + 0.5

        -- Slowly corrodes parts (25% chance per tick)
        for _, part in ipairs(parts) do
            if part.Anchored and math.random(1, 100) <= 3 then
                -- Corrodes = shrinks the part a little
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

        -- Spawn acid drops
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
    end
end

-- ============================================
-- 🏜️ SANDSTORM
-- ============================================
function DisasterManager.Sandstorm()
    local parts = getBreakableParts()
    local windDir = Vector3.new(1, 0, 0)
    local elapsed = 0

    -- Break 8% of lightweight parts
    breakPercentage(parts, 8, function(part)
        return Vector3.new(math.random(20, 50), math.random(5, 25), math.random(-10, 10))
    end, 10)

    while elapsed < 20 do
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
end

-- ============================================
-- 🎯 Run disaster
-- ============================================
local disasterMap = {
    ["Tornado"]       = DisasterManager.Tornado,
    ["Flood"]            = DisasterManager.Flood,
    ["Meteor Strike"]   = DisasterManager.Meteor,
    ["Lightning Storm"] = DisasterManager.Lightning,
    ["Volcanic Eruption"] = DisasterManager.Volcano,
    ["Blizzard"]      = DisasterManager.Blizzard,
    ["Earthquake"]      = DisasterManager.Earthquake,
    ["Tsunami"]       = DisasterManager.Tsunami,
    ["Acid Rain"]       = DisasterManager.AcidRain,
    ["Sandstorm"]     = DisasterManager.Sandstorm,
}

function DisasterManager.Run(disasterName)
    local fn = disasterMap[disasterName]
    if fn then
        print("🌪️ Running disaster: " .. disasterName)
        RoundEvent:FireAllClients("DisasterWarning", disasterName)
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
        FirePart=true, LavaBomb=true, Meteor=true, AcidDrop=true, Lightning=true
    }
    for _, child in ipairs(workspace:GetDescendants()) do
        if names[child.Name] and child.Parent then
            pcall(function() child:Destroy() end)
        end
    end
end

return DisasterManager
