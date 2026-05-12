--[=[
	@class Avatar

	Themed avatar (round headshot/portrait with optional ring + indicator dot).
	Wraps OnyxUI's Avatar primitive.

	Reads `Theme.Avatar.RingColorRole` (default "Primary") and
	`Theme.Avatar.IndicatorColorRole` (default "Success") for the ring and
	indicator colors. Per-instance `RingColor` / `IndicatorColor` always wins.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local OnyxUI = ReplicatedStorage.Packages.OnyxUI.Packages.OnyxUI
local OnyxAvatar = require(OnyxUI.Components.Avatar)

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
	mergedComponents.Avatar = OnyxAvatar

	return function(Scope, Props)
		Props = Props or {}
		Scope = Fusion.innerScope(Scope, Fusion, Util, mergedComponents)
		local Theme = Themer.Theme:now()
		local config = configSlot(Theme, "Avatar")

		local extras = {}

		local ringColor = Props.RingColor
		Props.RingColor = nil
		if ringColor == nil then
			local role = Props.RingColorRole or configValue(config.RingColorRole, "Primary")
			Props.RingColorRole = nil
			ringColor = themeColor(Theme, role, "Main")
		end
		extras.RingColor = ringColor

		local indicatorColor = Props.IndicatorColor
		Props.IndicatorColor = nil
		if indicatorColor == nil then
			local role = Props.IndicatorColorRole or configValue(config.IndicatorColorRole, "Success")
			Props.IndicatorColorRole = nil
			indicatorColor = themeColor(Theme, role, "Main")
		end
		extras.IndicatorColor = indicatorColor

		return Scope:Avatar(CombineProps(Props, extras))
	end
end
