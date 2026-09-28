-- The Bed Wars 🛒 Item Shop window. Opens from the shop stand on your island
-- (its "Open the Item Shop" prompt). Tabs: Blocks, Weapons, Armor, Items and
-- team Upgrades. Prices are in the resources you carry this match.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local MatchData = require(Shared.MatchData)
local Remotes = require(Shared.Remotes)

local Toasts = require(script.Parent.Toasts)
local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local ItemShop = {}

local TABS = {
	{ "Blocks", "🧱 Blocks" },
	{ "Weapons", "⚔️ Weapons" },
	{ "Armor", "🛡️ Armor" },
	{ "Tools", "⛏️ Tools" },
	{ "Items", "🍎 Items" },
	{ "Upgrades", "💎 Team" },
}

local window: Frame
local grid: ScrollingFrame
local wallet: TextLabel
local tabButtons: { [string]: TextButton } = {}
local currentTab = "Blocks"
local refreshers: { () -> () } = {}
local busy = false

local function resource(key: string): number
	local value = player:GetAttribute("Res_" .. key)
	return if type(value) == "number" then value else 0
end

local function resourceInfo(key: string)
	for _, info in MatchData.Resources do
		if info.key == key then
			return info
		end
	end
	return MatchData.Resources[1]
end

local function walletText(): string
	local parts = {}
	for _, info in MatchData.Resources do
		table.insert(parts, info.emoji .. " " .. resource(info.key))
	end
	return table.concat(parts, "     ")
end

-- Already own this (or better)? Used to grey out swords and armor.
local function owned(key: string): boolean
	local swordTier = MatchData.swordTier(key)
	if swordTier then
		return (player:GetAttribute("SwordTier") or 1) >= swordTier
	end
	local armorTier = MatchData.armorTier(key)
	if armorTier then
		return (player:GetAttribute("ArmorTier") or 1) >= armorTier
	end
	return false
end

local function card(order: number): Frame
	return UI.new("Frame", {
		LayoutOrder = order,
		BackgroundColor3 = UI.Colors.PanelLight,
		Parent = grid,
	}, { UI.corner(12), UI.padding(8) })
end

local function buy(remote: string, key: string)
	if busy then
		return
	end
	busy = true
	local ok, message = Remotes.func(remote):InvokeServer(key)
	busy = false
	Toasts.show(message, if ok then "success" else "warn")
end

local function build()
	for _, child in grid:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	refreshers = {}
	if currentTab == "Tools" then
		for index, key in { "Pickaxe", "Axe" } do
			local info = MatchData.Tools[key]
			local frame = card(index)
			local title = UI.label({
				Size = UDim2.new(1, 0, 0, 24),
				TextSize = 17,
				Parent = frame,
			})
			local body = UI.label({
				Position = UDim2.fromOffset(0, 26),
				Size = UDim2.new(1, 0, 0, 52),
				TextSize = 13,
				TextWrapped = true,
				TextYAlignment = Enum.TextYAlignment.Top,
				TextColor3 = UI.Colors.Muted,
				Parent = frame,
			})
			local button = UI.button({
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.fromScale(0.5, 1),
				Size = UDim2.new(1, 0, 0, 36),
				TextSize = 16,
				Parent = frame,
			})
			button.Activated:Connect(function()
				buy("BuyMatchItem", key)
			end)
			local function run()
				local tier = player:GetAttribute(key .. "Tier") or 0
				local nextTier = info.tiers[tier + 1]
				local current = info.tiers[tier]
				title.Text = info.emoji .. " " .. (if nextTier then nextTier.name else current.name)
				body.Text = info.description
					.. "\nYou have: "
					.. (if current then current.name else "none")
					.. "\nKept when you respawn (one tier lower)."
				if not nextTier then
					button.Text = "Maxed ✓"
					button.BackgroundColor3 = UI.Colors.Disabled
				else
					local currency = resourceInfo(nextTier.currency)
					button.Text = currency.emoji .. " " .. nextTier.cost .. " " .. nextTier.currency
					button.BackgroundColor3 = if resource(nextTier.currency) >= nextTier.cost
						then UI.Colors.Good
						else UI.Colors.Disabled
				end
			end
			table.insert(refreshers, run)
			run()
		end
		return
	end
	if currentTab == "Upgrades" then
		for index, upgrade in MatchData.Upgrades do
			local frame = card(index)
			UI.label({
				Size = UDim2.new(1, 0, 0, 24),
				Text = upgrade.emoji .. " " .. upgrade.name,
				TextSize = 17,
				Parent = frame,
			})
			local body = UI.label({
				Position = UDim2.fromOffset(0, 26),
				Size = UDim2.new(1, 0, 0, 52),
				Text = upgrade.description,
				TextSize = 13,
				TextWrapped = true,
				TextYAlignment = Enum.TextYAlignment.Top,
				TextColor3 = UI.Colors.Muted,
				Parent = frame,
			})
			local button = UI.button({
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.fromScale(0.5, 1),
				Size = UDim2.new(1, 0, 0, 36),
				TextSize = 16,
				Parent = frame,
			})
			button.Activated:Connect(function()
				buy("BuyUpgrade", upgrade.key)
			end)
			local function run()
				local level = player:GetAttribute("Upgrade_" .. upgrade.key) or 0
				local cost = upgrade.costs[level + 1]
				body.Text = upgrade.description .. "\nLevel " .. level .. "/" .. #upgrade.costs
				if not cost then
					button.Text = "Maxed ✓"
					button.BackgroundColor3 = UI.Colors.Disabled
				else
					button.Text = "💎 " .. cost
					button.BackgroundColor3 = if resource("Crystals") >= cost
						then UI.Colors.Good
						else UI.Colors.Disabled
				end
			end
			table.insert(refreshers, run)
			run()
		end
		return
	end
	local order = 0
	for _, item in MatchData.Shop do
		if item.tab ~= currentTab then
			continue
		end
		order += 1
		local frame = card(order)
		local info = resourceInfo(item.currency)
		UI.stroke(info.color, 1.5).Parent = frame
		UI.label({
			Size = UDim2.new(1, 0, 0, 24),
			Text = item.emoji .. " " .. item.name,
			TextSize = 17,
			TextScaled = false,
			Parent = frame,
		})
		UI.label({
			Position = UDim2.fromOffset(0, 26),
			Size = UDim2.new(1, 0, 0, 52),
			Text = item.description,
			TextSize = 13,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = UI.Colors.Muted,
			Parent = frame,
		})
		local button = UI.button({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.new(1, 0, 0, 36),
			TextSize = 16,
			Parent = frame,
		})
		button.Activated:Connect(function()
			buy("BuyMatchItem", item.key)
		end)
		local function run()
			if owned(item.key) then
				button.Text = "Owned ✓"
				button.BackgroundColor3 = UI.Colors.Disabled
				return
			end
			button.Text = info.emoji .. " " .. item.cost .. " " .. item.currency
			button.BackgroundColor3 = if resource(item.currency) >= item.cost
				then UI.Colors.Good
				else UI.Colors.Disabled
		end
		table.insert(refreshers, run)
		run()
	end
end

local function showTab(name: string)
	currentTab = name
	for key, button in tabButtons do
		button.BackgroundColor3 = if key == name then UI.Colors.Stroke else UI.Colors.PanelLight
	end
	build()
end

function ItemShop.open()
	window.Visible = true
	wallet.Text = walletText()
	showTab(currentTab)
end

function ItemShop.start()
	local screen = UI.screen("ItemShop", 6)
	window = UI.new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.92, 0, 0.82, 0),
		BackgroundColor3 = UI.Colors.Panel,
		Visible = false,
		Parent = screen,
	}, {
		UI.corner(18),
		UI.stroke(UI.Colors.Spark, 3),
		UI.padding(14),
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(640, 520) }),
	})
	UI.label({
		Size = UDim2.new(1, -60, 0, 34),
		Text = "🛒 Item Shop",
		TextSize = 28,
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
	wallet = UI.label({
		Position = UDim2.fromOffset(0, 38),
		Size = UDim2.new(1, 0, 0, 26),
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = window,
	})
	local tabs = UI.new("Frame", {
		Position = UDim2.fromOffset(0, 70),
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		Parent = window,
	}, { UI.list(6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left) })
	for index, tab in TABS do
		local button = UI.button({
			LayoutOrder = index,
			Size = UDim2.new(1 / #TABS, -5, 1, 0),
			Text = tab[2],
			TextSize = 15,
			Parent = tabs,
		})
		button.Activated:Connect(function()
			showTab(tab[1])
		end)
		tabButtons[tab[1]] = button
	end
	grid = UI.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 118),
		Size = UDim2.new(1, 0, 1, -118),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = window,
	}, {
		UI.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(186, 136),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who == player and prompt.Name == "ItemShopPrompt" then
			ItemShop.open()
		end
	end)
	player.AttributeChanged:Connect(function()
		if window.Visible then
			wallet.Text = walletText()
			for _, run in refreshers do
				run()
			end
		end
	end)
	workspace:GetAttributeChangedSignal("MatchPhase"):Connect(function()
		if workspace:GetAttribute("MatchPhase") ~= "playing" then
			window.Visible = false
		end
	end)
end

return ItemShop
