--!strict
-- Robux items. Create each Game Pass and Developer Product on the Creator Dashboard,
-- then paste its ID here. An ID of 0 means "not set up yet": the shop shows it as
-- coming soon, and in Studio the buy button grants it for free so you can test.

export type Item = {
	key: string,
	id: number,
	price: number,
	name: string,
	description: string,
}

local Products = {}

Products.Passes = {
	{
		key = "VIP",
		id = 0,
		price = 199,
		name = "VIP Storm Chaser",
		description = "+25% Sparks from every storm, forever.",
	},
	{
		key = "DoubleSlots",
		id = 0,
		price = 149,
		name = "Double Pedestals",
		description = "Build up to 20 pedestals instead of 10.",
	},
	{
		key = "AutoCollect",
		id = 0,
		price = 99,
		name = "Auto-Collect",
		description = "Sparks go straight to your wallet. No walking to the pad.",
	},
	{
		key = "StormTamer",
		id = 0,
		price = 399,
		name = "Storm Tamer",
		description = "Your storms never escape, and they get bored half as fast.",
	},
	{
		key = "Flight",
		id = 0,
		price = 199,
		name = "Cloud Flight",
		description = "Fly anywhere on a fluffy cloud for 30 seconds at a time (G on PC).",
	},
} :: { Item }

Products.DevProducts = {
	{
		key = "SparksSmall",
		id = 0,
		price = 25,
		name = "Pouch of Sparks",
		description = "1,000 Sparks or 5 minutes of your income, whichever is more.",
	},
	{
		key = "SparksLarge",
		id = 0,
		price = 399,
		name = "Barrel of Sparks",
		description = "15,000 Sparks or 1 hour of your income, whichever is more.",
	},
	{
		key = "EmergencyLock",
		id = 0,
		price = 19,
		name = "Emergency Lock",
		description = "Lock your island for 5 minutes, from anywhere, right now.",
	},
	{
		key = "RaidShield",
		id = 0,
		price = 39,
		name = "Raid Shield",
		description = "If the next Mega-Storm wins, your storms stay safe.",
	},
	{
		key = "MysteryGoldenJar",
		id = 0,
		price = 99,
		name = "Golden Mystery Jar",
		description = "Hatch an Epic or Legendary storm, always mutated.",
	},
	{
		key = "SpinWheel3",
		id = 0,
		price = 49,
		name = "3 Wheel Spins",
		description = "Three extra spins on the daily prize wheel.",
	},
	{
		key = "SeasonPremium",
		id = 0,
		price = 299,
		name = "Season Premium",
		description = "Unlock this season's premium rewards, including 2 exclusive storms.",
	},
	{
		key = "SeasonSkip",
		id = 0,
		price = 49,
		name = "Skip a Season Tier",
		description = "Jump one tier ahead on the season pass.",
	},
	{
		key = "SummonWeather",
		id = 0,
		price = 79,
		name = "Summon Rainbow Hour",
		description = "Start a Rainbow Hour for the whole server. Everyone will know it was you!",
	},
} :: { Item }

-- Robux cosmetics (see CosmeticsData). Each is a Developer Product that
-- unlocks the cosmetic forever. They're sold in the 🎨 Style window, not the
-- Shop's Robux tab.
Products.Cosmetics = {
	{
		key = "Cosmetic_GoldenCrown",
		id = 0,
		price = 49,
		name = "Golden Storm Crown",
		description = "A shiny golden crown with sparkles.",
	},
	{
		key = "Cosmetic_GalaxyTrail",
		id = 0,
		price = 49,
		name = "Galaxy Trail",
		description = "A starry purple galaxy streak.",
	},
	{
		key = "Cosmetic_RainbowWings",
		id = 0,
		price = 79,
		name = "Rainbow Wings",
		description = "Big glowing rainbow wings.",
	},
	{
		key = "Cosmetic_HeartAura",
		id = 0,
		price = 39,
		name = "Love Aura",
		description = "Soft pink sparkles and a warm glow float up around you.",
	},
	{
		key = "Cosmetic_RainbowPedestal",
		id = 0,
		price = 49,
		name = "Rainbow Pedestals",
		description = "Every pedestal a different glowing color.",
	},
	{
		key = "Cosmetic_GoldenFlag",
		id = 0,
		price = 29,
		name = "Golden Flag",
		description = "A glittering gold flag.",
	},
	{
		key = "Cosmetic_ThunderstormTrail",
		id = 0,
		price = 49,
		name = "Thunderstorm Trail",
		description = "Storm clouds and crackling lightning.",
	},
	{
		key = "Cosmetic_PhoenixTrail",
		id = 0,
		price = 79,
		name = "Phoenix Trail",
		description = "Huge golden fire wings of flame.",
	},
	{
		key = "Cosmetic_ThunderCloudSkin",
		id = 0,
		price = 49,
		name = "Thunder Cloud",
		description = "A black thundercloud that flashes with lightning.",
	},
	{
		key = "Cosmetic_AuroraCloud",
		id = 0,
		price = 79,
		name = "Aurora Cloud",
		description = "A glowing green and purple aurora cloud.",
	},
	{
		key = "Cosmetic_PrismCloud",
		id = 0,
		price = 99,
		name = "Prism Cloud",
		description = "A glowing cloud that shifts through every color.",
	},
	{
		key = "Cosmetic_VoidCloud",
		id = 0,
		price = 79,
		name = "Void Cloud",
		description = "A black cloud with a throbbing purple heart.",
	},
	{
		key = "Cosmetic_CrystalPalace",
		id = 0,
		price = 149,
		name = "Crystal Palace",
		description = "See-through crystal with an icy dome.",
	},
	{
		key = "Cosmetic_SkyTemple",
		id = 0,
		price = 199,
		name = "Golden Sky Temple",
		description = "Marble and gold, fit for a storm legend.",
	},
	{
		key = "Cosmetic_StormDragon",
		id = 0,
		price = 79,
		name = "Baby Storm Dragon",
		description = "A baby dragon that flies around your island.",
	},
} :: { Item }

local byKey: { [string]: Item } = {}
local byId: { [number]: Item } = {}
for _, list in { Products.Passes, Products.DevProducts, Products.Cosmetics } do
	for _, item in list do
		byKey[item.key] = item
		if item.id ~= 0 then
			byId[item.id] = item
		end
	end
end

function Products.get(key: string): Item?
	return byKey[key]
end

function Products.fromId(id: number): Item?
	return byId[id]
end

function Products.isPass(key: string): boolean
	for _, item in Products.Passes do
		if item.key == key then
			return true
		end
	end
	return false
end

-- Player attribute that is true when the player owns the pass.
function Products.passAttribute(key: string): string
	return "Pass_" .. key
end

return Products
