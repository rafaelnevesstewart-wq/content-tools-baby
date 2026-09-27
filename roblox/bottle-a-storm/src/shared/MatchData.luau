--!strict
-- Bed Wars: teams, resources, the item shop, team upgrades and rewards.
-- (Timings and numbers for the match itself are in Config.Match.)

export type TeamInfo = { key: string, name: string, color: Color3, brick: string, emoji: string }

export type ShopItem = {
	key: string,
	name: string,
	emoji: string,
	tab: string, -- "Blocks" | "Weapons" | "Armor" | "Items"
	cost: number,
	currency: string, -- "Copper" | "Silver" | "Crystals" | "Cores"
	amount: number?, -- how many you get (blocks, arrows)
	description: string,
}

export type Upgrade = {
	key: string,
	name: string,
	emoji: string,
	costs: { number }, -- Storm Crystals per level
	description: string,
}

local rgb = Color3.fromRGB

local MatchData = {}

MatchData.Teams = {
	{ key = "Red", name = "Red", color = rgb(230, 70, 70), brick = "Bright red", emoji = "🟥" },
	{ key = "Blue", name = "Blue", color = rgb(70, 130, 240), brick = "Bright blue", emoji = "🟦" },
	{ key = "Green", name = "Green", color = rgb(70, 190, 90), brick = "Bright green", emoji = "🟩" },
	{ key = "Yellow", name = "Yellow", color = rgb(245, 205, 60), brick = "Bright yellow", emoji = "🟨" },
	{ key = "Aqua", name = "Aqua", color = rgb(60, 200, 210), brick = "Cyan", emoji = "🩵" },
	{ key = "White", name = "White", color = rgb(240, 240, 245), brick = "Institutional white", emoji = "⬜" },
	{ key = "Pink", name = "Pink", color = rgb(245, 120, 190), brick = "Hot pink", emoji = "🩷" },
	{ key = "Gray", name = "Gray", color = rgb(130, 130, 140), brick = "Medium stone grey", emoji = "⬛" },
} :: { TeamInfo }

-- Resources you carry during a match (lost when you die).
MatchData.Resources = {
	{ key = "Copper", emoji = "🟠", color = rgb(220, 130, 70) },
	{ key = "Silver", emoji = "⚪", color = rgb(210, 215, 225) },
	{ key = "Crystals", emoji = "💎", color = rgb(90, 220, 240) },
	{ key = "Cores", emoji = "⚡", color = rgb(255, 225, 80) },
}

-- Swords by tier. Damage per hit (players have 100 health).
MatchData.Swords = {
	{ key = "WoodSword", name = "Wood Sword", damage = 18, color = rgb(150, 110, 70), material = Enum.Material.Wood },
	{
		key = "StoneSword",
		name = "Stone Sword",
		damage = 24,
		color = rgb(140, 140, 145),
		material = Enum.Material.Slate,
	},
	{ key = "IronSword", name = "Iron Sword", damage = 30, color = rgb(220, 225, 232), material = Enum.Material.Metal },
	{
		key = "DiamondSword",
		name = "Diamond Sword",
		damage = 38,
		color = rgb(90, 230, 240),
		material = Enum.Material.Glass,
	},
}

-- Armor by tier: the share of damage that gets through.
MatchData.Armor = {
	{ key = "Cloth", name = "Cloth Armor", taken = 1, color = nil :: Color3? },
	{ key = "Chain", name = "Chain Armor", taken = 0.8, color = rgb(170, 170, 180) :: Color3? },
	{ key = "Iron", name = "Iron Armor", taken = 0.65, color = rgb(225, 228, 235) :: Color3? },
	{ key = "Diamond", name = "Diamond Armor", taken = 0.5, color = rgb(90, 230, 240) :: Color3? },
}

-- Blocks to protect your bed: how many sword hits break one.
MatchData.Blocks = {
	CloudWool = { name = "Cloud Wool", hits = 2, material = Enum.Material.Fabric },
	WoodPlanks = { name = "Wood Planks", hits = 5, material = Enum.Material.WoodPlanks, color = rgb(160, 120, 80) },
	StoneBricks = { name = "Stone Bricks", hits = 10, material = Enum.Material.Brick, color = rgb(150, 150, 155) },
	Obsidian = { name = "Obsidian", hits = 30, material = Enum.Material.Basalt, color = rgb(40, 30, 60) },
}

MatchData.Shop = {
	-- Blocks
	{
		key = "CloudWool",
		name = "Cloud Wool x16",
		emoji = "☁️",
		tab = "Blocks",
		cost = 4,
		currency = "Copper",
		amount = 16,
		description = "Soft team-colored blocks. 2 hits to break.",
	},
	{
		key = "WoodPlanks",
		name = "Wood Planks x16",
		emoji = "🪵",
		tab = "Blocks",
		cost = 4,
		currency = "Silver",
		amount = 16,
		description = "Sturdier. 5 hits to break.",
	},
	{
		key = "StoneBricks",
		name = "Stone Bricks x12",
		emoji = "🧱",
		tab = "Blocks",
		cost = 24,
		currency = "Copper",
		amount = 12,
		description = "Strong walls. 10 hits to break.",
	},
	{
		key = "Obsidian",
		name = "Obsidian x4",
		emoji = "🟪",
		tab = "Blocks",
		cost = 4,
		currency = "Cores",
		amount = 4,
		description = "Almost unbreakable. 30 hits.",
	},
	-- Weapons
	{
		key = "StoneSword",
		name = "Stone Sword",
		emoji = "🗡️",
		tab = "Weapons",
		cost = 10,
		currency = "Copper",
		description = "24 damage per hit.",
	},
	{
		key = "IronSword",
		name = "Iron Sword",
		emoji = "⚔️",
		tab = "Weapons",
		cost = 7,
		currency = "Silver",
		description = "30 damage per hit.",
	},
	{
		key = "DiamondSword",
		name = "Diamond Sword",
		emoji = "💠",
		tab = "Weapons",
		cost = 4,
		currency = "Cores",
		description = "38 damage per hit.",
	},
	{
		key = "Bow",
		name = "Bow",
		emoji = "🏹",
		tab = "Weapons",
		cost = 12,
		currency = "Silver",
		description = "Shoot from far away. Needs arrows.",
	},
	{
		key = "Arrows",
		name = "Arrows x8",
		emoji = "➶",
		tab = "Weapons",
		cost = 2,
		currency = "Silver",
		amount = 8,
		description = "8 arrows for your bow.",
	},
	-- Armor (kept when you respawn)
	{
		key = "Chain",
		name = "Chain Armor",
		emoji = "🥋",
		tab = "Armor",
		cost = 24,
		currency = "Copper",
		description = "Take 20% less damage. Kept when you respawn.",
	},
	{
		key = "Iron",
		name = "Iron Armor",
		emoji = "🛡️",
		tab = "Armor",
		cost = 12,
		currency = "Silver",
		description = "Take 35% less damage.",
	},
	{
		key = "Diamond",
		name = "Diamond Armor",
		emoji = "💎",
		tab = "Armor",
		cost = 6,
		currency = "Cores",
		description = "Take 50% less damage.",
	},
	-- Items
	{
		key = "StormApple",
		name = "Storm Apple",
		emoji = "🍎",
		tab = "Items",
		cost = 3,
		currency = "Silver",
		description = "Eat it to heal 40 health.",
	},
	{
		key = "WindPearl",
		name = "Wind Pearl",
		emoji = "🔮",
		tab = "Items",
		cost = 4,
		currency = "Cores",
		description = "Throw it and teleport to where it lands.",
	},
} :: { ShopItem }

-- Team upgrades, bought with Storm Crystals, help the whole team.
MatchData.Upgrades = {
	{
		key = "Sharpness",
		name = "Sharp Blades",
		emoji = "🗡️",
		costs = { 4 },
		description = "Your team's swords deal +4 damage.",
	},
	{
		key = "Protection",
		name = "Reinforced Armor",
		emoji = "🛡️",
		costs = { 2, 4, 8 },
		description = "Your team takes 6% less damage per level.",
	},
	{
		key = "Forge",
		name = "Storm Forge",
		emoji = "🔥",
		costs = { 2, 4, 6 },
		description = "Your island's generator makes resources 50% faster per level.",
	},
	{
		key = "HealAura",
		name = "Healing Aura",
		emoji = "💚",
		costs = { 3 },
		description = "Your team slowly heals on your island.",
	},
} :: { Upgrade }

-- Sparks and Season Stars earned in matches (before VIP and Style Bonus).
MatchData.Rewards = {
	Kill = { sparks = 25, stars = 10 },
	FinalKill = { sparks = 60, stars = 25 },
	Bed = { sparks = 120, stars = 50 },
	Win = { sparks = 300, stars = 120 },
	Played = { sparks = 50, stars = 30 },
}

function MatchData.shopItem(key: string): ShopItem?
	for _, item in MatchData.Shop do
		if item.key == key then
			return item
		end
	end
	return nil
end

function MatchData.upgrade(key: string): Upgrade?
	for _, upgrade in MatchData.Upgrades do
		if upgrade.key == key then
			return upgrade
		end
	end
	return nil
end

function MatchData.swordTier(key: string): number?
	for index, sword in MatchData.Swords do
		if sword.key == key then
			return index
		end
	end
	return nil
end

function MatchData.armorTier(key: string): number?
	for index, armor in MatchData.Armor do
		if armor.key == key then
			return index
		end
	end
	return nil
end

return MatchData
