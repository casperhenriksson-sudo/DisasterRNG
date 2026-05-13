-- SpinUI — 3 spin tier buttons in lobby
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local SpinRequestEvent  = ReplicatedStorage:WaitForChild("SpinRequestEvent", 15)
local SpinResultEvent   = ReplicatedStorage:WaitForChild("SpinResultEvent",  15)
local CurrencyUpdate    = ReplicatedStorage:WaitForChild("CurrencyUpdate",   15)
local GetData           = ReplicatedStorage:WaitForChild("GetData",          15)
local RoundEvent        = ReplicatedStorage:WaitForChild("RoundEvent",       15)

local TIERS = {
    {name="Basic", cost=50,   label="BASIC SPIN",  color=Color3.fromRGB(60,140,255)},
    {name="Big",   cost=500,  label="BIG SPIN",    color=Color3.fromRGB(220,100,20)},
    {name="Mega",  cost=5000, label="MEGA SPIN",   color=Color3.fromRGB(180,0,220)},
}

local currentDC = 0
local inRound = false
local spinning = false

-- ── ScreenGui ──────────────────────────────────────────────────────────────────
local spinGui = Instance.new("ScreenGui")
spinGui.Name = "SpinButtonGui"
spinGui.ResetOnSpawn = false
spinGui.DisplayOrder = 9
spinGui.Parent = playerGui

-- Container: center-bottom
local container = Instance.new("Frame")
container.Name = "SpinContainer"
container.Size = UDim2.new(0, 420, 0, 100)
container.Position = UDim2.new(0.5, -210, 1, -120)
container.BackgroundTransparency = 1
container.Parent = spinGui

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Padding = UDim.new(0, 8)
layout.Parent = container

-- DC balance label above buttons
local balanceLabel = Instance.new("TextLabel")
balanceLabel.Size = UDim2.new(0, 420, 0, 22)
balanceLabel.Position = UDim2.new(0.5, -210, 1, -145)
balanceLabel.BackgroundTransparency = 1
balanceLabel.Font = Enum.Font.GothamBold
balanceLabel.TextSize = 14
balanceLabel.Text = "DC: 0"
balanceLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
balanceLabel.TextXAlignment = Enum.TextXAlignment.Center
balanceLabel.Parent = spinGui

local buttons = {}

local function updateButtonStates()
    for _, btn in ipairs(buttons) do
        local canAfford = currentDC >= btn.tier.cost
        local enabled = canAfford and not inRound and not spinning
        btn.frame.BackgroundColor3 = enabled and btn.tier.color or Color3.fromRGB(60, 60, 70)
        btn.frame.BackgroundTransparency = enabled and 0 or 0.5
        btn.label.TextTransparency = enabled and 0 or 0.4
        btn.costLabel.TextTransparency = enabled and 0 or 0.4
    end
end

local function setDC(amount)
    currentDC = amount
    balanceLabel.Text = string.format("%d DC", amount)
    updateButtonStates()
end

-- Create 3 tier buttons
for _, tier in ipairs(TIERS) do
    local frame = Instance.new("TextButton")
    frame.Name = tier.name .. "SpinBtn"
    frame.Size = UDim2.new(0, 126, 0, 80)
    frame.BackgroundColor3 = tier.color
    frame.BorderSizePixel = 0
    frame.Text = ""
    frame.Parent = container
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

    local topLabel = Instance.new("TextLabel")
    topLabel.Size = UDim2.new(1, -8, 0, 30)
    topLabel.Position = UDim2.new(0, 4, 0, 8)
    topLabel.BackgroundTransparency = 1
    topLabel.Font = Enum.Font.GothamBlack
    topLabel.TextSize = 13
    topLabel.Text = tier.label
    topLabel.TextColor3 = Color3.new(1, 1, 1)
    topLabel.TextScaled = false
    topLabel.Parent = frame

    local costLabel = Instance.new("TextLabel")
    costLabel.Size = UDim2.new(1, -8, 0, 24)
    costLabel.Position = UDim2.new(0, 4, 0, 42)
    costLabel.BackgroundTransparency = 1
    costLabel.Font = Enum.Font.GothamBold
    costLabel.TextSize = 15
    costLabel.Text = tostring(tier.cost) .. " DC"
    costLabel.TextColor3 = Color3.fromRGB(255, 240, 100)
    costLabel.Parent = frame

    local btnData = {frame=frame, label=topLabel, costLabel=costLabel, tier=tier}
    table.insert(buttons, btnData)

    -- Hover scale effect
    frame.MouseEnter:Connect(function()
        local canAfford = currentDC >= tier.cost
        if canAfford and not inRound and not spinning then
            TweenService:Create(frame, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = UDim2.new(0, 134, 0, 86),
            }):Play()
        end
    end)
    frame.MouseLeave:Connect(function()
        TweenService:Create(frame, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 126, 0, 80),
        }):Play()
    end)

    frame.MouseButton1Click:Connect(function()
        if inRound or spinning then return end
        if currentDC < tier.cost then
            -- Brief shake on insufficient funds
            local origPos = frame.Position
            for _ = 1, 3 do
                TweenService:Create(frame, TweenInfo.new(0.04), {Position = UDim2.new(origPos.X.Scale, origPos.X.Offset + 5, origPos.Y.Scale, origPos.Y.Offset)}):Play()
                task.wait(0.05)
                TweenService:Create(frame, TweenInfo.new(0.04), {Position = origPos}):Play()
                task.wait(0.05)
            end
            return
        end
        -- Press scale-down then release
        TweenService:Create(frame, TweenInfo.new(0.08), {Size = UDim2.new(0, 118, 0, 74)}):Play()
        task.delay(0.1, function()
            TweenService:Create(frame, TweenInfo.new(0.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 126, 0, 80)}):Play()
        end)
        spinning = true
        updateButtonStates()
        SpinRequestEvent:FireServer(tier.name)
    end)
end

-- Visibility control
local function setVisible(v)
    container.Visible = v
    balanceLabel.Visible = v
end

-- Round state
RoundEvent.OnClientEvent:Connect(function(eventName)
    if eventName == "RoundStart" then
        inRound = true
        setVisible(false)
    elseif eventName == "RoundEnd" or eventName == "LobbyWaiting" then
        inRound = false
        setVisible(true)
        updateButtonStates()
    end
end)

-- DC updates
CurrencyUpdate.OnClientEvent:Connect(function(newBalance)
    setDC(newBalance)
end)

-- Spin result
SpinResultEvent.OnClientEvent:Connect(function(result)
    spinning = false
    updateButtonStates()

    if result.error then
        -- Show brief error toast on balanceLabel
        local prev = balanceLabel.Text
        if result.error == "in_round" then
            balanceLabel.Text = "Can't spin during a round!"
        elseif result.error == "insufficient_dc" then
            balanceLabel.Text = "Not enough DC!"
        elseif result.error == "cooldown" then
            balanceLabel.Text = "Wait a moment..."
        else
            balanceLabel.Text = "Spin failed"
        end
        task.delay(2, function()
            balanceLabel.Text = string.format("%d DC", currentDC)
        end)
        return
    end
    -- Success: SpinAnimation.client.lua handles the reveal via SpinResultEvent
end)

-- Fetch initial DC
task.spawn(function()
    local ok, data = pcall(function() return GetData:InvokeServer() end)
    if ok and data then setDC(data.disasterCoins or 0) end
end)

updateButtonStates()
print("[SpinUI] Loaded")
