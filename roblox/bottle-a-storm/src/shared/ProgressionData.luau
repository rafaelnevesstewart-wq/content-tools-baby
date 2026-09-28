--!strict
-- Long-term progress (ProgressionService): your level and prestige, your
-- ranked rank, win streaks and achievements.

local SeasonData = require(script.Parent.SeasonData)

local ProgressionData = {}

---------------------------------------------------------------------------
-- Levels and prestige
---------------------------------------------------------------------------

ProgressionData.MaxLevel = 100
ProgressionData.MaxPrestige = 10

-- XP from each thing you do in a match.
ProgressionData.Xp = { Played = 40, Kill = 10, FinalKill = 20, Bed = 30, Win = 80 }

-- XP needed to go from `level` to the next one.
function ProgressionData.xpFor(level: number): number
	return 100 + (level - 1) * 10
end

-- Sparks for reaching a level (every 10th level gives a kit too).
function ProgressionData.levelSparks(level: number): number
	return 50 + level * 5
end

ProgressionData.PrestigeSparks = 5000

-- The star in front of your level shows your prestige.
ProgressionData.PrestigeColors = {
	Color3.fromRGB(235, 240, 250), -- no prestige yet
	Color3.fromRGB(255, 200, 80),
	Color3.fromRGB(120, 220, 255),
	Color3.fromRGB(140, 240, 140),
	Color3.fromRGB(255, 120, 200),
	Color3.fromRGB(190, 120, 255),
	Color3.fromRGB(255, 120, 60),
	Color3.fromRGB(255, 80, 80),
	Color3.fromRGB(90, 255, 220),
	Color3.fromRGB(255, 240, 120),
	Color3.fromRGB(255, 255, 255),
}

---------------------------------------------------------------------------
-- Ranked
---------------------------------------------------------------------------

export type Rank = { name: string, emoji: string, points: number, color: Color3 }

ProgressionData.Ranks = {
	{ name = "Bronze", emoji = "🥉", points = 0, color = Color3.fromRGB(205, 127, 50) },
	{ name = "Silver", emoji = "🥈", points = 150, color = Color3.fromRGB(200, 205, 215) },
	{ name = "Gold", emoji = "🥇", points = 400, color = Color3.fromRGB(255, 205, 60) },
	{ name = "Platinum", emoji = "💠", points = 800, color = Color3.fromRGB(110, 230, 220) },
	{ name = "Diamond", emoji = "💎", points = 1300, color = Color3.fromRGB(110, 170, 255) },
	{ name = "Master", emoji = "🔮", points = 2000, color = Color3.fromRGB(190, 110, 255) },
	{ name = "Champion", emoji = "👑", points = 3000, color = Color3.fromRGB(255, 90, 90) },
} :: { Rank }

-- Rank points for a match (only matches with at least 2 teams count).
ProgressionData.RankPoints = { Win = 30, Loss = -12, FinalKill = 5, Bed = 8 }

function ProgressionData.rankOf(points: number): Rank
	local best = ProgressionData.Ranks[1]
	for _, rank in ProgressionData.Ranks do
		if points >= rank.points then
			best = rank
		end
	end
	return best
end

---------------------------------------------------------------------------
-- Win streaks
---------------------------------------------------------------------------

-- Extra Sparks for a win on a streak: this many per win in a row.
ProgressionData.StreakSparks = 50
ProgressionData.StreakSparksMax = 500

---------------------------------------------------------------------------
-- Achievements
---------------------------------------------------------------------------

export type Achievement = {
	id: string,
	name: string,
	emoji: string,
	goal: string,
	target: number,
	progress: (data: any) -> number,
	reward: SeasonData.Reward,
}

local function stat(key: string): (any) -> number
	return function(data)
		return data.stats[key] or 0
	end
end

local function field(key: string): (any) -> number
	return function(data)
		return data[key] or 0
	end
end

local function count(key: string): (any) -> number
	return function(data)
		local total = 0
		for _ in data[key] do
			total += 1
		end
		return total
	end
end

local function sparks(amount: number): SeasonData.Reward
	return { kind = "sparks", amount = amount }
end

local function kit(rarity: number, mutated: boolean?): SeasonData.Reward
	return { kind = "kit", rarity = rarity, mutated = mutated }
end

local function cosmetic(id: string): SeasonData.Reward
	return { kind = "cosmetic", id = id }
end

local function totalLevel(data: any): number
	return (data.prestige or 0) * ProgressionData.MaxLevel + (data.level or 1)
end

ProgressionData.Achievements = {
	-- Playing
	{
		id = "Play1",
		name = "First Match",
		emoji = "🎮",
		goal = "Play a match",
		target = 1,
		progress = stat("matches"),
		reward = sparks(200),
	},
	{
		id = "Play25",
		name = "Regular",
		emoji = "📅",
		goal = "Play 25 matches",
		target = 25,
		progress = stat("matches"),
		reward = kit(3),
	},
	{
		id = "Play100",
		name = "Dedicated",
		emoji = "🗓️",
		goal = "Play 100 matches",
		target = 100,
		progress = stat("matches"),
		reward = sparks(5000),
	},
	{
		id = "Play500",
		name = "No Life",
		emoji = "🌙",
		goal = "Play 500 matches",
		target = 500,
		progress = stat("matches"),
		reward = cosmetic("VeteranBed"),
	},
	-- Winning
	{
		id = "Win1",
		name = "Victory!",
		emoji = "🏅",
		goal = "Win a match",
		target = 1,
		progress = stat("wins"),
		reward = sparks(300),
	},
	{
		id = "Win10",
		name = "Winner",
		emoji = "🥇",
		goal = "Win 10 matches",
		target = 10,
		progress = stat("wins"),
		reward = kit(4),
	},
	{
		id = "Win50",
		name = "Champion",
		emoji = "🏆",
		goal = "Win 50 matches",
		target = 50,
		progress = stat("wins"),
		reward = sparks(10000),
	},
	{
		id = "Win200",
		name = "Unstoppable",
		emoji = "👑",
		goal = "Win 200 matches",
		target = 200,
		progress = stat("wins"),
		reward = cosmetic("ChampionTrail"),
	},
	-- Fighting
	{
		id = "Kill10",
		name = "Brawler",
		emoji = "🗡️",
		goal = "Knock out 10 players",
		target = 10,
		progress = stat("kills"),
		reward = sparks(300),
	},
	{
		id = "Kill100",
		name = "Fighter",
		emoji = "⚔️",
		goal = "Knock out 100 players",
		target = 100,
		progress = stat("kills"),
		reward = kit(4, true),
	},
	{
		id = "Kill1000",
		name = "Warlord",
		emoji = "💀",
		goal = "Knock out 1,000 players",
		target = 1000,
		progress = stat("kills"),
		reward = cosmetic("LegendKO"),
	},
	{
		id = "Final10",
		name = "Finisher",
		emoji = "☠️",
		goal = "Get 10 final kills",
		target = 10,
		progress = stat("finalKills"),
		reward = sparks(1000),
	},
	{
		id = "Final100",
		name = "Executioner",
		emoji = "⚰️",
		goal = "Get 100 final kills",
		target = 100,
		progress = stat("finalKills"),
		reward = kit(5),
	},
	-- Beds
	{
		id = "Bed1",
		name = "Bed Breaker",
		emoji = "🛏️",
		goal = "Break a cloud bed",
		target = 1,
		progress = stat("bedsBroken"),
		reward = sparks(300),
	},
	{
		id = "Bed25",
		name = "Nightmare",
		emoji = "😈",
		goal = "Break 25 cloud beds",
		target = 25,
		progress = stat("bedsBroken"),
		reward = kit(4),
	},
	{
		id = "Bed100",
		name = "Insomnia",
		emoji = "🌪️",
		goal = "Break 100 cloud beds",
		target = 100,
		progress = stat("bedsBroken"),
		reward = sparks(15000),
	},
	-- Streaks
	{
		id = "Streak3",
		name = "On Fire",
		emoji = "🔥",
		goal = "Win 3 matches in a row",
		target = 3,
		progress = field("bestStreak"),
		reward = sparks(1000),
	},
	{
		id = "Streak5",
		name = "Heat Wave",
		emoji = "☄️",
		goal = "Win 5 matches in a row",
		target = 5,
		progress = field("bestStreak"),
		reward = kit(5),
	},
	{
		id = "Streak10",
		name = "Inferno",
		emoji = "🌋",
		goal = "Win 10 matches in a row",
		target = 10,
		progress = field("bestStreak"),
		reward = kit(6, true),
	},
	-- Levels and ranks
	{
		id = "Level10",
		name = "Getting Started",
		emoji = "⭐",
		goal = "Reach level 10",
		target = 10,
		progress = totalLevel,
		reward = sparks(1000),
	},
	{
		id = "Level50",
		name = "Experienced",
		emoji = "🌟",
		goal = "Reach level 50",
		target = 50,
		progress = totalLevel,
		reward = kit(5),
	},
	{
		id = "Prestige1",
		name = "Prestige",
		emoji = "💫",
		goal = "Prestige for the first time",
		target = 1,
		progress = field("prestige"),
		reward = sparks(20000),
	},
	{
		id = "RankGold",
		name = "Golden",
		emoji = "🥇",
		goal = "Reach Gold rank",
		target = 400,
		progress = field("bestRank"),
		reward = sparks(2000),
	},
	{
		id = "RankDiamond",
		name = "Diamond Hands",
		emoji = "💎",
		goal = "Reach Diamond rank",
		target = 1300,
		progress = field("bestRank"),
		reward = kit(5, true),
	},
	{
		id = "RankChampion",
		name = "Sky Champion",
		emoji = "👑",
		goal = "Reach Champion rank",
		target = 3000,
		progress = field("bestRank"),
		reward = kit(7),
	},
	-- Lobby
	{
		id = "Duelist",
		name = "Duelist",
		emoji = "🤺",
		goal = "Win 10 duels in the lobby arena",
		target = 10,
		progress = stat("duelsWon"),
		reward = sparks(1500),
	},
	-- Collecting
	{
		id = "Kits10",
		name = "Kit Collector",
		emoji = "🌪️",
		goal = "Collect 10 kinds of kits",
		target = 10,
		progress = count("discovered"),
		reward = sparks(1500),
	},
	{
		id = "Kits30",
		name = "Kit Master",
		emoji = "📖",
		goal = "Collect 30 kinds of kits",
		target = 30,
		progress = count("discovered"),
		reward = kit(6),
	},
	{
		id = "Style10",
		name = "Fashionista",
		emoji = "🎨",
		goal = "Own 10 cosmetics",
		target = 10,
		progress = function(data)
			local total = 0
			for _ in data.cosmetics.owned do
				total += 1
			end
			return total
		end,
		reward = sparks(2500),
	},
} :: { Achievement }

function ProgressionData.achievement(id: string): Achievement?
	for _, achievement in ProgressionData.Achievements do
		if achievement.id == id then
			return achievement
		end
	end
	return nil
end

return ProgressionData
