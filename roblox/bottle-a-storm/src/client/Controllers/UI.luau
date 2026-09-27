-- Small helpers for building UI in code, plus the game's colors: a cute
-- pastel "candy" theme with light panels, dark purple text and chunky
-- outlines. Buttons use white text with an outline so they read on any color.

local Players = game:GetService("Players")

local Sfx = require(script.Parent.Sfx)

local UI = {}

UI.Font = Enum.Font.FredokaOne

UI.Colors = {
	Panel = Color3.fromRGB(255, 248, 252), -- window background (cream pink)
	PanelLight = Color3.fromRGB(232, 222, 255), -- cards and plain buttons (lilac)
	Stroke = Color3.fromRGB(165, 130, 240), -- window borders and selected things
	Outline = Color3.fromRGB(95, 65, 160), -- chunky button outline and text outline
	Text = Color3.fromRGB(75, 50, 115), -- dark purple, for text on light panels
	Muted = Color3.fromRGB(145, 125, 175),
	Spark = Color3.fromRGB(240, 165, 25), -- warm gold, readable on light panels
	Good = Color3.fromRGB(95, 205, 135), -- mint
	Bad = Color3.fromRGB(245, 110, 135), -- strawberry
	Warn = Color3.fromRGB(250, 160, 80), -- peach
	Rare = Color3.fromRGB(180, 115, 250), -- grape
	Robux = Color3.fromRGB(70, 195, 125),
	Disabled = Color3.fromRGB(222, 216, 234), -- greyed-out buttons
	Track = Color3.fromRGB(236, 228, 248), -- empty part of bars, text boxes
}

-- Makes a (possibly very light) color dark enough to read on a light panel.
function UI.ink(color: Color3): Color3
	local h, sat, v = color:ToHSV()
	if v > 0.72 or sat < 0.25 then
		return Color3.fromHSV(h, math.max(sat, 0.45), math.min(v, 0.62))
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

-- A rounded candy button with a chunky outline. It plays a click sound.
function UI.button(props: { [string]: any }): TextButton
	local defaults = {
		AutoButtonColor = true,
		BackgroundColor3 = UI.Colors.PanelLight,
		Font = UI.Font,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeColor3 = UI.Colors.Outline,
		TextStrokeTransparency = 0.2,
		TextSize = 18,
	}
	for key, value in props do
		defaults[key] = value
	end
	local button = UI.new("TextButton", defaults, { UI.corner(14), UI.stroke(UI.Colors.Outline, 2.5) })
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

-- The island model owned by the local player, if any.
function UI.myPlot(): Model?
	local world = workspace:FindFirstChild("World")
	local plots = world and world:FindFirstChild("Plots")
	if not plots then
		return nil
	end
	for _, plot in plots:GetChildren() do
		if plot:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId then
			return plot :: Model
		end
	end
	return nil
end

return UI
