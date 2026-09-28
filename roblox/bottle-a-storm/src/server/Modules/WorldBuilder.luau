-- Builds the sky world from code: the big middle island (the lobby between
-- matches, and the Crystal and Core generators during them), 8 team islands
-- around it, bridges, clouds and the weather forecast TV. Replace with
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

-- Keeps decorations off the spawn, forecast TV, leaderboards and bridge ends.
local function wildBlocked(p: Vector3): boolean
	local spawn = Vector3.new(0, 0, -(Config.World.CenterRadius - 20))
	if (p - spawn).Magnitude < 14 or (p - Vector3.new(0, 0, -30)).Magnitude < 16 then
		return true
	end
	if p.Z > -128 and p.Z < -76 and math.abs(p.X) < 136 then
		return true -- leaderboards and the winners' podium
	end
	local degrees = math.deg(math.atan2(p.Z, p.X)) % 360
	if degrees > 192 and degrees < 222 and p.Magnitude > 130 then
		return true -- the first steps of the lobby parkour
	end
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
	terrain.Decoration = true -- swaying grass blades on the grass
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

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "WildSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(0, 0.5, -Config.World.CenterRadius + 20)
	spawn.Material = Enum.Material.Neon
	spawn.Color = Color3.fromRGB(150, 220, 255)
	spawn.Transparency = 0.4
	spawn.Duration = 0
	spawn.Parent = world

	forecastTV(world, Vector3.new(0, 0, -30), Vector3.new(0, 0, -100))

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
