--[=[
	@class UILibrary

	Shared boilerplate components for UI templates.

	Exports: Themes (named themes), GameTheme (= Themes.Studs, default),
	Pane, ElevatedPane, CloseButton, HeadingBanner, Widget, Divider, TextInput,
	Button, IconButton, Badge, Card, ProgressBar, Switch, Checkbox, Slider,
	TextArea, TextSwap, Tabs, TitleBar, Scroller, plus OnyxUI/Fusion re-exports.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local OnyxUI = ReplicatedStorage.Packages.OnyxUI.Packages.OnyxUI
local Fusion = require(OnyxUI.Parent.Fusion)
local ColorUtils = require(OnyxUI.Parent.ColorUtils)
local Themer = require(OnyxUI.Themer)
local OnyxNightTheme = require(OnyxUI.Themer.OnyxNight)
local Util = require(OnyxUI.Util)

local Frame = require(OnyxUI.Components.Frame)
local Image = require(OnyxUI.Components.Image)
local Text = require(OnyxUI.Components.Text)
local Heading = require(OnyxUI.Components.Heading)
local Group = require(OnyxUI.Components.Group)
local BaseButton = require(OnyxUI.Components.BaseButton)
local SharedComponentFactory = require(script.Components)

local CombineProps = Util.CombineProps
local Children = Fusion.Children
local peek = Fusion.peek

-- Wraps a text-rendering OnyxUI component so it auto-applies the active
-- theme's `Theme.TextStroke` slot when the caller didn't pass an explicit
-- `Stroke` prop. Pass `Stroke = false` to opt out, or `Stroke = {...}` to
-- override fully (caller's table wins, no merge).
--
-- `multiplier` accounts for components that scale TextSize before render
-- (e.g. Heading multiplies by HeadingSize, default 1.75) so the stroke
-- thickness derived from `Theme.TextStroke.Thickness(size)` reflects the
-- size that actually hits the screen.
local function wrapWithTextStroke(component, multiplier)
	multiplier = multiplier or 1
	return function(Scope, Props)
		Props = Props or {}
		local stroke = Props.Stroke
		if stroke == false then
			Props.Stroke = nil
		elseif stroke == nil then
			local Theme = Themer.Theme:now()
			local config = Theme.TextStroke
			if config then
				local sizeProp = Props.TextSize
				local thickness = config.Thickness
				if type(thickness) == "function" then
					local fn = thickness
					thickness = Scope:Computed(function(use)
						local resolved = use(sizeProp)
						if type(resolved) ~= "number" then
							resolved = use(Theme.TextSize["1"])
						end
						return fn((resolved or 20) * multiplier)
					end)
				end
				Props.Stroke = {
					ApplyStrokeMode = config.ApplyStrokeMode or Enum.ApplyStrokeMode.Contextual,
					LineJoinMode = config.LineJoinMode or Enum.LineJoinMode.Round,
					Color = config.Color or Color3.new(0, 0, 0),
					Transparency = config.Transparency or 0,
					Thickness = thickness,
				}
			end
		end
		return component(Scope, Props)
	end
end

local WrappedText = wrapWithTextStroke(Text, 1)
local WrappedHeading = wrapWithTextStroke(Heading, 1.75)

-- Fusion's scope merge silently drops overrides (merge.lua only logs conflicts;
-- it never actually overwrites). That means putting WrappedText into our own
-- Components table doesn't help — when callers' outer scope already has bare
-- OnyxUI Text, the inner scope's WrappedText gets shadowed.
--
-- Workaround: mutate the shared OnyxUI.Components table directly so every
-- caller that does `require(OnyxUI.Components)` ends up with the wrapped
-- Text/Heading. require() returns the same table by reference, so this is
-- a one-time surgical replacement, not a copy.
local SharedOnyxComponents = require(OnyxUI.Components)
SharedOnyxComponents.Text = WrappedText
SharedOnyxComponents.Heading = WrappedHeading

-- Catch-all auto-stroke for raw `Scope:New "TextLabel"` / `Scope:New "TextButton"`
-- callsites scattered through the templates. Fusion.New (in this place's copy
-- of the elttob_fusion package) calls `_G.__OnyxAutoStrokeHook(className,
-- instance, props)` after applying props; here we register that hook to attach
-- a themed UIStroke when none is already present (OnyxUI's Base path adds its
-- own UIStroke from the Stroke prop, so we skip those automatically).
local _autoStrokeHook
_autoStrokeHook = function(className, instance, props)
	if className ~= "TextLabel" and className ~= "TextButton" then
		return
	end
	if instance:FindFirstChildOfClass("UIStroke") then
		return
	end
	local theme = Themer.Theme:now()
	local config = theme and theme.TextStroke
	if not config then
		return
	end
	local size = props and props.TextSize
	if type(size) ~= "number" then
		size = 20
	end
	local thickness = config.Thickness
	if type(thickness) == "function" then
		thickness = thickness(size)
	end
	local stroke = Instance.new("UIStroke")
	stroke.Color = config.Color or Color3.new(0, 0, 0)
	stroke.ApplyStrokeMode = config.ApplyStrokeMode or Enum.ApplyStrokeMode.Contextual
	stroke.LineJoinMode = config.LineJoinMode or Enum.LineJoinMode.Round
	stroke.Transparency = config.Transparency or 0
	stroke.Thickness = thickness or 2
	stroke.Parent = instance
end
;(_G :: any).__OnyxAutoStrokeHook = _autoStrokeHook



local Components = {
	Frame = Frame,
	Image = Image,
	Text = WrappedText,
	Heading = WrappedHeading,
	Group = Group,
	BaseButton = BaseButton,
}

local ThemeConfigs = {
	Studs = {
		ThemeName = "Studs",
		Colors = {
			Primary = { Main = Color3.fromHex "00F7FF", Dark = Color3.fromHex "0066FF" },
			Secondary = { Main = Color3.fromHex "FFF600", Dark = Color3.fromHex "00A700" },
			Accent = { Main = Color3.new(1, 1, 1) },
			Neutral = { Main = Color3.fromHex "BABABA", Dark = Color3.fromHex "525252" },
			NeutralContent = { Main = Color3.fromHex "A8A29E" },
			Base = { Main = Color3.fromHex "0F1519" },
			BaseContent = { Main = Color3.new(1, 1, 1) },
			Success = { Main = Color3.fromHex "22C55E" },
			Error = { Main = Color3.fromHex "EF4444" },
			Warning = { Main = Color3.fromHex "F59E0B" },
			Info = { Main = Color3.fromHex "22D3EE" },
		},
		Font = {
			Body = "rbxasset://fonts/families/Montserrat.json",
			Heading = "rbxasset://fonts/families/Montserrat.json",
			Monospace = "rbxasset://fonts/families/Montserrat.json",
		},
		FontWeight = {
			Body = Enum.FontWeight.Bold,
			Bold = Enum.FontWeight.Bold,
			Heading = Enum.FontWeight.ExtraBold,
		},
		TextSize = {
			["0.75"] = 16,
			["0.875"] = 18,
			Base = 20,
			["1"] = 20,
			["1.125"] = 24,
			["1.25"] = 28,
			["1.5"] = 32,
			["1.875"] = 36,
			["2.25"] = 38,
			["3"] = 40 ,
			["3.75"] = 48,
			["4.5"] = 52,
			["5.5"] = 56,
			["6.5"] = 64,
		},
		CornerRadius = { Base = 8 },
		StrokeThickness = { Base = 4 },
		StrokeEmphasis = { Regular = 0.2 },
		Spacing = { Base = 22 },
		Sizing = { Base = 22 },
		Padding = { ["0.5"] = 10,  Base = 16 },
		SpringSpeed = { Base = 50 },
		SpringDampening = { Base = 1 },
		Sound = {},
		Emphasis = {},
		Background = {
			--Color = Color3.fromHex("101517"),
			--Transparency = 1,
			ImageId = "rbxassetid://135275431100741",
			--ImageTransparency = 0,
			ScaleType = Enum.ScaleType.Crop,
		},
		Pane = {
			UseThemeBackground = true,
			BackgroundTransparency = 0.35,
			WatermarkImageId = "rbxassetid://135275431100741",
			WatermarkImageTransparency = 0.4,
			WatermarkSize = 1200,
			ClipsDescendants = false,
		},
		Widget = {
			BannerHeight = 110,
			-- Per-edge body padding. Top stays small because BannerHeight
			-- already handles the gap below the banner; give Left/Right/
			-- Bottom enough breathing room for content-heavy templates
			-- (Inventory grid, Shop columns) so they don't butt against
			-- the panel edges.

			Padding = {
				Top = UDim.new(0, 24),
				Bottom = UDim.new(0, 24),
				Left   = UDim.new(0.01, 24),
				Right = UDim.new(0.01, 24)
			},

			--BackgroundImage = {
			--	Image =	"rbxassetid://76910057910474",
			--}
		},
		HeadingBanner = {
			TextProps = {
				Stroke = {
					ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
					Color = Color3.fromHex("#000000"),
					LineJoinMode = Enum.LineJoinMode.Round,
					Thickness = 4,
				},
			},
		},
		CloseButton = {
			ColorRole = "Error",
			Position = UDim2.fromScale(1, 0.5),
			AnchorPoint = Vector2.new(1, 0.5),

			--HideStroke = true,
			Image = "rbxassetid://76910057910474",
		},
		IconButton = { ColorRole = "Primary" },
		Badge = {
			ColorRole = "Primary",
			Padding = {
				All = UDim.new(0, 6),
				Left = UDim.new(0, 12),
				Right = UDim.new(0, 12),
			},
		},
		Card = { ColorRole = "Accent" },
		ProgressBar = { ColorRole = "Primary" },
		Switch = { ColorRole = "Success" },
		Checkbox = { ColorRole = "Primary" },
		Slider = { ColorRole = "Success" },
		TextSwap = { ColorRole = "Primary" },
		Tabs = { ColorRole = "Primary" },
		TitleBar = { ColorRole = "BaseContent" },
		Avatar = { RingColorRole = "Primary", IndicatorColorRole = "Success" },
		IconText = { ColorRole = "BaseContent" },
		IconSwap = { ColorRole = "Primary" },
		HUD = {
			IconColorRole = "Secondary",
			BackgroundColorRole = "Base",
			BackgroundTransparency = 0.05,
			IconSize = 48,
			IconOverhang = 8,
			IconGap = 12,
			IconImage = "rbxassetid://123251413929848",
		},
		XPBar = {
			ProgressColorRole = "Primary",
			LabelColorRole = "BaseContent",
			BackgroundColorRole = "Base",
			BackgroundTransparency = 0.05,
			BarHeight = 14,
			LabelGap = 6,
		},
		LoadingScreen = {
			ProgressColorRole = "Success",
			TitleColorRole = "BaseContent",
			SubtextColorRole = "BaseContent",
			BackgroundColorRole = "Base",
			BackgroundImage = "rbxassetid://72499194346940",
		},
		Toast = {
			BackgroundTransparency = 0.25,
			CornerRadius = UDim.new(1, 0),
			Padding = { Vertical = 12, Horizontal = 18 },
			IconSize = 36,
			DividerWidth = 2,
			DividerColor = Color3.new(1, 1, 1),
			DividerTransparency = 0.5,
			TextColorRole = "BaseContent",
			Severities = {
				Info = {
					Icon = "rbxassetid://140291432435133",
					ColorRole = "Info",
					BackgroundColorRole = "Neutral",
				},
				Success = {
					Icon = "rbxassetid://103438334837778",
					ColorRole = "Success",
					BackgroundColorRole = "Success",
				},
				Warning = {
					Icon = "rbxassetid://110209612171213",
					ColorRole = "Warning",
					BackgroundColorRole = "Warning",
				},
				Error = {
					Icon = "rbxassetid://120469969313346",
					ColorRole = "Error",
					BackgroundColorRole = "Neutral",
				},
				Announcement = {
					Icon = nil,
					ColorRole = "Neutral",
					BackgroundColorRole = "Neutral",
				},
			},
		},

		Button = {
			Default = {
				Image = "rbxassetid://102355872404947",
				TextColor3 = Color3.fromHex("#3A2A10"),
				TextSize = 28,
			},

			Active = {
				Image = "rbxassetid://127652267430903",
				TextColor3 = Color3.fromHex("#3B2600"),
				TextSize = 28,
			},

			Secondary = {
				Image = "rbxassetid://108147913930831",
				TextColor3 = Color3.fromHex("#3B2A0A"),
				TextSize = 28,
			},

			Enabled = {
				Image = "rbxassetid://121545617864772",
				TextColor3 = Color3.fromHex("#1F3A05"),
				TextSize = 28,
			},

			Destructive = {
				Image = "rbxassetid://125092722896041",
				TextColor3 = Color3.fromHex("#FFFFFF"),
				TextSize = 28,
			},

			Ghost = {
				Image = "rbxassetid://92375383899635",
				TextColor3 = Color3.fromHex("#2B2B2B"),
				TextSize = 28,
			},
		},


		Scrollbar = { Color = Color3.new(1, 1, 1) },
		TextStroke = {
			Color = Color3.fromHex("#000000"),
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			LineJoinMode = Enum.LineJoinMode.Round,
			Transparency = 0,
			-- Thickness scales with rendered text size. ~1px per 14px of text,
			-- floored at 1, gives a readable outline at body sizes (20→2,
			-- 28→2, 38→3) and a chunkier banner stroke (56→4, 64→5).
			Thickness = function(size)
				return math.max(2, math.round(size / 12))
			end,
		},
	},

	Dracula = {
		ThemeName = "Dracula",
		Colors = {
			Primary = { Main = Color3.fromHex "7C3AED", Dark = Color3.fromHex "3B14A7" },
			Secondary = { Main = Color3.fromHex "FBC72D", Dark = Color3.fromHex "FF8A1E" },
			Accent = { Main = Color3.fromHex "E06BF9" },
			Neutral = { Main = Color3.fromHex "B8A8D9", Dark = Color3.fromHex "070515" },
			NeutralContent = { Main = Color3.fromHex "B8A8D9" },
			Base = { Main = Color3.fromHex "070515", Dark = Color3.fromHex "000000" },
			BaseContent = { Main = Color3.fromHex "FFFFFF" },
			Success = { Main = Color3.fromHex "4ADE80", Dark = Color3.fromHex "16A34A" },
			Error = { Main = Color3.fromHex "EF4444", Dark = Color3.fromHex "B91C1C" },
			Warning = { Main = Color3.fromHex "FBC72D", Dark = Color3.fromHex "FF8A1E" },
			Info = { Main = Color3.fromHex "67E8F9" },
		},
		Font = {
			Body = "rbxasset://fonts/families/Fondamento.json",
			Heading = "rbxasset://fonts/families/Fondamento.json",
			Monospace = "rbxasset://fonts/families/Fondamento.json",
		},
		FontWeight = {
			Body = Enum.FontWeight.Medium,
			Bold = Enum.FontWeight.Bold,
			Heading = Enum.FontWeight.ExtraBold,
		},
		TextSize = {
			["0.75"] = 20,
			["0.875"] = 22,
			Base = 24,
			["1"] = 24,
			["1.125"] = 28,
			["1.25"] = 34,
			["1.5"] = 44,
			["1.875"] = 44,
			["2.25"] = 46,
			["3"] = 48 ,
			["3.75"] = 58,
			["4.5"] = 62,
			["5.5"] = 68,
			["6.5"] = 76
		},
		-- Dracula uses sharp corners everywhere. We override every CornerRadius
		-- key OnyxUI components read (.Base, "0.5", "1", "2", "3", "4", "6", Full)
		-- so the no-rounding rule applies globally — no per-component overrides
		-- needed. The themed Badge.CornerRadius slot still wins on top of this.
		CornerRadius = {
			Base = 0,
			["0"] = 0,
			["0.5"] = 0,
			["1"] = 0,
			["1.5"] = 0,
			["2"] = 0,
			["3"] = 0,
			["4"] = 0,
			["6"] = 0,
			Full = 0,
		},
		StrokeThickness = { Base = 3 },
		StrokeEmphasis = { Regular = 0.2 },
		Spacing = { Base = 22 },
		Sizing = { Base = 22 },
		Padding = { Base = 16 },
		SpringSpeed = { Base = 50 },
		SpringDampening = { Base = 1 },
		Sound = {},
		Emphasis = {},
		Background = {
			-- Image-only background. No solid Color: the halftone image has
			-- transparent regions, and we want those to remain transparent so
			-- nothing bleeds through underneath.
			ImageId = "rbxassetid://126001157837467",
			ImageTransparency = 0,
			ScaleType = Enum.ScaleType.Stretch,
		},
		Pane = {
			BackgroundTransparency = 0.35,
			Stroke = { Enabled = false },
			Corner = { Enabled = false },
			ClipsDescendants = false,
		},
		Widget = {
			-- Dracula's tilted-ribbon banner image visually overhangs into
			-- the body area; reserve enough vertical space so top-anchored
			-- content (e.g. Quest's tab strip) doesn't collide with the
			-- ribbon, while content-centered templates (Profile, Settings)
			-- still center cleanly in the remaining body area.
			BannerHeight = 100,
			-- Per-edge body padding. Top stays small because BannerHeight
			-- already handles the gap below the banner; give Left/Right/
			-- Bottom enough breathing room for content-heavy templates
			-- (Inventory grid, Shop columns) so they don't butt against
			-- the panel edges.

			Padding = {
				Top = UDim.new(0, 0),
				Bottom = UDim.new(0.02, 24),
				Left   = UDim.new(0.04, 12),
				Right = UDim.new(0.04, 12),
			},
		},
		HeadingBanner = {
			-- ColorRole is the fallback for templates that don't override Image;
			-- the gradient ElevatedPane path picks it up (currently unused by
			-- Dracula templates, all of which provide their own Image).
			ColorRole = "Base",
			-- Tilted orange banner overlay — pulled from the Dracula_GangInfo /
			-- Dracula_Settings template style. Reuses the Active button 9-slice
			-- asset since it has the right rounded-corner ribbon shape.
			Image = "rbxassetid://99132505905865",
			ImageProps = {
				Size = UDim2.new(0.7, 0, 1, 15),
				Position = UDim2.new(0, 0, 0.25, 5),
				AnchorPoint = Vector2.new(0.1, 0.5),
				Rotation = -2,
			},
			TextProps = {
				Rotation = -3,
				Position = UDim2.new(0.02, 16, 0.25, -4),
				AnchorPoint = Vector2.new(0, 0.5),
				TextXAlignment = Enum.TextXAlignment.Center,

				TextColor3 = Color3.fromRGB(16, 29, 16),
				TextSize = 52,
				Stroke = {
					ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
					Color = Color3.fromHex("#FFFFFF"),
					LineJoinMode = Enum.LineJoinMode.Round,
					Thickness = 3.25,
				},
			},
		},
		CloseButton = {
			ColorRole = "Secondary",
			Size = UDim2.fromOffset(54, 54),
			Position = UDim2.new(1, 0, 0, 5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = 5,
			HideStroke = true,
			Image = "rbxassetid://75595317912305",
		},
		IconButton = { ColorRole = "Primary" },
		Badge = {
			ColorRole = "Primary",
			CornerRadius = UDim.new(0, 0),
			Padding = {
				All = UDim.new(0, 6),
				Left = UDim.new(0, 12),
				Right = UDim.new(0, 12),
			},
		},
		Card = { ColorRole = "Primary" },
		ProgressBar = { ColorRole = "Primary" },
		Switch = { ColorRole = "Error" },
		Checkbox = { ColorRole = "Primary" },
		Slider = { ColorRole = "Error" },
		TextSwap = { ColorRole = "Primary" },
		Tabs = { ColorRole = "Primary" },
		TitleBar = { ColorRole = "BaseContent" },
		Avatar = { RingColorRole = "Primary", IndicatorColorRole = "Success" },
		IconText = { ColorRole = "BaseContent" },
		IconSwap = { ColorRole = "Primary" },
		HUD = {
			IconColorRole = "Secondary",
			BackgroundColorRole = "Neutral",
			BackgroundTransparency = 0.0,
			CornerRadius = UDim.new(0, 0),
			IconSize = 56,
			IconOverhang = 8,
			IconGap = 16,
			IconImage = "rbxassetid://123251413929848",
		},
		XPBar = {
			ProgressColorRole = "Primary",
			LabelColorRole = "BaseContent",
			BackgroundColorRole = "Neutral",
			BackgroundTransparency = 0.0,
			CornerRadius = UDim.new(0, 0),
			BarHeight = 16,
			LabelGap = 6,
		},
		LoadingScreen = {
			ProgressColorRole = "Primary",
			TitleColorRole = "BaseContent",
			SubtextColorRole = "BaseContent",
			BackgroundColorRole = "Base",
			BackgroundImage = "rbxassetid://72268513362896",
		},
		Toast = {
			BackgroundTransparency = 0.15,
			CornerRadius = UDim.new(0, 0),
			Padding = { Vertical = 12, Horizontal = 18 },
			IconSize = 36,
			DividerWidth = 2,
			DividerColor = Color3.new(1, 1, 1),
			DividerTransparency = 0.4,
			TextColorRole = "BaseContent",
			Severities = {
				Info = {
					Icon = "rbxassetid://140291432435133",
					ColorRole = "Info",
					BackgroundColorRole = "Neutral",
				},
				Success = {
					Icon = "rbxassetid://103438334837778",
					ColorRole = "Success",
					BackgroundColorRole = "Success",
				},
				Warning = {
					Icon = "rbxassetid://110209612171213",
					ColorRole = "Warning",
					BackgroundColorRole = "Warning",
				},
				Error = {
					Icon = "rbxassetid://120469969313346",
					ColorRole = "Error",
					BackgroundColorRole = "Neutral",
				},
				Announcement = {
					Icon = nil,
					ColorRole = "Neutral",
					BackgroundColorRole = "Neutral",
				},
			},
		},
		Button = {
			Default = {
				Image = "rbxassetid://94242502437540",
				TextColor3 = Color3.fromHex("#F8F8F2"),
				TextSize = 28,
			},

			Active = {
				Image = "rbxassetid://99132505905865",
				TextColor3 = Color3.fromHex("#2B1500"),
				TextSize = 28,
			},

			Secondary = {
				Image = "rbxassetid://79743679349001",
				TextColor3 = Color3.fromHex("#2B1500"),
				TextSize = 28,
			},

			Enabled = {
				Image = "rbxassetid://99127971476980",
				TextColor3 = Color3.fromHex("#062A12"),
				TextSize = 28,
			},

			Destructive = {
				Image = "rbxassetid://96626039026169",
				TextColor3 = Color3.fromHex("#FFFFFF"),
				TextSize = 28,
			},

			Ghost = {
				Image = "rbxassetid://80888453820957",
				TextColor3 = Color3.fromHex("#F8F8F2"),
				TextSize = 28,
			},
		},
		Scrollbar = { Color = Color3.fromHex("E06BF9") },
		TextStroke = {
			Color = Color3.fromHex("#000000"),
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			LineJoinMode = Enum.LineJoinMode.Round,
			Transparency = 0,
			Thickness = function(size)
				return math.max(2, math.round(size / 16))
			end,
		},
	},

	Arcade = {
		ThemeName = "Arcade",
		Colors = {
			-- Spec leads with Shop Red and Teleport Green as the two strongest
			-- accent colors; Accent picks up Inventory Yellow. The remaining
			-- spec colors (Codes Blue, Quests Gold) map to Info / Warning so
			-- toasts and badges can hit them without a new role.
			Primary = { Main = Color3.fromHex "F5362D", Dark = Color3.fromHex "B82218" },
			Secondary = { Main = Color3.fromHex "15C95A", Dark = Color3.fromHex "0E8E40" },
			Accent = { Main = Color3.fromHex "D6DB24" },
			-- Neutral and Base both point at the Charcoal Panel surface — every
			-- pane, card, and item slot in the spec is the same dark slab, so
			-- collapsing the two roles avoids accidental contrast drift.
			Neutral = { Main = Color3.fromHex "3B3B3B", Dark = Color3.fromHex "232323" },
			NeutralContent = { Main = Color3.fromHex "E6E6E6" },
			Base = { Main = Color3.fromHex "3B3B3B", Dark = Color3.fromHex "232323" },
			BaseContent = { Main = Color3.fromHex "FFFFFF" },
			Success = { Main = Color3.fromHex "35C84C", Dark = Color3.fromHex "1F8E32" },
			Error = { Main = Color3.fromHex "F5362D", Dark = Color3.fromHex "B82218" },
			Warning = { Main = Color3.fromHex "E3A516", Dark = Color3.fromHex "A07308" },
			Info = { Main = Color3.fromHex "259EF6", Dark = Color3.fromHex "1568AD" },
		},
		Font = {
			Body = "rbxasset://fonts/families/FredokaOne.json",
			Heading = "rbxasset://fonts/families/FredokaOne.json",
			Monospace = "rbxasset://fonts/families/RobotoMono.json",
		},
		FontWeight = {
			Body = Enum.FontWeight.Regular,
			Bold = Enum.FontWeight.Bold,
			Heading = Enum.FontWeight.ExtraBold,
		},
		TextSize = {
			["0.75"] = 16,
			["0.875"] = 18,
			Base = 20,
			["1"] = 20,
			["1.125"] = 24,
			["1.25"] = 28,
			["1.5"] = 32,
			["1.875"] = 36,
			["2.25"] = 38,
			["3"] = 40,
			["3.75"] = 48,
			["4.5"] = 52,
			["5.5"] = 56,
			["6.5"] = 64,
		},
		CornerRadius = { Base = 12 },
		StrokeThickness = { Base = 4 },
		-- Soft halo stroke (matching Dracula) — the chunky black ink outline
		-- has been disabled in favor of an unbordered look.
		StrokeEmphasis = { Regular = 0.2 },
		Spacing = { Base = 22 },
		Sizing = { Base = 22 },
		Padding = { Base = 16 },
		SpringSpeed = { Base = 50 },
		SpringDampening = { Base = 1 },
		Sound = {},
		Emphasis = {},
		Background = {
			-- Light surface, opposite of Studs — the dark charcoal panels
			-- need a bright halo around them to read as floating slabs.
			--Color = Color3.fromHex("F4F4F4"),
			ImageId = "rbxassetid://106555095919932", -- PLACEHOLDER: subtle light dot/grid pattern
			ImageTransparency = 0,
			ScaleType = Enum.ScaleType.Stretch,
		},

		Pane = {
			BackgroundTransparency = 0,
			-- Borderless: pane stroke disabled to match Dracula's clean,
			-- outline-free panel look.
			Stroke = { Enabled = false },
			Corner = { Enabled = false },
			ClipsDescendants = false,
		},
		Widget = {
			-- Padding mirrors Dracula: small top gap (BannerHeight already
			-- handles the space below the banner) with generous Left/Right/
			-- Bottom breathing room for content-heavy templates.
			BannerHeight = 104,
			Padding = {
				Top = UDim.new(0, 0),
				Bottom = UDim.new(0.1, 0),
				--Left = 72,
				Left   = UDim.new(0.12, 20),
				Right = UDim.new(0.1, 20),
			},
		},
		HeadingBanner = {
			ColorRole = "Base",
			-- Reuses Dracula's tilted ribbon banner asset until Arcade-specific
			-- banner art is exported.
			Image = "rbxassetid://102262056010998",
			ImageProps = {
				Size = UDim2.new(0.75, 0, 1, 15),
				Position = UDim2.new(0, 0, 0.1, 5),
				AnchorPoint = Vector2.new(0, 0.5),
				--Rotation = -2,
			},
			TextProps = {
				--Rotation = -2,
				Position = UDim2.new(0.05, 24, 0, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				TextXAlignment = Enum.TextXAlignment.Center,
			},
		},
		CloseButton = {
			ColorRole = "Error",
			Position = UDim2.fromScale(1, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			HideStroke = false,
			-- UI/Close Button colored from iconCatalog — red X with the spec's
			-- thick black outline; reused so the most common button in the
			-- system doesn't need a fresh upload.
			Image = "rbxassetid://90857209355154",
		},
		IconButton = { ColorRole = "Primary" },
		Badge = {
			ColorRole = "Error",
			Padding = {
				All = UDim.new(0, 6),
				Left = UDim.new(0, 12),
				Right = UDim.new(0, 12),
			},
		},
		Card = { ColorRole = "Base" },
		ProgressBar = { ColorRole = "Success" },
		Switch = { ColorRole = "Success" },
		Checkbox = { ColorRole = "Success" },
		Slider = { ColorRole = "Primary" },
		TextSwap = { ColorRole = "Primary" },
		Tabs = { ColorRole = "Primary" },
		TitleBar = { ColorRole = "BaseContent" },
		Avatar = { RingColorRole = "Primary", IndicatorColorRole = "Success" },
		IconText = { ColorRole = "BaseContent" },
		IconSwap = { ColorRole = "Primary" },
		HUD = {
			IconColorRole = "Warning",
			BackgroundColorRole = "Neutral",
			BackgroundTransparency = 0,
			IconSize = 48,
			IconOverhang = 8,
			IconGap = 12,
			-- Currency/Coin colored from iconCatalog — matches the spec's
			-- gold Currency Badge.
			IconImage = "rbxassetid://77506246542645",
		},
		XPBar = {
			ProgressColorRole = "Success",
			LabelColorRole = "BaseContent",
			BackgroundColorRole = "Neutral",
			BackgroundTransparency = 0,
			BarHeight = 14,
			LabelGap = 6,
		},
		LoadingScreen = {
			ProgressColorRole = "Success",
			TitleColorRole = "BaseContent",
			SubtextColorRole = "BaseContent",
			BackgroundColorRole = "Neutral",
			BackgroundImage = "rbxassetid://0", -- PLACEHOLDER: arcade loading bg
		},
		Toast = {
			BackgroundTransparency = 0.15,
			CornerRadius = UDim.new(0, 12),
			Padding = { Vertical = 12, Horizontal = 18 },
			IconSize = 36,
			DividerWidth = 2,
			DividerColor = Color3.new(1, 1, 1),
			DividerTransparency = 0.5,
			TextColorRole = "BaseContent",
			Severities = {
				Info = {
					Icon = "rbxassetid://108800013691143", -- UI/Info colored
					ColorRole = "Info",
					BackgroundColorRole = "Neutral",
				},
				Success = {
					Icon = "rbxassetid://140312201644821", -- UI/Checkmark Button colored
					ColorRole = "Success",
					BackgroundColorRole = "Neutral",
				},
				Warning = {
					Icon = "rbxassetid://73955615617298", -- UI/Warning colored
					ColorRole = "Warning",
					BackgroundColorRole = "Neutral",
				},
				Error = {
					Icon = "rbxassetid://90857209355154", -- UI/Close Button colored
					ColorRole = "Error",
					BackgroundColorRole = "Neutral",
				},
				Announcement = {
					Icon = "rbxassetid://127217150000578", -- UI/Exclamation Mark colored
					ColorRole = "Accent",
					BackgroundColorRole = "Neutral",
				},
			},
		},
		Button = {
			Default = {
				Image = "rbxassetid://131843670564796",
				TextColor3 = Color3.fromHex("#F8F8F2"),
				TextSize = 28,
			},

			Active = {
				Image = "rbxassetid://133268834191422",
				TextColor3 = Color3.fromHex("#2B1500"),
				TextSize = 28,
			},

			Secondary = {
				Image = "rbxassetid://116734983896964",
				TextColor3 = Color3.fromHex("#2B1500"),
				TextSize = 28,
			},

			Enabled = {
				Image = "rbxassetid://94094449272932",
				TextColor3 = Color3.fromHex("#062A12"),
				TextSize = 28,
			},

			Destructive = {
				Image = "rbxassetid://77182445055170",
				TextColor3 = Color3.fromHex("#FFFFFF"),
				TextSize = 28,
			},

			Ghost = {
				Image = "rbxassetid://100288907531640",
				TextColor3 = Color3.fromHex("#F8F8F2"),
				TextSize = 28,
			},
		},
		Scrollbar = { Color = Color3.fromHex("F5362D") },
		TextStroke = {
			Color = Color3.fromHex("#000000"),
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			LineJoinMode = Enum.LineJoinMode.Round,
			Transparency = 0,
			Thickness = function(size)
				return math.max(2, math.round(size / 10))
			end,
		},
	}

}

local SLOT_KEYS = {
	"Background", "Pane", "Widget", "HeadingBanner", "CloseButton",
	"IconButton", "Button", "Badge",
	"Card", "ProgressBar", "Switch", "Checkbox", "Slider",
	"TextSwap", "Tabs", "TitleBar",
	"Avatar", "IconText", "IconSwap", "HUD", "LoadingScreen",
	"XPBar",
	"Toast",
	"Scrollbar",
	"TextStroke",
}
local Themes = {}
for name, config in pairs(ThemeConfigs) do
	local theme = Themer.NewTheme(Fusion.scoped(Fusion), config)
	for _, key in ipairs(SLOT_KEYS) do
		theme[key] = config[key]
	end
	Themes[name] = theme
end

Themes.Lemonade = Themes.Studs -- Back-compat for old generated LocalScripts.

local GameTheme = Themes[_G.__THEME_NAME] or Themes.Studs

-- Auto-fallback wrapper: if no caller has explicitly established a theme,
-- Themer.Theme:now() returns OnyxUI's OnyxNightTheme (the contextual default).
-- In that case, run `callback` with GameTheme installed; otherwise respect
-- whatever theme the caller already set up.
--
-- Templates wrap their body in this so they can be rendered without a
-- builder having to do `Themer.Theme:is(...):during(...)` themselves.
local function WithGameTheme(callback)
	if Themer.Theme:now() == OnyxNightTheme then
		return Themer.Theme:is(GameTheme):during(callback)
	end
	return callback()
end

local deps = {
	Fusion = Fusion,
	Themer = Themer,
	Util = Util,
	ColorUtils = ColorUtils,
	CombineProps = CombineProps,
	Children = Children,
	peek = peek,
	Components = Components,
}

local SharedComponents = SharedComponentFactory(deps)

return {
	Themes = Themes,
	GameTheme = GameTheme,
	OnyxNightTheme = OnyxNightTheme,
	WithGameTheme = WithGameTheme,

	Pane = SharedComponents.Pane,
	ElevatedPane = SharedComponents.ElevatedPane,
	CloseButton = SharedComponents.CloseButton,
	HeadingBanner = SharedComponents.HeadingBanner,
	Widget = SharedComponents.Widget,
	Divider = SharedComponents.Divider,
	TextInput = SharedComponents.TextInput,
	Button = SharedComponents.Button,
	IconButton = SharedComponents.IconButton,
	Badge = SharedComponents.Badge,
	Card = SharedComponents.Card,
	ProgressBar = SharedComponents.ProgressBar,
	Switch = SharedComponents.Switch,
	Checkbox = SharedComponents.Checkbox,
	Slider = SharedComponents.Slider,
	TextArea = SharedComponents.TextArea,
	TextSwap = SharedComponents.TextSwap,
	Tabs = SharedComponents.Tabs,
	TitleBar = SharedComponents.TitleBar,
	Scroller = SharedComponents.Scroller,
	Avatar = SharedComponents.Avatar,
	Icon = SharedComponents.Icon,
	IconText = SharedComponents.IconText,
	IconSwap = SharedComponents.IconSwap,
	HUD = SharedComponents.HUD,
	LoadingScreen = SharedComponents.LoadingScreen,
	XPBar = SharedComponents.XPBar,
	Toast = SharedComponents.Toast,
	HoverSpinIcon = SharedComponents.HoverSpinIcon,

	Fusion = Fusion,
	Themer = Themer,
	Util = Util,
	ColorUtils = ColorUtils,
	CombineProps = CombineProps,
	Children = Children,
	peek = peek,

	Components = Components,
	OnyxUI = OnyxUI,
}
