--[=[
	@class Icon

	Image primitive sized to the active theme's `Theme.TextSize["1"]`.
	Pure passthrough wrap of OnyxUI's Icon.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local OnyxUI = ReplicatedStorage.Packages.OnyxUI.Packages.OnyxUI
local OnyxIcon = require(OnyxUI.Components.Icon)

return function(deps, lib)
	local Fusion = deps.Fusion
	local Util = deps.Util
	local Components = deps.Components

	local mergedComponents = table.clone(Components)
	mergedComponents.Icon = OnyxIcon

	return function(Scope, Props)
		Props = Props or {}
		Scope = Fusion.innerScope(Scope, Fusion, Util, mergedComponents)
		return Scope:Icon(Props)
	end
end
