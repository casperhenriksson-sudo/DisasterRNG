--[=[
	@class Card

	Themed card surface. Wraps OnyxUI's Card primitive. Reads `Theme.Card.ColorRole`
	(default "Base") for background; per-instance `BackgroundColor3` or `ColorRole`
	overrides.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local OnyxUI = ReplicatedStorage.Packages.OnyxUI.Packages.OnyxUI
local OnyxCard = require(OnyxUI.Components.Card)

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
	mergedComponents.Card = OnyxCard

	return function(Scope, Props)
		Props = Props or {}
		Scope = Fusion.innerScope(Scope, Fusion, Util, mergedComponents)
		local Theme = Themer.Theme:now()
		local config = configSlot(Theme, "Card")

		local colorRole = Props.ColorRole or configValue(config.ColorRole, "Base")
		Props.ColorRole = nil

		local bg = Props.BackgroundColor3
		Props.BackgroundColor3 = nil
		if bg == nil then
			bg = themeColor(Theme, colorRole, "Main")
		end

		local extras = { BackgroundColor3 = bg }
		if config.CornerRadius ~= nil then extras.Corner = { Radius = config.CornerRadius } end
		if config.Padding ~= nil then extras.Padding = config.Padding end

		return Scope:Card(CombineProps(Props, extras))
	end
end
