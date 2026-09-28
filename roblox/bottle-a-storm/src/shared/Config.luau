--!strict
-- Every balance number in the game lives here. Tune the game from this file,
-- not from inside the services.

local Config = {}

-- Bed Wars matches (the rest is in MatchData).
Config.Match = {
	MinPlayers = 2, -- players needed to start a match
	StudioMinPlayers = 1, -- in Studio a match starts with just you, for testing
	CountdownSeconds = 15,
	EndSeconds = 10, -- the winner screen before going back to the lobby
	RespawnSeconds = 5,
	SpawnProtection = 3, -- seconds of safety after respawning
	SoloUpTo = 4, -- up to this many players: everyone for themselves; more: teams of 2
	SuddenDeathAt = 1200, -- 20 minutes in, every bed breaks
	MaxSeconds = 1800, -- 30 minutes: the team with the most players left wins
	-- Each team island's generator.
	Generator = {
		Copper = { every = 1.2, cap = 48 },
		Silver = { every = 6, cap = 12 },
	},
	-- Generators on the middle island.
	Crystals = { every = 30, cap = 4, count = 4, radius = 55 },
	Cores = { every = 60, cap = 2, count = 2, radius = 30 },
	TierUpAt = { 360, 720 }, -- the middle generators speed up at these times
	-- Combat.
	HitCooldown = 0.45,
	StickDamage = 4, -- the Knockback Stick barely hurts...
	StickKnockback = 2.6, -- ...but sends people flying
	SwordRange = 9,
	Knockback = 32,
	BowDamage = 22,
	BowCooldown = 0.8,
	BowRange = 140,
	AppleHeal = 40,
	PearlRange = 60,
	-- Gadgets (GadgetService).
	TNTFuse = 3,
	TNTRadius = 8,
	TNTDamage = 40, -- at the center, less farther out
	TNTKnockback = 70,
	FireballSpeed = 70,
	FireballRange = 90,
	FireballRadius = 5,
	FireballDamage = 15,
	FireballKnockback = 55,
	PotionSeconds = 30,
	SpeedBoost = 1.4,
	JumpBoost = 1.8,
	-- Blocks.
	BlockSize = 3,
	BlockReach = 20,
	-- Digging: a pickaxe or axe also digs into the islands' ground. Holes
	-- are filled back in after the match.
	RocketSpeed = 110,
	RocketRange = 260,
	RocketRadius = 11,
	RocketDamage = 40,
	RocketKnockback = 75,
	DigRadius = 2.6,
	DigDepth = -8, -- can't dig deeper than this (the island's rocky bottom)
	DigKeepAway = 9, -- studs from beds, generators, shops and spawns
	MaxBlockHeight = 70,
	BedBreakSeconds = 2.5,
}

-- The lobby: a floating castle island of its own next to the battle map,
-- where you wait between matches (spawn, leaderboards, forecast TV, duel
-- arena, training dummies and the parkour).
Config.Lobby = {
	Center = Vector3.new(0, 20, -620), -- the island's grass top
	Radius = 90,
	CastleHalf = 44, -- the castle walls are a square this far from the center
	StreetDistance = 190, -- the shop street island, behind the castle (-Z)
	StreetRadius = 56,
}

-- Background music (MusicController). Add songs as Roblox audio ids: in
-- Studio open Toolbox > Audio, pick the Music category (the free
-- Roblox-licensed tracks), right-click a song > Copy Asset ID and paste the
-- number here, e.g. Lobby = { 1234567890, 2345678901 }. Empty lists play
-- nothing. The volume is in ⚙️ Settings.
Config.Music = {
	Lobby = {} :: { number }, -- calm songs between matches
	Match = {} :: { number }, -- faster songs while you fight
	Victory = nil :: number?, -- a short fanfare when your team wins
	Volume = 0.35,
}

-- 🤖 Bots (BotService): computer players that fill empty teams, so a
-- match can start with just one real player.
Config.Bots = {
	Enabled = true,
	MinTeams = 4, -- bot teams are added until a match has this many teams
	SoloCountdown = 40, -- the wait before a match when you're alone with bots
	Reach = 6.5,
	-- Voted in the lobby (🗳️ Vote); Normal when nobody votes.
	Difficulties = {
		Easy = {
			emoji = "🟢",
			health = 70,
			damage = 0.35, -- times the damage of a player's sword
			cooldown = 1.3, -- seconds between swings
			sight = 30, -- they go after enemies this close
			speed = 13,
			bedBreak = 6, -- seconds to break a bed
		},
		Normal = { emoji = "🟡", health = 100, damage = 0.55, cooldown = 0.9, sight = 45, speed = 15, bedBreak = 4 },
		Hard = { emoji = "🔴", health = 150, damage = 0.85, cooldown = 0.65, sight = 65, speed = 17, bedBreak = 2.5 },
	} :: {
		[string]: {
			emoji: string,
			health: number,
			damage: number,
			cooldown: number,
			sight: number,
			speed: number,
			bedBreak: number,
		},
	},
	DifficultyOrder = { "Easy", "Normal", "Hard" },
	Names = {
		"Bolt",
		"Nimbus",
		"Drizzle",
		"Gusty",
		"Thunder",
		"Misty",
		"Cyclone",
		"Hailey",
		"Breeze",
		"Sleet",
		"Squall",
		"Zephyr",
		"Flurry",
		"Sparky",
		"Tempest",
		"Cirrus",
	},
}

-- 🐉 The Storm Dragon boss (BossService) attacks the middle island.
Config.Boss = {
	Enabled = true,
	FirstAt = 240, -- seconds into a match
	Every = 300, -- seconds between visits
	StaySeconds = 150, -- it flies away if nobody beats it by then
	BaseHealth = 900,
	HealthPerPlayer = 250,
	CircleRadius = 50,
	FlyHeight = 38,
	FlySeconds = 14, -- circling and spitting fireballs...
	LandSeconds = 10, -- ...then landing to stomp (hit it with swords now!)
	FireEvery = 2.2,
	FireballDamage = 22,
	StompEvery = 3,
	StompRadius = 16,
	StompDamage = 25,
	HelperSparks = 400, -- everyone who hurt it
	TeamLoot = { Crystals = 6, Cores = 3 }, -- each player on the team that hurt it most
}

-- 🛡️ Clans (ClanService).
Config.Clans = {
	CreateCost = 5000, -- Sparks
	MaxMembers = 20,
	NameMax = 20,
	TagMin = 2,
	TagMax = 4,
	InviteSeconds = 30,
	-- Tag colors (each clan gets one).
	Colors = {
		Color3.fromRGB(255, 120, 120),
		Color3.fromRGB(255, 190, 90),
		Color3.fromRGB(255, 235, 110),
		Color3.fromRGB(130, 230, 140),
		Color3.fromRGB(110, 210, 255),
		Color3.fromRGB(170, 140, 255),
		Color3.fromRGB(255, 140, 220),
	},
}

-- 🤝 Trading (TradeService).
Config.Trade = {
	RequestSeconds = 30,
	MaxItems = 8, -- kits and cosmetics per side
}

-- 📱 Friend invites (InviteService).
Config.Invite = {
	NewSparks = 1000, -- the new player
	NewKitRarity = 3, -- and a Rare kit
	InviterSparks = 1500, -- the friend who invited them
	MaxRewards = 25, -- invites that pay Sparks (they still count after)
}

-- 🧟 Zombie Survival mode (ZombieService).
Config.Zombies = {
	Waves = 10,
	FirstDelay = 20, -- seconds to build walls before wave 1
	BreakSeconds = 15, -- between waves
	BaseCount = 4, -- zombies in wave 1...
	PerWave = 2, -- ...plus this many more each wave...
	PerPlayer = 2, -- ...and this many per extra player
	Health = 60,
	HealthPerWave = 18,
	BruteHealth = 4, -- Brutes (every 5th wave) have this many times the health
	Damage = 8,
	DamagePerWave = 1.5,
	Speed = 11,
	SpeedPerWave = 0.35,
	Reach = 5.5,
	HitCooldown = 1.1,
	SightRange = 70,
	BedBreakSeconds = 5,
	KillCopper = 3, -- for each zombie you knock out
	WaveSparks = 60, -- times the wave number, for everyone still in
}

-- Lucky Blocks mode (MatchData.Modes): ❓ blocks to break for surprises.
Config.Lucky = {
	Interval = 45, -- seconds between new batches of blocks
	PerIsland = 2, -- on each team island per batch
	Middle = 6, -- on the middle island per batch
	MaxBlocks = 40,
	Hits = 3, -- sword hits to open one
	Size = 3.2,
}

-- 🏆 Weekend tournaments: a 1v1 bracket in the lobby's duel arena. On
-- Saturdays and Sundays (UTC) one starts every EveryMinutes; admins can start
-- one any time. Matches wait while a tournament is on.
Config.Tournament = {
	EveryMinutes = 30,
	SignupSeconds = 60,
	MinPlayers = 2,
	MaxPlayers = 8,
	Prizes = { Champion = 5000, RunnerUp = 2000, Semifinal = 750, Joined = 150 },
}

-- 1v1 duels in the castle lobby's arena (challenge people from 👥 Party).
Config.Duel = {
	InviteSeconds = 20,
	CountdownSeconds = 3,
	Seconds = 90, -- no knockout by then: a draw
	SwordTier = 3, -- both duelists get an iron sword
	WinSparks = 150,
	RewardsPerDay = 10, -- wins that pay Sparks each day
}

-- Parties (👥 Party): friends who always end up on the same team.
Config.Party = {
	MaxSize = 4,
	InviteSeconds = 60, -- an invite expires after this
}

-- Team islands around the middle (up to 8 teams). Set the place's Max
-- Players to this number.
Config.MaxPlots = 8

Config.World = {
	CenterRadius = 165, -- the middle island: the Crystal and Core generators (the lobby is the castle island)
	PlotRadius = 58,
	PlotRingDistance = 340, -- distance from the world center to each team island
	VoidKillY = -120, -- fall below this and you're knocked out
}

-- Battle pass: Season Stars (tiers and rewards are in SeasonData). Most stars
-- come from matches (MatchData.Rewards); this is the rest.
Config.Season = {
	PlaytimeXpPerMinute = 3,
	SkipTierXp = 250, -- the Robux "Skip a Tier" product
	DuplicatePremiumTiers = 3, -- if you buy Premium twice, you get this many tier skips instead
	StarBoosterMultiplier = 1.5, -- the Star Booster pass
}

-- Rewards (RewardService).
Config.Rewards = {
	DuplicateCosmeticSparks = 1500, -- a battle pass cosmetic you already own pays this instead
}

-- Kit powers (Shift in a match). Rarer kits recharge faster (StormData
-- rarity "cooldown").
Config.Kit = {
	Cooldowns = {
		Updraft = 6,
		BlinkDash = 5,
		Surf = 5,
		CloudJump = 0.3,
		Flight = 25,
		Heal = 18,
		Bridge = 14,
		Volley = 10,
	},
	UpdraftPower = 110, -- upward launch speed
	DashDistance = 24,
	SurfSpeed = 75,
	SurfSeconds = 0.6,
	CloudJumpPower = 55,
	GlideFallSpeed = 14, -- cloud kits fall no faster than this
	FlightSeconds = 4,
	FlightSpeed = 45,
	BuddyScale = 0.45, -- the kit storm floating beside you
	HealAmount = 35, -- Healing Rain: health for you and teammates nearby
	HealRange = 18,
	BridgeLength = 10, -- Instant Bridge: blocks in a line ahead of you
	VolleyArrows = 5, -- Arrow Volley: free arrows in a fan
}

-- Sparks (IncomeService).
Config.Income = {
	VIPMultiplier = 1.25, -- the VIP pass: +25% match Sparks
}

-- Match weather (WeatherEvents): events during Bed Wars matches.
Config.Weather = {
	FirstEventDelay = 180, -- after a match starts
	Interval = 240, -- time between the end of one event and the start of the next
	Duration = 90,
	SummonSeconds = 600, -- the Robux "Summon Rainbow Hour" lasts 10 minutes
}

-- New players get this kit for free the first time they join.
Config.Starter = { StormId = "Puffcloud" }

-- Kit Collection: Sparks for your first kit of each kind (by rarity), and
-- +5% match Sparks forever per completed rarity row.
Config.Index = {
	DiscoverSparks = { 100, 250, 600, 1500, 4000, 10000, 25000 },
	RowBonus = 0.05,
}

-- Daily quests.
Config.Quests = {
	PerDay = 3,
	RewardSparks = 400,
	RewardStars = 150, -- battle pass stars
}

Config.Products = {
	SparksSmall = 1000,
	SparksLarge = 20000,
}

-- Your Roblox group: members get a Sparks bonus. Put your group's ID here
-- (the number in its web address). 0 turns the bonus off.
Config.Group = {
	Id = 0,
	Bonus = 0.1, -- +10% Sparks
	Name = "our group",
}

-- The like goal shown in the lobby and in 🎁 Rewards → Codes. Roblox
-- doesn't let games read their like count, so update this by hand and post
-- the code when you reach the goal.
Config.LikeGoal = {
	Goal = 1000,
	Reward = "a code for ⚡3,000 Sparks",
}

-- Holiday events (dates are in HolidayData). In Studio you can force one on to
-- test it: "Halloween", "Winter", "Summer", or nil for the real calendar.
Config.Holiday = {
	StudioEvent = "Halloween" :: string?,
}

-- Admin Abuse: the owner (and anyone in UserIds) gets a 👑 Admin panel to
-- start or end matches and start server-wide events. Admin Abuse also runs by
-- itself once a week.
Config.Admin = {
	UserIds = {} :: { number }, -- extra admins besides the game's owner
	AbuseMinutes = 30,
	AbuseIncomeMultiplier = 2, -- match Sparks while Admin Abuse is on
	-- Weekly automatic Admin Abuse (UTC). Weekday: 1 = Sunday ... 7 = Saturday.
	WeeklyDay = 7,
	WeeklyHour = 17,
}

-- Lobby parkour: a hidden path of cloud platforms from the edge of the middle
-- island up to a secret island with a free Epic kit once a day.
Config.Obby = {
	StartAngle = 60, -- degrees around the lobby island (it starts outside the castle gate)
	Radius = 95,
	Steps = 30,
	StepAngle = 3.3, -- degrees between platforms
	Rise = 3.4, -- studs up per platform
	BaseHeight = 3,
	Checkpoints = { 10, 20 }, -- platforms that must be touched on the way up
}

-- Style Bonus: every cosmetic you use adds its rarity tier's bonus
-- (CosmeticsData.Tiers) to your match Sparks, up to this much in total.
Config.Style = {
	MaxBonus = 0.5, -- +50%
}

-- Day and night: one full day in the sky takes this long.
Config.DayNight = {
	CycleSeconds = 720, -- 12 minutes
	NightShare = 0.3, -- 30% of it is night
}

Config.AutosaveSeconds = 60

return Config
