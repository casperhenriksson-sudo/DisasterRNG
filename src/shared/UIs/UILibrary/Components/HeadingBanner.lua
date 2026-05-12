--[=[
	@class HeadingBanner

	Top of a Widget. Three rendering modes:
	  1. Image-backed (Theme.HeadingBanner.Image, Props.Image, or Transparent=true) →
	     plain Pane background.
	  2. ColorRole / ColorSequence → gradient ElevatedPane.
	  3. Default → Primary gradient ElevatedPane.
]=]

return function(deps, lib)
	local Fusion = deps.Fusion
	local Themer = deps.Themer
	local Util = deps.Util
	local ColorUtils = deps.ColorUtils
	local CombineProps = deps.CombineProps
	local Children = deps.Children
	local Components = deps.Components
	local configValue = deps.configValue
	local configSlot = deps.configSlot
	local themeColor = deps.themeColor

	return function(Scope, Props)
		Props = Props or {}
		Scope = Fusion.innerScope(Scope, Fusion, Util, Components)
		local Theme = Themer.Theme:now()
		local headingConfig = configSlot(Theme, "HeadingBanner")

		local children = Props[Children] or {}
		Props[Children] = nil

		local textColorRole = Props.TextColorRole or headingConfig.TextColorRole
		Props.TextColorRole = nil
		local textColor = Props.TextColor3
		Props.TextColor3 = nil

		local colorRole = Props.ColorRole or headingConfig.ColorRole
		Props.ColorRole = nil
		local colorSequence = Props.ColorSequence
		if not colorSequence and colorRole then
			colorSequence = Scope:Computed(function(use)
				local main = use(themeColor(Theme, colorRole, "Main"))
				local palette = Theme.Colors[colorRole]
				local dark
				if palette and palette.Dark then
					dark = use(palette.Dark)
				else
					dark = ColorUtils.Darken(main, 0.4)
				end
				return ColorSequence.new(main, dark)
			end)
		end
		Props.ColorSequence = nil

		local bannerImage = Props.Image or headingConfig.Image
		Props.Image = nil
		local bannerImageScaleType = Props.ImageScaleType or headingConfig.ImageScaleType or Enum.ScaleType.Stretch
		Props.ImageScaleType = nil
		local bannerImageSize = Props.ImageSize or headingConfig.ImageSize or UDim2.fromScale(1, 1)
		Props.ImageSize = nil
		local bannerImagePosition = Props.ImagePosition or headingConfig.ImagePosition or UDim2.fromScale(0, 0)
		Props.ImagePosition = nil
		local bannerImageAnchorPoint = Props.ImageAnchorPoint or headingConfig.ImageAnchorPoint or Vector2.new(0, 0)
		Props.ImageAnchorPoint = nil

		local bannerImagePropsOverride = Props.ImageProps or headingConfig.ImageProps
		Props.ImageProps = nil

		local transparent = Props.Transparent
		if transparent == nil then
			transparent = configValue(headingConfig.Transparent, false)
		end
		Props.Transparent = nil

		-- No default Stroke. A black contextual stroke around already-dark
		-- text (Studs BaseContent #2D3748) combined with Bold/ExtraBold
		-- weights renders as a mushy "filled in" blob with no light interior.
		-- Themes that want an outline (Dracula's cartoon look) can opt in via
		-- Theme.HeadingBanner.TextProps or per-call Props.TextProps.
		local headingProps = {
			Position = UDim2.fromScale(0, 0.5),
			AnchorPoint = Vector2.new(0, 0.5),
			Text = Props.Text or "Heading",
			-- Single source of truth for the "big" heading size used at the
			-- top of every Widget. Templates should not set their own
			-- TextSize for headers — adjust this key (or the theme's TextSize
			-- ramp) instead.
			TextSize = Props.TextSize or Theme.TextSize["3"],
			HeadingSize = 1,
			TextWrapped = false,
		}
		if textColor then
			headingProps.TextColor3 = textColor
		elseif textColorRole then
			headingProps.TextColor3 = themeColor(Theme, textColorRole, "Main")
		end

		local headingPropsOverride = Props.TextProps or headingConfig.TextProps
		Props.TextProps = nil
		if type(headingPropsOverride) == "table" then
			for k, v in pairs(headingPropsOverride) do
				if k ~= "Text" then
					headingProps[k] = v
				end
			end
		end

		local headingContent = Scope:Frame {
			Size = Scope:UDim2Scale(1, 1),
			AutomaticSize = Enum.AutomaticSize.None,
			Padding = {},
			[Children] = {
				Scope:Heading(headingProps),
				lib.CloseButton(Scope, CombineProps(Props.CloseButton or {}, {

				})),
			},
		}

		if bannerImage or transparent then
			local background
			if bannerImage then
				local imageProps = {
					Image = bannerImage,
					Size = bannerImageSize,
					Position = bannerImagePosition,
					AnchorPoint = bannerImageAnchorPoint,
					BackgroundTransparency = 1,
					ScaleType = bannerImageScaleType,
				}
				if type(bannerImagePropsOverride) == "table" then
					for k, v in pairs(bannerImagePropsOverride) do
						imageProps[k] = v
					end
				end
				background = { Scope:Image(imageProps) }
			end
			return lib.Pane(Scope, CombineProps(Props, {
				Name = "HeadingBanner",
				Size = Scope:UDim2(1, 0, 0, 104),
				BackgroundTransparency = 1,
				HideStroke = true,
				SuppressThemeBackground = true,
				Background = background,
				[Children] = { children, headingContent },
			}))
		end

		local bannerChildren = { children }

		table.insert(bannerChildren, headingContent)

		return lib.ElevatedPane(Scope, CombineProps(Props, {
			Size = Scope:UDim2(1, 0, 0, 104),
			ColorSequence = colorSequence,
			[Children] = bannerChildren,
		}))
	end
end
