--[=[
	@class Tabs

	Themed tab strip rendered as Buttons. The selected tab paints with
	`Theme.Button.Active`; the rest use `Theme.Button.Secondary`. Tabs ride
	the same theme spec as the button system, so a theme that re-skins
	buttons automatically re-skins tabs too.

	Props:
	  Tabs        { string | { string } }   -- labels (OnyxUI shape supported)
	  Tab         Fusion.Value | number     -- active index (default 1)
	  OnActivated function(i)               -- fired when a tab is selected
	  ButtonProps table                     -- forwarded to each child Button
	  List        table                     -- override the inner UIListLayout

	`Tabs` accepts either bare strings or single-element arrays
	(`{ "Label" }`) to stay backwards-compatible with the old OnyxUI API.
]=]

return function(deps, lib)
	local Fusion = deps.Fusion
	local Themer = deps.Themer
	local Util = deps.Util
	local CombineProps = deps.CombineProps
	local Children = deps.Children
	local Components = deps.Components

	return function(Scope, Props)
		Props = Props or {}
		Scope = Fusion.innerScope(Scope, Fusion, Util, Components)
		local Theme = Themer.Theme:now()

		local tabs = Util.Fallback(Props.Tabs, {})
		local tab = Scope:EnsureValue(Util.Fallback(Props.Tab, 1))
		local onActivated = Props.OnActivated
		local listOverride = Props.List
		local buttonPropsOverride = Props.ButtonProps and table.clone(Props.ButtonProps) or {}

		Props.Tabs = nil
		Props.Tab = nil
		Props.OnActivated = nil
		Props.ButtonProps = nil
		Props.List = nil
		-- Legacy props from the OnyxUI wrapper — ignored now that tabs read
		-- their look from Theme.Button.{Active,Secondary}.
		Props.ColorRole = nil
		Props.Color = nil

		-- Lock down per-button props the strip owns. Caller-supplied
		-- ButtonProps can still customise text styling, padding, etc., but
		-- can't break tab selection or theming.
		buttonPropsOverride.Variant = nil
		buttonPropsOverride.OnActivate = nil
		buttonPropsOverride.Text = nil
		buttonPropsOverride.LayoutOrder = nil

		-- OnyxUI Tabs took `{ { "Label" } }`; bare strings work too for
		-- ergonomics. First string in the inner table wins.
		local function labelOf(content)
			if type(content) == "string" then return content end
			if type(content) == "table" then
				for _, c in ipairs(content) do
					if type(c) == "string" then return c end
				end
			end
			return ""
		end

		local children = {
			Scope:New "UIListLayout" (CombineProps(listOverride or {}, {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				HorizontalFlex = Enum.UIFlexAlignment.Fill,
			})),
		}

		for i, content in ipairs(tabs) do
			local label = labelOf(content)
			table.insert(children, lib.Button(Scope, CombineProps(buttonPropsOverride, {
				Text = label,
				LayoutOrder = i,
				Size = UDim2.new(0, 0, 1, 0),
				AutomaticSize = Enum.AutomaticSize.None,
				-- Reactive variant: each tab re-resolves its spec when the
				-- active index changes, so swapping themes (or toggling
				-- selection) re-skins instantly.
				Variant = Scope:Computed(function(use)
					return use(tab) == i and Theme.Button.Active or Theme.Button.Secondary
				end),
				OnActivate = function()
					tab:set(i)
					if onActivated then onActivated(i) end
				end,
			})))
		end

		return Scope:New "Frame" (CombineProps(Props, {
			Name = "Tabs",
			BackgroundTransparency = 1,
			[Children] = children,
		}))
	end
end
