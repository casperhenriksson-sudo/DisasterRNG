-- DisasterUI LocalScript — Rewritten with juicy animations
-- Agent 1 (UI Animator) — Disaster RNG

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")
local Players          = game:GetService("Players")

local RoundEvent = ReplicatedStorage:WaitForChild("RoundEvent")

local player = Players.LocalPlayer
local gui    = player.PlayerGui:WaitForChild("GameUI")

-- DisasterFrame children
local DisasterFrame = gui:WaitForChild("DisasterFrame")
local DisasterName  = DisasterFrame:WaitForChild("DisasterName")
local MutationLabel = DisasterFrame:WaitForChild("MutationLabel")
local TitleLabel    = DisasterFrame:WaitForChild("TextLabel")
local IconLabel     = DisasterFrame:WaitForChild("DisasterIcon")
local TimerBG       = DisasterFrame:WaitForChild("TimerBG")
local TimerFill     = TimerBG:WaitForChild("TimerFill")
local UIStroke      = DisasterFrame:WaitForChild("UIStroke")
local UIGradient    = DisasterFrame:WaitForChild("UIGradient")

-- SpinFrame (shown on RoundEnd)
local SpinFrame = gui:WaitForChild("SpinFrame")
local spinFrameOrigSize = SpinFrame and SpinFrame.Size or UDim2.new(0.55, 0, 0.45, 0)

-- ─── Disaster data ────────────────────────────────────────────────────────────
local disasterData = {
    ["Tornado"]       = { icon = "🌪️", color = Color3.fromRGB(150, 150, 200) },
    ["Flood"]            = { icon = "🌊", color = Color3.fromRGB(50, 100, 255) },
    ["Meteor Strike"]   = { icon = "☄️", color = Color3.fromRGB(255, 100, 50) },
    ["Lightning Storm"] = { icon = "⚡", color = Color3.fromRGB(255, 255, 100) },
    ["Volcanic Eruption"] = { icon = "🌋", color = Color3.fromRGB(255, 80, 30) },
    ["Blizzard"]      = { icon = "❄️", color = Color3.fromRGB(150, 220, 255) },
    ["Earthquake"]      = { icon = "🏔️", color = Color3.fromRGB(180, 140, 100) },
    ["Tsunami"]       = { icon = "🌊", color = Color3.fromRGB(30, 80, 255) },
    ["Acid Rain"]       = { icon = "☠️", color = Color3.fromRGB(100, 255, 80) },
    ["Sandstorm"]     = { icon = "🏜️", color = Color3.fromRGB(220, 180, 80) },
}

-- ─── State ────────────────────────────────────────────────────────────────────
local hideThread      = nil
local iconPulseConn   = nil   -- RunService connection for icon pulse loop
local iconPulseTween  = nil   -- current icon tween (so we can cancel)

-- ─── Flash overlay (created once in code) ─────────────────────────────────────
local FlashOverlay = Instance.new("Frame")
FlashOverlay.Name             = "FlashOverlay"
FlashOverlay.Size             = UDim2.new(1, 0, 1, 0)
FlashOverlay.Position         = UDim2.new(0, 0, 0, 0)
FlashOverlay.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
FlashOverlay.BackgroundTransparency = 1
FlashOverlay.ZIndex           = 100
FlashOverlay.BorderSizePixel  = 0
FlashOverlay.Parent           = gui

-- ─── Helpers ──────────────────────────────────────────────────────────────────
local function tween(instance, info, props)
    local t = TweenService:Create(instance, info, props)
    t:Play()
    return t
end

-- ─── Screen shake ─────────────────────────────────────────────────────────────
local function doScreenShake(duration, intensity)
    local camera    = workspace.CurrentCamera
    local elapsed   = 0
    local baseCF    = camera.CFrame
    local shakeConn

    shakeConn = RunService.Heartbeat:Connect(function(dt)
        elapsed += dt
        if elapsed >= duration then
            -- Restore camera offset and disconnect
            camera.CFrame = baseCF
            shakeConn:Disconnect()
            return
        end
        -- Diminish over time: factor goes 1 → 0
        local factor = 1 - (elapsed / duration)
        local mag    = intensity * factor
        local offset = Vector3.new(
            (math.random() * 2 - 1) * mag,
            (math.random() * 2 - 1) * mag,
            0
        )
        camera.CFrame = baseCF * CFrame.new(offset)
    end)
end

-- ─── Flash overlay trigger ────────────────────────────────────────────────────
local function doFlash()
    FlashOverlay.BackgroundTransparency = 0
    tween(FlashOverlay,
        TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { BackgroundTransparency = 1 }
    )
end

-- ─── Icon pulse loop (starts after frame is visible) ─────────────────────────
local ICON_BASE_SIZE   = UDim2.new(0, 60, 0, 60)
local ICON_LARGE_SIZE  = UDim2.new(0, 74, 0, 74)
local ICON_PULSE_TIME  = 0.55

local function startIconPulse()
    -- Cancel any previous pulse
    if iconPulseConn then iconPulseConn:Disconnect(); iconPulseConn = nil end
    if iconPulseTween then iconPulseTween:Cancel(); iconPulseTween = nil end

    local growing = true
    local function step()
        if growing then
            iconPulseTween = tween(IconLabel,
                TweenInfo.new(ICON_PULSE_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                { Size = ICON_LARGE_SIZE }
            )
        else
            iconPulseTween = tween(IconLabel,
                TweenInfo.new(ICON_PULSE_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                { Size = ICON_BASE_SIZE }
            )
        end
        growing = not growing
    end

    step() -- kick off immediately
    iconPulseConn = RunService.Heartbeat:Connect(function()
        -- Drive pulse via tween Completed; we poll IconLabel.Size against target
        -- Actually easier: re-schedule via a looped task
    end)
    -- Disconnect the placeholder heartbeat right away; use recursive task.delay instead
    iconPulseConn:Disconnect()
    iconPulseConn = nil

    local function loopPulse()
        if iconPulseTween then
            iconPulseTween.Completed:Wait()
        end
        -- Check if we're still supposed to be pulsing (iconPulseTween still set)
        if iconPulseTween == nil then return end
        step()
        task.delay(ICON_PULSE_TIME, loopPulse)
    end
    task.delay(ICON_PULSE_TIME, loopPulse)
end

local function stopIconPulse()
    if iconPulseConn  then iconPulseConn:Disconnect(); iconPulseConn = nil end
    if iconPulseTween then iconPulseTween:Cancel();    iconPulseTween = nil end
    -- Snap icon back to base size cleanly
    tween(IconLabel,
        TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Size = ICON_BASE_SIZE }
    )
end

-- ─── Timer bar color shift (green → yellow → red) ────────────────────────────
local function animateTimerBar()
    -- Reset colour to green first
    TimerFill.BackgroundColor3 = Color3.fromRGB(0, 200, 100)

    -- Green → Yellow over first 5 s
    local t1 = tween(TimerFill,
        TweenInfo.new(5, Enum.EasingStyle.Linear),
        { BackgroundColor3 = Color3.fromRGB(255, 200, 0) }
    )
    t1.Completed:Connect(function(state)
        if state ~= Enum.PlaybackState.Completed then return end
        -- Yellow → Red over next 5 s
        tween(TimerFill,
            TweenInfo.new(5, Enum.EasingStyle.Linear),
            { BackgroundColor3 = Color3.fromRGB(255, 50, 50) }
        )
    end)
end

-- ─── UIStroke / UIGradient glow ───────────────────────────────────────────────
local function applyDisasterTheme(color)
    -- Stroke: thickness 0 → 4, color → disaster color
    UIStroke.Thickness = 0
    UIStroke.Color     = Color3.fromRGB(255, 255, 255)
    tween(UIStroke,
        TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Thickness = 4, Color = color }
    )

    -- Gradient: fade from disaster color (left) to dark (right)
    local darkColor = Color3.fromRGB(
        math.floor(color.R * 255 * 0.15),
        math.floor(color.G * 255 * 0.15),
        math.floor(color.B * 255 * 0.15)
    )
    UIGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, color),
        ColorSequenceKeypoint.new(1, darkColor),
    })
end

-- ─── Hide ─────────────────────────────────────────────────────────────────────
local function hideDisaster()
    stopIconPulse()

    -- Simultaneously slide up AND scale to zero
    tween(DisasterFrame,
        TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In),
        {
            Position = UDim2.new(0.5, -230, 0, -180),
            Size     = UDim2.new(0, 0, 0, 0),
        }
    )
    task.delay(0.35, function()
        DisasterFrame.Visible = false
        -- Reset size so next show works correctly
        DisasterFrame.Size = UDim2.new(0, 460, 0, 175)
    end)
end

-- ─── Show ─────────────────────────────────────────────────────────────────────
local function showDisaster(name, mutation)
    local data = disasterData[name] or { icon = "⚠️", color = Color3.fromRGB(255, 80, 80) }

    -- Populate labels
    DisasterName.Text      = data.icon .. " " .. name
    DisasterName.TextColor3 = data.color
    TitleLabel.Text        = "⚡ DISASTER INCOMING"
    IconLabel.Text         = data.icon
    IconLabel.Size         = ICON_BASE_SIZE
    MutationLabel.Text     = mutation and ("✨ Mutation: " .. mutation) or ""
    MutationLabel.Visible  = mutation ~= nil

    -- Reset timer fill
    TimerFill.Size = UDim2.new(1, 0, 1, 0)

    -- Apply disaster theme (stroke glow + gradient)
    applyDisasterTheme(data.color)

    -- Position off-screen above, full size, then make visible
    DisasterFrame.Size     = UDim2.new(0, 460, 0, 175)
    DisasterFrame.Position = UDim2.new(0.5, -230, 0, -200)
    DisasterFrame.Visible  = true

    -- Flash overlay
    doFlash()

    -- Overshoot slide-in (bigger spring feel than old 0.5 s Back)
    tween(DisasterFrame,
        TweenInfo.new(0.7, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0),
        { Position = UDim2.new(0.5, -230, 0, 20) }
    )

    -- Timer shrink (size)
    tween(TimerFill,
        TweenInfo.new(10, Enum.EasingStyle.Linear),
        { Size = UDim2.new(0, 0, 1, 0) }
    )

    -- Timer bar color shift
    animateTimerBar()

    -- Start icon pulse after frame arrives
    task.delay(0.7, startIconPulse)

    -- Cancel any pending auto-hide, schedule a new one
    if hideThread then task.cancel(hideThread) end
    hideThread = task.delay(10, hideDisaster)
end

-- ─── SpinFrame bounce entrance ────────────────────────────────────────────────
local function showSpinFrame()
    SpinFrame.Size    = UDim2.new(0, 0, 0, 0)
    SpinFrame.Visible = true
    -- Overshoot to 110% then settle to natural size
    tween(SpinFrame,
        TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Size = spinFrameOrigSize }   -- cached from SpinFrame.Size at script load
    )
end

-- ─── Init ─────────────────────────────────────────────────────────────────────
DisasterFrame.Visible = false

RoundEvent.OnClientEvent:Connect(function(eventType, data)
    if eventType == "RoundStart" then
        showDisaster(data.disaster, data.mutation)
    elseif eventType == "RoundEnd" then
        hideDisaster()
        showSpinFrame()
    end
end)

print("✅ DisasterUI active! (Rewritten — juicy animations)")
