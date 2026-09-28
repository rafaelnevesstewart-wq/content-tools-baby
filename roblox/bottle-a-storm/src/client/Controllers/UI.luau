-- Small helpers for building UI in code, plus the game's colors: a sleek,
-- dark "glass" theme with bright accents and a clean font. Buttons use white
-- text so they read on any accent color.

local Players = game:GetService("Players")

local Sfx = require(script.Parent.Sfx)

local UI = {}

UI.Font = Enum.Font.GothamBold

UI.Colors = {
	Panel = Color3.fromRGB(22, 26, 36), -- window background (deep slate)
	PanelLight = Color3.fromRGB(40, 46, 62), -- cards and plain buttons
	Stroke = Color3.fromRGB(96, 122, 172), -- window borders and selected things
	Outline = Color3.fromRGB(10, 12, 18), -- thin button outline and text outline
	Text = Color3.fromRGB(236, 240, 248), -- light text for dark panels
	Muted = Color3.fromRGB(150, 160, 182),
	Spark = Color3.fromRGB(255, 196, 64), -- warm gold
	Good = Color3.fromRGB(52, 168, 108), -- green
	Bad = Color3.fromRGB(206, 64, 78), -- red
	Warn = Color3.fromRGB(222, 136, 46), -- orange
	Rare = Color3.fromRGB(132, 92, 226), -- purple
	Robux = Color3.fromRGB(36, 156, 92),
	Disabled = Color3.fromRGB(58, 62, 76), -- greyed-out buttons
	Track = Color3.fromRGB(32, 36, 48), -- empty part of bars, text boxes
}

-- Makes a (possibly very dark) color bright enough to read on a dark panel.
function UI.ink(color: Color3): Color3
	local h, sat, v = color:ToHSV()
	if v < 0.8 then
		return Color3.fromHSV(h, math.min(sat, 0.7), 0.92)
	end
	return color
end

-- UI.new("TextLabel", { Text = "hi", Parent = frame }, { UI.corner(8) })
function UI.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent = nil
	local properties: { [string]: any } = props or {}
	local childList: { Instance } = children or {}
	for key, value in properties do
		if key == "Parent" then
			parent = value
		else
			(instance :: any)[key] = value
		end
	end
	for _, child in childList do
		child.Parent = instance
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function UI.corner(radius: number): UICorner
	return UI.new("UICorner", { CornerRadius = UDim.new(0, radius) })
end

function UI.stroke(color: Color3, thickness: number): UIStroke
	return UI.new("UIStroke", {
		Color = color,
		Thickness = thickness,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UI.padding(pixels: number): UIPadding
	local p = UDim.new(0, pixels)
	return UI.new("UIPadding", { PaddingTop = p, PaddingBottom = p, PaddingLeft = p, PaddingRight = p })
end

function UI.list(padding: number, direction: Enum.FillDirection?, align: Enum.HorizontalAlignment?): UIListLayout
	return UI.new("UIListLayout", {
		Padding = UDim.new(0, padding),
		FillDirection = direction or Enum.FillDirection.Vertical,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

function UI.label(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		Font = UI.Font,
		TextColor3 = UI.Colors.Text,
		TextSize = 18,
	}
	for key, value in props do
		defaults[key] = value
	end
	return UI.new("TextLabel", defaults)
end

-- A rounded button with a thin outline. It plays a click sound.
function UI.button(props: { [string]: any }): TextButton
	local defaults = {
		AutoButtonColor = true,
		BackgroundColor3 = UI.Colors.PanelLight,
		Font = UI.Font,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeColor3 = UI.Colors.Outline,
		TextStrokeTransparency = 0.6,
		TextSize = 18,
	}
	for key, value in props do
		defaults[key] = value
	end
	local button = UI.new("TextButton", defaults, { UI.corner(10), UI.stroke(UI.Colors.Outline, 1.5) })
	button.Activated:Connect(function()
		Sfx.play("click")
	end)
	return button
end

function UI.screen(name: string, displayOrder: number?): ScreenGui
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	return UI.new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = displayOrder or 0,
		Parent = playerGui,
	})
end

-- The stack of small status chips on the right, just above the kill feed
-- (contest, guide step, weekly event, match clock). It grows upward and
-- hidden chips take no room. Give each chip a LayoutOrder (higher = lower).
local sideStack: Frame? = nil
function UI.sideStack(): Frame
	if not sideStack then
		local screen = UI.screen("SideChips", 2)
		sideStack = UI.new("Frame", {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -12, 0.3, -8),
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			Parent = screen,
		}, {
			UI.new("UIListLayout", {
				Padding = UDim.new(0, 4),
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				VerticalAlignment = Enum.VerticalAlignment.Bottom,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
	end
	return sideStack :: Frame
end

return UI
