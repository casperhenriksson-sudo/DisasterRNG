-- GameFeel LocalScript
-- Subagent 4: Money/Luck HUD, Dramatic Notifications, PlayerStatus, LeaderFrame, Rebirth Badge
-- Does NOT duplicate: screen shake (DisasterUI), NotifFrame popups (HUDPolish), PerkButton anims (HUDPolish)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local playerGui = player.PlayerGui

-- ============================================================
-- CONSTANTS
-- ============================================================
local NEON_CYAN  = Color3.fromRGB(0, 240, 255)
local NEON_GOLD  = Color3.fromRGB(255, 210, 0)
local DARK_BG    = Color3.fromRGB(14, 20, 30)
local GREEN_SURV = Color3.fromRGB(80, 255, 120)
local RED_ELIM   = Color3.fromRGB(255, 80, 80)
local RED_DIED   = Color3.fromRGB(180, 80, 80)

-- ============================================================
-- REMOTE EVENTS
-- ============================================================
local RoundEvent   = ReplicatedStorage:WaitForChild("RoundEvent", 10)
local PerkEvent    = ReplicatedStorage:FindFirstChild("PerkEvent")
-- Optional data channel
local DataEvent    = ReplicatedStorage:FindFirstChild("DataEvent")
local GetDataFn    = ReplicatedStorage:FindFirstChild("GetData")

-- ============================================================
-- WAIT FOR GAME UI
-- ============================================================
local gameUI = playerGui:WaitForChild("GameUI", 15)
local leaderFrame     = gameUI:WaitForChild("LeaderFrame", 5)
local playerStatusFrame = gameUI:WaitForChild("PlayerStatusFrame", 5)
local statusLabel     = playerStatusFrame and playerStatusFrame:FindFirstChild("StatusLabel")

-- ============================================================
-- PART 1: GameFeel_HUD ScreenGui (Money + Luck + Rebirth)
-- ============================================================
local hudGui = Instance.new("ScreenGui")
hudGui.Name = "GameFeel_HUD"
hudGui.DisplayOrder = 5
hudGui.ResetOnSpawn = false
hudGui.IgnoreGuiInset = true
hudGui.Parent = playerGui

local function makeCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = parent
    return c
end

local function makeStroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color
    s.Thickness = thickness
    s.Parent = parent
    return s
end

-- ----- LuckDisplay -----
local luckDisplay = Instance.new("Frame")
luckDisplay.Name = "LuckDisplay"
luckDisplay.Size = UDim2.new(0, 160, 0, 46)
luckDisplay.Position = UDim2.new(0, 16, 1, -116)
luckDisplay.BackgroundColor3 = DARK_BG
luckDisplay.BackgroundTransparency = 0.15
luckDisplay.BorderSizePixel = 0
luckDisplay.Parent = hudGui
makeCorner(luckDisplay, 10)
makeStroke(luckDisplay, NEON_CYAN, 1.5)

local luckIcon = Instance.new("TextLabel")
luckIcon.Name = "LuckIcon"
luckIcon.Size = UDim2.new(0, 36, 1, 0)
luckIcon.Position = UDim2.new(0, 4, 0, 0)
luckIcon.BackgroundTransparency = 1
luckIcon.Text = "🍀"
luckIcon.TextSize = 22
luckIcon.Font = Enum.Font.GothamBold
luckIcon.TextColor3 = Color3.fromRGB(100, 255, 160)
luckIcon.TextXAlignment = Enum.TextXAlignment.Center
luckIcon.Parent = luckDisplay

local luckLabel = Instance.new("TextLabel")
luckLabel.Name = "LuckLabel"
luckLabel.Size = UDim2.new(1, -44, 1, 0)
luckLabel.Position = UDim2.new(0, 42, 0, 0)
luckLabel.BackgroundTransparency = 1
luckLabel.Text = "1.0x"
luckLabel.TextSize = 22
luckLabel.Font = Enum.Font.GothamBold
luckLabel.TextColor3 = Color3.fromRGB(100, 255, 160)
luckLabel.TextXAlignment = Enum.TextXAlignment.Left
luckLabel.Parent = luckDisplay

-- ----- MoneyDisplay -----
local moneyDisplay = Instance.new("Frame")
moneyDisplay.Name = "MoneyDisplay"
moneyDisplay.Size = UDim2.new(0, 160, 0, 46)
moneyDisplay.Position = UDim2.new(0, 16, 1, -62)
moneyDisplay.BackgroundColor3 = DARK_BG
moneyDisplay.BackgroundTransparency = 0.15
moneyDisplay.BorderSizePixel = 0
moneyDisplay.Parent = hudGui
makeCorner(moneyDisplay, 10)
makeStroke(moneyDisplay, NEON_CYAN, 1.5)

local moneyIcon = Instance.new("TextLabel")
moneyIcon.Name = "MoneyIcon"
moneyIcon.Size = UDim2.new(0, 36, 1, 0)
moneyIcon.Position = UDim2.new(0, 4, 0, 0)
moneyIcon.BackgroundTransparency = 1
moneyIcon.Text = "💰"
moneyIcon.TextSize = 22
moneyIcon.Font = Enum.Font.GothamBold
moneyIcon.TextColor3 = Color3.fromRGB(255, 210, 0)
moneyIcon.TextXAlignment = Enum.TextXAlignment.Center
moneyIcon.Parent = moneyDisplay

local moneyLabel = Instance.new("TextLabel")
moneyLabel.Name = "MoneyLabel"
moneyLabel.Size = UDim2.new(1, -44, 1, 0)
moneyLabel.Position = UDim2.new(0, 42, 0, 0)
moneyLabel.BackgroundTransparency = 1
moneyLabel.Text = "0"
moneyLabel.TextSize = 22
moneyLabel.Font = Enum.Font.GothamBold
moneyLabel.TextColor3 = Color3.fromRGB(255, 210, 0)
moneyLabel.TextXAlignment = Enum.TextXAlignment.Left
moneyLabel.Parent = moneyDisplay

-- ----- Rebirth Badge (top-right, shown when rebirth > 0) -----
local rebirthBadge = Instance.new("Frame")
rebirthBadge.Name = "RebirthBadge"
rebirthBadge.Position = UDim2.new(1, -90, 0, 16)
rebirthBadge.Size = UDim2.new(0, 80, 0, 36)
rebirthBadge.BackgroundColor3 = Color3.fromRGB(255, 210, 0)
rebirthBadge.BorderSizePixel = 0
rebirthBadge.Visible = false
rebirthBadge.Parent = hudGui
makeCorner(rebirthBadge, 18)

local rebirthLabel = Instance.new("TextLabel")
rebirthLabel.Name = "RebirthLabel"
rebirthLabel.Size = UDim2.new(1, 0, 1, 0)
rebirthLabel.BackgroundTransparency = 1
rebirthLabel.Text = "🔄 R1"
rebirthLabel.TextSize = 18
rebirthLabel.Font = Enum.Font.GothamBlack
rebirthLabel.TextColor3 = Color3.fromRGB(20, 10, 0)
rebirthLabel.TextXAlignment = Enum.TextXAlignment.Center
rebirthLabel.Parent = rebirthBadge

-- ============================================================
-- DATA STATE
-- ============================================================
local currentMoney  = 0
local currentLuck   = 1
local currentRebirth = 0

local function animateMoney(oldVal, newVal)
    -- Scale pulse
    local origSize = moneyLabel.TextSize
    TweenService:Create(moneyLabel,
        TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { TextSize = origSize * 1.1 }
    ):Play()
    task.delay(0.12, function()
        TweenService:Create(moneyLabel,
            TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { TextSize = origSize }
        ):Play()
    end)
    -- Count up
    local steps = 20
    local stepTime = 0.8 / steps
    local diff = newVal - oldVal
    for i = 1, steps do
        task.delay(stepTime * i, function()
            local v = math.floor(oldVal + diff * (i / steps))
            moneyLabel.Text = tostring(v)
        end)
    end
end

local function updateData(money, luck, rebirth)
    local oldMoney = currentMoney
    currentMoney  = money  or currentMoney
    currentLuck   = luck   or currentLuck
    currentRebirth = rebirth or currentRebirth

    -- Animate money if changed
    if money and money ~= oldMoney then
        animateMoney(oldMoney, money)
    else
        moneyLabel.Text = tostring(currentMoney)
    end

    luckLabel.Text = string.format("%.1fx", currentLuck)

    -- Rebirth badge
    if currentRebirth > 0 then
        rebirthLabel.Text = "🔄 R" .. tostring(currentRebirth)
        rebirthBadge.Visible = true
    else
        rebirthBadge.Visible = false
    end
end

local function tryGetData()
    if GetDataFn and GetDataFn:IsA("RemoteFunction") then
        local ok, result = pcall(function()
            return GetDataFn:InvokeServer()
        end)
        if ok and type(result) == "table" then
            updateData(result.money, result.luck, result.rebirth)
        end
    end
end

-- Listen for DataEvent broadcasts if available
if DataEvent and DataEvent:IsA("RemoteEvent") then
    DataEvent.OnClientEvent:Connect(function(data)
        if type(data) == "table" then
            updateData(data.money, data.luck, data.rebirth)
        end
    end)
end

-- Initial data fetch
task.delay(1, tryGetData)

-- ============================================================
-- PART 2: DRAMATIC NOTIFICATION GUI
-- ============================================================
local dramaticGui = Instance.new("ScreenGui")
dramaticGui.Name = "DramaticNotif"
dramaticGui.DisplayOrder = 20
dramaticGui.ResetOnSpawn = false
dramaticGui.IgnoreGuiInset = true
dramaticGui.Parent = playerGui

local function showDramatic(text, color, duration, style)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.7, 0, 0, 80)
    label.AnchorPoint = Vector2.new(0.5, 0.5)
    label.Position = UDim2.new(0.5, 0, 0.38, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = color
    label.TextSize = 48
    label.Font = Enum.Font.GothamBlack
    label.TextStrokeTransparency = 0.4
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.TextScaled = false
    label.ZIndex = 20
    label.TextTransparency = 1
    label.Parent = dramaticGui

    if style == "drop" then
        -- Start tiny and grow in with Back easing
        label.TextSize = 14
        label.TextTransparency = 0.5
        TweenService:Create(label,
            TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            { TextSize = 48, TextTransparency = 0 }
        ):Play()

    elseif style == "slide" then
        -- Slide in from left
        label.Position = UDim2.new(-0.5, 0, 0.38, 0)
        label.TextTransparency = 0
        TweenService:Create(label,
            TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { Position = UDim2.new(0.5, 0, 0.38, 0) }
        ):Play()

    elseif style == "flash" then
        -- Rapid flashes then hold
        label.TextTransparency = 0
        local flashCount = 4
        for i = 1, flashCount do
            task.delay((i - 1) * 0.1, function()
                label.TextTransparency = 0
                task.delay(0.05, function()
                    label.TextTransparency = 0.6
                end)
            end)
        end
        task.delay(flashCount * 0.1, function()
            label.TextTransparency = 0
        end)
    end

    -- Hold then fade out
    task.delay(duration, function()
        if label and label.Parent then
            TweenService:Create(label,
                TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                { TextTransparency = 1 }
            ):Play()
            task.delay(0.45, function()
                if label and label.Parent then
                    label:Destroy()
                end
            end)
        end
    end)

    return label
end

local function showGoldFlash()
    local flash = Instance.new("Frame")
    flash.Size = UDim2.new(1, 0, 1, 0)
    flash.Position = UDim2.new(0, 0, 0, 0)
    flash.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
    flash.BackgroundTransparency = 0.85
    flash.BorderSizePixel = 0
    flash.ZIndex = 19
    flash.Parent = dramaticGui
    TweenService:Create(flash,
        TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { BackgroundTransparency = 1 }
    ):Play()
    task.delay(0.55, function()
        if flash and flash.Parent then flash:Destroy() end
    end)
end

-- ============================================================
-- PART 2: PlayerStatusFrame updates
-- ============================================================
local aliveCount = 0
local totalCount = 0

local function setStatusText(text, color)
    if statusLabel then
        statusLabel.Text = text
        if color then
            statusLabel.TextColor3 = color
        end
    end
end

local function flashStatusRed()
    if not playerStatusFrame then return end
    local stroke = playerStatusFrame:FindFirstChildWhichIsA("UIStroke")
    local origColor = stroke and stroke.Color or Color3.fromRGB(0, 240, 255)
    if stroke then
        stroke.Color = RED_ELIM
        TweenService:Create(stroke,
            TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { Color = origColor }
        ):Play()
    end
end

-- Pulsing LastSurvivor effect
local survivorPulseActive = false
local function startSurvivorPulse()
    survivorPulseActive = true
    task.spawn(function()
        while survivorPulseActive and statusLabel and statusLabel.Parent do
            TweenService:Create(statusLabel,
                TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                { TextColor3 = Color3.fromRGB(255, 255, 100) }
            ):Play()
            task.wait(0.5)
            TweenService:Create(statusLabel,
                TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                { TextColor3 = NEON_GOLD }
            ):Play()
            task.wait(0.5)
        end
    end)
end

local function stopSurvivorPulse()
    survivorPulseActive = false
    if statusLabel then
        statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    end
end

-- ============================================================
-- PART 3: LeaderFrame management
-- ============================================================
local playerRows = {} -- [playerName] = TextLabel

local function clearLeaderRows()
    for name, lbl in pairs(playerRows) do
        if lbl and lbl.Parent then
            lbl:Destroy()
        end
    end
    playerRows = {}
end

local function populateLeaderFrame()
    clearLeaderRows()
    -- Ensure UIListLayout exists (Subagent 1 may have added it already)
    local layout = leaderFrame:FindFirstChildWhichIsA("UIListLayout")
    if not layout then
        layout = Instance.new("UIListLayout")
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, 4)
        layout.Parent = leaderFrame
    end

    for _, p in ipairs(Players:GetPlayers()) do
        local row = Instance.new("TextLabel")
        row.Name = p.Name
        row.Size = UDim2.new(1, -16, 0, 28)
        row.BackgroundTransparency = 1
        row.Text = p.Name
        row.Font = Enum.Font.GothamBold
        row.TextSize = 18
        row.TextColor3 = Color3.fromRGB(255, 255, 255)
        row.TextXAlignment = Enum.TextXAlignment.Left
        local pad = Instance.new("UIPadding")
        pad.PaddingLeft = UDim.new(0, 10)
        pad.Parent = row
        row.Parent = leaderFrame
        playerRows[p.Name] = row
    end
end

local function markPlayerDead(name)
    local row = playerRows[name]
    if row then
        row.Text = "💀 " .. name
        row.TextColor3 = Color3.fromRGB(140, 140, 140)
    end
end

local function highlightWinner(name)
    local row = playerRows[name]
    if row then
        row.Text = "🏆 " .. name
        row.TextColor3 = NEON_GOLD
        row.TextSize = 22
    end
end

-- ============================================================
-- ROUND EVENT HANDLER
-- ============================================================
local isPlayerAlive = true

if RoundEvent then
    RoundEvent.OnClientEvent:Connect(function(eventType, data)
        data = data or {}

        if eventType == "LobbyCountdown" then
            -- Show PlayerStatusFrame in lobby state
            if playerStatusFrame then
                playerStatusFrame.Visible = true
            end
            stopSurvivorPulse()
            setStatusText("🎮 Lobby", Color3.fromRGB(200, 200, 200))
            -- Only show GET READY once (at low countdown)
            local t = data.time or data[1] or 0
            if type(t) == "number" and t <= 5 and t > 0 then
                showDramatic("🎮 GET READY!", NEON_CYAN, 2, "drop")
            end
            -- Hide leaderframe in lobby
            if leaderFrame then leaderFrame.Visible = false end

        elseif eventType == "RoundStart" then
            isPlayerAlive = true
            resetDeathCC()
            stopSurvivorPulse()

            -- Count players
            totalCount = #Players:GetPlayers()
            aliveCount = totalCount

            -- PlayerStatusFrame
            if playerStatusFrame then
                playerStatusFrame.Visible = true
            end
            setStatusText("👥 " .. aliveCount .. " alive", Color3.fromRGB(255, 255, 255))

            -- LeaderFrame
            if leaderFrame then
                leaderFrame.Visible = true
                populateLeaderFrame()
            end

            -- Dramatic: Round Starting
            showDramatic("🌪️ ROUND STARTING!", NEON_CYAN, 2.5, "drop")

            -- If mutation present, show mutation notification after brief delay
            local mutation = data.mutation or data[2]
            if mutation and mutation ~= "" and mutation ~= "None" then
                task.delay(0.8, function()
                    showDramatic("⚠️ MUTATION: " .. tostring(mutation) .. "!", NEON_GOLD, 2.5, "flash")
                end)
            end

            -- Refresh data after round starts
            task.delay(1.5, tryGetData)

        elseif eventType == "PlayerDied" then
            local name = data.name or data[1] or "Unknown"

            -- Decrement alive count
            aliveCount = math.max(0, aliveCount - 1)
            setStatusText("👥 " .. aliveCount .. " alive", Color3.fromRGB(255, 255, 255))
            flashStatusRed()

            -- Mark in leaderboard
            markPlayerDead(name)

            -- Dramatic notification
            showDramatic("💀 " .. name .. " eliminated", RED_ELIM, 2, "slide")

            -- Track if local player died
            if name == player.Name then
                isPlayerAlive = false
                applyDeathCC()
            end

        elseif eventType == "LastSurvivor" then
            local name = data.name or data[1] or "Unknown"

            -- PlayerStatus: Last One!
            setStatusText("🏆 LAST ONE!", NEON_GOLD)
            startSurvivorPulse()

            -- LeaderFrame: highlight winner
            highlightWinner(name)

            -- Gold screen flash
            showGoldFlash()

            -- Dramatic: big golden notification
            showDramatic("🏆 LAST PLAYER STANDING!", NEON_GOLD, 4, "drop")

        elseif eventType == "RoundEnd" then
            -- Determine if local player survived
            local survived = false
            local char = player.Character
            if char then
                local hum = char:FindFirstChildWhichIsA("Humanoid")
                survived = hum ~= nil and hum.Health > 0
            end
            -- Also use tracked flag
            if not isPlayerAlive then
                survived = false
            end

            resetDeathCC()

            if survived then
                showDramatic("✅ YOU SURVIVED!", GREEN_SURV, 3, "flash")
            else
                showDramatic("☠️ BETTER LUCK NEXT TIME", RED_DIED, 3, "slide")
            end

            -- Hide LeaderFrame after 3 seconds
            task.delay(3, function()
                if leaderFrame then leaderFrame.Visible = false end
            end)

            -- Reset status after a moment
            stopSurvivorPulse()
            task.delay(3.5, function()
                setStatusText("🎮 Lobby", Color3.fromRGB(200, 200, 200))
            end)

            -- Refresh money/luck after round ends (may have earned money)
            task.delay(1, tryGetData)
        end
    end)
end

-- ============================================================
-- DataEvent (if server adds one later)
-- ============================================================
-- Already connected above. This block is intentionally left brief.

-- ============================================================
-- PLAYER ADDED / REMOVED (keep counts fresh in lobby)
-- ============================================================
Players.PlayerAdded:Connect(function(p)
    if leaderFrame and leaderFrame.Visible then
        -- During a round: just note new player (rare edge case)
        totalCount = totalCount + 1
    end
end)

Players.PlayerRemoving:Connect(function(p)
    -- If they leave during a round, remove their row
    if playerRows[p.Name] then
        local row = playerRows[p.Name]
        if row and row.Parent then row:Destroy() end
        playerRows[p.Name] = nil
    end
end)

-- ============================================================
-- INITIAL SETUP: hide leaderframe, show status
-- ============================================================
if leaderFrame then leaderFrame.Visible = false end
if playerStatusFrame then playerStatusFrame.Visible = true end
setStatusText("🎮 Lobby", Color3.fromRGB(200, 200, 200))

-- ============================================================
-- DEATH COLOR CORRECTION
-- ============================================================
local deathCC = Instance.new("ColorCorrectionEffect")
deathCC.Name  = "GameFeel_DeathCC"
deathCC.Saturation  = 0
deathCC.Brightness  = 0
deathCC.Contrast    = 0
deathCC.TintColor   = Color3.fromRGB(255, 255, 255)
deathCC.Parent      = Lighting

local function resetDeathCC()
    TweenService:Create(deathCC,
        TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Saturation = 0, Brightness = 0, TintColor = Color3.fromRGB(255, 255, 255) }
    ):Play()
end

local function applyDeathCC()
    TweenService:Create(deathCC,
        TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Saturation = -1, Brightness = -0.2, TintColor = Color3.fromRGB(255, 180, 180) }
    ):Play()
end

-- Reset on character respawn
player.CharacterAdded:Connect(resetDeathCC)
