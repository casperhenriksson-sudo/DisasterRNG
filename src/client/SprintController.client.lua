-- SprintController  (StarterPlayerScripts)
-- Hold Shift to sprint at 1.5x speed. 5s stamina, 3s refill.
-- WalkSpeed is ALWAYS set server-side — this script only requests and draws the UI.

local Players         = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService      = game:GetService("RunService")
local TweenService    = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- Wait for SprintRequest remote (created by SprintHandler.server)
local SprintRequest = ReplicatedStorage:WaitForChild("SprintRequest", 10)
if not SprintRequest then return end

-- ── Stamina constants (mirrored from server) ──────────────────────────────────
local MAX_STAMINA  = 5      -- seconds
local DRAIN_RATE   = 1      -- per second while sprinting
local REFILL_RATE  = 1 / 3  -- per second when not sprinting (refills in ~3s)

-- ── Local stamina for smooth UI (server is authoritative for speed) ───────────
local stamina      = MAX_STAMINA
local isSprinting  = false
local wasExhausted = false  -- prevents re-requesting sprint until bar refills 30%

-- ── Build stamina bar UI ──────────────────────────────────────────────────────
local playerGui = player:WaitForChild("PlayerGui")
local gui = Instance.new("ScreenGui")
gui.Name = "SprintGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 10
gui.Parent = playerGui

local barBG = Instance.new("Frame")
barBG.Name = "StaminaBG"
barBG.Size = UDim2.new(0, 160, 0, 14)
barBG.Position = UDim2.new(0.5, -80, 1, -50)
barBG.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
barBG.BackgroundTransparency = 0.4
barBG.BorderSizePixel = 0
barBG.Parent = gui
Instance.new("UICorner", barBG).CornerRadius = UDim.new(0, 6)

local barFill = Instance.new("Frame")
barFill.Name = "StaminaFill"
barFill.Size = UDim2.new(1, 0, 1, 0)
barFill.BackgroundColor3 = Color3.fromRGB(80, 220, 120)
barFill.BorderSizePixel = 0
barFill.Parent = barBG
Instance.new("UICorner", barFill).CornerRadius = UDim.new(0, 6)

local barLabel = Instance.new("TextLabel")
barLabel.Size = UDim2.new(1, 0, 0, 16)
barLabel.Position = UDim2.new(0, 0, -1.3, 0)
barLabel.BackgroundTransparency = 1
barLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
barLabel.Font = Enum.Font.GothamBold
barLabel.TextSize = 11
barLabel.Text = "STAMINA  [SHIFT]"
barLabel.Parent = barBG

-- Only show bar when stamina is not full
barBG.Visible = false

-- ── Input handling ────────────────────────────────────────────────────────────
local function requestSprint(on)
    if SprintRequest then
        pcall(function() SprintRequest:FireServer(on) end)
    end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
        if not wasExhausted and stamina > 0.1 then
            isSprinting = true
            requestSprint(true)
            barBG.Visible = true
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
        if isSprinting then
            isSprinting = false
            requestSprint(false)
        end
    end
end)

-- ── Stamina update loop (visual only — server is authoritative) ───────────────
RunService.Heartbeat:Connect(function(dt)
    if isSprinting then
        stamina = math.max(0, stamina - DRAIN_RATE * dt)
        if stamina <= 0 then
            isSprinting = false
            wasExhausted = true
            requestSprint(false)
        end
    else
        local prevStamina = stamina
        stamina = math.min(MAX_STAMINA, stamina + REFILL_RATE * dt)
        -- Once refilled past 30% after exhaustion, allow sprinting again
        if wasExhausted and stamina >= MAX_STAMINA * 0.3 then
            wasExhausted = false
        end
        -- Hide bar when full
        if stamina >= MAX_STAMINA and barBG.Visible then
            barBG.Visible = false
        end
    end

    -- Update fill width and color
    local pct = stamina / MAX_STAMINA
    barFill.Size = UDim2.new(pct, 0, 1, 0)
    if pct < 0.25 then
        barFill.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
    elseif pct < 0.6 then
        barFill.BackgroundColor3 = Color3.fromRGB(255, 180, 40)
    else
        barFill.BackgroundColor3 = Color3.fromRGB(80, 220, 120)
    end
end)
