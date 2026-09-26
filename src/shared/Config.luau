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
		BodyColor = Color3.fromRGB(104, 170, 96),
		BellyColor = Color3.fromRGB(230, 220, 160),
		ShellColor = Color3.fromRGB(150, 104, 62),
		AccentColor = Color3.fromRGB(240, 200, 110),
	},
	Mossback = {
		DisplayName = "Mossback",
		BodyColor = Color3.fromRGB(150, 126, 100),
		BellyColor = Color3.fromRGB(225, 205, 175),
		ShellColor = Color3.fromRGB(86, 150, 66),
		AccentColor = Color3.fromRGB(255, 140, 190),
	},
	Tuskhorn = {
		DisplayName = "Tuskhorn",
		BodyColor = Color3.fromRGB(160, 116, 92),
		BellyColor = Color3.fromRGB(215, 180, 150),
		ShellColor = Color3.fromRGB(110, 78, 60),
		AccentColor = Color3.fromRGB(250, 245, 230),
	},
	Driftfin = {
		DisplayName = "Driftfin",
		BodyColor = Color3.fromRGB(84, 132, 196),
		BellyColor = Color3.fromRGB(215, 235, 250),
		ShellColor = Color3.fromRGB(46, 84, 150),
		AccentColor = Color3.fromRGB(120, 240, 255),
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
	WaveInterval = 7,
	MaxBeasts = 24,
	SpawnRadius = 160,
	Beast = { Health = 60, Damage = 6, Speed = 14, AttackEvery = 1.5, Size = Vector3.new(4, 3, 6) },
	Boss = { Health = 1800, Damage = 30, Speed = 9, AttackEvery = 2, Size = Vector3.new(14, 10, 20) },
	LootPerSurvivor = 120, -- coins added to the shared pool per surviving titan
	BossLootMult = 3,
	SlingDamage = 20,
	SlingRange = 80,
	SlingCooldown = 0.4,
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

-- Monetisation. Set Id to the real asset id after creating each item on the Creator Hub.
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

Config.DataStoreName = "GrowATitan_v1"
Config.AutosaveInterval = 90

return Config
