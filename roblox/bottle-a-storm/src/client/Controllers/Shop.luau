-- The shop window: Sparks upgrades, island themes, thief styles and Robux items.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)
local Products = require(Shared.Products)
local Remotes = require(Shared.Remotes)
local StormData = require(Shared.StormData)
local ThemeData = require(Shared.ThemeData)
local ThiefStyles = require(Shared.ThiefStyles)

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
local upgradeList: ScrollingFrame
local robuxList: ScrollingFrame
local styleList: ScrollingFrame
local themeList: ScrollingFrame
local tabButtons: { [string]: TextButton } = {}
local refreshers: { () -> () } = {}

local function attr(name: string): number
	return player:GetAttribute(name) or 0
end

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

local function buySparks(itemKey: string)
	local ok, message = Remotes.func("BuyItem"):InvokeServer(itemKey)
	Toasts.show(message, if ok then "success" else "warn")
end

local function sparksPrice(cost: number?): (string, boolean)
	if not cost then
		return "MAX", false
	end
	return "⚡ " .. Format.number(cost), attr("Sparks") >= cost
end

local function buildUpgrades()
	local order = 0
	local function add(key: string, refresh: (Card) -> ())
		order += 1
		local card = makeCard(upgradeList, order)
		card.button.Activated:Connect(function()
			if card.button.Active then
				buySparks(key)
			end
		end)
		local function run()
			refresh(card)
		end
		table.insert(refreshers, run)
		run()
	end

	add("Jar", function(card)
		local tier = math.max(1, attr("JarTier"))
		local jar = Config.Jars[tier]
		local nextJar = Config.Jars[tier + 1]
		card.title.Text = "🫙 " .. jar.name
		card.body.Text = if nextJar
			then "Upgrade to "
				.. nextJar.name
				.. ": catch "
				.. StormData.Rarities[nextJar.maxRarity].name
				.. " storms, fewer dodges and hits."
			else "The best jar there is. Every storm fears it."
		local needed = if nextJar then nextJar.climate or 0 else 0
		if attr("Climate") < needed then
			setBuyable(card, "🔒 Climate " .. needed, false)
			return
		end
		local text, can = sparksPrice(Economy.jarCost(tier))
		setBuyable(card, text, can)
	end)

	add("Pedestal", function(card)
		local owned = attr("Pedestals")
		local max = attr("MaxPedestals")
		card.title.Text = "🏛️ Pedestals " .. owned .. "/" .. max
		card.body.Text = "Each pedestal displays one storm. More storms, more Sparks!"
		local cost = if owned < max then Economy.pedestalCost(owned) else nil
		local text, can = sparksPrice(cost)
		setBuyable(card, text, can)
	end)

	add("Boots", function(card)
		local level = attr("BootsLevel")
		card.title.Text = "👟 Boots of Wind  Lv " .. level .. "/" .. Config.Boots.MaxLevel
		card.body.Text = "+"
			.. Config.Boots.SpeedPerLevel
			.. " run speed per level. Catch fast storms and outrun thieves."
		local text, can = sparksPrice(Economy.bootsCost(level))
		setBuyable(card, text, can)
	end)

	add("Snacks", function(card)
		card.title.Text = "🍪 Storm Snacks"
		card.body.Text = "Makes every storm 😄 Happy (+25% Sparks). Bored storms earn less and can escape!"
		if attr("StormCount") == 0 then
			setBuyable(card, "No storms", false)
			return
		end
		local text, can = sparksPrice(attr("SnackCost"))
		setBuyable(card, text, can)
	end)

	add("Trap", function(card)
		local level = attr("TrapLevel")
		card.title.Text = "⚡ Lightning Rod  Lv " .. level .. "/" .. #Config.Traps.Costs
		card.body.Text = "Stuns thieves for "
			.. (level + 1) * Config.Traps.StunPerLevel
			.. "s the moment they grab your storm."
		local text, can = sparksPrice(Economy.trapCost(level))
		setBuyable(card, text, can)
	end)
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

local function buildRobux()
	local order = 0
	local function add(item: Products.Item, isPass: boolean)
		order += 1
		local card = makeCard(robuxList, order)
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
			if item.key == "RaidShield" then
				card.body.Text = item.description .. " (You have " .. attr("RaidShields") .. ")"
			end
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

local function buildStyles()
	for order, style in ThiefStyles.List do
		local card = makeCard(styleList, order)
		card.title.Text = style.emoji .. " " .. style.name
		card.body.Text = style.description
		card.button.Activated:Connect(function()
			if card.button.Active then
				buySparks("Style:" .. style.key)
			end
		end)
		local function run()
			local unlocked = table.find(string.split(player:GetAttribute("UnlockedStyles") or "", ","), style.key)
			if player:GetAttribute("ThiefStyle") == style.key then
				setBuyable(card, "✓ Equipped", true, UI.Colors.Good)
			elseif unlocked then
				setBuyable(card, "Equip", true, UI.Colors.Stroke)
			else
				local text, can = sparksPrice(style.cost)
				setBuyable(card, text, can)
			end
		end
		table.insert(refreshers, run)
		run()
	end
end

local function buildThemes()
	for order, theme in ThemeData.List do
		local card = makeCard(themeList, order)
		card.title.Text = theme.emoji .. " " .. theme.name
		card.body.Text = theme.description
		if theme.ground then
			card.frame.BackgroundColor3 = UI.Colors.PanelLight:Lerp(theme.ground, 0.35)
		end
		card.button.Activated:Connect(function()
			if card.button.Active then
				buySparks("Theme:" .. theme.key)
			end
		end)
		local function run()
			local owned = theme.cost == 0
				or table.find(string.split(player:GetAttribute("UnlockedThemes") or "", ","), theme.key) ~= nil
			if player:GetAttribute("Theme") == theme.key then
				setBuyable(card, "✓ Using", false)
				card.button.BackgroundColor3 = UI.Colors.Good
			elseif owned then
				setBuyable(card, "Use", true, UI.Colors.Stroke)
			else
				local text, can = sparksPrice(theme.cost)
				setBuyable(card, text, can)
			end
		end
		table.insert(refreshers, run)
		run()
	end
end

local function showTab(name: string)
	upgradeList.Visible = name == "Upgrades"
	themeList.Visible = name == "Themes"
	robuxList.Visible = name == "Robux"
	styleList.Visible = name == "Styles"
	for tab, button in tabButtons do
		button.BackgroundColor3 = if tab == name then UI.Colors.Stroke else UI.Colors.PanelLight
	end
end

function Shop.toggle(tab: string?)
	window.Visible = not window.Visible or tab ~= nil
	if tab then
		showTab(tab)
	end
end

local function makeList(name: string): ScrollingFrame
	local list = UI.new("ScrollingFrame", {
		Name = name,
		Position = UDim2.fromOffset(0, 104),
		Size = UDim2.new(1, 0, 1, -104),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = window,
	}, { UI.list(8) })
	return list
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
		UI.stroke(UI.Colors.Stroke, 3),
		UI.padding(14),
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(560, 520) }),
	})

	UI.label({
		Size = UDim2.new(1, -60, 0, 40),
		Text = "🛒 Storm Shop",
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Spark,
		Parent = window,
	})
	local close = UI.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(44, 40),
		Text = "✕",
		TextSize = 22,
		BackgroundColor3 = UI.Colors.Bad,
		Parent = window,
	})
	close.Activated:Connect(function()
		window.Visible = false
	end)

	local tabs = UI.new("Frame", {
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundTransparency = 1,
		Parent = window,
	}, { UI.list(8, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left) })
	local tabList = {
		{ "Upgrades", "⚡ Upgrades" },
		{ "Themes", "🏝️ Themes" },
		{ "Styles", "🥷 Styles" },
		{ "Robux", "💎 Robux" },
	}
	for index, tab in tabList do
		local button = UI.button({
			LayoutOrder = index,
			Size = UDim2.new(1 / #tabList, -6, 1, 0),
			Text = tab[2],
			TextSize = 17,
			Parent = tabs,
		})
		button.Activated:Connect(function()
			showTab(tab[1])
		end)
		tabButtons[tab[1]] = button
	end

	upgradeList = makeList("Upgrades")
	robuxList = makeList("Robux")
	styleList = makeList("Styles")
	themeList = makeList("Themes")
	buildUpgrades()
	buildThemes()
	buildRobux()
	buildStyles()
	showTab("Upgrades")

	local function refreshAll()
		for _, refresh in refreshers do
			refresh()
		end
	end
	player.AttributeChanged:Connect(refreshAll)
end

return Shop
