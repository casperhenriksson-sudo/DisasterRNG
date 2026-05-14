-- AuraReveal: visual effect when equipping a Rare+ item
-- Shows BillboardGui above HumanoidRootPart and radiating GUI particles.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local localPlayer       = Players.LocalPlayer
local EquipUpdateEvent  = ReplicatedStorage:WaitForChild("EquipUpdateEvent")

-- RARE_PLUS list (mirrors QuestData.RARE_PLUS — server-validated)
local RARE_PLUS = {"Rare","Epic","Legendary","Mythical","Divine","Corrupted","Celestial","Secret"}

local RARITY_COLORS = {
    Rare        = Color3.fromRGB(85,  170, 255),
    Epic        = Color3.fromRGB(170, 85,  255),
    Legendary   = Color3.fromRGB(255, 170, 0  ),
    Mythical    = Color3.fromRGB(255, 50,  50 ),
    Divine      = Color3.fromRGB(100, 220, 255),
    Corrupted   = Color3.fromRGB(80,  255, 80 ),
    Celestial   = Color3.fromRGB(255, 255, 120),
    Secret      = Color3.fromRGB(255, 20,  147),
}

local function isRarePlus(rarity)
    for _, r in ipairs(RARE_PLUS) do
        if r == rarity then return true end
    end
    return false
end

-- ── BillboardGui above HRP ────────────────────────────────────────────────────
local function showBillboard(character, rarity, color)
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Size              = UDim2.new(0, 160, 0, 36)
    billboard.StudsOffset       = Vector3.new(0, 4, 0)
    billboard.AlwaysOnTop       = false
    billboard.Adornee           = hrp
    billboard.Parent            = hrp

    local label = Instance.new("TextLabel")
    label.Size                   = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3             = color
    label.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
    label.TextStrokeTransparency = 0.4
    label.TextScaled             = true
    label.Font                   = Enum.Font.GothamBold
    label.Text                   = rarity .. " EQUIPPED"
    label.Parent                 = billboard

    -- Fade out and destroy after 2s
    task.delay(1.5, function()
        TweenService:Create(label, TweenInfo.new(0.5), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
        task.delay(0.5, function()
            billboard:Destroy()
        end)
    end)
end

-- ── Radiating GUI particles (8 ImageLabels from screen center) ───────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "AuraRevealGui"
screenGui.ResetOnSpawn   = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset = true
screenGui.Parent         = localPlayer.PlayerGui

local function spawnParticles(color)
    local CENTER = UDim2.new(0.5, 0, 0.5, 0)
    local PARTICLE_COUNT = 8
    local TRAVEL = 180  -- pixels of travel

    for i = 1, PARTICLE_COUNT do
        local angle = (i - 1) * (360 / PARTICLE_COUNT)
        local rad   = math.rad(angle)
        local dx    = math.cos(rad) * TRAVEL
        local dy    = math.sin(rad) * TRAVEL

        local dot = Instance.new("Frame")
        dot.Size                   = UDim2.new(0, 14, 0, 14)
        dot.AnchorPoint            = Vector2.new(0.5, 0.5)
        dot.Position               = CENTER
        dot.BackgroundColor3       = color
        dot.BackgroundTransparency = 0
        dot.BorderSizePixel        = 0
        dot.ZIndex                 = 10
        dot.Parent                 = screenGui

        local dotCorner = Instance.new("UICorner")
        dotCorner.CornerRadius = UDim.new(1, 0)
        dotCorner.Parent       = dot

        -- Radiate outward
        local target = UDim2.new(0.5, dx, 0.5, dy)
        TweenService:Create(dot, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position               = target,
            BackgroundTransparency = 1,
            Size                   = UDim2.new(0, 4, 0, 4),
        }):Play()

        task.delay(0.6, function()
            dot:Destroy()
        end)
    end
end

-- ── Wire to EquipUpdateEvent ──────────────────────────────────────────────────
EquipUpdateEvent.OnClientEvent:Connect(function(equippedPlayer, itemName, rarityName)
    -- Only trigger for local player
    if equippedPlayer ~= localPlayer then return end
    if not itemName or not rarityName then return end
    if not isRarePlus(rarityName) then return end

    local color = RARITY_COLORS[rarityName] or Color3.fromRGB(255, 255, 255)

    -- Show billboard on character if loaded
    local char = localPlayer.Character
    if char then
        showBillboard(char, rarityName, color)
    end

    -- Spawn screen particles
    spawnParticles(color)
end)
