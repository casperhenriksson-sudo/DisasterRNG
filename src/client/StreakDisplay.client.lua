-- StreakDisplay: bottom-left HUD showing current survival streak flame
-- Position: UDim2.new(0, 16, 1, -170) — above nothing, safe zone

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local localPlayer       = Players.LocalPlayer
local StreakUpdateEvent = ReplicatedStorage:WaitForChild("StreakUpdateEvent")

-- ── Build GUI ─────────────────────────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "StreakDisplayGui"
screenGui.ResetOnSpawn   = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent         = localPlayer.PlayerGui

-- Container frame
local frame = Instance.new("Frame")
frame.Size                  = UDim2.new(0, 160, 0, 44)
frame.Position              = UDim2.new(0, 16, 1, -170)
frame.AnchorPoint           = Vector2.new(0, 1)
frame.BackgroundColor3      = Color3.fromRGB(20, 20, 20)
frame.BackgroundTransparency = 0.4
frame.BorderSizePixel       = 0
frame.Visible               = false
frame.Parent                = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent       = frame

local streakLabel = Instance.new("TextLabel")
streakLabel.Size                   = UDim2.new(1, 0, 1, 0)
streakLabel.BackgroundTransparency = 1
streakLabel.TextColor3             = Color3.fromRGB(255, 255, 255)
streakLabel.TextScaled             = true
streakLabel.Font                   = Enum.Font.GothamBold
streakLabel.Text                   = "🔥 0 streak"
streakLabel.Parent                 = frame

-- "NEW RECORD!" overlay label
local recordLabel = Instance.new("TextLabel")
recordLabel.Size                   = UDim2.new(1, 0, 0, 20)
recordLabel.Position               = UDim2.new(0, 0, 1, 2)
recordLabel.BackgroundTransparency = 1
recordLabel.TextColor3             = Color3.fromRGB(255, 215, 0)
recordLabel.TextScaled             = true
recordLabel.Font                   = Enum.Font.GothamBold
recordLabel.Text                   = "NEW RECORD!"
recordLabel.TextTransparency       = 1
recordLabel.Parent                 = frame

-- ── Gold flash tween ─────────────────────────────────────────────────────────
local function playRecordFlash()
    -- Flash frame gold
    frame.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
    TweenService:Create(frame, TweenInfo.new(0.5), {BackgroundColor3 = Color3.fromRGB(20, 20, 20)}):Play()

    -- Show NEW RECORD! text
    recordLabel.TextTransparency = 0
    task.delay(2, function()
        TweenService:Create(recordLabel, TweenInfo.new(0.4), {TextTransparency = 1}):Play()
    end)
end

-- ── Update display ────────────────────────────────────────────────────────────
local lastSurvivalStreak = 0

StreakUpdateEvent.OnClientEvent:Connect(function(data)
    if not data then return end

    local survivalStreak    = data.survivalStreak   or 0
    local bestSurvival      = data.bestSurvivalStreak or 0

    if survivalStreak == 0 then
        frame.Visible = false
        lastSurvivalStreak = 0
        return
    end

    frame.Visible  = true
    streakLabel.Text = "🔥 " .. survivalStreak .. " streak"

    -- Check for new survival record
    if survivalStreak >= bestSurvival and survivalStreak > lastSurvivalStreak and survivalStreak > 1 then
        playRecordFlash()
    end

    lastSurvivalStreak = survivalStreak
end)
