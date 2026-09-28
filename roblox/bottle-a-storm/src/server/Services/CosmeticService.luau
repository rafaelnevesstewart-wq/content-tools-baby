-- Cosmetics (see CosmeticsData): buying and equipping them, and building
-- them from parts.
--   Character: a hat, a trail, something on your back and an aura.
--   Match: your team's cloud bed skin, and the knockout effect that bursts
--   out when you knock someone out (MatchService calls dressBed and
--   knockout). Sword skins and arrow effects are applied by CombatService.
-- Everything is built on the server so every player sees it.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local CosmeticsData = require(Shared.CosmeticsData)
local Format = require(Shared.Format)
local PetLevels = require(Shared.PetLevels)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Signal)

local Modules = script.Parent.Parent.Modules
local Effects = require(Modules.Effects)
local PetModels = require(Modules.PetModels)

local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)

local CosmeticService = {}

-- (player, category) after a cosmetic is put on or taken off. CombatService
-- listens for "sword" to reskin the sword you're holding.
CosmeticService.Changed = Signal.new()

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

-- Flashy hats (added to HATS below).
HATS.InfernoCrown = function(model, top)
	local band = cylinder(model, 0.45, 1.4, rgb(30, 26, 30), top * CFrame.new(0, 0.2, 0))
	band.Material = Enum.Material.Basalt
	for i = 1, 6 do
		local angle = i / 6 * math.pi * 2
		local spike = part(model, {
			Size = Vector3.new(0.2, 0.7, 0.2),
			Color = rgb(255, 120, 40),
			Material = Enum.Material.Neon,
			CFrame = top * CFrame.new(math.cos(angle) * 0.62, 0.65, math.sin(angle) * 0.62),
		})
		spike.Name = "Spike"
	end
	local fire = Instance.new("Fire")
	fire.Size = 3
	fire.Heat = 8
	fire.Color = rgb(255, 150, 50)
	fire.SecondaryColor = rgb(255, 60, 20)
	fire.Parent = band
	local light = Instance.new("PointLight")
	light.Color = rgb(255, 140, 60)
	light.Range = 10
	light.Brightness = 1.5
	light.Parent = band
end

HATS.StormHalo = function(model, top)
	local ring = part(model, {
		Size = Vector3.one * 0.2,
		Transparency = 1,
		CFrame = top * CFrame.new(0, 1.3, 0),
	})
	ring:SetAttribute("SpinRing", 2.5)
	for i = 1, 12 do
		local angle = i / 12 * math.pi * 2
		local orb = ball(
			model,
			Vector3.one * 0.32,
			rgb(170, 220, 255),
			top * CFrame.new(math.cos(angle) * 1, 1.3, math.sin(angle) * 1),
			Enum.Material.Neon
		)
		orb:SetAttribute("OnRing", true)
	end
	local light = Instance.new("PointLight")
	light.Color = rgb(170, 220, 255)
	light.Range = 10
	light.Brightness = 1.5
	light.Parent = ring
	model:SetAttribute("Bolts", rgb(190, 230, 255))
end

local BACKS: { [string]: (Model, CFrame) -> () } = {
	ArrowQuiver = function(model, back)
		local tilt = back * CFrame.new(0.3, 0, 0.6) * CFrame.Angles(0, 0, math.rad(-20))
		local quiver = cylinder(model, 2.2, 0.8, rgb(110, 70, 40), tilt)
		quiver.Material = Enum.Material.Leather
		cylinder(model, 0.15, 0.85, rgb(200, 160, 70), tilt * CFrame.new(0, 1.05, 0)).Material = Enum.Material.Metal
		for i = 0, 2 do
			local shaft = cylinder(model, 1, 0.08, rgb(150, 110, 70), tilt * CFrame.new((i - 1) * 0.2, 1.5, 0))
			shaft.Material = Enum.Material.Wood
			local tip =
				ball(model, Vector3.new(0.2, 0.35, 0.2), rgb(140, 220, 255), tilt * CFrame.new((i - 1) * 0.2, 2.05, 0))
			tip.Material = Enum.Material.Neon
		end
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

-- Trails have a bright core, an optional wide soft glow behind it, and
-- optional particles (flames, petals, stars...) that fall off as you move.
-- Flashy backs.
BACKS.PhoenixWings = function(model, back)
	for _, side in { -1, 1 } do
		for index = 1, 3 do
			local feather = ball(
				model,
				Vector3.new(3 - index * 0.5, 0.45, 0.2),
				({ rgb(255, 200, 70), rgb(255, 130, 40), rgb(220, 50, 20) })[index],
				back
					* CFrame.new(side * (1.5 + index * 0.1), 1 - index * 0.4, 0.6)
					* CFrame.Angles(0, side * 0.3, side * (0.45 - index * 0.15))
			)
			feather.Material = Enum.Material.Neon
			if index == 1 then
				local fire = Instance.new("Fire")
				fire.Size = 3
				fire.Heat = 6
				fire.Color = rgb(255, 170, 60)
				fire.SecondaryColor = rgb(255, 70, 20)
				fire.Parent = feather
			end
		end
	end
end

BACKS.LightningWings = function(model, back)
	for _, side in { -1, 1 } do
		for index = 1, 3 do
			local bolt = part(model, {
				Size = Vector3.new(2.6 - index * 0.4, 0.25, 0.15),
				Color = rgb(170, 220, 255),
				Material = Enum.Material.Neon,
				CFrame = back
					* CFrame.new(side * (1.4 + index * 0.1), 1 - index * 0.45, 0.6)
					* CFrame.Angles(0, side * 0.3, side * (0.5 - index * 0.2)),
			})
			bolt.Name = "WingBolt"
		end
	end
	model:SetAttribute("Bolts", rgb(170, 220, 255))
end

type ParticleStyle = {
	texture: string,
	colors: { Color3 },
	size: number,
	rate: number,
	lifetime: number,
	speed: number,
	accel: Vector3?,
	spin: number?,
	emission: number?,
	transparency: number?,
}

type TrailStyle = {
	colors: { Color3 },
	width: number,
	lifetime: number,
	texture: string?,
	emission: number,
	glow: { colors: { Color3 }?, width: number, lifetime: number }?,
	particles: ParticleStyle?,
	light: Color3?,
}

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SOFT = "rbxasset://textures/particles/forcefield_glow_main.dds"

local TRAILS: { [string]: TrailStyle } = {
	RainbowTrail = {
		colors = RAINBOW,
		width = 1.1,
		lifetime = 0.7,
		emission = 0.5,
		glow = { width = 2.4, lifetime = 0.45 },
	},
	SparkleTrail = {
		colors = { rgb(255, 225, 120), rgb(255, 255, 255) },
		width = 0.9,
		lifetime = 0.6,
		texture = SPARKLES,
		emission = 1,
		particles = {
			texture = SPARKLES,
			colors = { rgb(255, 225, 120) },
			size = 0.35,
			rate = 18,
			lifetime = 0.8,
			speed = 1,
			accel = Vector3.new(0, -6, 0),
			emission = 1,
		},
	},
	SnowTrail = {
		colors = { rgb(225, 240, 255), rgb(160, 200, 255) },
		width = 1.2,
		lifetime = 0.8,
		texture = SPARKLES,
		emission = 0.6,
		particles = {
			texture = SPARKLES,
			colors = { rgb(255, 255, 255) },
			size = 0.3,
			rate = 14,
			lifetime = 1.4,
			speed = 0.5,
			accel = Vector3.new(0, -3, 0),
			spin = 60,
		},
	},
	LightningTrail = {
		colors = { rgb(255, 255, 220), rgb(255, 220, 80) },
		width = 0.35,
		lifetime = 0.3,
		emission = 1,
		glow = { colors = { rgb(120, 170, 255) }, width = 1.6, lifetime = 0.2 },
		particles = {
			texture = SPARKLES,
			colors = { rgb(255, 250, 170), rgb(150, 200, 255) },
			size = 0.4,
			rate = 20,
			lifetime = 0.2,
			speed = 6,
			emission = 1,
		},
		light = rgb(255, 240, 160),
	},
	BubbleTrail = {
		colors = { rgb(200, 240, 255), rgb(255, 210, 250) },
		width = 1,
		lifetime = 0.9,
		emission = 0.3,
		particles = {
			texture = SOFT,
			colors = { rgb(210, 240, 255), rgb(255, 215, 245) },
			size = 0.6,
			rate = 8,
			lifetime = 2,
			speed = 1,
			accel = Vector3.new(0, 1.5, 0),
			transparency = 0.4,
		},
	},
	GalaxyTrail = {
		colors = { rgb(70, 40, 170), rgb(190, 80, 220), rgb(80, 170, 255) },
		width = 1.3,
		lifetime = 0.9,
		texture = SPARKLES,
		emission = 0.8,
		glow = { width = 2.6, lifetime = 0.5 },
		particles = {
			texture = SPARKLES,
			colors = { rgb(255, 255, 255), rgb(180, 200, 255) },
			size = 0.3,
			rate = 16,
			lifetime = 1.2,
			speed = 0.5,
			emission = 1,
		},
	},
	FireTrail = {
		colors = { rgb(255, 220, 120), rgb(255, 120, 40), rgb(200, 40, 20) },
		width = 1.2,
		lifetime = 0.5,
		emission = 1,
		particles = {
			texture = FIRE,
			colors = { rgb(255, 190, 80), rgb(255, 80, 30) },
			size = 1.1,
			rate = 30,
			lifetime = 0.6,
			speed = 2,
			accel = Vector3.new(0, 6, 0),
			spin = 90,
			emission = 1,
		},
		light = rgb(255, 150, 60),
	},
	SakuraTrail = {
		colors = { rgb(255, 200, 220), rgb(255, 150, 190) },
		width = 0.7,
		lifetime = 0.6,
		emission = 0.3,
		particles = {
			texture = SPARKLES,
			colors = { rgb(255, 180, 210), rgb(255, 230, 240) },
			size = 0.4,
			rate = 12,
			lifetime = 2,
			speed = 1,
			accel = Vector3.new(0, -1.5, 0),
			spin = 180,
		},
	},
	TornadoTrail = {
		colors = { rgb(200, 205, 215), rgb(140, 145, 160) },
		width = 1.4,
		lifetime = 0.6,
		texture = SMOKE,
		emission = 0,
		particles = {
			texture = SMOKE,
			colors = { rgb(210, 215, 225) },
			size = 1.6,
			rate = 14,
			lifetime = 1,
			speed = 2,
			spin = 300,
			transparency = 0.5,
		},
	},
	AuroraTrail = {
		colors = { rgb(80, 255, 160), rgb(60, 200, 220), rgb(170, 90, 255) },
		width = 2.2,
		lifetime = 1.1,
		emission = 1,
		glow = { width = 4, lifetime = 0.8 },
	},
	ShadowTrail = {
		colors = { rgb(30, 20, 45), rgb(110, 50, 170) },
		width = 1.3,
		lifetime = 0.7,
		texture = SMOKE,
		emission = 0,
		particles = {
			texture = SMOKE,
			colors = { rgb(25, 18, 35), rgb(90, 40, 140) },
			size = 1.3,
			rate = 16,
			lifetime = 0.9,
			speed = 1,
			spin = 120,
			transparency = 0.3,
		},
	},
	PlasmaTrail = {
		colors = { rgb(220, 255, 255), rgb(60, 220, 255) },
		width = 0.6,
		lifetime = 0.45,
		emission = 1,
		glow = { colors = { rgb(40, 160, 255) }, width = 2.2, lifetime = 0.35 },
		particles = {
			texture = SPARKLES,
			colors = { rgb(120, 240, 255) },
			size = 0.35,
			rate = 18,
			lifetime = 0.4,
			speed = 4,
			emission = 1,
		},
		light = rgb(80, 220, 255),
	},
	StarfallTrail = {
		colors = { rgb(255, 245, 200), rgb(255, 200, 80) },
		width = 1,
		lifetime = 0.8,
		texture = SPARKLES,
		emission = 1,
		glow = { width = 2.4, lifetime = 0.5 },
		particles = {
			texture = SPARKLES,
			colors = { rgb(255, 235, 150), rgb(255, 255, 255) },
			size = 0.7,
			rate = 14,
			lifetime = 1.6,
			speed = 2,
			accel = Vector3.new(0, -8, 0),
			spin = 120,
			emission = 1,
		},
		light = rgb(255, 225, 140),
	},
	ThunderstormTrail = {
		colors = { rgb(90, 95, 110), rgb(40, 42, 55) },
		width = 1.6,
		lifetime = 0.8,
		texture = SMOKE,
		emission = 0,
		particles = {
			texture = SPARKLES,
			colors = { rgb(255, 250, 170), rgb(170, 210, 255) },
			size = 0.6,
			rate = 14,
			lifetime = 0.25,
			speed = 8,
			emission = 1,
		},
		light = rgb(200, 220, 255),
	},
	PhoenixTrail = {
		colors = { rgb(255, 240, 150), rgb(255, 150, 40), rgb(220, 50, 20) },
		width = 2.2,
		lifetime = 0.8,
		emission = 1,
		glow = { colors = { rgb(255, 180, 60) }, width = 4, lifetime = 0.5 },
		particles = {
			texture = FIRE,
			colors = { rgb(255, 210, 90), rgb(255, 90, 30) },
			size = 1.6,
			rate = 36,
			lifetime = 0.7,
			speed = 3,
			accel = Vector3.new(0, 8, 0),
			spin = 120,
			emission = 1,
		},
		light = rgb(255, 170, 70),
	},

	-- Battle pass trails.
	AutumnLeavesTrail = {
		colors = { rgb(255, 170, 60), rgb(200, 80, 30) },
		width = 1.4,
		lifetime = 0.6,
		emission = 0.3,
		particles = {
			texture = SPARKLES,
			colors = { rgb(255, 150, 40), rgb(220, 90, 30), rgb(250, 200, 70) },
			size = 0.6,
			rate = 18,
			lifetime = 1.4,
			speed = 2,
			accel = Vector3.new(0, -3, 0),
			spin = 180,
		},
	},
	CandyCaneTrail = {
		colors = { rgb(255, 255, 255), rgb(230, 40, 60), rgb(255, 255, 255), rgb(230, 40, 60) },
		width = 1.3,
		lifetime = 0.6,
		emission = 0.4,
		particles = {
			texture = SPARKLES,
			colors = { rgb(255, 255, 255) },
			size = 0.3,
			rate = 14,
			lifetime = 1,
			speed = 1,
			accel = Vector3.new(0, -3, 0),
			emission = 1,
		},
	},
	PetalTrail = {
		colors = { rgb(255, 190, 215), rgb(255, 140, 190) },
		width = 1.2,
		lifetime = 0.6,
		emission = 0.3,
		particles = {
			texture = SPARKLES,
			colors = { rgb(255, 170, 200), rgb(255, 230, 240) },
			size = 0.5,
			rate = 18,
			lifetime = 1.6,
			speed = 1.5,
			accel = Vector3.new(0, -2, 0),
			spin = 160,
		},
	},
	ChampionTrail = {
		colors = { rgb(255, 215, 90), rgb(190, 110, 255), rgb(255, 215, 90) },
		width = 1.8,
		lifetime = 0.8,
		emission = 1,
		glow = { colors = { rgb(255, 200, 120) }, width = 3.6, lifetime = 0.5 },
		particles = {
			texture = SPARKLES,
			colors = { rgb(255, 230, 140), rgb(210, 160, 255) },
			size = 0.45,
			rate = 20,
			lifetime = 0.9,
			speed = 2,
			emission = 1,
		},
		light = rgb(255, 210, 120),
	},
	SunbeamTrail = {
		colors = { rgb(255, 245, 170), rgb(255, 200, 60) },
		width = 1.6,
		lifetime = 0.7,
		emission = 1,
		glow = { colors = { rgb(255, 220, 100) }, width = 3.4, lifetime = 0.45 },
		light = rgb(255, 220, 120),
	},
}

-- Each aura's main color (the glowing halo on the ground under you).
local AURA_COLORS: { [string]: Color3 } = {
	SparkleAura = rgb(255, 235, 140),
	RainHalo = rgb(140, 190, 255),
	LightningOrbit = rgb(255, 240, 120),
	HeartAura = rgb(255, 120, 170),
	RainbowAura = rgb(220, 160, 255),
	InfernoAura = rgb(255, 120, 40),
	ThunderGodAura = rgb(190, 220, 255),
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

-- Flashy auras.
AURAS.RainbowAura = function(root)
	emitter(root, {
		Name = "CosmeticAura",
		Color = colorSequence(RAINBOW),
		Size = NumberSequence.new(0.45, 0),
		Speed = NumberRange.new(1, 2),
		SpreadAngle = Vector2.new(180, 180),
		Lifetime = NumberRange.new(1, 1.6),
		Rate = 30,
		LightEmission = 1,
	})
	local light = Instance.new("PointLight")
	light.Name = "CosmeticAuraLight"
	light.Range = 10
	light.Brightness = 1.2
	light.Color = rgb(255, 180, 230)
	light.Parent = root
end

AURAS.InfernoAura = function(root)
	local fire = Instance.new("Fire")
	fire.Name = "CosmeticAuraFire"
	fire.Size = 7
	fire.Heat = 10
	fire.Color = rgb(255, 150, 50)
	fire.SecondaryColor = rgb(255, 60, 20)
	fire.Parent = root
	local light = Instance.new("PointLight")
	light.Name = "CosmeticAuraLight"
	light.Color = rgb(255, 130, 50)
	light.Range = 12
	light.Brightness = 2
	light.Parent = root
end

AURAS.ThunderGodAura = function(root)
	emitter(root, {
		Name = "CosmeticAura",
		Color = ColorSequence.new(rgb(255, 250, 170), rgb(150, 210, 255)),
		Size = NumberSequence.new(0.35, 0),
		Speed = NumberRange.new(4, 8),
		SpreadAngle = Vector2.new(180, 180),
		Lifetime = NumberRange.new(0.15, 0.3),
		Rate = 30,
		LightEmission = 1,
	})
	-- Its bolts and throbbing light live in an "AuraFx" model (see applyCharacter).
end

-- Hats and backs can have a ring that spins (parts marked "SpinRing", with
-- pieces marked "OnRing"). After welding, the ring gets a SpinWeld the
-- client's FlashyFx turns. Anything flashy gets the "FlashyFx" tag.
local function finishFlashy(model: Model, anchor: BasePart)
	for _, ring in model:GetDescendants() do
		if ring:IsA("BasePart") and ring:GetAttribute("SpinRing") then
			for _, child in ring:GetChildren() do
				if child:IsA("WeldConstraint") then
					child:Destroy()
				end
			end
			local spin = Instance.new("Weld")
			spin.Name = "SpinWeld"
			spin.Part0 = anchor
			spin.Part1 = ring
			spin.C0 = anchor.CFrame:ToObjectSpace(ring.CFrame)
			spin:SetAttribute("Speed", ring:GetAttribute("SpinRing"))
			spin.Parent = ring
			for _, other in model:GetDescendants() do
				if other:IsA("BasePart") and other:GetAttribute("OnRing") then
					local weld = other:FindFirstChildOfClass("WeldConstraint")
					if weld then
						weld.Part0 = ring
					end
				end
			end
			CollectionService:AddTag(model, "FlashyFx")
		end
	end
	if model:GetAttribute("Bolts") or model:GetAttribute("Rainbow") then
		CollectionService:AddTag(model, "FlashyFx")
	end
end

-- A finishing touch for hats and backs: glowing parts cast a soft light, and
-- metal, gold and glass pick up a little shine.
local function polish(model: Model)
	local lit = model:FindFirstChildWhichIsA("PointLight", true) ~= nil
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			if p.Material == Enum.Material.Neon and not lit then
				local light = Instance.new("PointLight")
				light.Color = p.Color
				light.Range = 6
				light.Brightness = 0.9
				light.Parent = p
				lit = true
			elseif
				(
					p.Material == Enum.Material.Metal
					or p.Material == Enum.Material.Foil
					or p.Material == Enum.Material.Glass
				) and p.Reflectance == 0
			then
				p.Reflectance = 0.15
			end
			p.CastShadow = false
		end
	end
end

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
		finishFlashy(model, head)
		polish(model)
		model.Parent = folder
	end

	local back = cosmetics.back and BACKS[cosmetics.back]
	if back and torso then
		local model = Instance.new("Model")
		model.Name = "Back"
		back(model, torso.CFrame * CFrame.new(0, 0.1, torso.Size.Z / 2))
		weldAll(model, torso)
		finishFlashy(model, torso)
		polish(model)
		model.Parent = folder
	end

	local trail = cosmetics.trail and TRAILS[cosmetics.trail]
	if trail and root then
		-- Three layers: a bright core ribbon from the waist to the feet, a
		-- wide soft glow around it, and particles falling off as you move,
		-- plus a light in the trail's color.
		local function ribbon(
			name: string,
			colors: { Color3 },
			width: number,
			lifetime: number,
			strength: number,
			texture: string?,
			emission: number
		)
			local top = Instance.new("Attachment")
			top.Name = name .. "Top"
			top.Position = Vector3.new(0, 0.3 + width * 0.25, 0.4)
			top.Parent = root
			local bottom = Instance.new("Attachment")
			bottom.Name = name .. "Bottom"
			bottom.Position = Vector3.new(0, -2.2 - width * 0.25, 0.4)
			bottom.Parent = root
			local effect = Instance.new("Trail")
			effect.Name = name
			effect.Attachment0 = top
			effect.Attachment1 = bottom
			effect.Color = colorSequence(colors)
			effect.Lifetime = lifetime
			effect.MinLength = 0.05
			effect.WidthScale = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.6, 0.6),
				NumberSequenceKeypoint.new(1, 0.05),
			})
			effect.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1 - strength),
				NumberSequenceKeypoint.new(0.7, 1 - strength * 0.5),
				NumberSequenceKeypoint.new(1, 1),
			})
			effect.LightEmission = emission
			effect.LightInfluence = if emission > 0.5 then 0 else 1
			effect.FaceCamera = true
			if texture then
				effect.Texture = texture
				effect.TextureMode = Enum.TextureMode.Stretch
			end
			effect.Parent = root
		end
		ribbon("CosmeticTrail", trail.colors, trail.width, trail.lifetime * 1.2, 0.95, trail.texture, trail.emission)
		local glow = trail.glow or { colors = trail.colors, width = trail.width * 2, lifetime = trail.lifetime * 0.7 }
		ribbon(
			"CosmeticTrailGlow",
			glow.colors or trail.colors,
			glow.width,
			glow.lifetime,
			0.3,
			SOFT,
			math.max(trail.emission, 0.6)
		)
		local fx = trail.particles
			or {
				texture = SPARKLES,
				colors = trail.colors,
				size = 0.3,
				rate = 12,
				lifetime = 0.9,
				speed = 1,
				accel = Vector3.new(0, -1.5, 0),
				emission = 1,
			}
		local spot = Instance.new("Attachment")
		spot.Name = "CosmeticTrailFx"
		spot.Position = Vector3.new(0, -1.4, 0.6)
		spot.Parent = root
		emitter(spot, {
			Texture = fx.texture,
			Color = colorSequence(fx.colors),
			Size = NumberSequence.new(fx.size, fx.size * 0.3),
			Transparency = NumberSequence.new(fx.transparency or 0, 1),
			Rate = fx.rate,
			Lifetime = NumberRange.new(fx.lifetime * 0.8, fx.lifetime * 1.2),
			Speed = NumberRange.new(fx.speed * 0.5, fx.speed),
			SpreadAngle = Vector2.new(180, 180),
			Acceleration = fx.accel or Vector3.zero,
			RotSpeed = NumberRange.new(-(fx.spin or 0), fx.spin or 0),
			Rotation = NumberRange.new(0, 360),
			LightEmission = fx.emission or 0,
		})
		local light = Instance.new("PointLight")
		light.Name = "CosmeticTrailLight"
		light.Color = trail.light or trail.colors[1]
		light.Range = if trail.light then 10 else 7
		light.Brightness = if trail.light then 1.2 else 0.6
		light.Parent = root
	end

	local aura = cosmetics.aura and AURAS[cosmetics.aura]
	if aura and root then
		aura(root)
		-- A soft glowing halo on the ground under you, in the aura's color.
		local haloColor = AURA_COLORS[cosmetics.aura] or rgb(255, 255, 255)
		local floor = Instance.new("Attachment")
		floor.Name = "CosmeticAuraFloor"
		floor.Position = Vector3.new(0, -2.9, 0)
		floor.Parent = root
		emitter(floor, {
			Name = "CosmeticAuraHalo",
			Texture = SOFT,
			Color = ColorSequence.new(haloColor),
			Size = NumberSequence.new(4.5),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.4, 0.55),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Rate = 3,
			Lifetime = NumberRange.new(1.2),
			Speed = NumberRange.new(0),
			Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
			EmissionDirection = Enum.NormalId.Top,
			LockedToPart = true,
			LightEmission = 1,
		})
		local glow = Instance.new("PointLight")
		glow.Name = "CosmeticAuraLight"
		glow.Color = haloColor
		glow.Range = 8
		glow.Brightness = 0.8
		glow.Parent = root
		if cosmetics.aura == "ThunderGodAura" then
			-- Bolts crackle around you and a light throbs.
			local fx = Instance.new("Model")
			fx.Name = "AuraFx"
			local core = part(fx, { Size = Vector3.one * 0.2, Transparency = 1, CFrame = root.CFrame })
			fx.PrimaryPart = core
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = core
			weld.Parent = core
			local light = Instance.new("PointLight")
			light.Name = "PulseLight"
			light.Color = rgb(200, 225, 255)
			light.Range = 12
			light.Parent = core
			fx:SetAttribute("Bolts", rgb(200, 225, 255))
			fx.Parent = folder
			CollectionService:AddTag(fx, "FlashyFx")
		end
	end
end

-- Cloud bed skins: the fluffy mattress of your team's bed in a match.
type CloudSkin = {
	colors: { Color3 },
	material: Enum.Material?,
	transparency: number?,
	wisp: Color3,
	fx: ParticleStyle?,
	light: Color3?,
	flashes: boolean?,
	fire: boolean?, -- real flames
	bolts: Color3?, -- lightning bolts crackle around it
	rainbow: boolean?, -- colors flow through it
	pulse: Color3?, -- a throbbing glow
}

local RAIN_FX: ParticleStyle = {
	texture = SPARKLES,
	colors = { rgb(150, 190, 240) },
	size = 0.15,
	rate = 30,
	lifetime = 0.6,
	speed = 12,
	accel = Vector3.new(0, -20, 0),
}

local BEDS: { [string]: CloudSkin } = {
	Cumulus = { colors = { rgb(250, 251, 255), rgb(230, 234, 242) }, wisp = rgb(244, 246, 252) },
	StormCloudSkin = { colors = { rgb(118, 122, 136), rgb(86, 90, 102) }, wisp = rgb(126, 130, 144), fx = RAIN_FX },
	SunsetCloud = {
		colors = { rgb(255, 196, 150), rgb(246, 146, 150), rgb(255, 218, 176) },
		wisp = rgb(255, 196, 168),
		light = rgb(255, 160, 110),
	},
	SnowCloud = {
		colors = { rgb(238, 246, 255), rgb(204, 222, 246) },
		wisp = rgb(236, 244, 255),
		fx = {
			texture = SPARKLES,
			colors = { rgb(255, 255, 255) },
			size = 0.3,
			rate = 16,
			lifetime = 1.4,
			speed = 2,
			accel = Vector3.new(0, -4, 0),
			spin = 60,
		},
	},
	RainbowCloud = {
		colors = { rgb(255, 196, 200), rgb(255, 230, 180), rgb(200, 240, 200), rgb(190, 215, 255), rgb(222, 200, 255) },
		wisp = rgb(250, 245, 255),
		fx = {
			texture = SPARKLES,
			colors = RAINBOW,
			size = 0.35,
			rate = 12,
			lifetime = 1,
			speed = 1,
			emission = 1,
		},
	},
	GoldenCloud = {
		colors = { rgb(255, 214, 110), rgb(236, 176, 58) },
		material = Enum.Material.Foil,
		wisp = rgb(255, 228, 160),
		fx = {
			texture = SPARKLES,
			colors = { rgb(255, 230, 140) },
			size = 0.4,
			rate = 14,
			lifetime = 1,
			speed = 1,
			emission = 1,
		},
		light = rgb(255, 210, 110),
	},
	ThunderCloudSkin = {
		colors = { rgb(58, 60, 72), rgb(36, 38, 48) },
		wisp = rgb(70, 72, 86),
		fx = RAIN_FX,
		flashes = true,
	},
	InfernoCloud = {
		colors = { rgb(255, 120, 40), rgb(200, 50, 20), rgb(255, 180, 70) },
		material = Enum.Material.Neon,
		transparency = 0.25,
		wisp = rgb(90, 60, 50),
		fire = true,
		fx = {
			texture = SPARKLES,
			colors = { rgb(255, 200, 90), rgb(255, 80, 30) },
			size = 0.35,
			rate = 20,
			lifetime = 1,
			speed = 3,
			accel = Vector3.new(0, 6, 0),
			emission = 1,
		},
		light = rgb(255, 130, 50),
	},
	ThunderboltCloud = {
		colors = { rgb(70, 72, 90), rgb(46, 48, 62) },
		wisp = rgb(90, 92, 110),
		bolts = rgb(170, 220, 255),
		fx = RAIN_FX,
		light = rgb(160, 200, 255),
	},
	PrismCloud = {
		colors = { rgb(255, 255, 255) },
		material = Enum.Material.Neon,
		transparency = 0.35,
		wisp = rgb(255, 240, 255),
		rainbow = true,
		fx = {
			texture = SPARKLES,
			colors = RAINBOW,
			size = 0.4,
			rate = 18,
			lifetime = 1.2,
			speed = 1.5,
			emission = 1,
		},
	},
	GalaxyCloud = {
		colors = { rgb(40, 30, 90), rgb(80, 40, 140), rgb(30, 60, 130) },
		material = Enum.Material.Neon,
		transparency = 0.3,
		wisp = rgb(90, 70, 170),
		fx = {
			texture = SPARKLES,
			colors = { rgb(255, 255, 255), rgb(190, 210, 255) },
			size = 0.3,
			rate = 25,
			lifetime = 1.6,
			speed = 0.6,
			emission = 1,
		},
		light = rgb(140, 110, 255),
	},
	VoidCloud = {
		colors = { rgb(25, 12, 40), rgb(60, 25, 100) },
		wisp = rgb(60, 30, 100),
		pulse = rgb(160, 80, 255),
	},
	AuroraCloud = {
		colors = { rgb(120, 255, 190), rgb(110, 200, 255), rgb(190, 130, 255) },
		material = Enum.Material.Neon,
		transparency = 0.45,
		wisp = rgb(160, 255, 220),
		light = rgb(120, 255, 200),
	},

	-- Battle pass beds.
	HarvestBed = {
		colors = { rgb(255, 150, 50), rgb(230, 110, 30) },
		wisp = rgb(255, 190, 120),
		light = rgb(255, 150, 60),
		fx = {
			texture = SPARKLES,
			colors = { rgb(255, 200, 90) },
			size = 0.3,
			rate = 10,
			lifetime = 1.2,
			speed = 1,
			emission = 1,
		},
	},
	SnowGlobeBed = {
		colors = { rgb(235, 245, 255), rgb(200, 225, 255) },
		material = Enum.Material.Glass,
		transparency = 0.15,
		wisp = rgb(236, 244, 255),
		light = rgb(255, 230, 170),
		flashes = true,
		fx = {
			texture = SPARKLES,
			colors = { rgb(255, 255, 255) },
			size = 0.3,
			rate = 16,
			lifetime = 1.4,
			speed = 2,
			accel = Vector3.new(0, -4, 0),
			spin = 60,
		},
	},
	BlossomBed = {
		colors = { rgb(255, 200, 225), rgb(255, 160, 200), rgb(255, 235, 245) },
		wisp = rgb(255, 215, 235),
		fx = {
			texture = SPARKLES,
			colors = { rgb(255, 170, 200), rgb(255, 230, 240) },
			size = 0.4,
			rate = 12,
			lifetime = 1.6,
			speed = 1,
			accel = Vector3.new(0, -2, 0),
			spin = 160,
		},
	},
	VeteranBed = {
		colors = { rgb(255, 205, 80), rgb(200, 150, 50) },
		material = Enum.Material.Foil,
		wisp = rgb(255, 230, 150),
		light = rgb(255, 210, 110),
		bolts = rgb(255, 230, 140),
	},
	BeachBed = {
		colors = { rgb(255, 225, 140), rgb(255, 245, 200) },
		material = Enum.Material.Neon,
		transparency = 0.3,
		wisp = rgb(255, 240, 190),
		light = rgb(255, 220, 120),
		pulse = rgb(255, 200, 90),
	},
}

-- Fills a cloud bed (built by MatchService) with its mattress in the skin
-- picked by the first teammate who has one. `frame` is the bed's center on
-- the floor. The puffs don't block the "Break the bed" prompt.
function CosmeticService.dressBed(bed: Model, frame: CFrame, members: { Player })
	local skinId = CosmeticsData.Defaults.bed
	for _, member in members do
		local data = DataService.get(member)
		local pick = data and data.cosmetics.bed
		if pick and BEDS[pick] then
			skinId = pick
			break
		end
	end
	local skin = BEDS[skinId] or BEDS.Cumulus
	local cloud = Instance.new("Model")
	cloud.Name = "Mattress"
	local puffs = {}
	for row = 0, 2 do
		for side = -1, 1, 2 do
			table.insert(puffs, { Vector3.new(side * 1.3, 2, -2.8 + row * 2.6), 3.2 })
		end
	end
	table.insert(puffs, { Vector3.new(0, 2.6, -1.4), 2.8 })
	table.insert(puffs, { Vector3.new(0, 2.6, 1.4), 2.8 })
	local center: Part? = nil
	for index, puff in puffs do
		local p = ball(
			cloud,
			Vector3.one * puff[2],
			skin.colors[(index - 1) % #skin.colors + 1],
			frame * CFrame.new(puff[1]),
			skin.material
		)
		p.Name = "CloudPuff"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.Transparency = skin.transparency or 0
		center = center or p
	end
	local middle = center :: Part
	emitter(middle, {
		Name = "Wisps",
		Texture = SMOKE,
		Color = ColorSequence.new(skin.wisp),
		Size = NumberSequence.new(2.4, 3.6),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0.5),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(1, 1.6),
		Rate = 10,
		Speed = NumberRange.new(0.5, 1.5),
		SpreadAngle = Vector2.new(180, 30),
		LightEmission = 0,
	})
	local fx = skin.fx
	if fx then
		emitter(middle, {
			Texture = fx.texture,
			Color = colorSequence(fx.colors),
			Size = NumberSequence.new(fx.size),
			Rate = fx.rate,
			Lifetime = NumberRange.new(fx.lifetime * 0.8, fx.lifetime * 1.2),
			Speed = NumberRange.new(fx.speed * 0.5, fx.speed),
			EmissionDirection = Enum.NormalId.Bottom,
			SpreadAngle = Vector2.new(40, 40),
			Acceleration = fx.accel or Vector3.zero,
			RotSpeed = NumberRange.new(-(fx.spin or 0), fx.spin or 0),
			LightEmission = fx.emission or 0.2,
		})
	end
	if skin.light or skin.flashes then
		local light = Instance.new("PointLight")
		light.Color = skin.light or rgb(210, 225, 255)
		light.Range = 14
		light.Brightness = if skin.flashes then 0 else 1.5
		light.Parent = middle
		if skin.flashes then
			-- Lightning flickers inside the thundercloud.
			task.defer(function()
				while cloud.Parent do
					task.wait(rng:NextNumber(0.8, 2.5))
					light.Brightness = 5
					task.wait(0.07)
					light.Brightness = 0
					task.wait(0.06)
					light.Brightness = 3
					task.wait(0.08)
					light.Brightness = 0
				end
			end)
		end
	end
	if skin.fire then
		local fire = Instance.new("Fire")
		fire.Size = 6
		fire.Heat = 12
		fire.Color = rgb(255, 150, 50)
		fire.SecondaryColor = rgb(255, 60, 20)
		fire.Parent = middle
	end
	if skin.pulse then
		local light = Instance.new("PointLight")
		light.Name = "PulseLight"
		light.Color = skin.pulse
		light.Range = 16
		light.Parent = middle
	end
	if skin.bolts then
		cloud:SetAttribute("Bolts", skin.bolts)
	end
	if skin.rainbow then
		cloud:SetAttribute("Rainbow", true)
	end
	if skin.bolts or skin.rainbow or skin.pulse then
		CollectionService:AddTag(cloud, "FlashyFx")
	end
	cloud.Parent = bed
end

---------------------------------------------------------------------------
-- Knockout effects (MatchService calls knockout when someone is knocked out)
---------------------------------------------------------------------------

local function spark(position: Vector3, color: Color3, size: number, lifetime: number): Part
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.one * size
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.CFrame = CFrame.new(position)
	p.Parent = workspace
	Debris:AddItem(p, lifetime)
	return p
end

-- A burst of glowing balls flying out and fading.
local function burst(position: Vector3, colors: { Color3 }, count: number, reach: number, gravity: boolean?)
	for i = 1, count do
		local piece = spark(position, colors[(i - 1) % #colors + 1], rng:NextNumber(0.4, 0.9), 1.3)
		local direction = rng:NextUnitVector()
		if not gravity then
			direction = Vector3.new(direction.X, math.abs(direction.Y), direction.Z)
		end
		local goal = position + direction * reach * rng:NextNumber(0.5, 1)
		if gravity then
			goal -= Vector3.new(0, reach * 0.6, 0)
		end
		TweenService:Create(piece, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.new(goal),
			Size = Vector3.one * 0.1,
			Transparency = 1,
		}):Play()
	end
end

-- A zigzag bolt from the sky down to `position`.
local function bolt(position: Vector3, color: Color3)
	local from = position + Vector3.new(rng:NextNumber(-4, 4), 40, rng:NextNumber(-4, 4))
	local last = from
	for i = 1, 8 do
		local alpha = i / 8
		local point = from:Lerp(position, alpha)
			+ (if i < 8 then Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2)) else Vector3.zero)
		local segment = Instance.new("Part")
		segment.Anchored = true
		segment.CanCollide = false
		segment.CanQuery = false
		segment.CanTouch = false
		segment.Material = Enum.Material.Neon
		segment.Color = color
		segment.Size = Vector3.new(0.4, 0.4, (point - last).Magnitude)
		segment.CFrame = CFrame.lookAt(last, point) * CFrame.new(0, 0, -(point - last).Magnitude / 2)
		segment.Parent = workspace
		Debris:AddItem(segment, 0.35)
		last = point
	end
	local flash = spark(position, color, 4, 0.4)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 30
	light.Brightness = 6
	light.Parent = flash
end

local KNOCKOUTS: { [string]: (Vector3) -> () } = {
	Poof = function(position)
		burst(position, { rgb(250, 251, 255), rgb(220, 226, 238) }, 10, 5)
	end,
	ConfettiKO = function(position)
		Effects.confetti(position, 60)
	end,
	LightningKO = function(position)
		bolt(position, rgb(200, 230, 255))
		burst(position, { rgb(255, 250, 170), rgb(170, 210, 255) }, 12, 7)
	end,
	FrostKO = function(position)
		burst(position, { rgb(190, 235, 255), rgb(255, 255, 255), rgb(140, 200, 255) }, 22, 8, true)
	end,
	TornadoKO = function(position)
		for i = 1, 24 do
			local angle = i / 24 * math.pi * 6
			local ring = spark(position, rgb(210, 220, 235), 0.6, 1.2)
			TweenService:Create(ring, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				CFrame = CFrame.new(
					position + Vector3.new(math.cos(angle) * (1 + i * 0.2), i * 0.6, math.sin(angle) * (1 + i * 0.2))
				),
				Transparency = 1,
			}):Play()
		end
	end,
	FireworkKO = function(position)
		for i = 1, 3 do
			task.delay((i - 1) * 0.25, function()
				burst(
					position + Vector3.new(rng:NextNumber(-6, 6), 14 + i * 3, rng:NextNumber(-6, 6)),
					RAINBOW,
					18,
					8,
					true
				)
			end)
		end
	end,
	InfernoKO = function(position)
		local core = spark(position, rgb(255, 140, 40), 3, 1)
		local fire = Instance.new("Fire")
		fire.Size = 10
		fire.Heat = 15
		fire.Parent = core
		burst(position, { rgb(255, 200, 80), rgb(255, 90, 30), rgb(80, 60, 50) }, 20, 9)
	end,
	GoldenRainKO = function(position)
		burst(position + Vector3.new(0, 10, 0), { rgb(255, 215, 80), rgb(255, 240, 160) }, 30, 10, true)
		Effects.confetti(position, 30)
	end,
	VoidKO = function(position)
		local rift = spark(position, rgb(60, 20, 100), 1, 1.2)
		TweenService:Create(rift, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = Vector3.one * 8,
			Color = rgb(20, 5, 40),
		}):Play()
		burst(position, { rgb(160, 80, 255), rgb(90, 40, 140) }, 16, 6)
	end,
	LegendKO = function(position)
		for i = 1, 3 do
			task.delay((i - 1) * 0.15, function()
				bolt(position + Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3)), rgb(255, 225, 120))
			end)
		end
		burst(position, { rgb(255, 215, 90), rgb(255, 255, 255) }, 24, 9)
	end,
	-- Battle pass knockouts.
	PumpkinKO = function(position)
		burst(position, { rgb(255, 140, 30), rgb(90, 160, 60), rgb(255, 200, 80) }, 20, 8)
	end,
	SnowmanKO = function(position)
		burst(position, { rgb(255, 255, 255), rgb(200, 230, 255) }, 26, 9, true)
	end,
	BlossomKO = function(position)
		burst(position, { rgb(255, 170, 200), rgb(255, 230, 240), rgb(255, 120, 180) }, 24, 8, true)
	end,
	SunflareKO = function(position)
		local sun = spark(position, rgb(255, 230, 120), 2, 0.9)
		local light = Instance.new("PointLight")
		light.Color = rgb(255, 220, 120)
		light.Range = 40
		light.Brightness = 8
		light.Parent = sun
		TweenService:Create(sun, TweenInfo.new(0.8), { Size = Vector3.one * 12, Transparency = 1 }):Play()
	end,
}

-- The emote a winner dances (Roblox's built-in emotes: cheer, wave, dance...).
function CosmeticService.danceOf(player: Player): string
	local data = DataService.get(player)
	local item = CosmeticsData.get(data and data.cosmetics.dance or CosmeticsData.Defaults.dance)
	return if item and item.emote then item.emote else "cheer"
end

-- The killer's knockout effect at the spot where someone was knocked out.
function CosmeticService.knockout(killer: Player, position: Vector3)
	local data = DataService.get(killer)
	local id = data and data.cosmetics.ko or CosmeticsData.Defaults.ko
	local play = KNOCKOUTS[id] or KNOCKOUTS.Poof
	play(position)
end

---------------------------------------------------------------------------
-- Buying and equipping
---------------------------------------------------------------------------

-- The Style Bonus: every cosmetic you use adds its tier's bonus.
local SLOTS = { "hat", "trail", "back", "aura", "pet", "bed", "sword", "fx", "ko", "dance" }

local function styleBonus(cosmetics: any): number
	local total = 0
	for _, key in SLOTS do
		local item = CosmeticsData.get(cosmetics[key])
		if
			item
			and (
				cosmetics.owned[item.id]
				or (item.cost <= 0 and not item.robux and not item.season and not item.achievement)
			)
		then
			total += CosmeticsData.tierOf(item).bonus
		end
	end
	return math.min(total, Config.Style.MaxBonus)
end

local function publish(player: Player, data: any)
	local cosmetics = data.cosmetics
	data.styleBonus = styleBonus(cosmetics)
	player:SetAttribute("StyleBonus", data.styleBonus)
	IncomeService.sync(player)
	local owned = {}
	for id in cosmetics.owned do
		table.insert(owned, id)
	end
	local state: { [string]: any } = { owned = owned }
	for _, key in SLOTS do
		state[key] = cosmetics[key]
	end
	player:SetAttribute("Cosmetics", HttpService:JSONEncode(state))
end

-- Your pet: built here, then every screen walks it after you (PetFollower).
local petOf: { [Player]: Model } = {}

local function refreshPet(player: Player)
	local old = petOf[player]
	if old then
		old:Destroy()
		petOf[player] = nil
	end
	local data = DataService.get(player)
	local item = data and CosmeticsData.get(data.cosmetics.pet)
	if not item or not item.pet or not player.Parent then
		return
	end
	local owned = data.cosmetics.owned[item.id] or (item.cost <= 0 and not item.robux and not item.season)
	if not owned then
		return
	end
	local character = player.Character
	local start = if character then character:GetPivot() * CFrame.new(3, -1.5, 3) else CFrame.new(Config.Lobby.Center)
	local model = PetModels.build(item.pet, start)
	if not model then
		return
	end
	model.Name = player.Name .. "_Pet"
	model:SetAttribute("OwnerId", player.UserId)
	-- Its level: bigger, sparkly at 5, golden at 10, and a name tag.
	local level = PetLevels.levelOf(data, item.id)
	local scale = PetLevels.scale(level)
	if scale ~= 1 then
		pcall(function()
			model:ScaleTo(scale)
		end)
		local height = model:GetAttribute("Height")
		if type(height) == "number" then
			model:SetAttribute("Height", height * scale)
		end
	end
	local root = model.PrimaryPart
	local body: BasePart? = nil
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and child ~= root then
			body = child
			break
		end
	end
	if body and level >= PetLevels.SparkleLevel then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = if level >= PetLevels.GoldLevel
			then Color3.fromRGB(255, 215, 90)
			else Color3.fromRGB(200, 230, 255)
		sparkles.Parent = body
	end
	if body and level >= PetLevels.GoldLevel then
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 210, 110)
		glow.Range = 10
		glow.Brightness = 1.5
		glow.Parent = body
	end
	if root then
		local tag = Instance.new("BillboardGui")
		tag.Size = UDim2.fromOffset(140, 24)
		tag.StudsOffset = Vector3.new(0, 2.2 * scale, 0)
		tag.MaxDistance = 50
		tag.Parent = root
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextColor3 = if level >= PetLevels.GoldLevel then Color3.fromRGB(255, 215, 90) else Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0.3
		label.Text = "Lv " .. level .. " " .. item.emoji .. " " .. item.name
		label.Parent = tag
	end
	CollectionService:AddTag(model, "FollowerPet")
	local folder = workspace:FindFirstChild("Pets")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Pets"
		folder.Parent = workspace
	end
	model.Parent = folder
	petOf[player] = model
end

local function refreshFor(player: Player, data: any, category: string)
	publish(player, data)
	if category == "hat" or category == "trail" or category == "back" or category == "aura" then
		applyCharacter(player)
	elseif category == "pet" then
		refreshPet(player)
	end
	CosmeticService.Changed:Fire(player, category)
end

local function owns(cosmetics: any, item: CosmeticsData.Item): boolean
	return cosmetics.owned[item.id] == true
		or (item.cost <= 0 and not item.robux and not item.season and not item.achievement)
end

-- Unlocks a cosmetic (Sparks, Robux or a battle pass reward) and puts it on.
local function unlock(player: Player, data: any, item: CosmeticsData.Item): string
	data.cosmetics.owned[item.id] = true
	data.cosmetics[item.category] = item.id
	refreshFor(player, data, item.category)
	return item.emoji .. " " .. item.name .. " on!"
end

local function onAction(player: Player, action: any, a: any): (boolean, string)
	local data = DataService.get(player)
	if not data or os.clock() - (lastRequest[player] or 0) < 0.25 then
		return false, "Slow down!"
	end
	lastRequest[player] = os.clock()
	local cosmetics = data.cosmetics

	if action == "unequip" then
		if type(a) ~= "string" or not CosmeticsData.category(a) then
			return false, "Can't do that."
		end
		cosmetics[a] = nil -- back to the free default
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
		if item.season then
			return false, "That's a battle pass reward!"
		end
		if item.achievement then
			return false, "That's an achievement reward!"
		end
		if data.sparks < item.cost then
			return false, "You need ⚡" .. Format.number(item.cost - data.sparks) .. " more Sparks."
		end
		data.sparks -= item.cost
		IncomeService.sync(player)
		return true, "🎉 Bought! " .. unlock(player, data, item)
	elseif action == "equip" then
		if not owns(cosmetics, item) then
			return false, "You don't own that yet."
		end
		cosmetics[item.category] = item.id
		refreshFor(player, data, item.category)
		return true, item.emoji .. " " .. item.name .. " on!"
	end
	return false, "Can't do that."
end

-- Gives a cosmetic (battle pass, holiday shop, spin wheel). Returns an error
-- message if it couldn't.
function CosmeticService.grant(player: Player, id: string): string?
	local data = DataService.get(player)
	local item = CosmeticsData.get(id)
	if not data or not item then
		return "That cosmetic is missing."
	end
	if data.cosmetics.owned[item.id] then
		return "You already own " .. item.name .. "!"
	end
	unlock(player, data, item)
	return nil
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

-- Rebuilds a player's pet (it levelled up).
function CosmeticService.rebuildPet(player: Player)
	refreshPet(player)
end

-- After a trade: take off anything no longer owned and refresh everything.
function CosmeticService.refreshAll(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local cosmetics = data.cosmetics
	for _, key in SLOTS do
		local item = CosmeticsData.get(cosmetics[key])
		if item and not owns(cosmetics, item) then
			cosmetics[key] = nil
		end
	end
	publish(player, data)
	applyCharacter(player)
	refreshPet(player)
	for _, key in SLOTS do
		CosmeticService.Changed:Fire(player, key)
	end
end

function CosmeticService.start()
	Remotes.func("Cosmetic").OnServerInvoke = onAction

	DataService.ProfileLoaded:Connect(function(player, data)
		publish(player, data)
		applyCharacter(player)
		refreshPet(player)
	end)

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
		if petOf[player] then
			petOf[player]:Destroy()
			petOf[player] = nil
		end
	end)
end

return CosmeticService
