--[=[
	@class LoadingScreen

	Full-screen loading template. Renders a background image (theme- or
	caller-provided) with a centered stack: icon, title, asset-count label,
	progress bar, and percentage readout.

	Props:
	  Progress         UsedAs<number 0..1>?
	  LoadedCount      UsedAs<number>?
	  TotalCount       UsedAs<number>?
	  Format           ((loaded, total) -> string)?
	  Title            string?                  — default "LOADING SCREEN"
	  Icon             string?                  — small icon above title
	  BackgroundImage  string?                  — full-screen background asset
	  ProgressColorRole string?                 — palette role for the bar fill
	  OnComplete       (() -> ())?              — fires once when Progress hits 1

	Theme slot `Theme.LoadingScreen`:
	  BackgroundImage, BackgroundColorRole, BackgroundTransparency,
	  Icon, ProgressColorRole, TitleColorRole, SubtextColorRole.
]=]

return function(deps, lib)
	local Fusion = deps.Fusion
	local Themer = deps.Themer
	local Util = deps.Util
	local CombineProps = deps.CombineProps
	local Children = deps.Children
	local peek = deps.peek
	local Components = deps.Components
	local configValue = deps.configValue
	local configSlot = deps.configSlot
	local themeColor = deps.themeColor

	return function(Scope, Props)
		Props = Props or {}
		Scope = Fusion.innerScope(Scope, Fusion, Util, Components)
		local Theme = Themer.Theme:now()
		local config = configSlot(Theme, "LoadingScreen")

		local progress = Props.Progress
		Props.Progress = nil

		local loadedCount = Props.LoadedCount
		Props.LoadedCount = nil
		local totalCount = Props.TotalCount
		Props.TotalCount = nil

		local format = Props.Format
		Props.Format = nil

		local title = Props.Title or "LOADING SCREEN"
		Props.Title = nil
		local icon = Props.Icon or configValue(config.Icon, nil)
		Props.Icon = nil
		local backgroundImage = Props.BackgroundImage or configValue(config.BackgroundImage, nil)
		Props.BackgroundImage = nil

		local progressColorRole = Props.ProgressColorRole or configValue(config.ProgressColorRole, "Success")
		Props.ProgressColorRole = nil

		local onComplete = Props.OnComplete
		Props.OnComplete = nil

		local titleColor = themeColor(Theme, configValue(config.TitleColorRole, "BaseContent"), "Main")
		local subtextColor = themeColor(Theme, configValue(config.SubtextColorRole, "BaseContent"), "Main")
		local bgColor = themeColor(Theme, configValue(config.BackgroundColorRole, "Base"), "Main")

		local loadedText = Scope:Computed(function(use)
			if format then
				return format(use(loadedCount), use(totalCount))
			end
			local loaded = use(loadedCount)
			local total = use(totalCount)
			if loaded and total then
				return string.format("Assets Loaded: %d/%d", loaded, total)
			elseif loaded then
				return tostring(loaded)
			end
			return ""
		end)

		local percentText = Scope:Computed(function(use)
			local p = use(progress) or 0
			return string.format("%d%%", math.floor(p * 100))
		end)

		if onComplete then
			local triggered = false
			Scope:Observer(progress):onChange(function()
				if not triggered and (peek(progress) or 0) >= 1 then
					triggered = true
					onComplete()
				end
			end)
		end

		local backgroundLayer
		if backgroundImage then
			backgroundLayer = Scope:New "ImageLabel" {
				Name = "Background",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Image = backgroundImage,
				ScaleType = Enum.ScaleType.Crop,
				ImageTransparency = configValue(config.BackgroundTransparency, 0),
			}
		end

		return Scope:New "Frame" (CombineProps(Props, {
			Name = "LoadingScreen",
			Size = Props.Size or UDim2.fromScale(1, 1),
			BackgroundColor3 = bgColor,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			[Children] = {
				backgroundLayer,
				Scope:New "Frame" {
					Name = "Content",
					Size = UDim2.new(0.6, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					[Children] = {
						Scope:New "UIListLayout" {
							FillDirection = Enum.FillDirection.Vertical,
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							VerticalAlignment = Enum.VerticalAlignment.Top,
							Padding = UDim.new(0, 16),
							SortOrder = Enum.SortOrder.LayoutOrder,
						},
						if icon then
							Scope:New "ImageLabel" {
								Name = "Icon",
								Size = UDim2.fromOffset(72, 72),
								BackgroundTransparency = 1,
								Image = icon,
								ScaleType = Enum.ScaleType.Fit,
								LayoutOrder = 1,
							}
						else nil,
						Scope:New "TextLabel" {
							Name = "Title",
							Size = UDim2.new(1, 0, 0, 96),
							BackgroundTransparency = 1,
							Text = title,
							TextColor3 = titleColor,
							TextScaled = true,
							TextXAlignment = Enum.TextXAlignment.Center,
							TextYAlignment = Enum.TextYAlignment.Center,
							FontFace = Font.new(peek(Theme.Font.Heading), peek(Theme.FontWeight.Heading)),
							LayoutOrder = 2,
							[Children] = {
							},
						},
						Scope:New "TextLabel" {
							Name = "LoadedLabel",
							Size = UDim2.new(1, 0, 0, 32),
							BackgroundTransparency = 1,
							Text = loadedText,
							TextColor3 = subtextColor,
							TextScaled = true,
							TextXAlignment = Enum.TextXAlignment.Center,
							TextYAlignment = Enum.TextYAlignment.Center,
							FontFace = Font.new(peek(Theme.Font.Body), peek(Theme.FontWeight.Bold)),
							LayoutOrder = 3,
							[Children] = {
							},
						},
						lib.ProgressBar(Scope, {
							Name = "Progress",
							Progress = progress,
							ColorRole = progressColorRole,
							Size = UDim2.new(1, 0, 0, 36),
							LayoutOrder = 4,
						}),
						Scope:New "TextLabel" {
							Name = "PercentLabel",
							Size = UDim2.new(1, 0, 0, 40),
							BackgroundTransparency = 1,
							Text = percentText,
							TextColor3 = subtextColor,
							TextScaled = true,
							TextXAlignment = Enum.TextXAlignment.Center,
							TextYAlignment = Enum.TextYAlignment.Center,
							FontFace = Font.new(peek(Theme.Font.Body), peek(Theme.FontWeight.Bold)),
							LayoutOrder = 5,
							[Children] = {
							},
						},
					},
				},
			},
		}))
	end
end
