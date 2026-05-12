--[=[
	@class Slider

	Themed slider. Wraps OnyxUI's Slider.
	Reads `Theme.Slider.ColorRole` (default "Primary") for the track/handle color.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local OnyxUI = ReplicatedStorage.Packages.OnyxUI.Packages.OnyxUI
local OnyxSlider = require(OnyxUI.Components.Slider)

return function(deps, lib)
	local Fusion = deps.Fusion
	local Themer = deps.Themer
	local Util = deps.Util
	local CombineProps = deps.CombineProps
	local Components = deps.Components
	local configValue = deps.configValue
	local configSlot = deps.configSlot
	local themeColor = deps.themeColor

	local mergedComponents = table.clone(Components)
	mergedComponents.Slider = OnyxSlider

	return function(Scope, Props)
		Props = Props or {}
		Scope = Fusion.innerScope(Scope, Fusion, Util, mergedComponents)
		local Theme = Themer.Theme:now()
		local config = configSlot(Theme, "Slider")

		local colorRole = Props.ColorRole or configValue(config.ColorRole, "Primary")
		Props.ColorRole = nil

		local color = Props.Color
		Props.Color = nil
		if color == nil then
			color = themeColor(Theme, colorRole, "Main")
		end

		return Scope:Slider(CombineProps(Props, { Color = color }))
	end
end
