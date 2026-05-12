--[=[
	@class Divider

	Horizontal gradient line with centered text. Pure layout, no theme slot.
]=]

return function(deps, lib)
	local Fusion = deps.Fusion
	local Themer = deps.Themer
	local Util = deps.Util
	local CombineProps = deps.CombineProps
	local Children = deps.Children
	local Components = deps.Components

	return function(Scope, Props)
		Props = Props or {}
		Scope = Fusion.innerScope(Scope, Fusion, Util, Components)
		local Theme = Themer.Theme:now()

		return Scope:Frame(CombineProps(Props, {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			[Children] = {
				Scope:New "Frame" {
					Size = UDim2.new(0.75, 0, 0, 4),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					BackgroundTransparency = 0.5,
					[Children] = {
						Scope:New "UIGradient" {
							Transparency = NumberSequence.new {
								NumberSequenceKeypoint.new(0, 1),
								NumberSequenceKeypoint.new(0.5, 0),
								NumberSequenceKeypoint.new(1, 1),
							},
						},
					},
				},
				Scope:Text {
					Text = Props.Text or "Title",
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					TextXAlignment = Enum.TextXAlignment.Center,
					TextSize = Theme.TextSize["3"],

				},
			},
		}))
	end
end
