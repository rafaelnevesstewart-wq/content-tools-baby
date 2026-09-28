--!strict
-- Robux items. Create each Game Pass and Developer Product on the Creator Dashboard,
-- then paste its ID here. An ID of 0 means "not set up yet": the shop shows it as
-- coming soon, and in Studio the buy button grants it for free so you can test.
-- Nothing here makes you stronger in a match: it's Sparks, kits, looks and the
-- battle pass.

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
		name = "VIP",
		description = "+25% Sparks from every match, forever, and a VIP tag.",
	},
	{
		key = "StarBooster",
		id = 0,
		price = 149,
		name = "Star Booster",
		description = "+50% Season Stars: climb the battle pass faster.",
	},
} :: { Item }

Products.DevProducts = {
	{
		key = "SparksSmall",
		id = 0,
		price = 25,
		name = "Pouch of Sparks",
		description = "1,000 Sparks for cosmetics and Kit Crates.",
	},
	{
		key = "SparksLarge",
		id = 0,
		price = 399,
		name = "Barrel of Sparks",
		description = "20,000 Sparks for cosmetics and Kit Crates.",
	},
	{
		key = "GoldenKitCrate",
		id = 0,
		price = 99,
		name = "Golden Kit Crate",
		description = "An Epic or better kit, always shiny.",
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
		name = "Battle Pass Premium",
		description = "Unlock this season's premium rewards: 2 exclusive kits and more.",
	},
	{
		key = "SeasonSkip",
		id = 0,
		price = 49,
		name = "Skip a Battle Pass Tier",
		description = "Jump one tier ahead on the battle pass.",
	},
	{
		key = "SummonWeather",
		id = 0,
		price = 79,
		name = "Summon Rainbow Hour",
		description = "Double Sparks for everyone for 10 minutes. Everyone will know it was you!",
	},
} :: { Item }

-- Robux cosmetics (see CosmeticsData). Each is a Developer Product that
-- unlocks the cosmetic forever. They're sold in the 🎨 Style window, not the
-- Shop's Robux tab.
Products.Cosmetics = {
	{
		key = "Cosmetic_MountUnicorn",
		id = 0,
		price = 149,
		name = "Unicorn Mount",
		description = "A sparkling white unicorn to ride around the lobby.",
	},
	{
		key = "Cosmetic_PetDeer",
		id = 0,
		price = 99,
		name = "Deer Pet",
		description = "A graceful deer that follows you everywhere.",
	},
	{
		key = "Cosmetic_PetDragon",
		id = 0,
		price = 199,
		name = "Storm Dragon Pet",
		description = "A little dragon that flies over your shoulder.",
	},
	{
		key = "Cosmetic_GoldenCrown",
		id = 0,
		price = 49,
		name = "Golden Storm Crown",
		description = "A shiny golden crown with sparkles.",
	},
	{
		key = "Cosmetic_StormHalo",
		id = 0,
		price = 99,
		name = "Storm Halo",
		description = "A spinning halo that crackles with lightning.",
	},
	{
		key = "Cosmetic_GalaxyTrail",
		id = 0,
		price = 49,
		name = "Galaxy Trail",
		description = "A starry purple galaxy streak.",
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
		key = "Cosmetic_RainbowWings",
		id = 0,
		price = 79,
		name = "Rainbow Wings",
		description = "Big glowing rainbow wings.",
	},
	{
		key = "Cosmetic_LightningWings",
		id = 0,
		price = 99,
		name = "Lightning Wings",
		description = "Electric wings with crackling bolts.",
	},
	{
		key = "Cosmetic_HeartAura",
		id = 0,
		price = 39,
		name = "Love Aura",
		description = "Soft pink sparkles and a warm glow float up around you.",
	},
	{
		key = "Cosmetic_ThunderCloudSkin",
		id = 0,
		price = 49,
		name = "Thunder Bed",
		description = "A black thundercloud bed that flashes with lightning.",
	},
	{
		key = "Cosmetic_AuroraCloud",
		id = 0,
		price = 79,
		name = "Aurora Bed",
		description = "A glowing green and purple aurora bed.",
	},
	{
		key = "Cosmetic_PrismCloud",
		id = 0,
		price = 99,
		name = "Prism Bed",
		description = "A glowing bed that shifts through every color.",
	},
	{
		key = "Cosmetic_VoidCloud",
		id = 0,
		price = 79,
		name = "Void Bed",
		description = "A black bed with a throbbing purple heart.",
	},
	{
		key = "Cosmetic_GalaxyBlade",
		id = 0,
		price = 129,
		name = "Galaxy Blade",
		description = "A glowing blade full of stars.",
	},
	{
		key = "Cosmetic_DiamondBlade",
		id = 0,
		price = 179,
		name = "Diamond Blade",
		description = "A flawless sparkling diamond blade.",
	},
	{
		key = "Cosmetic_ShadowBlade",
		id = 0,
		price = 149,
		name = "Shadow Blade",
		description = "A black blade with violet edges, trailing dark smoke.",
	},
	{
		key = "Cosmetic_GoldenRay",
		id = 0,
		price = 49,
		name = "Golden Arrows",
		description = "Shining golden arrows.",
	},
	{
		key = "Cosmetic_GoldenRainKO",
		id = 0,
		price = 149,
		name = "Golden Rain",
		description = "Golden sparks rain down on the spot.",
	},
	{
		key = "Cosmetic_VoidKO",
		id = 0,
		price = 199,
		name = "Void Rift",
		description = "A purple rift swallows them.",
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
