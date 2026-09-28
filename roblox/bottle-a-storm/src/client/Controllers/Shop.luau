-- The 💎 Robux shop window: game passes (VIP, Star Booster) and products
-- (Sparks, Golden Kit Crate, wheel spins, Battle Pass Premium, tier skips,
-- Rainbow Hour). Robux cosmetics are sold in 🎨 Style instead.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Products = require(Shared.Products)
local Remotes = require(Shared.Remotes)

local Toasts = require(script.Parent.Toasts)
local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local Shop = {}

type Card = {
	frame: Frame,
	title: TextLabel,
	body: TextLabel,
	button: TextButton,
}

local window: Frame
local list: ScrollingFrame
local refreshers: { () -> () } = {}

local function makeCard(parent: Instance, order: number): Card
	local frame = UI.new("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, 84),
		BackgroundColor3 = UI.Colors.PanelLight,
		Parent = parent,
	}, { UI.corner(12), UI.padding(10) })
	local title = UI.label({
		Size = UDim2.new(1, -140, 0, 26),
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = frame,
	})
	local body = UI.label({
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, -140, 0, 36),
		TextSize = 15,
		TextWrapped = true,
		TextColor3 = UI.Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = frame,
	})
	local button = UI.button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(126, 46),
		TextSize = 19,
		Parent = frame,
	})
	return { frame = frame, title = title, body = body, button = button }
end

local function setBuyable(card: Card, text: string, enabled: boolean, color: Color3?)
	card.button.Text = text
	card.button.Active = enabled
	card.button.AutoButtonColor = enabled
	card.button.BackgroundColor3 = if enabled then color or UI.Colors.Spark else UI.Colors.Disabled
	card.button.TextColor3 = Color3.new(1, 1, 1)
end

local function buyRobux(item: Products.Item, isPass: boolean)
	if item.id == 0 then
		if RunService:IsStudio() then
			Remotes.event("DevPurchase"):FireServer(item.key)
		else
			Toasts.show(item.name .. " is coming soon!", "info")
		end
		return
	end
	if isPass then
		MarketplaceService:PromptGamePassPurchase(player, item.id)
	else
		MarketplaceService:PromptProductPurchase(player, item.id)
	end
end

local function build()
	local order = 0
	local function add(item: Products.Item, isPass: boolean)
		order += 1
		local card = makeCard(list, order)
		card.title.Text = (if isPass then "🎟️ " else "💎 ") .. item.name
		card.body.Text = item.description
		card.button.Activated:Connect(function()
			if card.button.Active then
				buyRobux(item, isPass)
			end
		end)
		local function run()
			local owned = (isPass and player:GetAttribute(Products.passAttribute(item.key)) == true)
				or (item.key == "SeasonPremium" and player:GetAttribute("SeasonPremium") == true)
			if owned then
				setBuyable(card, "Owned ✓", false)
			else
				setBuyable(card, "R$ " .. item.price, true, UI.Colors.Robux)
			end
		end
		table.insert(refreshers, run)
		run()
	end
	for _, pass in Products.Passes do
		add(pass, true)
	end
	for _, product in Products.DevProducts do
		add(product, false)
	end
end

function Shop.toggle()
	window.Visible = not window.Visible
end

function Shop.start()
	local screen = UI.screen("Shop", 5)
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
		UI.stroke(UI.Colors.Robux, 3),
		UI.padding(14),
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(560, 520) }),
	})

	UI.label({
		Size = UDim2.new(1, -60, 0, 40),
		Text = "💎 Robux Shop",
		TextSize = 30,
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
	UI.label({
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(1, 0, 0, 22),
		Text = "Nothing here makes you stronger in a match. It's all Sparks, kits, looks and the battle pass.",
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Muted,
		Parent = window,
	})

	list = UI.new("ScrollingFrame", {
		Name = "Robux",
		Position = UDim2.fromOffset(0, 72),
		Size = UDim2.new(1, 0, 1, -72),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = window,
	}, { UI.list(8) })
	build()

	player.AttributeChanged:Connect(function()
		for _, refresh in refreshers do
			refresh()
		end
	end)
end

return Shop
