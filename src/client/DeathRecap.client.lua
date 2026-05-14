-- DeathRecap: brief animated card after being eliminated in a round
-- Shows cause/disaster + time survived. Slides up from below screen,
-- holds 3s, slides back down.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer
local RoundEvent  = ReplicatedStorage:WaitForChild("RoundEvent")

-- Cache disaster name from RoundStart
local currentDisaster   = "Unknown"
local roundStartTime    = 0

-- ── Build GUI ─────────────────────────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "DeathRecapGui"
screenGui.ResetOnSpawn   = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent         = localPlayer.PlayerGui

-- Card frame (300×120, bottom-center)
local card = Instance.new("Frame")
card.Size                   = UDim2.new(0, 300, 0, 120)
card.AnchorPoint            = Vector2.new(0.5, 1)
-- Start below screen (hidden)
card.Position               = UDim2.new(0.5, 0, 1, 140)
card.BackgroundColor3       = Color3.fromRGB(15, 15, 15)
card.BackgroundTransparency = 0.2
card.BorderSizePixel        = 0
card.Visible                = false
card.Parent                 = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent       = card

-- Red accent bar at top
local accentBar = Instance.new("Frame")
accentBar.Size             = UDim2.new(1, 0, 0, 4)
accentBar.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
accentBar.BorderSizePixel  = 0
accentBar.Parent           = card
local accentCorner = Instance.new("UICorner")
accentCorner.CornerRadius = UDim.new(0, 4)
accentCorner.Parent       = accentBar

-- Top line: cause
local causeLabel = Instance.new("TextLabel")
causeLabel.Size                   = UDim2.new(1, -16, 0, 50)
causeLabel.Position               = UDim2.new(0, 8, 0, 10)
causeLabel.BackgroundTransparency = 1
causeLabel.TextColor3             = Color3.fromRGB(255, 255, 255)
causeLabel.TextScaled             = true
causeLabel.Font                   = Enum.Font.GothamBold
causeLabel.Text                   = "💀 Eliminated by Unknown"
causeLabel.TextXAlignment         = Enum.TextXAlignment.Center
causeLabel.Parent                 = card

-- Bottom line: time
local timeLabel = Instance.new("TextLabel")
timeLabel.Size                   = UDim2.new(1, -16, 0, 36)
timeLabel.Position               = UDim2.new(0, 8, 0, 64)
timeLabel.BackgroundTransparency = 1
timeLabel.TextColor3             = Color3.fromRGB(180, 180, 180)
timeLabel.TextScaled             = true
timeLabel.Font                   = Enum.Font.Gotham
timeLabel.Text                   = ""
timeLabel.TextXAlignment         = Enum.TextXAlignment.Center
timeLabel.Parent                 = card

-- ── Animation ─────────────────────────────────────────────────────────────────
local recapActive = false

local function showRecap(disaster, secondsLasted)
    if recapActive then return end
    recapActive = true

    causeLabel.Text = "💀 Eliminated by " .. (disaster or "Unknown")
    if secondsLasted and secondsLasted > 0 then
        timeLabel.Text = "You lasted " .. math.floor(secondsLasted) .. "s"
    else
        timeLabel.Text = ""
    end

    -- Show card off-screen bottom
    card.Position = UDim2.new(0.5, 0, 1, 140)
    card.Visible  = true

    -- Slide up to resting position
    local restPos = UDim2.new(0.5, 0, 1, -180)
    TweenService:Create(card, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = restPos
    }):Play()

    -- Hold 3s, then slide back down
    task.delay(3.4, function()
        if not recapActive then return end
        TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(0.5, 0, 1, 140)
        }):Play()
        task.delay(0.35, function()
            card.Visible  = false
            recapActive   = false
        end)
    end)
end

-- ── Wire RoundEvent ───────────────────────────────────────────────────────────
RoundEvent.OnClientEvent:Connect(function(event, data)
    if event == "RoundStart" then
        currentDisaster = data and data.disaster or "Unknown"
        roundStartTime  = os.clock()

    elseif event == "RoundResult" then
        if data and data.survived == false then
            local elapsed = os.clock() - roundStartTime
            showRecap(data.disaster or currentDisaster, elapsed)
        end
    end
end)
