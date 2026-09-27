-- Builds the sky world from code: the Wild Skies island in the middle, one
-- floating island per player around it, bridges, clouds and the forecast TV.
-- Replace with hand-built terrain later; the services only need the plot
-- CFrames and the part names used here.

local Lighting = game:GetService("Lighting")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local ClimateData = require(Shared.ClimateData)
local Config = require(Shared.Config)

local WorldBuilder = {}

local GRASS = Color3.fromRGB(120, 200, 110)
local WILD_GRASS = Color3.fromRGB(150, 215, 140)
local DIRT = Color3.fromRGB(140, 105, 80)
local ROCK = Color3.fromRGB(120, 115, 125)
local WOOD = Color3.fromRGB(170, 125, 80)
local CLOUD = Color3.fromRGB(250, 252, 255)

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

-- A flat disc whose top surface sits at `top`.
local function disc(
	parent: Instance,
	name: string,
	center: Vector3,
	radius: number,
	thickness: number,
	color: Color3,
	material: Enum.Material
): Part
	return part({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(thickness, radius * 2, radius * 2),
		CFrame = CFrame.new(center - Vector3.new(0, thickness / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material,
		Parent = parent,
	})
end

-- Grass top with shrinking layers of dirt and rock underneath.
local function floatingIsland(
	parent: Instance,
	name: string,
	center: Vector3,
	radius: number,
	grass: Color3,
	groundMaterial: Enum.Material?,
	rock: Color3?
): Model
	local model = Instance.new("Model")
	model.Name = name
	local top = disc(model, "Ground", center, radius, 4, grass, groundMaterial or Enum.Material.Grass)
	model.PrimaryPart = top
	local layers = {
		{ scale = 0.92, depth = 4, thickness = 7, color = rock or DIRT },
		{ scale = 0.7, depth = 11, thickness = 8, color = rock or ROCK },
		{ scale = 0.42, depth = 19, thickness = 9, color = rock or ROCK },
		{ scale = 0.18, depth = 28, thickness = 8, color = rock or ROCK },
	}
	for index, layer in layers do
		disc(
			model,
			"Underside" .. index,
			center - Vector3.new(0, layer.depth, 0),
			radius * layer.scale,
			layer.thickness,
			layer.color,
			Enum.Material.Slate
		)
	end
	model.Parent = parent
	return model
end

local function bridge(parent: Instance, from: Vector3, to: Vector3)
	local model = Instance.new("Model")
	model.Name = "Bridge"
	local flatTo = Vector3.new(to.X, from.Y, to.Z)
	local length = (flatTo - from).Magnitude
	local frame = CFrame.lookAt((from + flatTo) / 2, flatTo)
	part({
		Name = "Deck",
		Size = Vector3.new(12, 1.5, length),
		CFrame = frame * CFrame.new(0, -0.75, 0),
		Color = WOOD,
		Material = Enum.Material.WoodPlanks,
		Parent = model,
	})
	for _, side in { -1, 1 } do
		part({
			Name = "Rail",
			Size = Vector3.new(0.6, 2.5, length),
			CFrame = frame * CFrame.new(6 * side, 1.25, 0),
			Color = Color3.fromRGB(235, 225, 200),
			Material = Enum.Material.Wood,
			Parent = model,
		})
	end
	model.Parent = parent
end

local function cloudCluster(parent: Instance, center: Vector3, size: number, rng: Random)
	for _ = 1, rng:NextInteger(3, 5) do
		local s = size * rng:NextNumber(0.6, 1.1)
		part({
			Name = "Cloud",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(s, s * 0.7, s),
			CFrame = CFrame.new(
				center
					+ Vector3.new(
						rng:NextNumber(-size, size),
						rng:NextNumber(-size * 0.15, size * 0.15),
						rng:NextNumber(-size, size) * 0.6
					)
			),
			Color = CLOUD,
			Material = Enum.Material.SmoothPlastic,
			Transparency = 0.15,
			CanCollide = false,
			CanTouch = false,
			CanQuery = false,
			CastShadow = false,
			Parent = parent,
		})
	end
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
	l.Font = Enum.Font.FredokaOne
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

local function setupLighting()
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.2
	Lighting.Ambient = Color3.fromRGB(140, 150, 170)
	Lighting.OutdoorAmbient = Color3.fromRGB(170, 185, 210)
	Lighting.GlobalShadows = true
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.3
		atmosphere.Offset = 0.2
		atmosphere.Color = Color3.fromRGB(200, 225, 255)
		atmosphere.Decay = Color3.fromRGB(120, 160, 220)
		atmosphere.Glare = 0.2
		atmosphere.Haze = 1.2
		atmosphere.Parent = Lighting
	end
end

-- A glowing pad that teleports you (handled by ClimateService).
local function portalPad(
	parent: Instance,
	name: string,
	position: Vector3,
	color: Color3,
	title: string,
	subtitle: string
): Part
	local pad = part({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 12, 12),
		CFrame = CFrame.new(position + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.2,
		Parent = parent,
	})
	part({
		Name = "Ring",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 16, 16),
		CFrame = CFrame.new(position + Vector3.new(0, 9, 0)) * CFrame.Angles(0, math.rad(90), 0),
		Color = color,
		Material = Enum.Material.ForceField,
		CanCollide = false,
		CanTouch = false,
		Parent = pad,
	})
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(260, 70)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 19, 0)
	gui.MaxDistance = 250
	gui.LightInfluence = 0
	gui.Parent = pad
	label(gui, "Title", title, UDim2.fromScale(1, 0.6), UDim2.fromScale(0, 0), 32, Color3.new(1, 1, 1))
	label(gui, "Subtitle", subtitle, UDim2.fromScale(1, 0.4), UDim2.fromScale(0, 0.6), 22, color)
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = color
	sparkles.Parent = pad
	return pad
end

-- Themed props for each Climate Shift island.
local function decorateBiome(parent: Instance, climate: ClimateData.Climate, center: Vector3, rng: Random)
	local radius = ClimateData.BiomeRadius
	local function spot(minR: number, maxR: number): Vector3
		local angle = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(minR, maxR)
		return center + Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
	end
	if climate.key == "Arctic" then
		for _ = 1, 10 do
			local height = rng:NextNumber(8, 20)
			part({
				Name = "IceSpike",
				Size = Vector3.new(3, height, 3),
				CFrame = CFrame.new(spot(30, radius - 8) + Vector3.new(0, height / 2 - 1, 0))
					* CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, 6), rng:NextNumber(-0.25, 0.25)),
				Color = Color3.fromRGB(170, 220, 255),
				Material = Enum.Material.Ice,
				Transparency = 0.2,
				Parent = parent,
			})
		end
	elseif climate.key == "Volcano" then
		for _ = 1, 4 do
			local size = rng:NextNumber(10, 16)
			part({
				Name = "LavaPool",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.4, size, size),
				CFrame = CFrame.new(spot(28, radius - 12) + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				Color = Color3.fromRGB(255, 110, 30),
				Material = Enum.Material.Neon,
				CanCollide = false,
				Parent = parent,
			})
		end
		for _ = 1, 6 do
			local height = rng:NextNumber(12, 24)
			local spire = part({
				Name = "Spire",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(height, 5, 5),
				CFrame = CFrame.new(spot(30, radius - 6) + Vector3.new(0, height / 2, 0))
					* CFrame.Angles(0, 0, math.rad(90)),
				Color = Color3.fromRGB(55, 40, 40),
				Material = Enum.Material.Basalt,
				Parent = parent,
			})
			local fire = Instance.new("Fire")
			fire.Size = 6
			fire.Heat = 12
			fire.Parent = spire
		end
	elseif climate.key == "Space" then
		for _ = 1, 10 do
			local height = rng:NextNumber(5, 12)
			part({
				Name = "Crystal",
				Size = Vector3.new(2.5, height, 2.5),
				CFrame = CFrame.new(spot(28, radius - 6) + Vector3.new(0, height / 2 - 1, 0))
					* CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6), rng:NextNumber(-0.4, 0.4)),
				Color = if rng:NextNumber() < 0.5 then Color3.fromRGB(150, 110, 255) else Color3.fromRGB(90, 220, 255),
				Material = Enum.Material.Neon,
				Parent = parent,
			})
		end
		for _ = 1, 6 do
			local size = rng:NextNumber(2, 5)
			part({
				Name = "Orb",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(size, size, size),
				CFrame = CFrame.new(spot(10, radius) + Vector3.new(0, rng:NextNumber(25, 45), 0)),
				Color = Color3.fromRGB(255, 240, 200),
				Material = Enum.Material.Neon,
				CanCollide = false,
				Parent = parent,
			})
		end
	end
end

export type BiomeInfo = {
	climate: ClimateData.Climate,
	center: Vector3, -- island top center
	spawn: CFrame, -- where the portal drops you
}

-- Filled in by build(): the Climate Shift islands and where the Wild Skies
-- return portal drops you.
WorldBuilder.Biomes = {} :: { [string]: BiomeInfo }
WorldBuilder.WildArrival = CFrame.new(0, 4, 50)

-- The portal row on the Wild Skies, and one island per climate.
local function buildBiomes(world: Instance, rng: Random)
	local portals = Instance.new("Folder")
	portals.Name = "Portals"
	portals.Parent = world
	local biomes = Instance.new("Folder")
	biomes.Name = "Biomes"
	biomes.Parent = world

	for _, climate in ClimateData.List do
		if climate.level > 0 then
			local color = climate.tint or Color3.new(1, 1, 1)
			local x = (climate.level - 2) * 36
			local pad = portalPad(
				portals,
				"Portal_" .. climate.key,
				Vector3.new(x, 0, 72),
				color,
				climate.emoji .. " " .. climate.name,
				"Climate Shift " .. climate.level
			)
			pad:SetAttribute("Climate", climate.key)
			pad:SetAttribute("Level", climate.level)

			local center = ClimateData.center(climate)
			local island = floatingIsland(
				biomes,
				climate.key,
				center,
				ClimateData.BiomeRadius,
				climate.ground or GRASS,
				climate.groundMaterial,
				climate.rock
			)
			island:SetAttribute("Climate", climate.key)
			island:SetAttribute("Center", center)
			island:SetAttribute("Radius", ClimateData.BiomeRadius)
			decorateBiome(island, climate, center, rng)

			-- Arrive near one edge, facing the middle.
			local arrive = center + Vector3.new(0, 4, -(ClimateData.BiomeRadius - 18))
			local back = portalPad(
				island,
				"ReturnPortal",
				center + Vector3.new(0, 0, -(ClimateData.BiomeRadius - 8)),
				Color3.fromRGB(150, 220, 255),
				"🌤️ Back to the Wild Skies",
				""
			)
			back:SetAttribute("Destination", "Wild")
			WorldBuilder.Biomes[climate.key] = {
				climate = climate,
				center = center,
				spawn = CFrame.lookAt(arrive, center + Vector3.new(0, 4, 0)),
			}
		end
	end
end

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
	floatingIsland(world, "WildSkies", center, Config.World.CenterRadius, WILD_GRASS)

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
	buildBiomes(world, rng)

	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = world

	local plots: { PlotInfo } = {}
	for index = 1, Config.MaxPlots do
		local angle = (index - 1) / Config.MaxPlots * math.pi * 2
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local plotCenter = center + direction * Config.World.PlotRingDistance
		local cframe = CFrame.lookAt(plotCenter, center)

		local island = floatingIsland(plotsFolder, "Plot" .. index, plotCenter, Config.World.PlotRadius, GRASS)
		island:SetAttribute("PlotIndex", index)
		table.insert(plots, { index = index, cframe = cframe, model = island })

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
