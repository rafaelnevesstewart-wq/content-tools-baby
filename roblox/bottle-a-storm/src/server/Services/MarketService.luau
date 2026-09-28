-- The 🏪 Kit Market.
--   * Kit Shop: 6 kits with limited stock, restocked every 5 minutes. Every
--     server gets the same stock at the same time, and stock is shared: first
--     come, first served.
--   * Kit Crates: pay, then open a random kit with the crate's odds. The
--     client plays the opening animation.

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

local function kitOfRarity(rarity: number, random: Random): StormData.StormDef
	local options = StormData.ofRarity(rarity)
	while #options == 0 and rarity > 1 do
		rarity -= 1
		options = StormData.ofRarity(rarity)
	end
	return options[random:NextInteger(1, #options)]
end

local function restock(index: number)
	restockIndex = index
	local random = Random.new(index)
	offers = {}
	local used: { [string]: boolean } = {}
	local hasLegendary = false
	for _ = 1, MarketData.Slots do
		local def
		for _ = 1, 10 do -- avoid showing the same kit twice
			def = kitOfRarity(pickRarity(MarketData.RarityWeights, random), random)
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
		local price = MarketData.Prices[def.rarity] or 1000
		if mutation then
			price *= MarketData.ShinyPriceMultiplier
		end
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
		Notify.all("🏪 The Kit Shop restocked, and there's a LEGENDARY kit in stock! Hurry!", "rare")
	else
		Notify.all("🏪 The Kit Shop restocked! Check out the new kits.", "info")
	end
end

local function getMarket(_player: Player)
	local list = {}
	for _, offer in offers do
		local ability = StormData.AbilityInfo[StormData.abilityOf(offer.def)]
		table.insert(list, {
			id = offer.def.id,
			mut = offer.mutation,
			price = offer.price,
			stock = offer.stock,
			power = ability.emoji .. " " .. ability.name,
		})
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
	if data.sparks < offer.price then
		return false, "You need ⚡" .. Format.number(offer.price - data.sparks) .. " more Sparks."
	end
	data.sparks -= offer.price
	local problem = RewardService.giveKit(player, offer.def, offer.mutation)
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

-- Opens a crate the player has already paid for. Returns an error message if
-- it couldn't (nothing was given).
local function openCrate(player: Player, crate: MarketData.Crate): string?
	local def = kitOfRarity(pickRarity(crate.odds, rng), rng)
	local mutation = if rng:NextNumber() < crate.mutationChance then RewardService.randomMutation() else nil
	local problem = RewardService.giveKit(player, def, mutation)
	if problem then
		return problem
	end
	local rarity = StormData.rarityOf(def)
	local mutationDef = StormData.getMutation(mutation)
	local ability = StormData.AbilityInfo[StormData.abilityOf(def)]
	Remotes.event("CrateOpened"):FireClient(player, {
		crate = crate.name,
		crateEmoji = crate.emoji,
		name = StormData.displayName({ id = def.id, mut = mutation }),
		rarity = rarity.name,
		rarityIndex = rarity.index,
		color = rarity.color,
		mutation = if mutationDef then mutationDef.emoji .. " " .. mutationDef.name else nil,
		power = ability.emoji .. " " .. ability.name,
	})
	if def.rarity >= 5 then
		Notify.allExcept(
			player,
			"🎁 " .. player.DisplayName .. " opened a " .. string.upper(rarity.name) .. " " .. def.name .. " kit!",
			"rare"
		)
	end
	return nil
end

local function onOpen(player: Player, key: any): (boolean, string)
	local data = DataService.get(player)
	local crate = type(key) == "string" and MarketData.crate(key)
	if not data or not crate or slowDown(player) then
		return false, "Can't open that right now."
	end
	if crate.cost <= 0 then
		return false, "That crate is bought with Robux."
	end
	if data.sparks < crate.cost then
		return false, "You need ⚡" .. Format.number(crate.cost - data.sparks) .. " more Sparks."
	end
	data.sparks -= crate.cost
	local problem = openCrate(player, crate)
	if problem then
		data.sparks += crate.cost
		IncomeService.sync(player)
		return false, problem
	end
	IncomeService.sync(player)
	return true, crate.emoji .. " Opening your " .. crate.name .. "..."
end

-- The Robux Golden Crate.
function MarketService.openGoldenCrate(player: Player): boolean
	local crate = MarketData.crate("Golden")
	return crate ~= nil and openCrate(player, crate) == nil
end

function MarketService.start()
	Remotes.func("GetMarket").OnServerInvoke = getMarket
	Remotes.func("BuyMarket").OnServerInvoke = buyMarket
	Remotes.func("OpenCrate").OnServerInvoke = onOpen
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
