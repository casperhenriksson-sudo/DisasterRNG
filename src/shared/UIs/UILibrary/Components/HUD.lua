--[=[
	@class HUD

	HUD-style currency / stat display. A themed pill with an amount on the left
	and an icon on the right, laid out via a horizontal UIListLayout so the
	text region and icon region don't fight each other.

	Layout:
	  ┌───────────────────────────────────┐
	  │  $12,365              [B coin]    │
	  └───────────────────────────────────┘
	  └───── flex (text) ─────┘└─icon─┘

	Props:
	  Amount        number | string                — value to display
	  Format        ((value) -> string)?           — formatter; default "$" + thousands-separated
	  IconImage     string?                        — asset id (falls back to theme slot)
	  ColorRole     string?                        — palette role for the icon tint
	  IconColor     Color3?                        — raw override (wins over ColorRole)

	Theme slot `Theme.HUD`:
	  IconColorRole       "Secondary"
	  IconImage           rbxassetid (default coin)
	  BackgroundColorRole "Base" / "Neutral"
	  BackgroundImage     optional 9-slice asset — replaces the rectangle
	  CornerRadius        UDim
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

	local function defaultFormat(amount)
		if type(amount) == "number" then
			local s = tostring(math.floor(amount))
			local sign = ""
			if s:sub(1, 1) == "-" then
				sign = "-"; s = s:sub(2)
			end
			while true do
				local replaced
				s, replaced = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
				if replaced == 0 then break end
			end
			return "$" .. sign .. s
		end
		return tostring(amount)
	end

	return function(Scope, Props)
		Props = Props or {}
		Scope = Fusion.innerScope(Scope, Fusion, Util, Components)
		local Theme = Themer.Theme:now()
		local config = configSlot(Theme, "HUD")

		local amount = Props.Amount
		Props.Amount = nil

		local format = Props.Format or defaultFormat
		Props.Format = nil

		local iconImage = Props.IconImage or configValue(config.IconImage, nil)
		Props.IconImage = nil

		local iconColorRole = Props.ColorRole or configValue(config.IconColorRole, "Secondary")
		Props.ColorRole = nil

		local iconColor = Props.IconColor
		Props.IconColor = nil
		if iconColor == nil then
			iconColor = themeColor(Theme, iconColorRole, "Main")
		end

		local backgroundImage = Props.BackgroundImage or configValue(config.BackgroundImage, nil)
		Props.BackgroundImage = nil

		local bgColorRole = configValue(config.BackgroundColorRole, "Base")
		local bgColor = themeColor(Theme, bgColorRole, "Main")

		local displayText = Scope:Computed(function(use)
			return format(use(amount))
		end)

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

		local coinImage = Scope:New "ImageLabel" {
			Name = "Coin",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = iconImage or "",
			ImageColor3 = iconColor,
			ScaleType = Enum.ScaleType.Fit,
		}

		local iconInset = configValue(config.IconInset, 6)

		return Scope:New "Frame" (CombineProps(Props, {
			Name = "HUD",
			Size = Props.Size or UDim2.fromOffset(220, 56),
			BackgroundTransparency = 1,
			ClipsDescendants = false,
			[Children] = {
				pillBody,
				Scope:New "Frame" {
					Name = "Row",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					[Children] = {
						Scope:New "UIPadding" {
							PaddingLeft = UDim.new(0, 16),
							PaddingRight = UDim.new(0, 8),
							PaddingTop = UDim.new(0, iconInset),
							PaddingBottom = UDim.new(0, iconInset),
						},
						Scope:New "UIListLayout" {
							FillDirection = Enum.FillDirection.Horizontal,
							VerticalAlignment = Enum.VerticalAlignment.Center,
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							Padding = UDim.new(0, configValue(config.IconGap, 8)),
							SortOrder = Enum.SortOrder.LayoutOrder,
							HorizontalFlex = Enum.UIFlexAlignment.Fill,
						},
						Scope:New "Frame" {
							Name = "AmountSlot",
							Size = UDim2.fromScale(1, 1),
							BackgroundTransparency = 1,
							LayoutOrder = 1,
							[Children] = {
								Scope:New "UIFlexItem" {
									FlexMode = Enum.UIFlexMode.Fill,
								},
								Scope:Text {
									Name = "Amount",
									Text = displayText,
									Size = UDim2.fromScale(1, 1),
									BackgroundTransparency = 1,
									TextColor3 = Color3.new(1, 1, 1),
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
						Scope:New "Frame" {
							Name = "IconSlot",
							Size = UDim2.fromScale(1, 1),
							BackgroundTransparency = 1,
							LayoutOrder = 2,
							[Children] = {
								Scope:New "UIAspectRatioConstraint" {
									AspectRatio = 1,
									DominantAxis = Enum.DominantAxis.Height,
								},
								coinImage,
							},
						},
					},
				},
			},
		}))
	end
end
