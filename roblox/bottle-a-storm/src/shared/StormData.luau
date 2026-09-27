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
	hybrid: boolean?, -- only made in the Storm Mixer, never found in the wild
	biome: string?, -- only lives on that Climate Shift island (see ClimateData)
	weight: number?, -- spawn weight on its biome island
	season: string?, -- only from that season's pass (see SeasonData)
	holiday: string?, -- only during that holiday event (see HolidayData)
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
	mood: number?, -- 0-100; nil on storms saved before moods existed
	xp: number?, -- seconds owned while online; sets the storm's level
	wm: { string }?, -- weather mutations picked up during weather events (they stack)
}

export type MoodTier = {
	name: string,
	emoji: string,
	min: number,
	multiplier: number,
	color: Color3,
}

local StormData = {}

StormData.Rarities = {
	{
		index = 1,
		name = "Common",
		color = Color3.fromRGB(200, 205, 215),
		weight = 55,
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
		weight = 14,
		speed = 11,
		pull = 0.5,
		scale = 1.2,
	},
	{
		index = 4,
		name = "Epic",
		color = Color3.fromRGB(190, 90, 255),
		weight = 6,
		speed = 14,
		pull = 0.7,
		scale = 1.35,
	},
	{
		index = 5,
		name = "Legendary",
		color = Color3.fromRGB(255, 190, 40),
		weight = 1.8,
		speed = 17,
		pull = 0.9,
		scale = 1.5,
	},
	{
		index = 6,
		name = "Mythic",
		color = Color3.fromRGB(255, 80, 140),
		weight = 0, -- never wild: only from the Storm Mixer
		speed = 18,
		pull = 1,
		scale = 1.65,
	},
	{
		index = 7,
		name = "Cosmic",
		color = Color3.fromRGB(110, 170, 255),
		weight = 0, -- only on the Space island
		speed = 20,
		pull = 1,
		scale = 1.8,
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

	-- Hybrids: only from the Storm Mixer. The recipes are secret (server only).
	{
		id = "GhostFog",
		name = "Ghost Fog",
		rarity = 3,
		income = 90,
		colors = { rgb(225, 230, 255), rgb(180, 170, 220) },
		fx = "fog",
		hybrid = true,
	},
	{
		id = "ZappyDrizzle",
		name = "Zappy Drizzle",
		rarity = 3,
		income = 140,
		colors = { rgb(150, 190, 240), rgb(255, 235, 120) },
		fx = "lightning",
		hybrid = true,
	},
	{
		id = "SleetSprite",
		name = "Sleet Sprite",
		rarity = 4,
		income = 400,
		colors = { rgb(210, 235, 255), rgb(170, 200, 235) },
		fx = "hail",
		hybrid = true,
	},
	{
		id = "SandTwister",
		name = "Sand Twister",
		rarity = 4,
		income = 450,
		colors = { rgb(230, 200, 140), rgb(170, 240, 215) },
		fx = "dust",
		hybrid = true,
	},
	{
		id = "Thundernado",
		name = "Thundernado",
		rarity = 4,
		income = 900,
		colors = { rgb(90, 95, 130), rgb(140, 155, 140) },
		fx = "lightning",
		hybrid = true,
	},
	{
		id = "DoubleRainbow",
		name = "Double Rainbow",
		rarity = 4,
		income = 1100,
		colors = { rgb(255, 150, 180), rgb(150, 255, 200), rgb(160, 200, 255) },
		fx = "rainbow",
		hybrid = true,
	},
	{
		id = "DesertCyclone",
		name = "Desert Cyclone",
		rarity = 5,
		income = 6000,
		colors = { rgb(235, 195, 110), rgb(70, 190, 190) },
		fx = "hurricane",
		hybrid = true,
	},
	{
		id = "FrostVortex",
		name = "Frost Vortex",
		rarity = 5,
		income = 7500,
		colors = { rgb(200, 230, 255), rgb(120, 150, 200) },
		fx = "snow",
		hybrid = true,
	},
	{
		id = "StormSerpent",
		name = "Storm Serpent",
		rarity = 6,
		income = 15000,
		colors = { rgb(40, 90, 150), rgb(255, 235, 100) },
		fx = "lightning",
		hybrid = true,
	},
	{
		id = "AuroraSerpent",
		name = "Aurora Serpent",
		rarity = 6,
		income = 25000,
		colors = { rgb(120, 255, 200), rgb(200, 120, 255) },
		fx = "rainbow",
		hybrid = true,
	},
	{
		id = "TyphoonTitan",
		name = "Typhoon Titan",
		rarity = 6,
		income = 40000,
		colors = { rgb(30, 110, 140), rgb(70, 190, 190) },
		fx = "hurricane",
		hybrid = true,
	},

	-- Climate Shift biomes: each only lives on its own sky island.
	-- Arctic Skies
	{
		id = "FrostbitePup",
		name = "Frostbite Pup",
		rarity = 3,
		income = 200,
		colors = { rgb(220, 240, 255), rgb(170, 210, 245) },
		fx = "snow",
		biome = "Arctic",
		weight = 60,
	},
	{
		id = "SnowballYeti",
		name = "Snowball Yeti",
		rarity = 4,
		income = 1200,
		colors = { rgb(250, 252, 255), rgb(190, 215, 240) },
		fx = "snow",
		biome = "Arctic",
		weight = 28,
	},
	{
		id = "GlacierGuardian",
		name = "Glacier Guardian",
		rarity = 5,
		income = 9000,
		colors = { rgb(140, 210, 240), rgb(90, 160, 210) },
		fx = "hail",
		biome = "Arctic",
		weight = 10,
	},
	{
		id = "PolarAurora",
		name = "Polar Aurora",
		rarity = 6,
		income = 30000,
		colors = { rgb(120, 255, 200), rgb(120, 170, 255), rgb(210, 130, 255) },
		fx = "rainbow",
		biome = "Arctic",
		weight = 2,
	},
	-- Volcano Skies
	{
		id = "EmberPuff",
		name = "Ember Puff",
		rarity = 3,
		income = 400,
		colors = { rgb(255, 150, 80), rgb(120, 90, 90) },
		fx = "fire",
		biome = "Volcano",
		weight = 60,
	},
	{
		id = "MagmaMoth",
		name = "Magma Moth",
		rarity = 4,
		income = 2500,
		colors = { rgb(255, 110, 40), rgb(90, 50, 40) },
		fx = "fire",
		biome = "Volcano",
		weight = 28,
	},
	{
		id = "AshStormDrake",
		name = "Ash Storm Drake",
		rarity = 5,
		income = 18000,
		colors = { rgb(90, 85, 90), rgb(255, 120, 60) },
		fx = "dust",
		biome = "Volcano",
		weight = 10,
	},
	{
		id = "LavaRainGolem",
		name = "Lava Rain Golem",
		rarity = 6,
		income = 60000,
		colors = { rgb(255, 80, 30), rgb(60, 35, 35) },
		fx = "fire",
		biome = "Volcano",
		weight = 2,
	},
	-- Space Skies
	{
		id = "StardustSprite",
		name = "Stardust Sprite",
		rarity = 4,
		income = 5000,
		colors = { rgb(200, 190, 255), rgb(120, 110, 200) },
		fx = "stars",
		biome = "Space",
		weight = 60,
	},
	{
		id = "CometKid",
		name = "Comet Kid",
		rarity = 5,
		income = 40000,
		colors = { rgb(160, 220, 255), rgb(70, 90, 180) },
		fx = "stars",
		biome = "Space",
		weight = 28,
	},
	{
		id = "MeteorShowerWhale",
		name = "Meteor Shower Whale",
		rarity = 7,
		income = 250000,
		colors = { rgb(80, 70, 160), rgb(255, 170, 90) },
		fx = "stars",
		biome = "Space",
		weight = 9,
	},
	{
		id = "SolarFlarePhoenix",
		name = "Solar Flare Phoenix",
		rarity = 7,
		income = 500000,
		colors = { rgb(255, 210, 80), rgb(255, 110, 50) },
		fx = "fire",
		biome = "Space",
		weight = 3,
	},

	-- Holiday event storms (see HolidayData): they roam the Wild Skies and sit in
	-- the event shop only while their holiday is on.
	{
		id = "SpookyFog",
		name = "Spooky Fog",
		rarity = 4,
		income = 700,
		colors = { rgb(120, 110, 140), rgb(255, 140, 40) },
		fx = "fog",
		holiday = "Halloween",
	},
	{
		id = "PhantomSquall",
		name = "Phantom Squall",
		rarity = 5,
		income = 4500,
		colors = { rgb(70, 60, 90), rgb(150, 255, 170) },
		fx = "wind",
		holiday = "Halloween",
	},
	{
		id = "FrostbiteFlurry",
		name = "Frostbite Flurry",
		rarity = 4,
		income = 700,
		colors = { rgb(220, 240, 255), rgb(200, 40, 50) },
		fx = "snow",
		holiday = "Winter",
	},
	{
		id = "JollyNoreaster",
		name = "Jolly Nor'easter",
		rarity = 5,
		income = 4500,
		colors = { rgb(240, 245, 255), rgb(40, 140, 70) },
		fx = "snow",
		holiday = "Winter",
	},
	{
		id = "BeachBreeze",
		name = "Beach Breeze",
		rarity = 4,
		income = 700,
		colors = { rgb(120, 210, 230), rgb(250, 230, 170) },
		fx = "wind",
		holiday = "Summer",
	},
	{
		id = "TropicalTyphoon",
		name = "Tropical Typhoon",
		rarity = 5,
		income = 4500,
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
		income = 800,
		colors = { rgb(255, 190, 215), rgb(255, 240, 245) },
		fx = "rain",
		season = "SpringShowers",
	},
	{
		id = "PetalTwister",
		name = "Petal Twister",
		rarity = 5,
		income = 7000,
		colors = { rgb(255, 150, 190), rgb(170, 230, 150) },
		fx = "wind",
		season = "SpringShowers",
	},
	{
		id = "CherryMonsoon",
		name = "Cherry Monsoon",
		rarity = 6,
		income = 35000,
		colors = { rgb(255, 120, 170), rgb(120, 60, 90) },
		fx = "rain",
		season = "SpringShowers",
	},
	-- Summer Heatwave
	{
		id = "SunnyPuff",
		name = "Sunny Puff",
		rarity = 4,
		income = 900,
		colors = { rgb(255, 230, 110), rgb(255, 250, 220) },
		fx = "fire",
		season = "SummerHeatwave",
	},
	{
		id = "HeatwaveHawk",
		name = "Heatwave Hawk",
		rarity = 5,
		income = 7500,
		colors = { rgb(255, 160, 60), rgb(255, 90, 60) },
		fx = "fire",
		season = "SummerHeatwave",
	},
	{
		id = "TropicalTyphoon",
		name = "Tropical Typhoon",
		rarity = 6,
		income = 38000,
		colors = { rgb(60, 210, 190), rgb(255, 220, 120) },
		fx = "hurricane",
		season = "SummerHeatwave",
	},
	-- Autumn Gusts
	{
		id = "LeafyBreeze",
		name = "Leafy Breeze",
		rarity = 4,
		income = 850,
		colors = { rgb(230, 150, 60), rgb(200, 90, 40) },
		fx = "wind",
		season = "AutumnGusts",
	},
	{
		id = "PumpkinTornado",
		name = "Pumpkin Tornado",
		rarity = 5,
		income = 8000,
		colors = { rgb(255, 140, 30), rgb(60, 130, 50) },
		fx = "wind",
		season = "AutumnGusts",
	},
	{
		id = "HarvestMoonSquall",
		name = "Harvest Moon Squall",
		rarity = 6,
		income = 36000,
		colors = { rgb(255, 200, 110), rgb(120, 70, 140) },
		fx = "rainbow",
		season = "AutumnGusts",
	},
	-- Winter Wonder
	{
		id = "JingleFlurry",
		name = "Jingle Flurry",
		rarity = 4,
		income = 900,
		colors = { rgb(240, 250, 255), rgb(220, 60, 70) },
		fx = "snow",
		season = "WinterWonder",
	},
	{
		id = "CandyCaneCyclone",
		name = "Candy Cane Cyclone",
		rarity = 5,
		income = 8500,
		colors = { rgb(255, 255, 255), rgb(230, 50, 60) },
		fx = "hurricane",
		season = "WinterWonder",
	},
	{
		id = "AuroraReindeer",
		name = "Aurora Reindeer",
		rarity = 6,
		income = 40000,
		colors = { rgb(150, 110, 80), rgb(120, 255, 200) },
		fx = "rainbow",
		season = "WinterWonder",
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

StormData.MoodTiers = {
	{ name = "Happy", emoji = "😄", min = 70, multiplier = 1.25, color = Color3.fromRGB(120, 230, 120) },
	{ name = "Content", emoji = "🙂", min = 40, multiplier = 1, color = Color3.fromRGB(230, 230, 230) },
	{ name = "Bored", emoji = "😐", min = 15, multiplier = 0.8, color = Color3.fromRGB(255, 190, 90) },
	{ name = "Restless", emoji = "😤", min = -math.huge, multiplier = 0.5, color = Color3.fromRGB(255, 100, 100) },
} :: { MoodTier }

StormData.DefaultMood = 80

function StormData.moodValue(record: { mood: number? }): number
	return record.mood or StormData.DefaultMood
end

function StormData.moodOf(record: { mood: number? }): MoodTier
	local mood = StormData.moodValue(record)
	for _, tier in StormData.MoodTiers do
		if mood >= tier.min then
			return tier
		end
	end
	return StormData.MoodTiers[#StormData.MoodTiers]
end

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

-- Season pass and holiday storms: only from their pass or event, so they're
-- not in the wild roll or the Storm Index rows.
function StormData.isExclusive(def: StormDef): boolean
	return def.season ~= nil or def.holiday ~= nil
end

-- Storms of one rarity that roam the Wild Skies (no hybrids, no biome storms).
-- Storms that live on one Climate Shift island.
function StormData.ofBiome(biome: string): { StormDef }
	local list = {}
	for _, def in StormData.Storms do
		if def.biome == biome then
			table.insert(list, def)
		end
	end
	return list
end

function StormData.wildOfRarity(rarity: number): { StormDef }
	local list = {}
	for _, def in StormData.Storms do
		if def.rarity == rarity and not def.hybrid and not def.biome and not StormData.isExclusive(def) then
			table.insert(list, def)
		end
	end
	return list
end

-- Storm levels. Storms level up the longer you own them (time online):
-- the seconds needed to reach each level, Lv 1 to Lv 10.
StormData.LevelSeconds = { 0, 300, 900, 1800, 3600, 7200, 14400, 28800, 57600, 100800 }
StormData.LevelBonus = 0.1 -- +10% income per level above 1

function StormData.levelOf(record: { xp: number? }): number
	local xp = record.xp or 0
	local level = 1
	for index, needed in StormData.LevelSeconds do
		if xp >= needed then
			level = index
		end
	end
	return level
end

-- Seconds of ownership still needed for the next level, or nil at max level.
function StormData.toNextLevel(record: { xp: number? }): number?
	local nextNeeded = StormData.LevelSeconds[StormData.levelOf(record) + 1]
	return if nextNeeded then nextNeeded - (record.xp or 0) else nil
end

function StormData.levelMultiplier(record: { xp: number? }): number
	return 1 + StormData.LevelBonus * (StormData.levelOf(record) - 1)
end

-- Each storm's riding power, from its weather type.
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
}

function StormData.abilityOf(def: StormDef): string
	return ABILITIES[def.fx] or "Surf"
end

function StormData.rarityOf(def: StormDef): Rarity
	return StormData.Rarities[def.rarity]
end

-- Weather mutations: storms on your island can pick these up during weather
-- events. They stack (up to 4, no repeats) and multiply together.
export type WeatherMutation = {
	id: string,
	name: string,
	emoji: string,
	multiplier: number,
	events: { string }, -- WeatherEvents keys that can give it
}

StormData.WeatherMutations = {
	{
		id = "Wet",
		name = "Wet",
		emoji = "💧",
		multiplier = 1.25,
		events = { "RainbowHour", "ThunderFrenzy", "FogNight" },
	},
	{ id = "Misty", name = "Misty", emoji = "🌫️", multiplier = 1.5, events = { "FogNight" } },
	{ id = "Sunkissed", name = "Sunkissed", emoji = "☀️", multiplier = 1.5, events = { "DoubleSparks" } },
	{ id = "Shocked", name = "Shocked", emoji = "⚡", multiplier = 2, events = { "ThunderFrenzy" } },
	{ id = "Rainbowed", name = "Rainbowed", emoji = "🌈", multiplier = 2.5, events = { "RainbowHour" } },
	{ id = "Starstruck", name = "Starstruck", emoji = "🌠", multiplier = 3, events = { "MeteorNight" } },
	{ id = "Chaotic", name = "Chaotic", emoji = "🌀", multiplier = 4, events = { "MutationStorm" } },
} :: { WeatherMutation }

function StormData.getWeatherMutation(id: string): WeatherMutation?
	for _, mutation in StormData.WeatherMutations do
		if mutation.id == id then
			return mutation
		end
	end
	return nil
end

function StormData.weatherMultiplier(record: { wm: { string }? }): number
	local total = 1
	local list: { string } = record.wm or {}
	for _, id in list do
		local mutation = StormData.getWeatherMutation(id)
		if mutation then
			total *= mutation.multiplier
		end
	end
	return total
end

-- "💧⚡" (empty when the storm has none)
function StormData.weatherEmojis(record: { wm: { string }? }): string
	local text = ""
	local list: { string } = record.wm or {}
	for _, id in list do
		local mutation = StormData.getWeatherMutation(id)
		if mutation then
			text ..= mutation.emoji
		end
	end
	return text
end

-- Sparks per second for one owned storm, before player-wide bonuses like VIP.
function StormData.incomeOf(record: { id: string, mut: string?, wm: { string }? }): number
	local def = stormsById[record.id]
	if not def then
		return 0
	end
	local mutation = StormData.getMutation(record.mut)
	return def.income * (if mutation then mutation.multiplier else 1) * StormData.weatherMultiplier(record)
end

-- What the storm earns right now, mood and level included (before VIP).
function StormData.earningOf(record: { id: string, mut: string?, mood: number?, xp: number?, wm: { string }? }): number
	return StormData.incomeOf(record) * StormData.moodOf(record).multiplier * StormData.levelMultiplier(record)
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
