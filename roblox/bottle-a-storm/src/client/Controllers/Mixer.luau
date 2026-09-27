-- The Storm Mixer window. Opens from the cauldron on your island. Pick two
-- storms, see the fee and (if you've found the recipe) what you'll get, then
-- mix. The recipe book lists the recipes you've discovered.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local StormData = require(Shared.StormData)

local Toasts = require(script.Parent.Toasts)
local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local Mixer = {}

type StormInfo = { uid: string, id: string, mut: string?, slot: number, stolen: boolean }
type Recipe = { a: string, b: string, result: string }

local window: Frame
local grid: ScrollingFrame
local slotA: TextLabel
local slotB: TextLabel
local resultLabel: TextLabel
local mixButton: TextButton
local bookLabel: TextLabel

local storms: { StormInfo } = {}
local found: { Recipe } = {}
local selected: { StormInfo } = {}
local busy = false

local function stormText(info: StormInfo): string
	local mutation = StormData.getMutation(info.mut)
	return (if mutation then mutation.emoji .. " " else "") .. StormData.displayName(info)
end

local function rarityColor(id: string): Color3
	local def = StormData.get(id)
	return if def then UI.ink(StormData.rarityOf(def).color) else UI.Colors.Muted
end

local function nameOf(id: string): string
	local def = StormData.get(id)
	return if def then def.name else id
end

local function knownResult(a: string, b: string): string?
	for _, recipe in found do
		if (recipe.a == a and recipe.b == b) or (recipe.a == b and recipe.b == a) then
			return recipe.result
		end
	end
	return nil
end

local function fee(): number
	local a, b = selected[1], selected[2]
	if not a or not b then
		return 0
	end
	local total = (StormData.incomeOf(a) + StormData.incomeOf(b)) * Config.Mixing.FeeSeconds
	return math.max(Config.Mixing.MinFee, math.floor(total))
end

local function refreshSelection()
	local a, b = selected[1], selected[2]
	for index, slotLabel in { slotA, slotB } do
		local info = selected[index]
		slotLabel.Text = if info then stormText(info) else "Pick a storm"
		slotLabel.TextColor3 = if info then rarityColor(info.id) else UI.Colors.Muted
	end
	if a and b then
		local result = knownResult(a.id, b.id)
		resultLabel.Text = if result then nameOf(result) else "❓ Unknown mix"
		resultLabel.TextColor3 = if result then rarityColor(result) else UI.Colors.Muted
		local cost = fee()
		mixButton.Text = "🧪 Mix  ⚡" .. Format.number(cost)
		local canPay = (player:GetAttribute("Sparks") or 0) >= cost
		mixButton.BackgroundColor3 = if canPay and not busy then UI.Colors.Rare else UI.Colors.Disabled
	else
		resultLabel.Text = "?"
		resultLabel.TextColor3 = UI.Colors.Muted
		mixButton.Text = "🧪 Mix"
		mixButton.BackgroundColor3 = UI.Colors.Disabled
	end
end

local function toggle(info: StormInfo)
	for index, chosen in selected do
		if chosen.uid == info.uid then
			table.remove(selected, index)
			return
		end
	end
	if #selected >= 2 then
		selected[2] = info
	else
		table.insert(selected, info)
	end
end

local function rebuildGrid()
	for _, child in grid:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	table.sort(storms, function(x, y)
		return StormData.incomeOf(x) > StormData.incomeOf(y)
	end)
	for index, info in storms do
		local isSelected = false
		for _, chosen in selected do
			if chosen.uid == info.uid then
				isSelected = true
			end
		end
		local card = UI.button({
			LayoutOrder = index,
			Text = "",
			BackgroundColor3 = if isSelected then UI.Colors.Stroke else UI.Colors.PanelLight,
			AutoButtonColor = not info.stolen,
			Parent = grid,
		})
		UI.label({
			Size = UDim2.new(1, -8, 0.6, 0),
			Position = UDim2.fromOffset(4, 2),
			Text = stormText(info),
			TextScaled = true,
			TextColor3 = rarityColor(info.id),
			Parent = card,
		})
		UI.label({
			Size = UDim2.new(1, -8, 0.35, 0),
			Position = UDim2.new(0, 4, 0.62, 0),
			Text = if info.stolen
				then "🚨 being stolen"
				else "+" .. Format.number(StormData.incomeOf(info)) .. " ⚡/s",
			TextSize = 14,
			TextColor3 = UI.Colors.Muted,
			Parent = card,
		})
		card.Activated:Connect(function()
			if info.stolen or busy then
				return
			end
			toggle(info)
			rebuildGrid()
			refreshSelection()
		end)
	end
end

local function refreshBook(total: number)
	local lines = { "📖 Recipes found: " .. #found .. "/" .. total }
	for _, recipe in found do
		table.insert(lines, nameOf(recipe.a) .. " + " .. nameOf(recipe.b) .. " = " .. nameOf(recipe.result))
	end
	if #found < total then
		table.insert(lines, "??? + ??? = ???  (keep experimenting!)")
	end
	bookLabel.Text = table.concat(lines, "\n")
end

local function load()
	local info = Remotes.func("GetMixer"):InvokeServer()
	if type(info) ~= "table" then
		return
	end
	storms = info.storms
	found = info.found
	-- Drop selections for storms you no longer have.
	local still = {}
	for _, chosen in selected do
		for _, storm in storms do
			if storm.uid == chosen.uid and not storm.stolen then
				table.insert(still, storm)
			end
		end
	end
	selected = still
	rebuildGrid()
	refreshSelection()
	refreshBook(info.total)
end

function Mixer.open()
	window.Visible = true
	load()
end

local function slotBox(parent: Instance, order: number): TextLabel
	return UI.label({
		LayoutOrder = order,
		Size = UDim2.new(0.26, 0, 1, 0),
		BackgroundColor3 = UI.Colors.PanelLight,
		BackgroundTransparency = 0,
		TextScaled = true,
		Text = "Pick a storm",
		Parent = parent,
	})
end

local function symbol(parent: Instance, order: number, text: string)
	UI.label({ LayoutOrder = order, Size = UDim2.new(0.06, 0, 1, 0), Text = text, TextSize = 28, Parent = parent })
end

function Mixer.start()
	local screen = UI.screen("Mixer", 6)
	window = UI.new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.92, 0, 0.85, 0),
		BackgroundColor3 = UI.Colors.Panel,
		Visible = false,
		Parent = screen,
	}, {
		UI.corner(18),
		UI.stroke(UI.Colors.Rare, 3),
		UI.padding(14),
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(640, 560) }),
	})

	UI.label({
		Size = UDim2.new(1, -60, 0, 36),
		Text = "🧪 Storm Mixer",
		TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Rare,
		Parent = window,
	})
	local close = UI.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(44, 36),
		Text = "✕",
		TextSize = 22,
		BackgroundColor3 = UI.Colors.Bad,
		Parent = window,
	})
	close.Activated:Connect(function()
		window.Visible = false
	end)

	-- A + B = ?
	local row = UI.new("Frame", {
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 0, 56),
		BackgroundTransparency = 1,
		Parent = window,
	}, { UI.list(4, Enum.FillDirection.Horizontal) })
	slotA = slotBox(row, 1)
	symbol(row, 2, "+")
	slotB = slotBox(row, 3)
	symbol(row, 4, "=")
	resultLabel = slotBox(row, 5)
	for _, box in { slotA, slotB, resultLabel } do
		UI.corner(10).Parent = box
		UI.padding(6).Parent = box
	end

	mixButton = UI.button({
		Position = UDim2.fromOffset(0, 108),
		Size = UDim2.new(1, 0, 0, 40),
		Text = "🧪 Mix",
		TextSize = 22,
		BackgroundColor3 = UI.Colors.Disabled,
		Parent = window,
	})
	mixButton.Activated:Connect(function()
		local a, b = selected[1], selected[2]
		if busy or not a or not b then
			return
		end
		busy = true
		local ok, message = Remotes.func("MixStorms"):InvokeServer(a.uid, b.uid)
		if not ok then
			busy = false
			Toasts.show(message, "warn")
			return
		end
		selected = {}
		refreshSelection()
		task.delay(Config.Mixing.MixSeconds + 0.3, function()
			busy = false
			if window.Visible then
				load()
			end
		end)
	end)

	grid = UI.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 156),
		Size = UDim2.new(1, 0, 1, -270),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = window,
	}, {
		UI.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(140, 58),
			CellPadding = UDim2.fromOffset(6, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local book = UI.new("ScrollingFrame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 104),
		BackgroundColor3 = UI.Colors.Track,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = window,
	}, { UI.corner(10), UI.padding(8) })
	bookLabel = UI.label({
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = 15,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = UI.Colors.Muted,
		Parent = book,
	})

	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who == player and prompt.Name == "MixerPrompt" then
			Mixer.open()
		end
	end)
	player:GetAttributeChangedSignal("Sparks"):Connect(function()
		if window.Visible then
			refreshSelection()
		end
	end)
end

return Mixer
