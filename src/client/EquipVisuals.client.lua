-- EquipVisuals — applies cosmetic effects to characters based on equipped item
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local EquipUpdateEvent = ReplicatedStorage:WaitForChild("EquipUpdateEvent", 15)

local RARITY_TIER = {
    Common=1,Uncommon=2,Rare=3,Epic=4,Legendary=5,Mythical=6,Divine=7,Corrupted=8,Celestial=9,Secret=10
}

local SpinData = require(ReplicatedStorage:WaitForChild("SpinData"))

-- Get item color from SpinData.Items
local function getItemColor(itemName)
    for _, items in pairs(SpinData.Items) do
        for _, item in ipairs(items) do
            if item.name == itemName then return item.color end
        end
    end
    return Color3.fromRGB(200,200,200)
end

-- Remove previous equip effects from a character
local function clearEffects(character)
    for _, child in ipairs(character:GetChildren()) do
        if child.Name == "EquipEffect" then child:Destroy() end
    end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if hrp then
        for _, child in ipairs(hrp:GetChildren()) do
            if child.Name == "EquipLight" or child.Name == "EquipParticle" then
                child:Destroy()
            end
        end
    end
end

local function applyEffect(character, itemName, rarityName)
    clearEffects(character)
    if not itemName or itemName == "" then return end

    local tier = RARITY_TIER[rarityName] or 1
    local color = getItemColor(itemName)
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- All tiers: colored point light
    local light = Instance.new("PointLight")
    light.Name = "EquipLight"
    light.Color = color
    light.Brightness = math.clamp(tier * 0.3, 0.2, 3)
    light.Range = math.clamp(tier * 4, 8, 40)
    light.Parent = hrp

    -- Tier 3+ (Rare+): particle emitter
    if tier >= 3 then
        local particle = Instance.new("ParticleEmitter")
        particle.Name = "EquipParticle"
        particle.Color = ColorSequence.new(color)
        particle.LightEmission = 0.5
        particle.LightInfluence = 0.3
        particle.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.3),
            NumberSequenceKeypoint.new(1, 0),
        })
        particle.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.3),
            NumberSequenceKeypoint.new(1, 1),
        })
        particle.Speed = NumberRange.new(1, tier * 2)
        particle.Rate = math.clamp(tier * 8, 10, 80)
        particle.Lifetime = NumberRange.new(0.5, 1.5)
        particle.SpreadAngle = Vector2.new(360, 360)
        particle.RotSpeed = NumberRange.new(-45, 45)
        particle.Parent = hrp
    end

    -- Tier 7+ (Divine+): BillboardGui aura ring
    if tier >= 7 then
        local billboard = Instance.new("BillboardGui")
        billboard.Name = "EquipEffect"
        billboard.Size = UDim2.new(0, 80, 0, 80)
        billboard.StudsOffset = Vector3.new(0, -2.5, 0)
        billboard.AlwaysOnTop = false
        billboard.Parent = hrp

        local ring = Instance.new("Frame")
        ring.Size = UDim2.fromScale(1, 1)
        ring.BackgroundTransparency = 1
        ring.Parent = billboard
        Instance.new("UICorner", ring).CornerRadius = UDim.new(1, 0)

        local stroke = Instance.new("UIStroke")
        stroke.Color = color
        stroke.Thickness = tier >= 9 and 4 or 2
        stroke.Transparency = 0.2
        stroke.Parent = ring

        -- Pulse animation
        TweenService:Create(stroke, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, math.huge, true),
            {Transparency=0.7}):Play()
    end

    -- SECRET (tier 10): extra overhead text
    if tier >= 10 then
        local billboard2 = Instance.new("BillboardGui")
        billboard2.Name = "EquipEffect"
        billboard2.Size = UDim2.new(0, 120, 0, 30)
        billboard2.StudsOffset = Vector3.new(0, 3.5, 0)
        billboard2.AlwaysOnTop = false
        billboard2.Parent = hrp

        local secretLabel = Instance.new("TextLabel")
        secretLabel.Size = UDim2.fromScale(1, 1)
        secretLabel.BackgroundTransparency = 1
        secretLabel.Font = Enum.Font.GothamBlack
        secretLabel.TextSize = 14
        secretLabel.Text = "???"
        secretLabel.TextColor3 = Color3.fromRGB(255, 240, 100)
        secretLabel.Parent = billboard2

        -- Rainbow color cycle
        task.spawn(function()
            local hue = 0
            while secretLabel.Parent do
                hue = (hue + 0.01) % 1
                secretLabel.TextColor3 = Color3.fromHSV(hue, 0.9, 1)
                task.wait(0.05)
            end
        end)
    end
end

-- Watch all players for equip updates
EquipUpdateEvent.OnClientEvent:Connect(function(equippedPlayer, itemName, rarityName)
    if not equippedPlayer then return end
    local character = equippedPlayer.Character
    if character then
        applyEffect(character, itemName, rarityName)
    end
    -- Also re-apply when character respawns
    equippedPlayer.CharacterAdded:Connect(function(newCharacter)
        task.wait(0.5)  -- Wait for character to load
        if itemName and itemName ~= "" then
            applyEffect(newCharacter, itemName, rarityName)
        end
    end)
end)

-- On initial join, apply each player's equipped item (fetched via GetData or EquipUpdate on join)
-- EquipVisuals relies on EquipUpdateEvent being fired on join by the server

print("[EquipVisuals] Loaded")
