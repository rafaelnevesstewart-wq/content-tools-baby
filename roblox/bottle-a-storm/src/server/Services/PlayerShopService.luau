-- 🏪 Player shops: sell your spare cosmetics to other players in the server
-- for Sparks (the 🏪 Player Market kiosk at the start of Shop Street). Put
-- up to 5 of your cosmetics on sale at your own price; anyone can buy them.
-- The seller gets the price minus a 10% market fee and the cosmetic moves to
-- the buyer. Only cosmetics sold for Sparks can be sold (like trading), and
-- your listings go away when you leave.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local CosmeticsData = require(Shared.CosmeticsData)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent.Parent.Modules
local Juice = require(Modules.Juice)
local Notify = require(Modules.Notify)

local CosmeticService = require(script.Parent.CosmeticService)
local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)

local PlayerShopService = {}

local MAX_LISTINGS = 5
local FEE = 0.1
local MIN_PRICE, MAX_PRICE = 10, 1000000

type Listing = { id: number, seller: Player, item: string, price: number }

local listings: { [number]: Listing } = {}
local nextId = 0
local lastAction: { [Player]: number } = {}

local function sellable(item: CosmeticsData.Item?): boolean
	return item ~= nil and not item.robux and item.cost > 0
end

local function listed(player: Player, itemId: string): boolean
	for _, listing in listings do
		if listing.seller == player and listing.item == itemId then
			return true
		end
	end
	return false
end

local function countFor(player: Player): number
	local count = 0
	for _, listing in listings do
		if listing.seller == player then
			count += 1
		end
	end
	return count
end

local function info(player: Player): any
	local data = DataService.get(player)
	local list = {}
	for id, listing in listings do
		local item = CosmeticsData.get(listing.item)
		if item then
			table.insert(list, {
				id = id,
				name = item.name,
				emoji = item.emoji,
				category = item.category,
				price = listing.price,
				seller = listing.seller.DisplayName,
				mine = listing.seller == player,
				owned = data ~= nil and data.cosmetics.owned[item.id] == true,
			})
		end
	end
	table.sort(list, function(a, b)
		return a.price < b.price
	end)
	local mine = {}
	if data then
		for id in data.cosmetics.owned do
			local item = CosmeticsData.get(id)
			if item and sellable(item) and not listed(player, id) then
				table.insert(mine, { id = id, name = item.name, emoji = item.emoji, value = item.cost })
			end
		end
	end
	table.sort(mine, function(a, b)
		return a.name < b.name
	end)
	return { listings = list, mine = mine, sparks = if data then data.sparks else 0, fee = FEE }
end

local function sell(player: Player, itemId: any, price: any): (boolean, string)
	local data = DataService.get(player)
	local item = if type(itemId) == "string" then CosmeticsData.get(itemId) else nil
	if not data or not item or not data.cosmetics.owned[item.id] or not sellable(item) then
		return false, "You can't sell that."
	end
	if type(price) ~= "number" or price ~= price then
		return false, "Type a price."
	end
	price = math.clamp(math.floor(price), MIN_PRICE, MAX_PRICE)
	if listed(player, item.id) then
		return false, "That's already on sale."
	end
	if countFor(player) >= MAX_LISTINGS then
		return false, "You can sell " .. MAX_LISTINGS .. " things at a time."
	end
	nextId += 1
	listings[nextId] = { id = nextId, seller = player, item = item.id, price = price }
	Notify.all(
		"🏪 "
			.. player.DisplayName
			.. " is selling "
			.. item.emoji
			.. " "
			.. item.name
			.. " for ⚡"
			.. Format.number(price)
			.. " (Shop Street market)",
		"info"
	)
	return true, "🏪 On sale for ⚡" .. Format.number(price) .. "!"
end

local function cancel(player: Player, id: any): (boolean, string)
	local listing = if type(id) == "number" then listings[id] else nil
	if not listing or listing.seller ~= player then
		return false, "That's not your listing."
	end
	listings[id] = nil
	return true, "Taken off sale."
end

local function buy(player: Player, id: any): (boolean, string)
	local listing = if type(id) == "number" then listings[id] else nil
	if not listing or not listing.seller.Parent then
		return false, "That's gone!"
	end
	local seller = listing.seller
	if seller == player then
		return false, "That's yours!"
	end
	local data, sellerData = DataService.get(player), DataService.get(seller)
	local item = CosmeticsData.get(listing.item)
	if not data or not sellerData or not item then
		return false, "Try again in a moment."
	end
	if not sellerData.cosmetics.owned[item.id] then
		listings[id] = nil
		return false, "They don't have it anymore."
	end
	if data.cosmetics.owned[item.id] then
		return false, "You already have " .. item.name .. "!"
	end
	if data.sparks < listing.price then
		return false, "You need ⚡" .. Format.number(listing.price - data.sparks) .. " more Sparks."
	end
	listings[id] = nil
	local earned = math.floor(listing.price * (1 - FEE))
	data.sparks -= listing.price
	sellerData.sparks += earned
	sellerData.cosmetics.owned[item.id] = nil
	if sellerData.cosmetics[item.category] == item.id then
		sellerData.cosmetics[item.category] = nil
	end
	data.cosmetics.owned[item.id] = true
	sellerData.stats.shopSales = (sellerData.stats.shopSales or 0) + 1
	for _, who in { player, seller } do
		IncomeService.sync(who)
		CosmeticService.refreshAll(who)
		task.spawn(DataService.saveNow, who)
	end
	Juice.sound(seller, "coins")
	Notify.player(
		seller,
		"🏪 "
			.. player.DisplayName
			.. " bought your "
			.. item.emoji
			.. " "
			.. item.name
			.. "! +⚡"
			.. Format.number(earned),
		"success"
	)
	return true, "🏪 You bought " .. item.emoji .. " " .. item.name .. "! Wear it in 🎨 Style."
end

local function onAction(player: Player, action: any, a: any, b: any): any
	if action == "info" then
		return info(player)
	end
	if os.clock() - (lastAction[player] or 0) < 0.4 then
		return false, "Slow down!"
	end
	lastAction[player] = os.clock()
	if action == "sell" then
		return sell(player, a, b)
	elseif action == "cancel" then
		return cancel(player, a)
	elseif action == "buy" then
		return buy(player, a)
	end
	return false, "Can't do that."
end

-- The market kiosk at the start of Shop Street.
local function buildKiosk()
	local street = Config.Lobby.Center + Vector3.new(0, 0, -Config.Lobby.StreetDistance)
	local at = street + Vector3.new(-10, 0, 40)
	local kiosk = Instance.new("Part")
	kiosk.Name = "PlayerMarket"
	kiosk.Anchored = true
	kiosk.Size = Vector3.new(3, 3.4, 2)
	kiosk.CFrame = CFrame.lookAt(at + Vector3.new(0, 1.7, 0), at + Vector3.new(0, 1.7, 5))
	kiosk.Color = Color3.fromRGB(140, 100, 64)
	kiosk.Material = Enum.Material.WoodPlanks
	kiosk.Parent = workspace
	local board = Instance.new("Part")
	board.Anchored = true
	board.CanCollide = false
	board.Size = Vector3.new(4.4, 1.6, 0.2)
	board.CFrame = kiosk.CFrame * CFrame.new(0, 2.6, 0)
	board.Color = Color3.fromRGB(230, 184, 70)
	board.Material = Enum.Material.Foil
	board.Parent = kiosk
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(220, 80)
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(60, 40, 20)
	label.Text = "🏪 Player Market"
	label.Parent = gui
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Buy & sell"
	prompt.ObjectText = "🏪 Player Market"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OpenWindow", "PlayerShop")
	prompt.Parent = kiosk
end

function PlayerShopService.start()
	buildKiosk()
	Remotes.func("PlayerShop").OnServerInvoke = onAction
	Players.PlayerRemoving:Connect(function(player)
		lastAction[player] = nil
		for id, listing in listings do
			if listing.seller == player then
				listings[id] = nil
			end
		end
	end)
end

return PlayerShopService
