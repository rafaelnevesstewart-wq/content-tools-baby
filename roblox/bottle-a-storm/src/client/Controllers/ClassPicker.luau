-- The 🧙 Class window: four cards (Knight, Archer, Builder, Healer) with what
-- each does; tap one to play it next match (ClassService). Opened from the
-- 🧙 button next to the mode vote.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local ClassData = require(Shared.ClassData)
local Remotes = require(Shared.Remotes)

local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local ClassPicker = {}

local window: Frame
local cards: { [string]: TextButton } = {}

local function refresh()
	local current = player:GetAttribute("Class")
	for key, card in cards do
		card.BackgroundColor3 = if key == current then UI.Colors.Good else UI.Colors.PanelLight
	end
end

function ClassPicker.toggle()
	window.Visible = not window.Visible
	refresh()
end

-- "🛡️ Knight" (your class) for the button in the vote row.
function ClassPicker.label(): string
	local class = ClassData.get(player:GetAttribute("Class") :: string?)
	return if class then class.emoji .. " " .. class.name else "🧙 Class"
end

function ClassPicker.start()
	local screen = UI.screen("ClassPicker", 8)
	window = UI.new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.9, 0, 0.8, 0),
		BackgroundColor3 = UI.Colors.Panel,
		Visible = false,
		Parent = screen,
	}, {
		UI.corner(18),
		UI.stroke(UI.Colors.Stroke, 3),
		UI.padding(12),
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(560, 480) }),
	})
	UI.label({
		Size = UDim2.new(1, -60, 0, 34),
		Text = "🧙 Pick your class",
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Spark,
		Parent = window,
	})
	UI.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(44, 40),
		Text = "✕",
		TextSize = 22,
		BackgroundColor3 = UI.Colors.Bad,
		Parent = window,
	}).Activated
		:Connect(function()
			window.Visible = false
		end)
	local grid = UI.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 1, -44),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = window,
	}, {
		UI.new("UIGridLayout", {
			CellSize = UDim2.new(0.5, -6, 0, 170),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for order, class in ClassData.List do
		local card = UI.button({
			LayoutOrder = order,
			Text = "",
			Parent = grid,
		})
		UI.label({
			Size = UDim2.new(1, 0, 0, 44),
			Text = class.emoji,
			TextSize = 36,
			Parent = card,
		})
		UI.label({
			Position = UDim2.fromOffset(0, 44),
			Size = UDim2.new(1, 0, 0, 24),
			Text = class.name,
			TextSize = 20,
			Parent = card,
		})
		UI.label({
			Position = UDim2.fromOffset(8, 70),
			Size = UDim2.new(1, -16, 1, -76),
			Text = class.description,
			TextSize = 13,
			TextWrapped = true,
			TextColor3 = UI.Colors.Text,
			TextYAlignment = Enum.TextYAlignment.Top,
			Parent = card,
		})
		card.Activated:Connect(function()
			Remotes.event("PickClass"):FireServer(class.key)
		end)
		cards[class.key] = card
	end
	player:GetAttributeChangedSignal("Class"):Connect(refresh)
	refresh()
end

return ClassPicker
