-- All tunable numbers for Grow a Titan live here.

local Config = {}

Config.Cycle = {
	DayLength = 480, -- seconds of Migration
	NightLength = 180, -- seconds of Nightfall
	BossEvery = 5, -- every Nth night has a boss
	StormChance = 0.25, -- chance a day starts with a natural storm
	StormLength = 90,
	-- Shorter cycle when play-testing in Studio so Nightfall comes quickly.
	StudioDayLength = 75,
	StudioNightLength = 60,
}

Config.Herd = {
	PathRadius = 700, -- radius of the migration loop
	LaneSpacing = 70, -- distance between neighbouring titans
	DaySpeed = 6, -- studs per second along the loop
	-- Scenery is kept clear of the lanes up to this many titans. Match it to the
	-- place's max server size (Game Settings) so titans never walk into buildings.
	MaxLanes = 12,
}

Config.Species = {
	Shellback = {
		DisplayName = "Shellback",
		BodyColor = Color3.fromRGB(70, 82, 60),
		BellyColor = Color3.fromRGB(120, 112, 88),
		ShellColor = Color3.fromRGB(72, 58, 44),
		AccentColor = Color3.fromRGB(190, 180, 160),
		SkinMaterial = Enum.Material.Slate,
	},
	Mossback = {
		DisplayName = "Mossback",
		BodyColor = Color3.fromRGB(78, 70, 58),
		BellyColor = Color3.fromRGB(110, 100, 82),
		ShellColor = Color3.fromRGB(52, 78, 40),
		AccentColor = Color3.fromRGB(160, 60, 70),
		SkinMaterial = Enum.Material.Rock,
	},
	Tuskhorn = {
		DisplayName = "Tuskhorn",
		BodyColor = Color3.fromRGB(88, 68, 58),
		BellyColor = Color3.fromRGB(120, 100, 88),
		ShellColor = Color3.fromRGB(60, 46, 40),
		AccentColor = Color3.fromRGB(225, 215, 190),
		SkinMaterial = Enum.Material.Slate,
	},
	Driftfin = {
		DisplayName = "Driftfin",
		BodyColor = Color3.fromRGB(44, 62, 84),
		BellyColor = Color3.fromRGB(96, 112, 124),
		ShellColor = Color3.fromRGB(26, 38, 60),
		AccentColor = Color3.fromRGB(80, 220, 255),
		SkinMaterial = Enum.Material.Slate,
	},
}
Config.SpeciesOrder = { "Shellback", "Mossback", "Tuskhorn", "Driftfin" }

-- Growth stages. GrowthToNext is nil on the last stage (time to Molt).
Config.Stages = {
	{ Name = "Hatchling", GrowthToNext = 60, Scale = 1.0, RiderSlots = 2, EggSlots = 1, IncomeMult = 1.0, MaxHealth = 120 },
	{ Name = "Juvenile", GrowthToNext = 180, Scale = 1.3, RiderSlots = 3, EggSlots = 2, IncomeMult = 1.25, MaxHealth = 180 },
	{ Name = "Young", GrowthToNext = 450, Scale = 1.6, RiderSlots = 4, EggSlots = 2, IncomeMult = 1.6, MaxHealth = 260 },
	{ Name = "Adult", GrowthToNext = 1100, Scale = 1.95, RiderSlots = 6, EggSlots = 3, IncomeMult = 2.0, MaxHealth = 380 },
	{ Name = "Elder", GrowthToNext = 2600, Scale = 2.3, RiderSlots = 8, EggSlots = 3, IncomeMult = 2.6, MaxHealth = 520 },
	{ Name = "Ancient", GrowthToNext = nil, Scale = 2.7, RiderSlots = 10, EggSlots = 4, IncomeMult = 3.4, MaxHealth = 720 },
}

Config.Growth = {
	IdlePerSecond = 0.2, -- while online
	OfflinePerSecond = 0.05, -- while away
	OfflineCapSeconds = 8 * 3600,
	FoodValue = 4, -- growth per food fed
	BaseFoodCapacity = 20,
}

Config.FoodCrate = {
	BaseCost = 30, -- coins, multiplied by CostGrowth^(stage-1)
	CostGrowth = 2.1,
	GrowthFraction = 0.12, -- share of the current stage requirement it gives
}

Config.Mutations = {
	{ Name = "Normal", Weight = 800, Mult = 1 },
	{ Name = "Golden", Weight = 80, Mult = 2, Color = Color3.fromRGB(255, 200, 40), Material = Enum.Material.Foil },
	{ Name = "Frost", Weight = 50, Mult = 1.8, Color = Color3.fromRGB(170, 225, 255), Material = Enum.Material.Ice },
	{ Name = "Molten", Weight = 40, Mult = 2.2, Color = Color3.fromRGB(255, 90, 30), Material = Enum.Material.Neon },
	{ Name = "Moonlit", Weight = 20, Mult = 3, Color = Color3.fromRGB(150, 140, 255), Material = Enum.Material.Glass },
	{ Name = "Rainbow", Weight = 8, Mult = 5, Rainbow = true },
	{ Name = "Void", Weight = 2, Mult = 10, Color = Color3.fromRGB(30, 10, 50), Material = Enum.Material.Neon },
}
Config.StormMutationLuck = 3 -- non-Normal weights are multiplied by this during storms

Config.Rarities = {
	{ Name = "Common", Weight = 600, HatchTime = 30, Color = Color3.fromRGB(200, 200, 200) },
	{ Name = "Uncommon", Weight = 250, HatchTime = 60, Color = Color3.fromRGB(90, 200, 90) },
	{ Name = "Rare", Weight = 110, HatchTime = 120, Color = Color3.fromRGB(70, 140, 255) },
	{ Name = "Epic", Weight = 32, HatchTime = 240, Color = Color3.fromRGB(170, 80, 255) },
	{ Name = "Legendary", Weight = 7, HatchTime = 480, Color = Color3.fromRGB(255, 170, 30) },
	{ Name = "Mythic", Weight = 1, HatchTime = 900, Color = Color3.fromRGB(255, 60, 120) },
}
Config.LuckyHatcherBoost = 1.5 -- non-Common weights multiplied by this with the pass

-- Riders: small creatures that live on your titan and earn coins per second.
Config.Riders = {
	{ Name = "Pebblet", Rarity = "Common", Income = 1, Color = Color3.fromRGB(160, 160, 150) },
	{ Name = "Fernmouse", Rarity = "Common", Income = 1, Color = Color3.fromRGB(110, 170, 90) },
	{ Name = "Puddlehop", Rarity = "Uncommon", Income = 3, Color = Color3.fromRGB(80, 170, 200) },
	{ Name = "Burrowbun", Rarity = "Uncommon", Income = 3, Color = Color3.fromRGB(200, 170, 130) },
	{ Name = "Glowmoth", Rarity = "Rare", Income = 8, Color = Color3.fromRGB(240, 230, 120) },
	{ Name = "Cragfox", Rarity = "Rare", Income = 8, Color = Color3.fromRGB(220, 110, 60) },
	{ Name = "Stormowl", Rarity = "Epic", Income = 25, Color = Color3.fromRGB(120, 120, 200) },
	{ Name = "Emberpup", Rarity = "Legendary", Income = 80, Color = Color3.fromRGB(255, 120, 40) },
	{ Name = "Starwhale Calf", Rarity = "Mythic", Income = 300, Color = Color3.fromRGB(80, 60, 200) },
}

Config.World = {
	FoodCount = 70,
	DigSpotCount = 14,
	WildRiderCount = 10,
	SpawnAheadMin = 0.02, -- radians ahead of the herd
	SpawnAheadMax = 0.45,
	SpawnSpread = 180, -- studs either side of the loop
	DespawnBehind = 0.25, -- radians behind the herd before an item is moved ahead
}

Config.Steal = {
	ShellLockBase = 30, -- seconds of protection after joining
	ShellLockPerMolt = 15,
	MinStageForRiderSteal = 3, -- smaller titans can only lose eggs
	CarryTimeout = 60,
	LeapRange = 170,
	HomesickNights = 1, -- nights a stolen rider can be called home for free
}

Config.Molt = {
	EarningsBonus = 0.15, -- per molt, permanent
	BonusRiderSlotsCap = 4, -- each molt adds one rider slot, up to this many
}

Config.Nightfall = {
	WaveInterval = 8,
	MaxMonsters = 24,
	SpawnRadius = 170,
	LootPerSurvivor = 120, -- coins added to the shared pool per surviving titan
	BossLootMult = 3,
	RoarStage = 4,
	RoarRadius = 70,
	RoarStun = 3,
	WeatheredStreak = 10,
}

Config.Perks = {
	ResonanceCount = 3,
	ResonanceMult = 1.25,
	HerdBondMult = 1.1,
	VipIncomeMult = 1.1,
}

-- Quests from the board in town: 3 at a time, a fresh set every RefreshMinutes.
-- Rewards per unit of the goal, scaled up by +15% for each fighter level.
Config.Quests = {
	RefreshMinutes = 20,
	LevelBonus = 0.15,
	Templates = {
		{ Stat = "Kill", Text = "Defeat %d monsters", Goals = { 6, 12, 20 }, CoinsEach = 45, XPEach = 10 },
		{ Stat = "Forage", Text = "Pick up %d food", Goals = { 15, 30, 45 }, CoinsEach = 12, XPEach = 3 },
		{ Stat = "Feed", Text = "Feed your titan %d food", Goals = { 20, 40 }, CoinsEach = 10, XPEach = 2 },
		{ Stat = "Chest", Text = "Open %d treasure chests", Goals = { 2, 3, 5 }, CoinsEach = 160, XPEach = 30 },
		{ Stat = "Spell", Text = "Cast %d spells", Goals = { 8, 15 }, CoinsEach = 25, XPEach = 6 },
	},
}

-- Treasure chests scattered ahead of the herd. Hold to open.
Config.Chests = {
	Count = 7,
	HoldTime = 1.2,
	CoinsBase = 120,
	CoinsPerStage = 60,
	IncomeSeconds = 45, -- or this many seconds of your income, if that is more
	XP = 25,
}

-- Monetisation. Balance rule: Robux buys time, style and convenience, never
-- the strongest power. The best weapon (Kingslayer Greatsword) is free-to-play
-- only, and the Robux weapons are sidegrades with special effects.
-- Set Id to the real asset id after creating each item on the Creator Hub.
-- Items with Id = 0 show in the shop but cannot be bought yet.
Config.GamePasses = {
	{ Key = "TitanWhistle", Name = "Titan Whistle", Price = 49, Id = 0, Description = "Teleport back to your titan any time." },
	{ Key = "BigBackpack", Name = "Big Backpack", Price = 99, Id = 0, Description = "Carry twice as much food." },
	{ Key = "AutoFeeder", Name = "Auto-Feeder", Price = 149, Id = 0, Description = "Your titan eats carried food automatically." },
	{ Key = "PlusRiderSlots", Name = "+2 Rider Slots", Price = 199, Id = 0, Description = "Two extra Rider slots on every titan." },
	{ Key = "DoubleGrowth", Name = "2x Growth", Price = 299, Id = 0, Description = "Your titan grows twice as fast." },
	{ Key = "VIP", Name = "VIP Herd", Price = 399, Id = 0, Description = "+10% coins, VIP tag and a free egg every day." },
	{ Key = "LuckyHatcher", Name = "Lucky Hatcher", Price = 499, Id = 0, Description = "Better odds on every egg." },
}

Config.DevProducts = {
	{ Key = "GrowthSnack", Name = "Growth Snack", Price = 29, Id = 0, Description = "2x growth for 15 minutes." },
	{ Key = "InstantHatch", Name = "Instant Hatch", Price = 49, Id = 0, Description = "Hatch every egg on your titan now." },
	{ Key = "CoinPouch", Name = "Coin Pouch", Price = 49, Id = 0, Description = "A pouch of coins (scales with your income)." },
	{ Key = "CoinChest", Name = "Coin Chest", Price = 299, Id = 0, Description = "A chest of coins (scales with your income)." },
	{ Key = "StormTotem", Name = "Storm Totem", Price = 199, Id = 0, Description = "Starts a storm for the whole server: rare mutations for everyone." },
}

-- Titan skins. Coin skins are bought in game; Robux skins are developer
-- products (set Id after creating them on the Creator Hub, 0 = Studio test only).
-- Colours left out fall back to the species colours.
Config.Skins = {
	{ Key = "Classic", Name = "Classic", Currency = "Free", Price = 0, Description = "Your titan's natural colours. Mutations tint the shell." },
	{
		Key = "Mossy",
		Name = "Mossy Grove",
		Currency = "Coins",
		Price = 5000,
		Description = "A shell overgrown with moss and flowers.",
		ShellColor = Color3.fromRGB(70, 140, 60),
		ShellMaterial = Enum.Material.Grass,
		AccentColor = Color3.fromRGB(255, 150, 200),
	},
	{
		Key = "Sandstone",
		Name = "Desert Stone",
		Currency = "Coins",
		Price = 20000,
		Description = "Carved sandstone plates, weathered by the Salt Flats.",
		ShellColor = Color3.fromRGB(215, 180, 120),
		ShellMaterial = Enum.Material.Sandstone,
		BodyColor = Color3.fromRGB(190, 150, 100),
		AccentColor = Color3.fromRGB(150, 90, 50),
	},
	{
		Key = "Candy",
		Name = "Candy Pop",
		Currency = "Robux",
		Price = 99,
		Id = 0,
		Description = "Pastel sweets from head to tail.",
		ShellColor = Color3.fromRGB(255, 150, 200),
		BodyColor = Color3.fromRGB(190, 170, 255),
		BellyColor = Color3.fromRGB(255, 250, 220),
		AccentColor = Color3.fromRGB(140, 240, 200),
		Effect = "Sparkles",
	},
	{
		Key = "Crystal",
		Name = "Crystal Shell",
		Currency = "Robux",
		Price = 149,
		Id = 0,
		Description = "A see-through shell that glitters in the sun.",
		ShellColor = Color3.fromRGB(150, 230, 255),
		ShellMaterial = Enum.Material.Glass,
		AccentColor = Color3.fromRGB(230, 250, 255),
		AccentMaterial = Enum.Material.Neon,
		Effect = "Sparkles",
	},
	{
		Key = "Lava",
		Name = "Lava Forge",
		Currency = "Robux",
		Price = 199,
		Id = 0,
		Description = "Cooling rock with glowing lava cracks and embers.",
		ShellColor = Color3.fromRGB(45, 40, 40),
		ShellMaterial = Enum.Material.Basalt,
		BodyColor = Color3.fromRGB(70, 55, 50),
		AccentColor = Color3.fromRGB(255, 110, 20),
		AccentMaterial = Enum.Material.Neon,
		Effect = "Embers",
	},
	{
		Key = "Mech",
		Name = "Mech Armor",
		Currency = "Robux",
		Price = 299,
		Id = 0,
		Description = "Armor plating with glowing power lines.",
		ShellColor = Color3.fromRGB(150, 155, 165),
		ShellMaterial = Enum.Material.DiamondPlate,
		BodyColor = Color3.fromRGB(90, 95, 105),
		BodyMaterial = Enum.Material.Metal,
		BellyColor = Color3.fromRGB(60, 65, 75),
		AccentColor = Color3.fromRGB(60, 230, 255),
		AccentMaterial = Enum.Material.Neon,
		Effect = "Lights",
	},
	{
		Key = "Galaxy",
		Name = "Galaxy",
		Currency = "Robux",
		Price = 399,
		Id = 0,
		Description = "A shell full of drifting stars that shifts colour.",
		ShellColor = Color3.fromRGB(60, 30, 120),
		ShellMaterial = Enum.Material.Neon,
		BodyColor = Color3.fromRGB(35, 25, 70),
		AccentColor = Color3.fromRGB(255, 255, 255),
		AccentMaterial = Enum.Material.Neon,
		Effect = "Stars",
		Galaxy = true,
	},
	{
		Key = "GoldenKing",
		Name = "Golden King",
		Currency = "Robux",
		Price = 499,
		Id = 0,
		Description = "Solid gold shell and a royal crown. Pure flex.",
		ShellColor = Color3.fromRGB(255, 200, 50),
		ShellMaterial = Enum.Material.Foil,
		BodyColor = Color3.fromRGB(250, 235, 200),
		AccentColor = Color3.fromRGB(200, 40, 60),
		Effect = "Sparkles",
		Crown = true,
	},
}

Config.Products = {
	GrowthSnackSeconds = 15 * 60,
	CoinPouchSeconds = 600, -- worth this many seconds of income
	CoinPouchMin = 1000,
	CoinChestSeconds = 4800,
	CoinChestMin = 8000,
}

-- Combat ----------------------------------------------------------------------

Config.Combat = {
	PvPEnabled = true,
	SafeZoneRadius = 240, -- Titan's Rest (the town in the middle) is a no-fighting zone
	SpawnProtection = 8, -- seconds of protection after respawning
	KillRewardBase = 50,
	KillRewardPerStage = 20,
	CritChance = 0.12, -- chance a hit lands as a critical
	CritMult = 1.75,
	PvPRepeatCooldown = 90, -- no reward for killing the same player again this soon
	BaseHealth = 100,
	BaseWalkSpeed = 16,
	RespawnTime = 5, -- seconds on the death screen before you wake up on your titan
}

-- Fighting experience. Killing monsters (and players) gives XP; each level
-- adds max health, max power and damage.
Config.Leveling = {
	MaxLevel = 50,
	XPBase = 100, -- XP needed to go from level 1 to 2
	XPGrowth = 1.3, -- each level needs this much more
	HealthPerLevel = 8,
	PowerPerLevel = 6,
	DamagePerLevel = 0.03, -- +3% damage per level
	PlayerKillXP = 40, -- plus PlayerKillXPPerLevel for each level the victim has
	PlayerKillXPPerLevel = 8,
}

-- Power (mana) pays for spells and refills over time.
Config.Power = {
	Base = 100,
	RegenPerSecond = 6,
}

-- Weapons. Free ones everybody owns; Coins ones are bought in the shop; Robux
-- ones are developer products (set Id after creating them, 0 = Studio test only).
-- Kind: "Melee" hits everything in front of you, "Ranged" fires at what you aim at.
Config.Weapons = {
	{
		Key = "Blade",
		Name = "Hunter's Blade",
		Kind = "Melee",
		Damage = 26,
		Range = 11,
		Cooldown = 0.5,
		Currency = "Free",
		Price = 0,
		Color = Color3.fromRGB(190, 195, 205),
		Description = "A trusty short sword.",
	},
	{
		Key = "Sling",
		Name = "Pebble Sling",
		Kind = "Ranged",
		Damage = 14,
		Range = 90,
		Cooldown = 0.4,
		Currency = "Free",
		Price = 0,
		Color = Color3.fromRGB(150, 110, 70),
		Description = "Fast pebbles from far away.",
	},
	{
		Key = "Crossbow",
		Name = "Bone Crossbow",
		Kind = "Ranged",
		Damage = 34,
		Range = 150,
		Cooldown = 0.85,
		MinLevel = 3,
		Currency = "Coins",
		Price = 2500,
		Color = Color3.fromRGB(230, 220, 200),
		Description = "Heavy bolts with long range.",
	},
	{
		Key = "Cleaver",
		Name = "Titan Cleaver",
		Kind = "Melee",
		Damage = 55,
		Range = 14,
		Cooldown = 0.9,
		MinLevel = 8,
		Currency = "Coins",
		Price = 10000,
		Color = Color3.fromRGB(120, 125, 135),
		Description = "A huge axe that hits everything in front of you.",
	},
	{
		Key = "Spear",
		Name = "Storm Spear",
		Kind = "Ranged",
		Damage = 60,
		Range = 130,
		Cooldown = 0.7,
		MinLevel = 15,
		Currency = "Coins",
		Price = 30000,
		Color = Color3.fromRGB(120, 180, 255),
		Description = "Thrown lightning that pierces through foes.",
	},
	{
		Key = "Greatsword",
		Name = "Kingslayer Greatsword",
		Kind = "Melee",
		Damage = 115,
		Range = 15,
		Cooldown = 1.1,
		Currency = "Coins",
		MinLevel = 25,
		Price = 120000,
		Color = Color3.fromRGB(240, 210, 120),
		Description = "The strongest blade in the land. Earned, never bought with Robux.",
	},
	{
		Key = "Maul",
		Name = "Thunder Maul",
		Kind = "Melee",
		Damage = 70,
		Range = 16,
		Cooldown = 1.1,
		Currency = "Robux",
		Price = 249,
		Id = 0,
		Color = Color3.fromRGB(90, 200, 255),
		Shock = true,
		Description = "Each smash sends out a shockwave.",
	},
	{
		Key = "Reaper",
		Name = "Soul Reaper",
		Kind = "Melee",
		Damage = 80,
		Range = 16,
		Cooldown = 1.0,
		Currency = "Robux",
		Price = 449,
		Id = 0,
		Color = Color3.fromRGB(170, 40, 60),
		Lifesteal = 0.2,
		Description = "A cursed scythe. Heals you for a fifth of the damage.",
	},
}

-- Spells: two attack spells, one control spell and two defence spells.
-- Unlock with coins, then upgrade to level 5. Keys are for keyboard players.
Config.Spells = {
	{
		Key = "Fireball",
		Name = "Fireball",
		Type = "Attack",
		Hotkey = "Z",
		PowerCost = 20,
		Cooldown = 6,
		Damage = 40,
		DamagePerLevel = 18,
		Radius = 12,
		Range = 140,
		UnlockCost = 1500,
		Color = Color3.fromRGB(255, 120, 30),
		Description = "Explodes where it lands.",
	},
	{
		Key = "Lightning",
		Name = "Lightning Strike",
		Type = "Attack",
		Hotkey = "X",
		PowerCost = 35,
		Cooldown = 10,
		Damage = 75,
		DamagePerLevel = 30,
		Range = 160,
		Chains = 2,
		UnlockCost = 6000,
		Color = Color3.fromRGB(150, 200, 255),
		Description = "Strikes your target, then jumps to more.",
	},
	{
		Key = "FrostNova",
		Name = "Frost Nova",
		Type = "Attack",
		Hotkey = "C",
		PowerCost = 30,
		Cooldown = 14,
		Damage = 20,
		DamagePerLevel = 10,
		Radius = 26,
		Stun = 2.5,
		UnlockCost = 4000,
		Color = Color3.fromRGB(170, 230, 255),
		Description = "Freezes everything around you in place.",
	},
	{
		Key = "Shield",
		Name = "Stone Shield",
		Type = "Defence",
		Hotkey = "V",
		PowerCost = 25,
		Cooldown = 16,
		Absorb = 60,
		AbsorbPerLevel = 35,
		Duration = 6,
		UnlockCost = 2500,
		Color = Color3.fromRGB(220, 190, 120),
		Description = "Blocks incoming damage for a few seconds.",
	},
	{
		Key = "Heal",
		Name = "Healing Light",
		Type = "Defence",
		Hotkey = "B",
		PowerCost = 25,
		Cooldown = 14,
		Heal = 40,
		HealPerLevel = 20,
		UnlockCost = 2000,
		Color = Color3.fromRGB(120, 255, 150),
		Description = "Heals you straight away.",
	},
}
Config.SpellMaxLevel = 5
Config.SpellUpgradeCost = 2500 -- multiplied by the current level squared

-- Coin upgrades. Cost for the next level = BaseCost * Growth^level.
Config.Upgrades = {
	{ Key = "Strength", Name = "Strength", MaxLevel = 10, BaseCost = 800, Growth = 1.7, Description = "+10% damage with weapons and spells per level." },
	{ Key = "Armor", Name = "Armor", MaxLevel = 10, BaseCost = 800, Growth = 1.7, Description = "+20 max health per level." },
	{ Key = "Swiftness", Name = "Swiftness", MaxLevel = 6, BaseCost = 1000, Growth = 1.9, Description = "Run faster (+1.5 speed per level)." },
	{
		Key = "AutoPicker",
		Name = "Auto-Picker",
		MaxLevel = 5,
		BaseCost = 400,
		Growth = 2.6,
		Description = "Automatically grabs food around you. Bigger radius each level.",
	},
}
Config.AutoPickerRadius = { 14, 22, 32, 46, 65 }

-- Monsters. Day monsters roam near the herd; night monsters hunt in waves.
Config.Monsters = {
	Gloomling = {
		Name = "Gloomling",
		Health = 30,
		Damage = 3,
		Speed = 10,
		AttackEvery = 1.5,
		Size = 0.6,
		Aggro = 35,
		Reward = 10,
		XP = 12,
		Color = Color3.fromRGB(60, 55, 70),
		Eye = Color3.fromRGB(255, 120, 60),
	},
	Gloomhound = {
		Name = "Gloomhound",
		Health = 70,
		Damage = 9,
		Speed = 18,
		AttackEvery = 1.2,
		Size = 1,
		Aggro = 70,
		Reward = 35,
		XP = 25,
		Color = Color3.fromRGB(40, 38, 48),
		Eye = Color3.fromRGB(255, 40, 40),
	},
	Thornback = {
		Name = "Thornback",
		Health = 160,
		Damage = 16,
		Speed = 13,
		AttackEvery = 1.6,
		Size = 1.5,
		Aggro = 60,
		Reward = 80,
		XP = 60,
		Color = Color3.fromRGB(70, 55, 45),
		Eye = Color3.fromRGB(255, 170, 30),
	},
	Golem = {
		Name = "Stone Golem",
		Health = 420,
		Damage = 30,
		Speed = 8,
		AttackEvery = 2.2,
		Size = 2.2,
		Aggro = 55,
		Reward = 200,
		XP = 150,
		Color = Color3.fromRGB(95, 95, 100),
		Eye = Color3.fromRGB(120, 220, 255),
	},
	StormKing = {
		Name = "Storm King",
		Health = 2500,
		Damage = 45,
		Speed = 9,
		AttackEvery = 2,
		Size = 5,
		Aggro = 140,
		Reward = 1500,
		XP = 1200,
		Color = Color3.fromRGB(45, 25, 70),
		Eye = Color3.fromRGB(200, 120, 255),
		Boss = true,
	},
}
-- Weak Gloomlings always prowl just outside town: a safe first fight.
Config.StarterMonsters = { Count = 10, Kind = "Gloomling", InnerRadius = 265, OuterRadius = 380 }
Config.DayMonsters = { Count = 8, Kinds = { "Gloomhound", "Gloomhound", "Thornback", "Golem" } }
Config.NightMonsterKinds = { "Gloomhound", "Gloomhound", "Gloomhound", "Thornback", "Thornback", "Golem" }

-- Driving your titan from the saddle.
Config.Drive = {
	Speed = 28,
	TurnRate = 1.1, -- radians per second
	ReturnSpeed = 30, -- speed when it walks back to the herd after you get off
	MaxRadius = 1550, -- stay inside the mountains
}

Config.DataStoreName = "GrowATitan_v1"
Config.AutosaveInterval = 90

return Config
