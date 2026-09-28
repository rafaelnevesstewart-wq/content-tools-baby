--!strict
-- 🎣 The fishing pond on Games Island (FishingService): what you can catch.
-- `chance` is the weight of each fish (bigger = more common), `weight` its
-- size range in kg, and `sparks` what it's worth (more for heavier ones).
-- Your catches are saved as data.fish (caught counts and best weights).

export type Fish = {
	id: string,
	name: string,
	emoji: string,
	rarity: string,
	chance: number,
	weight: { number },
	sparks: number,
}

local Config = require(script.Parent.Config)

local FishData = {}

-- The pond: on the east side of Games Island.
FishData.Center = Config.Lobby.Center + Vector3.new(Config.Lobby.SideDistance + 38, 0, 0)
FishData.Radius = 9

FishData.Rarities = {
	Junk = Color3.fromRGB(150, 140, 120),
	Common = Color3.fromRGB(200, 205, 215),
	Uncommon = Color3.fromRGB(110, 220, 120),
	Rare = Color3.fromRGB(80, 160, 255),
	Epic = Color3.fromRGB(190, 90, 255),
	Legendary = Color3.fromRGB(255, 190, 40),
	Mythic = Color3.fromRGB(255, 80, 140),
}

FishData.List = {
	{ id = "Boot", name = "Old Boot", emoji = "👢", rarity = "Junk", chance = 8, weight = { 0.5, 1.2 }, sparks = 2 },
	{
		id = "Minnow",
		name = "Sky Minnow",
		emoji = "🐟",
		rarity = "Common",
		chance = 30,
		weight = { 0.1, 0.4 },
		sparks = 10,
	},
	{
		id = "Guppy",
		name = "Cloud Guppy",
		emoji = "🐠",
		rarity = "Common",
		chance = 26,
		weight = { 0.1, 0.3 },
		sparks = 12,
	},
	{
		id = "Shrimp",
		name = "Storm Shrimp",
		emoji = "🦐",
		rarity = "Common",
		chance = 20,
		weight = { 0.05, 0.2 },
		sparks = 14,
	},
	{
		id = "Trout",
		name = "Rain Trout",
		emoji = "🐟",
		rarity = "Uncommon",
		chance = 14,
		weight = { 1, 3 },
		sparks = 30,
	},
	{
		id = "Crab",
		name = "Bubble Crab",
		emoji = "🦀",
		rarity = "Uncommon",
		chance = 12,
		weight = { 0.5, 2 },
		sparks = 35,
	},
	{
		id = "Puffer",
		name = "Puffer Puff",
		emoji = "🐡",
		rarity = "Uncommon",
		chance = 10,
		weight = { 0.4, 1.5 },
		sparks = 40,
	},
	{
		id = "Octo",
		name = "Thunder Octopus",
		emoji = "🐙",
		rarity = "Rare",
		chance = 5,
		weight = { 2, 6 },
		sparks = 90,
	},
	{
		id = "Squid",
		name = "Lightning Squid",
		emoji = "🦑",
		rarity = "Rare",
		chance = 5,
		weight = { 1.5, 5 },
		sparks = 100,
	},
	{ id = "Koi", name = "Rainbow Koi", emoji = "🎏", rarity = "Epic", chance = 2, weight = { 3, 8 }, sparks = 250 },
	{
		id = "Turtle",
		name = "Old Sky Turtle",
		emoji = "🐢",
		rarity = "Epic",
		chance = 1.6,
		weight = { 10, 30 },
		sparks = 300,
	},
	{
		id = "Shark",
		name = "Cyclone Shark",
		emoji = "🦈",
		rarity = "Legendary",
		chance = 0.6,
		weight = { 40, 120 },
		sparks = 800,
	},
	{
		id = "Whale",
		name = "Cloud Whale",
		emoji = "🐋",
		rarity = "Legendary",
		chance = 0.4,
		weight = { 200, 600 },
		sparks = 1200,
	},
	{
		id = "StormEel",
		name = "Storm Serpent",
		emoji = "🐉",
		rarity = "Mythic",
		chance = 0.12,
		weight = { 50, 150 },
		sparks = 5000,
	},
} :: { Fish }

FishData.BiteAfter = { 2, 7 } -- seconds before a fish bites
FishData.ReactSeconds = 1.3 -- how long you have to click once it bites
FishData.CastRange = 26 -- how far from the pond's middle you can fish from
FishData.MaxSparksPerDay = 3000 -- fish stop paying Sparks after this much a day (they still count)...
FishData.AlwaysPays = { Legendary = true, Mythic = true } :: { [string]: boolean } -- ...except these, which always pay in full

function FishData.get(id: string?): Fish?
	for _, fish in FishData.List do
		if fish.id == id then
			return fish
		end
	end
	return nil
end

-- Picks a fish; `roll` is a number from 0 to 1.
function FishData.pick(roll: number): Fish
	local total = 0
	for _, fish in FishData.List do
		total += fish.chance
	end
	local at = roll * total
	for _, fish in FishData.List do
		at -= fish.chance
		if at <= 0 then
			return fish
		end
	end
	return FishData.List[2]
end

return FishData
