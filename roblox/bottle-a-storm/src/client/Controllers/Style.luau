-- The 🎨 Style window: Bed Wars cosmetics for you (hats, trails, backs,
-- auras) and for your matches (your team's cloud bed, sword skin, arrow
-- effect and knockout effect). Buy with Sparks (or Robux for a few; some only
-- come from the battle pass), then tap to use.

local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local CosmeticsData = require(Shared.CosmeticsData)
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Products = require(Shared.Products)
local Remotes = require(Shared.Remotes)

local Paint = require(script.Parent.Paint)
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
	bed: string?,
	sword: string?,
	fx: string?,
	ko: string?,
}

local window: Frame
local content: ScrollingFrame
local tabButtons: { [string]: TextButton } = {}
local currentTab = "hat"
local refreshers: { () -> () } = {}
local shimmers: { UIGradient } = {}
local bonusLabel: TextLabel
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
	return { owned = {} }
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
	shimmers = {}
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
			CellSize = UDim2.fromOffset(150, 172),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
end

local function card(grid: Frame, order: number, item: CosmeticsData.Item)
	local tier = CosmeticsData.tierOf(item)
	local frame = UI.new("Frame", {
		LayoutOrder = order,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = grid,
	}, { UI.corner(12), UI.padding(6) })
	-- A glow of the tier's color from the top of the card.
	local gradient = UI.new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(UI.Colors.PanelLight:Lerp(tier.color, 0.35), UI.Colors.PanelLight),
		Parent = frame,
	})
	if tier.name == "Legendary" or tier.name == "Mythic" then
		table.insert(shimmers, gradient)
	end
	local stroke = UI.stroke(tier.color, 1.5)
	stroke.Parent = frame
	UI.label({ Size = UDim2.new(1, 0, 0, 40), Text = item.emoji, TextSize = 34, Parent = frame })
	UI.label({
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 0, 16),
		Text = if tier.bonus > 0
			then tier.name .. "  ·  +" .. math.floor(tier.bonus * 100) .. "% Sparks"
			else tier.name,
		TextSize = 12,
		TextColor3 = UI.ink(tier.color),
		Parent = frame,
	})
	local name = UI.label({
		Position = UDim2.fromOffset(0, 58),
		Size = UDim2.new(1, 0, 0, 20),
		Text = item.name,
		TextScaled = true,
		Parent = frame,
	})
	UI.new("UITextSizeConstraint", { MaxTextSize = 16, Parent = name })
	local about = UI.label({
		Position = UDim2.fromOffset(0, 78),
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
		local owned = table.find(current.owned or {}, item.id) ~= nil
			or (item.cost == 0 and not item.robux and not item.season and not item.achievement)
		local default = CosmeticsData.Defaults[item.category]
		local using = (current :: any)[item.category] == item.id
			or (item.id == default and (current :: any)[item.category] == nil)
		stroke.Thickness = if using then 3.5 else 1.5
		stroke.Color = if using then UI.Colors.Good else tier.color
		if using then
			local isDefault = CosmeticsData.Defaults[item.category] == item.id
			mode = if isDefault then "none" else "unequip"
			button.Text = "✓ Using"
			button.BackgroundColor3 = UI.Colors.Good
		elseif owned then
			mode = "equip"
			button.Text = "Use"
			button.BackgroundColor3 = UI.Colors.Stroke
		elseif item.season then
			mode = "none"
			button.Text = "🎟️ Battle pass"
			button.BackgroundColor3 = UI.Colors.Disabled
		elseif item.achievement then
			mode = "none"
			button.Text = "🏅 Achievement"
			button.BackgroundColor3 = UI.Colors.Disabled
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

-- What each match cosmetic does, under its title.
local HINTS: { [string]: string } = {
	bed = "  ·  your team's bed uses the first teammate's pick",
	sword = "  ·  every sword you hold, wood to diamond",
	fx = "  ·  your bow's arrows",
	ko = "  ·  bursts out when you knock someone out",
	dance = "  ·  your character dances when your team wins",
}

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
	local grid = section(1, category.emoji .. " " .. category.name .. (HINTS[key] or ""))
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

-- Opens the window on one category (the shop street's Pet Shop uses this).
function Style.open(tab: string)
	window.Visible = true
	showTab(tab)
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
	bonusLabel = UI.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -54, 0, 0),
		Size = UDim2.fromOffset(330, 32),
		TextSize = 16,
		TextColor3 = UI.Colors.Spark,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = window,
	})
	local function refreshBonus()
		local bonus = player:GetAttribute("StyleBonus") or 0
		bonusLabel.Text = "✨ Style Bonus: +"
			.. math.floor(bonus * 100 + 0.5)
			.. "% match Sparks (max +"
			.. math.floor(Config.Style.MaxBonus * 100)
			.. "%)"
	end
	player:GetAttributeChangedSignal("StyleBonus"):Connect(refreshBonus)
	refreshBonus()
	-- Legendary and Mythic cards shimmer.
	task.spawn(function()
		while true do
			if window.Visible then
				local offset = (os.clock() * 0.6) % 2 - 1
				for _, gradient in shimmers do
					gradient.Offset = Vector2.new(0, offset * 0.3)
				end
			end
			task.wait(0.05)
		end
	end)
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
	UI.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -52, 0, 0),
		Size = UDim2.fromOffset(110, 34),
		Text = "🖌️ Paint",
		TextSize = 16,
		BackgroundColor3 = UI.Colors.Rare,
		Parent = window,
	}).Activated
		:Connect(function()
			window.Visible = false
			Paint.toggle()
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
		if index == 1 or category.key == "bed" then
			UI.label({
				LayoutOrder = index * 2 - 1,
				Size = UDim2.new(1, -6, 0, 18),
				Text = if index == 1 then "🧍 You" else "⚔️ In matches",
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
