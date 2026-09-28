-- The 🤝 Trade window (TradeService): your offer and theirs side by side,
-- your kits and cosmetics to add, a Sparks box, and Ready → Confirm. Start a
-- trade from 👥 Party; requests pop up at the bottom of the screen.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local UI = require(script.Parent.UI)

local Trade = {}

local screen: ScreenGui
local window: Frame
local title: TextLabel
local mineList: ScrollingFrame
local theirsList: ScrollingFrame
local inventoryList: ScrollingFrame
local sparksBox: TextBox
local readyButton: TextButton
local confirmButton: TextButton
local state: any = nil
local inventory: any = nil

local function send(action: string, a: any?, b: any?)
	Remotes.event("TradeAction"):FireServer(action, a, b)
end

-- Starts a trade with someone (the Party window calls this).
function Trade.request(userId: number)
	send("request", userId)
end

local function fill(list: ScrollingFrame, lines: { string })
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	if #lines == 0 then
		UI.label({
			Size = UDim2.new(1, -6, 0, 24),
			Text = "(nothing yet)",
			TextSize = 14,
			TextColor3 = UI.Colors.Muted,
			Parent = list,
		})
	end
	for index, line in lines do
		UI.label({
			LayoutOrder = index,
			Size = UDim2.new(1, -6, 0, 24),
			Text = line,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = list,
		})
	end
end

local function column(x: number, heading: string): ScrollingFrame
	UI.label({
		Position = UDim2.new(x, 0, 0, 44),
		Size = UDim2.new(0.5, -6, 0, 22),
		Text = heading,
		TextSize = 16,
		TextColor3 = UI.Colors.Spark,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = window,
	})
	return UI.new("ScrollingFrame", {
		Position = UDim2.new(x, 0, 0, 68),
		Size = UDim2.new(0.5, -6, 0.3, 0),
		BackgroundColor3 = UI.Colors.PanelLight,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = window,
	}, { UI.corner(10), UI.padding(6), UI.list(2) })
end

local function buildInventory()
	for _, child in inventoryList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	if type(inventory) ~= "table" or not state then
		return
	end
	local raw = state.mineRaw or { kits = {}, cosmetics = {} }
	local order = 0
	local function row(text: string, offered: boolean, onClick: () -> ())
		order += 1
		local frame = UI.new("Frame", {
			LayoutOrder = order,
			Size = UDim2.new(1, -6, 0, 34),
			BackgroundTransparency = 1,
			Parent = inventoryList,
		})
		UI.label({
			Size = UDim2.new(1, -90, 1, 0),
			Text = text,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = frame,
		})
		UI.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(84, 28),
			Text = if offered then "Take out" else "Add",
			TextSize = 14,
			BackgroundColor3 = if offered then UI.Colors.Bad else UI.Colors.Good,
			Parent = frame,
		}).Activated
			:Connect(onClick)
	end
	for _, kit in inventory.kits do
		local offered = table.find(raw.kits, kit.uid) ~= nil
		row("🌪️ " .. kit.name .. " (" .. kit.rarityName .. ")", offered, function()
			send(if offered then "remove" else "add", "kit", kit.uid)
		end)
	end
	for _, item in inventory.cosmetics do
		local offered = table.find(raw.cosmetics, item.id) ~= nil
		row(item.emoji .. " " .. item.name, offered, function()
			send(if offered then "remove" else "add", "cosmetic", item.id)
		end)
	end
end

local function refreshInventory()
	task.spawn(function()
		local ok, result = pcall(function()
			return Remotes.func("GetTradeInventory"):InvokeServer()
		end)
		inventory = if ok then result else nil
		buildInventory()
	end)
end

local function render()
	if not state then
		return
	end
	title.Text = "🤝 Trading with " .. tostring(state.partner)
	fill(mineList, state.mine or {})
	fill(theirsList, state.theirs or {})
	readyButton.Text = if state.readyMine then "✅ Ready (click to undo)" else "Ready"
	readyButton.BackgroundColor3 = if state.readyMine then UI.Colors.Good else UI.Colors.PanelLight
	local bothReady = state.readyMine and state.readyTheirs
	confirmButton.Text = if state.confirmMine
		then "Waiting for them..."
		elseif bothReady then "🤝 Confirm trade"
		elseif state.readyTheirs then "They're ready!"
		else "Both must be Ready"
	confirmButton.BackgroundColor3 = if bothReady and not state.confirmMine then UI.Colors.Spark else UI.Colors.Disabled
	buildInventory()
end

local function showRequest(fromUserId: number, fromName: string)
	local card = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -380),
		Size = UDim2.fromOffset(360, 96),
		BackgroundColor3 = UI.Colors.Panel,
		Parent = screen,
	}, { UI.corner(14), UI.stroke(UI.Colors.Spark, 3), UI.padding(10) })
	UI.label({
		Size = UDim2.new(1, 0, 0, 30),
		Text = "🤝 " .. fromName .. " wants to trade with you!",
		TextSize = 16,
		TextWrapped = true,
		Parent = card,
	})
	UI.button({
		Position = UDim2.new(0, 0, 1, -38),
		Size = UDim2.new(0.5, -4, 0, 38),
		Text = "Trade",
		BackgroundColor3 = UI.Colors.Good,
		Parent = card,
	}).Activated
		:Connect(function()
			card:Destroy()
			send("accept", fromUserId)
		end)
	UI.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 1, -38),
		Size = UDim2.new(0.5, -4, 0, 38),
		Text = "No thanks",
		BackgroundColor3 = UI.Colors.Bad,
		Parent = card,
	}).Activated
		:Connect(function()
			card:Destroy()
			send("decline", fromUserId)
		end)
	task.delay(Config.Trade.RequestSeconds, function()
		if card.Parent then
			card:Destroy()
		end
	end)
end

function Trade.start()
	screen = UI.screen("Trade", 8)
	window = UI.new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.92, 0, 0.88, 0),
		BackgroundColor3 = UI.Colors.Panel,
		Visible = false,
		Parent = screen,
	}, {
		UI.corner(18),
		UI.stroke(UI.Colors.Stroke, 3),
		UI.padding(12),
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(620, 640) }),
	})
	title = UI.label({
		Size = UDim2.new(1, -60, 0, 34),
		Text = "🤝 Trade",
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
			send("cancel")
		end)
	mineList = column(0, "You give")
	theirsList = column(0.5, "You get")

	UI.label({
		Position = UDim2.new(0, 0, 0.3, 74),
		Size = UDim2.new(1, 0, 0, 22),
		Text = "Your kits and cosmetics (Robux cosmetics can't be traded)",
		TextSize = 14,
		TextColor3 = UI.Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = window,
	})
	inventoryList = UI.new("ScrollingFrame", {
		Position = UDim2.new(0, 0, 0.3, 98),
		Size = UDim2.new(1, 0, 0.7, -206),
		BackgroundColor3 = UI.Colors.PanelLight,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = window,
	}, { UI.corner(10), UI.padding(6), UI.list(2) })

	local bottom = UI.new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 96),
		BackgroundTransparency = 1,
		Parent = window,
	})
	sparksBox = UI.new("TextBox", {
		Size = UDim2.new(0.5, -6, 0, 40),
		BackgroundColor3 = UI.Colors.Track,
		PlaceholderText = "⚡ Sparks to give",
		PlaceholderColor3 = UI.Colors.Muted,
		Text = "",
		TextColor3 = UI.Colors.Text,
		Font = UI.Font,
		TextSize = 16,
		ClearTextOnFocus = false,
		Parent = bottom,
	}, { UI.corner(10), UI.padding(6) })
	UI.button({
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.new(0.5, 0, 0, 40),
		Text = "Set Sparks",
		TextSize = 16,
		Parent = bottom,
	}).Activated
		:Connect(function()
			send("sparks", tonumber(sparksBox.Text) or 0)
		end)
	readyButton = UI.button({
		Position = UDim2.new(0, 0, 0, 48),
		Size = UDim2.new(0.5, -6, 0, 44),
		Text = "Ready",
		TextSize = 17,
		Parent = bottom,
	})
	readyButton.Activated:Connect(function()
		send("ready")
	end)
	confirmButton = UI.button({
		Position = UDim2.new(0.5, 0, 0, 48),
		Size = UDim2.new(0.5, 0, 0, 44),
		Text = "Confirm",
		TextSize = 17,
		Parent = bottom,
	})
	confirmButton.Activated:Connect(function()
		if state and state.readyMine and state.readyTheirs then
			send("confirm")
		end
	end)

	Remotes.event("TradeInvite").OnClientEvent:Connect(function(fromUserId, fromName)
		if type(fromUserId) == "number" and type(fromName) == "string" then
			showRequest(fromUserId, fromName)
		end
	end)
	Remotes.event("TradeUpdate").OnClientEvent:Connect(function(newState)
		if type(newState) ~= "table" then
			return
		end
		if newState.open then
			local opening = not window.Visible
			state = newState
			window.Visible = true
			if opening then
				sparksBox.Text = ""
				refreshInventory()
			end
			render()
		else
			state = nil
			window.Visible = false
			inventory = nil
		end
	end)
end

return Trade
