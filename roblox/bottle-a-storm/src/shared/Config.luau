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
	-- By rarity index: Common, Uncommon, Rare, Epic, Legendary
	HitsNeeded = { 1, 1, 2, 2, 3 },
	DodgeChance = { 0, 0.1, 0.25, 0.35, 0.45 },
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
	SpeedByRarity = { 2, 3, 4, 6, 8, 10 }, -- extra walk speed while riding
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
