--!strict
-- Titles you earn by playing and can show above your name.
-- `progress` reads the player's saved data and returns how far along they are.

local StormData = require(script.Parent.StormData)

export type Title = {
	id: string,
	name: string,
	emoji: string,
	color: Color3,
	goal: string, -- how to earn it, shown in the Titles tab
	target: number,
	progress: (data: any) -> number,
}

local rgb = Color3.fromRGB

local function stat(key: string): (any) -> number
	return function(data)
		return data.stats[key] or 0
	end
end

local function hasRarity(rarity: number): (any) -> number
	return function(data)
		for id in data.discovered do
			local def = StormData.get(id)
			if def and def.rarity >= rarity then
				return 1
			end
		end
		return 0
	end
end

local function kills(data: any): number
	return data.stats.kills or 0
end

local TitleData = {}

TitleData.List = {
	{
		id = "Challenger",
		name = "Challenger",
		emoji = "🌟",
		color = rgb(255, 230, 120),
		goal = "Finish every Weekly Challenge in a week",
		target = 1,
		progress = stat("weeklyCleared"),
	},
	{
		id = "TourneyChamp",
		name = "Tournament Champion",
		emoji = "🏆",
		color = rgb(255, 205, 70),
		goal = "Win a weekend tournament",
		target = 1,
		progress = stat("tournamentWins"),
	},
	{
		id = "Rookie",
		name = "Rookie",
		emoji = "🌱",
		color = rgb(120, 220, 140),
		goal = "Play your first Bed Wars match",
		target = 1,
		progress = stat("matches"),
	},
	{
		id = "Regular",
		name = "Sky Regular",
		emoji = "☁️",
		color = rgb(170, 210, 255),
		goal = "Play 50 matches",
		target = 50,
		progress = stat("matches"),
	},
	{
		id = "FirstBlood",
		name = "First Blood",
		emoji = "🗡️",
		color = rgb(230, 90, 90),
		goal = "Knock out a player",
		target = 1,
		progress = kills,
	},
	{
		id = "Fighter",
		name = "Sky Fighter",
		emoji = "⚔️",
		color = rgb(255, 140, 110),
		goal = "Knock out 100 players",
		target = 100,
		progress = kills,
	},
	{
		id = "Slayer",
		name = "Storm Slayer",
		emoji = "💀",
		color = rgb(200, 60, 80),
		goal = "Knock out 1,000 players",
		target = 1000,
		progress = kills,
	},
	{
		id = "Finisher",
		name = "Finisher",
		emoji = "☠️",
		color = rgb(170, 90, 220),
		goal = "Get 25 final kills",
		target = 25,
		progress = stat("finalKills"),
	},
	{
		id = "Warlord",
		name = "Storm Warlord",
		emoji = "👹",
		color = rgb(200, 80, 255),
		goal = "Get 250 final kills",
		target = 250,
		progress = stat("finalKills"),
	},
	{
		id = "BedBreaker",
		name = "Bed Breaker",
		emoji = "🛏️",
		color = rgb(255, 150, 90),
		goal = "Break 10 cloud beds",
		target = 10,
		progress = stat("bedsBroken"),
	},
	{
		id = "Nightmare",
		name = "Bedtime Nightmare",
		emoji = "😈",
		color = rgb(255, 90, 40),
		goal = "Break 100 cloud beds",
		target = 100,
		progress = stat("bedsBroken"),
	},
	{
		id = "Winner",
		name = "Winner",
		emoji = "🏅",
		color = rgb(255, 225, 120),
		goal = "Win a match",
		target = 1,
		progress = stat("wins"),
	},
	{
		id = "Champion",
		name = "Sky Champion",
		emoji = "🏆",
		color = rgb(255, 210, 60),
		goal = "Win 25 matches",
		target = 25,
		progress = stat("wins"),
	},
	{
		id = "Legend",
		name = "Bed Wars Legend",
		emoji = "👑",
		color = rgb(255, 190, 40),
		goal = "Win 250 matches",
		target = 250,
		progress = stat("wins"),
	},
	{
		id = "SkyClimber",
		name = "Sky Climber",
		emoji = "🏔️",
		color = rgb(170, 220, 255),
		goal = "Reach the top of the lobby parkour",
		target = 1,
		progress = stat("obbyClears"),
	},
	{
		id = "Collector",
		name = "Kit Collector",
		emoji = "📖",
		color = rgb(140, 200, 255),
		goal = "Complete 3 rows of your Kit Collection",
		target = 3,
		progress = function(data)
			return data.indexRows or 0
		end,
	},
	{
		id = "LegendHunter",
		name = "Legend Owner",
		emoji = "🌟",
		color = rgb(255, 190, 40),
		goal = "Get a Legendary kit",
		target = 1,
		progress = hasRarity(5),
	},
	{
		id = "Millionaire",
		name = "Millionaire",
		emoji = "💰",
		color = rgb(90, 200, 120),
		goal = "Earn ⚡1,000,000 in total",
		target = 1000000,
		progress = stat("sparksEarned"),
	},
} :: { Title }

function TitleData.get(id: string?): Title?
	for _, title in TitleData.List do
		if title.id == id then
			return title
		end
	end
	return nil
end

return TitleData
