--!strict
-- Cosmetics for your character and your island, bought in the 🎨 Style window.
-- Most cost Sparks; a few special ones cost Robux (a Developer Product each,
-- listed in Products.Cosmetics under the key "Cosmetic_<id>").
-- What each one looks like is built in CosmeticService.

export type Item = {
	id: string,
	category: string, -- hat, trail, back, aura, pedestal, decor, flag, pet
	name: string,
	emoji: string,
	cost: number, -- Sparks; 0 = free
	robux: boolean?, -- bought with Robux instead (see Products.Cosmetics)
	description: string,
}

export type Category = {
	key: string,
	name: string,
	emoji: string,
	multi: boolean?, -- you can use several at once (decorations, pets)
	max: number?,
	island: boolean?,
}

local CosmeticsData = {}

CosmeticsData.Categories = {
	{ key = "hat", name = "Hats", emoji = "🎩" },
	{ key = "trail", name = "Trails", emoji = "✨" },
	{ key = "back", name = "Backs", emoji = "🪽" },
	{ key = "aura", name = "Auras", emoji = "💫" },
	{ key = "pedestal", name = "Pedestals", emoji = "🏛️", island = true },
	{ key = "decor", name = "Decor", emoji = "⛲", multi = true, island = true },
	{ key = "flag", name = "Sign & Flag", emoji = "🚩", island = true },
	{ key = "pet", name = "Island Pets", emoji = "🐤", multi = true, max = 3, island = true },
} :: { Category }

CosmeticsData.Items = {
	-- Hats
	{
		id = "CloudHat",
		category = "hat",
		name = "Rain Cloud Hat",
		emoji = "☁️",
		cost = 2000,
		description = "A little cloud that drizzles on your head.",
	},
	{
		id = "LightningCrown",
		category = "hat",
		name = "Lightning Crown",
		emoji = "⚡",
		cost = 15000,
		description = "A sparking crown of zigzags.",
	},
	{
		id = "RainbowCap",
		category = "hat",
		name = "Rainbow Cap",
		emoji = "🌈",
		cost = 40000,
		description = "A striped cap in every color.",
	},
	{
		id = "SnowBeanie",
		category = "hat",
		name = "Snowflake Beanie",
		emoji = "❄️",
		cost = 100000,
		description = "A cozy beanie with falling snowflakes.",
	},
	{
		id = "TornadoTopHat",
		category = "hat",
		name = "Tornado Top Hat",
		emoji = "🎩",
		cost = 400000,
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

	-- Trails
	{
		id = "RainbowTrail",
		category = "trail",
		name = "Rainbow Trail",
		emoji = "🌈",
		cost = 5000,
		description = "Leave a rainbow wherever you run.",
	},
	{
		id = "SparkleTrail",
		category = "trail",
		name = "Sparkle Trail",
		emoji = "✨",
		cost = 20000,
		description = "Glittery golden sparkles.",
	},
	{
		id = "SnowTrail",
		category = "trail",
		name = "Snowflake Trail",
		emoji = "❄️",
		cost = 75000,
		description = "A frosty trail of snowflakes.",
	},
	{
		id = "LightningTrail",
		category = "trail",
		name = "Lightning Trail",
		emoji = "⚡",
		cost = 250000,
		description = "A crackling bolt behind you.",
	},
	{
		id = "BubbleTrail",
		category = "trail",
		name = "Bubble Trail",
		emoji = "🫧",
		cost = 600000,
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

	-- Backs
	{
		id = "JarPack",
		category = "back",
		name = "Storm Jar Backpack",
		emoji = "🫙",
		cost = 3000,
		description = "A jar backpack with a tiny storm inside.",
	},
	{
		id = "CloudWings",
		category = "back",
		name = "Cloud Wings",
		emoji = "☁️",
		cost = 30000,
		description = "Two fluffy cloud wings.",
	},
	{
		id = "ButterflyWings",
		category = "back",
		name = "Butterfly Wings",
		emoji = "🦋",
		cost = 120000,
		description = "Pretty pastel butterfly wings.",
	},
	{
		id = "MiniTornado",
		category = "back",
		name = "Mini Tornado",
		emoji = "🌪️",
		cost = 500000,
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

	-- Auras
	{
		id = "SparkleAura",
		category = "aura",
		name = "Sparkle Aura",
		emoji = "✨",
		cost = 8000,
		description = "Sparkles float all around you.",
	},
	{
		id = "RainHalo",
		category = "aura",
		name = "Rain Halo",
		emoji = "🌧️",
		cost = 50000,
		description = "Gentle rain falling around you.",
	},
	{
		id = "LightningOrbit",
		category = "aura",
		name = "Lightning Orbit",
		emoji = "⚡",
		cost = 300000,
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

	-- Pedestal styles
	{
		id = "Marble",
		category = "pedestal",
		name = "Marble",
		emoji = "🏛️",
		cost = 0,
		description = "The classic white pedestals.",
	},
	{
		id = "CandyPedestal",
		category = "pedestal",
		name = "Candy",
		emoji = "🍬",
		cost = 10000,
		description = "Sweet pink candy pedestals.",
	},
	{
		id = "GoldPedestal",
		category = "pedestal",
		name = "Gold",
		emoji = "🥇",
		cost = 25000,
		description = "Shiny gold pedestals.",
	},
	{
		id = "CloudPedestal",
		category = "pedestal",
		name = "Cloud",
		emoji = "☁️",
		cost = 60000,
		description = "Soft, puffy cloud pedestals.",
	},
	{
		id = "CrystalPedestal",
		category = "pedestal",
		name = "Crystal",
		emoji = "💎",
		cost = 150000,
		description = "See-through glowing crystal.",
	},
	{
		id = "RainbowPedestal",
		category = "pedestal",
		name = "Rainbow",
		emoji = "🌈",
		cost = 0,
		robux = true,
		description = "Every pedestal a different glowing color.",
	},

	-- Decorations
	{
		id = "LampPosts",
		category = "decor",
		name = "Lamp Posts",
		emoji = "🏮",
		cost = 5000,
		description = "Four cozy lamps that glow at night.",
	},
	{
		id = "Fountain",
		category = "decor",
		name = "Fountain",
		emoji = "⛲",
		cost = 15000,
		description = "A splashing fountain.",
	},
	{
		id = "RainbowArch",
		category = "decor",
		name = "Rainbow Arch",
		emoji = "🌈",
		cost = 50000,
		description = "A rainbow over your pedestals.",
	},
	{
		id = "StormStatue",
		category = "decor",
		name = "Golden Storm Statue",
		emoji = "🗿",
		cost = 200000,
		description = "A golden statue of your best storm.",
	},
	{
		id = "Fireworks",
		category = "decor",
		name = "Fireworks",
		emoji = "🎆",
		cost = 500000,
		description = "Fireworks over your island every night.",
	},

	-- Flags (the sign's color and emoji are free, in the same tab)
	{
		id = "StormFlag",
		category = "flag",
		name = "Storm Flag",
		emoji = "⛈️",
		cost = 2000,
		description = "A flag with a storm cloud.",
	},
	{
		id = "LightningFlag",
		category = "flag",
		name = "Lightning Flag",
		emoji = "⚡",
		cost = 8000,
		description = "A bold lightning bolt flag.",
	},
	{
		id = "RainbowFlag",
		category = "flag",
		name = "Rainbow Flag",
		emoji = "🌈",
		cost = 25000,
		description = "A cheerful rainbow flag.",
	},
	{
		id = "PirateFlag",
		category = "flag",
		name = "Sky Pirate Flag",
		emoji = "🏴‍☠️",
		cost = 80000,
		description = "For storm thieves with style.",
	},
	{
		id = "GoldenFlag",
		category = "flag",
		name = "Golden Flag",
		emoji = "✨",
		cost = 0,
		robux = true,
		description = "A glittering gold flag.",
	},

	-- Island pets (up to 3 kinds at once)
	{
		id = "Ducks",
		category = "pet",
		name = "Ducks",
		emoji = "🦆",
		cost = 10000,
		description = "Two little ducks waddle around.",
	},
	{
		id = "Bunnies",
		category = "pet",
		name = "Bunnies",
		emoji = "🐰",
		cost = 30000,
		description = "Two bunnies hop around.",
	},
	{
		id = "CloudSheep",
		category = "pet",
		name = "Cloud Sheep",
		emoji = "🐑",
		cost = 90000,
		description = "Two fluffy cloud sheep.",
	},
	{
		id = "StormDragon",
		category = "pet",
		name = "Baby Storm Dragon",
		emoji = "🐉",
		cost = 0,
		robux = true,
		description = "A baby dragon that flies around your island.",
	},
} :: { Item }

-- The island sign's colors and emoji (free).
CosmeticsData.SignColors = {
	Color3.fromRGB(90, 150, 230), -- sky blue (the default)
	Color3.fromRGB(255, 130, 180), -- pink
	Color3.fromRGB(110, 205, 140), -- mint
	Color3.fromRGB(175, 125, 245), -- grape
	Color3.fromRGB(250, 170, 80), -- peach
	Color3.fromRGB(245, 205, 70), -- lemon
	Color3.fromRGB(240, 100, 110), -- strawberry
	Color3.fromRGB(80, 70, 120), -- night
}
CosmeticsData.SignEmoji = { "🏝️", "⛈️", "🌈", "⚡", "❄️", "🌪️", "💖", "⭐", "🍭", "👑" }

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
