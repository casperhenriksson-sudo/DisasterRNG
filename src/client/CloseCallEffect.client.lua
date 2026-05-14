-- CloseCallEffect: client visual when health drops to ≤10
-- Red vignette flash, screen shake (camera offset oscillation), "CLOSE CALL!" toast

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local Lighting          = game:GetService("Lighting")
local RunService        = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local CloseCallEvent = ReplicatedStorage:WaitForChild("CloseCallEvent")

-- ── Create or reuse ColorCorrectionEffect ────────────────────────────────────
local colorCorrection = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
if not colorCorrection then
    colorCorrection = Instance.new("ColorCorrectionEffect")
    colorCorrection.Enabled = true
    colorCorrection.Parent  = Lighting
end

-- ── Build "CLOSE CALL!" GUI ───────────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "CloseCallGui"
screenGui.ResetOnSpawn   = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent         = localPlayer.PlayerGui

local toastFrame = Instance.new("Frame")
toastFrame.Size            = UDim2.new(0, 300, 0, 70)
toastFrame.AnchorPoint     = Vector2.new(0.5, 0.5)
toastFrame.Position        = UDim2.new(0.5, 0, 0.5, 0)
toastFrame.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
toastFrame.BackgroundTransparency = 0.3
toastFrame.BorderSizePixel = 0
toastFrame.Visible         = false
toastFrame.Parent          = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent       = toastFrame

local toastLabel = Instance.new("TextLabel")
toastLabel.Size                  = UDim2.new(1, 0, 1, 0)
toastLabel.BackgroundTransparency = 1
toastLabel.Text                  = "CLOSE CALL!"
toastLabel.TextColor3            = Color3.fromRGB(255, 255, 255)
toastLabel.TextScaled            = true
toastLabel.Font                  = Enum.Font.GothamBold
toastLabel.Parent                = toastFrame

-- ── Shake via camera CFrame offset ───────────────────────────────────────────
local shakeActive = false

local function doShake()
    if shakeActive then return end
    shakeActive = true

    local cam    = workspace.CurrentCamera
    local elapsed = 0
    local duration = 0.5
    local frequency = 10  -- oscillations per second (5 full cycles in 0.5s)

    local conn
    conn = RunService.Heartbeat:Connect(function(dt)
        elapsed = elapsed + dt
        local t = elapsed / duration
        if t >= 1 then
            conn:Disconnect()
            shakeActive = false
            cam.CFrame = cam.CFrame  -- let system resume naturally
            return
        end

        -- Oscillate amplitude fading out
        local amplitude = 3 * (1 - t)
        local offset = math.sin(elapsed * frequency * math.pi * 2) * amplitude
        -- Apply as a small CFrame offset (horizontal shake)
        local baseCF = cam.CFrame
        cam.CFrame = baseCF * CFrame.new(offset, 0, 0)
    end)
end

-- ── Vignette flash (ColorCorrection saturation + tint) ───────────────────────
local vignetteActive = false

local function doVignette()
    if vignetteActive then return end
    vignetteActive = true

    -- Spike saturation and red tint
    local spikeTween = TweenService:Create(colorCorrection,
        TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Saturation = -0.5,
            TintColor  = Color3.fromRGB(255, 100, 100),
        })
    spikeTween:Play()
    spikeTween.Completed:Wait()

    -- Fade back to neutral
    local fadeTween = TweenService:Create(colorCorrection,
        TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Saturation = 0,
            TintColor  = Color3.fromRGB(128, 128, 128),
        })
    fadeTween:Play()
    fadeTween.Completed:Wait()
    vignetteActive = false
end

-- ── Toast display ─────────────────────────────────────────────────────────────
local toastActive = false

local function showToast()
    if toastActive then return end
    toastActive = true
    toastFrame.Visible = true

    -- Fade in
    toastFrame.BackgroundTransparency = 1
    toastLabel.TextTransparency       = 1
    TweenService:Create(toastFrame, TweenInfo.new(0.15), {BackgroundTransparency = 0.3}):Play()
    TweenService:Create(toastLabel, TweenInfo.new(0.15), {TextTransparency = 0}):Play()

    task.delay(1.5, function()
        -- Fade out
        TweenService:Create(toastFrame, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
        TweenService:Create(toastLabel, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
        task.delay(0.3, function()
            toastFrame.Visible = false
            toastActive = false
        end)
    end)
end

-- ── Wire to event ─────────────────────────────────────────────────────────────
CloseCallEvent.OnClientEvent:Connect(function()
    task.spawn(doVignette)
    task.spawn(doShake)
    task.spawn(showToast)
end)
