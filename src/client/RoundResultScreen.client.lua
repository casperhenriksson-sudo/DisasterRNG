-- RoundResultScreen  (StarterPlayerScripts)
-- Shows a 5-second result overlay after each round.
-- Listens to RoundEvent "RoundResult" and "RoundStart" (for objectives).

local Players         = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService    = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local RoundEvent = ReplicatedStorage:WaitForChild("RoundEvent")

-- ── Per-disaster objective strings ─────────────────────────────────────────────
local OBJECTIVES = {
    ["Tornado"]           = "SURVIVE  ·  Run PERPENDICULAR to the vortex!",
    ["Flood"]             = "SURVIVE  ·  Climb to HIGH GROUND before the water rises!",
    ["Meteor Strike"]     = "SURVIVE  ·  Watch for RED CIRCLES — dodge the impact zones!",
    ["Lightning Storm"]   = "SURVIVE  ·  YELLOW markers appear 1 second before each strike!",
    ["Volcanic Eruption"] = "SURVIVE  ·  Lava rings EXPAND from the center — climb high!",
    ["Blizzard"]          = "SURVIVE  ·  Keep MOVING — standing still causes frostbite!",
    ["Earthquake"]        = "SURVIVE  ·  Stay on STABLE ground — platforms collapse!",
    ["Tsunami"]           = "SURVIVE  ·  Climb ABOVE 50 studs before the wave hits!",
    ["Acid Rain"]         = "SURVIVE  ·  Find SHELTER — roofs block the acid!",
    ["Sandstorm"]         = "SURVIVE  ·  You are SLOWED — find wind cover!",
}

-- ── Helper: make a screen gui ──────────────────────────────────────────────────
local function makeGui(name, order)
    local g = Instance.new("ScreenGui")
    g.Name = name
    g.ResetOnSpawn = false
    g.DisplayOrder = order
    g.IgnoreGuiInset = true
    g.Parent = playerGui
    return g
end

-- ══════════════════════════════════════════════════════════════════════════════
-- OBJECTIVES DISPLAY  (shown 4s at round start)
-- ══════════════════════════════════════════════════════════════════════════════
local objGui    = makeGui("ObjectiveGui", 15)
local objFrame  = Instance.new("Frame")
objFrame.Name   = "ObjectiveFrame"
objFrame.Size   = UDim2.new(0.6, 0, 0, 80)
objFrame.Position = UDim2.new(0.2, 0, 0.08, 0)
objFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 20)
objFrame.BackgroundTransparency = 0.3
objFrame.BorderSizePixel = 0
objFrame.Visible = false
objFrame.Parent = objGui
local objCorner = Instance.new("UICorner", objFrame)
objCorner.CornerRadius = UDim.new(0, 10)

local objLabel = Instance.new("TextLabel")
objLabel.Size = UDim2.new(1, -20, 1, 0)
objLabel.Position = UDim2.new(0, 10, 0, 0)
objLabel.BackgroundTransparency = 1
objLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
objLabel.Font = Enum.Font.GothamBold
objLabel.TextSize = 18
objLabel.TextWrapped = true
objLabel.TextXAlignment = Enum.TextXAlignment.Center
objLabel.Text = ""
objLabel.Parent = objFrame

local bonusLabel = Instance.new("TextLabel")
bonusLabel.Size = UDim2.new(1, -20, 0, 24)
bonusLabel.Position = UDim2.new(0, 10, 1, -28)
bonusLabel.BackgroundTransparency = 1
bonusLabel.TextColor3 = Color3.fromRGB(255, 210, 60)
bonusLabel.Font = Enum.Font.Gotham
bonusLabel.TextSize = 13
bonusLabel.Text = "Bonus: Last survivor +50 XP  ·  No damage +25 XP"
bonusLabel.Parent = objFrame

local function showObjective(disasterName)
    local text = OBJECTIVES[disasterName] or ("SURVIVE the " .. disasterName .. "!")
    objLabel.Text = text
    objFrame.Visible = true
    objFrame.BackgroundTransparency = 0.3
    -- Fade out after 4s
    task.delay(3.5, function()
        TweenService:Create(objFrame, TweenInfo.new(0.8, Enum.EasingStyle.Quad), {
            BackgroundTransparency = 1
        }):Play()
        TweenService:Create(objLabel, TweenInfo.new(0.8), {TextTransparency = 1}):Play()
        TweenService:Create(bonusLabel, TweenInfo.new(0.8), {TextTransparency = 1}):Play()
        task.delay(0.9, function()
            objFrame.Visible = false
            objLabel.TextTransparency = 0
            bonusLabel.TextTransparency = 0
        end)
    end)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- ROUND RESULT SCREEN
-- ══════════════════════════════════════════════════════════════════════════════
local resultGui = makeGui("ResultGui", 25)

local dim = Instance.new("Frame")
dim.Size = UDim2.new(1, 0, 1, 0)
dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
dim.BackgroundTransparency = 0.5
dim.BorderSizePixel = 0
dim.Visible = false
dim.Parent = resultGui

local card = Instance.new("Frame")
card.Size = UDim2.new(0, 420, 0, 320)
card.Position = UDim2.new(0.5, -210, 0.5, -160)
card.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
card.BackgroundTransparency = 0.05
card.BorderSizePixel = 0
card.Parent = dim
Instance.new("UICorner", card).CornerRadius = UDim.new(0, 16)

-- Title
local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 0, 70)
titleLabel.Position = UDim2.new(0, 0, 0, 8)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.GothamBlack
titleLabel.TextSize = 42
titleLabel.Text = "ROUND OVER"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.Parent = card

-- Result sub-text (survived / eliminated)
local resultLabel = Instance.new("TextLabel")
resultLabel.Size = UDim2.new(1, 0, 0, 32)
resultLabel.Position = UDim2.new(0, 0, 0, 76)
resultLabel.BackgroundTransparency = 1
resultLabel.Font = Enum.Font.GothamBold
resultLabel.TextSize = 22
resultLabel.Text = "YOU SURVIVED!"
resultLabel.TextColor3 = Color3.fromRGB(80, 220, 120)
resultLabel.Parent = card

-- Disaster name
local disasterLabel = Instance.new("TextLabel")
disasterLabel.Size = UDim2.new(1, 0, 0, 24)
disasterLabel.Position = UDim2.new(0, 0, 0, 108)
disasterLabel.BackgroundTransparency = 1
disasterLabel.Font = Enum.Font.Gotham
disasterLabel.TextSize = 15
disasterLabel.Text = ""
disasterLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
disasterLabel.Parent = card

-- XP earned
local xpLabel = Instance.new("TextLabel")
xpLabel.Size = UDim2.new(1, 0, 0, 44)
xpLabel.Position = UDim2.new(0, 0, 0, 132)
xpLabel.BackgroundTransparency = 1
xpLabel.Font = Enum.Font.GothamBold
xpLabel.TextSize = 30
xpLabel.Text = "+0 XP"
xpLabel.TextColor3 = Color3.fromRGB(255, 215, 60)
xpLabel.Parent = card

-- Level info
local levelLabel = Instance.new("TextLabel")
levelLabel.Size = UDim2.new(1, 0, 0, 22)
levelLabel.Position = UDim2.new(0, 0, 0, 174)
levelLabel.BackgroundTransparency = 1
levelLabel.Font = Enum.Font.Gotham
levelLabel.TextSize = 14
levelLabel.Text = "Level 1"
levelLabel.TextColor3 = Color3.fromRGB(150, 150, 200)
levelLabel.Parent = card

-- Divider
local div = Instance.new("Frame")
div.Size = UDim2.new(0.85, 0, 0, 1)
div.Position = UDim2.new(0.075, 0, 0, 206)
div.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
div.BorderSizePixel = 0
div.Parent = card

-- Survivors header
local survHeader = Instance.new("TextLabel")
survHeader.Size = UDim2.new(1, 0, 0, 20)
survHeader.Position = UDim2.new(0, 0, 0, 216)
survHeader.BackgroundTransparency = 1
survHeader.Font = Enum.Font.GothamBold
survHeader.TextSize = 13
survHeader.Text = "SURVIVORS"
survHeader.TextColor3 = Color3.fromRGB(100, 200, 255)
survHeader.Parent = card

-- Survivor names
local survNames = Instance.new("TextLabel")
survNames.Size = UDim2.new(1, -20, 0, 60)
survNames.Position = UDim2.new(0, 10, 0, 236)
survNames.BackgroundTransparency = 1
survNames.Font = Enum.Font.Gotham
survNames.TextSize = 14
survNames.Text = "—"
survNames.TextColor3 = Color3.fromRGB(220, 220, 220)
survNames.TextWrapped = true
survNames.Parent = card

-- Level-up banner (hidden by default)
local levelUpBanner = Instance.new("TextLabel")
levelUpBanner.Size = UDim2.new(0.9, 0, 0, 40)
levelUpBanner.Position = UDim2.new(0.05, 0, 0, 272)
levelUpBanner.BackgroundColor3 = Color3.fromRGB(255, 200, 20)
levelUpBanner.BackgroundTransparency = 0.1
levelUpBanner.BorderSizePixel = 0
levelUpBanner.Font = Enum.Font.GothamBlack
levelUpBanner.TextSize = 18
levelUpBanner.Text = "⭐ LEVEL UP!"
levelUpBanner.TextColor3 = Color3.fromRGB(20, 20, 20)
levelUpBanner.Visible = false
levelUpBanner.Parent = card
Instance.new("UICorner", levelUpBanner).CornerRadius = UDim.new(0, 8)

-- ── Show result card ──────────────────────────────────────────────────────────
local function showResult(data)
    local survived   = data.survived or false
    local isWinner   = data.isWinner or false
    local xpEarned   = data.xpEarned or 0
    local newLevel   = data.newLevel or 1
    local didLevelUp = data.didLevelUp or false
    local survivors  = data.survivors or {}
    local disaster   = data.disaster or "?"

    -- Set text
    if isWinner then
        titleLabel.Text = "VICTORY!"
        titleLabel.TextColor3 = Color3.fromRGB(255, 215, 60)
        resultLabel.Text = "LAST SURVIVOR"
        resultLabel.TextColor3 = Color3.fromRGB(255, 215, 60)
    elseif survived then
        titleLabel.Text = "ROUND OVER"
        titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        resultLabel.Text = "YOU SURVIVED!"
        resultLabel.TextColor3 = Color3.fromRGB(80, 220, 120)
    else
        titleLabel.Text = "ROUND OVER"
        titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        resultLabel.Text = "ELIMINATED"
        resultLabel.TextColor3 = Color3.fromRGB(220, 80, 80)
    end

    disasterLabel.Text = disaster
    xpLabel.Text = xpEarned > 0 and ("+" .. xpEarned .. " XP") or "No XP"
    levelLabel.Text = "Level " .. newLevel
    levelUpBanner.Visible = didLevelUp
    if didLevelUp then
        levelUpBanner.Text = "⭐ LEVEL UP!  Now Level " .. newLevel
    end

    if #survivors == 0 then
        survNames.Text = "Nobody survived"
    else
        local top = {}
        for i = 1, math.min(3, #survivors) do
            table.insert(top, "🏅 " .. survivors[i])
        end
        survNames.Text = table.concat(top, "   ")
    end

    -- Animate in: dim fades in, card bounces up from below
    dim.BackgroundTransparency = 1
    dim.Visible = true
    TweenService:Create(dim, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        BackgroundTransparency = 0.5,
    }):Play()

    card.BackgroundTransparency = 1
    card.Size = UDim2.new(0, 380, 0, 290)
    card.Position = UDim2.new(0.5, -190, 0.5, -80)
    TweenService:Create(card, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        BackgroundTransparency = 0.05,
        Size = UDim2.new(0, 420, 0, 320),
        Position = UDim2.new(0.5, -210, 0.5, -160),
    }):Play()

    -- Auto-hide after 5s
    task.delay(5, function()
        TweenService:Create(dim, TweenInfo.new(0.35, Enum.EasingStyle.Quad), {BackgroundTransparency = 1}):Play()
        TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 380, 0, 290),
            Position = UDim2.new(0.5, -190, 0.5, -100),
        }):Play()
        task.delay(0.4, function()
            dim.Visible = false
            dim.BackgroundTransparency = 0.5
            card.BackgroundTransparency = 0.05
            card.Size = UDim2.new(0, 420, 0, 320)
            card.Position = UDim2.new(0.5, -210, 0.5, -160)
        end)
    end)
end

-- ── Event listeners ───────────────────────────────────────────────────────────
RoundEvent.OnClientEvent:Connect(function(eventName, data)
    if eventName == "RoundStart" and type(data) == "table" then
        -- Show objectives for this disaster
        if data.disaster then
            showObjective(data.disaster)
        end
    elseif eventName == "RoundResult" and type(data) == "table" then
        showResult(data)
    end
end)
