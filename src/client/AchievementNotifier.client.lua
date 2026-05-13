-- AchievementNotifier  (StarterPlayerScripts)
-- Shows a slide-in toast when an achievement is earned.

local Players         = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService    = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local AchievementEvent = ReplicatedStorage:WaitForChild("AchievementEvent", 15)
if not AchievementEvent then return end

-- Build toast GUI
local gui = Instance.new("ScreenGui")
gui.Name = "AchievementGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 50
gui.Parent = playerGui

-- Queue so multiple achievements don't overlap
local queue = {}
local showing = false

local function showNext()
    if showing or #queue == 0 then return end
    showing = true
    local ach = table.remove(queue, 1)

    local toast = Instance.new("Frame")
    toast.Size = UDim2.new(0, 320, 0, 72)
    toast.Position = UDim2.new(1, 10, 0.15, 0)  -- starts off-screen right
    toast.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
    toast.BackgroundTransparency = 0.1
    toast.BorderSizePixel = 0
    toast.Parent = gui
    Instance.new("UICorner", toast).CornerRadius = UDim.new(0, 12)

    -- Gold left border accent
    local accent = Instance.new("Frame")
    accent.Size = UDim2.new(0, 5, 1, 0)
    accent.BackgroundColor3 = Color3.fromRGB(255, 200, 30)
    accent.BorderSizePixel = 0
    accent.Parent = toast
    Instance.new("UICorner", accent).CornerRadius = UDim.new(0, 4)

    -- Icon
    local iconLabel = Instance.new("TextLabel")
    iconLabel.Size = UDim2.new(0, 50, 1, 0)
    iconLabel.Position = UDim2.new(0, 8, 0, 0)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Font = Enum.Font.GothamBold
    iconLabel.TextSize = 28
    iconLabel.Text = ach.icon or "🏅"
    iconLabel.Parent = toast

    -- "Achievement Unlocked!" header
    local header = Instance.new("TextLabel")
    header.Size = UDim2.new(1, -70, 0, 22)
    header.Position = UDim2.new(0, 60, 0, 8)
    header.BackgroundTransparency = 1
    header.Font = Enum.Font.GothamBold
    header.TextSize = 12
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.Text = "ACHIEVEMENT UNLOCKED"
    header.TextColor3 = Color3.fromRGB(255, 200, 30)
    header.Parent = toast

    -- Achievement name
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -70, 0, 24)
    nameLabel.Position = UDim2.new(0, 60, 0, 26)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 17
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Text = ach.name or "?"
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.Parent = toast

    -- Description
    local descLabel = Instance.new("TextLabel")
    descLabel.Size = UDim2.new(1, -70, 0, 18)
    descLabel.Position = UDim2.new(0, 60, 0, 48)
    descLabel.BackgroundTransparency = 1
    descLabel.Font = Enum.Font.Gotham
    descLabel.TextSize = 12
    descLabel.TextXAlignment = Enum.TextXAlignment.Left
    descLabel.Text = ach.desc or ""
    descLabel.TextColor3 = Color3.fromRGB(160, 160, 190)
    descLabel.Parent = toast

    -- Slide in
    TweenService:Create(toast, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(1, -330, 0.15, 0)
    }):Play()

    task.wait(3.5)

    -- Slide out
    TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Position = UDim2.new(1, 10, 0.15, 0)
    }):Play()
    task.delay(0.35, function()
        toast:Destroy()
        showing = false
        showNext()
    end)
end

AchievementEvent.OnClientEvent:Connect(function(eventType, data)
    if eventType == "earned" then
        table.insert(queue, data)
        task.spawn(showNext)
    end
end)
