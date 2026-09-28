--!strict
-- The Bed Wars battle pass. A new season every 4 weeks, rotating through four
-- themes forever (Autumn first). Earn Season Stars by playing matches
-- (knockouts, beds, wins, just playing) to climb 30 tiers. Every tier has a
-- free reward and a premium reward (Battle Pass Premium, bought with Robux).
-- Each theme has 3 exclusive kits and 3 exclusive cosmetics (a trail, a cloud
-- bed and a knockout effect) you can only get from its pass.

export type Reward = {
	kind: string, -- "sparks" | "kit" | "exclusive" | "cosmetic"
	amount: number?, -- sparks: how many
	rarity: number?, -- kit: a random kit of this rarity
	mutated: boolean?, -- kit: always a shiny variant
	slot: number?, -- exclusive / cosmetic: which of the theme's 3
	id: string?, -- cosmetic: a specific cosmetic id instead of a theme slot
}

export type Theme = {
	key: string,
	name: string,
	emoji: string,
	color: Color3,
	storms: { string }, -- exclusive kit ids: Epic (free), Legendary, Mythic (premium)
	cosmetics: { string }, -- exclusive cosmetic ids: trail (free), bed, knockout (premium)
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
		cosmetics = { "AutumnLeavesTrail", "HarvestBed", "PumpkinKO" },
	},
	{
		key = "WinterWonder",
		name = "Winter Wonder",
		emoji = "🎄",
		color = Color3.fromRGB(140, 210, 255),
		storms = { "JingleFlurry", "CandyCaneCyclone", "AuroraReindeer" },
		cosmetics = { "CandyCaneTrail", "SnowGlobeBed", "SnowmanKO" },
	},
	{
		key = "SpringShowers",
		name = "Spring Showers",
		emoji = "🌸",
		color = Color3.fromRGB(255, 160, 200),
		storms = { "BlossomDrizzle", "PetalTwister", "CherryMonsoon" },
		cosmetics = { "PetalTrail", "BlossomBed", "BlossomKO" },
	},
	{
		key = "SummerHeatwave",
		name = "Summer Heatwave",
		emoji = "☀️",
		color = Color3.fromRGB(255, 200, 70),
		storms = { "SunnyPuff", "HeatwaveHawk", "SolsticeTyphoon" },
		cosmetics = { "SunbeamTrail", "BeachBed", "SunflareKO" },
	},
} :: { Theme }

-- Tier -> { free, premium }. Edit freely; nil means no reward on that track.
local function sparks(amount: number): Reward
	return { kind = "sparks", amount = amount }
end
local function kit(rarity: number, mutated: boolean?): Reward
	return { kind = "kit", rarity = rarity, mutated = mutated }
end
local function exclusive(slot: number): Reward
	return { kind = "exclusive", slot = slot }
end
local function cosmetic(slot: number): Reward
	return { kind = "cosmetic", slot = slot }
end

SeasonData.Rewards = {
	[1] = { free = sparks(150), premium = sparks(400) },
	[2] = { free = nil, premium = kit(2) },
	[3] = { free = sparks(200), premium = cosmetic(3) },
	[4] = { free = nil, premium = sparks(600) },
	[5] = { free = kit(2), premium = kit(3) },
	[6] = { free = sparks(300), premium = sparks(800) },
	[7] = { free = nil, premium = kit(3, true) },
	[8] = { free = sparks(400), premium = sparks(1000) },
	[9] = { free = nil, premium = kit(4) },
	[10] = { free = kit(3), premium = exclusive(2) },
	[11] = { free = sparks(500), premium = sparks(1200) },
	[12] = { free = nil, premium = kit(4, true) },
	[13] = { free = sparks(600), premium = sparks(1500) },
	[14] = { free = nil, premium = kit(4) },
	[15] = { free = cosmetic(1), premium = sparks(2000) },
	[16] = { free = nil, premium = kit(5) },
	[17] = { free = sparks(800), premium = sparks(2500) },
	[18] = { free = nil, premium = cosmetic(2) },
	[19] = { free = kit(3, true), premium = sparks(3000) },
	[20] = { free = exclusive(1), premium = kit(5, true) },
	[21] = { free = sparks(1000), premium = sparks(3500) },
	[22] = { free = nil, premium = kit(5) },
	[23] = { free = kit(4), premium = sparks(4000) },
	[24] = { free = nil, premium = kit(6) },
	[25] = { free = sparks(1500), premium = sparks(5000) },
	[26] = { free = nil, premium = kit(5, true) },
	[27] = { free = kit(4, true), premium = sparks(6000) },
	[28] = { free = nil, premium = kit(6, true) },
	[29] = { free = sparks(2000), premium = sparks(8000) },
	[30] = { free = kit(5), premium = exclusive(3) },
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
