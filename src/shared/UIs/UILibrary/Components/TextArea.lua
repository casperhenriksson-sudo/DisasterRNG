--[=[
	@class TextArea

	Multi-line text input. Pure passthrough wrapper over OnyxUI's TextArea (which
	extends OnyxUI's TextInput primitive — distinct from our themed `UILibrary.TextInput`).
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local OnyxUI = ReplicatedStorage.Packages.OnyxUI.Packages.OnyxUI
local OnyxTextArea = require(OnyxUI.Components.TextArea)

return function(deps, lib)
	local Fusion = deps.Fusion
	local Util = deps.Util
	local Components = deps.Components

	local mergedComponents = table.clone(Components)
	mergedComponents.TextArea = OnyxTextArea

	return function(Scope, Props)
		Props = Props or {}
		Scope = Fusion.innerScope(Scope, Fusion, Util, mergedComponents)
		return Scope:TextArea(Props)
	end
end
