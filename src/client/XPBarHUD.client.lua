-- XPBarHUD  (StarterPlayerScripts)
-- Persistent bottom-left bar showing current level and XP progress.
-- Updates on RoundResult; loads initial data via GetData on join.

local Players         = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService    = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local RoundEvent = ReplicatedStorage:WaitForChild("RoundEvent")
local GetData    = ReplicatedStorage:WaitForChild("GetData", 15)

-- Cumulative XP thresholds (must match DataManager.XP_LEVELS)
local XP_LEVELS = {100, 250, 500, 900, 1400, 2100, 3000, 4200, 5800, 8000, 11000, 15000, 20000, 27000, 36000}
local MAX_LEVEL = #XP_LEVELS + 1  -- level 16

local function getLevelBounds(level)
    if level >= MAX_LEVEL then
        return XP_LEVELS[#XP_LEVELS], XP_LEVELS[#XP_LEVELS]
    end
    local xpStart = level <= 1 and 0 or XP_LEVELS[level - 1]
    local xpEnd   = XP_LEVELS[level]
    return xpStart, xpEnd
end

local function barColor(level)
    if level >= MAX_LEVEL then return Color3.fromRGB(255, 200, 30) end
    local t = (level - 1) / (MAX_LEVEL - 1)
    -- Green (low) → Cyan → Purple (high)
    if t < 0.5 then
        local s = t * 2
        return Color3.fromRGB(
            math.floor(60 * s),
            math.floor(200 - 60 * s),
            math.floor(80 + 175 * s)
        )
    else
        local s = (t - 0.5) * 2
        return Color3.fromRGB(
            math.floor(60 + 100 * s),
            math.floor(140 - 140 * s),
            math.floor(255 - 55 * s)
        )
    end
end

-- ── Build GUI ─────────────────────────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name = "XPBarGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 5
gui.IgnoreGuiInset = true
gui.Parent = playerGui

-- Container anchored to bottom-left
local container = Instance.new("Frame")
container.Name = "XPContainer"
container.Size = UDim2.new(0, 220, 0, 52)
container.Position = UDim2.new(0, 12, 1, -70)
container.BackgroundColor3 = Color3.fromRGB(10, 10, 22)
container.BackgroundTransparency = 0.2
container.BorderSizePixel = 0
container.Parent = gui
Instance.new("UICorner", container).CornerRadius = UDim.new(0, 10)

-- Level badge (left side)
local levelBadge = Instance.new("Frame")
levelBadge.Name = "LevelBadge"
levelBadge.Size = UDim2.new(0, 44, 0, 44)
levelBadge.Position = UDim2.new(0, 4, 0.5, -22)
levelBadge.BackgroundColor3 = Color3.fromRGB(30, 20, 60)
levelBadge.BorderSizePixel = 0
levelBadge.Parent = container
Instance.new("UICorner", levelBadge).CornerRadius = UDim.new(0, 8)

local levelLabel = Instance.new("TextLabel")
levelLabel.Size = UDim2.new(1, 0, 1, 0)
levelLabel.BackgroundTransparency = 1
levelLabel.Font = Enum.Font.GothamBlack
levelLabel.TextSize = 14
levelLabel.Text = "LV 1"
levelLabel.TextColor3 = Color3.fromRGB(255, 215, 60)
levelLabel.Parent = levelBadge

-- Right side: xp text + bar
local xpLabel = Instance.new("TextLabel")
xpLabel.Name = "XPLabel"
xpLabel.Size = UDim2.new(1, -58, 0, 18)
xpLabel.Position = UDim2.new(0, 54, 0, 8)
xpLabel.BackgroundTransparency = 1
xpLabel.Font = Enum.Font.GothamBold
xpLabel.TextSize = 11
xpLabel.Text = "0 / 100 XP"
xpLabel.TextColor3 = Color3.fromRGB(180, 180, 210)
xpLabel.TextXAlignment = Enum.TextXAlignment.Left
xpLabel.Parent = container

-- Bar track
local barTrack = Instance.new("Frame")
barTrack.Name = "BarTrack"
barTrack.Size = UDim2.new(1, -58, 0, 10)
barTrack.Position = UDim2.new(0, 54, 0, 30)
barTrack.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
barTrack.BorderSizePixel = 0
barTrack.Parent = container
Instance.new("UICorner", barTrack).CornerRadius = UDim.new(1, 0)

-- Bar fill
local barFill = Instance.new("Frame")
barFill.Name = "BarFill"
barFill.Size = UDim2.new(0, 0, 1, 0)
barFill.BackgroundColor3 = Color3.fromRGB(60, 200, 100)
barFill.BorderSizePixel = 0
barFill.Parent = barTrack
Instance.new("UICorner", barFill).CornerRadius = UDim.new(1, 0)

-- XP gained pop label (appears briefly above the bar on level events)
local xpPopLabel = Instance.new("TextLabel")
xpPopLabel.Name = "XPPop"
xpPopLabel.Size = UDim2.new(0, 180, 0, 24)
xpPopLabel.AnchorPoint = Vector2.new(0.5, 1)
xpPopLabel.Position = UDim2.new(0.5, 0, 0, -4)
xpPopLabel.BackgroundTransparency = 1
xpPopLabel.Font = Enum.Font.GothamBold
xpPopLabel.TextSize = 13
xpPopLabel.Text = ""
xpPopLabel.TextColor3 = Color3.fromRGB(255, 215, 60)
xpPopLabel.TextTransparency = 1
xpPopLabel.Parent = container

-- ── State ──────────────────────────────────────────────────────────────────────
local currentLevel = 1
local currentXP    = 0

local function refresh(level, xp, xpGained, didLevelUp)
    currentLevel = level or 1
    currentXP    = xp    or 0

    local color = barColor(currentLevel)
    levelLabel.Text  = "LV " .. currentLevel
    levelLabel.TextColor3 = color

    local xpStart, xpEnd = getLevelBounds(currentLevel)
    local progress

    if currentLevel >= MAX_LEVEL then
        xpLabel.Text = "MAX LEVEL"
        progress = 1
    else
        local needed = xpEnd - xpStart
        local have   = math.max(0, currentXP - xpStart)
        progress = needed > 0 and math.min(1, have / needed) or 1
        xpLabel.Text = have .. " / " .. needed .. " XP"
    end

    -- Animate bar fill
    TweenService:Create(barFill, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.new(progress, 0, 1, 0),
        BackgroundColor3 = color,
    }):Play()

    -- XP gained pop
    if xpGained and xpGained > 0 then
        xpPopLabel.Text = "+" .. xpGained .. " XP"
        xpPopLabel.TextTransparency = 0
        xpPopLabel.Position = UDim2.new(0.5, 0, 0, -4)
        TweenService:Create(xpPopLabel, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.5, 0, 0, -28),
            TextTransparency = 1,
        }):Play()
    end

    -- Level-up badge pop
    if didLevelUp then
        TweenService:Create(levelBadge, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 52, 0, 52),
            Position = UDim2.new(0, 0, 0.5, -26),
        }):Play()
        task.delay(0.2, function()
            TweenService:Create(levelBadge, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Size = UDim2.new(0, 44, 0, 44),
                Position = UDim2.new(0, 4, 0.5, -22),
            }):Play()
        end)
    end
end

-- ── Events ────────────────────────────────────────────────────────────────────
RoundEvent.OnClientEvent:Connect(function(eventName, data)
    if eventName == "RoundResult" and type(data) == "table" then
        refresh(data.newLevel, data.newXP, data.xpEarned, data.didLevelUp)
    end
end)

-- Initial load
task.spawn(function()
    if not GetData then return end
    local ok, data = pcall(function() return GetData:InvokeServer() end)
    if ok and data then
        refresh(data.level or 1, data.xp or 0, nil, false)
    end
end)
