--[=[
	@class IconButton

	Compact button with an icon stacked above a label. Used as the side-launcher
	button for opening Widget panels (Profile, Inventory, Shop, etc.).

	Reads `Theme.IconButton.ColorRole` (default "Primary") for the gradient.
	Per-instance overrides:
	  * `ColorRole`         — palette role string
	  * `ColorSequence`     — raw gradient (wins over ColorRole)
	  * `HideBackground`    — drop the elevated chrome, render icon + label only
	                          (useful when the button sits over its own art)
]=]

return function(deps, lib)
	local Fusion = deps.Fusion
	local Themer = deps.Themer
	local Util = deps.Util
	local CombineProps = deps.CombineProps
	local Children = deps.Children
	local Components = deps.Components
	local configValue = deps.configValue
	local configSlot = deps.configSlot
	local themeColor = deps.themeColor

	export type Props = {
		Image: string?,
		Text: string?,
		ColorRole: string?,
		ColorSequence: any?,
		HideBackground: boolean?,
		OnActivate: (() -> ())?,
	}

	return function(Scope, Props: Props?)
		Props = Props or {}
		Scope = Fusion.innerScope(Scope, Fusion, Util, Components)
		local Theme = Themer.Theme:now()
		local iconConfig = configSlot(Theme, "IconButton")

		local hideBackground = Util.Fallback(Props.HideBackground, false)
		Props.HideBackground = nil

		local colorRole = Props.ColorRole or configValue(iconConfig.ColorRole, "Primary")
		Props.ColorRole = nil

		local colorSequence = Props.ColorSequence or Scope:Computed(function(use)
			return ColorSequence.new(
				use(themeColor(Theme, colorRole, "Main")),
				use(themeColor(Theme, colorRole, "Dark"))
			)
		end)
		Props.ColorSequence = nil

		-- Press/hover scale animations live here; the icon hover-spin is owned
		-- by the shared HoverSpinIcon component below so the launcher buttons
		-- match the spin used in Inventory / GameShop / Trade / etc.
		local hovering = Scope:Value(false)
		local holding = Scope:Value(false)
		local rawScale = Scope:Spring(
			Scope:Computed(function(use)
				if use(holding) then return 0.85
				elseif use(hovering) then return 1.025
				else return 1 end
			end),
			Scope:Computed(function(use)
				return use(holding) and 10000 or 25
			end),
			0.25
		)

		-- Shared hover-spin: same Spring-driven oscillation used by Inventory /
		-- GameShop / Trade item icons. `iconHolder` parents the actual
		-- ImageLabel; `spinIcon` is the trigger fired from BaseButton's OnHover.
		local iconHolder, spinIcon
		if Props.Image ~= nil then
			iconHolder, spinIcon = lib.HoverSpinIcon(Scope, {
				Image = Props.Image,
				Size = UDim2.fromOffset(40, 40),
				LayoutOrder = 1,
			})
		end

		-- Inner content: icon above label with a small fixed gap. UIListLayout
		-- with VerticalAlignment.Center keeps the pair centered, so the visual
		-- spacing is just the layout `Padding`.
		local content = Scope:New "Frame" {
			Name = "Content",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			[Children] = {
				Scope:New "UIListLayout" {
					FillDirection = Enum.FillDirection.Vertical,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, 0),
					SortOrder = Enum.SortOrder.LayoutOrder,
				},
				iconHolder,
				Scope:Text {
					Name = "Label",
					Size = UDim2.new(1, 0, 0, 22),
					AutomaticSize = Enum.AutomaticSize.None,
					TextXAlignment = Enum.TextXAlignment.Center,
					Text = Props.Text,
					TextScaled = true,
					Rotation = 0.01,
					LayoutOrder = 2,
					Stroke = {
						ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
						Color = Color3.new(0, 0, 0),
						LineJoinMode = Enum.LineJoinMode.Round,
						Thickness = 3,
					},
				},
			},
		}

		local layers = {
			Scope:New "UIScale" {
				Scale = Scope:Computed(function(use)
					return math.round(use(rawScale) * 100) / 100
				end),
			},
		}

		if not hideBackground then
			-- Elevated chrome (drop shadow + inner gradient stroke). The hover
			-- dim overlay is a child of the pane so it follows the same shape.
			table.insert(layers, lib.ElevatedPane(Scope, {
				Elevation = 4,
				Size = UDim2.fromScale(1, 1),
				Corner = { Radius = Scope:UDim(0, Theme.CornerRadius.Base) },
				ColorSequence = colorSequence,
				[Children] = {
					Scope:Frame {
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = Scope:Spring(
							Scope:Computed(function(use)
								if use(holding) then return 0.5
								elseif use(hovering) then return 0.75
								else return 1 end
							end),
							100
						),
					},
				},
			}))
		end

		table.insert(layers, content)

		return Scope:BaseButton(CombineProps(Props, {
			Name = "IconButton",
			Size = Scope:UDim2Offset(80, 80),
			BackgroundTransparency = 1,
			BackgroundColor3 = Theme.Colors.Base.Main,
			AutomaticSize = Enum.AutomaticSize.None,
			ClipsDescendants = false,
			Hovering = hovering,
			Holding = holding,
			OnHover = spinIcon,
			[Children] = layers,
		}))
	end
end
