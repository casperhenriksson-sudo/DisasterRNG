--[=[
	@class ProgressBar

	Themed progress bar. Wraps OnyxUI's ProgressBar.
	Reads `Theme.ProgressBar.ColorRole` (default "Primary") for the fill color.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local OnyxUI = ReplicatedStorage.Packages.OnyxUI.Packages.OnyxUI
local OnyxProgressBar = require(OnyxUI.Components.ProgressBar)

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
	mergedComponents.ProgressBar = OnyxProgressBar

	return function(Scope, Props)
		Props = Props or {}
		Scope = Fusion.innerScope(Scope, Fusion, Util, mergedComponents)
		local Theme = Themer.Theme:now()
		local config = configSlot(Theme, "ProgressBar")

		local colorRole = Props.ColorRole or configValue(config.ColorRole, "Primary")
		Props.ColorRole = nil

		local color = Props.Color
		Props.Color = nil
		if color == nil then
			color = themeColor(Theme, colorRole, "Main")
		end

		local extras = { Color = color }
		if config.CornerRadius ~= nil then extras.Corner = { Radius = config.CornerRadius } end

		return Scope:ProgressBar(CombineProps(Props, extras))
	end
end
