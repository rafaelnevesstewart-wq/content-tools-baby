-- Builds the sky world from code: the castle lobby on its own island, the
-- big middle island (the Crystal and Core generators during matches), 8 team
-- islands around it, bridges and clouds. Replace with
-- hand-built terrain later; MatchService only needs the island CFrames.

local Lighting = game:GetService("Lighting")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local WorldBuilder = {}

local GRASS = Color3.fromRGB(88, 124, 62)
local DIRT = Color3.fromRGB(104, 82, 62)
local ROCK = Color3.fromRGB(102, 98, 94)
local WOOD = Color3.fromRGB(120, 88, 60)
local CLOUD = Color3.fromRGB(244, 246, 250)

-- Natural colors for leaves, flowers and mushrooms.
local LEAVES = {
	Color3.fromRGB(66, 104, 48),
	Color3.fromRGB(80, 118, 54),
	Color3.fromRGB(58, 92, 44),
	Color3.fromRGB(96, 126, 58),
	Color3.fromRGB(122, 132, 60), -- a touch of autumn
}
local PASTELS = {
	Color3.fromRGB(214, 62, 72), -- poppy red
	Color3.fromRGB(238, 196, 66), -- buttercup yellow
	Color3.fromRGB(244, 244, 238), -- daisy white
	Color3.fromRGB(150, 104, 196), -- lavender
	Color3.fromRGB(232, 128, 58), -- marigold
	Color3.fromRGB(226, 120, 160), -- wild rose
}

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		if key ~= "Parent" then
			(p :: any)[key] = value
		end
	end
	p.Parent = props.Parent
	return p
end

-- A floating island made of real Roblox terrain: a grass top whose surface
-- sits at `center.Y`, a dirt layer with a ragged edge, and a rugged rock
-- underside that tapers to a point. The returned Model holds the island's
-- decorations (the terrain itself lives in workspace.Terrain).
local function floatingIsland(parent: Instance, name: string, center: Vector3, radius: number, rng: Random): Model
	local terrain = workspace.Terrain
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("Radius", radius)
	-- Dirt edge first, then grass over it, so the rim shows a little earth.
	terrain:FillCylinder(CFrame.new(center - Vector3.new(0, 3, 0)), 6, radius + 1.5, Enum.Material.Ground)
	terrain:FillCylinder(CFrame.new(center - Vector3.new(0, 2, 0)), 4, radius, Enum.Material.Grass)
	terrain:FillCylinder(CFrame.new(center - Vector3.new(0, 8, 0)), 8, radius * 0.97, Enum.Material.Ground)
	-- The underside: overlapping rock blobs, smaller and deeper toward a point.
	local layers = 6
	for layer = 1, layers do
		local share = 1 - layer / (layers + 1)
		local ring = radius * share
		local depth = 10 + layer * radius * 0.11
		local count = math.max(3, math.ceil(ring / 7))
		for _ = 1, count do
			local angle = rng:NextNumber(0, math.pi * 2)
			local distance = rng:NextNumber(0, ring * 0.75)
			local size = ring * rng:NextNumber(0.28, 0.45) + 4
			terrain:FillBall(
				center
					+ Vector3.new(
						math.cos(angle) * distance,
						-depth - rng:NextNumber(-3, 3),
						math.sin(angle) * distance
					),
				size,
				if rng:NextNumber() < 0.25 then Enum.Material.Slate else Enum.Material.Rock
			)
		end
	end
	terrain:FillBall(
		center - Vector3.new(0, 10 + (layers + 1) * radius * 0.11, 0),
		radius * 0.08 + 3,
		Enum.Material.Rock
	)
	model.Parent = parent
	return model
end

-- Mossy boulders half sunk into an island, away from the busy spots.
local function boulders(frame: CFrame, radius: number, count: number, rng: Random, blocked: (Vector3) -> boolean)
	local placed, tries = 0, 0
	while placed < count and tries < count * 20 do
		tries += 1
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(radius * 0.45, radius - 4)
		local spot = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		if not blocked(spot) then
			placed += 1
			local size = rng:NextNumber(2.5, 5)
			workspace.Terrain:FillBall(
				frame:PointToWorldSpace(spot - Vector3.new(0, size * 0.35, 0)),
				size,
				if rng:NextNumber() < 0.3 then Enum.Material.Slate else Enum.Material.Rock
			)
		end
	end
end

-- A rope-and-plank bridge: a planked deck on two support beams, posts every
-- few studs and sagging rope rails.
local function bridge(parent: Instance, from: Vector3, to: Vector3)
	local model = Instance.new("Model")
	model.Name = "Bridge"
	local flatTo = Vector3.new(to.X, from.Y, to.Z)
	local length = (flatTo - from).Magnitude
	local frame = CFrame.lookAt((from + flatTo) / 2, flatTo)
	part({
		Name = "Deck",
		Size = Vector3.new(12, 1, length),
		CFrame = frame * CFrame.new(0, -0.5, 0),
		Color = Color3.fromRGB(128, 96, 66),
		Material = Enum.Material.WoodPlanks,
		Parent = model,
	})
	for _, side in { -1, 1 } do
		part({
			Name = "Beam",
			Size = Vector3.new(1.2, 1.4, length),
			CFrame = frame * CFrame.new(side * 5, -1.6, 0),
			Color = Color3.fromRGB(86, 62, 44),
			Material = Enum.Material.Wood,
			Parent = model,
		})
		local posts = math.floor(length / 12)
		local previous: Vector3? = nil
		for i = 0, posts do
			local z = -length / 2 + i * length / posts
			local post = part({
				Name = "Post",
				Size = Vector3.new(0.7, 4, 0.7),
				CFrame = frame * CFrame.new(side * 5.8, 1.5, z),
				Color = Color3.fromRGB(96, 70, 48),
				Material = Enum.Material.Wood,
				Parent = model,
			})
			local top = post.Position + Vector3.new(0, 1.6, 0)
			if previous then
				-- The rope sags a little between posts.
				local mid = (previous + top) / 2 - Vector3.new(0, 0.5, 0)
				for _, pair in { { previous, mid }, { mid, top } } do
					local a, b = pair[1], pair[2]
					part({
						Name = "Rope",
						Shape = Enum.PartType.Cylinder,
						Size = Vector3.new((b - a).Magnitude, 0.25, 0.25),
						CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0),
						Color = Color3.fromRGB(176, 150, 110),
						Material = Enum.Material.Fabric,
						CanCollide = false,
						Parent = model,
					})
				end
			end
			previous = top
		end
		-- An invisible rail so nobody slips off the side by accident.
		part({
			Name = "Rail",
			Size = Vector3.new(0.4, 3.5, length),
			CFrame = frame * CFrame.new(side * 5.8, 1.75, 0),
			Transparency = 1,
			Parent = model,
		})
	end
	model.Parent = parent
end

-- A soft, wispy cloud made of slow smoke puffs (no solid parts).
local function cloudCluster(parent: Instance, center: Vector3, size: number, rng: Random)
	local holder = part({
		Name = "Cloud",
		Size = Vector3.new(size * 2, size * 0.5, size * 1.2),
		CFrame = CFrame.new(center) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
		Transparency = 1,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		CastShadow = false,
		Parent = parent,
	})
	local puffs = Instance.new("ParticleEmitter")
	puffs.Texture = "rbxasset://textures/particles/smoke_main.dds"
	puffs.Color = ColorSequence.new(CLOUD, Color3.fromRGB(214, 220, 230))
	puffs.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size * 0.5),
		NumberSequenceKeypoint.new(0.5, size * 0.9),
		NumberSequenceKeypoint.new(1, size * 1),
	})
	puffs.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.35),
		NumberSequenceKeypoint.new(0.8, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	puffs.Lifetime = NumberRange.new(10, 14)
	puffs.Rate = 1
	puffs.Speed = NumberRange.new(0.2, 0.6)
	puffs.SpreadAngle = Vector2.new(180, 180)
	puffs.Rotation = NumberRange.new(0, 360)
	puffs.RotSpeed = NumberRange.new(-4, 4)
	puffs.LockedToPart = true
	puffs.LightInfluence = 1
	puffs.Parent = holder
	-- Start with a full cloud instead of waiting for it to fill in.
	puffs:Emit(10)
end

local function label(
	parent: Instance,
	name: string,
	text: string,
	size: UDim2,
	position: UDim2,
	textSize: number,
	color: Color3
): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = position
	l.Font = Enum.Font.GothamBold
	l.TextScaled = true
	l.TextColor3 = color
	l.Text = text
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = textSize
	constraint.Parent = l
	l.Parent = parent
	return l
end

-- A TV on a pole. The client fills in the text; see ForecastController.
local function forecastTV(parent: Instance, position: Vector3, facing: Vector3)
	local model = Instance.new("Model")
	model.Name = "ForecastTV"
	local frame = CFrame.lookAt(position, facing)
	part({
		Name = "Pole",
		Size = Vector3.new(1.5, 12, 1.5),
		CFrame = frame * CFrame.new(0, 6, 0),
		Color = Color3.fromRGB(80, 80, 95),
		Material = Enum.Material.Metal,
		Parent = model,
	})
	local screen = part({
		Name = "Screen",
		Size = Vector3.new(22, 12, 1),
		CFrame = frame * CFrame.new(0, 17, 0),
		Color = Color3.fromRGB(30, 35, 60),
		Material = Enum.Material.SmoothPlastic,
		Parent = model,
	})
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Display" .. face.Name
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.LightInfluence = 0
		gui.Brightness = 1.5
		gui.Parent = screen

		local bg = Instance.new("Frame")
		bg.Name = "Background"
		bg.Size = UDim2.fromScale(1, 1)
		bg.BackgroundColor3 = Color3.fromRGB(25, 30, 60)
		bg.Parent = gui
		local gradient = Instance.new("UIGradient")
		gradient.Color = ColorSequence.new(Color3.fromRGB(60, 90, 170), Color3.fromRGB(25, 30, 70))
		gradient.Rotation = 90
		gradient.Parent = bg

		label(
			bg,
			"Title",
			"📺 WEATHER FORECAST",
			UDim2.fromScale(0.9, 0.2),
			UDim2.fromScale(0.05, 0.05),
			70,
			Color3.fromRGB(255, 230, 120)
		)
		label(
			bg,
			"Headline",
			"Clear skies",
			UDim2.fromScale(0.9, 0.3),
			UDim2.fromScale(0.05, 0.3),
			110,
			Color3.new(1, 1, 1)
		)
		label(
			bg,
			"Detail",
			"",
			UDim2.fromScale(0.9, 0.3),
			UDim2.fromScale(0.05, 0.63),
			55,
			Color3.fromRGB(200, 220, 255)
		)
	end
	model.PrimaryPart = screen
	model.Parent = parent
end

-- Realistic sky: soft sunlight and shadows, haze, bloom, sun rays, gentle
-- color grading and real 3D clouds. (Lighting.Technology is set to Future in
-- default.project.json, since scripts can't change it.)
local function setupLighting()
	Lighting.ClockTime = 14
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(80, 86, 98)
	Lighting.OutdoorAmbient = Color3.fromRGB(128, 134, 146)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.ShadowSoftness = 0.25
	Lighting.GlobalShadows = true
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.25
	atmosphere.Color = Color3.fromRGB(199, 206, 216)
	atmosphere.Decay = Color3.fromRGB(106, 118, 138)
	atmosphere.Glare = 0.35
	atmosphere.Haze = 1.6
	atmosphere.Parent = Lighting

	local function effect(className: string, props: { [string]: any })
		local existing = Lighting:FindFirstChildOfClass(className)
		local instance = existing or Instance.new(className)
		for key, value in props do
			(instance :: any)[key] = value
		end
		instance.Parent = Lighting
	end
	effect("BloomEffect", { Intensity = 0.5, Size = 24, Threshold = 1.4 })
	effect("SunRaysEffect", { Intensity = 0.07, Spread = 0.7 })
	effect("ColorCorrectionEffect", { Saturation = -0.06, Contrast = 0.08, Brightness = 0.01 })

	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.6
	clouds.Color = Color3.fromRGB(245, 247, 250)
	clouds.Parent = workspace.Terrain
end

-- A glowing pad that teleports you (handled by ClimateService).
local function pastel(rng: Random): Color3
	return PASTELS[rng:NextInteger(1, #PASTELS)]
end

local function squashedBall(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3)
	local p = part({
		Name = name,
		Size = size,
		CFrame = cframe,
		Color = color,
		Material = if name == "Bush" then Enum.Material.LeafyGrass else Enum.Material.SmoothPlastic,
		CanCollide = false,
		CanQuery = false,
		Parent = parent,
	})
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- A tree with a tapering trunk, a few branches and clumps of leaves in
-- slightly different greens.
local function tree(parent: Instance, ground: Vector3, rng: Random)
	local height = rng:NextNumber(8, 12)
	local bark = WOOD:Lerp(Color3.fromRGB(70, 52, 38), rng:NextNumber(0.2, 0.7))
	local lean =
		CFrame.Angles(math.rad(rng:NextNumber(-4, 4)), rng:NextNumber(0, math.pi * 2), math.rad(rng:NextNumber(-4, 4)))
	local base = CFrame.new(ground) * lean
	part({
		Name = "TreeTrunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height * 0.6, 2, 2),
		CFrame = base * CFrame.new(0, height * 0.3, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = bark,
		Material = Enum.Material.Wood,
		Parent = parent,
	})
	part({
		Name = "TreeTrunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height * 0.5, 1.4, 1.4),
		CFrame = base * CFrame.new(0, height * 0.75, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = bark,
		Material = Enum.Material.Wood,
		Parent = parent,
	})
	-- Roots flaring out at the bottom.
	for i = 1, 3 do
		part({
			Name = "TreeRoot",
			Size = Vector3.new(0.8, 0.8, 2.4),
			CFrame = base * CFrame.Angles(0, i * 2.1, 0) * CFrame.new(0, 0.2, 1.2) * CFrame.Angles(math.rad(25), 0, 0),
			Color = bark,
			Material = Enum.Material.Wood,
			Parent = parent,
		})
	end
	local color = LEAVES[rng:NextInteger(1, #LEAVES)]
	local crown = base * CFrame.new(0, height, 0)
	for i = 1, rng:NextInteger(5, 7) do
		local angle = i * 2.4
		local spread = if i == 1 then 0 else rng:NextNumber(2, 3.5)
		local size = rng:NextNumber(4.5, 7)
		local offset = Vector3.new(math.cos(angle) * spread, rng:NextNumber(-1.5, 2), math.sin(angle) * spread)
		if i > 1 then
			-- A branch reaching out to this clump.
			local from = (base * CFrame.new(0, height * 0.7, 0)).Position
			local to = (crown * CFrame.new(offset * 0.8)).Position
			part({
				Name = "TreeBranch",
				Size = Vector3.new(0.5, 0.5, (to - from).Magnitude),
				CFrame = CFrame.lookAt((from + to) / 2, to),
				Color = bark,
				Material = Enum.Material.Wood,
				CanCollide = false,
				Parent = parent,
			})
		end
		part({
			Name = "TreeTop",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(size, size * 0.8, size),
			CFrame = crown * CFrame.new(offset),
			Color = color:Lerp(Color3.fromRGB(40, 60, 30), rng:NextNumber(0, 0.35)),
			Material = Enum.Material.LeafyGrass,
			CanCollide = false,
			CanQuery = false,
			Parent = parent,
		})
	end
end

local function flowerPatch(parent: Instance, ground: Vector3, rng: Random)
	local color = pastel(rng)
	for _ = 1, rng:NextInteger(4, 7) do
		local spot = ground + Vector3.new(rng:NextNumber(-2.5, 2.5), 0, rng:NextNumber(-2.5, 2.5))
		local height = rng:NextNumber(0.8, 1.6)
		part({
			Name = "Stem",
			Size = Vector3.new(0.2, height, 0.2),
			CFrame = CFrame.new(spot + Vector3.new(0, height / 2, 0)),
			Color = Color3.fromRGB(70, 110, 50),
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
			Parent = parent,
		})
		part({
			Name = "Petals",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.7, 0.7, 0.7),
			CFrame = CFrame.new(spot + Vector3.new(0, height + 0.3, 0)),
			Color = color,
			Material = Enum.Material.Fabric,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
			Parent = parent,
		})
		part({
			Name = "FlowerMiddle",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.4, 0.4, 0.4),
			CFrame = CFrame.new(spot + Vector3.new(0, height + 0.35, -0.35)),
			Color = Color3.fromRGB(224, 176, 52),
			Material = Enum.Material.Sand,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
			Parent = parent,
		})
	end
end

local function mushroom(parent: Instance, ground: Vector3, rng: Random)
	local size = rng:NextNumber(0.8, 1.4)
	part({
		Name = "MushroomStem",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2 * size, 1.2 * size, 1.2 * size),
		CFrame = CFrame.new(ground + Vector3.new(0, size, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(226, 216, 196),
		Material = Enum.Material.Sand,
		CanCollide = false,
		CanQuery = false,
		Parent = parent,
	})
	local capColor = if rng:NextNumber() < 0.4 then Color3.fromRGB(176, 48, 40) else Color3.fromRGB(150, 110, 78)
	squashedBall(
		parent,
		"MushroomCap",
		Vector3.new(4, 2.2, 4) * size,
		CFrame.new(ground + Vector3.new(0, 2.3 * size, 0)),
		capColor
	)
end

local function bush(parent: Instance, ground: Vector3, rng: Random)
	for _ = 1, 3 do
		local size = rng:NextNumber(2.2, 3.4)
		squashedBall(
			parent,
			"Bush",
			Vector3.new(size, size * 0.8, size),
			CFrame.new(ground + Vector3.new(rng:NextNumber(-1.5, 1.5), size * 0.3, rng:NextNumber(-1.5, 1.5))),
			LEAVES[rng:NextInteger(1, #LEAVES)]:Lerp(Color3.fromRGB(40, 60, 30), rng:NextNumber(0, 0.2))
		)
	end
end

-- Scatters decorations over an island, skipping spots `blocked` rejects.
-- `frame` is the island's top center; points are in its local space.
local function scatter(
	parent: Instance,
	frame: CFrame,
	rng: Random,
	counts: { trees: number, flowers: number, mushrooms: number, bushes: number },
	ring: { treeMin: number, treeMax: number, max: number },
	blocked: (Vector3) -> boolean
)
	local folder = Instance.new("Folder")
	folder.Name = "Decor"
	folder.Parent = parent
	local function place(count: number, minR: number, maxR: number, make: (Instance, Vector3, Random) -> ())
		local placed, tries = 0, 0
		while placed < count and tries < count * 30 do
			tries += 1
			local angle = rng:NextNumber(0, math.pi * 2)
			local r = math.sqrt(rng:NextNumber(minR * minR, maxR * maxR))
			local localPoint = Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
			if not blocked(localPoint) then
				make(folder, frame:PointToWorldSpace(localPoint), rng)
				placed += 1
			end
		end
	end
	place(counts.trees, ring.treeMin, ring.treeMax, tree)
	place(counts.bushes, ring.treeMin - 6, ring.max, bush)
	place(counts.mushrooms, 8, ring.max, mushroom)
	place(counts.flowers, 6, ring.max, flowerPatch)
end

-- Keeps trees off the team base: spawn, generator, bed, shop and bridge.
local function plotBlocked(p: Vector3): boolean
	if math.abs(p.X) < 14 and p.Z > -32 and p.Z < 34 then
		return true -- spawn, generator and the cloud bed
	end
	if (p - Vector3.new(-14, 0, -12)).Magnitude < 9 then
		return true -- the Item Shop
	end
	return math.abs(p.X) < 12 and p.Z < -36 -- the bridge
end

local function decoratePlot(island: Model, frame: CFrame, rng: Random)
	scatter(
		island,
		frame,
		rng,
		{ trees = 6, flowers = 8, mushrooms = 4, bushes = 4 },
		{ treeMin = 45, treeMax = Config.World.PlotRadius - 5, max = Config.World.PlotRadius - 3 },
		plotBlocked
	)
end

-- Keeps map props off the middle generators' rings and the bridge ends.
local function wildBlocked(p: Vector3): boolean
	for _, radius in { Config.Match.Crystals.radius, Config.Match.Cores.radius } do
		if math.abs(p.Magnitude - radius) < 6 then
			return true -- the middle generators' rings
		end
	end
	local angle = math.atan2(p.Z, p.X)
	for index = 1, Config.MaxPlots do
		local bridgeAngle = (index - 1) / Config.MaxPlots * math.pi * 2
		local diff = math.abs((angle - bridgeAngle + math.pi) % (math.pi * 2) - math.pi)
		if diff < math.rad(9) and p.Magnitude > 70 then
			return true
		end
	end
	return false
end

---------------------------------------------------------------------------
-- The lobby: a stone castle on its own island, far from the match islands.
-- You spawn inside the gate; the courtyard has the fountain, the forecast TV,
-- the leaderboards and winners' statues, a duel arena and training dummies.
-- The parkour climbs around the outside of the island.

local LOBBY = Config.Lobby.Center
local STONE = Color3.fromRGB(150, 146, 138)
local DARK_STONE = Color3.fromRGB(108, 104, 98)
local ROOF = Color3.fromRGB(124, 48, 42)
local IRON = Color3.fromRGB(60, 60, 64)
local BANNERS = {
	Color3.fromRGB(176, 36, 40),
	Color3.fromRGB(40, 84, 176),
	Color3.fromRGB(52, 132, 64),
	Color3.fromRGB(214, 170, 48),
}

local function lobbyPoint(x: number, y: number, z: number): Vector3
	return LOBBY + Vector3.new(x, y, z)
end

-- Where things stand in the castle. Everything faces the spawn by the gate
-- (+Z), so it's the first thing you see.
WorldBuilder.LobbySpots = {
	spawn = CFrame.new(lobbyPoint(0, 0.5, 26)),
	tv = lobbyPoint(0, 0, -26),
	boards = { lobbyPoint(-33, 0, -35), lobbyPoint(-18, 0, -37), lobbyPoint(18, 0, -37), lobbyPoint(33, 0, -35) },
	statues = { lobbyPoint(0, 0, -13), lobbyPoint(-9, 0, -11), lobbyPoint(9, 0, -11) },
	likeSign = CFrame.lookAt(lobbyPoint(-26, 5, 36), lobbyPoint(0, 5, 14)),
	news = CFrame.lookAt(lobbyPoint(26, 0, 36), lobbyPoint(0, 0, 14)),
	arena = lobbyPoint(28, 0, 10),
	arenaRadius = 10,
	dummies = { lobbyPoint(-33, 0, -8), lobbyPoint(-33, 0, 0), lobbyPoint(-33, 0, 8), lobbyPoint(-33, 0, 16) },
	chest = CFrame.lookAt(lobbyPoint(-20, 0, -22), lobbyPoint(0, 0, 0)),
	bracket = CFrame.lookAt(lobbyPoint(28, 0, -8), lobbyPoint(28, 0, 10)),
}

-- Keeps trees and holiday decor out of the castle, off the path from the
-- gate and away from the first parkour steps. `p` is relative to the lobby
-- island's center.
local function lobbyBlocked(p: Vector3): boolean
	local half = Config.Lobby.CastleHalf + 9
	if math.abs(p.X) < half and math.abs(p.Z) < half then
		return true
	end
	if math.abs(p.X) < 9 then
		return true -- the paths out of the gates
	end
	if math.abs(p.Z) < 9 and math.abs(p.X) > 40 then
		return true -- the paths to Games Island and Base Island
	end
	local degrees = math.deg(math.atan2(p.Z, p.X)) % 360
	return degrees > Config.Obby.StartAngle - 12 and degrees < Config.Obby.StartAngle + 30 and p.Magnitude > 60
end

WorldBuilder.isLobbyBlocked = lobbyBlocked

local function castle(parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Castle"
	local half = Config.Lobby.CastleHalf
	local height = 16
	local thick = 4
	local gate = 7
	local base = CFrame.new(LOBBY)
	local function block(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
		return part({
			Name = name,
			Size = size,
			CFrame = cframe,
			Color = color,
			Material = material or Enum.Material.Cobblestone,
			Parent = model,
		})
	end
	local function cylinder(
		name: string,
		length: number,
		width: number,
		cframe: CFrame,
		color: Color3,
		material: Enum.Material?
	)
		local p =
			block(name, Vector3.new(length, width, width), cframe * CFrame.Angles(0, 0, math.rad(90)), color, material)
		p.Shape = Enum.PartType.Cylinder
		return p
	end

	-- Walls: the main gate is in the +Z wall (side 0), facing the path out;
	-- the back gate (side 2, -Z) leads to the bridge to the shop street.
	for side = 0, 3 do
		local wall = base * CFrame.Angles(0, side * math.pi / 2, 0) * CFrame.new(0, 0, half)
		local gated = side == 0 or side == 2
		local spans = if gated
			then { { -half - thick / 2, -gate }, { gate, half + thick / 2 } }
			else { { -half - thick / 2, half + thick / 2 } }
		for _, span in spans do
			local a, b = span[1], span[2]
			local length = b - a
			local middle = (a + b) / 2
			block("Wall", Vector3.new(length, height, thick), wall * CFrame.new(middle, height / 2, 0), STONE)
			block("WallBase", Vector3.new(length, 2, thick + 0.8), wall * CFrame.new(middle, 1, 0), DARK_STONE)
			block(
				"WallTop",
				Vector3.new(length, 0.6, thick + 0.6),
				wall * CFrame.new(middle, height + 0.3, 0),
				DARK_STONE
			)
			local count = math.floor(length / 4)
			for i = 0, count - 1 do
				local x = a + (i + 0.5) * length / count
				block("Merlon", Vector3.new(2, 2.4, thick), wall * CFrame.new(x, height + 1.8, 0), STONE)
			end
		end
		-- Torches and banners on the inside of the wall (inside is local -Z).
		for _, x in { -32, -12, 12, 32 } do
			local at = wall * CFrame.new(x, 8, -thick / 2 - 0.45)
			block("TorchBracket", Vector3.new(0.5, 0.5, 0.9), at, IRON, Enum.Material.Metal)
			local torch = block(
				"Torch",
				Vector3.new(0.45, 1.8, 0.45),
				at * CFrame.new(0, 0.9, -0.3) * CFrame.Angles(math.rad(-15), 0, 0),
				Color3.fromRGB(96, 68, 44),
				Enum.Material.Wood
			)
			local fire = Instance.new("Fire")
			fire.Size = 2.2
			fire.Heat = 6
			fire.Color = Color3.fromRGB(255, 150, 60)
			fire.SecondaryColor = Color3.fromRGB(255, 70, 20)
			fire.Parent = torch
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 170, 90)
			light.Range = 16
			light.Brightness = 1.4
			light.Shadows = true
			light.Parent = torch
		end
		for index, x in { -22, 0, 22 } do
			if not (gated and x == 0) then
				local color = BANNERS[(side + index) % #BANNERS + 1]
				local at = wall * CFrame.new(x, 10.5, -thick / 2 - 0.15)
				block("BannerRod", Vector3.new(5, 0.3, 0.3), at * CFrame.new(0, 3.6, 0), IRON, Enum.Material.Metal)
				block("Banner", Vector3.new(4, 7, 0.15), at, color, Enum.Material.Fabric)
				block(
					"BannerStripe",
					Vector3.new(4.02, 0.5, 0.17),
					at * CFrame.new(0, -2.6, 0),
					BANNERS[4],
					Enum.Material.Fabric
				)
				block(
					"BannerEmblem",
					Vector3.new(1.4, 1.4, 0.18),
					at * CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.rad(45)),
					BANNERS[4],
					Enum.Material.Fabric
				)
			end
		end
		if gated then
			-- The gate: an arch over the opening and a raised portcullis.
			block("GateTop", Vector3.new(gate * 2, 5, thick), wall * CFrame.new(0, height - 2.5, 0), STONE)
			block("GateArch", Vector3.new(gate * 2, 1.2, thick + 1), wall * CFrame.new(0, height - 5.6, 0), DARK_STONE)
			for _, x in { -gate - 0.6, gate + 0.6 } do
				block(
					"GatePillar",
					Vector3.new(1.6, height - 5, thick + 1.2),
					wall * CFrame.new(x, (height - 5) / 2, 0),
					DARK_STONE
				)
			end
			for x = -gate + 1, gate - 1, 2 do
				block(
					"Portcullis",
					Vector3.new(0.35, 3.6, 0.35),
					wall * CFrame.new(x, height - 7.8, 0),
					IRON,
					Enum.Material.Metal
				)
			end
			block(
				"PortcullisBar",
				Vector3.new(gate * 2 - 1, 0.35, 0.4),
				wall * CFrame.new(0, height - 9.4, 0),
				IRON,
				Enum.Material.Metal
			)
			for i = 0, 2 do
				block("Merlon", Vector3.new(2, 2.4, thick), wall * CFrame.new(-4 + i * 4, height + 1.8, 0), STONE)
			end
		end
	end

	-- Round towers on the corners with pointed roofs and flags.
	local tower = 26
	for index, corner in { Vector3.new(-1, 0, -1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, 1) } do
		local at = base * CFrame.new(corner.X * half, 0, corner.Z * half)
		cylinder("Tower", tower, 14, at * CFrame.new(0, tower / 2, 0), STONE)
		cylinder("TowerBase", 2, 15, at * CFrame.new(0, 1, 0), DARK_STONE)
		cylinder("TowerRim", 1.4, 16, at * CFrame.new(0, tower + 0.7, 0), DARK_STONE)
		for step = 0, 9 do
			local width = 17 - step * 1.65
			cylinder("Roof", 1.2, width, at * CFrame.new(0, tower + 1.9 + step * 1.1, 0), ROOF, Enum.Material.Slate)
		end
		for w = 0, 3 do
			block(
				"ArrowSlit",
				Vector3.new(0.9, 3, 0.6),
				at * CFrame.Angles(0, w * math.pi / 2 + math.pi / 4, 0) * CFrame.new(0, 17, 6.8),
				Color3.fromRGB(28, 26, 24),
				Enum.Material.Slate
			)
		end
		local top = tower + 1.9 + 10 * 1.1
		block("FlagPole", Vector3.new(0.3, 7, 0.3), at * CFrame.new(0, top + 3, 0), WOOD, Enum.Material.Wood)
		block(
			"Flag",
			Vector3.new(0.12, 2.4, 4),
			at * CFrame.new(0, top + 5.2, 2.1) * CFrame.Angles(0, math.rad(90), 0),
			BANNERS[index],
			Enum.Material.Fabric
		)
	end

	-- The fountain in the middle of the courtyard.
	local fountain = lobbyPoint(0, 0, 6)
	workspace.Terrain:FillCylinder(CFrame.new(fountain - Vector3.new(0, 1, 0)), 4, 6.5, Enum.Material.Water)
	for i = 0, 17 do
		local angle = i / 18 * math.pi * 2
		block(
			"FountainRim",
			Vector3.new(2.6, 1.8, 1.2),
			CFrame.new(fountain) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0.6, 7.2),
			Color3.fromRGB(200, 196, 188),
			Enum.Material.Marble
		)
	end
	cylinder(
		"FountainPillar",
		5,
		1.8,
		CFrame.new(fountain + Vector3.new(0, 0.5, 0)),
		Color3.fromRGB(200, 196, 188),
		Enum.Material.Marble
	)
	cylinder(
		"FountainBowl",
		0.8,
		6,
		CFrame.new(fountain + Vector3.new(0, 3.2, 0)),
		Color3.fromRGB(200, 196, 188),
		Enum.Material.Marble
	)
	local spout = cylinder(
		"FountainTop",
		1.4,
		1.2,
		CFrame.new(fountain + Vector3.new(0, 4.2, 0)),
		Color3.fromRGB(214, 190, 120),
		Enum.Material.Foil
	)
	local spray = Instance.new("ParticleEmitter")
	spray.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	spray.Color = ColorSequence.new(Color3.fromRGB(210, 235, 255))
	spray.Size = NumberSequence.new(0.35, 0.1)
	spray.Transparency = NumberSequence.new(0.2, 1)
	spray.Lifetime = NumberRange.new(0.9, 1.2)
	spray.Rate = 60
	spray.Speed = NumberRange.new(7, 9)
	spray.SpreadAngle = Vector2.new(18, 18)
	spray.Acceleration = Vector3.new(0, -24, 0)
	spray.EmissionDirection = Enum.NormalId.Right -- up, since the cylinder lies on its side
	spray.Parent = spout

	-- The duel arena: a sand ring with a low fence and an opening.
	local spots = WorldBuilder.LobbySpots
	cylinder(
		"ArenaFloor",
		0.4,
		spots.arenaRadius * 2,
		CFrame.new(spots.arena + Vector3.new(0, 0.2, 0)),
		Color3.fromRGB(214, 190, 140),
		Enum.Material.Sand
	)
	for i = 0, 19 do
		if i ~= 10 and i ~= 11 then -- the opening faces the fountain
			local angle = i / 20 * math.pi * 2
			block(
				"ArenaPost",
				Vector3.new(0.6, 2.4, 0.6),
				CFrame.new(spots.arena) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 1.2, spots.arenaRadius),
				Color3.fromRGB(96, 70, 48),
				Enum.Material.Wood
			)
		end
	end
	cylinder(
		"ArenaCircle",
		0.42,
		3,
		CFrame.new(spots.arena + Vector3.new(0, 0.2, 0)),
		Color3.fromRGB(176, 40, 40),
		Enum.Material.Fabric
	)

	-- Signs over the arena and the practice dummies.
	local function sign(text: string, at: Vector3)
		local holder = block(
			"SignPost",
			Vector3.new(0.6, 7, 0.6),
			CFrame.new(at + Vector3.new(0, 3.5, 0)),
			Color3.fromRGB(96, 70, 48),
			Enum.Material.Wood
		)
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(220, 50)
		gui.StudsOffset = Vector3.new(0, 4.5, 0)
		gui.MaxDistance = 90
		gui.Parent = holder
		local l = label(gui, "Text", text, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), 32, Color3.new(1, 1, 1))
		l.TextStrokeTransparency = 0.3
	end
	sign("⚔️ Duel Arena", spots.arena + Vector3.new(-12, 0, -9))
	sign("🎯 Practice", spots.dummies[1] + Vector3.new(4, 0, -6))

	-- Stone benches and planters around the courtyard.
	for _, x in { -14, 14 } do
		for _, z in { 18, -2 } do
			local at = CFrame.lookAt(lobbyPoint(x, 0, z), fountain)
			block(
				"Bench",
				Vector3.new(5, 0.5, 1.6),
				at * CFrame.new(0, 1.3, 0),
				Color3.fromRGB(200, 196, 188),
				Enum.Material.Marble
			)
			for _, bx in { -2, 2 } do
				block("BenchLeg", Vector3.new(0.6, 1.1, 1.4), at * CFrame.new(bx, 0.55, 0), DARK_STONE)
			end
		end
	end

	model.Parent = parent
end

-- 🛍️ The shop street: its own little island behind the castle (over a
-- bridge from the back gate), with market stalls down both sides of a
-- cobbled street. Each stall has a seller; talk to them (the E prompt) to
-- open that shop (the client's ShopStreet controller opens the window).
local STREET = LOBBY + Vector3.new(0, 0, -Config.Lobby.StreetDistance)

WorldBuilder.Shops = {
	{ key = "Market", name = "🏪 Kit Market", seller = "Merchant Mo", color = Color3.fromRGB(60, 150, 200) },
	{ key = "Kits", name = "🌪️ Kit Stables", seller = "Stable Master Sam", color = Color3.fromRGB(110, 170, 255) },
	{ key = "Style", name = "🎨 Style Boutique", seller = "Stylist Stella", color = Color3.fromRGB(230, 110, 180) },
	{ key = "Pets", name = "🐾 Pet Shop", seller = "Pet Keeper Pip", color = Color3.fromRGB(120, 200, 110) },
	{ key = "Emotes", name = "😀 Emote Stage", seller = "Dancer Dex", color = Color3.fromRGB(250, 180, 60) },
	{ key = "Paint", name = "🖌️ Paint Shop", seller = "Painter Pia", color = Color3.fromRGB(170, 110, 230) },
	{ key = "Rewards", name = "🎡 Prize Wheel", seller = "Lucky Lou", color = Color3.fromRGB(240, 90, 90) },
	{ key = "Robux", name = "💎 Gem Shop", seller = "Gem Trader Gus", color = Color3.fromRGB(40, 170, 110) },
}

local function stall(parent: Instance, at: CFrame, shop: { key: string, name: string, seller: string, color: Color3 })
	local model = Instance.new("Model")
	model.Name = "Stall_" .. shop.key
	local wood = Color3.fromRGB(116, 82, 54)
	local function block(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material): Part
		return part({
			Name = name,
			Size = size,
			CFrame = at * offset,
			Color = color,
			Material = material,
			Parent = model,
		})
	end
	-- `at` faces the street (-Z); the seller stands behind the counter.
	local counter = block("Counter", Vector3.new(8, 3, 2.2), CFrame.new(0, 1.5, -1), wood, Enum.Material.WoodPlanks)
	block(
		"CounterTop",
		Vector3.new(8.4, 0.3, 2.6),
		CFrame.new(0, 3.15, -1),
		Color3.fromRGB(86, 60, 40),
		Enum.Material.Wood
	)
	block("BackWall", Vector3.new(8, 7, 0.4), CFrame.new(0, 3.5, 3.4), wood, Enum.Material.WoodPlanks)
	for _, x in { -3.8, 3.8 } do
		for _, z in { -1.8, 3.2 } do
			block(
				"Post",
				Vector3.new(0.5, 7.6, 0.5),
				CFrame.new(x, 3.8, z),
				Color3.fromRGB(90, 64, 42),
				Enum.Material.Wood
			)
		end
	end
	-- A striped awning in the shop's color.
	for i = 0, 7 do
		block(
			"Awning",
			Vector3.new(1.05, 0.2, 6.2),
			CFrame.new(-3.65 + i * 1.05, 7.9, 0.7) * CFrame.Angles(math.rad(-14), 0, 0),
			if i % 2 == 0 then shop.color else Color3.fromRGB(245, 240, 230),
			Enum.Material.Fabric
		)
	end
	-- Crates and a lantern.
	block(
		"Crate",
		Vector3.new(1.6, 1.6, 1.6),
		CFrame.new(-4.8, 0.8, -1.6) * CFrame.Angles(0, 0.3, 0),
		wood,
		Enum.Material.WoodPlanks
	)
	local lantern = block(
		"Lantern",
		Vector3.new(0.7, 1, 0.7),
		CFrame.new(3.8, 6.6, -2.2),
		Color3.fromRGB(255, 220, 140),
		Enum.Material.Neon
	)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 200, 130)
	light.Range = 14
	light.Brightness = 1.2
	light.Parent = lantern
	-- The shop sign over the awning.
	local sign = block(
		"Sign",
		Vector3.new(7, 1.6, 0.3),
		CFrame.new(0, 9.3, -2.2),
		Color3.fromRGB(60, 44, 30),
		Enum.Material.Wood
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(350, 80)
	gui.LightInfluence = 0.2
	gui.Parent = sign
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(255, 230, 170)
	text.Text = shop.name
	text.Parent = gui
	-- Talk to the seller to shop.
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Shop"
	prompt.ObjectText = shop.name .. " · " .. shop.seller
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OpenWindow", shop.key)
	prompt.Parent = counter
	model.Parent = parent
	-- The seller (a Roblox avatar) behind the counter.
	task.spawn(function()
		local ok, seller = pcall(function()
			local description = Instance.new("HumanoidDescription")
			local skin = ({
				Color3.fromRGB(255, 219, 172),
				Color3.fromRGB(234, 184, 146),
				Color3.fromRGB(198, 134, 66),
				Color3.fromRGB(141, 85, 36),
			})[math.random(1, 4)]
			description.HeadColor = skin
			description.LeftArmColor = skin
			description.RightArmColor = skin
			description.TorsoColor = shop.color
			description.LeftLegColor = Color3.fromRGB(70, 60, 55)
			description.RightLegColor = Color3.fromRGB(70, 60, 55)
			return game:GetService("Players"):CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
		end)
		if not ok or not seller then
			return
		end
		seller.Name = shop.seller
		for _, p in seller:GetDescendants() do
			if p:IsA("BasePart") then
				p.Anchored = p.Name == "HumanoidRootPart"
				p.CanCollide = false
			end
		end
		local humanoid = seller:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.DisplayName = shop.seller
			humanoid.NameDisplayDistance = 40
			humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		end
		seller:PivotTo(at * CFrame.new(0, 3, 1.3))
		seller.Parent = model
		-- A gentle idle so they don't stand frozen.
		if humanoid then
			local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
			animator.Parent = humanoid
			local animation = Instance.new("Animation")
			animation.AnimationId = "rbxassetid://507766666"
			pcall(function()
				local track = animator:LoadAnimation(animation)
				track.Looped = true
				track:Play()
			end)
		end
	end)
end

local function shopStreet(world: Instance, rng: Random)
	local radius = Config.Lobby.StreetRadius
	local island = floatingIsland(world, "ShopStreet", STREET, radius, rng)
	local terrain = workspace.Terrain
	local length = radius * 2 - 16
	terrain:FillBlock(CFrame.new(STREET - Vector3.new(0, 2, 0)), Vector3.new(14, 4, length), Enum.Material.Cobblestone)
	-- The bridge from the castle's back path.
	bridge(world, LOBBY + Vector3.new(0, 0, -(Config.Lobby.Radius - 4)), STREET + Vector3.new(0, 0, radius - 4))
	-- An archway over the entrance.
	local entrance = CFrame.new(STREET + Vector3.new(0, 0, length / 2 - 2))
	for _, x in { -8, 8 } do
		part({
			Name = "ArchPillar",
			Size = Vector3.new(2, 12, 2),
			CFrame = entrance * CFrame.new(x, 6, 0),
			Color = Color3.fromRGB(200, 196, 188),
			Material = Enum.Material.Marble,
			Parent = island,
		})
	end
	local banner = part({
		Name = "ArchSign",
		Size = Vector3.new(18, 3, 0.6),
		CFrame = entrance * CFrame.new(0, 12.5, 0),
		Color = Color3.fromRGB(150, 60, 50),
		Material = Enum.Material.Fabric,
		Parent = island,
	})
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.CanvasSize = Vector2.new(600, 100)
		gui.Parent = banner
		label(
			gui,
			"Text",
			"🛍️ Shop Street",
			UDim2.fromScale(1, 1),
			UDim2.fromScale(0, 0),
			90,
			Color3.fromRGB(255, 230, 170)
		)
	end
	-- Stalls down both sides, facing the street.
	local count = #WorldBuilder.Shops
	local perSide = math.ceil(count / 2)
	for index, shop in WorldBuilder.Shops do
		local side = if index <= perSide then -1 else 1
		local slot = if index <= perSide then index else index - perSide
		local z = length / 2 - 14 - (slot - 1) * ((length - 24) / math.max(1, perSide - 1))
		local position = STREET + Vector3.new(side * 13, 0, z)
		stall(island, CFrame.lookAt(position, position - Vector3.new(side, 0, 0)), shop)
	end
	-- Street lamps.
	for z = -length / 2 + 6, length / 2 - 6, 18 do
		for _, x in { -8, 8 } do
			local base = STREET + Vector3.new(x, 0, z)
			part({
				Name = "LampPost",
				Size = Vector3.new(0.5, 9, 0.5),
				CFrame = CFrame.new(base + Vector3.new(0, 4.5, 0)),
				Color = Color3.fromRGB(40, 40, 46),
				Material = Enum.Material.Metal,
				Parent = island,
			})
			local lamp = part({
				Name = "Lamp",
				Size = Vector3.new(1, 1.2, 1),
				CFrame = CFrame.new(base + Vector3.new(0, 9.4, 0)),
				Color = Color3.fromRGB(255, 226, 160),
				Material = Enum.Material.Neon,
				CanCollide = false,
				Parent = island,
			})
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 210, 150)
			light.Range = 18
			light.Brightness = 1.3
			light.Parent = lamp
		end
	end
	-- A few trees around the back.
	scatter(island, CFrame.new(STREET), rng, { trees = 6, flowers = 10, mushrooms = 3, bushes = 6 }, {
		treeMin = 28,
		treeMax = radius - 5,
		max = radius - 4,
	}, function(p: Vector3): boolean
		return math.abs(p.X) < 22 or p.Z > radius - 14
	end)
end

-- A wooden signpost with an arrow-shaped board.
local function signpost(parent: Instance, at: Vector3, facing: Vector3, text: string)
	local frame = CFrame.lookAt(at, Vector3.new(facing.X, at.Y, facing.Z))
	part({
		Name = "SignPost",
		Size = Vector3.new(0.6, 7, 0.6),
		CFrame = frame * CFrame.new(0, 3.5, 0),
		Color = Color3.fromRGB(96, 70, 48),
		Material = Enum.Material.Wood,
		Parent = parent,
	})
	local board = part({
		Name = "SignBoard",
		Size = Vector3.new(8, 1.8, 0.3),
		CFrame = frame * CFrame.new(0, 6, -0.4),
		Color = Color3.fromRGB(150, 110, 70),
		Material = Enum.Material.WoodPlanks,
		Parent = parent,
	})
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.CanvasSize = Vector2.new(400, 90)
		gui.Parent = board
		label(gui, "Text", text, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), 60, Color3.fromRGB(255, 240, 210))
	end
end

-- 🎯 Games Island (east) and 🏗️ Base Island (west): flat grassy islands over
-- bridges from the lobby island's sides (MiniGameService and BaseService
-- build what's on them).
local function sideIslands(world: Instance, rng: Random)
	local terrain = workspace.Terrain
	local half = Config.Lobby.CastleHalf
	for _, side in { 1, -1 } do
		local radius = if side == 1 then Config.Lobby.GamesRadius else Config.Lobby.BaseRadius
		local center = LOBBY + Vector3.new(side * Config.Lobby.SideDistance, 0, 0)
		local island = floatingIsland(world, if side == 1 then "GamesIsland" else "BaseIsland", center, radius, rng)
		-- A path from the castle wall to the bridge, and the bridge.
		local pathLength = Config.Lobby.Radius - half - 10
		terrain:FillBlock(
			CFrame.new(lobbyPoint(side * (half + 6 + pathLength / 2), -2, 0)),
			Vector3.new(pathLength, 4, 8),
			Enum.Material.Pavement
		)
		bridge(
			world,
			LOBBY + Vector3.new(side * (Config.Lobby.Radius - 4), 0, 0),
			center - Vector3.new(side * (radius - 4), 0, 0)
		)
		-- A few trees round the edge.
		scatter(island, CFrame.new(center), rng, { trees = 8, flowers = 10, mushrooms = 3, bushes = 6 }, {
			treeMin = radius - 14,
			treeMax = radius - 5,
			max = radius - 4,
		}, function(p: Vector3): boolean
			return math.abs(p.Z) < 10 -- keep the bridge end clear
				or (side == -1 and math.abs(p.X) < 72 and math.abs(p.Z) < 38) -- the building plots
		end)
	end
	-- Signposts outside the main gate pointing the way.
	signpost(world, lobbyPoint(14, 0, 56), lobbyPoint(60, 0, 56), "🎯 Games Island →")
	signpost(world, lobbyPoint(-14, 0, 56), lobbyPoint(-60, 0, 56), "🏗️ Base Island →")
	signpost(world, lobbyPoint(7, 0, -58), lobbyPoint(7, 0, -100), "🛍️ Shop Street →")
end

local function lobbyIsland(world: Instance, rng: Random)
	local island = floatingIsland(world, "Lobby", LOBBY, Config.Lobby.Radius, rng)
	local terrain = workspace.Terrain
	local half = Config.Lobby.CastleHalf
	-- A cobbled courtyard and a path from the gate to the island's edge.
	terrain:FillBlock(
		CFrame.new(LOBBY - Vector3.new(0, 2, 0)),
		Vector3.new(half * 2, 4, half * 2),
		Enum.Material.Cobblestone
	)
	local pathLength = Config.Lobby.Radius - half - 6
	terrain:FillBlock(
		CFrame.new(lobbyPoint(0, -2, half + pathLength / 2)),
		Vector3.new(8, 4, pathLength),
		Enum.Material.Pavement
	)
	-- And one out of the back gate, to the shop street bridge.
	terrain:FillBlock(
		CFrame.new(lobbyPoint(0, -2, -(half + pathLength / 2))),
		Vector3.new(8, 4, pathLength),
		Enum.Material.Pavement
	)
	castle(island)
	local frame = CFrame.new(LOBBY)
	local function blocked(p: Vector3): boolean
		return lobbyBlocked(p)
	end
	boulders(frame, Config.Lobby.Radius, 6, rng, blocked)
	scatter(island, frame, rng, { trees = 16, flowers = 20, mushrooms = 8, bushes = 10 }, {
		treeMin = 56,
		treeMax = Config.Lobby.Radius - 6,
		max = Config.Lobby.Radius - 4,
	}, blocked)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Shape = Enum.PartType.Cylinder
	spawn.Size = Vector3.new(1, 12, 12)
	spawn.CFrame = WorldBuilder.LobbySpots.spawn * CFrame.Angles(0, 0, math.rad(90))
	spawn.Material = Enum.Material.Marble
	spawn.Color = Color3.fromRGB(226, 222, 212)
	spawn.Duration = 0
	spawn.Parent = island
	part({
		Name = "SpawnGlow",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.05, 8, 8),
		CFrame = spawn.CFrame,
		Color = Color3.fromRGB(150, 220, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		CanCollide = false,
		CanQuery = false,
		Parent = island,
	})

	forecastTV(island, WorldBuilder.LobbySpots.tv, WorldBuilder.LobbySpots.tv + Vector3.new(0, 0, 10))

	local clouds = Instance.new("Folder")
	clouds.Name = "Clouds"
	clouds.Parent = island
	for _ = 1, 8 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(60, 160)
		cloudCluster(
			clouds,
			LOBBY + Vector3.new(math.cos(angle) * distance, rng:NextNumber(-60, -25), math.sin(angle) * distance),
			rng:NextNumber(14, 26),
			rng
		)
	end
end

-- Other services use these to keep things off the islands' busy spots
-- (team islands in island space: -Z faces the middle).
WorldBuilder.isWildBlocked = wildBlocked
WorldBuilder.isPlotBlocked = plotBlocked

export type PlotInfo = {
	index: number,
	cframe: CFrame, -- island top center; LookVector points at the world center
	model: Model,
}

-- Builds everything and returns one PlotInfo per player island.
function WorldBuilder.build(): { PlotInfo }
	setupLighting()

	-- The Baseplate template's floor would catch everyone who falls off the sky.
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end

	local world = Instance.new("Folder")
	world.Name = "World"

	local rng = Random.new(42)
	local center = Vector3.new(0, 0, 0)
	local terrain = workspace.Terrain
	pcall(function()
		terrain.Decoration = true -- swaying grass blades on the grass (not allowed everywhere)
	end)
	terrain:SetMaterialColor(Enum.Material.Grass, GRASS)
	terrain:SetMaterialColor(Enum.Material.Ground, DIRT)
	terrain:SetMaterialColor(Enum.Material.Rock, ROCK)
	terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(78, 112, 52))
	local wild = floatingIsland(world, "WildSkies", center, Config.World.CenterRadius, rng)
	boulders(CFrame.new(center), Config.World.CenterRadius, 14, rng, wildBlocked)
	scatter(wild, CFrame.new(center), rng, { trees = 32, flowers = 55, mushrooms = 20, bushes = 22 }, {
		treeMin = Config.World.CenterRadius * 0.72,
		treeMax = Config.World.CenterRadius - 6,
		max = Config.World.CenterRadius - 4,
	}, wildBlocked)

	lobbyIsland(world, rng)
	shopStreet(world, rng)
	sideIslands(world, rng)

	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = world

	local plots: { PlotInfo } = {}
	for index = 1, Config.MaxPlots do
		local angle = (index - 1) / Config.MaxPlots * math.pi * 2
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local plotCenter = center + direction * Config.World.PlotRingDistance
		local cframe = CFrame.lookAt(plotCenter, center)

		local island = floatingIsland(plotsFolder, "Plot" .. index, plotCenter, Config.World.PlotRadius, rng)
		boulders(cframe, Config.World.PlotRadius, 5, rng, plotBlocked)
		island:SetAttribute("PlotIndex", index)
		table.insert(plots, { index = index, cframe = cframe, model = island })
		decoratePlot(island, cframe, rng)

		bridge(
			world,
			center + direction * (Config.World.CenterRadius - 4),
			plotCenter - direction * (Config.World.PlotRadius - 4)
		)
	end

	local clouds = Instance.new("Folder")
	clouds.Name = "Clouds"
	clouds.Parent = world
	for _ = 1, 26 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(60, 520)
		local height = rng:NextNumber(-70, -25)
		if rng:NextNumber() < 0.3 then
			height = rng:NextNumber(60, 120)
		end
		cloudCluster(
			clouds,
			Vector3.new(math.cos(angle) * distance, height, math.sin(angle) * distance),
			rng:NextNumber(14, 30),
			rng
		)
	end

	world.Parent = workspace
	return plots
end

return WorldBuilder
