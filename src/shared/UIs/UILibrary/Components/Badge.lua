--[=[
	@class Badge

	Themed badge — small rounded pill showing text and/or icon. Wraps OnyxUI's
	Badge primitive with theme-aware coloring.

	Reads `Theme.Badge.ColorRole` (default "Primary") for the default color.
	Per-instance overrides:
	  * `ColorRole` — palette role string ("Primary", "Success", "Warning",
	    "Error", "Info", "Secondary", etc.). Resolved via Theme.Colors[role].Main.
	  * `Color` — raw Color3 / State<Color3> (takes precedence over ColorRole).

	`Content` is passed through to OnyxUI Badge — array of strings (icon asset
	ids and/or plain text), e.g. `{ "Sale" }`, `{ "rbxassetid://...", "-50%" }`.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local OnyxUI = ReplicatedStorage.Packages.OnyxUI.Packages.OnyxUI
local OnyxBadge = require(OnyxUI.Components.Badge)

return function(deps, lib)
	local Fusion = deps.Fusion
	local Themer = deps.Themer
	local Util = deps.Util
	local CombineProps = deps.CombineProps
	local Components = deps.Components
	local configValue = deps.configValue
	local configSlot = deps.configSlot
	local themeColor = deps.themeColor

	-- Pre-merge OnyxUI's Badge into the components table so Scope:Badge works.
	local mergedComponents = table.clone(Components)
	mergedComponents.Badge = OnyxBadge

	return function(Scope, Props)
		Props = Props or {}
		Scope = Fusion.innerScope(Scope, Fusion, Util, mergedComponents)
		local Theme = Themer.Theme:now()
		local badgeConfig = configSlot(Theme, "Badge")

		local colorRole = Props.ColorRole or configValue(badgeConfig.ColorRole, "Primary")
		Props.ColorRole = nil

		local color = Props.Color
		Props.Color = nil

		if color == nil then
			-- themeColor returns the State<Color3> directly; OnyxUI accepts
			-- Fusion State objects for Color, so no Computed wrapper needed.
			color = themeColor(Theme, colorRole, "Main")
		end

		-- Optional theme-driven overrides. When the theme sets these we pass
		-- them through so OnyxUI's defaults are overridden:
		--   `CornerRadius` (UDim)  → `Corner = { Radius = ... }`
		--   `Padding`     (table)  → forwarded as-is (e.g. `{ All, Left, Right }`)
		--
		-- Pin ContentColor to white so the auto-stroke (black, contextual)
		-- always outlines a light interior. OnyxUI's default ContentColor
		-- is Util.Emphasize(Color, Contrast), which picks dark text against
		-- bright role colors (Primary/Secondary/Success/Warning/Info). Bold
		-- weight + dark fill + black stroke collapses into mushy glyphs.
		local extras = { Color = color, ContentColor = Color3.new(1, 1, 1) }
		local cornerRadius = badgeConfig.CornerRadius
		if cornerRadius ~= nil then
			extras.Corner = { Radius = cornerRadius }
		end
		local padding = badgeConfig.Padding
		if padding ~= nil then
			extras.Padding = padding
		end

		return Scope:Badge(CombineProps(Props, extras))
	end
end
