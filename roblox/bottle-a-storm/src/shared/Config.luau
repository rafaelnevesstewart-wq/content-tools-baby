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

Config.Capture = {
	PromptDistance = 12,
	MaxDistance = 30, -- you must stay this close while bottling
	MinSeconds = 1.8, -- the fastest possible honest catch; faster results are rejected
	Timeout = 25,
	EscapeCooldown = 3, -- a storm that just escaped can't be bottled for this long
	MutationChance = 0.08,
}

-- Jars decide the rarest storm you can hold and how wide your catch zone is.
Config.Jars = {
	{ name = "Glass Jar", cost = 0, maxRarity = 2, power = 0 },
	{ name = "Reinforced Jar", cost = 500, maxRarity = 3, power = 0.3 },
	{ name = "Crystal Jar", cost = 15000, maxRarity = 4, power = 0.6 },
	{ name = "Quantum Jar", cost = 250000, maxRarity = 5, power = 1 },
}

Config.Pedestals = {
	Start = 3,
	Max = 10,
	MaxWithPass = 20,
	BaseCost = 150,
	CostGrowth = 2.2,
}

Config.Boots = {
	MaxLevel = 5,
	BaseCost = 200,
	CostGrowth = 4,
	SpeedPerLevel = 3,
}

-- Lightning Rod traps stun a thief the moment they grab one of your storms.
Config.Traps = {
	Costs = { 1000, 10000, 100000 },
	StunPerLevel = 1.5,
}

Config.Income = {
	TickSeconds = 1,
	VIPMultiplier = 1.25,
	SellSeconds = 30, -- selling a storm pays this many seconds of its income
}

Config.Lock = {
	Duration = 60,
	Cooldown = 60, -- after a free lock ends, wait this long before locking again
	EmergencyDuration = 300, -- the Robux lock
}

Config.Steal = {
	HoldSeconds = 1.5,
	CarrySpeedMultiplier = 0.7,
	PromptDistance = 10,
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
	FirstEventDelay = 240,
	Interval = 600, -- time between the end of one event and the start of the next
	Duration = 180,
}

-- The Mega-Storm raid: a server-wide boss fight every 45 minutes.
Config.Raid = {
	Interval = 2700, -- seconds from one raid's start to the next
	FirstDelay = 900, -- first raid after a server starts
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

Config.Products = {
	SparksSmallMin = 1000,
	SparksSmallSeconds = 300, -- or 5 minutes of your income, whichever is more
	SparksLargeMin = 15000,
	SparksLargeSeconds = 3600,
}

Config.AutosaveSeconds = 60

return Config
