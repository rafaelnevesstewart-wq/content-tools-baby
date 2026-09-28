--!strict
-- Bed Wars cosmetics, bought in the 🎨 Style window: your look (hat, trail,
-- back, aura), your team's cloud bed, your sword and arrows, and the effect
-- when you knock someone out. Most cost Sparks; a few cost Robux (a Developer
-- Product each, listed in Products.Cosmetics under the key "Cosmetic_<id>");
-- some only come from the battle pass. What each one looks like is built in
-- CosmeticService (swords and arrows in SkinData).

export type Item = {
	id: string,
	category: string, -- hat, trail, back, aura, bed, sword, fx, ko, dance
	name: string,
	emoji: string,
	cost: number, -- Sparks; 0 = free
	robux: boolean?, -- bought with Robux instead (see Products.Cosmetics)
	season: string?, -- only from this season's battle pass (see SeasonData)
	achievement: boolean?, -- only from an achievement (see ProgressionData)
	emote: string?, -- dances: the Roblox emote your character plays
	description: string,
}

export type Category = {
	key: string,
	name: string,
	emoji: string,
}

local CosmeticsData = {}

CosmeticsData.Categories = {
	{ key = "hat", name = "Hats", emoji = "🎩" },
	{ key = "trail", name = "Trails", emoji = "✨" },
	{ key = "back", name = "Backs", emoji = "🪽" },
	{ key = "aura", name = "Auras", emoji = "💫" },
	{ key = "bed", name = "Cloud Beds", emoji = "🛏️" },
	{ key = "sword", name = "Sword Skins", emoji = "🗡️" },
	{ key = "fx", name = "Arrow Effects", emoji = "🏹" },
	{ key = "ko", name = "Knockout Effects", emoji = "💥" },
	{ key = "dance", name = "Victory Dances", emoji = "💃" },
} :: { Category }

CosmeticsData.Items = {
	-- Hats
	{
		id = "CloudHat",
		category = "hat",
		name = "Rain Cloud Hat",
		emoji = "☁️",
		cost = 100,
		description = "A little cloud that drizzles on your head.",
	},
	{
		id = "LightningCrown",
		category = "hat",
		name = "Lightning Crown",
		emoji = "⚡",
		cost = 750,
		description = "A sparking crown of zigzags.",
	},
	{
		id = "RainbowCap",
		category = "hat",
		name = "Rainbow Cap",
		emoji = "🌈",
		cost = 2000,
		description = "A striped cap in every color.",
	},
	{
		id = "SnowBeanie",
		category = "hat",
		name = "Snowflake Beanie",
		emoji = "❄️",
		cost = 5000,
		description = "A cozy beanie with falling snowflakes.",
	},
	{
		id = "TornadoTopHat",
		category = "hat",
		name = "Tornado Top Hat",
		emoji = "🎩",
		cost = 20000,
		description = "A fancy top hat with a swirling breeze.",
	},
	{
		id = "GoldenCrown",
		category = "hat",
		name = "Golden Storm Crown",
		emoji = "👑",
		cost = 0,
		robux = true,
		description = "A shiny golden crown with sparkles.",
	},
	{
		id = "InfernoCrown",
		category = "hat",
		name = "Inferno Crown",
		emoji = "🔥",
		cost = 75000,
		description = "A black crown wreathed in real flames.",
	},
	{
		id = "StormHalo",
		category = "hat",
		name = "Storm Halo",
		emoji = "🌩️",
		cost = 0,
		robux = true,
		description = "A spinning halo that crackles with lightning.",
	},

	-- Trails
	{
		id = "RainbowTrail",
		category = "trail",
		name = "Rainbow Trail",
		emoji = "🌈",
		cost = 250,
		description = "Leave a rainbow wherever you run.",
	},
	{
		id = "SparkleTrail",
		category = "trail",
		name = "Sparkle Trail",
		emoji = "✨",
		cost = 1000,
		description = "Glittery golden sparkles.",
	},
	{
		id = "SnowTrail",
		category = "trail",
		name = "Snowflake Trail",
		emoji = "❄️",
		cost = 4000,
		description = "A frosty trail of snowflakes.",
	},
	{
		id = "LightningTrail",
		category = "trail",
		name = "Lightning Trail",
		emoji = "⚡",
		cost = 10000,
		description = "A crackling bolt behind you.",
	},
	{
		id = "BubbleTrail",
		category = "trail",
		name = "Bubble Trail",
		emoji = "🫧",
		cost = 30000,
		description = "Floaty soap bubbles.",
	},
	{
		id = "GalaxyTrail",
		category = "trail",
		name = "Galaxy Trail",
		emoji = "🌌",
		cost = 0,
		robux = true,
		description = "A starry purple galaxy streak.",
	},
	{
		id = "FireTrail",
		category = "trail",
		name = "Fire Trail",
		emoji = "🔥",
		cost = 2000,
		description = "Real flames lick the ground behind you.",
	},
	{
		id = "SakuraTrail",
		category = "trail",
		name = "Cherry Blossom Trail",
		emoji = "🌸",
		cost = 2000,
		description = "Pink petals drift down as you run.",
	},
	{
		id = "TornadoTrail",
		category = "trail",
		name = "Tornado Trail",
		emoji = "🌪️",
		cost = 4500,
		description = "A swirling gray whirlwind follows you.",
	},
	{
		id = "AuroraTrail",
		category = "trail",
		name = "Aurora Trail",
		emoji = "🟢",
		cost = 7500,
		description = "Wide glowing ribbons like the northern lights.",
	},
	{
		id = "ShadowTrail",
		category = "trail",
		name = "Shadow Trail",
		emoji = "🖤",
		cost = 10000,
		description = "Dark smoke with a purple edge.",
	},
	{
		id = "PlasmaTrail",
		category = "trail",
		name = "Plasma Trail",
		emoji = "🔷",
		cost = 20000,
		description = "A blazing cyan energy beam.",
	},
	{
		id = "StarfallTrail",
		category = "trail",
		name = "Starfall Trail",
		emoji = "🌠",
		cost = 50000,
		description = "Golden stars rain down behind you.",
	},
	{
		id = "ThunderstormTrail",
		category = "trail",
		name = "Thunderstorm Trail",
		emoji = "⛈️",
		cost = 0,
		robux = true,
		description = "Storm clouds and crackling lightning.",
	},
	{
		id = "PhoenixTrail",
		category = "trail",
		name = "Phoenix Trail",
		emoji = "🐦‍🔥",
		cost = 0,
		robux = true,
		description = "Huge golden fire wings of flame.",
	},

	-- Backs
	{
		id = "ArrowQuiver",
		category = "back",
		name = "Arrow Quiver",
		emoji = "🏹",
		cost = 150,
		description = "A leather quiver full of glowing arrows.",
	},
	{
		id = "CloudWings",
		category = "back",
		name = "Cloud Wings",
		emoji = "☁️",
		cost = 1500,
		description = "Two fluffy cloud wings.",
	},
	{
		id = "ButterflyWings",
		category = "back",
		name = "Butterfly Wings",
		emoji = "🦋",
		cost = 6000,
		description = "Pretty pastel butterfly wings.",
	},
	{
		id = "MiniTornado",
		category = "back",
		name = "Mini Tornado",
		emoji = "🌪️",
		cost = 25000,
		description = "A tiny tornado that follows your back.",
	},
	{
		id = "RainbowWings",
		category = "back",
		name = "Rainbow Wings",
		emoji = "🌈",
		cost = 0,
		robux = true,
		description = "Big glowing rainbow wings.",
	},
	{
		id = "PhoenixWings",
		category = "back",
		name = "Phoenix Wings",
		emoji = "🐦‍🔥",
		cost = 100000,
		description = "Blazing wings of fire.",
	},
	{
		id = "LightningWings",
		category = "back",
		name = "Lightning Wings",
		emoji = "⚡",
		cost = 0,
		robux = true,
		description = "Electric wings with crackling bolts.",
	},

	-- Auras
	{
		id = "SparkleAura",
		category = "aura",
		name = "Sparkle Aura",
		emoji = "✨",
		cost = 400,
		description = "Sparkles float all around you.",
	},
	{
		id = "RainHalo",
		category = "aura",
		name = "Rain Halo",
		emoji = "🌧️",
		cost = 2500,
		description = "Gentle rain falling around you.",
	},
	{
		id = "LightningOrbit",
		category = "aura",
		name = "Lightning Orbit",
		emoji = "⚡",
		cost = 15000,
		description = "Crackling sparks zip around you.",
	},
	{
		id = "HeartAura",
		category = "aura",
		name = "Love Aura",
		emoji = "💕",
		cost = 0,
		robux = true,
		description = "Soft pink sparkles and a warm glow float up around you.",
	},
	{
		id = "RainbowAura",
		category = "aura",
		name = "Rainbow Aura",
		emoji = "🌈",
		cost = 20000,
		description = "Every color of the rainbow swirls around you.",
	},
	{
		id = "InfernoAura",
		category = "aura",
		name = "Inferno Aura",
		emoji = "🔥",
		cost = 40000,
		description = "You're surrounded by real flames.",
	},
	{
		id = "ThunderGodAura",
		category = "aura",
		name = "Thunder God",
		emoji = "⚡",
		cost = 100000,
		description = "Lightning bolts crackle all around you.",
	},

	-- Cloud Beds (your team's bed uses the first teammate's pick)
	{
		id = "Cumulus",
		category = "bed",
		name = "Cumulus Bed",
		emoji = "☁️",
		cost = 0,
		description = "The classic fluffy white cloud bed.",
	},
	{
		id = "StormCloudSkin",
		category = "bed",
		name = "Storm Bed",
		emoji = "🌧️",
		cost = 250,
		description = "A dark rain cloud bed that drizzles.",
	},
	{
		id = "SunsetCloud",
		category = "bed",
		name = "Sunset Bed",
		emoji = "🌅",
		cost = 750,
		description = "A glowing orange and pink sunset bed.",
	},
	{
		id = "SnowCloud",
		category = "bed",
		name = "Snow Bed",
		emoji = "🌨️",
		cost = 2000,
		description = "A cold blue-white bed dropping snowflakes.",
	},
	{
		id = "RainbowCloud",
		category = "bed",
		name = "Rainbow Bed",
		emoji = "🌈",
		cost = 6000,
		description = "Soft rainbow layers with sparkles.",
	},
	{
		id = "GoldenCloud",
		category = "bed",
		name = "Golden Bed",
		emoji = "✨",
		cost = 20000,
		description = "A shining gold bed for true champions.",
	},
	{
		id = "ThunderCloudSkin",
		category = "bed",
		name = "Thunder Bed",
		emoji = "⚡",
		cost = 0,
		robux = true,
		description = "A black thundercloud bed that flashes with lightning.",
	},
	{
		id = "AuroraCloud",
		category = "bed",
		name = "Aurora Bed",
		emoji = "🌌",
		cost = 0,
		robux = true,
		description = "A glowing green and purple aurora bed.",
	},
	{
		id = "InfernoCloud",
		category = "bed",
		name = "Inferno Bed",
		emoji = "🔥",
		cost = 10000,
		description = "A blazing bed of real fire and embers.",
	},
	{
		id = "ThunderboltCloud",
		category = "bed",
		name = "Thunderbolt Bed",
		emoji = "🌩️",
		cost = 30000,
		description = "Lightning bolts crackle all around your bed.",
	},
	{
		id = "PrismCloud",
		category = "bed",
		name = "Prism Bed",
		emoji = "💎",
		cost = 0,
		robux = true,
		description = "A glowing bed that shifts through every color.",
	},
	{
		id = "GalaxyCloud",
		category = "bed",
		name = "Galaxy Bed",
		emoji = "🌌",
		cost = 75000,
		description = "A starry nebula to sleep on.",
	},
	{
		id = "VoidCloud",
		category = "bed",
		name = "Void Bed",
		emoji = "🕳️",
		cost = 0,
		robux = true,
		description = "A black bed with a throbbing purple heart.",
	},

	-- Sword skins
	{
		id = "ClassicBlade",
		category = "sword",
		name = "Classic Blade",
		emoji = "🗡️",
		cost = 0,
		description = "Your sword's normal look: wood, stone, iron or diamond.",
	},
	{
		id = "CrystalBlade",
		category = "sword",
		name = "Crystal Blade",
		emoji = "💜",
		cost = 750,
		description = "A violet crystal blade with a soft glow.",
	},
	{
		id = "FrostBlade",
		category = "sword",
		name = "Frost Blade",
		emoji = "❄️",
		cost = 3000,
		description = "A blade of solid ice with glittering frost.",
	},
	{
		id = "GoldenBlade",
		category = "sword",
		name = "Golden Blade",
		emoji = "✨",
		cost = 10000,
		description = "A shining gold blade.",
	},
	{
		id = "LavaBlade",
		category = "sword",
		name = "Lava Blade",
		emoji = "🔥",
		cost = 40000,
		description = "Cracked lava stone that burns with real fire.",
	},
	{
		id = "GalaxyBlade",
		category = "sword",
		name = "Galaxy Blade",
		emoji = "🌌",
		cost = 0,
		robux = true,
		description = "A glowing blade full of stars.",
	},
	{
		id = "DiamondBlade",
		category = "sword",
		name = "Diamond Blade",
		emoji = "💎",
		cost = 0,
		robux = true,
		description = "A flawless sparkling diamond blade.",
	},

	-- Arrow effects
	{
		id = "ClassicZap",
		category = "fx",
		name = "Classic Arrows",
		emoji = "⚡",
		cost = 0,
		description = "Bright yellow arrows.",
	},
	{
		id = "FireBlast",
		category = "fx",
		name = "Fire Arrows",
		emoji = "🔥",
		cost = 1000,
		description = "Flaming orange arrows.",
	},
	{
		id = "FrostBeam",
		category = "fx",
		name = "Frost Arrows",
		emoji = "❄️",
		cost = 3000,
		description = "Icy blue arrows.",
	},
	{
		id = "RainbowBeam",
		category = "fx",
		name = "Rainbow Arrows",
		emoji = "🌈",
		cost = 7500,
		description = "Candy pink arrows.",
	},
	{
		id = "VoidRay",
		category = "fx",
		name = "Void Arrows",
		emoji = "🕳️",
		cost = 25000,
		description = "Deep purple arrows from the void.",
	},
	{
		id = "GoldenRay",
		category = "fx",
		name = "Golden Arrows",
		emoji = "✨",
		cost = 0,
		robux = true,
		description = "Shining golden arrows.",
	},

	-- Knockout effects: what bursts out when you knock someone out.
	{
		id = "Poof",
		category = "ko",
		name = "Cloud Poof",
		emoji = "💨",
		cost = 0,
		description = "A soft puff of cloud.",
	},
	{
		id = "ConfettiKO",
		category = "ko",
		name = "Confetti Pop",
		emoji = "🎉",
		cost = 400,
		description = "A shower of party confetti.",
	},
	{
		id = "LightningKO",
		category = "ko",
		name = "Lightning Strike",
		emoji = "⚡",
		cost = 2000,
		description = "A bolt of lightning strikes where they fell.",
	},
	{
		id = "FrostKO",
		category = "ko",
		name = "Frost Shatter",
		emoji = "🧊",
		cost = 4500,
		description = "They shatter into ice crystals.",
	},
	{
		id = "TornadoKO",
		category = "ko",
		name = "Tornado Spin",
		emoji = "🌪️",
		cost = 10000,
		description = "A tornado whisks them away.",
	},
	{
		id = "FireworkKO",
		category = "ko",
		name = "Firework Show",
		emoji = "🎆",
		cost = 35000,
		description = "Fireworks burst in the sky.",
	},
	{
		id = "InfernoKO",
		category = "ko",
		name = "Inferno Blast",
		emoji = "🔥",
		cost = 75000,
		description = "An explosion of real fire.",
	},
	{
		id = "GoldenRainKO",
		category = "ko",
		name = "Golden Rain",
		emoji = "💰",
		cost = 0,
		robux = true,
		description = "Golden sparks rain down on the spot.",
	},
	{
		id = "VoidKO",
		category = "ko",
		name = "Void Rift",
		emoji = "🌑",
		cost = 0,
		robux = true,
		description = "A purple rift swallows them.",
	},

	-- Battle pass exclusives (see SeasonData): only from that season's pass.
	{
		id = "AutumnLeavesTrail",
		category = "trail",
		name = "Falling Leaves Trail",
		emoji = "🍁",
		cost = 0,
		season = "AutumnGusts",
		description = "Orange leaves swirl behind you.",
	},
	{
		id = "HarvestBed",
		category = "bed",
		name = "Harvest Moon Bed",
		emoji = "🎃",
		cost = 0,
		season = "AutumnGusts",
		description = "A glowing pumpkin-orange bed.",
	},
	{
		id = "PumpkinKO",
		category = "ko",
		name = "Pumpkin Smash",
		emoji = "🎃",
		cost = 0,
		season = "AutumnGusts",
		description = "A pumpkin bursts into sparks.",
	},
	{
		id = "CandyCaneTrail",
		category = "trail",
		name = "Candy Cane Trail",
		emoji = "🍬",
		cost = 0,
		season = "WinterWonder",
		description = "A red and white striped trail.",
	},
	{
		id = "SnowGlobeBed",
		category = "bed",
		name = "Snow Globe Bed",
		emoji = "🎄",
		cost = 0,
		season = "WinterWonder",
		description = "A frosty bed with twinkling lights.",
	},
	{
		id = "SnowmanKO",
		category = "ko",
		name = "Snowman Blizzard",
		emoji = "☃️",
		cost = 0,
		season = "WinterWonder",
		description = "A burst of snow and ice.",
	},
	{
		id = "PetalTrail",
		category = "trail",
		name = "Cherry Petal Trail",
		emoji = "🌸",
		cost = 0,
		season = "SpringShowers",
		description = "Pink petals drift behind you.",
	},
	{
		id = "BlossomBed",
		category = "bed",
		name = "Blossom Bed",
		emoji = "🌸",
		cost = 0,
		season = "SpringShowers",
		description = "A pink bed covered in blossoms.",
	},
	{
		id = "BlossomKO",
		category = "ko",
		name = "Blossom Burst",
		emoji = "🌺",
		cost = 0,
		season = "SpringShowers",
		description = "A cloud of flower petals.",
	},
	{
		id = "SunbeamTrail",
		category = "trail",
		name = "Sunbeam Trail",
		emoji = "☀️",
		cost = 0,
		season = "SummerHeatwave",
		description = "A warm golden sun trail.",
	},
	{
		id = "BeachBed",
		category = "bed",
		name = "Sunny Beach Bed",
		emoji = "🏖️",
		cost = 0,
		season = "SummerHeatwave",
		description = "A sunny golden bed that glows.",
	},
	{
		id = "SunflareKO",
		category = "ko",
		name = "Solar Flare",
		emoji = "🌞",
		cost = 0,
		season = "SummerHeatwave",
		description = "A blinding burst of sunlight.",
	},

	-- Victory dances: your character dances when your team wins.
	{
		id = "Cheer",
		category = "dance",
		name = "Cheer",
		emoji = "🙌",
		cost = 0,
		emote = "cheer",
		description = "Throw your arms up when your team wins.",
	},
	{
		id = "Wave",
		category = "dance",
		name = "Wave",
		emoji = "👋",
		cost = 150,
		emote = "wave",
		description = "Wave goodbye to the losers.",
	},
	{
		id = "Point",
		category = "dance",
		name = "Point",
		emoji = "👉",
		cost = 250,
		emote = "point",
		description = "Point at the beaten teams.",
	},
	{
		id = "Laugh",
		category = "dance",
		name = "Laugh",
		emoji = "😂",
		cost = 500,
		emote = "laugh",
		description = "Laugh it up after the win.",
	},
	{
		id = "Dance1",
		category = "dance",
		name = "Groove",
		emoji = "🕺",
		cost = 1500,
		emote = "dance",
		description = "A classic victory groove.",
	},
	{
		id = "Dance2",
		category = "dance",
		name = "Spin Move",
		emoji = "💃",
		cost = 4000,
		emote = "dance2",
		description = "Show off your best spin.",
	},
	{
		id = "Dance3",
		category = "dance",
		name = "Robot",
		emoji = "🤖",
		cost = 10000,
		emote = "dance3",
		description = "Do the robot. Legendary.",
	},

	-- Achievement rewards (see ProgressionData): only from achievements.
	{
		id = "ChampionTrail",
		category = "trail",
		name = "Champion Trail",
		emoji = "🏆",
		cost = 0,
		achievement = true,
		description = "Gold and violet light. Win 200 matches to earn it.",
	},
	{
		id = "VeteranBed",
		category = "bed",
		name = "Veteran Bed",
		emoji = "🎖️",
		cost = 0,
		achievement = true,
		description = "A medal-gold bed. Play 500 matches to earn it.",
	},
	{
		id = "LegendKO",
		category = "ko",
		name = "Legend Strike",
		emoji = "⚡",
		cost = 0,
		achievement = true,
		description = "A golden lightning storm. 1,000 knockouts to earn it.",
	},
} :: { Item }

-- What you have when nothing else is picked (free, always owned).
CosmeticsData.Defaults = {
	bed = "Cumulus",
	sword = "ClassicBlade",
	fx = "ClassicZap",
	ko = "Poof",
	dance = "Cheer",
} :: { [string]: string }

-- Rarity tiers. Every cosmetic you wear or place adds its tier's bonus to
-- your Style Bonus: extra Sparks from matches (see Config.Style).
export type Tier = { name: string, color: Color3, bonus: number }

CosmeticsData.Tiers = {
	Basic = { name = "Basic", color = Color3.fromRGB(150, 160, 182), bonus = 0 },
	Common = { name = "Common", color = Color3.fromRGB(200, 205, 215), bonus = 0.01 },
	Rare = { name = "Rare", color = Color3.fromRGB(80, 160, 255), bonus = 0.02 },
	Epic = { name = "Epic", color = Color3.fromRGB(190, 90, 255), bonus = 0.04 },
	Legendary = { name = "Legendary", color = Color3.fromRGB(255, 190, 40), bonus = 0.06 },
	Mythic = { name = "Mythic", color = Color3.fromRGB(255, 80, 140), bonus = 0.08 },
} :: { [string]: Tier }

function CosmeticsData.tierOf(item: Item): Tier
	local tiers = CosmeticsData.Tiers
	if item.robux then
		return tiers.Mythic
	elseif item.cost <= 0 then
		return tiers.Basic
	elseif item.season or item.achievement then
		return tiers.Epic
	elseif item.cost < 500 then
		return tiers.Common
	elseif item.cost < 5000 then
		return tiers.Rare
	elseif item.cost < 50000 then
		return tiers.Epic
	end
	return tiers.Legendary
end

local byId: { [string]: Item } = {}
for _, item in CosmeticsData.Items do
	byId[item.id] = item
end

function CosmeticsData.get(id: string?): Item?
	return if id then byId[id] else nil
end

function CosmeticsData.category(key: string): Category?
	for _, category in CosmeticsData.Categories do
		if category.key == key then
			return category
		end
	end
	return nil
end

-- The Developer Product key for a Robux cosmetic.
function CosmeticsData.productKey(id: string): string
	return "Cosmetic_" .. id
end

return CosmeticsData
