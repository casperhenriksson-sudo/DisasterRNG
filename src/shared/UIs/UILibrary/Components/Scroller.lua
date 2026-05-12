--[=[
	@class Scroller

	Themed scrolling frame. Wraps OnyxUI's Scroller and applies the current
	theme's `Theme.Scrollbar.Color` as the default `ScrollBarImageColor3`.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local OnyxUI = ReplicatedStorage.Packages.OnyxUI.Packages.OnyxUI
local OnyxScroller = require(OnyxUI.Components.Scroller)

return function(deps, lib)
	local Fusion = deps.Fusion
	local Themer = deps.Themer
	local Util = deps.Util
	local CombineProps = deps.CombineProps
	local Components = deps.Components
	local configSlot = deps.configSlot

	local mergedComponents = table.clone(Components)
	mergedComponents.Scroller = OnyxScroller

	return function(Scope, Props)
		Props = Props or {}
		Scope = Fusion.innerScope(Scope, Fusion, Util, mergedComponents)
		local Theme = Themer.Theme:now()
		local config = configSlot(Theme, "Scrollbar")

		local extras = {}
		if Props.ScrollBarImageColor3 == nil and config.Color ~= nil then
			extras.ScrollBarImageColor3 = config.Color
		end

		return Scope:Scroller(CombineProps(Props, extras))
	end
end
