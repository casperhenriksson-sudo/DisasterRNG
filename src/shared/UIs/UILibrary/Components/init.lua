--[=[
	@class UILibraryComponents

	Shared component implementations. Each component is its own child
	ModuleScript and receives `(deps, lib)`. Cross-component refs go through
	`lib.X(...)` and resolve at call time.
]=]

return function(deps)
	local peek = deps.peek

	local function configValue(value, fallback)
		local resolved = peek(value)
		if resolved == nil then
			return fallback
		end
		return resolved
	end

	local function configSlot(Theme, slotName)
		local slot = Theme[slotName]
		if type(slot) == "table" then
			return slot
		end
		return {}
	end

	local function themeColor(Theme, role, tone)
		local resolvedRole = configValue(role, "Error")
		local palette = Theme.Colors[resolvedRole] or Theme.Colors.Error
		return palette[tone or "Main"] or Theme.Colors.Error.Main
	end

	local extDeps = {}
	for k, v in pairs(deps) do
		extDeps[k] = v
	end
	extDeps.configValue = configValue
	extDeps.configSlot = configSlot
	extDeps.themeColor = themeColor

	local lib = {}
	-- HoverSpinIcon registers first so other components (notably IconButton)
	-- can resolve `lib.HoverSpinIcon` at construction time.
	lib.HoverSpinIcon = require(script.HoverSpinIcon)(extDeps, lib)
	lib.Pane = require(script.Pane)(extDeps, lib)
	lib.ElevatedPane = require(script.ElevatedPane)(extDeps, lib)
	lib.Button = require(script.Button)(extDeps, lib)
	lib.CloseButton = require(script.CloseButton)(extDeps, lib)
	lib.HeadingBanner = require(script.HeadingBanner)(extDeps, lib)
	lib.Widget = require(script.Widget)(extDeps, lib)
	lib.Divider = require(script.Divider)(extDeps, lib)
	lib.TextInput = require(script.TextInput)(extDeps, lib)
	lib.IconButton = require(script.IconButton)(extDeps, lib)
	lib.Badge = require(script.Badge)(extDeps, lib)
	lib.Card = require(script.Card)(extDeps, lib)
	lib.ProgressBar = require(script.ProgressBar)(extDeps, lib)
	lib.Switch = require(script.Switch)(extDeps, lib)
	lib.Checkbox = require(script.Checkbox)(extDeps, lib)
	lib.Slider = require(script.Slider)(extDeps, lib)
	lib.TextArea = require(script.TextArea)(extDeps, lib)
	lib.TextSwap = require(script.TextSwap)(extDeps, lib)
	lib.Tabs = require(script.Tabs)(extDeps, lib)
	lib.TitleBar = require(script.TitleBar)(extDeps, lib)
	lib.Scroller = require(script.Scroller)(extDeps, lib)
	lib.Avatar = require(script.Avatar)(extDeps, lib)
	lib.Icon = require(script.Icon)(extDeps, lib)
	lib.IconText = require(script.IconText)(extDeps, lib)
	lib.IconSwap = require(script.IconSwap)(extDeps, lib)
	lib.HUD = require(script.HUD)(extDeps, lib)
	lib.LoadingScreen = require(script.LoadingScreen)(extDeps, lib)
	lib.XPBar = require(script.XPBar)(extDeps, lib)
	lib.Toast = require(script.Toast)(extDeps, lib)

	return lib
end
