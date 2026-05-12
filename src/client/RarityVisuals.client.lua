-- RarityVisuals LocalScript
-- Triggers escalating visual effects on SpinFrame when a spin result is received.
-- Listens to SpinEvent.OnClientEvent (server fires results back to this client).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local SpinEvent = ReplicatedStorage:WaitForChild("SpinEvent")

-- ─────────────────────────────────────────────
-- Setup: dedicated ScreenGui for all overlay FX
-- ─────────────────────────────────────────────
local effectsGui = Instance.new("ScreenGui")
effectsGui.Name = "RarityEffectsGui"
effectsGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
effectsGui.DisplayOrder = 100
effectsGui.ResetOnSpawn = false
effectsGui.Parent = playerGui

-- ─────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────

-- Retrieve SpinFrame from GameUI (waits until it exists)
local function getSpinFrame()
	local gameUI = playerGui:WaitForChild("GameUI", 10)
	if not gameUI then return nil end
	return gameUI:WaitForChild("SpinFrame", 10)
end

-- Ensure a UIStroke lives inside SpinFrame; return it
local function getOrCreateStroke(spinFrame)
	local stroke = spinFrame:FindFirstChildOfClass("UIStroke")
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = spinFrame
	end
	return stroke
end

-- Create a full-screen colored flash frame, tween transparency to 1, then destroy
local function screenFlash(color, startTransparency, duration)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.Position = UDim2.fromScale(0, 0)
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = startTransparency
	frame.BorderSizePixel = 0
	frame.ZIndex = 50
	frame.Parent = effectsGui

	local tween = TweenService:Create(
		frame,
		TweenInfo.new(duration, Enum.EasingStyle.Linear),
		{ BackgroundTransparency = 1 }
	)
	tween:Play()
	tween.Completed:Connect(function() frame:Destroy() end)
end

-- Pulse a UIStroke thickness: from -> peak -> from over totalTime
local function pulseStroke(stroke, fromThick, peakThick, totalTime)
	local half = totalTime / 2
	local t1 = TweenService:Create(
		stroke,
		TweenInfo.new(half, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ Thickness = peakThick }
	)
	t1:Play()
	t1.Completed:Connect(function()
		local t2 = TweenService:Create(
			stroke,
			TweenInfo.new(half, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
			{ Thickness = fromThick }
		)
		t2:Play()
	end)
end

-- Spawn N small square frames at SpinFrame center, tween them outward then destroy
local function spawnParticles(count, baseColor, spinFrame)
	local center = UDim2.new(0.5, 0, 0.5, 0)
	for i = 1, count do
		task.spawn(function()
			local p = Instance.new("Frame")
			p.Size = UDim2.fromOffset(10, 10)
			p.AnchorPoint = Vector2.new(0.5, 0.5)
			p.Position = center
			p.BackgroundColor3 = baseColor
			p.BackgroundTransparency = 0
			p.BorderSizePixel = 0
			p.ZIndex = 60
			p.Parent = effectsGui

			local angle = (i / count) * (2 * math.pi) + math.random() * 0.5
			local dist = 250 + math.random(0, 150)
			local targetPos = UDim2.new(
				0.5, math.cos(angle) * dist,
				0.5, math.sin(angle) * dist
			)

			local tween = TweenService:Create(
				p,
				TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Position = targetPos, BackgroundTransparency = 1, Size = UDim2.fromOffset(4, 4) }
			)
			tween:Play()
			tween.Completed:Connect(function() p:Destroy() end)
		end)
	end
end

-- Floating label that rises and fades from SpinFrame
local function floatLabel(text, color, fontSize)
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(0, 400, 0, 80)
	lbl.AnchorPoint = Vector2.new(0.5, 0.5)
	lbl.Position = UDim2.new(0.5, 0, 0.55, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = color
	lbl.TextScaled = true
	lbl.Font = Enum.Font.GothamBold
	lbl.TextTransparency = 0
	lbl.ZIndex = 70
	lbl.Parent = effectsGui

	if fontSize then
		lbl.TextScaled = false
		lbl.TextSize = fontSize
	end

	local tween = TweenService:Create(
		lbl,
		TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0.5, 0, 0.3, 0), TextTransparency = 1 }
	)
	tween:Play()
	tween.Completed:Connect(function() lbl:Destroy() end)
end

-- Screen shake: randomly offset effectsGui.Frame position for duration seconds
local function screenShake(intensity, duration)
	task.spawn(function()
		local shakeFrame = Instance.new("Frame")
		shakeFrame.Size = UDim2.fromScale(1, 1)
		shakeFrame.BackgroundTransparency = 1
		shakeFrame.ZIndex = 1
		shakeFrame.Parent = effectsGui

		-- We shake by moving a transparent overlay; the visual trick is to
		-- shift the entire effectsGui's position briefly.
		local gui = effectsGui
		local elapsed = 0
		-- Use a dedicated shake ScreenGui so we don't disturb other effects
		local shakeGui = Instance.new("ScreenGui")
		shakeGui.Name = "ShakeGui"
		shakeGui.DisplayOrder = 99
		shakeGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
		shakeGui.ResetOnSpawn = false
		shakeGui.Parent = playerGui

		local blocker = Instance.new("Frame")
		blocker.Size = UDim2.fromScale(1, 1)
		blocker.BackgroundTransparency = 1
		blocker.ZIndex = 1
		blocker.Parent = shakeGui

		local startTime = tick()
		while tick() - startTime < duration do
			local offsetX = (math.random() * 2 - 1) * intensity
			local offsetY = (math.random() * 2 - 1) * intensity
			shakeGui.ScreenInsets = Enum.ScreenInsets.None
			blocker.Position = UDim2.fromOffset(offsetX, offsetY)
			task.wait(0.03)
		end
		blocker.Position = UDim2.fromOffset(0, 0)
		shakeGui:Destroy()
		shakeFrame:Destroy()
	end)
end

-- Letterbox: slide black bars in from top/bottom, hold, slide out
local function letterbox(holdTime)
	task.spawn(function()
		local barThickness = 80

		local topBar = Instance.new("Frame")
		topBar.Size = UDim2.new(1, 0, 0, barThickness)
		topBar.Position = UDim2.new(0, 0, 0, -barThickness)
		topBar.BackgroundColor3 = Color3.new(0, 0, 0)
		topBar.BorderSizePixel = 0
		topBar.ZIndex = 80
		topBar.Parent = effectsGui

		local botBar = Instance.new("Frame")
		botBar.Size = UDim2.new(1, 0, 0, barThickness)
		botBar.Position = UDim2.new(0, 0, 1, 0)
		botBar.BackgroundColor3 = Color3.new(0, 0, 0)
		botBar.BorderSizePixel = 0
		botBar.ZIndex = 80
		botBar.Parent = effectsGui

		local inInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local tTop = TweenService:Create(topBar, inInfo, { Position = UDim2.new(0, 0, 0, 0) })
		local tBot = TweenService:Create(botBar, inInfo, { Position = UDim2.new(0, 0, 1, -barThickness) })
		tTop:Play() tBot:Play()
		tTop.Completed:Wait()

		task.wait(holdTime)

		local outInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		local tTop2 = TweenService:Create(topBar, outInfo, { Position = UDim2.new(0, 0, 0, -barThickness) })
		local tBot2 = TweenService:Create(botBar, outInfo, { Position = UDim2.new(0, 0, 1, 0) })
		tTop2:Play() tBot2:Play()
		tTop2.Completed:Connect(function() topBar:Destroy() botBar:Destroy() end)
	end)
end

-- Golden edge borders (4 thin frames lining screen edges)
local function goldenBorders(duration)
	task.spawn(function()
		local color = Color3.fromRGB(255, 200, 0)
		local thick = 6
		local borders = {}

		local function makeBorder(size, pos)
			local f = Instance.new("Frame")
			f.Size = size
			f.Position = pos
			f.BackgroundColor3 = color
			f.BackgroundTransparency = 0.2
			f.BorderSizePixel = 0
			f.ZIndex = 55
			f.Parent = effectsGui
			table.insert(borders, f)
		end

		makeBorder(UDim2.new(1, 0, 0, thick), UDim2.new(0, 0, 0, 0))          -- top
		makeBorder(UDim2.new(1, 0, 0, thick), UDim2.new(0, 0, 1, -thick))     -- bottom
		makeBorder(UDim2.new(0, thick, 1, 0), UDim2.new(0, 0, 0, 0))          -- left
		makeBorder(UDim2.new(0, thick, 1, 0), UDim2.new(1, -thick, 0, 0))     -- right

		task.wait(duration)
		for _, f in ipairs(borders) do
			local t = TweenService:Create(
				f,
				TweenInfo.new(0.3),
				{ BackgroundTransparency = 1 }
			)
			t:Play()
			t.Completed:Connect(function() f:Destroy() end)
		end
	end)
end

-- Glitch label: briefly scramble text then restore
local function glitchLabel(spinFrame, labelName, originalText, duration)
	task.spawn(function()
		local lbl = spinFrame:FindFirstChild(labelName)
		if not lbl then return end
		local chars = "!@#$%^&*<>?/|ABCDEFxyz0123456789"
		local elapsed = 0
		while elapsed < duration do
			local scrambled = ""
			for _ = 1, #originalText do
				local idx = math.random(1, #chars)
				scrambled = scrambled .. chars:sub(idx, idx)
			end
			lbl.Text = scrambled
			task.wait(0.06)
			elapsed = elapsed + 0.06
		end
		lbl.Text = originalText
	end)
end

-- Rainbow UIStroke color cycle for a given number of steps
local function rainbowStroke(stroke, steps, stepDelay)
	task.spawn(function()
		for i = 1, steps do
			local hue = (i / steps)
			stroke.Color = Color3.fromHSV(hue, 1, 1)
			task.wait(stepDelay)
		end
	end)
end

-- Twinkle: small white dots at random screen positions that fade in and out
local function twinkleStars(count, duration)
	task.spawn(function()
		local stars = {}
		for i = 1, count do
			local s = Instance.new("Frame")
			s.Size = UDim2.fromOffset(6, 6)
			s.AnchorPoint = Vector2.new(0.5, 0.5)
			s.Position = UDim2.new(math.random(), 0, math.random(), 0)
			s.BackgroundColor3 = Color3.new(1, 1, 1)
			s.BackgroundTransparency = 1
			s.BorderSizePixel = 0
			s.ZIndex = 65
			s.Parent = effectsGui
			table.insert(stars, s)

			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(1, 0)
			corner.Parent = s
		end

		local elapsed = 0
		while elapsed < duration do
			for _, s in ipairs(stars) do
				local t = TweenService:Create(
					s,
					TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 0, true),
					{ BackgroundTransparency = math.random() * 0.3 }
				)
				t:Play()
			end
			task.wait(0.35)
			elapsed = elapsed + 0.35
		end

		for _, s in ipairs(stars) do s:Destroy() end
	end)
end

-- ─────────────────────────────────────────────
-- Rarity Effect Functions
-- ─────────────────────────────────────────────

local RarityEffects = {}

-- TIER 1: Common
function RarityEffects.Common(spinFrame)
	local stroke = getOrCreateStroke(spinFrame)
	stroke.Color = Color3.fromRGB(200, 200, 200)
	stroke.Thickness = 2
	stroke.Enabled = true

	screenFlash(Color3.fromRGB(200, 200, 200), 0.9, 0.3)

	task.delay(0.5, function()
		stroke.Enabled = false
	end)
end

-- TIER 2: Uncommon
function RarityEffects.Uncommon(spinFrame)
	local stroke = getOrCreateStroke(spinFrame)
	stroke.Color = Color3.fromRGB(80, 200, 80)
	stroke.Thickness = 2
	stroke.Enabled = true

	screenFlash(Color3.fromRGB(80, 200, 80), 0.85, 0.4)
	pulseStroke(stroke, 2, 4, 0.6)

	task.delay(0.8, function()
		stroke.Enabled = false
	end)
end

-- TIER 3: Rare
function RarityEffects.Rare(spinFrame)
	local stroke = getOrCreateStroke(spinFrame)
	stroke.Color = Color3.fromRGB(60, 120, 255)
	stroke.Thickness = 2
	stroke.Enabled = true

	screenFlash(Color3.fromRGB(60, 120, 255), 0.8, 0.4)
	pulseStroke(stroke, 2, 5, 0.7)

	-- Bounce slide-in: move SpinFrame slightly off and back
	local origPos = spinFrame.Position
	spinFrame.Position = UDim2.new(origPos.X.Scale, origPos.X.Offset, origPos.Y.Scale, origPos.Y.Offset + 40)
	local bounceInfo = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local t = TweenService:Create(spinFrame, bounceInfo, { Position = origPos })
	t:Play()

	task.delay(1.0, function()
		stroke.Enabled = false
	end)
end

-- TIER 4: Epic
function RarityEffects.Epic(spinFrame)
	local stroke = getOrCreateStroke(spinFrame)
	stroke.Color = Color3.fromRGB(160, 60, 255)
	stroke.Thickness = 3
	stroke.Enabled = true

	screenFlash(Color3.fromRGB(160, 60, 255), 0.75, 0.5)
	pulseStroke(stroke, 3, 7, 0.8)

	-- UIGradient sweep on SpinFrame
	local existingGrad = spinFrame:FindFirstChildOfClass("UIGradient")
	if not existingGrad then
		local grad = Instance.new("UIGradient")
		grad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 0, 140)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(160, 60, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 0, 140)),
		})
		grad.Rotation = 45
		grad.Parent = spinFrame
		task.delay(1.5, function() grad:Destroy() end)
	end

	-- Slight shake on SpinFrame
	task.spawn(function()
		local origPos = spinFrame.Position
		for _ = 1, 6 do
			spinFrame.Position = UDim2.new(
				origPos.X.Scale, origPos.X.Offset + math.random(-5, 5),
				origPos.Y.Scale, origPos.Y.Offset + math.random(-5, 5)
			)
			task.wait(0.05)
		end
		spinFrame.Position = origPos
	end)

	task.delay(1.5, function()
		stroke.Enabled = false
	end)
end

-- TIER 5: Legendary
function RarityEffects.Legendary(spinFrame)
	local stroke = getOrCreateStroke(spinFrame)
	stroke.Color = Color3.fromRGB(255, 200, 0)
	stroke.Thickness = 6
	stroke.Enabled = true

	screenFlash(Color3.fromRGB(255, 200, 0), 0.7, 0.5)
	goldenBorders(1.5)
	pulseStroke(stroke, 6, 10, 1.0)
	floatLabel("LEGENDARY!", Color3.fromRGB(255, 200, 0))

	task.delay(2.0, function()
		stroke.Enabled = false
	end)
end

-- TIER 6: Mythical
function RarityEffects.Mythical(spinFrame)
	local stroke = getOrCreateStroke(spinFrame)
	stroke.Color = Color3.fromRGB(255, 50, 50)
	stroke.Thickness = 6
	stroke.Enabled = true

	screenFlash(Color3.fromRGB(200, 20, 20), 0.65, 0.5)
	screenShake(8, 0.5)
	pulseStroke(stroke, 6, 12, 0.8)
	spawnParticles(8, Color3.fromRGB(255, 50, 50), spinFrame)

	task.delay(2.0, function()
		stroke.Enabled = false
	end)
end

-- TIER 7: Divine
function RarityEffects.Divine(spinFrame)
	local stroke = getOrCreateStroke(spinFrame)
	stroke.Color = Color3.fromRGB(0, 220, 255)
	stroke.Thickness = 5
	stroke.Enabled = true

	screenFlash(Color3.fromRGB(0, 220, 255), 0.65, 0.5)
	letterbox(1.2)
	spawnParticles(12, Color3.fromRGB(0, 220, 255), spinFrame)
	pulseStroke(stroke, 5, 10, 0.9)

	-- Rotate SpinFrame: -3 -> 3 -> 0
	task.spawn(function()
		local t1 = TweenService:Create(
			spinFrame,
			TweenInfo.new(0.2, Enum.EasingStyle.Sine),
			{ Rotation = -3 }
		)
		t1:Play() t1.Completed:Wait()
		local t2 = TweenService:Create(
			spinFrame,
			TweenInfo.new(0.4, Enum.EasingStyle.Sine),
			{ Rotation = 3 }
		)
		t2:Play() t2.Completed:Wait()
		local t3 = TweenService:Create(
			spinFrame,
			TweenInfo.new(0.2, Enum.EasingStyle.Sine),
			{ Rotation = 0 }
		)
		t3:Play()
	end)

	task.delay(2.5, function()
		stroke.Enabled = false
	end)
end

-- TIER 8: Corrupted
function RarityEffects.Corrupted(spinFrame)
	local stroke = getOrCreateStroke(spinFrame)
	stroke.Color = Color3.fromRGB(80, 0, 120)
	stroke.Thickness = 8
	stroke.Enabled = true

	-- Glitch flash: alternate dark overlays 5 times rapidly
	task.spawn(function()
		for _ = 1, 5 do
			screenFlash(Color3.fromRGB(10, 0, 20), 0.3, 0.08)
			task.wait(0.1)
		end
	end)

	-- SpinFrame flicker
	task.spawn(function()
		for _ = 1, 3 do
			spinFrame.Visible = false
			task.wait(0.07)
			spinFrame.Visible = true
			task.wait(0.07)
		end
	end)

	pulseStroke(stroke, 8, 14, 1.0)

	-- Glitch the Rarity label text
	local rarityLabel = spinFrame:FindFirstChild("Rarity")
	local originalText = rarityLabel and rarityLabel.Text or "Corrupted"
	glitchLabel(spinFrame, "Rarity", originalText, 0.8)

	-- "CORRUPTED" float label
	floatLabel("CORRUPTED", Color3.fromRGB(140, 0, 200))

	task.delay(2.5, function()
		stroke.Enabled = false
	end)
end

-- TIER 9: Celestial
function RarityEffects.Celestial(spinFrame)
	local stroke = getOrCreateStroke(spinFrame)
	stroke.Color = Color3.fromRGB(255, 100, 255)
	stroke.Thickness = 7
	stroke.Enabled = true

	-- Sequential pink then white flash
	screenFlash(Color3.fromRGB(255, 100, 255), 0.55, 0.3)
	task.delay(0.3, function()
		screenFlash(Color3.new(1, 1, 1), 0.5, 0.4)
	end)

	spawnParticles(20, Color3.fromRGB(255, 100, 255), spinFrame)
	twinkleStars(15, 2.5)
	rainbowStroke(stroke, 30, 0.07)

	-- Scale up 1.2x then back
	task.spawn(function()
		local origSize = spinFrame.Size
		local bigSize = UDim2.new(
			origSize.X.Scale * 1.2, origSize.X.Offset * 1.2,
			origSize.Y.Scale * 1.2, origSize.Y.Offset * 1.2
		)
		local t1 = TweenService:Create(
			spinFrame,
			TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Size = bigSize }
		)
		t1:Play() t1.Completed:Wait()
		local t2 = TweenService:Create(
			spinFrame,
			TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Size = origSize }
		)
		t2:Play()
	end)

	task.delay(3.0, function()
		stroke.Enabled = false
	end)
end

-- TIER 10: Secret
function RarityEffects.Secret(spinFrame)
	local stroke = getOrCreateStroke(spinFrame)
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Thickness = 10
	stroke.Enabled = true

	-- Round 1: full white flash
	screenFlash(Color3.new(1, 1, 1), 0, 0.5)
	screenShake(15, 1.0)
	letterbox(2.0)
	spawnParticles(30, Color3.new(1, 1, 1), spinFrame)

	-- Round 2: rapid color flashes
	task.spawn(function()
		local colors = {
			Color3.fromRGB(255, 0, 0),
			Color3.fromRGB(255, 165, 0),
			Color3.fromRGB(255, 255, 0),
			Color3.fromRGB(0, 255, 0),
			Color3.fromRGB(0, 100, 255),
		}
		for _, c in ipairs(colors) do
			screenFlash(c, 0.4, 0.15)
			task.wait(0.18)
		end
	end)

	-- Scale SpinFrame to 1.3x with rainbow stroke
	task.spawn(function()
		local origSize = spinFrame.Size
		local bigSize = UDim2.new(
			origSize.X.Scale * 1.3, origSize.X.Offset * 1.3,
			origSize.Y.Scale * 1.3, origSize.Y.Offset * 1.3
		)
		local t1 = TweenService:Create(
			spinFrame,
			TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Size = bigSize }
		)
		t1:Play() t1.Completed:Wait()
		rainbowStroke(stroke, 60, 0.05)
		task.wait(1.5)
		local t2 = TweenService:Create(
			spinFrame,
			TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Size = origSize }
		)
		t2:Play()
	end)

	-- "???" explodes in size
	task.spawn(function()
		local ql = Instance.new("TextLabel")
		ql.Size = UDim2.fromOffset(200, 100)
		ql.AnchorPoint = Vector2.new(0.5, 0.5)
		ql.Position = UDim2.new(0.5, 0, 0.5, 0)
		ql.BackgroundTransparency = 1
		ql.Text = "???"
		ql.TextColor3 = Color3.new(1, 1, 1)
		ql.TextSize = 20
		ql.Font = Enum.Font.GothamBold
		ql.TextTransparency = 0
		ql.ZIndex = 75
		ql.Parent = effectsGui

		local t = TweenService:Create(
			ql,
			TweenInfo.new(0.8, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ TextSize = 120, TextTransparency = 0.1 }
		)
		t:Play() t.Completed:Wait()
		task.wait(0.3)
		local t2 = TweenService:Create(
			ql,
			TweenInfo.new(0.5),
			{ TextTransparency = 1 }
		)
		t2:Play()
		t2.Completed:Connect(function() ql:Destroy() end)
	end)

	-- Massive "SECRET" label in screen center
	task.delay(0.6, function()
		local secretLbl = Instance.new("TextLabel")
		secretLbl.Size = UDim2.new(1, 0, 0, 160)
		secretLbl.AnchorPoint = Vector2.new(0.5, 0.5)
		secretLbl.Position = UDim2.new(0.5, 0, 0.5, 0)
		secretLbl.BackgroundTransparency = 1
		secretLbl.Text = "SECRET"
		secretLbl.TextColor3 = Color3.new(1, 1, 1)
		secretLbl.TextScaled = true
		secretLbl.Font = Enum.Font.GothamBold
		secretLbl.TextTransparency = 0.1
		secretLbl.ZIndex = 90
		secretLbl.Parent = effectsGui

		-- Glow UIStroke on text
		local textStroke = Instance.new("UIStroke")
		textStroke.Color = Color3.fromRGB(255, 255, 255)
		textStroke.Thickness = 3
		textStroke.Parent = secretLbl

		task.wait(1.2)
		local fadeOut = TweenService:Create(
			secretLbl,
			TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ TextTransparency = 1 }
		)
		fadeOut:Play()
		fadeOut.Completed:Connect(function() secretLbl:Destroy() end)
	end)

	task.delay(4.0, function()
		stroke.Enabled = false
	end)
end

-- ─────────────────────────────────────────────
-- Rarity -> Effect dispatcher
-- ─────────────────────────────────────────────

local RARITY_MAP = {
	["Common"]    = RarityEffects.Common,
	["Uncommon"]  = RarityEffects.Uncommon,
	["Rare"]      = RarityEffects.Rare,
	["Epic"]      = RarityEffects.Epic,
	["Legendary"] = RarityEffects.Legendary,
	["Mythical"]  = RarityEffects.Mythical,
	["Divine"]    = RarityEffects.Divine,
	["Corrupted"] = RarityEffects.Corrupted,
	["Celestial"] = RarityEffects.Celestial,
	["Secret"]    = RarityEffects.Secret,
}

local function triggerEffect(rarityName)
	local spinFrame = getSpinFrame()
	if not spinFrame then
		warn("[RarityVisuals] SpinFrame not found – skipping effect for: " .. tostring(rarityName))
		return
	end

	local fn = RARITY_MAP[rarityName]
	if fn then
		task.spawn(fn, spinFrame)
	else
		warn("[RarityVisuals] Unknown rarity: " .. tostring(rarityName))
	end
end

-- ─────────────────────────────────────────────
-- Listen for spin results from SpinConnector
-- Server fires SpinEvent back to client with
-- an array of result tables: { brainrot, rarity, perk }
-- We trigger the effect for the last (final) result.
-- ─────────────────────────────────────────────

SpinEvent.OnClientEvent:Connect(function(results)
	if type(results) ~= "table" then return end
	local latest = results[#results]
	if not latest then return end

	local rarityName = latest.rarity
	if rarityName then
		triggerEffect(rarityName)
	end
end)

print("[RarityVisuals] Loaded – listening for spin results.")
