-- The 🎨 Style window: cosmetics for your character (hats, trails, backs,
-- auras) and your island (pedestals, decorations, sign and flag, pets).
-- Buy with Sparks (or Robux for a few), then tap to wear or place.

local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local CosmeticsData = require(Shared.CosmeticsData)
local Format = require(Shared.Format)
local Products = require(Shared.Products)
local Remotes = require(Shared.Remotes)

local Toasts = require(script.Parent.Toasts)
local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local Style = {}

type State = {
	owned: { string },
	hat: string?,
	trail: string?,
	back: string?,
	aura: string?,
	pedestal: string?,
	flag: string?,
	decor: { string },
	pets: { string },
	signColor: number?,
	signEmoji: string?,
}

local window: Frame
local content: ScrollingFrame
local tabButtons: { [string]: TextButton } = {}
local currentTab = "hat"
local refreshers: { () -> () } = {}
local busy = false

local function state(): State
	local raw = player:GetAttribute("Cosmetics")
	if type(raw) == "string" then
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(raw)
		end)
		if ok and type(decoded) == "table" then
			return decoded
		end
	end
	return { owned = {}, decor = {}, pets = {} }
end

local function send(action: string, value: any)
	if busy then
		return
	end
	busy = true
	local ok, message = Remotes.func("Cosmetic"):InvokeServer(action, value)
	busy = false
	Toasts.show(message, if ok then "success" else "warn")
end

local function buyRobux(item: CosmeticsData.Item)
	local product = Products.get(CosmeticsData.productKey(item.id))
	if not product then
		return
	end
	if product.id ~= 0 then
		MarketplaceService:PromptProductPurchase(player, product.id)
	elseif RunService:IsStudio() then
		Remotes.event("DevPurchase"):FireServer(product.key)
	else
		Toasts.show(item.name .. " is coming soon!", "info")
	end
end

local function clear()
	refreshers = {}
	for _, child in content:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local function section(order: number, title: string): Frame
	UI.label({
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, 26),
		Text = title,
		TextSize = 19,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = content,
	})
	return UI.new("Frame", {
		LayoutOrder = order + 1,
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = content,
	}, {
		UI.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(150, 150),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
end

local function card(grid: Frame, order: number, item: CosmeticsData.Item)
	local category = CosmeticsData.category(item.category)
	local multi = category ~= nil and category.multi == true
	local frame = UI.new("Frame", {
		LayoutOrder = order,
		BackgroundColor3 = UI.Colors.PanelLight,
		Parent = grid,
	}, { UI.corner(12), UI.padding(6) })
	local stroke = UI.stroke(UI.Colors.Stroke, 1.5)
	stroke.Parent = frame
	UI.label({ Size = UDim2.new(1, 0, 0, 40), Text = item.emoji, TextSize = 34, Parent = frame })
	local name = UI.label({
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 0, 20),
		Text = item.name,
		TextScaled = true,
		Parent = frame,
	})
	UI.new("UITextSizeConstraint", { MaxTextSize = 16, Parent = name })
	local about = UI.label({
		Position = UDim2.fromOffset(0, 60),
		Size = UDim2.new(1, 0, 0, 30),
		Text = item.description,
		TextScaled = true,
		TextWrapped = true,
		TextColor3 = UI.Colors.Muted,
		Parent = frame,
	})
	UI.new("UITextSizeConstraint", { MaxTextSize = 12, Parent = about })
	local button = UI.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(1, 0, 0, 36),
		TextSize = 16,
		Parent = frame,
	})

	local mode = "buy"
	local function refresh()
		local current = state()
		local owned = table.find(current.owned or {}, item.id) ~= nil or (item.cost == 0 and not item.robux)
		local using
		if multi then
			local list = if item.category == "decor" then current.decor else current.pets
			using = table.find(list or {}, item.id) ~= nil
		else
			using = (current :: any)[item.category] == item.id
				or (item.category == "pedestal" and item.id == "Marble" and not current.pedestal)
		end
		stroke.Thickness = if using then 3.5 else 1.5
		stroke.Color = if using then UI.Colors.Good else UI.Colors.Stroke
		if using then
			mode = if item.id == "Marble" then "none" else (if multi then "equip" else "unequip")
			button.Text = if multi then "✓ Placed" else "✓ Using"
			button.BackgroundColor3 = UI.Colors.Good
		elseif owned then
			mode = "equip"
			button.Text = if multi then "Place" elseif category and category.island then "Use" else "Wear"
			button.BackgroundColor3 = UI.Colors.Stroke
		elseif item.robux then
			mode = "robux"
			local product = Products.get(CosmeticsData.productKey(item.id))
			button.Text = "R$ " .. (if product then product.price else "?")
			button.BackgroundColor3 = UI.Colors.Robux
		else
			mode = "buy"
			button.Text = "⚡ " .. Format.number(item.cost)
			local sparks = player:GetAttribute("Sparks") or 0
			button.BackgroundColor3 = if sparks >= item.cost then UI.Colors.Spark else UI.Colors.Disabled
		end
	end
	button.Activated:Connect(function()
		if mode == "buy" then
			send("buy", item.id)
		elseif mode == "equip" then
			send("equip", item.id)
		elseif mode == "unequip" then
			send("unequip", item.category)
		elseif mode == "robux" then
			buyRobux(item)
		end
	end)
	table.insert(refreshers, refresh)
	refresh()
end

local function buildSignPicker(order: number)
	UI.label({
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, 26),
		Text = "🪧 Island sign (free)",
		TextSize = 19,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = content,
	})
	local colors = UI.new("Frame", {
		LayoutOrder = order + 1,
		Size = UDim2.new(1, -8, 0, 44),
		BackgroundTransparency = 1,
		Parent = content,
	}, { UI.list(8, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left) })
	for index, color in CosmeticsData.SignColors do
		local swatch = UI.button({
			LayoutOrder = index,
			Size = UDim2.fromOffset(40, 40),
			Text = "",
			BackgroundColor3 = color,
			Parent = colors,
		})
		swatch.Activated:Connect(function()
			send("signColor", index)
		end)
		table.insert(refreshers, function()
			swatch.Text = if (state().signColor or 1) == index then "✓" else ""
		end)
	end
	local emoji = UI.new("Frame", {
		LayoutOrder = order + 2,
		Size = UDim2.new(1, -8, 0, 44),
		BackgroundTransparency = 1,
		Parent = content,
	}, { UI.list(6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left) })
	for index, symbol in CosmeticsData.SignEmoji do
		local button = UI.button({
			LayoutOrder = index,
			Size = UDim2.fromOffset(40, 40),
			Text = symbol,
			TextSize = 22,
			Parent = emoji,
		})
		button.Activated:Connect(function()
			send("signEmoji", symbol)
		end)
		table.insert(refreshers, function()
			button.BackgroundColor3 = if (state().signEmoji or "🏝️") == symbol
				then UI.Colors.Good
				else UI.Colors.PanelLight
		end)
	end
end

local function showTab(key: string)
	currentTab = key
	for name, button in tabButtons do
		button.BackgroundColor3 = if name == key then UI.Colors.Rare else UI.Colors.PanelLight
	end
	clear()
	local category = CosmeticsData.category(key)
	if not category then
		return
	end
	local order = 1
	if key == "flag" then
		buildSignPicker(order)
		order += 10
	end
	local title = category.emoji .. " " .. category.name
	if category.max then
		title ..= " (up to " .. category.max .. " at once)"
	elseif category.multi then
		title ..= " (place as many as you like)"
	end
	local grid = section(order, title)
	local index = 0
	for _, item in CosmeticsData.Items do
		if item.category == key then
			index += 1
			card(grid, index, item)
		end
	end
	for _, refresh in refreshers do
		refresh()
	end
end

function Style.toggle()
	window.Visible = not window.Visible
	if window.Visible then
		showTab(currentTab)
	end
end

function Style.start()
	local screen = UI.screen("Style", 6)
	window = UI.new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.94, 0.84),
		BackgroundColor3 = UI.Colors.Panel,
		Visible = false,
		Parent = screen,
	}, {
		UI.corner(18),
		UI.stroke(UI.Colors.Stroke, 3),
		UI.padding(14),
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(820, 500) }),
	})
	UI.label({
		Size = UDim2.new(1, -60, 0, 32),
		Text = "🎨 Style",
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = window,
	})
	UI.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(44, 34),
		Text = "✕",
		TextSize = 22,
		BackgroundColor3 = UI.Colors.Bad,
		Parent = window,
	}).Activated
		:Connect(function()
			window.Visible = false
		end)

	local tabs = UI.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(0, 150, 1, -42),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = window,
	}, { UI.list(6) })
	for index, category in CosmeticsData.Categories do
		if index == 5 then
			UI.label({
				LayoutOrder = index * 2 - 1,
				Size = UDim2.new(1, -6, 0, 18),
				Text = "🏝️ Island",
				TextSize = 14,
				TextColor3 = UI.Colors.Muted,
				Parent = tabs,
			})
		elseif index == 1 then
			UI.label({
				LayoutOrder = 0,
				Size = UDim2.new(1, -6, 0, 18),
				Text = "🧍 You",
				TextSize = 14,
				TextColor3 = UI.Colors.Muted,
				Parent = tabs,
			})
		end
		local button = UI.button({
			LayoutOrder = index * 2,
			Size = UDim2.new(1, -6, 0, 38),
			Text = category.emoji .. " " .. category.name,
			TextSize = 16,
			Parent = tabs,
		})
		button.Activated:Connect(function()
			showTab(category.key)
		end)
		tabButtons[category.key] = button
	end

	content = UI.new("ScrollingFrame", {
		Position = UDim2.fromOffset(160, 42),
		Size = UDim2.new(1, -160, 1, -42),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = UI.Colors.Stroke,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = window,
	}, { UI.list(8, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Left), UI.padding(4) })

	local function refreshAll()
		if window.Visible then
			for _, refresh in refreshers do
				refresh()
			end
		end
	end
	player:GetAttributeChangedSignal("Cosmetics"):Connect(refreshAll)
	player:GetAttributeChangedSignal("Sparks"):Connect(refreshAll)
end

return Style
