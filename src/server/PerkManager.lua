local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PerkEvent = ReplicatedStorage:WaitForChild("PerkEvent")

local PerkManager = {}

-- Active perks per player during round
local activePerkData = {}

-- Cooldowns
local cooldowns = {}

-- ============================================
-- 🔧 HELPER FUNCTIONS
-- ============================================

local function getChar(player)
    return player.Character
end

local function getHRP(player)
    local char = getChar(player)
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid(player)
    local char = getChar(player)
    return char and char:FindFirstChild("Humanoid")
end

local function hasCooldown(player, perkName)
    local key = player.UserId .. perkName
    return cooldowns[key] == true
end

local function setCooldown(player, perkName, duration)
    local key = player.UserId .. perkName
    cooldowns[key] = true
    task.delay(duration, function()
        cooldowns[key] = nil
    end)
end

-- ============================================
-- 🎯 PASSIVE PERKS (activated automatically)
-- ============================================

local passivePerks = {}

-- Sturdy – less easily blown away
passivePerks["Sturdy"] = function(player)
    local hrp = getHRP(player)
    if not hrp then return end
    -- Increase mass
    local bv = Instance.new("BodyVelocity")
    bv.Name = "StadigForce"
    bv.MaxForce = Vector3.new(1000, 0, 1000)
    bv.Velocity = Vector3.new(0, 0, 0)
    bv.Parent = hrp
end

-- Soft Landing – no fall damage
passivePerks["SoftLanding"] = function(player)
    local humanoid = getHumanoid(player)
    if humanoid then
        humanoid.AutoJumpEnabled = true
        -- Reset fall damage via state
        humanoid.StateChanged:Connect(function(old, new)
            if new == Enum.HumanoidStateType.Landed then
                humanoid.Health = math.min(humanoid.Health + 10, humanoid.MaxHealth)
            end
        end)
    end
end

-- Tough – survives one extra hit
passivePerks["Tough"] = function(player)
    local humanoid = getHumanoid(player)
    if not humanoid then return end
    local blocked = false
    humanoid.HealthChanged:Connect(function(health)
        if health <= 0 and not blocked then
            blocked = true
            humanoid.Health = 1
            task.delay(0.1, function()
                -- Once per round
            end)
        end
    end)
end

-- WaterLegs – no damage underwater
passivePerks["WaterLegs"] = function(player)
    activePerkData[player.UserId] = activePerkData[player.UserId] or {}
    activePerkData[player.UserId].waterImmune = true
end

-- QuickFeet – runs 15% faster
passivePerks["QuickFeet"] = function(player)
    local humanoid = getHumanoid(player)
    if humanoid then
        humanoid.WalkSpeed = humanoid.WalkSpeed * 1.15
    end
end

-- LowProfile – disasters target you slightly less
passivePerks["LowProfile"] = function(player)
    activePerkData[player.UserId] = activePerkData[player.UserId] or {}
    activePerkData[player.UserId].lowProfile = true
end

-- FireImmune – takes no fire damage
passivePerks["FireImmune"] = function(player)
    activePerkData[player.UserId] = activePerkData[player.UserId] or {}
    activePerkData[player.UserId].fireImmune = true
end

-- Magnetic – not pulled toward water
passivePerks["Magnetic"] = function(player)
    activePerkData[player.UserId] = activePerkData[player.UserId] or {}
    activePerkData[player.UserId].waterRepel = true
end

-- Featherweight – halved gravity
passivePerks["Featherweight"] = function(player)
    local hrp = getHRP(player)
    if not hrp then return end
    local bg = Instance.new("BodyForce")
    bg.Name = "LightForce"
    bg.Force = Vector3.new(0, workspace.Gravity * hrp.AssemblyMass * 0.5, 0)
    bg.Parent = hrp
end

-- DoubleLife – survives one fatal hit
passivePerks["DoubleLife"] = function(player)
    local humanoid = getHumanoid(player)
    if not humanoid then return end
    local used = false
    local conn
    conn = humanoid.HealthChanged:Connect(function(health)
        if health <= 5 and not used then
            used = true
            humanoid.Health = humanoid.MaxHealth * 0.3
            PerkEvent:FireClient(player, "notification", "💚 Double Life activated!")
            conn:Disconnect()
        end
    end)
end

-- QuickRevive – gets up twice as fast
passivePerks["QuickRevive"] = function(player)
    activePerkData[player.UserId] = activePerkData[player.UserId] or {}
    activePerkData[player.UserId].fastRecover = true
end

-- DisasterSense – sees next disaster 3 sec early
passivePerks["DisasterSense"] = function(player)
    activePerkData[player.UserId] = activePerkData[player.UserId] or {}
    activePerkData[player.UserId].earlyWarning = true
end

-- EchoShield – nearest ally shares your buff
passivePerks["EchoShield"] = function(player)
    activePerkData[player.UserId] = activePerkData[player.UserId] or {}
    activePerkData[player.UserId].echoShield = true
end

-- ChaosMagnet – disasters target you more, but you take double health
passivePerks["ChaosMagnet"] = function(player)
    local humanoid = getHumanoid(player)
    if humanoid then
        humanoid.MaxHealth = humanoid.MaxHealth * 2
        humanoid.Health = humanoid.MaxHealth
    end
    activePerkData[player.UserId] = activePerkData[player.UserId] or {}
    activePerkData[player.UserId].chaosTarget = true
end

-- ContagiousCurse – bad luck spreads to nearest player
passivePerks["ContagiousCurse"] = function(player)
    activePerkData[player.UserId] = activePerkData[player.UserId] or {}
    activePerkData[player.UserId].contagious = true
end

-- CosmicAura – allies near you gain an Uncommon perk
passivePerks["CosmicAura"] = function(player)
    activePerkData[player.UserId] = activePerkData[player.UserId] or {}
    activePerkData[player.UserId].cosmicAura = true
end

-- SemiTransparent – 30% chance disasters miss
passivePerks["SemiTransparent"] = function(player)
    activePerkData[player.UserId] = activePerkData[player.UserId] or {}
    activePerkData[player.UserId].ghostChance = 0.3
end

-- ============================================
-- ⚡ ACTIVE PERKS (button press)
-- Cooldown in seconds
-- ============================================

local activePerks = {}

-- SmokeBomb – hides you for 3 sec (30s cooldown)
activePerks["SmokeBomb"] = {
    cooldown = 30,
    description = "Hides you for 3 seconds",
    activate = function(player)
        local char = getChar(player)
        if not char then return end
        for _, part in ipairs(char:GetChildren()) do
            if part:IsA("BasePart") then
                part.Transparency = 0.8
            end
        end
        PerkEvent:FireClient(player, "notification", "💨 Smoke Bomb activated!")
        task.wait(3)
        for _, part in ipairs(char:GetChildren()) do
            if part:IsA("BasePart") then
                part.Transparency = 0
            end
        end
    end
}

-- TeleportDash – short teleport (20s cooldown)
activePerks["TeleportDash"] = {
    cooldown = 20,
    description = "Teleports you forward",
    activate = function(player)
        local hrp = getHRP(player)
        if not hrp then return end
        local forward = hrp.CFrame.LookVector * 30
        hrp.CFrame = hrp.CFrame + forward
        PerkEvent:FireClient(player, "notification", "⚡ Teleport!")
    end
}

-- TimeBubble – freezes you for 2 sec (45s cooldown)
activePerks["TimeBubble"] = {
    cooldown = 45,
    description = "Freezes you for 2 seconds",
    activate = function(player)
        local hrp = getHRP(player)
        local humanoid = getHumanoid(player)
        if not hrp or not humanoid then return end
        local pos = hrp.CFrame
        hrp.Anchored = true
        humanoid.WalkSpeed = 0
        PerkEvent:FireClient(player, "notification", "⏸ Time Bubble activated!")
        task.wait(2)
        hrp.Anchored = false
        humanoid.WalkSpeed = 16
    end
}

-- MirrorShield – reflects the next projectile (60s cooldown)
activePerks["MirrorShield"] = {
    cooldown = 60,
    description = "Reflects the next projectile",
    activate = function(player)
        activePerkData[player.UserId] = activePerkData[player.UserId] or {}
        activePerkData[player.UserId].mirrorShield = true
        PerkEvent:FireClient(player, "notification", "🪞 Mirror Shield active!")
        task.delay(10, function()
            if activePerkData[player.UserId] then
                activePerkData[player.UserId].mirrorShield = nil
            end
        end)
    end
}

-- Cloned – creates a dummy (40s cooldown)
activePerks["Cloned"] = {
    cooldown = 40,
    description = "Creates a clone that takes one hit",
    activate = function(player)
        local hrp = getHRP(player)
        if not hrp then return end
        local dummy = Instance.new("Part")
        dummy.Name = "Dummy_" .. player.Name
        dummy.Size = Vector3.new(2, 5, 2)
        dummy.Position = hrp.Position + hrp.CFrame.RightVector * 5
        dummy.Anchored = true
        dummy.Material = Enum.Material.Plastic
        dummy.Color = player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character.HumanoidRootPart.Color or Color3.fromRGB(255,200,150)
        dummy.Parent = workspace

        local health = 1
        dummy.Touched:Connect(function()
            health = health - 1
            if health <= 0 then dummy:Destroy() end
        end)

        PerkEvent:FireClient(player, "notification", "🪆 Clone created!")
        game:GetService("Debris"):AddItem(dummy, 15)
    end
}

-- TimeStop – freezes everything for all players for 3 sec (90s cooldown)
activePerks["TimeStop"] = {
    cooldown = 90,
    description = "Freezes everything for 3 seconds",
    activate = function(player)
        -- Temporarily freeze all loose parts
        local frozen = {}
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") and not obj.Anchored and obj.Name ~= "HumanoidRootPart" then
                obj.Anchored = true
                table.insert(frozen, obj)
            end
        end
        PerkEvent:FireAllClients("notification", "⏱ " .. player.Name .. " activated Time Stop!")
        task.wait(3)
        for _, obj in ipairs(frozen) do
            if obj and obj.Parent then
                obj.Anchored = false
            end
        end
    end
}

-- MirrorArena – reverses controls for 5 sec (50s cooldown)
activePerks["MirrorArena"] = {
    cooldown = 50,
    description = "Reverses all controls for 5 seconds",
    activate = function(player)
        PerkEvent:FireAllClients("mirrorControls", true)
        PerkEvent:FireAllClients("notification", "🪞 " .. player.Name .. " mirrored the arena!")
        task.wait(5)
        PerkEvent:FireAllClients("mirrorControls", false)
    end
}

-- GroupMind – see all players' perks (25s cooldown)
activePerks["GroupMind"] = {
    cooldown = 25,
    description = "See all players perks",
    activate = function(player)
        local info = {}
        for _, p in ipairs(Players:GetPlayers()) do
            local data = activePerkData[p.UserId]
            table.insert(info, p.Name .. ": " .. (data and data.currentPerk or "None"))
        end
        PerkEvent:FireClient(player, "showPerkInfo", info)
    end
}

-- ============================================
-- 🚀 APPLY PERK FOR PLAYER
-- ============================================

function PerkManager.ApplyPerk(player, perkName)
    activePerkData[player.UserId] = activePerkData[player.UserId] or {}
    activePerkData[player.UserId].currentPerk = perkName

    -- Passive perk
    local passive = passivePerks[perkName]
    if passive then
        task.spawn(function() passive(player) end)
    end

    -- Active perk – notify client
    local active = activePerks[perkName]
    if active then
        PerkEvent:FireClient(player, "setActivePerk", {
            name = perkName,
            description = active.description,
            cooldown = active.cooldown,
        })
    end

    print("✅ " .. player.Name .. " got perk: " .. perkName)
end

-- Listen for active perk activation from client
PerkEvent.OnServerEvent:Connect(function(player, action, data)
    if action == "activate" then
        local perkName = activePerkData[player.UserId] and activePerkData[player.UserId].currentPerk
        if not perkName then return end

        local active = activePerks[perkName]
        if not active then return end

        if hasCooldown(player, perkName) then
            PerkEvent:FireClient(player, "notification", "⏳ Perk on cooldown!")
            return
        end

        setCooldown(player, perkName, active.cooldown)
        task.spawn(function() active.activate(player) end)
    end
end)

-- Clear perks when round ends
function PerkManager.ClearPerks(player)
    local data = activePerkData[player.UserId]
    if not data then return end

    -- Reset walkspeed
    local humanoid = getHumanoid(player)
    if humanoid then
        humanoid.WalkSpeed = 16
        humanoid.MaxHealth = 100
        humanoid.Health = 100
    end

    -- Remove BodyForce/BodyVelocity
    local hrp = getHRP(player)
    if hrp then
        for _, obj in ipairs(hrp:GetChildren()) do
            if obj:IsA("BodyForce") or obj:IsA("BodyVelocity") then
                obj:Destroy()
            end
        end
    end

    activePerkData[player.UserId] = nil
    PerkEvent:FireClient(player, "clearPerk", nil)
    print("🧹 Perks cleared for " .. player.Name)
end

function PerkManager.GetData(player)
    return activePerkData[player.UserId]
end

return PerkManager
