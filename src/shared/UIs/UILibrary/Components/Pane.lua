--[=[
	@class Pane

	Themed base panel. Reads `Theme.Pane` and `Theme.Background` slots.
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

	local function themeBackgroundImage(Scope, Theme)
		local cfg = configSlot(Theme, "Background")
		local imageId = configValue(cfg.ImageId, nil)
		if not imageId then
			return nil
		end

		return Scope:Image {
			Image = imageId,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ImageTransparency = configValue(cfg.ImageTransparency, 0),
			ScaleType = configValue(cfg.ScaleType, Enum.ScaleType.Crop),
		}
	end

	return function(Scope, Props)
		Props = Props or {}
		Scope = Fusion.innerScope(Scope, Fusion, Util, Components)
		local Theme = Themer.Theme:now()
		local paneConfig = configSlot(Theme, "Pane")

		local children = Props[Children] or {}
		Props[Children] = nil

		local background = Props.Background or {}
		Props.Background = nil

		local suppressThemeBackground = Props.SuppressThemeBackground or false
		Props.SuppressThemeBackground = nil

		local paneChildren = {
			Scope:Frame {
				Size = UDim2.fromScale(1, 1),
				AutomaticSize = Enum.AutomaticSize.None,
				[Children] = background,
			},
		}

		if configValue(paneConfig.UseThemeBackground, false) and not configValue(suppressThemeBackground, false) then
			local image = themeBackgroundImage(Scope, Theme)
			if image then
				table.insert(paneChildren, image)
			end
		end

		table.insert(paneChildren, Scope:Frame {
			Size = UDim2.fromScale(1, 1),
			AutomaticSize = Enum.AutomaticSize.None,
			[Children] = children,
		})

		local hideStroke = Props.HideStroke
		Props.HideStroke = nil

		local strokeProps
		if hideStroke then
			strokeProps = { Enabled = false, Thickness = 0 }
		else
			strokeProps = {
				Thickness = Theme.StrokeThickness.Base,
				Color = Color3.new(0, 0, 0),
			}
			if type(paneConfig.Stroke) == "table" then
				for k, v in pairs(paneConfig.Stroke) do
					strokeProps[k] = v
				end
			end
		end

		local cornerProps = {
			Radius = Scope:UDim(0, Theme.CornerRadius.Base),
		}
		if type(paneConfig.Corner) == "table" then
			for k, v in pairs(paneConfig.Corner) do
				cornerProps[k] = v
			end
		end

		return Scope:Frame(CombineProps(Props, {
			ClipsDescendants = configValue(paneConfig.ClipsDescendants, true),
			AutomaticSize = Enum.AutomaticSize.None,
			Name = "Pane",
			Size = Scope:UDim2Offset(100, 100),
			BackgroundTransparency = configValue(paneConfig.BackgroundTransparency, 0.35),
			BackgroundColor3 = Theme.Colors.Base.Main,
			Corner = cornerProps,
			Stroke = strokeProps,
			[Children] = paneChildren,
		}))
	end
end
