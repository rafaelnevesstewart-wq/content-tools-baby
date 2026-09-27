-- Small helpers for building UI in code, plus the game's colors.

local Players = game:GetService("Players")

local UI = {}

UI.Font = Enum.Font.FredokaOne

UI.Colors = {
	Panel = Color3.fromRGB(26, 34, 70),
	PanelLight = Color3.fromRGB(44, 58, 110),
	Stroke = Color3.fromRGB(120, 170, 255),
	Text = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(185, 200, 235),
	Spark = Color3.fromRGB(255, 214, 70),
	Good = Color3.fromRGB(90, 215, 120),
	Bad = Color3.fromRGB(255, 105, 105),
	Warn = Color3.fromRGB(255, 165, 70),
	Rare = Color3.fromRGB(190, 110, 255),
	Robux = Color3.fromRGB(40, 190, 110),
}

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

function UI.button(props: { [string]: any }): TextButton
	local defaults = {
		AutoButtonColor = true,
		BackgroundColor3 = UI.Colors.PanelLight,
		Font = UI.Font,
		TextColor3 = UI.Colors.Text,
		TextSize = 18,
	}
	for key, value in props do
		defaults[key] = value
	end
	return UI.new("TextButton", defaults, { UI.corner(10), UI.stroke(Color3.fromRGB(10, 15, 35), 2) })
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
