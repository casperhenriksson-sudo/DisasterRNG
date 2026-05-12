--[=[
	@class HoverSpinIcon

	Centered icon that wiggles via a Fusion Spring on demand. Returns the
	holder Frame plus a `spin` trigger function — wire `spin` into any
	BaseButton/Button `OnHover` (or call directly) to reproduce the same
	hover-spin used by the Inventory item icons.

	The icon sits inside a fixed-size holder so it can drop straight into
	a UIListLayout / UIGridLayout slot without rotation perturbing the
	layout. The image itself is anchored at its center so rotation pivots
	cleanly around the icon (instead of swinging from a corner, which
	makes a small-angle tilt visually invisible).

	Usage:
		local holder, spin = HoverSpinIcon(Scope, {
			Image = product.Icon,
			Size = UDim2.fromOffset(76, 76),
			LayoutOrder = 1,
		})

		Button(Scope, {
			OnHover = spin,
			[Children] = { ..., holder, ... },
		})

	Props:
		Image            : asset id (string or reactive)
		Size             : holder size, default UDim2.fromOffset(64, 64)
		Angle            : peak rotation in degrees, default 25
		Speed            : spring speed, default 30
		Damping          : spring damping ratio, default 0.25
		ScaleType        : Enum.ScaleType, default Fit
		ImageTransparency: forwarded to the inner ImageLabel
		ImageColor3      : forwarded to the inner ImageLabel
		Name             : holder Name, default "IconHolder"
		LayoutOrder      : forwarded to the holder
		AnchorPoint      : forwarded to the holder
		Position         : forwarded to the holder
		ZIndex           : forwarded to the holder
]=]

return function(deps, lib)
	local Fusion = deps.Fusion
	local Util = deps.Util
	local Children = deps.Children
	local Components = deps.Components

	return function(Scope, Props)
		Props = Props or {}
		Scope = Fusion.innerScope(Scope, Fusion, Util, Components)

		local angle = Props.Angle or 40
		local speed = Props.Speed or 15
		local damping = Props.Damping or 0.25
		local size = Props.Size or UDim2.fromOffset(64, 64)

		local rotation = Scope:Spring(Scope:Value(0), speed, damping)

		local holder = Scope:New "Frame" {
			Name = Props.Name or "IconHolder",
			Size = size,
			BackgroundTransparency = 1,
			LayoutOrder = Props.LayoutOrder,
			AnchorPoint = Props.AnchorPoint,
			Position = Props.Position,
			ZIndex = Props.ZIndex,
			[Children] = {
				Scope:New "ImageLabel" {
					Name = "Icon",
					Image = Props.Image or "",
					Size = UDim2.fromScale(1, 1),
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					ScaleType = Props.ScaleType or Enum.ScaleType.Fit,
					ImageTransparency = Props.ImageTransparency,
					ImageColor3 = Props.ImageColor3,
					Rotation = rotation,
				},
			},
		}

		local function spin()
			rotation:setPosition(angle)
		end

		return holder, spin
	end
end
