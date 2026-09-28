-- The 🖌️ Paint Shop window: color swatches for your sword blades and your
-- armor, plus "Default" to go back to normal (PaintService).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local PaintData = require(Shared.PaintData)
local Remotes = require(Shared.Remotes)

local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local Paint = {}

local window: Frame
local swatches: { [string]: { [number]: TextButton } } = {}
local defaults: { [string]: TextButton } = {}

local function chosen(): { [string]: number }
	local raw = player:GetAttribute("Paint")
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, if type(raw) == "string" then raw else "{}")
	return if ok and type(decoded) == "table" then decoded else {}
end

local function refresh()
	local current = chosen()
	for slot, buttons in swatches do
		for index, button in buttons do
			local stroke = button:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Thickness = if current[slot] == index then 4 else 1.5
				stroke.Color = if current[slot] == index then Color3.new(1, 1, 1) else UI.Colors.Outline
			end
		end
		defaults[slot].BackgroundColor3 = if current[slot] == nil then UI.Colors.Good else UI.Colors.PanelLight
	end
end

function Paint.toggle()
	window.Visible = not window.Visible
	if window.Visible then
		refresh()
	end
end

function Paint.start()
	local screen = UI.screen("Paint", 7)
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
		UI.padding(14),
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(500, 560) }),
	})
	UI.label({
		Size = UDim2.new(1, -60, 0, 34),
		Text = "🖌️ Paint Shop",
		TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Spark,
		Parent = window,
	})
	UI.label({
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, 0, 0, 20),
		Text = "Free! Your team's color still shows on your armor's trim.",
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Muted,
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
	local list = UI.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 62),
		Size = UDim2.new(1, 0, 1, -62),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = window,
	}, { UI.list(8) })
	for order, slot in PaintData.Slots do
		UI.label({
			LayoutOrder = order * 3,
			Size = UDim2.new(1, -8, 0, 26),
			Text = slot.name,
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = list,
		})
		local grid = UI.new("Frame", {
			LayoutOrder = order * 3 + 1,
			Size = UDim2.new(1, -8, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = list,
		}, {
			UI.new("UIGridLayout", {
				CellSize = UDim2.fromOffset(52, 52),
				CellPadding = UDim2.fromOffset(8, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		swatches[slot.key] = {}
		for index, paint in PaintData.Colors do
			local button = UI.button({
				LayoutOrder = index,
				Text = "",
				BackgroundColor3 = paint.color,
				AutoButtonColor = true,
				Parent = grid,
			})
			button.Activated:Connect(function()
				Remotes.event("SetPaint"):FireServer(slot.key, index)
			end)
			swatches[slot.key][index] = button
		end
		defaults[slot.key] = UI.button({
			LayoutOrder = order * 3 + 2,
			Size = UDim2.new(1, -8, 0, 36),
			Text = "Default (no paint)",
			TextSize = 15,
			Parent = list,
		})
		defaults[slot.key].Activated:Connect(function()
			Remotes.event("SetPaint"):FireServer(slot.key, 0)
		end)
	end
	player:GetAttributeChangedSignal("Paint"):Connect(refresh)
	refresh()
end

return Paint
