--[[
	DisasterWarning LocalScript  (v2 — dramatic multi-stage system)
	Handles all client-side disaster warning overlays and cinematic effects.
	Listens to RoundEvent.OnClientEvent for: DisasterWarning (stage 1 & 2),
	RoundStart (cinematic letterbox), and RoundEnd (cleanup).
	All UI is created dynamically in DisasterWarningGui; GameUI is never touched.
--]]

local Players        = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService   = game:GetService("TweenService")
local Lighting       = game:GetService("Lighting")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local RoundEvent = ReplicatedStorage:WaitForChild("RoundEvent")

-- ===========================================================================
-- Per-disaster data
-- ===========================================================================
local DISASTER_DATA = {
	["Tornado"] = {
		icon         = "🌪️",
		color        = Color3.fromRGB(150, 150, 220),
		warningColor = Color3.fromRGB(100, 100, 200),
		flashColor   = Color3.fromRGB(180, 180, 255),
		dangerLevel  = 3,
	},
	["Flood"] = {
		icon         = "🌊",
		color        = Color3.fromRGB(30, 100, 255),
		warningColor = Color3.fromRGB(20, 70, 200),
		flashColor   = Color3.fromRGB(80, 150, 255),
		dangerLevel  = 4,
	},
	["Meteor Strike"] = {
		icon         = "☄️",
		color        = Color3.fromRGB(255, 100, 30),
		warningColor = Color3.fromRGB(200, 70, 20),
		flashColor   = Color3.fromRGB(255, 150, 80),
		dangerLevel  = 5,
	},
	["Lightning Storm"] = {
		icon         = "⚡",
		color        = Color3.fromRGB(255, 255, 60),
		warningColor = Color3.fromRGB(200, 200, 0),
		flashColor   = Color3.fromRGB(255, 255, 150),
		dangerLevel  = 4,
	},
	["Volcanic Eruption"] = {
		icon         = "🌋",
		color        = Color3.fromRGB(255, 70, 20),
		warningColor = Color3.fromRGB(180, 40, 10),
		flashColor   = Color3.fromRGB(255, 120, 60),
		dangerLevel  = 5,
	},
	["Blizzard"] = {
		icon         = "❄️",
		color        = Color3.fromRGB(150, 220, 255),
		warningColor = Color3.fromRGB(100, 180, 230),
		flashColor   = Color3.fromRGB(200, 240, 255),
		dangerLevel  = 3,
	},
	["Earthquake"] = {
		icon         = "🏔️",
		color        = Color3.fromRGB(180, 140, 80),
		warningColor = Color3.fromRGB(140, 100, 50),
		flashColor   = Color3.fromRGB(220, 180, 120),
		dangerLevel  = 5,
	},
	["Tsunami"] = {
		icon         = "🌊",
		color        = Color3.fromRGB(0, 60, 200),
		warningColor = Color3.fromRGB(0, 40, 150),
		flashColor   = Color3.fromRGB(50, 100, 255),
		dangerLevel  = 5,
	},
	["Acid Rain"] = {
		icon         = "☠️",
		color        = Color3.fromRGB(80, 255, 60),
		warningColor = Color3.fromRGB(50, 180, 40),
		flashColor   = Color3.fromRGB(150, 255, 120),
		dangerLevel  = 4,
	},
	["Sandstorm"] = {
		icon         = "🏜️",
		color        = Color3.fromRGB(220, 170, 60),
		warningColor = Color3.fromRGB(180, 130, 40),
		flashColor   = Color3.fromRGB(255, 210, 120),
		dangerLevel  = 3,
	},
}

local DEFAULT_DATA = {
	icon         = "⚠️",
	color        = Color3.fromRGB(200, 200, 200),
	warningColor = Color3.fromRGB(160, 160, 160),
	flashColor   = Color3.fromRGB(230, 230, 230),
	dangerLevel  = 3,
}

local function getData(name)
	return DISASTER_DATA[name] or DEFAULT_DATA
end

-- ===========================================================================
-- Root ScreenGui  (DisplayOrder = 10, never touches GameUI)
-- ===========================================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name             = "DisasterWarningGui"
screenGui.DisplayOrder     = 10
screenGui.IgnoreGuiInset   = true
screenGui.ResetOnSpawn     = false
screenGui.ZIndexBehavior   = Enum.ZIndexBehavior.Sibling
screenGui.Parent           = playerGui

-- ===========================================================================
-- Tween tracking
-- ===========================================================================
local activeTweens = {}

local function trackTween(tween)
	table.insert(activeTweens, tween)
	return tween
end

local function cancelAllTweens()
	for _, t in ipairs(activeTweens) do
		pcall(function() t:Cancel() end)
	end
	activeTweens = {}
end

-- ===========================================================================
-- Cleanup
-- ===========================================================================
local function clearAll()
	cancelAllTweens()
	for _, child in ipairs(screenGui:GetChildren()) do
		child:Destroy()
	end
end

-- ===========================================================================
-- Helpers
-- ===========================================================================
local originalBrightness = Lighting.Brightness
local atmosphere_oldDensity  -- upvalue shared across activateStage1, activateRoundStart, onRoundEnd

local function makeFrame(props)
	local f = Instance.new("Frame")
	f.BorderSizePixel      = 0
	f.BackgroundTransparency = props.transparency or 0
	f.BackgroundColor3     = props.color or Color3.new(0, 0, 0)
	f.Size                 = props.size or UDim2.new(1, 0, 1, 0)
	f.Position             = props.position or UDim2.new(0, 0, 0, 0)
	f.ZIndex               = props.zIndex or 1
	f.Name                 = props.name or "Frame"
	f.Parent               = screenGui
	return f
end

local function makeLabel(props)
	local lbl = Instance.new("TextLabel")
	lbl.BorderSizePixel        = 0
	lbl.BackgroundTransparency = 1
	lbl.Name                   = props.name or "Label"
	lbl.Size                   = props.size or UDim2.new(1, 0, 0, 40)
	lbl.AnchorPoint            = props.anchor or Vector2.new(0.5, 0.5)
	lbl.Position               = props.position or UDim2.new(0.5, 0, 0.5, 0)
	lbl.Text                   = props.text or ""
	lbl.TextColor3             = props.textColor or Color3.new(1, 1, 1)
	lbl.TextTransparency       = props.textTransparency or 0
	lbl.TextStrokeColor3       = Color3.new(0, 0, 0)
	lbl.TextStrokeTransparency = props.strokeTransparency or 0.4
	lbl.Font                   = props.font or Enum.Font.Gotham
	lbl.TextSize               = props.textSize or 18
	lbl.TextScaled             = props.textScaled or false
	lbl.RichText               = props.richText or false
	lbl.ZIndex                 = props.zIndex or 5
	lbl.Parent                 = props.parent or screenGui
	return lbl
end

-- ===========================================================================
-- Border helpers
-- ===========================================================================
local borderFrames     = {}
local borderPulseAlive = false  -- flag to stop the pulse loop

local function destroyBorders()
	for _, f in ipairs(borderFrames) do
		if f and f.Parent then f:Destroy() end
	end
	borderFrames = {}
end

local function createBorderFrames(thickness, color)
	destroyBorders()
	local defs = {
		{ size = UDim2.new(1, 0, 0, thickness), pos = UDim2.new(0, 0, 0, 0) },          -- top
		{ size = UDim2.new(1, 0, 0, thickness), pos = UDim2.new(0, 0, 1, -thickness) }, -- bottom
		{ size = UDim2.new(0, thickness, 1, 0), pos = UDim2.new(0, 0, 0, 0) },          -- left
		{ size = UDim2.new(0, thickness, 1, 0), pos = UDim2.new(1, -thickness, 0, 0) }, -- right
	}
	for i, d in ipairs(defs) do
		local f = makeFrame({
			name         = "Border" .. i,
			color        = color,
			transparency = 1,
			size         = d.size,
			position     = d.pos,
			zIndex       = 6,
		})
		table.insert(borderFrames, f)
	end
	return borderFrames
end

-- Pulse borders using a boolean flag so we don't need task.cancel
local function startBorderPulse(frames, maxAlpha, halfCycle)
	borderPulseAlive = true
	task.spawn(function()
		while borderPulseAlive do
			-- fade in
			for _, f in ipairs(frames) do
				if not (f and f.Parent) then borderPulseAlive = false; return end
				trackTween(TweenService:Create(
					f,
					TweenInfo.new(halfCycle, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
					{ BackgroundTransparency = 1 - maxAlpha }
				)):Play()
			end
			task.wait(halfCycle)
			if not borderPulseAlive then return end
			-- fade out
			for _, f in ipairs(frames) do
				if not (f and f.Parent) then borderPulseAlive = false; return end
				trackTween(TweenService:Create(
					f,
					TweenInfo.new(halfCycle, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
					{ BackgroundTransparency = 1 }
				)):Play()
			end
			task.wait(halfCycle)
		end
	end)
end

local function stopBorderPulse()
	borderPulseAlive = false
end

-- ===========================================================================
-- STAGE 1  (subtle, 8 s before disaster)
-- ===========================================================================
local stage1LabelPulseAlive = false

local function activateStage1(disasterName)
	local d = getData(disasterName)

	-- Dim lighting slightly
	originalBrightness = Lighting.Brightness
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		atmosphere_oldDensity = atmosphere.Density  -- stored in module-level upvalue
		trackTween(TweenService:Create(
			atmosphere,
			TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Density = math.min(1, atmosphere.Density + 0.25) }
		)):Play()
	else
		trackTween(TweenService:Create(
			Lighting,
			TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Brightness = math.max(0, originalBrightness - 0.15) }
		)):Play()
	end

	-- Thin 5px border frames
	local frames = createBorderFrames(5, d.warningColor)
	startBorderPulse(frames, 0.3, 1.2)  -- slow pulse: 0 -> 0.3 opacity each 1.2s

	-- Bottom-centre "incoming" label
	local incomingLabel = makeLabel({
		name             = "Stage1IncomingLabel",
		size             = UDim2.new(0.5, 0, 0, 28),
		anchor           = Vector2.new(0.5, 1),
		position         = UDim2.new(0.5, 0, 0.95, 0),
		text             = "⚠ " .. d.icon .. " incoming...",
		textColor        = d.warningColor,
		textTransparency = 1,  -- fades in
		strokeTransparency = 0.5,
		textSize         = 18,
		font             = Enum.Font.Gotham,
		zIndex           = 8,
	})

	-- Fade in the label
	trackTween(TweenService:Create(
		incomingLabel,
		TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ TextTransparency = 0 }
	)):Play()

	-- Gentle "breathing" opacity pulse on the label
	stage1LabelPulseAlive = true
	task.spawn(function()
		task.wait(1.1)  -- let the fade-in finish first
		while stage1LabelPulseAlive and incomingLabel and incomingLabel.Parent do
			trackTween(TweenService:Create(
				incomingLabel,
				TweenInfo.new(1.0, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{ TextTransparency = 0.5 }
			)):Play()
			task.wait(1.0)
			if not (stage1LabelPulseAlive and incomingLabel and incomingLabel.Parent) then break end
			trackTween(TweenService:Create(
				incomingLabel,
				TweenInfo.new(1.0, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{ TextTransparency = 0 }
			)):Play()
			task.wait(1.0)
		end
	end)
end

-- ===========================================================================
-- STAGE 2  (dramatic, 4 s before disaster)
-- ===========================================================================
local stage2DangerPulseAlive = false

local function activateStage2(disasterName)
	local d = getData(disasterName)

	-- Kill stage 1 loops cleanly
	stopBorderPulse()
	stage1LabelPulseAlive = false

	-- Clear stage 1 children but keep screenGui
	cancelAllTweens()
	for _, child in ipairs(screenGui:GetChildren()) do
		child:Destroy()
	end

	-- Thicker 10px border with faster pulse
	local frames = createBorderFrames(10, d.warningColor)
	startBorderPulse(frames, 0.7, 0.5)  -- fast: 0 -> 0.7 opacity each 0.5s

	-- Vignette: dark gradient overlay at screen edges
	local vignetteFrame = makeFrame({
		name         = "Vignette",
		color        = Color3.new(0, 0, 0),
		transparency = 1,  -- fully transparent to start
		size         = UDim2.new(1, 0, 1, 0),
		position     = UDim2.new(0, 0, 0, 0),
		zIndex       = 4,
	})
	local grad = Instance.new("UIGradient")
	grad.Rotation    = 45
	grad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0,   1.0),  -- centre transparent
		NumberSequenceKeypoint.new(0.55, 0.6),
		NumberSequenceKeypoint.new(1,   0.0),  -- edges opaque
	})
	grad.Parent = vignetteFrame
	-- Fade vignette in
	trackTween(TweenService:Create(
		vignetteFrame,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 0.5 }
	)):Play()

	-- Large icon label (80px) — scales in from 0.5x to 1x
	local iconLabel = makeLabel({
		name             = "Stage2Icon",
		size             = UDim2.new(0, 40, 0, 40),  -- start at 0.5x
		anchor           = Vector2.new(0.5, 0.5),
		position         = UDim2.new(0.5, 0, 0.42, 0),
		text             = d.icon,
		textColor        = d.flashColor,
		textTransparency = 0,
		strokeTransparency = 1,
		textSize         = 40,
		zIndex           = 12,
	})
	trackTween(TweenService:Create(
		iconLabel,
		TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.new(0, 80, 0, 80), TextSize = 72 }
	)):Play()

	-- "DANGER INCOMING" label below icon
	local dangerLabel = makeLabel({
		name             = "Stage2DangerText",
		size             = UDim2.new(0.7, 0, 0, 38),
		anchor           = Vector2.new(0.5, 0),
		position         = UDim2.new(0.5, 0, 0.56, 0),
		text             = "DANGER INCOMING",
		textColor        = d.flashColor,
		textTransparency = 1,
		strokeTransparency = 0.2,
		font             = Enum.Font.GothamBlack,
		textSize         = 28,
		zIndex           = 12,
	})
	trackTween(TweenService:Create(
		dangerLabel,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ TextTransparency = 0 }
	)):Play()

	-- Fast pulse on the danger label
	stage2DangerPulseAlive = true
	task.spawn(function()
		task.wait(0.35)
		while stage2DangerPulseAlive and dangerLabel and dangerLabel.Parent do
			trackTween(TweenService:Create(
				dangerLabel,
				TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{ TextTransparency = 0.5, TextColor3 = Color3.new(1, 1, 1) }
			)):Play()
			task.wait(0.25)
			if not (stage2DangerPulseAlive and dangerLabel and dangerLabel.Parent) then break end
			trackTween(TweenService:Create(
				dangerLabel,
				TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{ TextTransparency = 0, TextColor3 = d.flashColor }
			)):Play()
			task.wait(0.25)
		end
	end)
end

-- ===========================================================================
-- ROUND START  (cinematic letterbox + disaster name reveal + mutation)
-- ===========================================================================
local function activateRoundStart(disasterName, mutation)
	-- Stop all loops and kill all pending tweens
	stopBorderPulse()
	stage1LabelPulseAlive  = false
	stage2DangerPulseAlive = false
	cancelAllTweens()

	-- Wipe the slate
	for _, child in ipairs(screenGui:GetChildren()) do
		child:Destroy()
	end

	local d          = getData(disasterName)
	local BAR_HEIGHT = 0.14  -- 14% of screen height each bar

	-- === Letterbox bars ===
	local topBar = makeFrame({
		name         = "LetterboxTop",
		color        = Color3.new(0, 0, 0),
		transparency = 0,
		size         = UDim2.new(1, 0, BAR_HEIGHT, 0),
		position     = UDim2.new(0, 0, -BAR_HEIGHT, 0),
		zIndex       = 20,
	})
	local botBar = makeFrame({
		name         = "LetterboxBottom",
		color        = Color3.new(0, 0, 0),
		transparency = 0,
		size         = UDim2.new(1, 0, BAR_HEIGHT, 0),
		position     = UDim2.new(0, 0, 1, 0),
		zIndex       = 20,
	})

	local slideInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	local topIn = TweenService:Create(topBar, slideInfo, { Position = UDim2.new(0, 0, 0, 0) })
	local botIn = TweenService:Create(botBar, slideInfo, { Position = UDim2.new(0, 0, 1 - BAR_HEIGHT, 0) })
	trackTween(topIn)
	trackTween(botIn)
	topIn:Play()
	botIn:Play()
	topIn.Completed:Wait()  -- wait for bars to settle

	-- === Icon — scales from 2x down to 1x ===
	local iconLabel = makeLabel({
		name             = "CinematicIcon",
		size             = UDim2.new(0, 120, 0, 120),  -- 2x start
		anchor           = Vector2.new(0.5, 0.5),
		position         = UDim2.new(0.5, 0, 0.37, 0),
		text             = d.icon,
		textColor        = d.color,
		textTransparency = 0,
		strokeTransparency = 1,
		textSize         = 100,
		zIndex           = 25,
	})
	local iconShrink = TweenService:Create(
		iconLabel,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.new(0, 60, 0, 60), TextSize = 52 }
	)
	trackTween(iconShrink)
	iconShrink:Play()
	iconShrink.Completed:Wait()

	-- === Disaster name — letter by letter ===
	local nameLabel = makeLabel({
		name             = "DisasterNameReveal",
		size             = UDim2.new(0.88, 0, 0, 60),
		anchor           = Vector2.new(0.5, 0),
		position         = UDim2.new(0.5, 0, 0.47, 0),
		text             = "",
		textColor        = d.color,
		textTransparency = 0,
		strokeTransparency = 0,
		font             = Enum.Font.GothamBlack,
		textSize         = 52,
		zIndex           = 25,
	})

	local fullText = disasterName:upper()
	for i = 1, #fullText do
		nameLabel.Text = string.sub(fullText, 1, i)
		task.wait(0.07)
	end

	-- === Mutation label (if present) ===
	if mutation and mutation ~= "" then
		local mutationLabel = makeLabel({
			name             = "MutationLabel",
			size             = UDim2.new(0.7, 0, 0, 26),
			anchor           = Vector2.new(0.5, 0),
			position         = UDim2.new(0.5, 0, 0.60, 0),
			text             = "MUTATION: " .. mutation:upper(),
			textColor        = Color3.fromRGB(255, 215, 0),  -- gold
			textTransparency = 1,
			strokeTransparency = 0.3,
			font             = Enum.Font.GothamMedium,
			textSize         = 20,
			zIndex           = 25,
		})
		trackTween(TweenService:Create(
			mutationLabel,
			TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ TextTransparency = 0 }
		)):Play()
	end

	-- Hold for 2.2 s
	task.wait(2.2)

	-- === Fade out all cinematic elements ===
	for _, child in ipairs(screenGui:GetChildren()) do
		if child.Name ~= "LetterboxTop" and child.Name ~= "LetterboxBottom" then
			if child:IsA("TextLabel") then
				trackTween(TweenService:Create(
					child,
					TweenInfo.new(0.3, Enum.EasingStyle.Quad),
					{ TextTransparency = 1 }
				)):Play()
			end
		end
	end
	task.wait(0.3)

	-- === Slide bars out ===
	local slideOut = TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
	local topOut = TweenService:Create(topBar, slideOut, { Position = UDim2.new(0, 0, -BAR_HEIGHT, 0) })
	local botOut = TweenService:Create(botBar, slideOut, { Position = UDim2.new(0, 0, 1, 0) })
	trackTween(topOut)
	trackTween(botOut)
	topOut:Play()
	botOut:Play()
	topOut.Completed:Wait()

	-- Full wipe
	for _, child in ipairs(screenGui:GetChildren()) do
		child:Destroy()
	end

	-- Restore lighting
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere and atmosphere_oldDensity then
		trackTween(TweenService:Create(
			atmosphere,
			TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Density = atmosphere_oldDensity }
		)):Play()
		atmosphere_oldDensity = nil
	else
		trackTween(TweenService:Create(
			Lighting,
			TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Brightness = originalBrightness }
		)):Play()
	end
end

-- ===========================================================================
-- ROUND END — clear everything, restore lighting
-- ===========================================================================
local function onRoundEnd()
	stopBorderPulse()
	stage1LabelPulseAlive  = false
	stage2DangerPulseAlive = false

	-- Fade out whatever is on screen
	for _, child in ipairs(screenGui:GetChildren()) do
		if child:IsA("TextLabel") then
			trackTween(TweenService:Create(
				child,
				TweenInfo.new(0.4, Enum.EasingStyle.Quad),
				{ TextTransparency = 1 }
			)):Play()
		elseif child:IsA("Frame") then
			trackTween(TweenService:Create(
				child,
				TweenInfo.new(0.4, Enum.EasingStyle.Quad),
				{ BackgroundTransparency = 1 }
			)):Play()
		end
	end
	task.delay(0.45, function()
		clearAll()
	end)

	-- Restore lighting
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere and atmosphere_oldDensity then
		atmosphere.Density = atmosphere_oldDensity
		atmosphere_oldDensity = nil
	end
	Lighting.Brightness = originalBrightness
end

-- ===========================================================================
-- Event listener
-- ===========================================================================
RoundEvent.OnClientEvent:Connect(function(event, data)
	if event == "DisasterWarning" then
		if data.stage == 1 then
			clearAll()
			activateStage1(data.disaster)
		elseif data.stage == 2 then
			activateStage2(data.disaster)
		end

	elseif event == "RoundStart" then
		task.spawn(function()
			activateRoundStart(data.disaster, data.mutation)
		end)

	elseif event == "RoundEnd" then
		onRoundEnd()
	end
end)
