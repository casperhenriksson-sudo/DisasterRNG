--[=[
	@class Button

	Theme-driven, ShadCN-style variants. Render mode is auto-detected from the
	resolved spec:
	  * Image set  → image-backed render (asset fills the button)
	  * Color set  → vertical gradient render (ColorSequence)
	  * Neither    → bare frame (Ghost-style)

	Two input shapes for the visual spec, in priority order (highest first):
	  1. Top-level Props.Image and/or Props.ColorSequence — convenience for
	     one-offs; coalesced onto the base variant.
	  2. Props.Variant — full spec table { Image=, Color=, TextColor3=,
	     TextSize=, Stroke=, Corner=, PressScale=, HoverScale= }, or a bare
	     string treated as { Image = string }.

	Theme-config shape for `Theme.Button.<Variant>` (e.g. Default, Active,
	Secondary, …). Each entry is either a bare asset-id string (back-compat)
	or a table:

	    Theme.Button.Active = {
	        Image = "rbxassetid://...",          -- background asset
	        TextColor3 = Color3.fromHex("FFD93D"), -- per-variant label color
	        TextSize = 28,                         -- per-variant label size
	    }

	Any field can be omitted; missing values fall back to the component's
	defaults (white text, Theme.TextSize["1.5"], no image).

	Content layers, bottom to top:
	  UIScale → gradient frame → image frame → ButtonContent (user
	  children, only when [Children] is provided) → Heading text overlay.

	Disabled state (Props.Disabled): runtime treatment only. Tints all layers
	to 0.5 transparency, freezes hover/press springs, and suppresses
	OnActivate. There is no per-variant disabled spec — same approach as
	OnyxUI.
]=]

return function(deps, lib)
	local Fusion = deps.Fusion
	local Themer = deps.Themer
	local Util = deps.Util
	local CombineProps = deps.CombineProps
	local Children = deps.Children
	local peek = deps.peek
	local Components = deps.Components

	return function(Scope, Props)
		Props = Props or {}
		Scope = Fusion.innerScope(Scope, Fusion, Util, Components)
		local Theme = Themer.Theme:now()

		-- Variant input shapes:
		--   1. bare string                → { Image = string }
		--   2. plain spec table           → used directly
		--   3. Fusion state object (e.g.  → resolved each frame; lets
		--      a Computed flipping           tab-style buttons re-skin
		--      between Active/Default)       reactively when selection
		--                                    changes.
		local rawVariant = Props.Variant
		if type(rawVariant) == "string" then
			rawVariant = { Image = rawVariant }
		end
		local variantState = (type(rawVariant) == "table" and rawVariant.type == "State") and rawVariant or nil
		local variant = (not variantState) and (rawVariant or {}) or nil

		-- Top-level Image / ColorSequence shortcuts override the base variant.
		-- Only apply to static variants — overriding a reactive variant
		-- would defeat its reactivity. Reactive callers already control
		-- the spec table they emit.
		if variant and (Props.Image ~= nil or Props.ColorSequence ~= nil) then
			variant = table.clone(variant)
			if Props.Image ~= nil then
				variant.Image = Props.Image
			end
			if Props.ColorSequence ~= nil then
				variant.Color = Props.ColorSequence
			end
		end

		-- Pull out everything we render or wire ourselves so CombineProps
		-- doesn't forward them to BaseButton as junk.
		local userChildren = Props[Children]
		local text = Props.Text
		local textPropsOverride = Props.TextProps
		local disabled = Util.Fallback(Props.Disabled, false)
		local onActivate = Props.OnActivate

		Props[Children] = nil
		Props.Variant = nil
		Props.Image = nil
		Props.ColorSequence = nil
		Props.Text = nil
		Props.TextProps = nil
		Props.Disabled = nil
		Props.OnActivate = nil

		-- Variant fields. For static variants these are simple reads. For
		-- reactive variants (a Computed that flips between spec tables —
		-- e.g. tab buttons toggling Active/Default), each field is its
		-- own Computed so changes to the underlying state propagate to
		-- the corresponding instance prop.
		--
		-- Per-variant text overrides (TextColor3 / TextSize) let theme
		-- configs give each button variant its own label treatment.
		local image, color, textColor3, textSize
		if variantState then
			image = Scope:Computed(function(use)
				local v = use(variantState) or {}
				return v.Image or v.BackgroundImage
			end)
			color = Scope:Computed(function(use)
				local v = use(variantState) or {}
				return v.Color
			end)
			textColor3 = Scope:Computed(function(use)
				local v = use(variantState) or {}
				return v.TextColor3 or v.TextColor
			end)
			textSize = Scope:Computed(function(use)
				local v = use(variantState) or {}
				return v.TextSize
			end)
		else
			image = variant.Image or variant.BackgroundImage
			color = variant.Color
			textColor3 = variant.TextColor3 or variant.TextColor
			textSize = variant.TextSize
		end

		-- Single reactive value driving every "this is dimmed because disabled"
		-- transparency. 0 when active, 0.5 when disabled.
		local disabledTint = Scope:Computed(function(use)
			return use(disabled) and 0.5 or 0
		end)

		-- Press feedback: hover bumps slightly, hold squishes hard, both spring back.
		-- Spring freezes at 1 when disabled — no animation while in that state.
		local hovering = Scope:EnsureValue(Util.Fallback(Props.Hovering, false))
		local holding = Scope:EnsureValue(Util.Fallback(Props.Holding, false))
		Props.Hovering = nil
		Props.Holding = nil
		local rawScale = Scope:Spring(
			Scope:Computed(function(use)
				if use(disabled) then
					return 1
				end
				local v = if variantState then use(variantState) else variant
				v = v or {}
				if use(holding) then
					return v.PressScale or 0.9
				elseif use(hovering) then
					return v.HoverScale or 1.025
				else
					return 1
				end
			end),
			Scope:Computed(function(use)
				return use(holding) and 10000 or 25
			end),
			0.25
		)

		-- Layer transparencies. Image wins over Color when both are present;
		-- when the layer is visible it fades with `disabledTint`. For reactive
		-- variants we resolve the gate inside a Computed so visibility flips
		-- correctly when the underlying state changes.
		local imageTransparency, gradientTransparency, gradientColor
		if variantState then
			imageTransparency = Scope:Computed(function(use)
				return use(image) ~= nil and use(disabledTint) or 1
			end)
			gradientTransparency = Scope:Computed(function(use)
				if use(image) ~= nil then return 1 end
				return use(color) ~= nil and use(disabledTint) or 1
			end)
			gradientColor = Scope:Computed(function(use)
				return use(color) or ColorSequence.new(Color3.new(1, 1, 1))
			end)
		else
			imageTransparency = if image then disabledTint else 1
			gradientTransparency = if image then 1 elseif color then disabledTint else 1
			gradientColor = color or ColorSequence.new(Color3.new(1, 1, 1))
		end

		-- Comic-style label: white fill + dark outline on every variant.
		-- The variant's `TextColor3` is repurposed as the *outline* color
		-- (each variant picks one that reads against its own background
		-- image); the fill is always white so glyphs pop instead of
		-- muddying into the bold weight + dark fill.
		--
		-- If the variant's TextColor3 is too light to function as an
		-- outline against the white fill (e.g. Destructive's #FFFFFF —
		-- meant for fill in the original interpretation), fall back to
		-- black so the outline stays visible.
		local effectiveTextColor = Color3.new(1, 1, 1)
		local function pickStrokeColor(c)
			if c == nil then return Color3.new(0, 0, 0) end
			if (c.R + c.G + c.B) / 3 > 0.7 then return Color3.new(0, 0, 0) end
			return c
		end
		local labelStrokeColor
		if variantState then
			labelStrokeColor = Scope:Computed(function(use)
				return pickStrokeColor(use(textColor3))
			end)
		else
			labelStrokeColor = pickStrokeColor(textColor3)
		end

		local headingProps = {
			Text = text,
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextSize = if variantState
				then Scope:Computed(function(use)
					return use(textSize) or use(Theme.TextSize["1.5"])
				end)
				else textSize or Theme.TextSize["1.5"],
			HeadingSize = 1,
			TextWrapped = false,
			TextColor3 = effectiveTextColor,
			TextTransparency = disabledTint,
			-- Explicit stroke using the variant's outline color. Setting
			-- Stroke skips the WrappedHeading auto-stroke that would
			-- otherwise paint a hardcoded black contextual outline.
			Stroke = {
				Color = labelStrokeColor,
				Thickness = 2,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
				LineJoinMode = Enum.LineJoinMode.Round,
			},
		}
		if type(textPropsOverride) == "table" then
			for k, v in pairs(textPropsOverride) do
				if k ~= "Text" then
					headingProps[k] = v
				end
			end
		end

		-- Visual layers go inside a centered wrapper so UIScale pivots
		-- around the button's center instead of the default top-left.
		local visualChildren = {
			Scope:New "UIScale" {
				Scale = Scope:Computed(function(use)
					return math.round(use(rawScale) * 100) / 100
				end),
			},
			Scope:Frame {
				Size = UDim2.fromScale(1, 1),
				AutomaticSize = Enum.AutomaticSize.None,
				BackgroundTransparency = gradientTransparency,
				Gradient = {
					Color = gradientColor,
					Rotation = 90,
				},
				Stroke = (variant and variant.Stroke) or { Enabled = false },
				Corner = variant and variant.Corner,
			},
			Scope:Image {
				Image = image or "",
				ImageTransparency = imageTransparency,
				Size = UDim2.fromScale(1, 1),
				AutomaticSize = Enum.AutomaticSize.None,
				BackgroundTransparency = 1,
				ScaleType = Enum.ScaleType.Stretch,
			},
		}

		if userChildren ~= nil then
			table.insert(visualChildren, Scope:New "Frame" {
				Name = "ButtonContent",
				Size = UDim2.fromScale(1, 1),
				AutomaticSize = Enum.AutomaticSize.None,
				BackgroundTransparency = 1,
				[Children] = {
					Scope:New "UIListLayout" {
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, 8),
						SortOrder = Enum.SortOrder.LayoutOrder,
					},
					userChildren,
				},
			})
		end

		if text ~= nil then
			headingProps.AutomaticSize = Enum.AutomaticSize.None
			table.insert(visualChildren, Scope:Heading(headingProps))
		end

		local buttonChildren = {
			Scope:New "Frame" {
				Name = "ScaleWrapper",
				Size = UDim2.fromScale(1, 1),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				AutomaticSize = Enum.AutomaticSize.None,
				BackgroundTransparency = 1,
				[Children] = visualChildren,
			},
		}

		return Scope:BaseButton(CombineProps(Props, {
			Name = "Button",
			Size = UDim2.new(1, 0, 0, 56),
			AutomaticSize = Enum.AutomaticSize.None,
			BackgroundTransparency = 1,
			Hovering = hovering,
			Holding = holding,
			OnActivate = function()
				if not peek(disabled) and onActivate then
					onActivate()
				end
			end,
			[Children] = buttonChildren,
		}))
	end
end
