-- LobbyHUD  (StarterPlayerScripts)
-- Shows: join hype toasts, live leaderboard, practice mode button.

local Players         = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService    = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local LobbyEvent   = ReplicatedStorage:WaitForChild("LobbyEvent",   15)
local LobbyRequest = ReplicatedStorage:WaitForChild("LobbyRequest", 15)
local RoundEvent   = ReplicatedStorage:WaitForChild("RoundEvent",   15)
if not LobbyEvent then return end

-- Track round state — hide lobby UI during rounds
local inRound = false

-- ── Hype toast (bottom-center, slides up and fades) ───────────────────────────
local hypeGui = Instance.new("ScreenGui")
hypeGui.Name = "HypeGui"
hypeGui.ResetOnSpawn = false
hypeGui.DisplayOrder = 8
hypeGui.Parent = playerGui

local function showHype(text, color)
    local toast = Instance.new("TextLabel")
    toast.Size = UDim2.new(0, 400, 0, 36)
    toast.Position = UDim2.new(0.5, -200, 0.88, 0)
    toast.BackgroundTransparency = 1
    toast.Font = Enum.Font.GothamBold
    toast.TextSize = 16
    toast.Text = text
    toast.TextColor3 = color or Color3.fromRGB(255, 255, 255)
    toast.TextTransparency = 0
    toast.Parent = hypeGui

    TweenService:Create(toast, TweenInfo.new(2, Enum.EasingStyle.Quad), {
        Position = UDim2.new(0.5, -200, 0.82, 0),
        TextTransparency = 1,
    }):Play()
    task.delay(2.1, function() toast:Destroy() end)
end

-- ── Leaderboard panel (top-right, shown in lobby) ─────────────────────────────
local lbGui = Instance.new("ScreenGui")
lbGui.Name = "LeaderboardGui"
lbGui.ResetOnSpawn = false
lbGui.DisplayOrder = 6
lbGui.Parent = playerGui

local lbPanel = Instance.new("Frame")
lbPanel.Name = "LeaderPanel"
lbPanel.Size = UDim2.new(0, 200, 0, 260)
lbPanel.Position = UDim2.new(1, -215, 0.5, -130)
lbPanel.BackgroundColor3 = Color3.fromRGB(10, 10, 25)
lbPanel.BackgroundTransparency = 0.25
lbPanel.BorderSizePixel = 0
lbPanel.Visible = true
lbPanel.Parent = lbGui
Instance.new("UICorner", lbPanel).CornerRadius = UDim.new(0, 12)

local lbTitle = Instance.new("TextLabel")
lbTitle.Size = UDim2.new(1, 0, 0, 30)
lbTitle.Position = UDim2.new(0, 0, 0, 4)
lbTitle.BackgroundTransparency = 1
lbTitle.Font = Enum.Font.GothamBlack
lbTitle.TextSize = 14
lbTitle.Text = "🏆  TOP WINS  🏆"
lbTitle.TextColor3 = Color3.fromRGB(255, 210, 40)
lbTitle.Parent = lbPanel

local lbList = Instance.new("Frame")
lbList.Size = UDim2.new(1, -10, 1, -38)
lbList.Position = UDim2.new(0, 5, 0, 36)
lbList.BackgroundTransparency = 1
lbList.Parent = lbPanel

local lbLayout = Instance.new("UIListLayout")
lbLayout.SortOrder = Enum.SortOrder.LayoutOrder
lbLayout.Padding = UDim.new(0, 2)
lbLayout.Parent = lbList

local lbRows = {}

local function updateLeaderboard(entries)
    -- Remove old rows
    for _, row in ipairs(lbRows) do
        if row.Parent then row:Destroy() end
    end
    lbRows = {}

    if #entries == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size = UDim2.new(1, 0, 0, 22)
        empty.BackgroundTransparency = 1
        empty.Font = Enum.Font.Gotham
        empty.TextSize = 12
        empty.Text = "No data yet"
        empty.TextColor3 = Color3.fromRGB(140, 140, 160)
        empty.Parent = lbList
        table.insert(lbRows, empty)
        return
    end

    for i, entry in ipairs(entries) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 22)
        row.BackgroundTransparency = i == 1 and 0.6 or 0.85
        row.BackgroundColor3 = i == 1 and Color3.fromRGB(255, 200, 30) or Color3.fromRGB(40, 40, 60)
        row.BorderSizePixel = 0
        row.LayoutOrder = i
        row.Parent = lbList
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 4)

        -- Medal / number
        local medals = {"🥇", "🥈", "🥉"}
        local rankText = medals[i] or ("#" .. i)
        local rankLabel = Instance.new("TextLabel")
        rankLabel.Size = UDim2.new(0, 28, 1, 0)
        rankLabel.BackgroundTransparency = 1
        rankLabel.Font = Enum.Font.GothamBold
        rankLabel.TextSize = 12
        rankLabel.Text = rankText
        rankLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        rankLabel.Parent = row

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, -70, 1, 0)
        nameLabel.Position = UDim2.new(0, 28, 0, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Font = Enum.Font.Gotham
        nameLabel.TextSize = 12
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.Text = entry.name
        nameLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
        nameLabel.Parent = row

        local winsLabel = Instance.new("TextLabel")
        winsLabel.Size = UDim2.new(0, 40, 1, 0)
        winsLabel.Position = UDim2.new(1, -44, 0, 0)
        winsLabel.BackgroundTransparency = 1
        winsLabel.Font = Enum.Font.GothamBold
        winsLabel.TextSize = 12
        winsLabel.Text = tostring(entry.wins) .. "W"
        winsLabel.TextColor3 = Color3.fromRGB(255, 210, 60)
        winsLabel.Parent = row

        table.insert(lbRows, row)
    end
end

-- ── Practice Mode button ──────────────────────────────────────────────────────
local practiceGui = Instance.new("ScreenGui")
practiceGui.Name = "PracticeGui"
practiceGui.ResetOnSpawn = false
practiceGui.DisplayOrder = 7
practiceGui.Parent = playerGui

local practiceBtn = Instance.new("TextButton")
practiceBtn.Name = "PracticeButton"
practiceBtn.Size = UDim2.new(0, 180, 0, 44)
practiceBtn.Position = UDim2.new(0.5, -90, 0, 16)
practiceBtn.BackgroundColor3 = Color3.fromRGB(40, 120, 255)
practiceBtn.BorderSizePixel = 0
practiceBtn.Font = Enum.Font.GothamBold
practiceBtn.TextSize = 15
practiceBtn.Text = "⚡ PRACTICE DISASTER"
practiceBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
practiceBtn.Visible = true
practiceBtn.Parent = practiceGui
Instance.new("UICorner", practiceBtn).CornerRadius = UDim.new(0, 10)

local practiceStatus = Instance.new("TextLabel")
practiceStatus.Size = UDim2.new(0, 180, 0, 22)
practiceStatus.Position = UDim2.new(0.5, -90, 0, 62)
practiceStatus.BackgroundTransparency = 1
practiceStatus.Font = Enum.Font.Gotham
practiceStatus.TextSize = 12
practiceStatus.Text = "Solo 30s disaster preview"
practiceStatus.TextColor3 = Color3.fromRGB(160, 200, 255)
practiceStatus.Visible = true
practiceStatus.Parent = practiceGui

local practicing = false

practiceBtn.MouseButton1Click:Connect(function()
    if practicing then return end
    if LobbyRequest then
        LobbyRequest:FireServer("startPractice")
    end
end)

-- ── Event handling ────────────────────────────────────────────────────────────
LobbyEvent.OnClientEvent:Connect(function(eventName, data)
    if eventName == "playerJoined" then
        if not inRound and type(data) == "table" then
            showHype("Welcome " .. data.name .. "!  " .. data.count .. " players in lobby",
                Color3.fromRGB(100, 220, 255))
        end

    elseif eventName == "roundSoon" then
        if not inRound then
            showHype("Round starting soon!", Color3.fromRGB(255, 210, 60))
        end

    elseif eventName == "leaderboard" then
        if not inRound and type(data) == "table" then
            updateLeaderboard(data)
        end

    elseif eventName == "practiceStart" then
        practicing = true
        practiceBtn.BackgroundColor3 = Color3.fromRGB(200, 80, 40)
        practiceBtn.Text = "⚡ PRACTICING..."
        practiceStatus.Text = "30 seconds — survive!"

    elseif eventName == "practiceEnd" then
        practicing = false
        practiceBtn.BackgroundColor3 = Color3.fromRGB(40, 120, 255)
        practiceBtn.Text = "⚡ PRACTICE DISASTER"
        practiceStatus.Text = "Solo 30s disaster preview"

    elseif eventName == "practiceError" then
        practiceStatus.Text = tostring(data)
        task.delay(2, function()
            practiceStatus.Text = "Solo 30s disaster preview"
        end)
    end
end)

if RoundEvent then
    RoundEvent.OnClientEvent:Connect(function(eventName)
        if eventName == "RoundStart" then
            inRound = true
            lbPanel.Visible = false
            practiceBtn.Visible = false
            practiceStatus.Visible = false
        elseif eventName == "RoundEnd" or eventName == "LobbyWaiting" then
            inRound = false
            lbPanel.Visible = true
            practiceBtn.Visible = true
            practiceStatus.Visible = true
            practicing = false
        end
    end)
end
