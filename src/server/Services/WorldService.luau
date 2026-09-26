-- Builds the map (four biomes around the migration loop) and keeps food,
-- egg dig spots and wild Riders spawning just ahead of the moving herd.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local MapBuilder = require(script.Parent.MapBuilder)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Util = require(ReplicatedStorage.Shared.Util)

local WorldService = {}
local S

local rng = Random.new()
local pickups = {} -- every pickup part (food, dig spots, wild Riders)
local foods = {} -- just the food parts, for the Auto-Picker
local pickupFolder

local function wrapPi(a: number): number
	a = (a + math.pi) % (math.pi * 2)
	return a - math.pi
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
	table.insert(foods, part)
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

function WorldService:TravelPoint(place: string): Vector3?
	if place == "Base" then
		return MapBuilder.TravelPoints.Base
	end
	return MapBuilder.TravelPoints[place]
end

-- Auto-Picker upgrade: grabs food within a radius of the player.
local function autoPick()
	for _, player in Players:GetPlayers() do
		local profile = S.PlayerService:GetProfile(player)
		local level = profile and profile.Upgrades.AutoPicker or 0
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if level > 0 and hrp then
			local radius = Config.AutoPickerRadius[math.min(level, #Config.AutoPickerRadius)]
			for _, food in foods do
				local offset = (food.Position - hrp.Position) * Vector3.new(1, 0, 1)
				if offset.Magnitude <= radius and math.abs(food.Position.Y - hrp.Position.Y) < radius then
					if S.PlayerService:AddFood(player, rng:NextInteger(1, 3)) <= 0 then
						break
					end
					placeAhead(food)
				end
			end
		end
	end
end

function WorldService:BiomeName(): string
	return MapBuilder.Biomes[MapBuilder.biomeIndexAt(S.TitanService:GetAngle())].Name
end

function WorldService:Init(services)
	S = services
end

function WorldService:Start()
	MapBuilder.build()
	-- Base buildings in town open their shop tab.
	for _, prompt in workspace.Map:GetDescendants() do
		if prompt:IsA("ProximityPrompt") and prompt:GetAttribute("OpenTab") then
			prompt.Triggered:Connect(function(player)
				Remotes.Ui:FireClient(player, { Open = prompt:GetAttribute("OpenTab") })
			end)
		end
	end
	task.spawn(function()
		while true do
			task.wait(0.4)
			autoPick()
		end
	end)
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
