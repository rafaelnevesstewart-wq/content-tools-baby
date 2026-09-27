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

local TitleData = {}

TitleData.List = {
	{
		id = "Rookie",
		name = "Storm Rookie",
		emoji = "🌱",
		color = rgb(120, 220, 140),
		goal = "Catch your first storm",
		target = 1,
		progress = stat("captured"),
	},
	{
		id = "Catcher",
		name = "Storm Catcher",
		emoji = "🫙",
		color = rgb(120, 190, 255),
		goal = "Catch 100 storms",
		target = 100,
		progress = stat("captured"),
	},
	{
		id = "Master",
		name = "Storm Master",
		emoji = "👑",
		color = rgb(255, 200, 60),
		goal = "Catch 1,000 storms",
		target = 1000,
		progress = stat("captured"),
	},
	{
		id = "Sneaky",
		name = "Sneaky Thief",
		emoji = "🥷",
		color = rgb(170, 140, 220),
		goal = "Steal a storm",
		target = 1,
		progress = stat("stolen"),
	},
	{
		id = "ThiefKing",
		name = "Thief King",
		emoji = "😈",
		color = rgb(200, 90, 255),
		goal = "Steal 50 storms",
		target = 50,
		progress = stat("stolen"),
	},
	{
		id = "Mixologist",
		name = "Mixologist",
		emoji = "🧪",
		color = rgb(255, 130, 200),
		goal = "Mix storms 10 times",
		target = 10,
		progress = stat("mixed"),
	},
	{
		id = "Trader",
		name = "Sky Trader",
		emoji = "🤝",
		color = rgb(255, 170, 110),
		goal = "Finish 10 trades",
		target = 10,
		progress = stat("trades"),
	},
	{
		id = "RaidHero",
		name = "Raid Hero",
		emoji = "🦸",
		color = rgb(255, 110, 110),
		goal = "Fight in 10 Mega-Storm raids",
		target = 10,
		progress = stat("raids"),
	},
	{
		id = "BattleChamp",
		name = "Battle Champ",
		emoji = "⚔️",
		color = rgb(255, 120, 90),
		goal = "Win 10 storm battles",
		target = 10,
		progress = stat("battlesWon"),
	},
	{
		id = "GoldenHunter",
		name = "Golden Hunter",
		emoji = "✨",
		color = rgb(255, 210, 60),
		goal = "Win 3 Golden Hunts or Storm Races",
		target = 3,
		progress = stat("huntsWon"),
	},
	{
		id = "CloudPopper",
		name = "Cloud Popper",
		emoji = "💥",
		color = rgb(255, 150, 210),
		goal = "Pop 100 grumpy clouds",
		target = 100,
		progress = stat("grumpsPopped"),
	},
	{
		id = "SplashChamp",
		name = "Splash Champ",
		emoji = "💦",
		color = rgb(110, 190, 255),
		goal = "Splash 100 players with water balloons",
		target = 100,
		progress = stat("splashes"),
	},
	{
		id = "Collector",
		name = "Collector",
		emoji = "📖",
		color = rgb(140, 200, 255),
		goal = "Complete 3 rows of the Storm Index",
		target = 3,
		progress = function(data)
			return data.indexRows or 0
		end,
	},
	{
		id = "LegendHunter",
		name = "Legend Hunter",
		emoji = "🌟",
		color = rgb(255, 190, 40),
		goal = "Get a Legendary storm",
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
	{
		id = "Shifter",
		name = "Climate Shifter",
		emoji = "🌍",
		color = rgb(110, 170, 255),
		goal = "Do a Climate Shift",
		target = 1,
		progress = stat("shifts"),
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
