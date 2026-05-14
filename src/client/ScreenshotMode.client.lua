-- ScreenshotMode: F2 toggle — hides HUD, enables free camera
-- Uses CameraStateManager priority 0 (lowest, overridden by any other system)

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")

local CameraStateManager = require(script.Parent.CameraStateManager)

local localPlayer = Players.LocalPlayer

-- ── HUD ScreenGui names to hide ───────────────────────────────────────────────
local HUD_GUI_NAMES = {
    "GameUI", "GameFeel_HUD", "DramaticNotif", "SprintGui", "HypeGui",
    "LeaderboardGui", "PracticeGui", "SpinButtonGui", "InventoryGui", "QuestGui",
    -- Common variants
    "HUDGui", "RoundGui", "StreakDisplayGui",
}

-- ── Build the "F2 to exit" status label ──────────────────────────────────────
local statusGui = Instance.new("ScreenGui")
statusGui.Name           = "ScreenshotModeGui"
statusGui.ResetOnSpawn   = false
statusGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
statusGui.Parent         = localPlayer.PlayerGui

local statusLabel = Instance.new("TextLabel")
statusLabel.Size                   = UDim2.new(0, 280, 0, 28)
statusLabel.Position               = UDim2.new(0.5, -140, 0, 10)
statusLabel.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
statusLabel.BackgroundTransparency = 0.5
statusLabel.BorderSizePixel        = 0
statusLabel.TextColor3             = Color3.fromRGB(255, 255, 255)
statusLabel.TextScaled             = true
statusLabel.Font                   = Enum.Font.Gotham
statusLabel.Text                   = "📷 Screenshot Mode — F2 to exit"
statusLabel.Visible                = false
statusLabel.Parent                 = statusGui

local labelCorner = Instance.new("UICorner")
labelCorner.CornerRadius = UDim.new(0, 6)
labelCorner.Parent       = statusLabel

-- ── State ─────────────────────────────────────────────────────────────────────
local active            = false
local hiddenGuis        = {}   -- {gui, wasVisible} pairs restored on exit
local freeCamConn       = nil  -- RunService connection for free camera
local freeCamCFrame     = nil  -- current free camera CFrame
local MOVE_SPEED        = 0.5  -- studs per frame (60fps base)
local LOOK_SENSITIVITY  = 0.3  -- degrees per pixel

-- ── Find ScreenGuis by name in PlayerGui + CoreGui (where accessible) ─────────
local function collectGuis()
    local found = {}
    for _, name in ipairs(HUD_GUI_NAMES) do
        local gui = localPlayer.PlayerGui:FindFirstChild(name)
        if gui and gui:IsA("ScreenGui") then
            table.insert(found, {gui = gui, wasVisible = gui.Enabled})
        end
    end
    return found
end

-- ── Free camera logic ─────────────────────────────────────────────────────────
local yaw   = 0
local pitch = 0

local function initFreeCam()
    local cam = workspace.CurrentCamera
    freeCamCFrame = cam.CFrame
    -- Decompose yaw/pitch from current camera CFrame
    local lookDir = cam.CFrame.LookVector
    yaw   = math.deg(math.atan2(-lookDir.X, -lookDir.Z))
    pitch = math.deg(math.asin(lookDir.Y))
end

local function updateFreeCam(dt)
    local cam = workspace.CurrentCamera
    if CameraStateManager.getActive() ~= "ScreenshotMode" then return end

    -- Mouse look
    local delta = UserInputService:GetMouseDelta()
    yaw   = yaw   - delta.X * LOOK_SENSITIVITY
    pitch = math.clamp(pitch - delta.Y * LOOK_SENSITIVITY, -89, 89)

    -- WASD movement
    local moveVec = Vector3.zero
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVec = moveVec + Vector3.new(0, 0, -1) end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVec = moveVec + Vector3.new(0, 0,  1) end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVec = moveVec + Vector3.new(-1, 0, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVec = moveVec + Vector3.new( 1, 0, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.E) then moveVec = moveVec + Vector3.new(0,  1, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.Q) then moveVec = moveVec + Vector3.new(0, -1, 0) end

    -- Build rotation CFrame
    local rotCF = CFrame.Angles(0, math.rad(yaw), 0) * CFrame.Angles(math.rad(pitch), 0, 0)

    -- Move in camera-local space
    if moveVec.Magnitude > 0 then
        local worldMove = rotCF:VectorToWorldSpace(moveVec.Unit * MOVE_SPEED * 60 * dt)
        freeCamCFrame = CFrame.new(freeCamCFrame.Position + worldMove) * rotCF
    else
        freeCamCFrame = CFrame.new(freeCamCFrame.Position) * rotCF
    end

    cam.CFrame = freeCamCFrame
end

-- ── Activate ─────────────────────────────────────────────────────────────────
local function activate()
    active = true

    -- Collect and hide HUD guis
    hiddenGuis = collectGuis()
    for _, entry in ipairs(hiddenGuis) do
        entry.gui.Enabled = false
    end

    -- Show status label
    statusLabel.Visible = true

    -- Push camera
    CameraStateManager.push("ScreenshotMode", 0)

    -- Init free cam from current camera position
    initFreeCam()

    -- Lock mouse
    UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter

    -- Start update loop
    freeCamConn = RunService.RenderStepped:Connect(function(dt)
        if not active then return end
        updateFreeCam(dt)
    end)
end

-- ── Deactivate ────────────────────────────────────────────────────────────────
local function deactivate()
    active = false

    if freeCamConn then
        freeCamConn:Disconnect()
        freeCamConn = nil
    end

    -- Restore hidden guis
    for _, entry in ipairs(hiddenGuis) do
        if entry.gui and entry.gui.Parent then
            entry.gui.Enabled = entry.wasVisible
        end
    end
    hiddenGuis = {}

    -- Hide status label
    statusLabel.Visible = false

    -- Pop camera
    CameraStateManager.pop("ScreenshotMode")

    -- Unlock mouse
    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
end

-- ── F2 toggle ─────────────────────────────────────────────────────────────────
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.F2 then
        if active then
            deactivate()
        else
            activate()
        end
    end
end)

-- Deactivate cleanly if player respawns
localPlayer.CharacterAdded:Connect(function()
    if active then
        deactivate()
    end
end)
