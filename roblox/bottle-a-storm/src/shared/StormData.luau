--!strict
-- Rarities, the 15 launch storms and mutations.

export type Rarity = {
	index: number,
	name: string,
	color: Color3,
	weight: number, -- spawn weight
	speed: number, -- studs per second while roaming
	pull: number, -- 0..1, how hard the storm fights the jar
	scale: number, -- model size
}

export type StormDef = {
	id: string,
	name: string,
	rarity: number,
	income: number, -- Sparks per second
	colors: { Color3 },
	fx: string, -- particle style, see StormModel
}

export type Mutation = {
	id: string,
	name: string,
	emoji: string,
	multiplier: number,
	weight: number,
	color: Color3,
}

-- What the DataStore keeps for each owned storm.
export type StormRecord = {
	uid: string,
	id: string,
	mut: string?,
	slot: number,
	at: number,
}

local StormData = {}

StormData.Rarities = {
	{
		index = 1,
		name = "Common",
		color = Color3.fromRGB(200, 205, 215),
		weight = 60,
		speed = 6,
		pull = 0.15,
		scale = 1,
	},
	{
		index = 2,
		name = "Uncommon",
		color = Color3.fromRGB(110, 220, 120),
		weight = 25,
		speed = 8,
		pull = 0.3,
		scale = 1.1,
	},
	{
		index = 3,
		name = "Rare",
		color = Color3.fromRGB(80, 160, 255),
		weight = 10,
		speed = 11,
		pull = 0.5,
		scale = 1.2,
	},
	{
		index = 4,
		name = "Epic",
		color = Color3.fromRGB(190, 90, 255),
		weight = 4,
		speed = 14,
		pull = 0.7,
		scale = 1.35,
	},
	{
		index = 5,
		name = "Legendary",
		color = Color3.fromRGB(255, 190, 40),
		weight = 1,
		speed = 17,
		pull = 0.9,
		scale = 1.5,
	},
} :: { Rarity }

local rgb = Color3.fromRGB

StormData.Storms = {
	-- Common
	{ id = "DrizzleDot", name = "Drizzle Dot", rarity = 1, income = 1, colors = { rgb(175, 200, 230) }, fx = "rain" },
	{ id = "Puffcloud", name = "Puffcloud", rarity = 1, income = 2, colors = { rgb(250, 250, 255) }, fx = "fog" },
	{ id = "FogBun", name = "Fog Bun", rarity = 1, income = 4, colors = { rgb(185, 185, 195) }, fx = "fog" },
	-- Uncommon
	{
		id = "HailHopper",
		name = "Hail Hopper",
		rarity = 2,
		income = 10,
		colors = { rgb(200, 225, 245), rgb(160, 195, 230) },
		fx = "hail",
	},
	{ id = "BreezyBoi", name = "Breezy Boi", rarity = 2, income = 15, colors = { rgb(170, 240, 215) }, fx = "wind" },
	{ id = "MistMouse", name = "Mist Mouse", rarity = 2, income = 25, colors = { rgb(205, 190, 225) }, fx = "fog" },
	-- Rare
	{
		id = "ThunderPup",
		name = "Thunder Pup",
		rarity = 3,
		income = 50,
		colors = { rgb(85, 90, 115), rgb(110, 115, 140) },
		fx = "lightning",
	},
	{
		id = "SnowGlobeSam",
		name = "Snow Globe Sam",
		rarity = 3,
		income = 80,
		colors = { rgb(240, 248, 255), rgb(200, 230, 255) },
		fx = "snow",
	},
	{
		id = "DustDevil",
		name = "Dust Devil",
		rarity = 3,
		income = 120,
		colors = { rgb(210, 175, 125), rgb(185, 145, 95) },
		fx = "dust",
	},
	-- Epic
	{
		id = "TornadoTony",
		name = "Tornado Tony",
		rarity = 4,
		income = 300,
		colors = { rgb(140, 155, 140), rgb(105, 120, 110) },
		fx = "wind",
	},
	{
		id = "RainbowSquall",
		name = "Rainbow Squall",
		rarity = 4,
		income = 500,
		colors = { rgb(255, 150, 180), rgb(160, 220, 255), rgb(255, 235, 140) },
		fx = "rainbow",
	},
	{
		id = "SandstormSultan",
		name = "Sandstorm Sultan",
		rarity = 4,
		income = 700,
		colors = { rgb(235, 195, 110), rgb(200, 150, 70) },
		fx = "dust",
	},
	-- Legendary
	{
		id = "HurricaneHana",
		name = "Hurricane Hana",
		rarity = 5,
		income = 2000,
		colors = { rgb(70, 190, 190), rgb(40, 140, 150) },
		fx = "hurricane",
	},
	{
		id = "BlizzardKing",
		name = "Blizzard King",
		rarity = 5,
		income = 3500,
		colors = { rgb(225, 240, 255), rgb(150, 200, 255) },
		fx = "snow",
	},
	{
		id = "MonsoonDragon",
		name = "Monsoon Dragon",
		rarity = 5,
		income = 5000,
		colors = { rgb(40, 90, 150), rgb(30, 130, 110) },
		fx = "rain",
	},
} :: { StormDef }

StormData.Mutations = {
	{ id = "Charged", name = "Charged", emoji = "⚡", multiplier = 2, weight = 50, color = rgb(255, 230, 60) },
	{ id = "Frozen", name = "Frozen", emoji = "❄️", multiplier = 3, weight = 25, color = rgb(140, 220, 255) },
	{ id = "Molten", name = "Molten", emoji = "🔥", multiplier = 4, weight = 13, color = rgb(255, 110, 40) },
	{ id = "Prismatic", name = "Prismatic", emoji = "🌈", multiplier = 6, weight = 8, color = rgb(255, 120, 230) },
	{ id = "Void", name = "Void", emoji = "🌑", multiplier = 10, weight = 3, color = rgb(90, 40, 140) },
	{ id = "Golden", name = "Golden", emoji = "✨", multiplier = 15, weight = 1, color = rgb(255, 200, 40) },
} :: { Mutation }

local stormsById: { [string]: StormDef } = {}
for _, def in StormData.Storms do
	stormsById[def.id] = def
end

local mutationsById: { [string]: Mutation } = {}
for _, mutation in StormData.Mutations do
	mutationsById[mutation.id] = mutation
end

function StormData.get(id: string): StormDef?
	return stormsById[id]
end

function StormData.getMutation(id: string?): Mutation?
	if id == nil then
		return nil
	end
	return mutationsById[id]
end

function StormData.rarityOf(def: StormDef): Rarity
	return StormData.Rarities[def.rarity]
end

-- Sparks per second for one owned storm, before player-wide bonuses like VIP.
function StormData.incomeOf(record: { id: string, mut: string? }): number
	local def = stormsById[record.id]
	if not def then
		return 0
	end
	local mutation = StormData.getMutation(record.mut)
	return def.income * (if mutation then mutation.multiplier else 1)
end

-- "Charged Tornado Tony"
function StormData.displayName(record: { id: string, mut: string? }): string
	local def = stormsById[record.id]
	local name = if def then def.name else record.id
	local mutation = StormData.getMutation(record.mut)
	if mutation then
		return mutation.name .. " " .. name
	end
	return name
end

return StormData
