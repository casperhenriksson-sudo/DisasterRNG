--[=[
	@class ElevatedPane

	Pane with vertical elevation offset and gradient color sequence. Suppresses
	theme background/watermark on the inner pane to avoid double imagery.
]=]

return function(deps, lib)
	local Fusion = deps.Fusion
	local Themer = deps.Themer
	local Util = deps.Util
	local ColorUtils = deps.ColorUtils
	local CombineProps = deps.CombineProps
	local Children = deps.Children
	local Components = deps.Components

	return function(Scope, Props)
		Props = Props or {}
		Scope = Fusion.innerScope(Scope, Fusion, Util, Components)
		local Theme = Themer.Theme:now()

		local children = Props[Children] or {}
		Props[Children] = nil
		local padding = Props.Padding or nil
		Props.Padding = nil

		local size = Props.Size or Scope:UDim2(1, 0, 0, 104)
		local colorSequence = Props.ColorSequence
			or Scope:Computed(function(use)
				return ColorSequence.new(use(Theme.Colors.Primary.Main), use(Theme.Colors.Primary.Dark))
			end)
		local dark = Scope:Computed(function(use)
			local keypoints = use(colorSequence).Keypoints
			return ColorUtils.Darken(keypoints[#keypoints].Value, 0.5)
		end)

		local corner = Props.Corner or { Enabled = false }
		Props.Corner = nil

		return Scope:Frame(CombineProps(Props, {
			Size = size,
			AutomaticSize = Enum.AutomaticSize.None,
			BackgroundTransparency = 0,
			BackgroundColor3 = dark,
			Stroke = { Color = Color3.new(0, 0, 0) },
			Corner = corner,
			[Children] = {
				Scope:Frame {
					Size = Scope:Computed(function(use)
						return UDim2.fromScale(1, 1) - UDim2.fromOffset(0, use(Props.Elevation) or 8)
					end),
					AutomaticSize = Enum.AutomaticSize.None,
					[Children] = {
						lib.Pane(Scope, {
							Corner = corner,
							Stroke = { Enabled = false },
							Size = UDim2.fromScale(1, 1),
							BackgroundTransparency = 1,
							SuppressThemeBackground = true,
							Background = {
								Scope:Frame {
									Size = UDim2.fromScale(1, 1),
									AutomaticSize = Enum.AutomaticSize.None,
									BackgroundTransparency = 0,
									Gradient = { Color = colorSequence, Rotation = 90 },
									Corner = corner,
									[Children] = {
										Scope:New "UIStroke" {
											Thickness = Theme.StrokeThickness.Base,
											Color = Color3.new(1, 1, 1),
											Transparency = 0.4,
											BorderStrokePosition = Enum.BorderStrokePosition.Inner,
											[Children] = {
												Scope:New "UIGradient" {
													Transparency = NumberSequence.new(1, 0),
													Rotation = 90,
												},
											},
										},
									},
								},
							},
							[Children] = {
								Scope:Frame {
									Size = UDim2.fromScale(1, 1),
									AutomaticSize = Enum.AutomaticSize.None,
									BackgroundTransparency = 1,
									Padding = padding,
									[Children] = { children },
								},
							},
						}),
					},
				},
			},
		}))
	end
end
