--[=[
	@class TextSwap

	Animated text swapper. Wraps OnyxUI's TextSwap.
	Reads `Theme.TextSwap.ColorRole` (default "Primary") for the content color.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local OnyxUI = ReplicatedStorage.Packages.OnyxUI.Packages.OnyxUI
local OnyxTextSwap = require(OnyxUI.Components.TextSwap)

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
	mergedComponents.TextSwap = OnyxTextSwap

	return function(Scope, Props)
		Props = Props or {}
		Scope = Fusion.innerScope(Scope, Fusion, Util, mergedComponents)
		local Theme = Themer.Theme:now()
		local config = configSlot(Theme, "TextSwap")

		local colorRole = Props.ColorRole or configValue(config.ColorRole, "Primary")
		Props.ColorRole = nil

		local color = Props.Color
		Props.Color = nil
		if color == nil then
			color = themeColor(Theme, colorRole, "Main")
		end

		return Scope:TextSwap(CombineProps(Props, { Color = color }))
	end
end
