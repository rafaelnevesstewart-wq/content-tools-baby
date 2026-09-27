--!strict
-- The Storm Market (restocking shop) and Mystery Jars (hatch a random storm).

export type Jar = {
	key: string,
	name: string,
	emoji: string,
	cost: number, -- Sparks; 0 = Robux (the "MysteryGoldenJar" product)
	odds: { number }, -- chance per rarity, Common .. Legendary (they add up to 100)
	mutationChance: number,
	color: Color3,
}

local MarketData = {}

MarketData.Jars = {
	{
		key = "Cloud",
		name = "Cloud Jar",
		emoji = "☁️",
		cost = 1000,
		odds = { 70, 25, 5, 0, 0 },
		mutationChance = 0.03,
		color = Color3.fromRGB(200, 215, 235),
	},
	{
		key = "Thunder",
		name = "Thunder Jar",
		emoji = "⚡",
		cost = 25000,
		odds = { 0, 50, 35, 13, 2 },
		mutationChance = 0.06,
		color = Color3.fromRGB(255, 205, 80),
	},
	{
		key = "Cosmic",
		name = "Cosmic Jar",
		emoji = "🌌",
		cost = 750000,
		odds = { 0, 0, 45, 40, 15 },
		mutationChance = 0.1,
		color = Color3.fromRGB(150, 110, 240),
	},
	{
		key = "Golden",
		name = "Golden Jar",
		emoji = "👑",
		cost = 0,
		odds = { 0, 0, 0, 70, 30 },
		mutationChance = 1, -- always mutated
		color = Color3.fromRGB(255, 200, 60),
	},
} :: { Jar }

-- The Storm Market restocks every RestockSeconds. Every server gets the same
-- stock at the same time (it's seeded by the restock number).
MarketData.RestockSeconds = 300
MarketData.Slots = 6
MarketData.RarityWeights = { 45, 30, 17, 6.5, 1.5 } -- Common .. Legendary
MarketData.StockRange = { 1, 3 } -- how many of each storm are for sale
MarketData.PriceSeconds = 120 -- price = this many seconds of the storm's base income...
MarketData.MinPrice = 80 -- ...or at least this
MarketData.MutationChance = 0.08

function MarketData.jar(key: string): Jar?
	for _, jar in MarketData.Jars do
		if jar.key == key then
			return jar
		end
	end
	return nil
end

function MarketData.restockIndex(now: number): number
	return math.floor(now / MarketData.RestockSeconds)
end

return MarketData
