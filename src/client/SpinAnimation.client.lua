-- SpinAnimation LocalScript
-- Disaster RNG — Subagent 3 (Spin System UI)
--
-- Event flow:
--   RoundEvent("RoundEnd") fires  →  we start slot-machine animation + FireServer
--   SpinEvent.OnServerEvent fires  →  SpinConnector.DoSpin → FireClient(results)
--   SpinEvent.OnClientEvent(results) fires here  →  we reveal results in sequence
--   RarityVisuals listens to the same OnClientEvent and fires overlay FX in parallel

local Players        = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService   = game:GetService("TweenService")
local RunService     = game:GetService("RunService")

local player     = Players.LocalPlayer
local playerGui  = player:WaitForChild("PlayerGui")

local RoundEvent = ReplicatedStorage:WaitForChild("RoundEvent")
local SpinEvent  = ReplicatedStorage:WaitForChild("SpinEvent")

-- ─────────────────────────────────────────────────────────────────────────────
-- Rarity data (local copy — no Module require to avoid timing issues)
-- ─────────────────────────────────────────────────────────────────────────────
local RARITIES = {
	{name = "Common",    color = Color3.fromRGB(200, 200, 200)},
	{name = "Uncommon",  color = Color3.fromRGB(80,  200, 80)},
	{name = "Rare",      color = Color3.fromRGB(60,  120, 255)},
	{name = "Epic",      color = Color3.fromRGB(160, 60,  255)},
	{name = "Legendary", color = Color3.fromRGB(255, 200, 0)},
	{name = "Mythical",  color = Color3.fromRGB(255, 50,  50)},
	{name = "Divine",    color = Color3.fromRGB(0,   220, 255)},
	{name = "Corrupted", color = Color3.fromRGB(80,  0,   120)},
	{name = "Celestial", color = Color3.fromRGB(255, 100, 255)},
	{name = "Secret",    color = Color3.fromRGB(255, 255, 255)},
}

-- Quick lookup: rarity name → color
local RARITY_COLOR = {}
for _, r in ipairs(RARITIES) do
	RARITY_COLOR[r.name] = r.color
end

-- Tiers 7–10 get mystery suspense buildup before reveal
local MYSTERY_RARITIES = {Divine=true, Corrupted=true, Celestial=true, Secret=true}

-- Slot-machine speed steps: delay between each rarity flip (seconds)
-- Starts very fast, decelerates toward the landing
local SPIN_SPEEDS = {0.06, 0.06, 0.07, 0.08, 0.10, 0.13, 0.17, 0.22, 0.30, 0.42, 0.58}

-- ─────────────────────────────────────────────────────────────────────────────
-- GUI references
-- ─────────────────────────────────────────────────────────────────────────────
local gameUI    = playerGui:WaitForChild("GameUI", 15)
local spinFrame = gameUI and gameUI:WaitForChild("SpinFrame", 10)

if not spinFrame then
	warn("[SpinAnimation] SpinFrame not found — aborting.")
	return
end

-- Labels inside SpinFrame
local labelRarity  = spinFrame:WaitForChild("Rarity",     5)
local labelBrainrot= spinFrame:WaitForChild("Brainrot",   5)
local labelPerk    = spinFrame:WaitForChild("Perk",       5)
local labelBonus   = spinFrame:WaitForChild("BonusLabel", 5)

-- ─────────────────────────────────────────────────────────────────────────────
-- Overlay ScreenGui for dim effect during mystery reveal
-- (DisplayOrder 50 — below RarityVisuals at 100, above normal game UI)
-- ─────────────────────────────────────────────────────────────────────────────
local spinGui = Instance.new("ScreenGui")
spinGui.Name            = "SpinAnimGui"
spinGui.DisplayOrder    = 50
spinGui.ZIndexBehavior  = Enum.ZIndexBehavior.Global
spinGui.ResetOnSpawn    = false
spinGui.Parent          = playerGui

-- Dim overlay (used for mystery suspense, normally fully transparent)
local dimFrame = Instance.new("Frame")
dimFrame.Name                   = "DimOverlay"
dimFrame.Size                   = UDim2.fromScale(1, 1)
dimFrame.Position               = UDim2.fromScale(0, 0)
dimFrame.BackgroundColor3       = Color3.new(0, 0, 0)
dimFrame.BackgroundTransparency = 1
dimFrame.BorderSizePixel        = 0
dimFrame.ZIndex                 = 5
dimFrame.Parent                 = spinGui

-- ─────────────────────────────────────────────────────────────────────────────
-- State
-- ─────────────────────────────────────────────────────────────────────────────
local activeThread  = nil  -- currently running animation coroutine/task
local pendingResults = nil -- set by OnClientEvent, consumed by animation
local resultsSignal  = nil -- BindableEvent used to notify slot loop
local luckMultiplier = 1
local isAnimating    = false

-- ─────────────────────────────────────────────────────────────────────────────
-- Tween helper
-- ─────────────────────────────────────────────────────────────────────────────
local function tw(instance, info, props)
	local t = TweenService:Create(instance, info, props)
	t:Play()
	return t
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Reset all label appearances to transparent/hidden starting states
-- ─────────────────────────────────────────────────────────────────────────────
local function resetLabels()
	-- Rarity: will be set by slot machine loop first, then revealed
	if labelRarity then
		labelRarity.Text             = ""
		labelRarity.TextTransparency = 0
		labelRarity.TextSize         = labelRarity.TextSize  -- preserve designer size
	end
	if labelBrainrot then
		labelBrainrot.Text             = ""
		labelBrainrot.TextTransparency = 1
		labelBrainrot.Position         = UDim2.new(
			labelBrainrot.Position.X.Scale, labelBrainrot.Position.X.Offset,
			labelBrainrot.Position.Y.Scale, labelBrainrot.Position.Y.Offset + 30
		)
	end
	if labelPerk then
		labelPerk.Text             = ""
		labelPerk.TextTransparency = 1
	end
	if labelBonus then
		labelBonus.Text             = ""
		labelBonus.TextTransparency = 1
		labelBonus.Visible          = false
	end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Dim overlay helpers
-- ─────────────────────────────────────────────────────────────────────────────
local function dimScreen(toAlpha, duration)
	tw(dimFrame, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{BackgroundTransparency = 1 - toAlpha})
end

local function undimScreen(duration)
	tw(dimFrame, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{BackgroundTransparency = 1})
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Slot-machine flash: rapidly set rarity bg color and text
-- ─────────────────────────────────────────────────────────────────────────────
local function setSlotDisplay(rarityName, rarityColor)
	spinFrame.BackgroundColor3       = rarityColor
	spinFrame.BackgroundTransparency = 0.25
	if labelRarity then
		labelRarity.Text = rarityName
	end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Phase 2: Slot-machine spin animation
-- Runs through SPIN_SPEEDS steps, flipping random rarities.
-- Returns only after the slowdown sequence completes.
-- resultRarity is the landing rarity (used at end).
-- ─────────────────────────────────────────────────────────────────────────────
local function runSlotMachine(resultRarity, resultColor)
	-- Fast random phase (before SPIN_SPEEDS kicks in)
	local FAST_FLIPS = 14  -- number of rapid flips at top speed
	for i = 1, FAST_FLIPS do
		local r = RARITIES[math.random(1, #RARITIES)]
		setSlotDisplay(r.name, r.color)
		task.wait(0.06)
	end

	-- Deceleration phase (SPIN_SPEEDS)
	for i, delay in ipairs(SPIN_SPEEDS) do
		local r
		if i == #SPIN_SPEEDS then
			-- Final step: lock onto result
			r = {name = resultRarity, color = resultColor}
		else
			r = RARITIES[math.random(1, #RARITIES)]
		end
		setSlotDisplay(r.name, r.color)
		task.wait(delay)
	end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Mystery suspense (for Divine / Corrupted / Celestial / Secret)
-- Shows ??? and dims the screen for dramatic effect before burst reveal.
-- ─────────────────────────────────────────────────────────────────────────────
local function runMysterySuspense(resultColor)
	-- Show ??? on rarity label
	if labelRarity then
		labelRarity.Text = "???"
	end
	spinFrame.BackgroundColor3       = Color3.fromRGB(20, 0, 30)
	spinFrame.BackgroundTransparency = 0.1

	-- Dim the screen
	dimScreen(0.55, 0.35)

	-- Pulse spinFrame stroke for anticipation
	local stroke = spinFrame:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color     = Color3.fromRGB(150, 0, 200)
		stroke.Thickness = 6
		stroke.Enabled   = true
		tw(stroke,
			TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 1, true),
			{Thickness = 12}
		)
	end

	task.wait(0.8)

	-- Screen flash burst: white flash then undim
	local burstFrame = Instance.new("Frame")
	burstFrame.Size                   = UDim2.fromScale(1, 1)
	burstFrame.BackgroundColor3       = Color3.new(1, 1, 1)
	burstFrame.BackgroundTransparency = 0.15
	burstFrame.BorderSizePixel        = 0
	burstFrame.ZIndex                 = 20
	burstFrame.Parent                 = spinGui

	tw(burstFrame,
		TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{BackgroundTransparency = 1}
	).Completed:Connect(function() burstFrame:Destroy() end)

	-- Restore dim
	undimScreen(0.3)

	if stroke then
		stroke.Enabled = false
	end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Phase 3 helpers: label reveal animations
-- ─────────────────────────────────────────────────────────────────────────────

-- Scale-in on rarity: starts huge, shrinks to normal (TextSize based)
local function revealRarity(rarityName, rarityColor)
	if not labelRarity then return end

	-- Ensure frame settled on result colour
	spinFrame.BackgroundColor3       = rarityColor
	spinFrame.BackgroundTransparency = 0.15

	labelRarity.Text = rarityName

	-- Quick BackgroundTransparency pulse on spinFrame (rarity color flash)
	tw(spinFrame,
		TweenInfo.new(0.08, Enum.EasingStyle.Linear),
		{BackgroundTransparency = 0}
	).Completed:Connect(function()
		tw(spinFrame,
			TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{BackgroundTransparency = 0.25}
		)
	end)

	-- Scale animation: TextSize starts at 2× normal, springs down
	local normalSize = labelRarity.TextSize
	labelRarity.TextScaled = false
	labelRarity.TextSize   = normalSize * 2.2

	tw(labelRarity,
		TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{TextSize = normalSize}
	)
	task.wait(0.5)
end

-- Slide-up reveal for brainrot label
local function revealBrainrot(brainrotName)
	if not labelBrainrot then return end

	-- Snap into offset-below position, then slide to natural position
	local origPos = UDim2.new(
		labelBrainrot.Position.X.Scale, labelBrainrot.Position.X.Offset,
		labelBrainrot.Position.Y.Scale, labelBrainrot.Position.Y.Offset - 30  -- undo the +30 offset from reset
	)
	local offPos  = UDim2.new(
		origPos.X.Scale, origPos.X.Offset,
		origPos.Y.Scale, origPos.Y.Offset + 30
	)

	labelBrainrot.Text             = brainrotName
	labelBrainrot.Position         = offPos
	labelBrainrot.TextTransparency = 1

	tw(labelBrainrot,
		TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Position = origPos, TextTransparency = 0}
	)
	task.wait(0.35)
end

-- Fade-in for perk label
local function revealPerk(perkName)
	if not labelPerk then return end
	labelPerk.Text             = perkName
	labelPerk.TextTransparency = 1
	tw(labelPerk,
		TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{TextTransparency = 0}
	)
	task.wait(0.4)
end

-- Bounce-in for bonus label
local function revealBonus(multiplierValue)
	if not labelBonus then return end

	labelBonus.Text             = "BONUS x" .. tostring(multiplierValue) .. "!"
	labelBonus.TextColor3       = Color3.fromRGB(255, 215, 0)
	labelBonus.TextTransparency = 1
	labelBonus.Visible          = true

	-- Fade + slight upward bounce
	tw(labelBonus,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{TextTransparency = 0}
	)

	-- Gold border flash on spinFrame
	task.spawn(function()
		local origColor = spinFrame.BackgroundColor3
		tw(spinFrame,
			TweenInfo.new(0.15, Enum.EasingStyle.Linear),
			{BackgroundColor3 = Color3.fromRGB(255, 200, 0)}
		).Completed:Connect(function()
			tw(spinFrame,
				TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{BackgroundColor3 = origColor}
			)
			end)
	end)
	task.wait(0.3)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- SpinFrame slide-out: eases down off screen (Back.In feel)
-- ─────────────────────────────────────────────────────────────────────────────
local function hideSpinFrame()
	local targetPos = UDim2.new(
		spinFrame.Position.X.Scale,  spinFrame.Position.X.Offset,
		spinFrame.Position.Y.Scale,  spinFrame.Position.Y.Offset + 350
	)
	tw(spinFrame,
		TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.In),
		{Position = targetPos, BackgroundTransparency = 0.8}
	).Completed:Connect(function()
		spinFrame.Visible = false
		spinFrame.BackgroundTransparency = 0.2  -- reset for next show
	end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Transition between bonus results
-- ─────────────────────────────────────────────────────────────────────────────
local function transitionResult()
	-- Flash white, briefly blank labels
	local flashFrame = Instance.new("Frame")
	flashFrame.Size                   = UDim2.fromScale(1, 1)
	flashFrame.BackgroundColor3       = Color3.new(1, 1, 1)
	flashFrame.BackgroundTransparency = 0.2
	flashFrame.BorderSizePixel        = 0
	flashFrame.ZIndex                 = 15
	flashFrame.Parent                 = spinGui

	tw(flashFrame,
		TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{BackgroundTransparency = 1}
	).Completed:Connect(function() flashFrame:Destroy() end)

	if labelBrainrot then labelBrainrot.TextTransparency = 1 end
	if labelPerk      then labelPerk.TextTransparency     = 1 end
	if labelBonus     then labelBonus.Visible             = false end
	task.wait(0.25)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Core animation sequence — runs for one full set of results
-- ─────────────────────────────────────────────────────────────────────────────
local function animateResults(results)
	isAnimating = true

	for i, result in ipairs(results) do
		local rarityName  = result.rarity  or "Common"
		local rarityColor = RARITY_COLOR[rarityName] or Color3.fromRGB(200, 200, 200)
		local brainrotName= result.brainrot or ""
		local perkName    = result.perk    or ""
		local bonusVal    = result.bonus   -- nil for first spin, number for bonus spins

		-- ── Transition frame for bonus ──────────────────────────────────────────
		if i > 1 then
			transitionResult()
			-- Mini slot machine for bonus spin
			runSlotMachine(rarityName, rarityColor)
		end

		-- ── Mystery suspense for high-tier rarities ──────────────────────────────
		if MYSTERY_RARITIES[rarityName] then
			runMysterySuspense(rarityColor)
		end

		-- ── Phase 3: Result Reveal ───────────────────────────────────────────────
		-- 3a: Rarity with scale punch
		revealRarity(rarityName, rarityColor)

		-- 3b: Wait then slide up brainrot
		task.wait(0.5)
		revealBrainrot(brainrotName)

		-- 3c: Wait then fade in perk
		task.wait(0.3)
		if perkName ~= "" and perkName ~= "???" then
			revealPerk(perkName)
		end

		-- 3d: Bonus multiplier label (for bonus chain entries)
		if bonusVal then
			task.wait(0.15)
			revealBonus(bonusVal)
		end

		-- ── Hold time: 2s per result ─────────────────────────────────────────────
		task.wait(2)
	end

	-- ── Phase 5: Hide SpinFrame ──────────────────────────────────────────────
	hideSpinFrame()
	undimScreen(0.5)

	isAnimating = false
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Full spin sequence: slot-machine → wait for results → reveal
-- This is spawned on RoundEnd.
-- ─────────────────────────────────────────────────────────────────────────────
local function startSpinSequence(luck)
	-- Cancel any in-progress animation
	if activeThread then
		task.cancel(activeThread)
		activeThread = nil
		isAnimating  = false
		undimScreen(0)
	end

	activeThread = task.spawn(function()
		-- SpinFrame may have been shown already by DisasterUI.showSpinFrame().
		-- Ensure it is visible and in a clean state.
		spinFrame.Visible = true
		resetLabels()

		-- ── Phase 1: Request spin from server ───────────────────────────────────
		-- SpinConnector listens for OnServerEvent(player, luckMultiplier)
		SpinEvent:FireServer(luck)

		-- ── Phase 2a: Fast slot-machine while we wait for server response ───────
		-- We run a short "free spin" (no specific target yet) while the results
		-- are in flight (network round-trip is typically <100 ms in Studio).
		-- When OnClientEvent fires, pendingResults is populated.
		pendingResults = nil

		-- Run fast pre-spin (8 flips) — purely cosmetic, results likely arrive
		-- within this window or shortly after
		for _ = 1, 8 do
			local r = RARITIES[math.random(1, #RARITIES)]
			setSlotDisplay(r.name, r.color)
			task.wait(0.06)
		end

		-- Wait for results (with timeout safety)
		local waitStart = os.clock()
		while pendingResults == nil do
			task.wait(0.03)
			if os.clock() - waitStart > 8 then
				warn("[SpinAnimation] Timed out waiting for spin results.")
				spinFrame.Visible = false
				return
			end
		end

		local results = pendingResults
		pendingResults = nil

		-- ── Phase 2b: Full slot-machine deceleration onto first result ───────────
		local firstRarity = results[1] and results[1].rarity or "Common"
		local firstColor  = RARITY_COLOR[firstRarity] or Color3.fromRGB(200, 200, 200)
		runSlotMachine(firstRarity, firstColor)

		-- ── Phases 3-5: Reveal all results (including bonus chain) ───────────────
		animateResults(results)
		activeThread = nil
	end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Event listeners
-- ─────────────────────────────────────────────────────────────────────────────

-- RoundEnd: kick off the spin sequence
RoundEvent.OnClientEvent:Connect(function(eventType, data)
	if eventType == "RoundEnd" then
		-- Extract luckBonus from the RoundEnd payload (set by RoundManager).
		-- data.luckBonus is the per-player luck multiplier for this spin.
		if type(data) == "table" and data.luckBonus then
			luckMultiplier = data.luckBonus
		end
		-- DisasterUI also handles RoundEnd (hides DisasterFrame, calls showSpinFrame).
		-- We start our sequence a hair later so DisasterUI's showSpinFrame goes first,
		-- then we take over. task.defer is enough — same frame, after current callbacks.
		task.defer(function()
			startSpinSequence(luckMultiplier)
		end)
	end
end)

-- SpinEvent client receives the results table from SpinConnector
SpinEvent.OnClientEvent:Connect(function(payload)
	-- Guard: if it's not a table, ignore (RarityVisuals has same guard)
	if type(payload) ~= "table" then return end

	-- Store results so startSpinSequence's wait-loop picks them up
	pendingResults = payload
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Initial state
-- ─────────────────────────────────────────────────────────────────────────────
spinFrame.Visible = false
resetLabels()

print("[SpinAnimation] Loaded — listening for RoundEnd and SpinEvent.")
