--[=[
	@class CloseButton

	Themed close (X) button. Reads `Theme.CloseButton` slot whose entries are
	merged onto props as defaults — Image, Size, Position, AnchorPoint, Rotation,
	ColorRole, etc. all themable.
]=]

return function(deps, lib)
	local Fusion = deps.Fusion
	local Themer = deps.Themer
	local Util = deps.Util
	local ColorUtils = deps.ColorUtils
	local CombineProps = deps.CombineProps
	local Children = deps.Children
	local Components = deps.Components
	local configSlot = deps.configSlot
	local themeColor = deps.themeColor

	return function(Scope, Props)
		Props = Props or {}
		Scope = Fusion.innerScope(Scope, Fusion, Util, Components)
		local Theme = Themer.Theme:now()
		local closeConfig = configSlot(Theme, "CloseButton")

		local hidden = Props.Hidden or false
		local colorRole = Props.ColorRole or closeConfig.ColorRole or "Error"
		Props.ColorRole = nil

		local image = Props.Image or closeConfig.Image
		Props.Image = nil

		Props.HideStroke = nil
		Props.ElevatedPane = nil

		local handledKeys = {
			ColorRole = true,
			Image = true,
			HideStroke = true,
		}
		for k, v in pairs(closeConfig) do
			if not handledKeys[k] and Props[k] == nil then
				Props[k] = v
			end
		end

		local buttonProps = {
			Size = UDim2.fromOffset(54, 54),
			Visible = Scope:Computed(function(use)
				return not use(hidden)
			end),
		}

		if image then
			buttonProps.Image = image
		else
			buttonProps.ColorSequence = Scope:Computed(function(use)
				local base = use(themeColor(Theme, colorRole, "Main"))
				return ColorSequence.new(base, ColorUtils.Darken(base, 0.4))
			end)
			buttonProps[Children] = {
				Scope:Text {
					Text = "X",
					TextSize = Theme.TextSize["1.875"],
				},
			}
		end

		return lib.Button(Scope, CombineProps(Props, buttonProps))
	end
end
