-- QuestUI: client-side daily quest panel
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local QuestGetEvent    = ReplicatedStorage:WaitForChild("QuestGetEvent", 15)
local QuestClaimEvent  = ReplicatedStorage:WaitForChild("QuestClaimEvent", 15)
local QuestUpdateEvent = ReplicatedStorage:WaitForChild("QuestUpdateEvent", 15)
local RoundEvent       = ReplicatedStorage:WaitForChild("RoundEvent", 15)

local TIER_COLOR = {
    Easy   = Color3.fromRGB(80, 200, 80),
    Medium = Color3.fromRGB(60, 120, 255),
    Hard   = Color3.fromRGB(255, 100, 100),
}

local state = { quests = {}, resetTimestamp = 0 }
local isOpen = false
local inRound = false
local rowRefs = {}  -- index -> { row=, bar=, barFill=, progText=, claimBtn= }

-- ── ScreenGui ──────────────────────────────────────────────────────────────────
local qGui = Instance.new("ScreenGui")
qGui.Name = "QuestGui"
qGui.ResetOnSpawn = false
qGui.DisplayOrder = 15
qGui.Parent = playerGui

-- Quests button (above Inventory btn)
local qBtn = Instance.new("TextButton")
qBtn.Name = "QuestsBtn"
qBtn.Size = UDim2.new(0, 140, 0, 44)
qBtn.Position = UDim2.new(1, -155, 1, -170)
qBtn.BackgroundColor3 = Color3.fromRGB(40, 30, 60)
qBtn.BorderSizePixel = 0
qBtn.Font = Enum.Font.GothamBold
qBtn.TextSize = 14
qBtn.Text = "Quests"
qBtn.TextColor3 = Color3.new(1, 1, 1)
qBtn.Parent = qGui
Instance.new("UICorner", qBtn).CornerRadius = UDim.new(0, 10)

-- Red dot notification
local redDot = Instance.new("Frame")
redDot.Name = "RedDot"
redDot.Size = UDim2.new(0, 10, 0, 10)
redDot.Position = UDim2.new(1, -6, 0, -4)
redDot.AnchorPoint = Vector2.new(0.5, 0.5)
redDot.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
redDot.BorderSizePixel = 0
redDot.Visible = false
redDot.ZIndex = 5
redDot.Parent = qBtn
Instance.new("UICorner", redDot).CornerRadius = UDim.new(1, 0)

-- Panel
local panel = Instance.new("Frame")
panel.Name = "QuestPanel"
panel.Size = UDim2.new(0, 340, 0, 420)
panel.Position = UDim2.new(0.5, -170, 0.5, -210)
panel.BackgroundColor3 = Color3.fromRGB(12, 12, 22)
panel.BackgroundTransparency = 0.05
panel.BorderSizePixel = 0
panel.Visible = false
panel.ZIndex = 10
panel.Parent = qGui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 16)

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 48)
titleBar.BackgroundColor3 = Color3.fromRGB(30, 20, 60)
titleBar.BorderSizePixel = 0
titleBar.ZIndex = 11
titleBar.Parent = panel
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 16)

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -50, 1, 0)
titleLabel.Position = UDim2.new(0, 16, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.GothamBlack
titleLabel.TextSize = 18
titleLabel.Text = "DAILY QUESTS"
titleLabel.TextColor3 = Color3.new(1, 1, 1)
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.ZIndex = 12
titleLabel.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 36, 0, 36)
closeBtn.Position = UDim2.new(1, -42, 0, 6)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
closeBtn.BorderSizePixel = 0
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 16
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.ZIndex = 12
closeBtn.Parent = titleBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

-- Quest list container
local listFrame = Instance.new("Frame")
listFrame.Size = UDim2.new(1, -16, 1, -90)
listFrame.Position = UDim2.new(0, 8, 0, 54)
listFrame.BackgroundTransparency = 1
listFrame.BorderSizePixel = 0
listFrame.ZIndex = 11
listFrame.Parent = panel

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 8)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = listFrame

-- Reset timer label
local timerLabel = Instance.new("TextLabel")
timerLabel.Size = UDim2.new(1, -16, 0, 24)
timerLabel.Position = UDim2.new(0, 8, 1, -32)
timerLabel.BackgroundTransparency = 1
timerLabel.Font = Enum.Font.Gotham
timerLabel.TextSize = 12
timerLabel.TextColor3 = Color3.fromRGB(160, 160, 180)
timerLabel.Text = "Resets in --"
timerLabel.TextXAlignment = Enum.TextXAlignment.Center
timerLabel.ZIndex = 12
timerLabel.Parent = panel

-- ── Build a quest row ──────────────────────────────────────────────────────────
local function buildRow(index, quest)
    local row = Instance.new("Frame")
    row.Name = "QuestRow_" .. index
    row.Size = UDim2.new(1, 0, 0, 90)
    row.BackgroundColor3 = Color3.fromRGB(22, 22, 36)
    row.BackgroundTransparency = 0.2
    row.BorderSizePixel = 0
    row.LayoutOrder = index
    row.ZIndex = 11
    row.Parent = listFrame
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 10)

    -- Tier dot
    local tierDot = Instance.new("Frame")
    tierDot.Size = UDim2.new(0, 12, 0, 12)
    tierDot.Position = UDim2.new(0, 10, 0, 12)
    tierDot.BackgroundColor3 = TIER_COLOR[quest.tier] or Color3.new(1, 1, 1)
    tierDot.BorderSizePixel = 0
    tierDot.ZIndex = 12
    tierDot.Parent = row
    Instance.new("UICorner", tierDot).CornerRadius = UDim.new(1, 0)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -110, 0, 22)
    label.Position = UDim2.new(0, 28, 0, 6)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 13
    label.Text = quest.label
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextTruncate = Enum.TextTruncate.AtEnd
    label.ZIndex = 12
    label.Parent = row

    -- Reward label
    local rewardL = Instance.new("TextLabel")
    rewardL.Size = UDim2.new(0, 80, 0, 22)
    rewardL.Position = UDim2.new(1, -88, 0, 6)
    rewardL.BackgroundTransparency = 1
    rewardL.Font = Enum.Font.GothamBold
    rewardL.TextSize = 12
    rewardL.Text = "+" .. quest.reward .. " DC"
    rewardL.TextColor3 = Color3.fromRGB(255, 215, 80)
    rewardL.TextXAlignment = Enum.TextXAlignment.Right
    rewardL.ZIndex = 12
    rewardL.Parent = row

    -- Progress bar background
    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -20, 0, 14)
    bar.Position = UDim2.new(0, 10, 0, 34)
    bar.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    bar.BorderSizePixel = 0
    bar.ZIndex = 12
    bar.Parent = row
    Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 4)

    local barFill = Instance.new("Frame")
    barFill.Size = UDim2.new(0, 0, 1, 0)
    barFill.BackgroundColor3 = Color3.fromRGB(120, 120, 140)
    barFill.BorderSizePixel = 0
    barFill.ZIndex = 13
    barFill.Parent = bar
    Instance.new("UICorner", barFill).CornerRadius = UDim.new(0, 4)

    local progText = Instance.new("TextLabel")
    progText.Size = UDim2.new(0, 80, 0, 16)
    progText.Position = UDim2.new(0, 10, 0, 50)
    progText.BackgroundTransparency = 1
    progText.Font = Enum.Font.Gotham
    progText.TextSize = 11
    progText.Text = "0/0"
    progText.TextColor3 = Color3.fromRGB(180, 180, 200)
    progText.TextXAlignment = Enum.TextXAlignment.Left
    progText.ZIndex = 13
    progText.Parent = row

    -- Claim button
    local claimBtn = Instance.new("TextButton")
    claimBtn.Size = UDim2.new(0, 90, 0, 28)
    claimBtn.Position = UDim2.new(1, -100, 1, -34)
    claimBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    claimBtn.BorderSizePixel = 0
    claimBtn.Font = Enum.Font.GothamBold
    claimBtn.TextSize = 12
    claimBtn.Text = "CLAIM"
    claimBtn.TextColor3 = Color3.new(1, 1, 1)
    claimBtn.AutoButtonColor = false
    claimBtn.ZIndex = 13
    claimBtn.Parent = row
    Instance.new("UICorner", claimBtn).CornerRadius = UDim.new(0, 6)

    return { row = row, bar = bar, barFill = barFill, progText = progText, claimBtn = claimBtn, rewardL = rewardL }
end

-- ── Quest row update ──────────────────────────────────────────────────────────
local function flyUpReward(amount, fromBtn)
    local flyL = Instance.new("TextLabel")
    flyL.Size = UDim2.new(0, 100, 0, 24)
    flyL.Position = UDim2.new(0, fromBtn.AbsolutePosition.X - panel.AbsolutePosition.X,
                              0, fromBtn.AbsolutePosition.Y - panel.AbsolutePosition.Y)
    flyL.BackgroundTransparency = 1
    flyL.Font = Enum.Font.GothamBlack
    flyL.TextSize = 18
    flyL.Text = "+" .. amount .. " DC"
    flyL.TextColor3 = Color3.fromRGB(255, 215, 80)
    flyL.TextStrokeTransparency = 0
    flyL.TextStrokeColor3 = Color3.new(0, 0, 0)
    flyL.ZIndex = 30
    flyL.Parent = panel
    TweenService:Create(flyL, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = flyL.Position - UDim2.new(0, 0, 0, 60),
        TextTransparency = 1,
        TextStrokeTransparency = 1,
    }):Play()
    task.delay(0.95, function() flyL:Destroy() end)
end

local pulseConns = {}
local function setClaimPulse(btn, enabled)
    if pulseConns[btn] then pulseConns[btn]:Disconnect(); pulseConns[btn] = nil end
    if not enabled then return end
    local t0 = os.clock()
    pulseConns[btn] = RunService.RenderStepped:Connect(function()
        local s = 1 + math.sin((os.clock() - t0) * 6) * 0.05
        btn.Size = UDim2.new(0, math.floor(90 * s), 0, math.floor(28 * s))
    end)
end

local function updateRow(idx, quest)
    local refs = rowRefs[idx]
    if not refs then return end
    local goal = math.max(1, quest.goal)
    local prog = math.clamp(quest.progress, 0, goal)
    local frac = prog / goal
    refs.barFill:TweenSize(UDim2.new(math.clamp(frac, 0, 1), 0, 1, 0),
        Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.3, true)
    refs.progText.Text = string.format("%d/%d", prog, goal)

    local complete = quest.progress >= quest.goal

    if quest.claimed then
        refs.barFill.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
        refs.claimBtn.Text = "CLAIMED"
        refs.claimBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
        refs.claimBtn.TextColor3 = Color3.fromRGB(140, 140, 160)
        setClaimPulse(refs.claimBtn, false)
        refs.claimBtn.Size = UDim2.new(0, 90, 0, 28)
    elseif complete then
        refs.barFill.BackgroundColor3 = Color3.fromRGB(80, 200, 80)
        refs.claimBtn.Text = "CLAIM"
        refs.claimBtn.BackgroundColor3 = Color3.fromRGB(60, 180, 60)
        refs.claimBtn.TextColor3 = Color3.new(1, 1, 1)
        setClaimPulse(refs.claimBtn, true)
    elseif prog > 0 then
        refs.barFill.BackgroundColor3 = Color3.fromRGB(60, 120, 255)
        refs.claimBtn.Text = "IN PROGRESS"
        refs.claimBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
        refs.claimBtn.TextColor3 = Color3.fromRGB(180, 180, 200)
        setClaimPulse(refs.claimBtn, false)
        refs.claimBtn.Size = UDim2.new(0, 90, 0, 28)
    else
        refs.barFill.BackgroundColor3 = Color3.fromRGB(120, 120, 140)
        refs.claimBtn.Text = "LOCKED"
        refs.claimBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
        refs.claimBtn.TextColor3 = Color3.fromRGB(140, 140, 160)
        setClaimPulse(refs.claimBtn, false)
        refs.claimBtn.Size = UDim2.new(0, 90, 0, 28)
    end
end

local function hasUnclaimedComplete()
    for _, q in ipairs(state.quests) do
        if not q.claimed and q.progress >= q.goal then return true end
    end
    return false
end

local function rebuildList()
    -- Tear down existing
    for _, refs in pairs(rowRefs) do
        if refs.row then refs.row:Destroy() end
        if pulseConns[refs.claimBtn] then pulseConns[refs.claimBtn]:Disconnect() end
    end
    rowRefs = {}
    pulseConns = {}

    for i, q in ipairs(state.quests) do
        local refs = buildRow(i, q)
        rowRefs[i] = refs
        local capturedIdx = i
        refs.claimBtn.MouseButton1Click:Connect(function()
            -- Optimistic UX: disable button briefly
            local oldText = refs.claimBtn.Text
            refs.claimBtn.Text = "..."
            local ok, result = pcall(function()
                return QuestClaimEvent:InvokeServer(capturedIdx)
            end)
            if ok and type(result) == "table" and result.ok then
                flyUpReward(result.reward or 0, refs.claimBtn)
                -- Server will push QuestUpdateEvent
            else
                refs.claimBtn.Text = oldText
            end
        end)
        updateRow(i, q)
    end

    redDot.Visible = hasUnclaimedComplete()
end

local function applyState(newState)
    if type(newState) ~= "table" then return end
    state.quests = newState.quests or {}
    state.resetTimestamp = newState.resetTimestamp or (os.time() + 86400)
    rebuildList()
end

-- ── Open / close ───────────────────────────────────────────────────────────────
local function refreshQuests()
    local ok, data = pcall(function() return QuestGetEvent:InvokeServer() end)
    if ok and data then applyState(data) end
end

local function openPanel()
    if isOpen or inRound then return end
    isOpen = true
    panel.Size = UDim2.new(0, 0, 0, 0)
    panel.Position = UDim2.new(0.5, 0, 0.5, 0)
    panel.Visible = true
    TweenService:Create(panel, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 340, 0, 420),
        Position = UDim2.new(0.5, -170, 0.5, -210),
    }):Play()
    task.spawn(refreshQuests)
end

local function closePanel()
    if not isOpen then return end
    TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 0, 0, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
    }):Play()
    task.delay(0.28, function()
        panel.Visible = false
        isOpen = false
    end)
end

qBtn.MouseButton1Click:Connect(function()
    if isOpen then closePanel() else openPanel() end
end)
closeBtn.MouseButton1Click:Connect(closePanel)

-- ── Server pushed updates ──────────────────────────────────────────────────────
QuestUpdateEvent.OnClientEvent:Connect(function(data)
    applyState(data)
end)

-- ── Round visibility ───────────────────────────────────────────────────────────
RoundEvent.OnClientEvent:Connect(function(ev)
    if ev == "RoundStart" then
        inRound = true
        if isOpen then closePanel() end
        qBtn.Visible = false
    elseif ev == "RoundEnd" or ev == "LobbyWaiting" or ev == "LobbyCountdown" then
        inRound = false
        qBtn.Visible = true
    end
end)

-- ── Reset timer (updates every second while panel visible) ────────────────────
task.spawn(function()
    while true do
        task.wait(1)
        if panel.Visible and state.resetTimestamp and state.resetTimestamp > 0 then
            local remaining = state.resetTimestamp - os.time()
            if remaining <= 0 then
                timerLabel.Text = "Resetting..."
                -- refresh after reset
                task.spawn(refreshQuests)
            else
                local h = math.floor(remaining / 3600)
                local m = math.floor((remaining % 3600) / 60)
                timerLabel.Text = string.format("Resets in %dh %dm", h, m)
            end
        end
    end
end)

-- Initial fetch
task.spawn(function()
    task.wait(2) -- wait a bit for server-side load
    refreshQuests()
end)

print("[QuestUI] Loaded")
