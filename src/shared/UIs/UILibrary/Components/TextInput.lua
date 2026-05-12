--[=[
	@class TextInput

	ElevatedPane-styled TextBox with two-way `Fusion.Out` text binding.
	Elevation = 0 keeps the surface flat.
]=]

return function(deps, lib)
	local Fusion = deps.Fusion
	local Themer = deps.Themer
	local Util = deps.Util
	local Children = deps.Children
	local Components = deps.Components

	return function(Scope, Props)
		Props = Props or {}
		Scope = Fusion.innerScope(Scope, Fusion, Util, Components)
		local Theme = Themer.Theme:now()
		local TextValue = Scope:EnsureValue(Util.Fallback(Props.Text, ""))

		return lib.ElevatedPane(Scope, {
			Name = Props.Name or "TextInput",
			Size = Props.Size or UDim2.new(1, 0, 0, 50),
			LayoutOrder = Props.LayoutOrder,
			Stroke = { Enabled = false },
			Elevation = 0,
			--ColorSequence = Props.ColorSequence or Scope:Computed(function(use)
			--	return ColorSequence.new(use(Theme.Colors.Neutral.Main), use(Theme.Colors.Neutral.Dark))
			--end),
			Color3 = Theme.Colors.NeutralContent.Main,
			[Children] = {
				Scope:New "TextBox" {
					Name = "Input",
					Size = UDim2.new(1, -24, 1, 0),
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Text = TextValue,
					PlaceholderText = Props.PlaceholderText or "Enter text...",
					TextColor3 = Theme.Colors.BaseContent.Main,
					--PlaceholderColor3 = Scope:Computed(function(use)
					--	return use(Theme.Colors.BaseContent.Main):Lerp(use(Theme.Colors.Base.Main), 0.5)
					--end),
					PlaceholderColor3 = Theme.Colors.Accent.Main,
					TextSize = Props.TextSize or Theme.TextSize["1"],
					FontFace = Font.new(Fusion.peek(Theme.Font.Body), Enum.FontWeight.Medium),
					ClearTextOnFocus = false,
					TextXAlignment = Props.TextXAlignment or Enum.TextXAlignment.Left,
					[Fusion.Out "Text"] = TextValue,
				},
			},
		})
	end
end
