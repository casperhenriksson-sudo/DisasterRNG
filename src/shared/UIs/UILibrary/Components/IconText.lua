--[=[
	@class IconText

	Inline icon + text row. Wraps OnyxUI's IconText primitive.
	`Content` accepts an array of strings (rbxassetid icons and/or plain text).

	Reads `Theme.IconText.ColorRole` (default "BaseContent") for the text /
	icon tint. Per-instance `ContentColor` or `ColorRole` overrides.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local OnyxUI = ReplicatedStorage.Packages.OnyxUI.Packages.OnyxUI
local OnyxIconText = require(OnyxUI.Components.IconText)

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
	mergedComponents.IconText = OnyxIconText

	return function(Scope, Props)
		Props = Props or {}
		Scope = Fusion.innerScope(Scope, Fusion, Util, mergedComponents)
		local Theme = Themer.Theme:now()
		local config = configSlot(Theme, "IconText")

		local colorRole = Props.ColorRole or configValue(config.ColorRole, "BaseContent")
		Props.ColorRole = nil

		local contentColor = Props.ContentColor
		Props.ContentColor = nil
		if contentColor == nil then
			contentColor = themeColor(Theme, colorRole, "Main")
		end

		return Scope:IconText(CombineProps(Props, { ContentColor = contentColor }))
	end
end
