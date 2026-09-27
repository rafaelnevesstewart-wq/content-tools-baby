-- Trading UI: the player list, the incoming-request pop-up and the trade window.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local StormData = require(Shared.StormData)

local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local Trade = {}

type StormInfo = { uid: string, id: string, mut: string?, stolen: boolean? }
type Side = { storms: { StormInfo }, sparks: number, ready: boolean }
type State = {
	partnerName: string,
	mine: Side,
	theirs: Side,
	inventory: { StormInfo },
	countdownEndsAt: number?,
}

local action = Remotes.event("TradeAction")

local menu: Frame
local menuList: ScrollingFrame
local popup: Frame
local popupText: TextLabel
local window: Frame
local titleLabel: TextLabel
local myOffer: TextLabel
local theirOffer: TextLabel
local valueLabel: TextLabel
local statusLabel: TextLabel
local inventoryGrid: ScrollingFrame
local sparksBox: TextBox
local readyButton: TextButton

local state: State? = nil
local pendingFrom: number? = nil

local function stormLine(info: StormInfo): string
	local mutation = StormData.getMutation(info.mut)
	return (if mutation then mutation.emoji .. " " else "") .. StormData.displayName(info)
end

local function sideText(side: Side): string
	local lines = {}
	for _, info in side.storms do
		local def = StormData.get(info.id)
		local rarity = if def then " (" .. StormData.rarityOf(def).name .. ")" else ""
		table.insert(lines, "🫙 " .. stormLine(info) .. rarity)
	end
	if side.sparks > 0 then
		table.insert(lines, "⚡ " .. Format.number(side.sparks) .. " Sparks")
	end
	if #lines == 0 then
		table.insert(lines, "(nothing yet)")
	end
	table.insert(lines, if side.ready then "✅ READY" else "⏳ not ready")
	return table.concat(lines, "\n")
end

local function income(side: Side): number
	local total = 0
	for _, info in side.storms do
		total += StormData.incomeOf(info)
	end
	return total
end

local function isOffered(uid: string): boolean
	if not state then
		return false
	end
	for _, info in state.mine.storms do
		if info.uid == uid then
			return true
		end
	end
	return false
end

local function sendStorms(uids: { string })
	action:FireServer("setStorms", uids)
end

local function toggleStorm(uid: string)
	local current = state
	if not current then
		return
	end
	local uids = {}
	local removed = false
	for _, info in current.mine.storms do
		if info.uid == uid then
			removed = true
		else
			table.insert(uids, info.uid)
		end
	end
	if not removed then
		if #uids >= Config.Trading.MaxStorms then
			return
		end
		table.insert(uids, uid)
	end
	sendStorms(uids)
end

local function rebuildInventory()
	for _, child in inventoryGrid:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	local current = state
	if not current then
		return
	end
	local list = table.clone(current.inventory)
	table.sort(list, function(a, b)
		return StormData.incomeOf(a) > StormData.incomeOf(b)
	end)
	for index, info in list do
		local offered = isOffered(info.uid)
		local def = StormData.get(info.id)
		local card = UI.button({
			LayoutOrder = index,
			Text = "",
			BackgroundColor3 = if offered then UI.Colors.Stroke else UI.Colors.PanelLight,
			Parent = inventoryGrid,
		})
		UI.label({
			Position = UDim2.fromOffset(4, 2),
			Size = UDim2.new(1, -8, 0.6, 0),
			Text = stormLine(info),
			TextScaled = true,
			TextColor3 = if def then StormData.rarityOf(def).color else UI.Colors.Text,
			Parent = card,
		})
		UI.label({
			Position = UDim2.new(0, 4, 0.62, 0),
			Size = UDim2.new(1, -8, 0.35, 0),
			Text = if info.stolen
				then "🚨 being stolen"
				else "+" .. Format.number(StormData.incomeOf(info)) .. " ⚡/s",
			TextSize = 14,
			TextColor3 = UI.Colors.Muted,
			Parent = card,
		})
		card.Activated:Connect(function()
			if not info.stolen then
				toggleStorm(info.uid)
			end
		end)
	end
end

local function refreshStatus()
	local current = state
	if not current then
		return
	end
	local countdown = current.countdownEndsAt
	if countdown then
		local left = math.max(0, math.ceil(countdown - workspace:GetServerTimeNow()))
		statusLabel.Text = "✅ Both ready! Trading in " .. left .. "... (change anything to stop)"
		statusLabel.TextColor3 = UI.Colors.Good
	elseif current.mine.ready then
		statusLabel.Text = "Waiting for " .. current.partnerName .. " to press Ready..."
		statusLabel.TextColor3 = UI.Colors.Muted
	else
		statusLabel.Text = "Pick up to " .. Config.Trading.MaxStorms .. " storms and/or Sparks, then press Ready."
		statusLabel.TextColor3 = UI.Colors.Muted
	end
end

local function render(newState: State?)
	state = newState
	if not newState then
		window.Visible = false
		return
	end
	window.Visible = true
	menu.Visible = false
	titleLabel.Text = "🤝 Trading with " .. newState.partnerName
	myOffer.Text = sideText(newState.mine)
	theirOffer.Text = sideText(newState.theirs)
	if not sparksBox:IsFocused() then
		sparksBox.Text = if newState.mine.sparks > 0 then tostring(newState.mine.sparks) else ""
	end

	local mineValue, theirValue = income(newState.mine), income(newState.theirs)
	local text = "You give +"
		.. Format.number(mineValue)
		.. " ⚡/s  ·  You get +"
		.. Format.number(theirValue)
		.. " ⚡/s"
	local ratio = Config.Trading.UnevenRatio
	if mineValue > 0 and theirValue * ratio < mineValue then
		text ..= "\n⚠️ You're giving a lot more than you get. Double-check!"
		valueLabel.TextColor3 = UI.Colors.Warn
	else
		valueLabel.TextColor3 = UI.Colors.Muted
	end
	valueLabel.Text = text

	readyButton.Text = if newState.mine.ready then "❌ Not ready" else "✅ Ready"
	readyButton.BackgroundColor3 = if newState.mine.ready then UI.Colors.Warn else UI.Colors.Good
	rebuildInventory()
	refreshStatus()
end

function Trade.openMenu()
	if state then
		window.Visible = true
		return
	end
	for _, child in menuList:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	local others = 0
	for index, other in Players:GetPlayers() do
		if other ~= player then
			others += 1
			local button = UI.button({
				LayoutOrder = index,
				Size = UDim2.new(1, -8, 0, 44),
				Text = "🤝 " .. other.DisplayName,
				TextSize = 20,
				Parent = menuList,
			})
			button.Activated:Connect(function()
				action:FireServer("request", other.UserId)
				menu.Visible = false
			end)
		end
	end
	if others == 0 then
		UI.button({
			Size = UDim2.new(1, -8, 0, 44),
			Text = "Nobody else is here yet!",
			TextSize = 18,
			AutoButtonColor = false,
			Parent = menuList,
		})
	end
	menu.Visible = not menu.Visible
end

local function panel(screen: Instance, name: string, maxSize: Vector2, stroke: Color3): Frame
	return UI.new("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.92, 0.85),
		BackgroundColor3 = UI.Colors.Panel,
		Visible = false,
		Parent = screen,
	}, { UI.corner(18), UI.stroke(stroke, 3), UI.padding(14), UI.new("UISizeConstraint", { MaxSize = maxSize }) })
end

local function closeButton(parent: Instance, onClick: () -> ())
	local button = UI.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(44, 36),
		Text = "✕",
		TextSize = 22,
		BackgroundColor3 = UI.Colors.Bad,
		Parent = parent,
	})
	button.Activated:Connect(onClick)
end

local function buildMenu(screen: Instance)
	menu = panel(screen, "TradeMenu", Vector2.new(360, 420), UI.Colors.Stroke)
	UI.label({
		Size = UDim2.new(1, -50, 0, 36),
		Text = "🤝 Trade with...",
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = menu,
	})
	closeButton(menu, function()
		menu.Visible = false
	end)
	menuList = UI.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 46),
		Size = UDim2.new(1, 0, 1, -46),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = menu,
	}, { UI.list(6) })
end

local function buildPopup(screen: Instance)
	popup = UI.new("Frame", {
		Name = "TradeRequest",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 170),
		Size = UDim2.fromOffset(340, 110),
		BackgroundColor3 = UI.Colors.Panel,
		Visible = false,
		Parent = screen,
	}, { UI.corner(14), UI.stroke(UI.Colors.Good, 3), UI.padding(10) })
	popupText = UI.label({ Size = UDim2.new(1, 0, 0, 44), TextSize = 20, TextWrapped = true, Parent = popup })
	for index, choice in { { "✅ Accept", UI.Colors.Good, true }, { "❌ Decline", UI.Colors.Bad, false } } do
		local button = UI.button({
			Position = UDim2.new(if index == 1 then 0 else 0.52, 0, 0, 50),
			Size = UDim2.new(0.48, 0, 0, 40),
			Text = choice[1] :: string,
			BackgroundColor3 = choice[2] :: Color3,
			Parent = popup,
		})
		button.Activated:Connect(function()
			if pendingFrom then
				action:FireServer("respond", pendingFrom, choice[3])
			end
			pendingFrom = nil
			popup.Visible = false
		end)
	end
end

local function buildWindow(screen: Instance)
	window = panel(screen, "TradeWindow", Vector2.new(680, 580), UI.Colors.Good)
	titleLabel = UI.label({
		Size = UDim2.new(1, -60, 0, 34),
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = window,
	})
	closeButton(window, function()
		action:FireServer("cancel")
	end)

	local function offerBox(x: number, heading: string): TextLabel
		local box = UI.new("Frame", {
			Position = UDim2.new(x, 0, 0, 42),
			Size = UDim2.new(0.49, 0, 0, 150),
			BackgroundColor3 = UI.Colors.PanelLight,
			Parent = window,
		}, { UI.corner(12), UI.padding(8) })
		UI.label({
			Size = UDim2.new(1, 0, 0, 22),
			Text = heading,
			TextSize = 18,
			TextColor3 = UI.Colors.Spark,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = box,
		})
		return UI.label({
			Position = UDim2.fromOffset(0, 26),
			Size = UDim2.new(1, 0, 1, -26),
			TextSize = 15,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Parent = box,
		})
	end
	myOffer = offerBox(0, "You give")
	theirOffer = offerBox(0.51, "You get")

	valueLabel = UI.label({
		Position = UDim2.fromOffset(0, 198),
		Size = UDim2.new(1, 0, 0, 38),
		TextSize = 15,
		TextWrapped = true,
		Parent = window,
	})

	UI.label({
		Position = UDim2.fromOffset(0, 240),
		Size = UDim2.new(0.5, 0, 0, 30),
		Text = "Add Sparks:",
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = window,
	})
	sparksBox = UI.new("TextBox", {
		Position = UDim2.new(0.25, 0, 0, 240),
		Size = UDim2.new(0.3, 0, 0, 30),
		BackgroundColor3 = Color3.fromRGB(18, 24, 50),
		TextColor3 = UI.Colors.Spark,
		PlaceholderText = "0",
		Font = UI.Font,
		TextSize = 18,
		ClearTextOnFocus = false,
		Parent = window,
	}, { UI.corner(8) })
	sparksBox.FocusLost:Connect(function()
		local amount = tonumber(sparksBox.Text) or 0
		action:FireServer("setSparks", amount)
	end)

	readyButton = UI.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 236),
		Size = UDim2.new(0.4, 0, 0, 40),
		TextSize = 20,
		Parent = window,
	})
	readyButton.Activated:Connect(function()
		if state then
			action:FireServer("ready", not state.mine.ready)
		end
	end)

	statusLabel = UI.label({
		Position = UDim2.fromOffset(0, 282),
		Size = UDim2.new(1, 0, 0, 22),
		TextSize = 16,
		TextWrapped = true,
		Parent = window,
	})

	UI.label({
		Position = UDim2.fromOffset(0, 308),
		Size = UDim2.new(1, 0, 0, 20),
		Text = "Your storms (tap to add or remove):",
		TextSize = 15,
		TextColor3 = UI.Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = window,
	})
	inventoryGrid = UI.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 332),
		Size = UDim2.new(1, 0, 1, -332),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = window,
	}, {
		UI.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(150, 56),
			CellPadding = UDim2.fromOffset(6, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
end

function Trade.start()
	local screen = UI.screen("Trade", 7)
	buildMenu(screen)
	buildPopup(screen)
	buildWindow(screen)

	Remotes.event("TradeRequest").OnClientEvent:Connect(function(fromUserId, fromName)
		pendingFrom = fromUserId
		popupText.Text = "🤝 " .. tostring(fromName) .. " wants to trade!"
		popup.Visible = true
		task.delay(Config.Trading.RequestSeconds, function()
			if pendingFrom == fromUserId then
				pendingFrom = nil
				popup.Visible = false
			end
		end)
	end)
	Remotes.event("TradeUpdate").OnClientEvent:Connect(render)

	task.spawn(function()
		while true do
			task.wait(0.25)
			if state and window.Visible then
				refreshStatus()
			end
		end
	end)
end

return Trade
