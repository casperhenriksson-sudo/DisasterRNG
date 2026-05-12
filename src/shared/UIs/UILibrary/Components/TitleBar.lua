--[=[
	@class TitleBar

	Themed title bar with built-in close button. Wraps OnyxUI's TitleBar.
	Reads `Theme.TitleBar.ColorRole` (default "BaseContent") for the title text color.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local OnyxUI = ReplicatedStorage.Packages.OnyxUI.Packages.OnyxUI
local OnyxTitleBar = require(OnyxUI.Components.TitleBar)

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
	mergedComponents.TitleBar = OnyxTitleBar

	return function(Scope, Props)
		Props = Props or {}
		Scope = Fusion.innerScope(Scope, Fusion, Util, mergedComponents)
		local Theme = Themer.Theme:now()
		local config = configSlot(Theme, "TitleBar")

		local colorRole = Props.ColorRole or configValue(config.ColorRole, "BaseContent")
		Props.ColorRole = nil

		local contentColor = Props.ContentColor
		Props.ContentColor = nil
		if contentColor == nil then
			contentColor = themeColor(Theme, colorRole, "Main")
		end

		return Scope:TitleBar(CombineProps(Props, { ContentColor = contentColor }))
	end
end
