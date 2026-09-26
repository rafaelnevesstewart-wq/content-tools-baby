-- Builds the static world: terrain for the four biomes, mountains ringing the
-- map, lakes, the town of Titan's Rest in the middle of the loop, an outpost in
-- each biome, and scenery. Everything stays out of the band the herd walks in,
-- so titans never bump into buildings.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local MapBuilder = {}

local rng = Random.new(20260926) -- fixed seed: every server gets the same map
local terrain = workspace.Terrain

MapBuilder.Biomes = {
	-- Quadrants in loop order, starting at angle 0.
	{ Name = "Fern Valley", Terrain = Enum.Material.Grass, Rock = Enum.Material.Rock, Leaf = Color3.fromRGB(60, 140, 60) },
	{ Name = "Salt Flats", Terrain = Enum.Material.Salt, Rock = Enum.Material.Sandstone, Leaf = Color3.fromRGB(90, 150, 80) },
	{ Name = "Aurora Tundra", Terrain = Enum.Material.Snow, Rock = Enum.Material.Rock, Leaf = Color3.fromRGB(40, 90, 70) },
	{ Name = "Ember Wastes", Terrain = Enum.Material.Basalt, Rock = Enum.Material.Basalt, Leaf = Color3.fromRGB(255, 90, 30) },
}

function MapBuilder.biomeIndexAt(angle: number): number
	local quadrant = math.floor((angle % (math.pi * 2)) / (math.pi / 2)) + 1
	return math.clamp(quadrant, 1, 4)
end

-- The ring the herd walks in, with a margin for the widest titan.
local laneHalf = math.ceil(Config.Herd.MaxLanes / 2) * Config.Herd.LaneSpacing
MapBuilder.BandInner = Config.Herd.PathRadius - laneHalf - 40
MapBuilder.BandOuter = Config.Herd.PathRadius + laneHalf + 40
MapBuilder.TravelPoints = {} -- filled in by build(): place name -> Vector3

local function part(className: string, props, parent: Instance)
	local p = Instance.new(className)
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		p[key] = value
	end
	p.Parent = parent
	return p
end

local function polar(angle: number, radius: number, y: number?): Vector3
	return Vector3.new(math.cos(angle) * radius, y or 0, math.sin(angle) * radius)
end

-- Faces the point's -Z side towards the map centre.
local function facingCenter(position: Vector3): CFrame
	return CFrame.lookAt(position, Vector3.new(0, position.Y, 0))
end

-- Buildings -------------------------------------------------------------------

local function house(cf: CFrame, size: Vector3, wallColor: Color3, roofColor: Color3, parent: Instance, wallMaterial: Enum.Material?)
	local model = Instance.new("Model")
	model.Name = "House"
	local w, h, d = size.X, size.Y, size.Z
	part(
		"Part",
		{ Name = "Walls", Size = size, CFrame = cf * CFrame.new(0, h / 2, 0), Color = wallColor, Material = wallMaterial or Enum.Material.WoodPlanks },
		model
	)
	-- Gable roof from two wedges.
	local roofHeight = w * 0.45
	for _, side in { -1, 1 } do
		part("WedgePart", {
			Name = "Roof",
			Size = Vector3.new(d + 2, roofHeight, w / 2 + 1),
			CFrame = cf * CFrame.new(side * (w / 4 + 0.5), h + roofHeight / 2, 0) * CFrame.Angles(0, -side * math.pi / 2, 0),
			Color = roofColor,
			Material = Enum.Material.Slate,
		}, model)
	end
	part("Part", {
		Name = "Door",
		Size = Vector3.new(4, 7, 0.4),
		CFrame = cf * CFrame.new(0, 3.5, -d / 2 - 0.1),
		Color = Color3.fromRGB(90, 60, 40),
		Material = Enum.Material.Wood,
	}, model)
	for _, side in { -1, 1 } do
		part("Part", {
			Name = "Window",
			Size = Vector3.new(3, 3, 0.3),
			CFrame = cf * CFrame.new(side * w * 0.3, h * 0.6, -d / 2 - 0.1),
			Color = Color3.fromRGB(255, 220, 140),
			Material = Enum.Material.Neon,
		}, model)
	end
	part("Part", {
		Name = "Chimney",
		Size = Vector3.new(2.5, roofHeight + 3, 2.5),
		CFrame = cf * CFrame.new(w * 0.25, h + (roofHeight + 3) / 2, d * 0.2),
		Color = Color3.fromRGB(120, 110, 105),
		Material = Enum.Material.Brick,
	}, model)
	model.Parent = parent
	return model
end

local function dome(position: Vector3, radius: number, color: Color3, material: Enum.Material, parent: Instance)
	local shell = part("Part", {
		Name = "Dome",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * radius * 2,
		Position = position,
		Color = color,
		Material = material,
	}, parent)
	-- Doorway facing the map centre.
	local toCenter = (Vector3.new(0, position.Y, 0) - position).Unit
	part("Part", {
		Name = "Doorway",
		Size = Vector3.new(4, 6, radius * 0.6),
		CFrame = CFrame.lookAt(position + toCenter * radius * 0.85 + Vector3.new(0, 3, 0), position + toCenter * radius * 2 + Vector3.new(0, 3, 0)),
		Color = Color3.fromRGB(40, 35, 35),
	}, parent)
	return shell
end

local function tower(cf: CFrame, height: number, parent: Instance)
	part("Part", {
		Name = "Tower",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, 14, 14),
		CFrame = cf * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(150, 145, 135),
		Material = Enum.Material.Cobblestone,
	}, parent)
	part("Part", {
		Name = "Lookout",
		Size = Vector3.new(20, 1.5, 20),
		CFrame = cf * CFrame.new(0, height + 0.75, 0),
		Color = Color3.fromRGB(120, 90, 60),
		Material = Enum.Material.WoodPlanks,
	}, parent)
	local beacon = part("Part", {
		Name = "Beacon",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 5,
		CFrame = cf * CFrame.new(0, height + 5, 0),
		Color = Color3.fromRGB(255, 200, 90),
		Material = Enum.Material.Neon,
	}, parent)
	local light = Instance.new("PointLight")
	light.Range = 60
	light.Brightness = 2
	light.Color = Color3.fromRGB(255, 200, 120)
	light.Parent = beacon
	-- Climbable side so players can go up for the view.
	part("TrussPart", {
		Name = "TowerLadder",
		Size = Vector3.new(2, math.floor(height / 2) * 2, 2),
		CFrame = cf * CFrame.new(0, math.floor(height / 2), -8),
		Color = Color3.fromRGB(120, 90, 60),
	}, parent)
end

local function stall(cf: CFrame, awningColor: Color3, parent: Instance)
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			part("Part", {
				Name = "Pole",
				Size = Vector3.new(0.6, 7, 0.6),
				CFrame = cf * CFrame.new(x * 4, 3.5, z * 3),
				Color = Color3.fromRGB(120, 90, 60),
				Material = Enum.Material.Wood,
			}, parent)
		end
	end
	part("Part", {
		Name = "Counter",
		Size = Vector3.new(8, 3, 2),
		CFrame = cf * CFrame.new(0, 1.5, -2),
		Color = Color3.fromRGB(150, 110, 70),
		Material = Enum.Material.WoodPlanks,
	}, parent)
	for i = -2, 1 do
		part("Part", {
			Name = "Awning",
			Size = Vector3.new(2.25, 0.4, 7.5),
			CFrame = cf * CFrame.new(i * 2.25 + 1.125, 7.2, 0) * CFrame.Angles(0.15, 0, 0),
			Color = i % 2 == 0 and awningColor or Color3.fromRGB(250, 245, 235),
			Material = Enum.Material.Fabric,
		}, parent)
	end
end

local function arch(cf: CFrame, parent: Instance, color: Color3)
	for _, x in { -1, 1 } do
		part(
			"Part",
			{ Name = "Pillar", Size = Vector3.new(5, 26, 5), CFrame = cf * CFrame.new(x * 10, 13, 0), Color = color, Material = Enum.Material.Cobblestone },
			parent
		)
	end
	part(
		"Part",
		{ Name = "Lintel", Size = Vector3.new(27, 5, 6), CFrame = cf * CFrame.new(0, 28, 0), Color = color, Material = Enum.Material.Cobblestone },
		parent
	)
end

-- Scenery -------------------------------------------------------------------

local function tree(position: Vector3, biomeIndex: number, parent: Instance)
	local biome = MapBuilder.Biomes[biomeIndex]
	local height = rng:NextNumber(14, 34)
	if biomeIndex == 2 then
		-- Cactus.
		part("Part", {
			Name = "Cactus",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(height * 0.6, 4, 4),
			CFrame = CFrame.new(position + Vector3.new(0, height * 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			Color = biome.Leaf,
			Material = Enum.Material.Grass,
		}, parent)
		for _, side in { -1, 1 } do
			part("Part", {
				Name = "CactusArm",
				Size = Vector3.new(2.5, 6, 2.5),
				Position = position + Vector3.new(side * 3.5, height * 0.35, 0),
				Color = biome.Leaf,
				Material = Enum.Material.Grass,
			}, parent)
		end
		return
	end
	part("Part", {
		Name = "Trunk",
		Size = Vector3.new(3, height, 3),
		Position = position + Vector3.new(0, height / 2, 0),
		Color = biomeIndex == 4 and Color3.fromRGB(40, 30, 30) or Color3.fromRGB(100, 70, 45),
		Material = Enum.Material.Wood,
	}, parent)
	if biomeIndex == 3 then
		-- Snowy pine: stacked tiers.
		for tier = 0, 2 do
			local r = (3 - tier) * 5
			part("Part", {
				Name = "Pine",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(r * 2, r * 1.1, r * 2),
				Position = position + Vector3.new(0, height * 0.45 + tier * 7, 0),
				Color = tier == 2 and Color3.fromRGB(240, 248, 255) or biome.Leaf,
				Material = tier == 2 and Enum.Material.Snow or Enum.Material.Grass,
			}, parent)
		end
	elseif biomeIndex == 4 then
		part("Part", {
			Name = "EmberCrown",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * rng:NextNumber(5, 9),
			Position = position + Vector3.new(0, height, 0),
			Color = biome.Leaf,
			Material = Enum.Material.Neon,
		}, parent)
	elseif rng:NextNumber() < 0.3 then
		-- Dead tree: bare, twisted branches.
		for _ = 1, 4 do
			local branchLength = rng:NextNumber(6, 12)
			local yaw = rng:NextNumber(0, math.pi * 2)
			part("Part", {
				Name = "Branch",
				Size = Vector3.new(1.2, branchLength, 1.2),
				CFrame = CFrame.new(position + Vector3.new(0, height * rng:NextNumber(0.6, 0.95), 0))
					* CFrame.Angles(0, yaw, rng:NextNumber(0.6, 1.1))
					* CFrame.new(0, branchLength / 2, 0),
				Color = Color3.fromRGB(70, 55, 45),
				Material = Enum.Material.Wood,
			}, parent)
		end
	else
		-- Leafy canopy made of several overlapping clumps.
		for _ = 1, 4 do
			local size = rng:NextNumber(10, 18)
			part("Part", {
				Name = "Canopy",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * size,
				Position = position + Vector3.new(rng:NextNumber(-5, 5), height + rng:NextNumber(-3, 4), rng:NextNumber(-5, 5)),
				Color = biome.Leaf:Lerp(Color3.fromRGB(30, 50, 25), rng:NextNumber(0.2, 0.6)),
				Material = Enum.Material.LeafyGrass,
			}, parent)
		end
	end
end

local function torch(position: Vector3, parent: Instance)
	part("Part", {
		Name = "TorchPost",
		Size = Vector3.new(0.8, 8, 0.8),
		Position = position + Vector3.new(0, 4, 0),
		Color = Color3.fromRGB(60, 45, 35),
		Material = Enum.Material.Wood,
	}, parent)
	local bowl = part("Part", {
		Name = "TorchBowl",
		Size = Vector3.new(2, 1, 2),
		Position = position + Vector3.new(0, 8.5, 0),
		Color = Color3.fromRGB(50, 50, 55),
		Material = Enum.Material.Metal,
	}, parent)
	local fire = Instance.new("Fire")
	fire.Size = 4
	fire.Heat = 8
	fire.Parent = bowl
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 60)
	light.Range = 30
	light.Brightness = 1.5
	light.Shadows = true
	light.Parent = bowl
end

-- A base building in town: walking up to it opens that shop tab.
local function baseBuilding(cf: CFrame, title: string, tab: string, color: Color3, parent: Instance)
	local model = house(cf, Vector3.new(24, 14, 16), Color3.fromRGB(90, 80, 70), color, parent, Enum.Material.Cobblestone)
	model.Name = title
	local sign = part("Part", {
		Name = "Sign",
		Size = Vector3.new(12, 3, 0.5),
		CFrame = cf * CFrame.new(0, 10.5, -8.4),
		Color = Color3.fromRGB(60, 40, 30),
		Material = Enum.Material.Wood,
	}, model)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Fantasy
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 220, 150)
	label.Text = title
	label.Parent = gui
	gui.Parent = sign
	local door = model:FindFirstChild("Door")
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Enter"
	prompt.ObjectText = title
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OpenTab", tab)
	prompt.Parent = door
	torch((cf * CFrame.new(-7, 0, -11)).Position, model)
	torch((cf * CFrame.new(7, 0, -11)).Position, model)
end

local function boulder(position: Vector3, biomeIndex: number, parent: Instance)
	local size = rng:NextNumber(6, 18)
	part("Part", {
		Name = "Boulder",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(size * 1.3, size, size),
		CFrame = CFrame.new(position + Vector3.new(0, size * 0.3, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0),
		Color = biomeIndex == 2 and Color3.fromRGB(210, 190, 150) or Color3.fromRGB(110, 110, 115),
		Material = biomeIndex == 2 and Enum.Material.Sandstone or Enum.Material.Rock,
	}, parent)
end

local function mountain(position: Vector3, radius: number, height: number, biomeIndex: number)
	local layers = 10
	local layerHeight = height / layers
	for i = 0, layers - 1 do
		local frac = i / layers
		local r = radius * (1 - frac) + 10
		local material = MapBuilder.Biomes[biomeIndex].Rock
		if (biomeIndex == 3 and frac > 0.3) or (biomeIndex == 1 and frac > 0.7) then
			material = Enum.Material.Snow
		elseif biomeIndex == 1 and frac < 0.2 then
			material = Enum.Material.Grass
		elseif biomeIndex == 4 and frac >= 0.8 then
			material = Enum.Material.CrackedLava
		end
		terrain:FillCylinder(CFrame.new(position.X, i * layerHeight + layerHeight / 2, position.Z), layerHeight + 4, r, material)
	end
end

-- Sections ------------------------------------------------------------------

local function buildTerrain()
	for index, biome in MapBuilder.Biomes do
		local mid = (index - 0.5) * math.pi / 2
		local sx = math.cos(mid) >= 0 and 1 or -1
		local sz = math.sin(mid) >= 0 and 1 or -1
		terrain:FillBlock(CFrame.new(sx * 1200, -4, sz * 1200), Vector3.new(2400, 8, 2400), biome.Terrain)
	end

	-- Mountains around the edge; the biggest peaks are landmarks.
	for i = 1, 26 do
		local a = (i + rng:NextNumber(-0.3, 0.3)) / 26 * math.pi * 2
		local r = rng:NextNumber(1650, 2050)
		local biomeIndex = MapBuilder.biomeIndexAt(a)
		local radius = rng:NextNumber(150, 240)
		local height = rng:NextNumber(160, 300)
		if i % 7 == 0 then
			height *= 1.6
			radius *= 1.3
		end
		mountain(polar(a, r), radius, height, biomeIndex)
	end
	-- Foothills just outside the herd's band.
	for _ = 1, 30 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(MapBuilder.BandOuter + 180, 1550)
		local biomeIndex = MapBuilder.biomeIndexAt(a)
		terrain:FillBall(polar(a, r, -30), rng:NextNumber(50, 90), MapBuilder.Biomes[biomeIndex].Terrain)
	end
	-- Patches of mud, rock, sand and ice so the ground isn't one flat colour.
	local patchMaterials = {
		{ Enum.Material.Mud, Enum.Material.LeafyGrass, Enum.Material.Ground },
		{ Enum.Material.Sand, Enum.Material.Sandstone, Enum.Material.Ground },
		{ Enum.Material.Glacier, Enum.Material.Ice, Enum.Material.Rock },
		{ Enum.Material.Ground, Enum.Material.Rock, Enum.Material.CrackedLava },
	}
	for _ = 1, 140 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(260, 1900)
		local options = patchMaterials[MapBuilder.biomeIndexAt(a)]
		terrain:FillCylinder(CFrame.new(polar(a, r, -1)), 2, rng:NextNumber(15, 60), options[rng:NextInteger(1, #options)])
	end

	-- Lakes in Fern Valley and a frozen one in the Tundra.
	terrain:FillCylinder(CFrame.new(polar(0.55, MapBuilder.BandOuter + 120, -3)), 6, 70, Enum.Material.Water)
	terrain:FillCylinder(CFrame.new(polar(1.1, MapBuilder.BandOuter + 140, -3)), 6, 50, Enum.Material.Water)
	terrain:FillCylinder(CFrame.new(polar(3.9, MapBuilder.BandOuter + 130, -3)), 6, 80, Enum.Material.Glacier)
	-- Lava pools in the Ember Wastes.
	for i = 1, 3 do
		terrain:FillCylinder(CFrame.new(polar(4.9 + i * 0.25, MapBuilder.BandOuter + 100 + i * 30, -2)), 5, 30, Enum.Material.CrackedLava)
	end
end

local function buildTrail(parent: Instance)
	local segments = 72
	local r = Config.Herd.PathRadius
	for i = 1, segments do
		local a = (i - 0.5) / segments * math.pi * 2
		local position = polar(a, r, 0.1)
		local tangent = Vector3.new(-math.sin(a), 0, math.cos(a))
		part("Part", {
			Name = "Trail",
			Size = Vector3.new(90, 0.2, 2 * math.pi * r / segments + 2),
			CFrame = CFrame.lookAt(position, position + tangent),
			Color = Color3.fromRGB(150, 115, 80),
			Material = Enum.Material.Ground,
			CanCollide = false,
		}, parent)
	end
end

local function buildTown(parent: Instance)
	local town = Instance.new("Model")
	town.Name = "Titan's Rest"

	-- Plaza and fountain.
	part("Part", {
		Name = "Plaza",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 130, 130),
		CFrame = CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(190, 180, 165),
		Material = Enum.Material.Cobblestone,
	}, town)
	part("Part", {
		Name = "FountainBasin",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(3, 30, 30),
		CFrame = CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(170, 170, 175),
		Material = Enum.Material.Marble,
	}, town)
	part("Part", {
		Name = "FountainWater",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 27, 27),
		CFrame = CFrame.new(0, 2.9, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(90, 170, 230),
		Material = Enum.Material.Glass,
		Transparency = 0.3,
		CanCollide = false,
	}, town)
	-- A statue of the first titan on the fountain.
	local statueColor = Color3.fromRGB(200, 200, 205)
	local statue = {
		{ Vector3.new(0, 7, 0), Vector3.new(8, 5, 11) },
		{ Vector3.new(0, 9.5, 0), Vector3.new(8.5, 5, 10) },
		{ Vector3.new(0, 7.5, -7), Vector3.new(4, 3.5, 4) },
	}
	for _, blob in statue do
		local p = part("Part", { Name = "Statue", Size = blob[2], Position = blob[1], Color = statueColor, Material = Enum.Material.Marble }, town)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	part(
		"Part",
		{ Name = "StatuePlinth", Size = Vector3.new(6, 4, 6), Position = Vector3.new(0, 4.5, 0), Color = statueColor, Material = Enum.Material.Marble },
		town
	)

	-- Houses in a ring facing the plaza.
	local wallColors = { Color3.fromRGB(120, 105, 90), Color3.fromRGB(100, 80, 65), Color3.fromRGB(95, 95, 95), Color3.fromRGB(110, 90, 80) }
	local roofColors = { Color3.fromRGB(70, 40, 35), Color3.fromRGB(45, 50, 60), Color3.fromRGB(55, 60, 45), Color3.fromRGB(60, 45, 40) }
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2 + 0.2
		local position = polar(a, rng:NextNumber(150, 190))
		local size = Vector3.new(rng:NextNumber(18, 26), rng:NextNumber(12, 18), rng:NextNumber(16, 22))
		house(facingCenter(position), size, wallColors[i % 4 + 1], roofColors[(i + 1) % 4 + 1], town)
	end
	-- Market stalls around the plaza.
	local awnings = { Color3.fromRGB(220, 70, 70), Color3.fromRGB(70, 150, 220), Color3.fromRGB(90, 180, 90), Color3.fromRGB(240, 180, 40) }
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		stall(facingCenter(polar(a, 85)), awnings[i % 4 + 1], town)
	end
	tower(CFrame.new(polar(math.pi * 1.25, 115)), 70, town)

	-- The base: an armory, a spell shrine and a forge for upgrades.
	baseBuilding(facingCenter(polar(0.45, 118)), "Armory", "Weapons", Color3.fromRGB(110, 40, 35), town)
	baseBuilding(facingCenter(polar(2.55, 118)), "Spell Shrine", "Spells", Color3.fromRGB(60, 50, 110), town)
	baseBuilding(facingCenter(polar(4.95, 118)), "Forge", "Upgrades", Color3.fromRGB(90, 60, 30), town)
	MapBuilder.TravelPoints.Base = polar(0, 55, 2)
	for i = 0, 7 do
		torch(polar(i / 8 * math.pi * 2 + 0.2, 68), town)
	end

	-- Welcome arches where the town meets the trail.
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + math.pi / 4
		arch(facingCenter(polar(a, 225)), town, Color3.fromRGB(170, 160, 150))
	end
	town.Parent = parent
end

local function buildOutposts(parent: Instance)
	local r = MapBuilder.BandOuter + 70
	for index = 1, 4 do
		local folder = Instance.new("Model")
		folder.Name = MapBuilder.Biomes[index].Name .. " Outpost"
		local mid = (index - 0.5) * math.pi / 2
		MapBuilder.TravelPoints[MapBuilder.Biomes[index].Name] = polar(mid - 0.12, r, 2)
		if index == 1 then
			-- Wooden cabins and a windmill.
			for i = -1, 1 do
				house(
					facingCenter(polar(mid + i * 0.06, r + math.abs(i) * 30)),
					Vector3.new(20, 13, 18),
					Color3.fromRGB(160, 110, 70),
					Color3.fromRGB(90, 60, 40),
					folder
				)
			end
			local millCF = facingCenter(polar(mid + 0.16, r + 30))
			part("Part", {
				Name = "Windmill",
				Size = Vector3.new(12, 40, 12),
				CFrame = millCF * CFrame.new(0, 20, 0),
				Color = Color3.fromRGB(230, 225, 210),
				Material = Enum.Material.Brick,
			}, folder)
			for blade = 0, 3 do
				part("Part", {
					Name = "Blade",
					Size = Vector3.new(3, 22, 0.6),
					CFrame = millCF * CFrame.new(0, 34, -6.5) * CFrame.Angles(0, 0, blade * math.pi / 2 + 0.3) * CFrame.new(0, 11, 0),
					Color = Color3.fromRGB(240, 240, 240),
					Material = Enum.Material.Fabric,
				}, folder)
			end
		elseif index == 2 then
			-- Adobe domes and the bones of an ancient titan.
			for i = -1, 1 do
				dome(polar(mid + i * 0.07, r + 20, 0), 12, Color3.fromRGB(240, 230, 210), Enum.Material.Sand, folder)
			end
			local skeleton = facingCenter(polar(mid + 0.2, r + 60))
			for rib = -3, 3 do
				for _, side in { -1, 1 } do
					part("Part", {
						Name = "Rib",
						Size = Vector3.new(3, 46, 3),
						CFrame = skeleton * CFrame.new(side * 14, 18, rib * 10) * CFrame.Angles(0, 0, side * 0.45),
						Color = Color3.fromRGB(245, 240, 225),
						Material = Enum.Material.Marble,
					}, folder)
				end
			end
			part("Part", {
				Name = "Spine",
				Size = Vector3.new(4, 4, 80),
				CFrame = skeleton * CFrame.new(0, 38, 0),
				Color = Color3.fromRGB(245, 240, 225),
				Material = Enum.Material.Marble,
			}, folder)
			local skull = part("Part", {
				Name = "Skull",
				Size = Vector3.new(24, 18, 26),
				CFrame = skeleton * CFrame.new(0, 12, -52),
				Color = Color3.fromRGB(245, 240, 225),
				Material = Enum.Material.Marble,
			}, folder)
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = skull
		elseif index == 3 then
			-- Igloos and ice spires.
			for i = -1, 1 do
				dome(polar(mid + i * 0.07, r + 20, 0), 11, Color3.fromRGB(220, 240, 255), Enum.Material.Ice, folder)
			end
			for _ = 1, 6 do
				local position = polar(mid + rng:NextNumber(-0.2, 0.2), r + rng:NextNumber(40, 120))
				local height = rng:NextNumber(25, 60)
				part("Part", {
					Name = "IceSpire",
					Size = Vector3.new(6, height, 6),
					CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0))
						* CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, 3), rng:NextNumber(-0.2, 0.2)),
					Color = Color3.fromRGB(170, 220, 255),
					Material = Enum.Material.Glass,
					Transparency = 0.2,
				}, folder)
			end
		else
			-- Forges with glowing furnaces and obsidian pillars.
			for i = -1, 1 do
				local cf = facingCenter(polar(mid + i * 0.06, r + math.abs(i) * 25))
				house(cf, Vector3.new(22, 12, 18), Color3.fromRGB(60, 55, 55), Color3.fromRGB(40, 30, 30), folder, Enum.Material.Basalt)
				local furnace = part("Part", {
					Name = "Furnace",
					Size = Vector3.new(6, 5, 6),
					CFrame = cf * CFrame.new(0, 2.5, -14),
					Color = Color3.fromRGB(255, 100, 20),
					Material = Enum.Material.Neon,
				}, folder)
				local fire = Instance.new("Fire")
				fire.Heat = 12
				fire.Size = 8
				fire.Parent = furnace
			end
			for _ = 1, 8 do
				local position = polar(mid + rng:NextNumber(-0.25, 0.25), r + rng:NextNumber(50, 140))
				local height = rng:NextNumber(20, 50)
				part("Part", {
					Name = "ObsidianPillar",
					Size = Vector3.new(7, height, 7),
					CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0),
					Color = Color3.fromRGB(25, 20, 30),
					Material = Enum.Material.Glass,
				}, folder)
			end
		end
		folder.Parent = parent
	end

	-- Ancient arches along the outside of the trail.
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2 + 0.4
		arch(facingCenter(polar(a, MapBuilder.BandOuter + 30)), parent, Color3.fromRGB(150, 145, 135))
	end
end

local function buildScenery(parent: Instance)
	for _ = 1, 140 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(MapBuilder.BandOuter + 40, 1600)
		local biomeIndex = MapBuilder.biomeIndexAt(a)
		if rng:NextNumber() < 0.75 then
			tree(polar(a, r), biomeIndex, parent)
		else
			boulder(polar(a, r), biomeIndex, parent)
		end
	end
	-- A ring of trees between the town and the trail.
	for _ = 1, 30 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(240, math.max(250, MapBuilder.BandInner - 10))
		tree(polar(a, r), MapBuilder.biomeIndexAt(a), parent)
	end
end

function MapBuilder.build()
	local map = Instance.new("Folder")
	map.Name = "Map"
	buildTerrain()
	buildTrail(map)
	buildTown(map)
	buildOutposts(map)
	buildScenery(map)

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = Vector3.new(Config.Herd.PathRadius, 0.5, 0)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Duration = 0
	spawn.Parent = map

	map.Parent = workspace
end

return MapBuilder
