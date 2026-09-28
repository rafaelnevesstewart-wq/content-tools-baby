--!strict
-- The 🏪 Kit Market: the Kit Shop (6 kits with limited stock that restocks
-- every 5 minutes) and Kit Crates (open one for a random kit).

export type Crate = {
	key: string,
	name: string,
	emoji: string,
	cost: number, -- Sparks; 0 = Robux (the "GoldenKitCrate" product)
	odds: { number }, -- chance per rarity, Common .. Cosmic (they add up to 100)
	mutationChance: number, -- chance the kit is a shiny variant
	color: Color3,
}

local MarketData = {}

MarketData.Crates = {
	{
		key = "Cloud",
		name = "Cloud Crate",
		emoji = "☁️",
		cost = 500,
		odds = { 65, 27, 7, 1, 0, 0, 0 },
		mutationChance = 0.03,
		color = Color3.fromRGB(200, 215, 235),
	},
	{
		key = "Thunder",
		name = "Thunder Crate",
		emoji = "⚡",
		cost = 2500,
		odds = { 0, 45, 35, 15, 4.5, 0.5, 0 },
		mutationChance = 0.06,
		color = Color3.fromRGB(255, 205, 80),
	},
	{
		key = "Cosmic",
		name = "Cosmic Crate",
		emoji = "🌌",
		cost = 12000,
		odds = { 0, 0, 35, 38, 20, 5.5, 1.5 },
		mutationChance = 0.1,
		color = Color3.fromRGB(150, 110, 240),
	},
	{
		key = "Golden",
		name = "Golden Crate",
		emoji = "👑",
		cost = 0,
		odds = { 0, 0, 0, 60, 30, 8, 2 },
		mutationChance = 1, -- always shiny
		color = Color3.fromRGB(255, 200, 60),
	},
} :: { Crate }

-- The Kit Shop restocks every RestockSeconds. Every server gets the same
-- stock at the same time (it's seeded by the restock number).
MarketData.RestockSeconds = 300
MarketData.Slots = 6
MarketData.RarityWeights = { 40, 30, 18, 8, 3, 0.8, 0.2 } -- Common .. Cosmic
MarketData.StockRange = { 1, 3 } -- how many of each kit are for sale
MarketData.Prices = { 250, 600, 1500, 4000, 10000, 25000, 60000 } -- Sparks, by rarity
MarketData.ShinyPriceMultiplier = 2
MarketData.MutationChance = 0.08

function MarketData.crate(key: string): Crate?
	for _, crate in MarketData.Crates do
		if crate.key == key then
			return crate
		end
	end
	return nil
end

function MarketData.restockIndex(now: number): number
	return math.floor(now / MarketData.RestockSeconds)
end

return MarketData
