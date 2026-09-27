-- Cosmetics (see CosmeticsData): buying and equipping them, and building
-- them from parts.
--   Character: a hat, a trail, something on your back and an aura.
--   Island: pedestal style, decorations, the sign's color and emoji, a flag
--   and up to 3 kinds of island pets.
-- Everything is built on the server so every player sees it.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local CosmeticsData = require(Shared.CosmeticsData)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local StormData = require(Shared.StormData)

local Modules = script.Parent.Parent.Modules
local Effects = require(Modules.Effects)
local StormModel = require(Modules.StormModel)

local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local PlotService = require(script.Parent.PlotService)

local CosmeticService = {}

local SPARKLES = "rbxasset://textures/particles/sparkles_main.dds"
local rgb = Color3.fromRGB
local RAINBOW = {
	rgb(255, 120, 130),
	rgb(255, 180, 90),
	rgb(255, 230, 110),
	rgb(130, 220, 140),
	rgb(120, 180, 255),
	rgb(180, 130, 255),
}

local rng = Random.new()
local lastRequest: { [Player]: number } = {}
local signBoards: { [Player]: BasePart } = {}
local fireworkIslands: { [Player]: CFrame } = {}

---------------------------------------------------------------------------
-- Building blocks
---------------------------------------------------------------------------

local function part(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

local function ball(parent: Instance, size: Vector3, color: Color3, cframe: CFrame, material: Enum.Material?): Part
	local p = part(parent, { Size = size, Color = color, CFrame = cframe, Material = material })
	if size.X == size.Y and size.Y == size.Z then
		p.Shape = Enum.PartType.Ball
	else
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	return p
end

-- An upright cylinder (Roblox cylinders lie along X, so it's turned).
local function cylinder(parent: Instance, height: number, diameter: number, color: Color3, cframe: CFrame): Part
	return part(parent, {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		Color = color,
		CFrame = cframe * CFrame.Angles(0, 0, math.rad(90)),
	})
end

local function weldAll(model: Instance, to: BasePart)
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = to
			weld.Part1 = item
			weld.Parent = item
		end
	end
end

local function anchorAll(model: Instance)
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = true
		end
	end
end

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARKLES
	e.LightEmission = 0.5
	for key, value in props do
		(e :: any)[key] = value
	end
	e.Parent = parent
	return e
end

local function colorSequence(colors: { Color3 }): ColorSequence
	if #colors == 1 then
		return ColorSequence.new(colors[1])
	end
	local points = {}
	for index, color in colors do
		table.insert(points, ColorSequenceKeypoint.new((index - 1) / (#colors - 1), color))
	end
	return ColorSequence.new(points)
end

---------------------------------------------------------------------------
-- Character cosmetics
---------------------------------------------------------------------------

-- Each builder gets the model to fill and the top of the head (hats) or the
-- middle of the back (backs), facing the way the character faces.
local HATS: { [string]: (Model, CFrame) -> () } = {
	CloudHat = function(model, top)
		local white = rgb(250, 250, 255)
		local middle = ball(model, Vector3.one * 1.3, white, top * CFrame.new(0, 0.9, 0))
		ball(model, Vector3.one * 1, white, top * CFrame.new(0.7, 0.75, 0.1))
		ball(model, Vector3.one * 1, white, top * CFrame.new(-0.7, 0.75, -0.1))
		ball(model, Vector3.one * 0.9, white, top * CFrame.new(0.1, 0.8, 0.6))
		emitter(middle, {
			Color = ColorSequence.new(rgb(120, 190, 255)),
			Size = NumberSequence.new(0.15),
			EmissionDirection = Enum.NormalId.Bottom,
			Speed = NumberRange.new(4, 6),
			Acceleration = Vector3.new(0, -10, 0),
			Lifetime = NumberRange.new(0.4, 0.6),
			Rate = 18,
			LightEmission = 0.2,
		})
	end,
	LightningCrown = function(model, top)
		local gold = rgb(255, 220, 80)
		cylinder(model, 0.35, 1.35, gold, top * CFrame.new(0, 0.15, 0)).Material = Enum.Material.Neon
		for i = 1, 7 do
			local angle = i / 7 * math.pi * 2
			local spike = part(model, {
				Size = Vector3.new(0.18, 0.6, 0.18),
				Color = gold,
				Material = Enum.Material.Neon,
				CFrame = top
					* CFrame.new(math.cos(angle) * 0.62, 0.55, math.sin(angle) * 0.62)
					* CFrame.Angles(0, 0, if i % 2 == 0 then 0.35 else -0.35),
			})
			spike.Name = "Spike"
		end
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = gold
		sparkles.Parent = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	end,
	RainbowCap = function(model, top)
		for index, color in RAINBOW do
			cylinder(model, 0.14, 1.4 - index * 0.13, color, top * CFrame.new(0, 0.05 + index * 0.13, 0))
		end
		part(model, {
			Size = Vector3.new(1.2, 0.1, 0.9),
			Color = RAINBOW[1],
			CFrame = top * CFrame.new(0, 0.08, -0.8),
		})
	end,
	SnowBeanie = function(model, top)
		local beanie = ball(model, Vector3.new(1.45, 1.1, 1.45), rgb(140, 190, 255), top * CFrame.new(0, 0.25, 0))
		cylinder(model, 0.3, 1.5, rgb(250, 250, 255), top * CFrame.new(0, 0.05, 0))
		ball(model, Vector3.one * 0.5, rgb(250, 250, 255), top * CFrame.new(0, 0.85, 0))
		emitter(beanie, {
			Color = ColorSequence.new(rgb(235, 245, 255)),
			Size = NumberSequence.new(0.18),
			Speed = NumberRange.new(0.5, 1),
			Acceleration = Vector3.new(0, -2, 0),
			SpreadAngle = Vector2.new(180, 180),
			Lifetime = NumberRange.new(1, 1.6),
			Rate = 6,
		})
	end,
	TornadoTopHat = function(model, top)
		local dark = rgb(70, 55, 110)
		cylinder(model, 0.12, 1.9, dark, top * CFrame.new(0, 0.06, 0))
		local tall = cylinder(model, 1.3, 1.2, dark, top * CFrame.new(0, 0.75, 0))
		cylinder(model, 0.25, 1.24, rgb(180, 140, 255), top * CFrame.new(0, 0.3, 0))
		emitter(tall, {
			Texture = "rbxasset://textures/particles/smoke_main.dds",
			Color = ColorSequence.new(rgb(230, 230, 255)),
			Transparency = NumberSequence.new(0.5, 1),
			Size = NumberSequence.new(0.4, 0.9),
			Speed = NumberRange.new(1, 2),
			RotSpeed = NumberRange.new(-200, 200),
			EmissionDirection = Enum.NormalId.Top,
			Lifetime = NumberRange.new(0.8, 1.2),
			Rate = 8,
			LightEmission = 0,
		})
	end,
	GoldenCrown = function(model, top)
		local gold = rgb(255, 200, 60)
		local band = cylinder(model, 0.45, 1.4, gold, top * CFrame.new(0, 0.2, 0))
		band.Material = Enum.Material.Foil
		for i = 1, 5 do
			local angle = i / 5 * math.pi * 2
			ball(
				model,
				Vector3.one * 0.32,
				rgb(255, 120, 170),
				top * CFrame.new(math.cos(angle) * 0.66, 0.62, math.sin(angle) * 0.66)
			).Material =
				Enum.Material.Neon
		end
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = gold
		sparkles.Parent = band
	end,
}

local BACKS: { [string]: (Model, CFrame) -> () } = {
	JarPack = function(model, back)
		local jar = cylinder(model, 1.6, 1.2, rgb(200, 235, 255), back * CFrame.new(0, 0, 0.7))
		jar.Material = Enum.Material.Glass
		jar.Transparency = 0.35
		cylinder(model, 0.25, 1.25, rgb(190, 140, 70), back * CFrame.new(0, 0.9, 0.7)).Material = Enum.Material.Metal
		local storm = ball(model, Vector3.one * 0.7, rgb(150, 190, 255), back * CFrame.new(0, 0, 0.7))
		storm.Material = Enum.Material.Neon
	end,
	CloudWings = function(model, back)
		for _, side in { -1, 1 } do
			local wing = back * CFrame.new(side * 1.3, 0.5, 0.6) * CFrame.Angles(0, side * 0.35, side * -0.3)
			ball(model, Vector3.new(2.2, 1.3, 0.6), rgb(250, 250, 255), wing)
			ball(model, Vector3.new(1.5, 0.9, 0.6), rgb(235, 240, 255), wing * CFrame.new(side * 0.7, -0.6, 0))
		end
	end,
	ButterflyWings = function(model, back)
		for _, side in { -1, 1 } do
			local base = back * CFrame.new(side * 0.4, 0.2, 0.55) * CFrame.Angles(0, side * 0.3, 0)
			local upper = ball(
				model,
				Vector3.new(1.9, 1.5, 0.12),
				rgb(255, 160, 210),
				base * CFrame.new(side * 1, 0.6, 0) * CFrame.Angles(0, 0, side * 0.4)
			)
			upper.Transparency = 0.1
			local lower = ball(
				model,
				Vector3.new(1.3, 1.1, 0.12),
				rgb(200, 170, 255),
				base * CFrame.new(side * 0.8, -0.6, 0) * CFrame.Angles(0, 0, side * -0.4)
			)
			lower.Transparency = 0.1
		end
	end,
	MiniTornado = function(model, back)
		local color = rgb(185, 180, 215)
		local core: Part? = nil
		for i = 0, 4 do
			local piece = cylinder(model, 0.4, 0.5 + i * 0.3, color, back * CFrame.new(0, -0.6 + i * 0.4, 0.9))
			piece.Transparency = 0.2
			core = core or piece
		end
		if core then
			emitter(core, {
				Texture = "rbxasset://textures/particles/smoke_main.dds",
				Color = ColorSequence.new(rgb(240, 240, 255)),
				Transparency = NumberSequence.new(0.4, 1),
				Size = NumberSequence.new(0.5, 1.2),
				Speed = NumberRange.new(1, 3),
				RotSpeed = NumberRange.new(-300, 300),
				EmissionDirection = Enum.NormalId.Top,
				Lifetime = NumberRange.new(0.7, 1),
				Rate = 10,
				LightEmission = 0,
			})
		end
	end,
	RainbowWings = function(model, back)
		for _, side in { -1, 1 } do
			for index = 1, 4 do
				local color = RAINBOW[index + 1]
				local wing = ball(
					model,
					Vector3.new(2.8 - index * 0.35, 0.5, 0.2),
					color,
					back
						* CFrame.new(side * (1.4 + index * 0.05), 0.9 - index * 0.35, 0.6)
						* CFrame.Angles(0, side * 0.3, side * (0.35 - index * 0.12))
				)
				wing.Material = Enum.Material.Neon
				wing.Transparency = 0.15
			end
		end
	end,
}

type TrailStyle = {
	colors: { Color3 },
	width: number,
	lifetime: number,
	texture: string?,
	emission: number,
}

local TRAILS: { [string]: TrailStyle } = {
	RainbowTrail = { colors = RAINBOW, width = 1, lifetime = 0.6, emission = 0.4 },
	SparkleTrail = {
		colors = { rgb(255, 230, 120), rgb(255, 255, 255) },
		width = 1,
		lifetime = 0.7,
		texture = SPARKLES,
		emission = 1,
	},
	SnowTrail = {
		colors = { rgb(220, 240, 255), rgb(170, 210, 255) },
		width = 1.2,
		lifetime = 0.8,
		texture = SPARKLES,
		emission = 0.6,
	},
	LightningTrail = { colors = { rgb(255, 250, 180), rgb(255, 210, 60) }, width = 0.4, lifetime = 0.3, emission = 1 },
	BubbleTrail = {
		colors = { rgb(200, 240, 255), rgb(255, 210, 250) },
		width = 1.3,
		lifetime = 1,
		texture = SPARKLES,
		emission = 0.3,
	},
	GalaxyTrail = {
		colors = { rgb(90, 60, 200), rgb(200, 90, 230), rgb(90, 180, 255) },
		width = 1.2,
		lifetime = 0.9,
		texture = SPARKLES,
		emission = 0.8,
	},
}

local AURAS: { [string]: (BasePart) -> () } = {
	SparkleAura = function(root)
		emitter(root, {
			Name = "CosmeticAura",
			Color = ColorSequence.new(rgb(255, 235, 140), rgb(255, 255, 255)),
			Size = NumberSequence.new(0.35, 0),
			Speed = NumberRange.new(0.5, 1.5),
			SpreadAngle = Vector2.new(180, 180),
			Lifetime = NumberRange.new(1, 1.5),
			Rate = 12,
			LightEmission = 1,
		})
	end,
	RainHalo = function(root)
		local above = Instance.new("Attachment")
		above.Name = "CosmeticAura"
		above.Position = Vector3.new(0, 3.4, 0)
		above.Parent = root
		emitter(above, {
			Color = ColorSequence.new(rgb(130, 190, 255)),
			Size = NumberSequence.new(0.15),
			EmissionDirection = Enum.NormalId.Bottom,
			SpreadAngle = Vector2.new(35, 35),
			Speed = NumberRange.new(5, 7),
			Acceleration = Vector3.new(0, -20, 0),
			Lifetime = NumberRange.new(0.35, 0.5),
			Rate = 30,
			LightEmission = 0.3,
		})
	end,
	LightningOrbit = function(root)
		emitter(root, {
			Name = "CosmeticAura",
			Color = ColorSequence.new(rgb(255, 250, 150), rgb(120, 220, 255)),
			Size = NumberSequence.new(0.3, 0),
			Speed = NumberRange.new(3, 6),
			SpreadAngle = Vector2.new(180, 180),
			RotSpeed = NumberRange.new(-400, 400),
			Lifetime = NumberRange.new(0.2, 0.4),
			Rate = 25,
			LightEmission = 1,
		})
		local light = Instance.new("PointLight")
		light.Name = "CosmeticAuraLight"
		light.Color = rgb(255, 245, 170)
		light.Range = 8
		light.Brightness = 1
		light.Parent = root
	end,
	HeartAura = function(root)
		emitter(root, {
			Name = "CosmeticAura",
			Color = ColorSequence.new(rgb(255, 130, 190), rgb(255, 200, 225)),
			Size = NumberSequence.new(0.45, 0.1),
			Speed = NumberRange.new(0.5, 1),
			Acceleration = Vector3.new(0, 3, 0),
			SpreadAngle = Vector2.new(60, 60),
			Lifetime = NumberRange.new(1.2, 1.8),
			Rate = 10,
			LightEmission = 0.8,
		})
		local light = Instance.new("PointLight")
		light.Name = "CosmeticAuraLight"
		light.Color = rgb(255, 150, 200)
		light.Range = 7
		light.Brightness = 0.8
		light.Parent = root
	end,
}

local function clearCharacter(character: Model)
	local folder = character:FindFirstChild("Cosmetics")
	if folder then
		folder:Destroy()
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		for _, child in root:GetChildren() do
			if string.sub(child.Name, 1, 8) == "Cosmetic" then
				child:Destroy()
			end
		end
	end
end

local function applyCharacter(player: Player)
	local data = DataService.get(player)
	local character = player.Character
	if not data or not character then
		return
	end
	clearCharacter(character)
	local cosmetics = data.cosmetics
	local head = character:FindFirstChild("Head") :: BasePart?
	local torso = (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) :: BasePart?
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local folder = Instance.new("Folder")
	folder.Name = "Cosmetics"
	folder.Parent = character

	local hat = cosmetics.hat and HATS[cosmetics.hat]
	if hat and head then
		local model = Instance.new("Model")
		model.Name = "Hat"
		hat(model, head.CFrame * CFrame.new(0, head.Size.Y / 2, 0))
		weldAll(model, head)
		model.Parent = folder
	end

	local back = cosmetics.back and BACKS[cosmetics.back]
	if back and torso then
		local model = Instance.new("Model")
		model.Name = "Back"
		back(model, torso.CFrame * CFrame.new(0, 0.1, torso.Size.Z / 2))
		weldAll(model, torso)
		model.Parent = folder
	end

	local trail = cosmetics.trail and TRAILS[cosmetics.trail]
	if trail and root then
		local top = Instance.new("Attachment")
		top.Name = "CosmeticTrailTop"
		top.Position = Vector3.new(0, 0.9, 0.3)
		top.Parent = root
		local bottom = Instance.new("Attachment")
		bottom.Name = "CosmeticTrailBottom"
		bottom.Position = Vector3.new(0, -0.9, 0.3)
		bottom.Parent = root
		local effect = Instance.new("Trail")
		effect.Name = "CosmeticTrail"
		effect.Attachment0 = top
		effect.Attachment1 = bottom
		effect.Color = colorSequence(trail.colors)
		effect.Lifetime = trail.lifetime
		effect.WidthScale = NumberSequence.new(trail.width, 0)
		effect.Transparency = NumberSequence.new(0.1, 1)
		effect.LightEmission = trail.emission
		effect.FaceCamera = true
		if trail.texture then
			effect.Texture = trail.texture
			effect.TextureMode = Enum.TextureMode.Wrap
			effect.TextureLength = 2
		end
		effect.Parent = root
	end

	local aura = cosmetics.aura and AURAS[cosmetics.aura]
	if aura and root then
		aura(root)
	end
end

---------------------------------------------------------------------------
-- Island cosmetics
---------------------------------------------------------------------------

type PedestalStyle = { color: Color3, material: Enum.Material, transparency: number?, rainbow: boolean? }

local PEDESTALS: { [string]: PedestalStyle } = {
	Marble = { color = rgb(235, 235, 245), material = Enum.Material.Marble },
	CandyPedestal = { color = rgb(255, 170, 205), material = Enum.Material.SmoothPlastic },
	GoldPedestal = { color = rgb(255, 200, 70), material = Enum.Material.Metal },
	CloudPedestal = { color = rgb(250, 250, 255), material = Enum.Material.SmoothPlastic },
	CrystalPedestal = { color = rgb(170, 220, 255), material = Enum.Material.Glass, transparency = 0.25 },
	RainbowPedestal = { color = rgb(255, 255, 255), material = Enum.Material.SmoothPlastic, rainbow = true },
}

-- Pedestals get rebuilt when you buy more, so this runs on a timer and only
-- changes the ones that don't match yet.
local function applyPedestals(player: Player)
	local data = DataService.get(player)
	local plot = PlotService.getPlot(player)
	if not data or not plot then
		return
	end
	local key = data.cosmetics.pedestal or "Marble"
	local style = PEDESTALS[key] or PEDESTALS.Marble
	for slot, pedestal in plot.pedestals do
		local base = pedestal.PrimaryPart
		if base and base:GetAttribute("Style") ~= key then
			base:SetAttribute("Style", key)
			base.Color = if style.rainbow then Color3.fromHSV((slot * 0.13) % 1, 0.45, 1) else style.color
			base.Material = style.material
			base.Transparency = style.transparency or 0
		end
	end
end

local function nightness(): number
	local clock = Lighting.ClockTime
	if clock >= 7 and clock <= 17 then
		return 0
	elseif clock > 17 and clock < 19 then
		return (clock - 17) / 2
	elseif clock > 5 and clock < 7 then
		return (7 - clock) / 2
	end
	return 1
end

-- Spots on the island (island space: -Z faces the Wild Skies) that stay clear
-- of the pedestals, pads, mixer, spawn and bridge.
local SPOTS = {
	lamps = { Vector3.new(-33, 0, -4), Vector3.new(33, 0, -4), Vector3.new(-33, 0, 30), Vector3.new(33, 0, 30) },
	fountain = Vector3.new(-38, 0, 14),
	statue = Vector3.new(38, 0, 14),
	arch = Vector3.new(0, 0, 48),
	fireworks = Vector3.new(36, 0, -24),
	flag = Vector3.new(-36, 0, -24),
}

local function bestStorm(data: any): StormData.StormRecord?
	local best, bestEarning = nil, -1
	for _, record in data.storms do
		local earning = StormData.incomeOf(record)
		if earning > bestEarning then
			best, bestEarning = record, earning
		end
	end
	return best
end

local DECOR: { [string]: (Instance, CFrame, any) -> () } = {
	LampPosts = function(parent, frame)
		for _, spot in SPOTS.lamps do
			local base = frame * CFrame.new(spot)
			cylinder(parent, 7, 0.45, rgb(90, 80, 120), base * CFrame.new(0, 3.5, 0))
			local lamp = ball(parent, Vector3.one * 1.4, rgb(255, 225, 150), base * CFrame.new(0, 7.4, 0))
			lamp.Material = Enum.Material.Neon
			local light = Instance.new("PointLight")
			light.Color = rgb(255, 215, 150)
			light.Range = 16
			light.Brightness = 1.4
			light.Parent = lamp
		end
	end,
	Fountain = function(parent, frame)
		local base = frame * CFrame.new(SPOTS.fountain)
		local stone = rgb(225, 220, 235)
		cylinder(parent, 1.2, 9, stone, base * CFrame.new(0, 0.6, 0))
		local water = cylinder(parent, 0.2, 8, rgb(120, 190, 255), base * CFrame.new(0, 1.15, 0))
		water.Transparency = 0.3
		cylinder(parent, 3, 1.2, stone, base * CFrame.new(0, 2.5, 0))
		cylinder(parent, 0.6, 3.4, stone, base * CFrame.new(0, 4.1, 0))
		local spout = ball(parent, Vector3.one * 0.8, rgb(150, 210, 255), base * CFrame.new(0, 4.6, 0))
		spout.Transparency = 0.4
		emitter(spout, {
			Color = ColorSequence.new(rgb(150, 210, 255), rgb(230, 245, 255)),
			Size = NumberSequence.new(0.35, 0.15),
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(25, 25),
			Speed = NumberRange.new(9, 12),
			Acceleration = Vector3.new(0, -30, 0),
			Lifetime = NumberRange.new(0.7, 0.9),
			Rate = 40,
			LightEmission = 0.2,
		})
	end,
	RainbowArch = function(parent, frame)
		local base = frame * CFrame.new(SPOTS.arch)
		for band, color in RAINBOW do
			local radius = 16 - band * 0.9
			for i = 0, 16 do
				local angle = i / 16 * math.pi
				local piece = ball(
					parent,
					Vector3.one * 1.1,
					color,
					base * CFrame.new(math.cos(angle) * radius, math.sin(angle) * radius, 0)
				)
				piece.Material = Enum.Material.Neon
				piece.Transparency = 0.1
			end
		end
	end,
	StormStatue = function(parent, frame, data)
		local base = frame * CFrame.new(SPOTS.statue)
		part(parent, {
			Size = Vector3.new(6, 2, 6),
			Color = rgb(235, 230, 245),
			Material = Enum.Material.Marble,
			CFrame = base * CFrame.new(0, 1, 0),
		})
		local record = bestStorm(data)
		local def = record and StormData.get(record.id)
		if not def then
			return
		end
		local statue = StormModel.build(def, { scale = 2.2 })
		CollectionService:RemoveTag(statue, "StormCreature") -- statues don't wiggle
		for _, item in statue:GetDescendants() do
			if item:IsA("BasePart") then
				if item.Transparency < 1 then
					item.Color = rgb(255, 205, 80)
					item.Material = Enum.Material.Metal
				end
			elseif item:IsA("ParticleEmitter") or item:IsA("Light") then
				item:Destroy()
			end
		end
		statue:PivotTo(base * CFrame.new(0, 2 + 3.5 * StormData.rarityOf(def).scale, 0) * CFrame.Angles(0, math.pi, 0))
		statue:SetAttribute("StatueOf", def.id)
		statue.Parent = parent
	end,
	Fireworks = function(parent, frame)
		local base = frame * CFrame.new(SPOTS.fireworks)
		part(parent, {
			Size = Vector3.new(3, 1, 3),
			Color = rgb(90, 80, 120),
			CFrame = base * CFrame.new(0, 0.5, 0),
		})
		for i = 1, 3 do
			local tube = cylinder(parent, 2.2, 0.7, RAINBOW[i * 2], base * CFrame.new((i - 2) * 0.9, 2, 0))
			tube.CFrame *= CFrame.Angles(0, 0, math.rad((i - 2) * 10))
		end
	end,
}

type FlagStyle = { color: Color3, emoji: string, rainbow: boolean?, material: Enum.Material? }

local FLAGS: { [string]: FlagStyle } = {
	StormFlag = { color = rgb(95, 105, 160), emoji = "⛈️" },
	LightningFlag = { color = rgb(255, 210, 70), emoji = "⚡" },
	RainbowFlag = { color = rgb(255, 255, 255), emoji = "🌈", rainbow = true },
	PirateFlag = { color = rgb(45, 40, 60), emoji = "☠️" },
	GoldenFlag = { color = rgb(255, 205, 70), emoji = "✨", material = Enum.Material.Foil },
}

local function buildFlag(parent: Instance, frame: CFrame, style: FlagStyle)
	local base = frame * CFrame.new(SPOTS.flag)
	cylinder(parent, 14, 0.4, rgb(235, 230, 245), base * CFrame.new(0, 7, 0))
	ball(parent, Vector3.one * 0.7, rgb(255, 215, 90), base * CFrame.new(0, 14.2, 0))
	local cloth = part(parent, {
		Size = Vector3.new(4.5, 2.8, 0.15),
		Color = style.color,
		Material = style.material or Enum.Material.Fabric,
		CFrame = base * CFrame.new(2.4, 12.3, 0),
	})
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.CanvasSize = Vector2.new(200, 125)
		gui.LightInfluence = 0.3
		gui.Parent = cloth
		if style.rainbow then
			local back = Instance.new("Frame")
			back.Size = UDim2.fromScale(1, 1)
			back.BorderSizePixel = 0
			back.BackgroundColor3 = Color3.new(1, 1, 1)
			back.Parent = gui
			local gradient = Instance.new("UIGradient")
			gradient.Rotation = 90
			gradient.Color = colorSequence(RAINBOW)
			gradient.Parent = back
		end
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.TextScaled = true
		label.Text = style.emoji
		label.Parent = gui
	end
end

-- Island pets: little critters built from balls that wander around.
type PetStyle = { build: (Model, Part) -> (), speed: number, height: number, hop: boolean? }

local function eyes(model: Model, root: Part, forward: number, up: number, spread: number)
	for _, side in { -1, 1 } do
		ball(model, Vector3.one * 0.22, rgb(40, 30, 60), root.CFrame * CFrame.new(side * spread, up, -forward))
	end
end

local PETS: { [string]: PetStyle } = {
	Ducks = {
		speed = 4,
		height = 0.8,
		build = function(model, root)
			root.Size = Vector3.one * 1.6
			root.Color = rgb(255, 225, 90)
			ball(model, Vector3.one * 1.1, rgb(255, 225, 90), root.CFrame * CFrame.new(0, 0.9, -0.6))
			part(model, {
				Size = Vector3.new(0.5, 0.2, 0.5),
				Color = rgb(255, 150, 60),
				CFrame = root.CFrame * CFrame.new(0, 0.85, -1.25),
			})
			eyes(model, root, 1.05, 1.05, 0.28)
		end,
	},
	Bunnies = {
		speed = 5,
		height = 0.8,
		hop = true,
		build = function(model, root)
			root.Size = Vector3.one * 1.6
			root.Color = rgb(250, 250, 255)
			ball(model, Vector3.one * 1.2, rgb(250, 250, 255), root.CFrame * CFrame.new(0, 0.9, -0.5))
			for _, side in { -1, 1 } do
				ball(
					model,
					Vector3.new(0.35, 1.2, 0.25),
					rgb(255, 200, 220),
					root.CFrame * CFrame.new(side * 0.3, 1.9, -0.4)
				)
			end
			ball(model, Vector3.one * 0.5, rgb(255, 255, 255), root.CFrame * CFrame.new(0, 0.1, 0.8))
			eyes(model, root, 1.05, 1.05, 0.28)
		end,
	},
	CloudSheep = {
		speed = 3,
		height = 1.4,
		build = function(model, root)
			root.Size = Vector3.one * 2
			root.Color = rgb(250, 250, 255)
			for _, offset in
				{
					Vector3.new(0.8, 0.3, 0),
					Vector3.new(-0.8, 0.3, 0),
					Vector3.new(0, 0.5, 0.7),
					Vector3.new(0, 0.5, -0.6),
				}
			do
				ball(model, Vector3.one * 1.4, rgb(245, 245, 255), root.CFrame + offset)
			end
			ball(model, Vector3.one * 0.9, rgb(90, 80, 110), root.CFrame * CFrame.new(0, 0.5, -1.4))
			for _, x in { -0.6, 0.6 } do
				for _, z in { -0.6, 0.6 } do
					part(model, {
						Size = Vector3.new(0.3, 0.9, 0.3),
						Color = rgb(90, 80, 110),
						CFrame = root.CFrame * CFrame.new(x, -1, z),
					})
				end
			end
			for _, side in { -1, 1 } do
				ball(model, Vector3.one * 0.18, rgb(255, 255, 255), root.CFrame * CFrame.new(side * 0.2, 0.6, -1.8))
			end
		end,
	},
	StormDragon = {
		speed = 8,
		height = 10,
		build = function(model, root)
			local purple = rgb(150, 110, 230)
			root.Size = Vector3.new(1.8, 1.8, 1.8)
			root.Color = purple
			ball(model, Vector3.new(1.4, 1.4, 1.6), purple, root.CFrame * CFrame.new(0, 0.8, -1.4))
			ball(model, Vector3.new(0.8, 0.8, 1.8), purple, root.CFrame * CFrame.new(0, -0.1, 1.5))
			for _, side in { -1, 1 } do
				local wing = ball(
					model,
					Vector3.new(2.6, 0.2, 1.4),
					rgb(200, 170, 255),
					root.CFrame * CFrame.new(side * 1.8, 0.6, 0) * CFrame.Angles(0, 0, side * 0.35)
				)
				wing.Transparency = 0.1
				ball(
					model,
					Vector3.new(0.25, 0.6, 0.25),
					rgb(255, 225, 120),
					root.CFrame * CFrame.new(side * 0.35, 1.7, -1.3)
				)
			end
			eyes(model, root, 2.1, 1, 0.35)
			emitter(root, {
				Color = ColorSequence.new(rgb(255, 240, 150)),
				Size = NumberSequence.new(0.3, 0),
				Speed = NumberRange.new(0.5, 1),
				SpreadAngle = Vector2.new(180, 180),
				Lifetime = NumberRange.new(0.6, 1),
				Rate = 6,
				LightEmission = 1,
			})
		end,
	},
}

local function spawnPet(parent: Instance, frame: CFrame, style: PetStyle)
	local model = Instance.new("Model")
	model.Name = "IslandPet"
	local root = part(model, { Name = "Root", Shape = Enum.PartType.Ball, Anchored = true })
	local function spot(): Vector3
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(8, 40)
		return frame:PointToWorldSpace(Vector3.new(math.cos(angle) * radius, style.height, math.sin(angle) * radius))
	end
	root.CFrame = CFrame.new(spot())
	style.build(model, root)
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") and item ~= root then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = item
			weld.Parent = item
		end
	end
	model.PrimaryPart = root
	model.Parent = parent

	task.spawn(function()
		while model.Parent do
			task.wait(rng:NextNumber(1.5, 4))
			if not model.Parent then
				break
			end
			local from = root.Position
			local goal = spot()
			local flat = Vector3.new(goal.X - from.X, 0, goal.Z - from.Z)
			if flat.Magnitude < 1 then
				continue
			end
			local facing = CFrame.lookAt(from, from + flat)
			root.CFrame = facing
			if style.hop then
				-- Bunnies hop in short bounces.
				local hops = math.ceil(flat.Magnitude / 3)
				for i = 1, hops do
					if not model.Parent then
						break
					end
					local stepTo = from:Lerp(goal, i / hops)
					local mid = from:Lerp(goal, (i - 0.5) / hops) + Vector3.new(0, 1.5, 0)
					local up = TweenService:Create(root, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
						CFrame = facing.Rotation + mid,
					})
					up:Play()
					up.Completed:Wait()
					local down = TweenService:Create(
						root,
						TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
						{ CFrame = facing.Rotation + stepTo }
					)
					down:Play()
					down.Completed:Wait()
				end
			else
				local tween = TweenService:Create(
					root,
					TweenInfo.new(flat.Magnitude / style.speed, Enum.EasingStyle.Sine),
					{ CFrame = facing.Rotation + goal }
				)
				tween:Play()
				tween.Completed:Wait()
			end
		end
	end)
end

local function applySign(player: Player, data: any)
	local plot = PlotService.getPlot(player)
	if not plot then
		return
	end
	local gui = plot.sign.Parent
	local board = gui and gui.Parent
	if board and board:IsA("BasePart") then
		board.Color = CosmeticsData.SignColors[data.cosmetics.signColor or 1] or CosmeticsData.SignColors[1]
		signBoards[player] = board
	end
	plot.sign.Text = (data.cosmetics.signEmoji or "🏝️") .. " " .. player.DisplayName .. "'s Island"
end

local function applyIsland(player: Player)
	local data = DataService.get(player)
	local plot = PlotService.getPlot(player)
	if not data or not plot then
		return
	end
	local old = plot.model:FindFirstChild("IslandCosmetics")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "IslandCosmetics"
	local cosmetics = data.cosmetics
	for id in cosmetics.decor do
		local build = DECOR[id]
		if build then
			local group = Instance.new("Model")
			group.Name = id
			build(group, plot.cframe, data)
			anchorAll(group)
			group.Parent = folder
		end
	end
	local flag = cosmetics.flag and FLAGS[cosmetics.flag]
	if flag then
		local group = Instance.new("Model")
		group.Name = "Flag"
		buildFlag(group, plot.cframe, flag)
		anchorAll(group)
		group.Parent = folder
	end
	folder.Parent = plot.model
	for id in cosmetics.pets do
		local style = PETS[id]
		if style then
			for _ = 1, 2 do
				spawnPet(folder, plot.cframe, style)
			end
		end
	end
	fireworkIslands[player] = if cosmetics.decor.Fireworks then plot.cframe else nil
	applySign(player, data)
	applyPedestals(player)
end

---------------------------------------------------------------------------
-- Buying and equipping
---------------------------------------------------------------------------

local function publish(player: Player, data: any)
	local cosmetics = data.cosmetics
	local owned, decor, pets = {}, {}, {}
	for id in cosmetics.owned do
		table.insert(owned, id)
	end
	for id in cosmetics.decor do
		table.insert(decor, id)
	end
	for id in cosmetics.pets do
		table.insert(pets, id)
	end
	player:SetAttribute(
		"Cosmetics",
		HttpService:JSONEncode({
			owned = owned,
			hat = cosmetics.hat,
			trail = cosmetics.trail,
			back = cosmetics.back,
			aura = cosmetics.aura,
			pedestal = cosmetics.pedestal,
			flag = cosmetics.flag,
			decor = decor,
			pets = pets,
			signColor = cosmetics.signColor,
			signEmoji = cosmetics.signEmoji,
		})
	)
end

local function refreshFor(player: Player, data: any, category: string)
	publish(player, data)
	local info = CosmeticsData.category(category)
	if info and info.island then
		applyIsland(player)
	else
		applyCharacter(player)
	end
end

-- Puts on (or places) an owned cosmetic. Returns a message.
local function equip(data: any, item: CosmeticsData.Item): (boolean, string)
	local cosmetics = data.cosmetics
	if item.category == "decor" then
		if cosmetics.decor[item.id] then
			cosmetics.decor[item.id] = nil
			return true, item.emoji .. " " .. item.name .. " put away."
		end
		cosmetics.decor[item.id] = true
		return true, item.emoji .. " " .. item.name .. " placed on your island!"
	elseif item.category == "pet" then
		if cosmetics.pets[item.id] then
			cosmetics.pets[item.id] = nil
			return true, item.emoji .. " " .. item.name .. " went home."
		end
		local count = 0
		for _ in cosmetics.pets do
			count += 1
		end
		local max = (CosmeticsData.category("pet") :: CosmeticsData.Category).max or 3
		if count >= max then
			return false, "Your island has room for " .. max .. " kinds of pets. Send one home first."
		end
		cosmetics.pets[item.id] = true
		return true, item.emoji .. " " .. item.name .. " moved onto your island!"
	end
	cosmetics[item.category] = item.id
	return true, item.emoji .. " " .. item.name .. " on!"
end

-- Unlocks a cosmetic (Sparks purchase or Robux product) and puts it on.
local function unlock(player: Player, data: any, item: CosmeticsData.Item): string
	data.cosmetics.owned[item.id] = true
	local _, message = equip(data, item)
	refreshFor(player, data, item.category)
	return message
end

local function onAction(player: Player, action: any, a: any): (boolean, string)
	local data = DataService.get(player)
	if not data or os.clock() - (lastRequest[player] or 0) < 0.25 then
		return false, "Slow down!"
	end
	lastRequest[player] = os.clock()
	local cosmetics = data.cosmetics

	if action == "signColor" then
		if type(a) ~= "number" or not CosmeticsData.SignColors[a] then
			return false, "Unknown color."
		end
		cosmetics.signColor = a
		publish(player, data)
		applySign(player, data)
		return true, "🎨 Sign color changed!"
	elseif action == "signEmoji" then
		if type(a) ~= "string" or not table.find(CosmeticsData.SignEmoji, a) then
			return false, "Unknown emoji."
		end
		cosmetics.signEmoji = a
		publish(player, data)
		applySign(player, data)
		return true, a .. " Sign updated!"
	elseif action == "unequip" then
		if type(a) ~= "string" or not CosmeticsData.category(a) then
			return false, "Can't do that."
		end
		if a == "pedestal" then
			cosmetics.pedestal = "Marble"
		elseif a ~= "decor" and a ~= "pet" then
			cosmetics[a] = nil
		end
		refreshFor(player, data, a)
		return true, "Taken off."
	end

	local item = type(a) == "string" and CosmeticsData.get(a)
	if not item then
		return false, "Unknown item."
	end
	if action == "buy" then
		if cosmetics.owned[item.id] then
			return false, "You already own that!"
		end
		if item.robux then
			return false, "That one is bought with Robux."
		end
		if data.sparks < item.cost then
			return false, "You need ⚡" .. Format.number(item.cost - data.sparks) .. " more Sparks."
		end
		data.sparks -= item.cost
		IncomeService.sync(player)
		return true, "🎉 Bought! " .. unlock(player, data, item)
	elseif action == "equip" then
		if not cosmetics.owned[item.id] and (item.cost > 0 or item.robux) then
			return false, "You don't own that yet."
		end
		local ok, message = equip(data, item)
		if ok then
			refreshFor(player, data, item.category)
		end
		return ok, message
	end
	return false, "Can't do that."
end

-- Called by MonetizationService when a Robux cosmetic is bought.
function CosmeticService.grantProduct(player: Player, productKey: string): boolean
	local data = DataService.get(player)
	local item = CosmeticsData.get(string.sub(productKey, #"Cosmetic_" + 1))
	if not data or not item then
		return false
	end
	unlock(player, data, item)
	return true
end

-- Launches a firework over every island that has Fireworks, at night.
local function fireworksLoop()
	while true do
		task.wait(rng:NextNumber(4, 8))
		if nightness() < 0.6 then
			continue
		end
		for player, frame in fireworkIslands do
			if not player.Parent then
				fireworkIslands[player] = nil
				continue
			end
			local from = frame:PointToWorldSpace(SPOTS.fireworks + Vector3.new(0, 3, 0))
			local to = from + Vector3.new(rng:NextNumber(-10, 10), rng:NextNumber(30, 45), rng:NextNumber(-10, 10))
			local rocket = Instance.new("Part")
			rocket.Shape = Enum.PartType.Ball
			rocket.Size = Vector3.one * 0.8
			rocket.Material = Enum.Material.Neon
			rocket.Color = RAINBOW[rng:NextInteger(1, #RAINBOW)]
			rocket.Anchored = true
			rocket.CanCollide = false
			rocket.CanTouch = false
			rocket.CanQuery = false
			rocket.CFrame = CFrame.new(from)
			rocket.Parent = workspace
			local flight = TweenService:Create(
				rocket,
				TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ CFrame = CFrame.new(to) }
			)
			flight.Completed:Connect(function()
				rocket:Destroy()
				Effects.confetti(to, 90)
			end)
			flight:Play()
		end
	end
end

function CosmeticService.start()
	Remotes.func("Cosmetic").OnServerInvoke = onAction

	DataService.ProfileLoaded:Connect(function(player, data)
		publish(player, data)
		applyCharacter(player)
	end)
	PlotService.PlotAssigned:Connect(applyIsland)

	local function onPlayer(player: Player)
		player.CharacterAppearanceLoaded:Connect(function()
			applyCharacter(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
		fireworkIslands[player] = nil
		local plot = PlotService.getPlot(player)
		local folder = plot and plot.model:FindFirstChild("IslandCosmetics")
		if folder then
			folder:Destroy()
		end
		local board = signBoards[player]
		signBoards[player] = nil
		if board then
			board.Color = CosmeticsData.SignColors[1]
		end
	end)

	task.spawn(fireworksLoop)

	-- Keep pedestal styles on new pedestals, and the statue on your best storm.
	task.spawn(function()
		local tick = 0
		while true do
			task.wait(2)
			tick += 1
			for _, player in Players:GetPlayers() do
				applyPedestals(player)
				local data = DataService.get(player)
				local plot = PlotService.getPlot(player)
				if tick % 15 == 0 and data and plot and data.cosmetics.decor.StormStatue then
					local record = bestStorm(data)
					local folder = plot.model:FindFirstChild("IslandCosmetics")
					local group = folder and folder:FindFirstChild("StormStatue")
					local statue = group and group:FindFirstChildWhichIsA("Model")
					local shown = statue and statue:GetAttribute("StatueOf")
					if record and shown ~= record.id then
						applyIsland(player)
					end
				end
			end
		end
	end)
end

return CosmeticService
