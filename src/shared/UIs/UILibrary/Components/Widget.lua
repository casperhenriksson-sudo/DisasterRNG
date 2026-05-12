--[=[
	@class Widget

	Full template shell — Pane + HeadingBanner (absolutely positioned at top)
	+ Body content frame. BannerHeight (default 104, matching HeadingBanner) reserves vertical space.
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

	return function(Scope, Props)
		Props = Props or {}
		Scope = Fusion.innerScope(Scope, Fusion, Util, Components)
		local Theme = Themer.Theme:now()
		local paneConfig = configSlot(Theme, "Pane")
		local widgetConfig = configSlot(Theme, "Widget")

		local children = Props[Children] or {}
		Props[Children] = nil

		local bgRaw = Props.BackgroundImage
		Props.BackgroundImage = nil
		local propImage, propTransparency, propScaleType
		if type(bgRaw) == "string" then
			propImage = bgRaw
		elseif type(bgRaw) == "table" then
			propImage = bgRaw.Image
			propTransparency = bgRaw.Transparency
			propScaleType = bgRaw.ScaleType
		end

		local usePaneThemeBackground = configValue(paneConfig.UseThemeBackground, false)
		local cfg = configSlot(Theme, "Background")
		local imageId, imageTransparency, scaleType
		local backgroundColor, backgroundTransparency
		if propImage then
			imageId = propImage
			imageTransparency = propTransparency or 0
			scaleType = propScaleType or Enum.ScaleType.Crop
		elseif not usePaneThemeBackground then
			if configValue(cfg.ImageId, nil) then
				imageId = configValue(cfg.ImageId, nil)
				imageTransparency = configValue(cfg.ImageTransparency, 0)
				scaleType = configValue(cfg.ScaleType, Enum.ScaleType.Crop)
			end
			if configValue(cfg.Color, nil) then
				backgroundColor = configValue(cfg.Color, nil)
				backgroundTransparency = configValue(cfg.Transparency, 0)
			end
		end

		local backgroundChildren = nil
		if imageId or backgroundColor then
			backgroundChildren = {}
			if backgroundColor then
				table.insert(backgroundChildren, Scope:Frame {
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = backgroundColor,
					BackgroundTransparency = backgroundTransparency or 0,
					BorderSizePixel = 0,
				})
			end
			if imageId then
				table.insert(backgroundChildren, Scope:Image {
					Image = imageId,
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					ImageTransparency = imageTransparency,
					ScaleType = scaleType,
				})
			end
		end

		-- Normalize a value into a plain UDim. Accepts:
		--   * number       — treated as offset only ({0, n})
		--   * UDim         — passed through
		--   * {Scale = s, Offset = o} or {[1] = s, [2] = o}
		-- Returns a raw UDim (not Scope:UDim, which wraps in Fusion.Computed
		-- and hides .Scale/.Offset) so we can read the components when
		-- composing the body frame's Size and Position.
		local function toUDim(value, defaultOffset)
			if value == nil then
				return UDim.new(0, defaultOffset or 0)
			elseif typeof(value) == "UDim" then
				return value
			elseif type(value) == "number" then
				return UDim.new(0, value)
			elseif type(value) == "table" then
				local s = value.Scale or value[1] or 0
				local o = value.Offset or value[2] or 0
				return UDim.new(s, o)
			end
			return UDim.new(0, 0)
		end

		local PER_EDGE_KEYS = { Top = true, Bottom = true, Left = true, Right = true, All = true }
		local function isPerEdgeTable(t)
			if type(t) ~= "table" then return false end
			for k in pairs(t) do
				if PER_EDGE_KEYS[k] then return true end
			end
			return false
		end

		-- Per-theme override: Theme.Widget.BannerHeight reserves vertical
		-- space for the heading banner. Accepts a number (pixels), a UDim,
		-- or a {Scale, Offset} table so themes can size the banner relative
		-- to the pane height in addition to the absolute offset.
		local rawBanner = Props.BannerHeight or configValue(widgetConfig.BannerHeight, 104)
		Props.BannerHeight = nil
		local bannerHeight = toUDim(rawBanner, 104)

		-- Per-theme override: Theme.Widget.Padding accepts a single value
		-- (number / UDim / {Scale, Offset}) applied to all four sides, OR a
		-- table with any of { Top, Bottom, Left, Right, All } where each edge
		-- is itself a number / UDim / {Scale, Offset}. Per-edge values win
		-- over All. Falls back to the theme's base padding when nothing is
		-- configured. OnyxUI's Frame Padding shorthand reads only
		-- Top/Bottom/Left/Right — a bare { All = X } produces zeros — so we
		-- always emit per-edge values, expanding `All` ourselves.
		local rawPadding = configValue(widgetConfig.Padding, Theme.Padding.Base)
		local bodyPadding
		if isPerEdgeTable(rawPadding) then
			local fallback = rawPadding.All or Theme.Padding.Base
			bodyPadding = {
				Top    = toUDim(rawPadding.Top    or fallback),
				Bottom = toUDim(rawPadding.Bottom or fallback),
				Left   = toUDim(rawPadding.Left   or fallback),
				Right  = toUDim(rawPadding.Right  or fallback),
			}
		else
			local u = toUDim(rawPadding, Theme.Padding.Base)
			bodyPadding = { Top = u, Bottom = u, Left = u, Right = u }
		end

		-- Inset the Pane's children by the stroke thickness so the heading
		-- banner (which sets its own Size at y=0) doesn't render on top of
		-- the Pane's top UIStroke. Without this, the top border of the
		-- widget is hidden behind the banner image while the left/right/
		-- bottom strokes remain visible.
		local strokePad = Theme.StrokeThickness.Base or 2

		return lib.Pane(Scope, CombineProps(Props, {
			Name = "Widget",
			AutomaticSize = Enum.AutomaticSize.None,
			Size = Scope:UDim2Offset(500, 500),
			BackgroundTransparency = if (imageId or backgroundColor) then 1 else nil,
			Background = backgroundChildren,
			SuppressThemeBackground = propImage ~= nil,
			Scale = {
				Scale = Props.DynamicScale or 1,
			},
			[Children] = {
				Scope:New "UIPadding" {
					PaddingTop    = UDim.new(0, strokePad),
					PaddingBottom = UDim.new(0, strokePad),
					PaddingLeft   = UDim.new(0, strokePad),
					PaddingRight  = UDim.new(0, strokePad),
				},
				lib.HeadingBanner(Scope, CombineProps(Props.HeadingBanner or {}, {
					Text = "Widget",
					CloseButton = {
						OnActivate = Props.OnClose,
					},
				})),
				Scope:Frame {
					Name = "Body",
					Size = UDim2.new(1, 0, 1 - bannerHeight.Scale, -bannerHeight.Offset),
					Position = UDim2.new(0, 0, bannerHeight.Scale, bannerHeight.Offset),
					AutomaticSize = Enum.AutomaticSize.None,
					BackgroundTransparency = 1,


					List = {
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Top,
					},

					Padding = bodyPadding,
					[Children] = {
						Scope:Frame {
							Size = UDim2.fromScale(1, 1),
							AutomaticSize = Enum.AutomaticSize.None,
							Flex = { Mode = Enum.UIFlexMode.Fill },
							[Children] = { children },
						},
					},
				},
			},
		}))
	end
end
