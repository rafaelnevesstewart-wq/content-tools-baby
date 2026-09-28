-- The 📖 Fish Book: every fish in the pond (FishData), with how many you've
-- caught and your heaviest. Fish you haven't caught yet show as ❓. Open it
-- at the stand by the fishing pond on Games Island.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local FishData = require(Shared.FishData)
local Remotes = require(Shared.Remotes)

local UI = require(script.Parent.UI)

local FishBook = {}

local window: Frame
local grid: ScrollingFrame
local summary: TextLabel

local function fill()
	for _, child in grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local ok, book = pcall(function()
		return Remotes.func("GetFish"):InvokeServer()
	end)
	if not ok or type(book) ~= "table" then
		return
	end
	local found = 0
	for index, fish in FishData.List do
		local count = book.caught[fish.id] or 0
		if count > 0 then
			found += 1
		end
		local card = UI.new("Frame", {
			LayoutOrder = index,
			BackgroundColor3 = UI.Colors.PanelLight,
			Parent = grid,
		}, { UI.corner(10), UI.padding(6), UI.stroke(FishData.Rarities[fish.rarity], 2) })
		UI.label({
			Size = UDim2.new(1, 0, 0, 40),
			Text = if count > 0 then fish.emoji else "❓",
			TextSize = 34,
			Parent = card,
		})
		UI.label({
			Position = UDim2.fromOffset(0, 42),
			Size = UDim2.new(1, 0, 0, 18),
			Text = if count > 0 then fish.name else "???",
			TextSize = 13,
			TextScaled = true,
			Parent = card,
		})
		UI.label({
			Position = UDim2.fromOffset(0, 60),
			Size = UDim2.new(1, 0, 0, 16),
			Text = fish.rarity,
			TextSize = 12,
			TextColor3 = FishData.Rarities[fish.rarity],
			Parent = card,
		})
		UI.label({
			Position = UDim2.fromOffset(0, 76),
			Size = UDim2.new(1, 0, 0, 16),
			Text = if count > 0 then "x" .. count .. " · best " .. tostring(book.best[fish.id] or 0) .. " kg" else "",
			TextSize = 12,
			TextColor3 = UI.Colors.Muted,
			Parent = card,
		})
	end
	summary.Text = "Found " .. found .. " of " .. #FishData.List .. " fish"
end

function FishBook.toggle()
	window.Visible = not window.Visible
	if window.Visible then
		fill()
	end
end

function FishBook.start()
	local screen = UI.screen("FishBook", 8)
	window = UI.new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.9, 0, 0.82, 0),
		BackgroundColor3 = UI.Colors.Panel,
		Visible = false,
		Parent = screen,
	}, {
		UI.corner(18),
		UI.stroke(UI.Colors.Stroke, 3),
		UI.padding(12),
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(620, 560) }),
	})
	UI.label({
		Size = UDim2.new(1, -60, 0, 34),
		Text = "📖 Fish Book",
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
	summary = UI.label({
		Position = UDim2.fromOffset(0, 38),
		Size = UDim2.new(1, 0, 0, 22),
		Text = "",
		TextSize = 15,
		TextColor3 = UI.Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = window,
	})
	grid = UI.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 64),
		Size = UDim2.new(1, 0, 1, -64),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = window,
	}, {
		UI.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(112, 100),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
end

return FishBook
