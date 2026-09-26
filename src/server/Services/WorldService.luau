-- Builds the map (four biomes around the migration loop) and keeps food,
-- egg dig spots and wild Riders spawning just ahead of the moving herd.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)

local WorldService = {}
local S

local rng = Random.new()
local pickups = {} -- list of { Part, Kind }
local pickupFolder

local BIOMES = {
	-- Quadrants in loop order, starting at angle 0.
	{ Name = "Fern Valley", Ground = Color3.fromRGB(96, 160, 70), Material = Enum.Material.Grass, Decor = Color3.fromRGB(50, 120, 50) },
	{ Name = "Salt Flats", Ground = Color3.fromRGB(230, 225, 210), Material = Enum.Material.Sand, Decor = Color3.fromRGB(250, 250, 250) },
	{ Name = "Aurora Tundra", Ground = Color3.fromRGB(220, 235, 245), Material = Enum.Material.Snow, Decor = Color3.fromRGB(60, 110, 90) },
	{ Name = "Ember Wastes", Ground = Color3.fromRGB(80, 50, 45), Material = Enum.Material.Basalt, Decor = Color3.fromRGB(255, 90, 30) },
}

local function wrapPi(a: number): number
	a = (a + math.pi) % (math.pi * 2)
	return a - math.pi
end

local function biomeAt(angle: number)
	local quadrant = math.floor((angle % (math.pi * 2)) / (math.pi / 2)) + 1
	return BIOMES[math.clamp(quadrant, 1, 4)]
end

local function anchoredPart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		part[key] = value
	end
	return part
end

local function buildMap()
	local map = Instance.new("Folder")
	map.Name = "Map"

	-- One ground tile per biome quadrant. Quadrant k covers angles [(k-1)*90°, k*90°).
	for index, biome in BIOMES do
		local mid = (index - 0.5) * math.pi / 2
		local sx = math.cos(mid) >= 0 and 1 or -1
		local sz = math.sin(mid) >= 0 and 1 or -1
		anchoredPart({
			Name = biome.Name,
			Size = Vector3.new(1600, 2, 1600),
			Position = Vector3.new(sx * 800, -1, sz * 800),
			Color = biome.Ground,
			Material = biome.Material,
		}).Parent =
			map
	end

	-- Dirt trail that the herd follows.
	local segments = 72
	local r = Config.Herd.PathRadius
	for i = 1, segments do
		local a = (i - 0.5) / segments * math.pi * 2
		local position = Vector3.new(math.cos(a) * r, 0.05, math.sin(a) * r)
		local tangent = Vector3.new(-math.sin(a), 0, math.cos(a))
		local length = 2 * math.pi * r / segments + 2
		local trail = anchoredPart({
			Name = "Trail",
			Size = Vector3.new(90, 0.2, length),
			Color = Color3.fromRGB(150, 115, 80),
			Material = Enum.Material.Ground,
			CanCollide = false,
		})
		trail.CFrame = CFrame.lookAt(position, position + tangent)
		trail.Parent = map
	end

	-- Scenery away from the herd's lanes.
	for _ = 1, 160 do
		local a = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber() < 0.5 and rng:NextNumber(150, r - 260) or rng:NextNumber(r + 260, 1500)
		local biome = biomeAt(a)
		local base = Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
		local height = rng:NextNumber(12, 40)
		anchoredPart({
			Name = "Trunk",
			Size = Vector3.new(3, height, 3),
			Position = base + Vector3.new(0, height / 2, 0),
			Color = Color3.fromRGB(100, 70, 45),
			Material = Enum.Material.Wood,
		}).Parent =
			map
		local crown = anchoredPart({
			Name = "Crown",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * rng:NextNumber(10, 22),
			Position = base + Vector3.new(0, height, 0),
			Color = biome.Decor,
			Material = biome.Name == "Ember Wastes" and Enum.Material.Neon or Enum.Material.Grass,
		})
		crown.Parent = map
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = Vector3.new(r, 0.5, 0)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Duration = 0
	spawn.Parent = map

	map.Parent = workspace
end

-- Pickups ---------------------------------------------------------------------

local function placeAhead(part: BasePart)
	local herdAngle = S.TitanService:GetAngle()
	local a = herdAngle + rng:NextNumber(Config.World.SpawnAheadMin, Config.World.SpawnAheadMax)
	local radius = Config.Herd.PathRadius + rng:NextNumber(-Config.World.SpawnSpread, Config.World.SpawnSpread)
	part.Position = Vector3.new(math.cos(a) * radius, part.Size.Y / 2, math.sin(a) * radius)
	part:SetAttribute("Angle", a % (math.pi * 2))
end

local function makePrompt(part: BasePart, action: string, object: string, hold: number)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = hold
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 10
	prompt.Parent = part
	return prompt
end

local function spawnFood()
	local part = anchoredPart({
		Name = "Fernfruit",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 2,
		Color = Color3.fromRGB(255, 120, 150),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	})
	placeAhead(part)
	part.Parent = pickupFolder
	makePrompt(part, "Pick", "Fernfruit", 0).Triggered:Connect(function(player)
		local added = S.PlayerService:AddFood(player, rng:NextInteger(1, 3))
		if added <= 0 then
			S.PlayerService:Notify(player, "Backpack full! Feed your titan.")
			return
		end
		placeAhead(part)
	end)
	table.insert(pickups, part)
end

local function spawnDigSpot()
	local part = anchoredPart({
		Name = "DigSpot",
		Size = Vector3.new(6, 1.2, 6),
		Color = Color3.fromRGB(110, 80, 50),
		Material = Enum.Material.Ground,
		CanCollide = false,
	})
	placeAhead(part)
	part.Parent = pickupFolder
	local sparkle = Instance.new("Sparkles")
	sparkle.SparkleColor = Color3.fromRGB(255, 230, 120)
	sparkle.Parent = part
	makePrompt(part, "Dig", "Buried egg", 2).Triggered:Connect(function(player)
		if S.PlayerService:FreeEggSlots(player) <= 0 then
			S.PlayerService:Notify(player, "Your egg slots are full. Grow your titan or wait for a hatch.")
			return
		end
		local rarity = S.PlayerService:RollRarity(player)
		S.PlayerService:AddEgg(player, rarity)
		S.PlayerService:Notify(player, string.format("You dug up a %s egg!", rarity))
		placeAhead(part)
	end)
	table.insert(pickups, part)
end

local function spawnWildRider()
	local part = anchoredPart({
		Name = "WildRider",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 2.6,
		CanCollide = false,
	})
	local function reroll()
		local rarity = rng:NextNumber() < 0.75 and "Common" or "Uncommon"
		local def = S.PlayerService:MakeRider(nil, rarity, "Normal")
		part:SetAttribute("RiderName", def.Name)
		part.Color = Util.riderDef(def.Name).Color
		local prompt = part:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.ObjectText = "Wild " .. def.Name
		end
	end
	placeAhead(part)
	part.Parent = pickupFolder
	local prompt = makePrompt(part, "Tame", "Wild Rider", 1.5)
	reroll()
	prompt.Triggered:Connect(function(player)
		if S.PlayerService:FreeRiderSlots(player) <= 0 then
			S.PlayerService:Notify(player, "No free Rider slot. Release a Rider or grow your titan.")
			return
		end
		local rider = { Name = part:GetAttribute("RiderName"), Mutation = S.PlayerService:RollMutation(player) }
		if S.PlayerService:AddRider(player, rider) then
			local profile = S.PlayerService:GetProfile(player)
			profile.TamedCount += 1
			local prefix = rider.Mutation ~= "Normal" and (rider.Mutation .. " ") or ""
			S.PlayerService:Notify(player, string.format("You tamed a %s%s!", prefix, rider.Name))
			placeAhead(part)
			reroll()
		end
	end)
	table.insert(pickups, part)
end

function WorldService:BiomeName(): string
	return biomeAt(S.TitanService:GetAngle()).Name
end

function WorldService:Init(services)
	S = services
end

function WorldService:Start()
	buildMap()
	pickupFolder = Instance.new("Folder")
	pickupFolder.Name = "Pickups"
	pickupFolder.Parent = workspace
	for _ = 1, Config.World.FoodCount do
		spawnFood()
	end
	for _ = 1, Config.World.DigSpotCount do
		spawnDigSpot()
	end
	for _ = 1, Config.World.WildRiderCount do
		spawnWildRider()
	end

	local lastBiome = nil
	while true do
		task.wait(2)
		local herdAngle = S.TitanService:GetAngle()
		for _, part in pickups do
			local a = part:GetAttribute("Angle") or 0
			if wrapPi(a - herdAngle) < -Config.World.DespawnBehind then
				placeAhead(part)
			end
		end
		local biome = self:BiomeName()
		ReplicatedStorage:SetAttribute("Biome", biome)
		if biome ~= lastBiome then
			if lastBiome then
				S.PlayerService:NotifyAll("The herd has entered " .. biome .. "!")
			end
			lastBiome = biome
		end
	end
end

return WorldService
