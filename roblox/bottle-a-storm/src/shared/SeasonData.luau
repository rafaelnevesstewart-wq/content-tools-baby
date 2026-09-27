--!strict
-- "Stormy Seasons": a season pass that rotates every 4 weeks through four
-- themes, forever (Autumn first, so October 2026 has the Pumpkin Tornado). Earn Season Stars by playing to climb 30 tiers. Every tier
-- has a free reward and a premium reward (Season Premium, bought with Robux).
-- Each theme has 3 exclusive storms you can only get from its pass.

export type Reward = {
	kind: string, -- "sparks" | "snacks" | "shield" | "storm" | "exclusive"
	minutes: number?, -- sparks: this many minutes of your income...
	min: number?, -- ...or at least this much
	amount: number?, -- shield: how many
	rarity: number?, -- storm: random wild storm of this rarity
	mutated: boolean?, -- storm: always has a mutation
	slot: number?, -- exclusive: which of the theme's 3 storms
}

export type Theme = {
	key: string,
	name: string,
	emoji: string,
	color: Color3,
	storms: { string }, -- exclusive storm ids: Epic (free), Legendary, Mythic (premium)
}

local SeasonData = {}

SeasonData.Epoch = 1789948800 -- Monday 21 Sep 2026 00:00 UTC: season 0 starts
SeasonData.LengthDays = 28
SeasonData.Tiers = 30
SeasonData.XpPerTier = 250

SeasonData.Themes = {
	{
		key = "AutumnGusts",
		name = "Autumn Gusts",
		emoji = "🍂",
		color = Color3.fromRGB(235, 130, 60),
		storms = { "LeafyBreeze", "PumpkinTornado", "HarvestMoonSquall" },
	},
	{
		key = "WinterWonder",
		name = "Winter Wonder",
		emoji = "🎄",
		color = Color3.fromRGB(140, 210, 255),
		storms = { "JingleFlurry", "CandyCaneCyclone", "AuroraReindeer" },
	},
	{
		key = "SpringShowers",
		name = "Spring Showers",
		emoji = "🌸",
		color = Color3.fromRGB(255, 160, 200),
		storms = { "BlossomDrizzle", "PetalTwister", "CherryMonsoon" },
	},
	{
		key = "SummerHeatwave",
		name = "Summer Heatwave",
		emoji = "☀️",
		color = Color3.fromRGB(255, 200, 70),
		storms = { "SunnyPuff", "HeatwaveHawk", "TropicalTyphoon" },
	},
} :: { Theme }

-- Tier -> { free, premium }. Edit freely; nil means no reward on that track.
local function sparks(minutes: number, min: number): Reward
	return { kind = "sparks", minutes = minutes, min = min }
end
local SNACKS: Reward = { kind = "snacks" }
local function shield(amount: number): Reward
	return { kind = "shield", amount = amount }
end
local function storm(rarity: number, mutated: boolean?): Reward
	return { kind = "storm", rarity = rarity, mutated = mutated }
end
local function exclusive(slot: number): Reward
	return { kind = "exclusive", slot = slot }
end

SeasonData.Rewards = {
	[1] = { free = sparks(2, 300), premium = sparks(5, 800) },
	[2] = { free = nil, premium = SNACKS },
	[3] = { free = sparks(3, 500), premium = shield(1) },
	[4] = { free = nil, premium = storm(3) },
	[5] = { free = shield(1), premium = sparks(10, 2000) },
	[6] = { free = sparks(4, 800), premium = storm(4) },
	[7] = { free = nil, premium = SNACKS },
	[8] = { free = SNACKS, premium = sparks(10, 3000) },
	[9] = { free = nil, premium = shield(1) },
	[10] = { free = storm(3), premium = exclusive(2) },
	[11] = { free = sparks(5, 1000), premium = sparks(15, 5000) },
	[12] = { free = nil, premium = storm(4, true) },
	[13] = { free = sparks(5, 1500), premium = SNACKS },
	[14] = { free = nil, premium = shield(2) },
	[15] = { free = storm(4), premium = sparks(20, 10000) },
	[16] = { free = nil, premium = storm(5) },
	[17] = { free = sparks(8, 3000), premium = SNACKS },
	[18] = { free = nil, premium = sparks(25, 20000) },
	[19] = { free = shield(1), premium = shield(2) },
	[20] = { free = exclusive(1), premium = storm(5, true) },
	[21] = { free = sparks(10, 5000), premium = sparks(30, 30000) },
	[22] = { free = nil, premium = SNACKS },
	[23] = { free = SNACKS, premium = storm(5) },
	[24] = { free = nil, premium = shield(3) },
	[25] = { free = storm(5), premium = sparks(45, 50000) },
	[26] = { free = nil, premium = storm(5, true) },
	[27] = { free = sparks(15, 10000), premium = SNACKS },
	[28] = { free = nil, premium = sparks(60, 100000) },
	[29] = { free = shield(2), premium = storm(5, true) },
	[30] = { free = sparks(30, 25000), premium = exclusive(3) },
} :: { [number]: { free: Reward?, premium: Reward? } }

-- The season running at unix time `now`.
function SeasonData.current(now: number): (number, Theme, number)
	local length = SeasonData.LengthDays * 86400
	local number = math.max(0, math.floor((now - SeasonData.Epoch) / length))
	local theme = SeasonData.Themes[number % #SeasonData.Themes + 1]
	local endsAt = SeasonData.Epoch + (number + 1) * length
	return number, theme, endsAt
end

function SeasonData.tierFor(xp: number): number
	return math.min(SeasonData.Tiers, math.floor(xp / SeasonData.XpPerTier))
end

return SeasonData
