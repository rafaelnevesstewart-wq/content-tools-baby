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
		key = "SummonWeather",
		id = 0,
		price = 79,
		name = "Summon Rainbow Hour",
		description = "Start a Rainbow Hour for the whole server. Everyone will know it was you!",
	},
} :: { Item }

local byKey: { [string]: Item } = {}
local byId: { [number]: Item } = {}
for _, list in { Products.Passes, Products.DevProducts } do
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
