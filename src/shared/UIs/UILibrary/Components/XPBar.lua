--[=[
	@class XPBar

	Floating XP bar pill. Renders a label like "Level 12 — 1,234 / 5,000 XP"
	above a themed ProgressBar, all inside a HUD-style pill body.

	Layout:
	  ┌────────────────────────────────────────┐
	  │  Level 12 — 1,234 / 5,000 XP           │
	  │  ████████████░░░░░░░░░░░░░░░░░░░░░     │
	  └────────────────────────────────────────┘
	  └─────── pill (Frame or 9-slice) ────────┘

	Props:
	  Level      number | Value<number>
	  Current    number | Value<number>
	  Max        number | Value<number>
	  Format     ((level, current, max) -> string)?  — default "Level %d — %s / %s XP"
	  Label      string | Value<string>?             — overrides Format entirely (e.g. "MAX LEVEL")
	  ColorRole  string?                             — bar fill role
	  Size       UDim2?                              — default UDim2.fromOffset(280, 56)

	Theme slot `Theme.XPBar`:
	  ProgressColorRole       "Primary"
	  LabelColorRole          "BaseContent"
	  BackgroundColorRole     "Base" / "Neutral"
	  BackgroundTransparency  number
	  BackgroundImage         optional 9-slice asset — replaces the rectangle
	  BackgroundSliceCenter   Rect
	  CornerRadius            UDim
	  BarHeight               number  (default 14)
	  LabelGap                number  (default 6)
]=]

return function(deps, lib)
	local Fusion = deps.Fusion
	local Themer = deps.Themer
	local Util = deps.Util
	local CombineProps = deps.CombineProps
	local Children = deps.Children
	local Components = deps.Components
	local configValue = deps.configValue
	local configSlot = deps.configSlot
	local themeColor = deps.themeColor

	local function commaFormat(n)
		local s = tostring(math.floor(n))
		local sign = ""
		if s:sub(1, 1) == "-" then
			sign = "-"; s = s:sub(2)
		end
		while true do
			local replaced
			s, replaced = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
			if replaced == 0 then break end
		end
		return sign .. s
	end

	local function defaultFormat(level, current, max)
		return string.format(
			"Level %d — %s / %s XP",
			level or 0,
			commaFormat(current or 0),
			commaFormat(max or 0)
		)
	end

	return function(Scope, Props)
		Props = Props or {}
		Scope = Fusion.innerScope(Scope, Fusion, Util, Components)
		local Theme = Themer.Theme:now()
		local config = configSlot(Theme, "XPBar")

		local level = Props.Level
		Props.Level = nil
		local current = Props.Current
		Props.Current = nil
		local max = Props.Max
		Props.Max = nil

		local format = Props.Format or defaultFormat
		Props.Format = nil

		local labelOverride = Props.Label
		Props.Label = nil

		local progressColorRole = Props.ColorRole or configValue(config.ProgressColorRole, "Primary")
		Props.ColorRole = nil

		local labelColorRole = configValue(config.LabelColorRole, "BaseContent")
		local labelColor = themeColor(Theme, labelColorRole, "Main")

		local backgroundImage = Props.BackgroundImage or configValue(config.BackgroundImage, nil)
		Props.BackgroundImage = nil

		local bgColorRole = configValue(config.BackgroundColorRole, "Base")
		local bgColor = themeColor(Theme, bgColorRole, "Main")

		local barHeight = configValue(config.BarHeight, 14)
		local labelGap = configValue(config.LabelGap, 6)

		-- Computed label text. Reactive to Level/Current/Max (or Label override).
		local labelText = Scope:Computed(function(use)
			if labelOverride ~= nil then
				return tostring(use(labelOverride))
			end
			return format(use(level), use(current), use(max))
		end)

		-- Computed progress in 0..1. The underlying OnyxUI ProgressBar springs
		-- the fill, so the bar animates whenever Current/Max change.
		local progress = Scope:Computed(function(use)
			local c = use(current) or 0
			local m = use(max) or 0
			if m <= 0 then return 0 end
			return math.clamp(c / m, 0, 1)
		end)

		-- Pill body: 9-slice when the theme provides one, otherwise flat Frame
		-- with theme background + corner + stroke. Mirrors HUD's pattern.
		local pillBody
		if backgroundImage then
			pillBody = Scope:New "ImageLabel" {
				Name = "Background",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Image = backgroundImage,
				ScaleType = Enum.ScaleType.Slice,
				SliceCenter = configValue(config.BackgroundSliceCenter, Rect.new(32, 32, 32, 32)),
			}
		else
			pillBody = Scope:New "Frame" {
				Name = "Background",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = bgColor,
				BackgroundTransparency = configValue(config.BackgroundTransparency, 0.1),
				[Children] = {
					Scope:New "UICorner" {
						CornerRadius = configValue(
							config.CornerRadius,
							UDim.new(0, Theme.CornerRadius.Base)
						),
					},
					Scope:New "UIStroke" {
						Color = Color3.new(0, 0, 0),
						Thickness = Theme.StrokeThickness.Base,
					},
				},
			}
		end

		return Scope:New "Frame" (CombineProps(Props, {
			Name = "XPBar",
			Size = Props.Size or UDim2.fromOffset(280, 56),
			BackgroundTransparency = 1,
			ClipsDescendants = false,
			[Children] = {
				pillBody,
				-- Vertical stack inside the pill: label fills remaining height
				-- via UIFlexItem, the bar holds its fixed height.
				Scope:New "Frame" {
					Name = "Stack",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					[Children] = {
						Scope:New "UIPadding" {
							PaddingLeft = UDim.new(0, 16),
							PaddingRight = UDim.new(0, 16),
							PaddingTop = UDim.new(0, 8),
							PaddingBottom = UDim.new(0, 8),
						},
						Scope:New "UIListLayout" {
							FillDirection = Enum.FillDirection.Vertical,
							VerticalAlignment = Enum.VerticalAlignment.Center,
							HorizontalAlignment = Enum.HorizontalAlignment.Left,
							Padding = UDim.new(0, labelGap),
							SortOrder = Enum.SortOrder.LayoutOrder,
							-- Flex mode lets the label slot absorb whatever
							-- height is left after the bar claims its 14 px.
							VerticalFlex = Enum.UIFlexAlignment.Fill,
						},
						-- Label row: flex-fills the remaining vertical space.
						Scope:New "Frame" {
							Name = "LabelSlot",
							Size = UDim2.new(1, 0, 1, 0),
							BackgroundTransparency = 1,
							LayoutOrder = 1,
							[Children] = {
								Scope:New "UIFlexItem" {
									FlexMode = Enum.UIFlexMode.Fill,
								},
								Scope:Text {
									Name = "Label",
									Text = labelText,
									Size = UDim2.fromScale(1, 1),
									BackgroundTransparency = 1,
									TextColor3 = labelColor,
									TextXAlignment = Enum.TextXAlignment.Left,
									TextYAlignment = Enum.TextYAlignment.Center,
									TextScaled = true,
									FontFace = Font.new(
										"rbxasset://fonts/families/Montserrat.json",
										Enum.FontWeight.ExtraBold
									),
								},
							},
						},
						-- Themed progress bar at fixed pixel height.
						lib.ProgressBar(Scope, {
							Name = "Bar",
							Progress = progress,
							ColorRole = progressColorRole,
							Size = UDim2.new(1, 0, 0, barHeight),
							LayoutOrder = 2,
						}),
					},
				},
			},
		}))
	end
end
