--!strict
-- Storm kits for Bed Wars: rarities, every storm and its look. Each storm you
-- own is a kit: pick one and, in a match, it floats beside you and gives its
-- power on Shift. Rarer kits recharge their power faster.

export type Rarity = {
	index: number,
	name: string,
	color: Color3,
	weight: number, -- how often it comes out of Kit Crates (see MarketData for crate odds)
	scale: number, -- model size
	cooldown: number, -- power recharge time multiplier (lower = faster)
}

export type StormDef = {
	id: string,
	name: string,
	rarity: number,
	colors: { Color3 },
	fx: string, -- particle style, see StormModel
	ability: string?, -- a special power instead of the one its fx gives
	season: string?, -- only from that season's battle pass (see SeasonData)
	holiday: string?, -- only during that holiday event (see HolidayData)
}

-- Shiny variants: a rare glow and name prefix on a kit. Just for looks.
export type Mutation = {
	id: string,
	name: string,
	emoji: string,
	weight: number,
	color: Color3,
}

-- What the DataStore keeps for each owned kit.
export type StormRecord = {
	uid: string,
	id: string,
	mut: string?,
	at: number,
}

local StormData = {}

StormData.Rarities = {
	{ index = 1, name = "Common", color = Color3.fromRGB(200, 205, 215), weight = 55, scale = 1, cooldown = 1 },
	{ index = 2, name = "Uncommon", color = Color3.fromRGB(110, 220, 120), weight = 25, scale = 1.1, cooldown = 0.92 },
	{ index = 3, name = "Rare", color = Color3.fromRGB(80, 160, 255), weight = 14, scale = 1.2, cooldown = 0.84 },
	{ index = 4, name = "Epic", color = Color3.fromRGB(190, 90, 255), weight = 6, scale = 1.35, cooldown = 0.76 },
	{ index = 5, name = "Legendary", color = Color3.fromRGB(255, 190, 40), weight = 1.8, scale = 1.5, cooldown = 0.68 },
	{ index = 6, name = "Mythic", color = Color3.fromRGB(255, 80, 140), weight = 0.5, scale = 1.65, cooldown = 0.6 },
	{ index = 7, name = "Cosmic", color = Color3.fromRGB(110, 170, 255), weight = 0.15, scale = 1.8, cooldown = 0.55 },
} :: { Rarity }

local rgb = Color3.fromRGB

StormData.Storms = {
	-- Common
	{ id = "DrizzleDot", name = "Drizzle Dot", rarity = 1, colors = { rgb(175, 200, 230) }, fx = "rain" },
	{ id = "Puffcloud", name = "Puffcloud", rarity = 1, colors = { rgb(250, 250, 255) }, fx = "fog" },
	{ id = "FogBun", name = "Fog Bun", rarity = 1, colors = { rgb(185, 185, 195) }, fx = "fog" },
	-- Uncommon
	{
		id = "HailHopper",
		name = "Hail Hopper",
		rarity = 2,
		colors = { rgb(200, 225, 245), rgb(160, 195, 230) },
		fx = "hail",
	},
	{ id = "BreezyBoi", name = "Breezy Boi", rarity = 2, colors = { rgb(170, 240, 215) }, fx = "wind" },
	{ id = "MistMouse", name = "Mist Mouse", rarity = 2, colors = { rgb(205, 190, 225) }, fx = "fog" },
	-- Rare
	{
		id = "ThunderPup",
		name = "Thunder Pup",
		rarity = 3,
		colors = { rgb(85, 90, 115), rgb(110, 115, 140) },
		fx = "lightning",
	},
	{
		id = "SnowGlobeSam",
		name = "Snow Globe Sam",
		rarity = 3,
		colors = { rgb(240, 248, 255), rgb(200, 230, 255) },
		fx = "snow",
	},
	{
		id = "DustDevil",
		name = "Dust Devil",
		rarity = 3,
		colors = { rgb(210, 175, 125), rgb(185, 145, 95) },
		fx = "dust",
	},
	-- Epic
	{
		id = "TornadoTony",
		name = "Tornado Tony",
		rarity = 4,
		colors = { rgb(140, 155, 140), rgb(105, 120, 110) },
		fx = "wind",
	},
	{
		id = "RainbowSquall",
		name = "Rainbow Squall",
		rarity = 4,
		colors = { rgb(255, 150, 180), rgb(160, 220, 255), rgb(255, 235, 140) },
		fx = "rainbow",
	},
	{
		id = "SandstormSultan",
		name = "Sandstorm Sultan",
		rarity = 4,
		colors = { rgb(235, 195, 110), rgb(200, 150, 70) },
		fx = "dust",
	},
	-- Legendary
	{
		id = "HurricaneHana",
		name = "Hurricane Hana",
		rarity = 5,
		colors = { rgb(70, 190, 190), rgb(40, 140, 150) },
		fx = "hurricane",
		ability = "Flight", -- the old Cloud Flight pass lives on as this power
	},
	{
		id = "BlizzardKing",
		name = "Blizzard King",
		rarity = 5,
		colors = { rgb(225, 240, 255), rgb(150, 200, 255) },
		fx = "snow",
	},
	{
		id = "MonsoonDragon",
		name = "Monsoon Dragon",
		rarity = 5,
		colors = { rgb(40, 90, 150), rgb(30, 130, 110) },
		fx = "rain",
	},

	-- Stronger kits: Epic to Mythic.
	{
		id = "GhostFog",
		name = "Ghost Fog",
		rarity = 3,
		colors = { rgb(225, 230, 255), rgb(180, 170, 220) },
		fx = "fog",
	},
	{
		id = "ZappyDrizzle",
		name = "Zappy Drizzle",
		rarity = 3,
		colors = { rgb(150, 190, 240), rgb(255, 235, 120) },
		fx = "lightning",
	},
	{
		id = "SleetSprite",
		name = "Sleet Sprite",
		rarity = 4,
		colors = { rgb(210, 235, 255), rgb(170, 200, 235) },
		fx = "hail",
	},
	{
		id = "SandTwister",
		name = "Sand Twister",
		rarity = 4,
		colors = { rgb(230, 200, 140), rgb(170, 240, 215) },
		fx = "dust",
	},
	{
		id = "Thundernado",
		name = "Thundernado",
		rarity = 4,
		colors = { rgb(90, 95, 130), rgb(140, 155, 140) },
		fx = "lightning",
	},
	{
		id = "DoubleRainbow",
		name = "Double Rainbow",
		rarity = 4,
		colors = { rgb(255, 150, 180), rgb(150, 255, 200), rgb(160, 200, 255) },
		fx = "rainbow",
	},
	{
		id = "DesertCyclone",
		name = "Desert Cyclone",
		rarity = 5,
		colors = { rgb(235, 195, 110), rgb(70, 190, 190) },
		fx = "hurricane",
	},
	{
		id = "FrostVortex",
		name = "Frost Vortex",
		rarity = 5,
		colors = { rgb(200, 230, 255), rgb(120, 150, 200) },
		fx = "snow",
	},
	{
		id = "StormSerpent",
		name = "Storm Serpent",
		rarity = 6,
		colors = { rgb(40, 90, 150), rgb(255, 235, 100) },
		fx = "lightning",
	},
	{
		id = "AuroraSerpent",
		name = "Aurora Serpent",
		rarity = 6,
		colors = { rgb(120, 255, 200), rgb(200, 120, 255) },
		fx = "rainbow",
	},
	{
		id = "TyphoonTitan",
		name = "Typhoon Titan",
		rarity = 6,
		colors = { rgb(30, 110, 140), rgb(70, 190, 190) },
		fx = "hurricane",
		ability = "Flight", -- the old Cloud Flight pass lives on as this power
	},

	-- Arctic kits
	{
		id = "FrostbitePup",
		name = "Frostbite Pup",
		rarity = 3,
		colors = { rgb(220, 240, 255), rgb(170, 210, 245) },
		fx = "snow",
	},
	{
		id = "SnowballYeti",
		name = "Snowball Yeti",
		rarity = 4,
		colors = { rgb(250, 252, 255), rgb(190, 215, 240) },
		fx = "snow",
	},
	{
		id = "GlacierGuardian",
		name = "Glacier Guardian",
		rarity = 5,
		colors = { rgb(140, 210, 240), rgb(90, 160, 210) },
		fx = "hail",
	},
	{
		id = "PolarAurora",
		name = "Polar Aurora",
		rarity = 6,
		colors = { rgb(120, 255, 200), rgb(120, 170, 255), rgb(210, 130, 255) },
		fx = "rainbow",
	},
	-- Volcano kits
	{
		id = "EmberPuff",
		name = "Ember Puff",
		rarity = 3,
		colors = { rgb(255, 150, 80), rgb(120, 90, 90) },
		fx = "fire",
	},
	{
		id = "MagmaMoth",
		name = "Magma Moth",
		rarity = 4,
		colors = { rgb(255, 110, 40), rgb(90, 50, 40) },
		fx = "fire",
	},
	{
		id = "AshStormDrake",
		name = "Ash Storm Drake",
		rarity = 5,
		colors = { rgb(90, 85, 90), rgb(255, 120, 60) },
		fx = "dust",
	},
	{
		id = "LavaRainGolem",
		name = "Lava Rain Golem",
		rarity = 6,
		colors = { rgb(255, 80, 30), rgb(60, 35, 35) },
		fx = "fire",
	},
	-- Space kits (the rarest: Cosmic)
	{
		id = "StardustSprite",
		name = "Stardust Sprite",
		rarity = 4,
		colors = { rgb(200, 190, 255), rgb(120, 110, 200) },
		fx = "stars",
	},
	{
		id = "CometKid",
		name = "Comet Kid",
		rarity = 5,
		colors = { rgb(160, 220, 255), rgb(70, 90, 180) },
		fx = "stars",
	},
	{
		id = "MeteorShowerWhale",
		name = "Meteor Shower Whale",
		rarity = 7,
		colors = { rgb(80, 70, 160), rgb(255, 170, 90) },
		fx = "stars",
	},
	{
		id = "SolarFlarePhoenix",
		name = "Solar Flare Phoenix",
		rarity = 7,
		colors = { rgb(255, 210, 80), rgb(255, 110, 50) },
		fx = "fire",
		ability = "Flight", -- the old Cloud Flight pass lives on as this power
	},

	-- Holiday event kits (see HolidayData): only in the event shop while their
	-- holiday is on.
	{
		id = "SpookyFog",
		name = "Spooky Fog",
		rarity = 4,
		colors = { rgb(120, 110, 140), rgb(255, 140, 40) },
		fx = "fog",
		holiday = "Halloween",
	},
	{
		id = "PhantomSquall",
		name = "Phantom Squall",
		rarity = 5,
		colors = { rgb(70, 60, 90), rgb(150, 255, 170) },
		fx = "wind",
		holiday = "Halloween",
	},
	{
		id = "FrostbiteFlurry",
		name = "Frostbite Flurry",
		rarity = 4,
		colors = { rgb(220, 240, 255), rgb(200, 40, 50) },
		fx = "snow",
		holiday = "Winter",
	},
	{
		id = "JollyNoreaster",
		name = "Jolly Nor'easter",
		rarity = 5,
		colors = { rgb(240, 245, 255), rgb(40, 140, 70) },
		fx = "snow",
		holiday = "Winter",
	},
	{
		id = "BeachBreeze",
		name = "Beach Breeze",
		rarity = 4,
		colors = { rgb(120, 210, 230), rgb(250, 230, 170) },
		fx = "wind",
		holiday = "Summer",
	},
	{
		id = "SolsticeTyphoon",
		name = "Solstice Typhoon",
		rarity = 5,
		colors = { rgb(60, 170, 150), rgb(255, 180, 80) },
		fx = "hurricane",
		holiday = "Summer",
	},

	-- Season pass exclusives (see SeasonData): Epic (free track), Legendary and Mythic (premium).
	-- Spring Showers
	{
		id = "BlossomDrizzle",
		name = "Blossom Drizzle",
		rarity = 4,
		colors = { rgb(255, 190, 215), rgb(255, 240, 245) },
		fx = "rain",
		season = "SpringShowers",
	},
	{
		id = "PetalTwister",
		name = "Petal Twister",
		rarity = 5,
		colors = { rgb(255, 150, 190), rgb(170, 230, 150) },
		fx = "wind",
		season = "SpringShowers",
	},
	{
		id = "CherryMonsoon",
		name = "Cherry Monsoon",
		rarity = 6,
		colors = { rgb(255, 120, 170), rgb(120, 60, 90) },
		fx = "rain",
		season = "SpringShowers",
	},
	-- Summer Heatwave
	{
		id = "SunnyPuff",
		name = "Sunny Puff",
		rarity = 4,
		colors = { rgb(255, 230, 110), rgb(255, 250, 220) },
		fx = "fire",
		season = "SummerHeatwave",
	},
	{
		id = "HeatwaveHawk",
		name = "Heatwave Hawk",
		rarity = 5,
		colors = { rgb(255, 160, 60), rgb(255, 90, 60) },
		fx = "fire",
		season = "SummerHeatwave",
	},
	{
		id = "TropicalTyphoon",
		name = "Tropical Typhoon",
		rarity = 6,
		colors = { rgb(60, 210, 190), rgb(255, 220, 120) },
		fx = "hurricane",
		season = "SummerHeatwave",
	},
	-- Autumn Gusts
	{
		id = "LeafyBreeze",
		name = "Leafy Breeze",
		rarity = 4,
		colors = { rgb(230, 150, 60), rgb(200, 90, 40) },
		fx = "wind",
		season = "AutumnGusts",
	},
	{
		id = "PumpkinTornado",
		name = "Pumpkin Tornado",
		rarity = 5,
		colors = { rgb(255, 140, 30), rgb(60, 130, 50) },
		fx = "wind",
		season = "AutumnGusts",
	},
	{
		id = "HarvestMoonSquall",
		name = "Harvest Moon Squall",
		rarity = 6,
		colors = { rgb(255, 200, 110), rgb(120, 70, 140) },
		fx = "rainbow",
		season = "AutumnGusts",
	},
	-- Winter Wonder
	{
		id = "JingleFlurry",
		name = "Jingle Flurry",
		rarity = 4,
		colors = { rgb(240, 250, 255), rgb(220, 60, 70) },
		fx = "snow",
		season = "WinterWonder",
	},
	{
		id = "CandyCaneCyclone",
		name = "Candy Cane Cyclone",
		rarity = 5,
		colors = { rgb(255, 255, 255), rgb(230, 50, 60) },
		fx = "hurricane",
		season = "WinterWonder",
	},
	{
		id = "AuroraReindeer",
		name = "Aurora Reindeer",
		rarity = 6,
		colors = { rgb(150, 110, 80), rgb(120, 255, 200) },
		fx = "rainbow",
		season = "WinterWonder",
	},
} :: { StormDef }

StormData.Mutations = {
	{ id = "Charged", name = "Charged", emoji = "⚡", weight = 50, color = rgb(255, 230, 60) },
	{ id = "Frozen", name = "Frozen", emoji = "❄️", weight = 25, color = rgb(140, 220, 255) },
	{ id = "Molten", name = "Molten", emoji = "🔥", weight = 13, color = rgb(255, 110, 40) },
	{ id = "Prismatic", name = "Prismatic", emoji = "🌈", weight = 8, color = rgb(255, 120, 230) },
	{ id = "Void", name = "Void", emoji = "🌑", weight = 3, color = rgb(90, 40, 140) },
	{ id = "Golden", name = "Golden", emoji = "✨", weight = 1, color = rgb(255, 200, 40) },
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

-- Battle pass and holiday kits: only from their pass or event, so they're not
-- in Kit Crates or the Kit Collection rows.
function StormData.isExclusive(def: StormDef): boolean
	return def.season ~= nil or def.holiday ~= nil
end

-- Kits of one rarity that can come out of Kit Crates.
function StormData.ofRarity(rarity: number): { StormDef }
	local list = {}
	for _, def in StormData.Storms do
		if def.rarity == rarity and not StormData.isExclusive(def) then
			table.insert(list, def)
		end
	end
	return list
end

-- Kit powers (Shift in a match). The client runs them (RideController).
local ABILITIES: { [string]: string } = {
	wind = "Updraft",
	hurricane = "Updraft",
	lightning = "BlinkDash",
	snow = "Surf",
	hail = "Surf",
	dust = "Surf",
	rain = "CloudJump",
	fog = "CloudJump",
	rainbow = "CloudJump",
	fire = "Updraft", -- heat rises
	stars = "BlinkDash",
}

StormData.AbilityInfo = {
	Updraft = { name = "Updraft", emoji = "🌪️", description = "launches you high into the sky" },
	BlinkDash = { name = "Blink Dash", emoji = "⚡", description = "teleports you forward" },
	Surf = { name = "Surf Boost", emoji = "🏄", description = "a burst of speed" },
	CloudJump = { name = "Cloud Jump", emoji = "☁️", description = "jump again in mid-air; you also glide" },
	Flight = { name = "Cloud Flight", emoji = "🕊️", description = "fly on a cloud for a few seconds" },
}

function StormData.abilityOf(def: StormDef): string
	return def.ability or ABILITIES[def.fx] or "Surf"
end

function StormData.rarityOf(def: StormDef): Rarity
	return StormData.Rarities[def.rarity]
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
