--[=[
	@class Toast

	Auto-dismissing centered notification pill. Fades up and out after a
	short delay, then fires `OnDismissed` so the caller can remove it
	from the tree. Mirrors the HUD/XPBar custom-build pattern; no exit
	button -- visibility is purely time-driven.

	Props:
	  Severity             "Info"|"Success"|"Warning"|"Error"|"Announcement"
	  Message              string | State<string>
	  Duration             seconds visible before dismiss kicks off (default 3)
	  FadeDuration         seconds for the fade-up animation (default 0.45)
	  RiseOffset           pixels the pill rises while fading (default 40)
	  ColorRole            icon tint role override
	  BackgroundColorRole  pill tint role override
	  Icon                 asset id override
	  OnDismissed          () -> () called after the fade-out finishes

	Theme slot `Theme.Toast`:
	  BackgroundTransparency  pill body transparency at full opacity
	  CornerRadius            UDim -- defaults to fully-rounded pill
	  Padding                 { Vertical, Horizontal }
	  IconSize                square icon glyph size in px
	  DividerWidth            vertical separator width in px
	  DividerColor            Color3
	  DividerTransparency     base transparency
	  TextColorRole           palette role for the message text
	  TextSize                font size override (defaults to Theme.TextSize.Base)
	  Severities              { [name] = { Icon, ColorRole, BackgroundColorRole } }
]=]

return function(deps, lib)
	local Fusion = deps.Fusion
	local Themer = deps.Themer
	local Util = deps.Util
	local CombineProps = deps.CombineProps
	local Children = deps.Children
	local Components = deps.Components
	local peek = deps.peek
	local configValue = deps.configValue
	local configSlot = deps.configSlot
	local themeColor = deps.themeColor

	return function(Scope, Props)
		Props = Props or {}
		Scope = Fusion.innerScope(Scope, Fusion, Util, Components)
		local Theme = Themer.Theme:now()
		local config = configSlot(Theme, "Toast")
		local severityMap = configValue(config.Severities, {}) or {}

		local severity = Props.Severity or "Info"
		Props.Severity = nil

		local message = Props.Message or ""
		Props.Message = nil

		local duration = Props.Duration or 3
		Props.Duration = nil

		local fadeDuration = Props.FadeDuration or 0.45
		Props.FadeDuration = nil

		local riseOffset = Props.RiseOffset or 40
		Props.RiseOffset = nil

		local onDismissed = Props.OnDismissed
		Props.OnDismissed = nil

		local severityCfg = severityMap[severity] or {}

		local iconAsset = Props.Icon or severityCfg.Icon
		Props.Icon = nil

		local colorRole = Props.ColorRole or severityCfg.ColorRole or "Info"
		Props.ColorRole = nil

		local backgroundColorRole = Props.BackgroundColorRole
			or severityCfg.BackgroundColorRole
			or "Neutral"
		Props.BackgroundColorRole = nil

		local userPosition = Props.Position or UDim2.fromScale(0.5, 0.5)
		Props.Position = nil

		local userAnchor = Props.AnchorPoint or Vector2.new(0.5, 0.5)
		Props.AnchorPoint = nil

		local iconColor = themeColor(Theme, colorRole, "Main")
		local backgroundColor = themeColor(Theme, backgroundColorRole, "Main")
		local textColor = themeColor(
			Theme,
			configValue(config.TextColorRole, "BaseContent"),
			"Main"
		)

		local progress = Scope:Value(0)
		local tweened = Scope:Tween(
			progress,
			TweenInfo.new(
				fadeDuration,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out
			)
		)

		local function fadeT(base)
			return Scope:Computed(function(use)
				return base + (1 - base) * use(tweened)
			end)
		end

		local positionState = Scope:Computed(function(use)
			local p = if typeof(userPosition) == "UDim2"
				then userPosition
				else use(userPosition)
			local rise = use(tweened) * riseOffset
			return UDim2.new(
				p.X.Scale, p.X.Offset,
				p.Y.Scale, p.Y.Offset - rise
			)
		end)

		task.delay(duration, function()
			local ok = pcall(function() progress:set(1) end)
			if not ok then return end
			task.delay(fadeDuration + 0.05, function()
				if onDismissed then
					pcall(onDismissed)
				end
			end)
		end)

		local baseBgTransparency = configValue(config.BackgroundTransparency, 0.25)
		local cornerRadius = configValue(config.CornerRadius, UDim.new(1, 0))
		local padding = configValue(config.Padding, {}) or {}
		local padV = configValue(padding.Vertical, 12)
		local padH = configValue(padding.Horizontal, 18)
		local iconSize = configValue(config.IconSize, 36)
		local dividerWidth = configValue(config.DividerWidth, 2)
		local dividerColor = configValue(config.DividerColor, Color3.new(1, 1, 1))
		local dividerBaseTransparency = configValue(config.DividerTransparency, 0.5)
		local textSize = configValue(config.TextSize, peek(Theme.TextSize.Base) or 20)
		local fontFamily = peek(Theme.Font.Body) or "rbxasset://fonts/families/Montserrat.json"
		local fontWeight = peek(Theme.FontWeight.Bold) or Enum.FontWeight.Bold
		local fontFace = Font.new(fontFamily, fontWeight)

		return Scope:New "Frame" (CombineProps(Props, {
			Name = "Toast",
			Position = positionState,
			AnchorPoint = userAnchor,
			Size = Props.Size or UDim2.fromOffset(480, 60),
			BackgroundColor3 = backgroundColor,
			BackgroundTransparency = fadeT(baseBgTransparency),
			BorderSizePixel = 0,
			ClipsDescendants = false,
			[Children] = {
				Scope:New "UICorner" {
					CornerRadius = cornerRadius,
				},
				Scope:New "UIPadding" {
					PaddingTop = UDim.new(0, padV),
					PaddingBottom = UDim.new(0, padV),
					PaddingLeft = UDim.new(0, padH),
					PaddingRight = UDim.new(0, padH),
				},
				Scope:New "UIListLayout" {
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					Padding = UDim.new(0, 12),
					SortOrder = Enum.SortOrder.LayoutOrder,
					HorizontalFlex = Enum.UIFlexAlignment.Fill,
				},
				Scope:New "Frame" {
					Name = "IconSlot",
					Size = UDim2.fromOffset(iconSize, iconSize),
					BackgroundTransparency = 1,
					LayoutOrder = 1,
					Visible = iconAsset ~= nil,
					[Children] = {
						Scope:New "ImageLabel" {
							Size = UDim2.fromScale(1, 1),
							BackgroundTransparency = 1,
							Image = iconAsset or "",
							ImageColor3 = iconColor,
							ImageTransparency = fadeT(0),
							ScaleType = Enum.ScaleType.Fit,
						},
					},
				},
				Scope:New "Frame" {
					Name = "Divider",
					Size = UDim2.new(0, dividerWidth, 1, -16),
					BackgroundColor3 = dividerColor,
					BackgroundTransparency = fadeT(dividerBaseTransparency),
					BorderSizePixel = 0,
					LayoutOrder = 2,
					Visible = iconAsset ~= nil,
				},
				Scope:New "Frame" {
					Name = "MessageSlot",
					Size = UDim2.new(1, 0, 1, 0),
					BackgroundTransparency = 1,
					LayoutOrder = 3,
					[Children] = {
						Scope:New "UIFlexItem" {
							FlexMode = Enum.UIFlexMode.Fill,
						},
						Scope:New "TextLabel" {
							Name = "Message",
							Size = UDim2.fromScale(1, 1),
							BackgroundTransparency = 1,
							Text = message,
							TextColor3 = textColor,
							TextTransparency = fadeT(0),
							TextSize = textSize,
							FontFace = fontFace,
							TextXAlignment = Enum.TextXAlignment.Center,
							TextYAlignment = Enum.TextYAlignment.Center,
							TextWrapped = true,
						},
					},
				},
			},
		}))
	end
end
