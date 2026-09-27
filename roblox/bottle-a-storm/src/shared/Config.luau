--!strict
-- Every balance number in the game lives here. Tune the game from this file,
-- not from inside the services.

local Config = {}

-- One island per player. Set the place's Max Players to this number.
Config.MaxPlots = 8

Config.World = {
	CenterRadius = 110, -- the shared "Wild Skies" island where storms roam
	WildRoamRadius = 95,
	PlotRadius = 58,
	PlotRingDistance = 280, -- distance from the world center to each player island
	VoidKillY = -120, -- fall below this and you respawn
}

Config.Wild = {
	MaxStorms = 18,
	SpawnInterval = 2.5, -- seconds between spawn attempts
	HoverHeight = 5,
	DodgeRadius = 16, -- Rare+ storms run from players closer than this
	-- Seconds before a wild storm drifts away, by rarity index (Common .. Legendary).
	Lifetime = { 150, 130, 110, 90, 75 },
}

-- Catching: throw your Storm Jar at a storm. Rarer storms dodge and need more hits.
Config.Throw = {
	Cooldown = 0.7,
	Range = 60, -- farthest you can throw
	AimRadius = 6, -- how close to a storm your click must land (plus the storm's size)
	Speed = 90, -- jar flight speed, studs per second
	DazeSeconds = 0.9, -- a storm freezes this long after a hit that doesn't catch it
	DizzySeconds = 6, -- hits wear off if you wait longer than this between them
	-- By rarity index: Common, Uncommon, Rare, Epic, Legendary, Mythic, Cosmic
	HitsNeeded = { 1, 1, 2, 2, 3, 3, 4 },
	DodgeChance = { 0, 0.05, 0.15, 0.22, 0.3, 0.38, 0.45 },
	JarDodgeReduction = 0.6, -- the best jar cuts dodge chance by this much
	MutationChance = 0.08,
}

-- Storm Mixer: combine two storms into one.
Config.Mixing = {
	FeeSeconds = 30, -- fee = this many seconds of both storms' income
	MinFee = 50,
	MixSeconds = 2.5,
	UpgradeChance = 0.2, -- unknown mixes: chance the result is one rarity higher
	Range = 25, -- you must stand this close to your mixer
}

-- Storm moods. Happy storms earn more; neglected ones try to escape.
Config.Mood = {
	Start = 80, -- mood of a newly caught, mixed or rewarded storm (0-100)
	DecayPerMinute = 2.5, -- only while you're online: about 25 minutes from Happy to Bored
	TamerDecayMultiplier = 0.5, -- Storm Tamer pass: moods drop half as fast
	PetAmount = 25,
	PetCooldown = 45, -- seconds between pets for the same storm
	RideGainPerMinute = 20, -- the storm you ride gets happier
	EscapeBelow = 15, -- Restless storms can try to escape
	EscapeChancePerMinute = 0.25,
	EscapeWarnSeconds = 30, -- time you have to calm it down
	CalmTo = 60, -- mood after you calm an escaping storm
	SnackSeconds = 60, -- Storm Snacks cost this many seconds of your storms' income
	SnackMinCost = 100,
}

-- Season pass: Season Stars earned by playing (tiers and rewards are in SeasonData).
Config.Season = {
	PlaytimeXpPerMinute = 3,
	CatchXpPerRarity = 8, -- a Rare (rarity 3) catch gives 24
	StealXp = 30,
	MixXp = 20,
	RaidFightXp = 60, -- dealt any damage in a raid
	RaidWinXp = 100, -- extra when the server wins
	SkipTierXp = 250, -- the Robux "Skip a Tier" product
	DuplicatePremiumTiers = 3, -- if you buy Premium twice, you get this many tier skips instead
}

-- Trading storms and Sparks with other players in the server.
Config.Trading = {
	MaxStorms = 4, -- per side
	ConfirmSeconds = 5, -- countdown after both players press Ready
	RequestSeconds = 20, -- a trade request expires after this
	RequestCooldown = 5, -- seconds between requests you send
	UnevenRatio = 3, -- warn when one side earns this many times more than the other
}

-- Riding your storms.
Config.Ride = {
	SpeedByRarity = { 2, 3, 4, 6, 8, 10, 12 }, -- extra walk speed while riding
	MountScale = 0.6,
	Cooldowns = { Updraft = 5, BlinkDash = 3, Surf = 5, CloudJump = 0.3 },
	UpdraftPower = 120, -- upward launch speed
	DashDistance = 32,
	SurfSpeed = 85,
	SurfSeconds = 0.6,
	CloudJumpPower = 60,
	GlideFallSpeed = 14, -- cloud riders fall no faster than this
}

-- Jars decide the rarest storm you can hold and how wide your catch zone is.
Config.Jars = {
	{ name = "Glass Jar", cost = 0, maxRarity = 2, power = 0 },
	{ name = "Reinforced Jar", cost = 250, maxRarity = 3, power = 0.3 },
	{ name = "Crystal Jar", cost = 10000, maxRarity = 4, power = 0.6 },
	{ name = "Quantum Jar", cost = 250000, maxRarity = 5, power = 1 },
	-- These need a Climate Shift first (climate = the level you must be at).
	{ name = "Aurora Jar", cost = 2000000, maxRarity = 6, power = 1, climate = 1 },
	{ name = "Cosmic Jar", cost = 500000000, maxRarity = 7, power = 1, climate = 3 },
}

-- Climate Shift biome islands (the climates themselves are in ClimateData).
Config.Biomes = {
	MaxStorms = 8, -- per island
	SpawnInterval = 4,
}

Config.Pedestals = {
	Start = 3,
	Max = 10,
	MaxWithPass = 20,
	BaseCost = 40, -- cheap first upgrades so new players feel progress quickly
	CostGrowth = 2.2,
}

Config.Boots = {
	MaxLevel = 5,
	BaseCost = 100,
	CostGrowth = 4,
	SpeedPerLevel = 3,
}

-- Lightning Rod traps stun a thief the moment they grab one of your storms.
Config.Traps = {
	Costs = { 500, 10000, 100000 },
	StunPerLevel = 1.5,
}

Config.Income = {
	TickSeconds = 1,
	VIPMultiplier = 1.25,
	SellSeconds = 30, -- selling a storm pays this many seconds of its income
}

Config.Lock = {
	Duration = 90,
	Cooldown = 60, -- after a free lock ends, wait this long before locking again
	EmergencyDuration = 300, -- the Robux lock
}

Config.Steal = {
	HoldSeconds = 1.5,
	CarrySpeedMultiplier = 0.7,
	PromptDistance = 10,
	-- When one of your storms is stolen, you get this many seconds of its income back.
	RefundSeconds = 120,
}

Config.Zapper = {
	Range = 16,
	Cooldown = 2.5,
	StunSeconds = 2,
}

Config.Movement = {
	BaseWalkSpeed = 16,
}

Config.Weather = {
	FirstEventDelay = 120,
	Interval = 300, -- time between the end of one event and the start of the next
	Duration = 180,
}

-- The Mega-Storm raid: a server-wide boss fight every 25 minutes.
Config.Raid = {
	Interval = 1500, -- seconds from one raid's start to the next (25 minutes)
	FirstDelay = 600, -- first raid after a server starts
	StudioFirstDelay = 45, -- shorter in Studio so you can test it
	StudioInterval = 300,
	WarningSeconds = 60,
	Duration = 180,
	-- Boss HP = HpPerPlayer x each player's damage multiplier, summed over the server.
	-- About 60% of players fighting should be enough to win.
	HpPerPlayer = 1100,
	ShotDamage = 10,
	ShotCooldown = 0.6,
	BossHeight = 55,
	AttackInterval = 6,
	EnragedAttackInterval = 3.5,
	EnrageAt = 0.3, -- fraction of HP left
	StrikeRadius = 8,
	StrikeWarning = 1.5,
	StrikeStun = 1.5,
	MaxStrikeTargets = 4,
	GustEvery = 3, -- every Nth attack is a gust instead of lightning
	GustSpeed = 65,
	GustSeconds = 0.35,
	LegendaryChance = 0.15, -- reward odds; everything else is Epic
	MVPLegendaryChance = 0.3,
	FullIslandRewardSeconds = 600, -- reward paid as this much of the storm's income if your island is full
	NewPlayerGraceSeconds = 600, -- players who just joined never lose a storm
}

-- New players get this storm for free the first time they join.
Config.Starter = { StormId = "Puffcloud" }

-- Catch storms quickly one after another to build a combo.
Config.Combo = {
	WindowSeconds = 10, -- catch again within this to keep the combo going
	Max = 10,
	SparksPerStep = 25, -- bonus = max(this, 3 s of income) x (combo - 1)
	MutationBonusPerStep = 0.02, -- extra mutation chance per combo step
}

-- The golden storm hunt: a fast golden storm; first to catch it wins.
Config.Golden = {
	FirstDelay = 120,
	StudioFirstDelay = 30, -- shorter in Studio so you can test it
	Interval = 270,
	Lifetime = 60,
	Rarity = 3, -- Rare (any Reinforced Jar can catch it)
	SpeedMultiplier = 1.7,
	PrizeSeconds = 600, -- prize: 10 minutes of your income...
	PrizeMin = 3000, -- ...or at least this
}

-- Storm races: a storm zooms around a ring track on the Wild Skies.
Config.Race = {
	FirstDelay = 240,
	StudioFirstDelay = 75,
	Interval = 360,
	WarningSeconds = 20,
	Lifetime = 90,
	Rarity = 2, -- Uncommon, so even a Glass Jar can catch it
	Mutation = "Prismatic",
	HitsNeeded = 3,
	Speed = 24,
	TrackRadius = 72,
	Rings = 10,
	PrizeSeconds = 600,
	PrizeMin = 2500,
}

-- Your storms keep earning while you're away.
Config.Offline = {
	Rate = 0.25, -- 25% of your normal income
	MaxHours = 8,
	MinSeconds = 120, -- ignore very short breaks
}

-- A guard storm circles your island and zaps thieves carrying your storms.
Config.Guard = {
	Range = 26,
	CooldownByRarity = { 12, 10, 8, 7, 5, 4, 3 }, -- seconds between zaps
	OrbitRadius = 24,
	OrbitHeight = 14,
}

-- Storm Index: rewards for discovering storms and completing rarity rows.
Config.Index = {
	DiscoverSeconds = 60, -- a new storm pays 60 s of its income...
	DiscoverMin = 100, -- ...or at least this
	RowBonus = 0.05, -- +5% income forever per completed rarity row
}

-- Daily quests.
Config.Quests = {
	PerDay = 3,
	RewardSeconds = 300, -- 5 minutes of your income...
	RewardMin = 1000, -- ...or at least this
	RewardStars = 150, -- Season Stars
}

Config.Products = {
	SparksSmallMin = 1000,
	SparksSmallSeconds = 300, -- or 5 minutes of your income, whichever is more
	SparksLargeMin = 15000,
	SparksLargeSeconds = 3600,
}

-- New players earn extra for their first minutes of play.
Config.Beginner = {
	BoostSeconds = 900, -- 15 minutes of play time
	Multiplier = 2,
}

-- Storm buddy: one storm that floats next to you everywhere.
Config.Buddy = {
	Scale = 0.45,
}

-- Storm battles: your best 3 storms against another player's, for Sparks.
-- Nobody loses a storm.
Config.Battle = {
	TeamSize = 3,
	RequestSeconds = 20, -- a challenge expires after this
	RequestCooldown = 5, -- seconds between challenges you send
	Cooldown = 90, -- seconds between battles for each player
	PrizesPerDay = 10, -- only this many wins a day pay a prize (stops farming with a friend)
	PrizeSeconds = 120, -- winner: 2 minutes of their income...
	PrizeMin = 500, -- ...or at least this
	ConsolationSeconds = 30, -- loser: 30 seconds of income...
	ConsolationMin = 100,
	MaxTurns = 60, -- after this many hits, the side with more HP left wins
	AdvantageMultiplier = 1.5, -- weather type advantage (see BattleData)
	CritChance = 0.12,
	CritMultiplier = 1.6,
	PlaybackTurnSeconds = 0.8, -- how long each hit takes to show in the battle window
}

-- Cloud Flight (Robux game pass): fly on a cloud for a while, then rest.
Config.Flight = {
	Duration = 30, -- seconds per flight
	Cooldown = 20, -- seconds before you can fly again
	Speed = 40, -- studs per second
	VerticalSpeed = 28, -- up/down speed
	MaxHeight = 220, -- can't fly higher than this
}

-- Day and night: one full day in the sky takes this long.
Config.DayNight = {
	CycleSeconds = 720, -- 12 minutes
	NightShare = 0.3, -- 30% of it is night
}

Config.AutosaveSeconds = 60

return Config
