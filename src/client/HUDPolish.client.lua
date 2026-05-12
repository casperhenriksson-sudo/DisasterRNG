-- HUDPolish LocalScript
-- Adds idle animations, breathing effects, and shimmer passes to HUD elements.
-- Does NOT touch DisasterFrame (owned by another agent).

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ============================================================
-- Color Palette
-- ============================================================
local COLORS = {
	Primary = Color3.fromRGB(0, 247, 255),   -- cyan
	Accent  = Color3.fromRGB(255, 246, 0),   -- yellow
	Dark    = Color3.fromRGB(15, 21, 25),    -- near black
	White   = Color3.new(1, 1, 1),
}

-- ============================================================
-- References
-- ============================================================
local player     = Players.LocalPlayer
local playerGui  = player:WaitForChild("PlayerGui")
local gameUI     = playerGui:WaitForChild("GameUI")

local Countdown   = gameUI:WaitForChild("Countdown")
local SpinFrame   = gameUI:WaitForChild("SpinFrame")
local PerkButton  = gameUI:WaitForChild("PerkButton")
local NotifFrame  = gameUI:WaitForChild("NotifFrame")

local RoundEvent = ReplicatedStorage:WaitForChild("RoundEvent")
local PerkEvent  = ReplicatedStorage:WaitForChild("PerkEvent")

-- ============================================================
-- State / Cleanup Tables
-- ============================================================
local activeLoops    = {}   -- { thread } — task.spawn threads to cancel via flag
local activeFlags    = {}   -- { key = bool } — false stops named loops
local activeTweens   = {}   -- { key = Tween } — so we can :Cancel() before restart

local function cancelTween(key)
	if activeTweens[key] then
		activeTweens[key]:Cancel()
		activeTweens[key] = nil
	end
end

local function stopFlag(key)
	activeFlags[key] = false
end

local function stopAllIdleLoops()
	for key in pairs(activeFlags) do
		activeFlags[key] = false
	end
	for key in pairs(activeTweens) do
		cancelTween(key)
	end
end

-- ============================================================
-- Helper: safe tween runner that respects a flag
-- ============================================================
local function tweenLoop(flagKey, tweenFn)
	-- tweenFn() should return a new Tween each call
	activeFlags[flagKey] = true
	task.spawn(function()
		while activeFlags[flagKey] do
			local t = tweenFn()
			if not t then break end
			activeTweens[flagKey] = t
			t:Play()
			t.Completed:Wait()
			activeTweens[flagKey] = nil
			if not activeFlags[flagKey] then break end
		end
	end)
end

-- ============================================================
-- 1. Countdown Label Polish
-- ============================================================

-- Attach a UIStroke for drop shadow (created once, reused)
local countdownStroke = Instance.new("UIStroke")
countdownStroke.Color     = Color3.new(0, 0, 0)
countdownStroke.Thickness = 2
countdownStroke.Parent    = Countdown

local COUNTDOWN_SIZE_SMALL = 28
local COUNTDOWN_SIZE_BIG   = 32

local function startCountdownBreathing()
	tweenLoop("countdown_breathe", function()
		local growing = (Countdown.TextSize == COUNTDOWN_SIZE_SMALL)
		local targetSize = growing and COUNTDOWN_SIZE_BIG or COUNTDOWN_SIZE_SMALL
		local info = TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		return TweenService:Create(Countdown, info, { TextSize = targetSize })
	end)
end

local function stopCountdownBreathing()
	stopFlag("countdown_breathe")
	cancelTween("countdown_breathe")
end

local function fadeOutCountdown()
	stopCountdownBreathing()
	cancelTween("countdown_fade")
	local info = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local t = TweenService:Create(Countdown, info, { TextTransparency = 1, TextStrokeTransparency = 1 })
	activeTweens["countdown_fade"] = t
	t:Play()
end

local function showCountdown()
	cancelTween("countdown_fade")
	Countdown.TextTransparency       = 0
	Countdown.TextStrokeTransparency = 1
	Countdown.Visible                = true
	Countdown.TextSize               = COUNTDOWN_SIZE_SMALL
	countdownStroke.Enabled          = true
	startCountdownBreathing()
end

-- ============================================================
-- 2. PerkButton Idle Animation
-- ============================================================

local PERK_BASE_SIZE    = UDim2.new(0, 160, 0, 60)
local PERK_BIG_SIZE     = UDim2.new(0, 168, 0, 64)
local PERK_BASE_COLOR   = PerkButton.BackgroundColor3
local PERK_BRIGHT_COLOR = Color3.fromRGB(
	math.min(PERK_BASE_COLOR.R * 255 + 30, 255),
	math.min(PERK_BASE_COLOR.G * 255 + 30, 255),
	math.min(PERK_BASE_COLOR.B * 255 + 30, 255)
)

-- Shimmer frame for PerkButton
local perkShimmer = Instance.new("Frame")
perkShimmer.Name             = "Shimmer"
perkShimmer.Size             = UDim2.new(0, 30, 1, 0)
perkShimmer.Position         = UDim2.new(0, -35, 0, 0)
perkShimmer.BackgroundColor3 = COLORS.White
perkShimmer.BackgroundTransparency = 0.6
perkShimmer.BorderSizePixel  = 0
perkShimmer.ZIndex           = PerkButton.ZIndex + 1
perkShimmer.ClipsDescendants = false
perkShimmer.Visible          = false
perkShimmer.Parent           = PerkButton

-- Clip shimmer inside PerkButton bounds via UICorner on a wrapper is tricky;
-- instead clip via PerkButton itself
PerkButton.ClipsDescendants = true

local function brighterColor(c, amount)
	return Color3.fromRGB(
		math.min(c.R * 255 + amount, 255),
		math.min(c.G * 255 + amount, 255),
		math.min(c.B * 255 + amount, 255)
	)
end

local function startPerkGlow()
	-- Glow / color breathing
	tweenLoop("perk_glow", function()
		local growing = (PerkButton.BackgroundColor3 == PERK_BASE_COLOR
			or (PerkButton.BackgroundColor3.R * 255) < (PERK_BRIGHT_COLOR.R * 255))
		local target = growing and PERK_BRIGHT_COLOR or PERK_BASE_COLOR
		local info = TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		return TweenService:Create(PerkButton, info, { BackgroundColor3 = target })
	end)

	-- Size breathing
	tweenLoop("perk_size", function()
		local growing = (PerkButton.Size == PERK_BASE_SIZE)
		local target = growing and PERK_BIG_SIZE or PERK_BASE_SIZE
		local info = TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		return TweenService:Create(PerkButton, info, { Size = target })
	end)

	-- Shimmer slide loop
	perkShimmer.Visible = true
	activeFlags["perk_shimmer"] = true
	task.spawn(function()
		while activeFlags["perk_shimmer"] do
			perkShimmer.Position = UDim2.new(0, -35, 0, 0)
			local info = TweenInfo.new(0.45, Enum.EasingStyle.Linear)
			local t = TweenService:Create(perkShimmer, info, {
				Position = UDim2.new(1, 5, 0, 0)
			})
			activeTweens["perk_shimmer"] = t
			t:Play()
			t.Completed:Wait()
			activeTweens["perk_shimmer"] = nil
			if not activeFlags["perk_shimmer"] then break end
			-- Pause between shimmer passes
			local elapsed = 0
			while elapsed < 3 and activeFlags["perk_shimmer"] do
				elapsed = elapsed + task.wait(0.1)
			end
		end
		perkShimmer.Visible = false
	end)
end

local function stopPerkGlow()
	stopFlag("perk_glow")
	stopFlag("perk_size")
	stopFlag("perk_shimmer")
	cancelTween("perk_glow")
	cancelTween("perk_size")
	cancelTween("perk_shimmer")

	-- Reset to base state
	local info = TweenInfo.new(0.3, Enum.EasingStyle.Quad)
	TweenService:Create(PerkButton, info, {
		BackgroundColor3 = PERK_BASE_COLOR,
		Size             = PERK_BASE_SIZE,
	}):Play()
	perkShimmer.Visible = false
end

-- ============================================================
-- 3. NotifFrame Polish
-- ============================================================

-- Left-border accent (3px wide colored strip)
local notifAccent = Instance.new("Frame")
notifAccent.Name             = "LeftAccent"
notifAccent.Size             = UDim2.new(0, 3, 1, 0)
notifAccent.Position         = UDim2.new(0, 0, 0, 0)
notifAccent.BackgroundColor3 = COLORS.Primary
notifAccent.BorderSizePixel  = 0
notifAccent.ZIndex           = NotifFrame.ZIndex + 1
notifAccent.Parent           = NotifFrame

-- Store the original (resting) NotifFrame position
local NOTIF_SHOWN_POS  = NotifFrame.Position   -- {0.5,-150},{0.15,0}
local NOTIF_HIDDEN_POS = UDim2.new(
	NOTIF_SHOWN_POS.X.Scale, NOTIF_SHOWN_POS.X.Offset,
	NOTIF_SHOWN_POS.Y.Scale, -50
)

-- Start hidden
NotifFrame.Position = NOTIF_HIDDEN_POS
NotifFrame.Visible  = false

local notifHideThread = nil

local function showNotification(message)
	-- Cancel any pending auto-hide
	if notifHideThread then
		task.cancel(notifHideThread)
		notifHideThread = nil
	end
	cancelTween("notif_in")
	cancelTween("notif_out")

	-- Update text
	local textLabel = NotifFrame:FindFirstChild("TextLabel")
	if textLabel then
		textLabel.Text = message
	end

	-- Snap to offscreen then slide in
	NotifFrame.Position = NOTIF_HIDDEN_POS
	NotifFrame.Visible  = true

	local inInfo = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local tIn = TweenService:Create(NotifFrame, inInfo, { Position = NOTIF_SHOWN_POS })
	activeTweens["notif_in"] = tIn
	tIn:Play()

	-- Auto-hide after 3 seconds
	notifHideThread = task.delay(3, function()
		notifHideThread = nil
		cancelTween("notif_in")
		local outInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		local tOut = TweenService:Create(NotifFrame, outInfo, { Position = NOTIF_HIDDEN_POS })
		activeTweens["notif_out"] = tOut
		tOut:Play()
		tOut.Completed:Wait()
		NotifFrame.Visible = false
	end)
end

-- ============================================================
-- 4. SpinFrame Idle Animation
-- ============================================================

local RarityLabel = SpinFrame:FindFirstChild("Rarity")

-- Shimmer diagonal frame for SpinFrame
local spinShimmer = Instance.new("Frame")
spinShimmer.Name             = "SpinShimmer"
spinShimmer.Size             = UDim2.new(0, 60, 1.4, 0)
spinShimmer.Position         = UDim2.new(0, -70, -0.2, 0)
spinShimmer.Rotation         = 20
spinShimmer.BackgroundColor3 = COLORS.White
spinShimmer.BackgroundTransparency = 0.65
spinShimmer.BorderSizePixel  = 0
spinShimmer.ZIndex           = SpinFrame.ZIndex + 1
spinShimmer.Visible          = false
spinShimmer.Parent           = SpinFrame
SpinFrame.ClipsDescendants   = true

-- UIStroke for Rarity label glow
local rarityStroke
if RarityLabel then
	rarityStroke = Instance.new("UIStroke")
	rarityStroke.Color     = COLORS.Primary
	rarityStroke.Thickness = 0
	rarityStroke.Parent    = RarityLabel
end

local function startSpinFrameAnimations()
	-- Shimmer sweep loop
	spinShimmer.Visible = true
	activeFlags["spin_shimmer"] = true
	task.spawn(function()
		while activeFlags["spin_shimmer"] do
			spinShimmer.Position = UDim2.new(0, -70, -0.2, 0)
			local info = TweenInfo.new(0.6, Enum.EasingStyle.Linear)
			local t = TweenService:Create(spinShimmer, info, {
				Position = UDim2.new(1, 10, -0.2, 0)
			})
			activeTweens["spin_shimmer"] = t
			t:Play()
			t.Completed:Wait()
			activeTweens["spin_shimmer"] = nil
			if not activeFlags["spin_shimmer"] then break end
			-- Wait ~4 seconds between passes
			local elapsed = 0
			while elapsed < 4 and activeFlags["spin_shimmer"] do
				elapsed = elapsed + task.wait(0.1)
			end
		end
		spinShimmer.Visible = false
	end)

	-- Rarity glow stroke pulse 0 -> 2 -> 0
	if rarityStroke then
		tweenLoop("spin_glow", function()
			local growing = (rarityStroke.Thickness < 1)
			local target = growing and 2 or 0
			local info = TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			return TweenService:Create(rarityStroke, info, { Thickness = target })
		end)
	end
end

local function stopSpinFrameAnimations()
	stopFlag("spin_shimmer")
	stopFlag("spin_glow")
	cancelTween("spin_shimmer")
	cancelTween("spin_glow")
	spinShimmer.Visible = false
	if rarityStroke then
		rarityStroke.Thickness = 0
	end
end

-- ============================================================
-- 5. Event Wiring
-- ============================================================

RoundEvent.OnClientEvent:Connect(function(eventName, data)
	if eventName == "LobbyCountdown" then
		-- Keep countdown visible and breathing during lobby
		if not activeFlags["countdown_breathe"] then
			showCountdown()
		end

	elseif eventName == "RoundStart" then
		-- Stop idle loops and perk glow at round start
		stopAllIdleLoops()
		stopPerkGlow()
		-- Show countdown
		showCountdown()

	elseif eventName == "RoundEnd" then
		-- Fade countdown
		fadeOutCountdown()
		-- Show SpinFrame animations
		startSpinFrameAnimations()
end
end)

PerkEvent.OnClientEvent:Connect(function(eventName, data)
	if eventName == "setActivePerk" then
		stopPerkGlow()       -- cancel any previous loop cleanly
		task.wait(0.05)      -- let resets settle
		startPerkGlow()

	elseif eventName == "clearPerk" then
		stopPerkGlow()

	elseif eventName == "notification" then
		local message = (type(data) == "string") and data or tostring(data)
		showNotification(message)
	end
end)

-- ============================================================
-- 6. SpinFrame visibility watcher
-- We also watch SpinFrame.Visible via GetPropertyChangedSignal
-- so that if another script shows/hides it we react correctly.
-- ============================================================
SpinFrame:GetPropertyChangedSignal("Visible"):Connect(function()
	if SpinFrame.Visible then
		startSpinFrameAnimations()
	else
		stopSpinFrameAnimations()
	end
end)

-- If SpinFrame is already visible on load, start animations
if SpinFrame.Visible then
	startSpinFrameAnimations()
end
