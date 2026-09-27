-- The Storm Market and Mystery Jars.
--   * Storm Market (like Grow a Garden's shop): 6 storms with limited stock,
--     restocked every 5 minutes. Every server gets the same stock at the same
--     time, and stock is shared: first come, first served.
--   * Mystery Jars (like Pet Simulator eggs): pay, then hatch a random storm
--     with the jar's odds. The client plays the hatch animation.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Format)
local MarketData = require(Shared.MarketData)
local Remotes = require(Shared.Remotes)
local StormData = require(Shared.StormData)

local Modules = script.Parent.Parent.Modules
local Notify = require(Modules.Notify)

local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local PlotService = require(script.Parent.PlotService)
local RewardService = require(script.Parent.RewardService)

local MarketService = {}

type Offer = { def: StormData.StormDef, mutation: string?, price: number, stock: number }

local offers: { Offer } = {}
local restockIndex = -1
local lastRequest: { [Player]: number } = {}
local rng = Random.new()

local function pickRarity(weights: { number }, random: Random): number
	local total = 0
	for _, weight in weights do
		total += weight
	end
	local pick = random:NextNumber(0, total)
	for index, weight in weights do
		pick -= weight
		if pick <= 0 and weight > 0 then
			return index
		end
	end
	return #weights
end

local function restock(index: number)
	restockIndex = index
	local random = Random.new(index)
	offers = {}
	local used: { [string]: boolean } = {}
	local hasLegendary = false
	for _ = 1, MarketData.Slots do
		local def
		for _ = 1, 10 do -- avoid showing the same storm twice
			local options = StormData.wildOfRarity(pickRarity(MarketData.RarityWeights, random))
			def = options[random:NextInteger(1, #options)]
			if not used[def.id] then
				break
			end
		end
		used[def.id] = true
		local mutation: string? = nil
		if random:NextNumber() < MarketData.MutationChance then
			local list = StormData.Mutations
			mutation = list[random:NextInteger(1, #list)].id
		end
		local price = math.max(
			MarketData.MinPrice,
			math.floor(StormData.incomeOf({ id = def.id, mut = mutation }) * MarketData.PriceSeconds)
		)
		table.insert(offers, {
			def = def,
			mutation = mutation,
			price = price,
			stock = random:NextInteger(MarketData.StockRange[1], MarketData.StockRange[2]),
		})
		hasLegendary = hasLegendary or def.rarity >= 5
	end
	workspace:SetAttribute("MarketRestockAt", (index + 1) * MarketData.RestockSeconds)
	workspace:SetAttribute("MarketVersion", (workspace:GetAttribute("MarketVersion") or 0) + 1)
	if hasLegendary then
		Notify.all("🏪 The Storm Market restocked, and there's a LEGENDARY storm in stock! Hurry!", "rare")
	else
		Notify.all("🏪 The Storm Market restocked! Check out the new storms.", "info")
	end
end

local function getMarket(_player: Player)
	local list = {}
	for _, offer in offers do
		table.insert(list, { id = offer.def.id, mut = offer.mutation, price = offer.price, stock = offer.stock })
	end
	return { restockAt = workspace:GetAttribute("MarketRestockAt"), items = list }
end

local function slowDown(player: Player): boolean
	if os.clock() - (lastRequest[player] or 0) < 0.4 then
		return true
	end
	lastRequest[player] = os.clock()
	return false
end

local function buyMarket(player: Player, slot: any): (boolean, string)
	local data = DataService.get(player)
	local offer = type(slot) == "number" and offers[slot]
	if not data or not offer or slowDown(player) then
		return false, "Can't buy that right now."
	end
	if offer.stock <= 0 then
		return false, "Sold out! Wait for the next restock."
	end
	if not PlotService.firstFreeSlot(player) then
		return false, "Your island is full! Buy a pedestal or sell a storm first."
	end
	if data.sparks < offer.price then
		return false, "You need ⚡" .. Format.number(offer.price - data.sparks) .. " more Sparks."
	end
	data.sparks -= offer.price
	local problem = RewardService.giveStorm(player, offer.def, offer.mutation, nil)
	if problem then
		data.sparks += offer.price
		IncomeService.sync(player)
		return false, problem
	end
	offer.stock -= 1
	workspace:SetAttribute("MarketVersion", (workspace:GetAttribute("MarketVersion") or 0) + 1)
	IncomeService.sync(player)
	return true, "🏪 Bought " .. StormData.displayName({ id = offer.def.id, mut = offer.mutation }) .. "!"
end

-- Hatches a jar the player has already paid for. Returns an error message
-- if it couldn't (nothing was given).
local function hatch(player: Player, jar: MarketData.Jar): string?
	if not PlotService.firstFreeSlot(player) then
		return "Your island is full! Buy a pedestal or sell a storm first."
	end
	local options = StormData.wildOfRarity(pickRarity(jar.odds, rng))
	local def = options[rng:NextInteger(1, #options)]
	local mutation = if rng:NextNumber() < jar.mutationChance then RewardService.randomMutation() else nil
	local problem = RewardService.giveStorm(player, def, mutation, nil)
	if problem then
		return problem
	end
	local rarity = StormData.rarityOf(def)
	local mutationDef = StormData.getMutation(mutation)
	Remotes.event("JarHatched"):FireClient(player, {
		jar = jar.name,
		jarEmoji = jar.emoji,
		name = StormData.displayName({ id = def.id, mut = mutation }),
		rarity = rarity.name,
		rarityIndex = rarity.index,
		color = rarity.color,
		mutation = if mutationDef then mutationDef.emoji .. " " .. mutationDef.name else nil,
	})
	if def.rarity >= 5 then
		Notify.allExcept(
			player,
			"🫙 " .. player.DisplayName .. " hatched a LEGENDARY " .. def.name .. " from a " .. jar.name .. "!",
			"rare"
		)
	end
	return nil
end

local function openJar(player: Player, key: any): (boolean, string)
	local data = DataService.get(player)
	local jar = type(key) == "string" and MarketData.jar(key)
	if not data or not jar or slowDown(player) then
		return false, "Can't open that right now."
	end
	if jar.cost <= 0 then
		return false, "That jar is bought with Robux."
	end
	if data.sparks < jar.cost then
		return false, "You need ⚡" .. Format.number(jar.cost - data.sparks) .. " more Sparks."
	end
	if not PlotService.firstFreeSlot(player) then
		return false, "Your island is full! Buy a pedestal or sell a storm first."
	end
	data.sparks -= jar.cost
	local problem = hatch(player, jar)
	if problem then
		data.sparks += jar.cost
		IncomeService.sync(player)
		return false, problem
	end
	IncomeService.sync(player)
	return true, jar.emoji .. " Opening your " .. jar.name .. "..."
end

-- The Robux Golden Jar. If the island is full, it pays 30 minutes of Sparks
-- instead so the purchase is never lost.
function MarketService.openGoldenJar(player: Player): boolean
	local jar = MarketData.jar("Golden")
	if not jar then
		return false
	end
	if hatch(player, jar) then
		local amount = math.floor(math.max(5000, IncomeService.rateOf(player) * 1800))
		IncomeService.addSparks(player, amount)
		Notify.player(
			player,
			"👑 Your island was full, so your Golden Jar paid ⚡" .. Format.number(amount) .. " instead.",
			"warn"
		)
	end
	return true
end

function MarketService.start()
	Remotes.func("GetMarket").OnServerInvoke = getMarket
	Remotes.func("BuyMarket").OnServerInvoke = buyMarket
	Remotes.func("OpenJar").OnServerInvoke = openJar
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
	restock(MarketData.restockIndex(os.time()))
	task.spawn(function()
		while true do
			task.wait(1)
			local index = MarketData.restockIndex(os.time())
			if index ~= restockIndex then
				restock(index)
			end
		end
	end)
end

return MarketService
