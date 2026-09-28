--!strict
-- Looks for your Bed Wars weapons: sword skins (every sword you hold, wood to
-- diamond) and arrow effects (your bow's arrows). They're cosmetics: see
-- CosmeticsData, categories "sword" and "fx". ItemModels builds them.

export type Particles = {
	texture: string,
	colors: { Color3 },
	size: number,
	rate: number,
	lifetime: number,
	speed: number,
	rise: number?, -- upward (+) or downward (-) pull
	emission: number?,
}

export type SwordSkin = {
	blade: Color3?, -- nil keeps the sword tier's own color (wood, stone, iron, diamond)
	material: Enum.Material?,
	transparency: number?,
	reflectance: number?,
	edge: Color3?, -- the two cutting edges
	edgeGlow: boolean?, -- edges glow (Neon)
	glow: Color3?, -- a light on the blade
	pulse: boolean?, -- that light throbs
	bolts: Color3?, -- little lightning bolts crackle around the blade
	sparkles: Color3?,
	fire: boolean?,
	particles: Particles?,
	swing: { Color3 }, -- the streak left in the air when you swing
}

export type BeamSkin = {
	color: Color3, -- fletching and the flight streak
	glow: Color3,
	material: Enum.Material,
	streak: { Color3 },
	particles: Particles?,
	light: boolean?,
}

local rgb = Color3.fromRGB
local M = Enum.Material

local SPARKLES = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

local SkinData = {}

SkinData.Textures = { Sparkles = SPARKLES, Smoke = SMOKE, Fire = FIRE }

SkinData.Swords = {
	ClassicBlade = { swing = { rgb(255, 255, 255) } },
	RubyBlade = {
		blade = rgb(190, 20, 40),
		material = M.Glass,
		reflectance = 0.2,
		edge = rgb(255, 120, 130),
		glow = rgb(255, 60, 80),
		sparkles = rgb(255, 120, 130),
		swing = { rgb(255, 90, 110), rgb(160, 0, 30) },
	},
	CrystalBlade = {
		blade = rgb(170, 140, 255),
		material = M.Glass,
		transparency = 0.15,
		reflectance = 0.2,
		edge = rgb(220, 200, 255),
		edgeGlow = true,
		glow = rgb(190, 160, 255),
		particles = {
			texture = SPARKLES,
			colors = { rgb(220, 200, 255), rgb(170, 140, 255) },
			size = 0.25,
			rate = 8,
			lifetime = 0.8,
			speed = 0.5,
			emission = 1,
		},
		swing = { rgb(220, 200, 255), rgb(140, 100, 255) },
	},
	FrostBlade = {
		blade = rgb(170, 220, 255),
		material = M.Ice,
		transparency = 0.1,
		edge = rgb(245, 252, 255),
		edgeGlow = true,
		glow = rgb(180, 230, 255),
		particles = {
			texture = SPARKLES,
			colors = { rgb(255, 255, 255), rgb(190, 230, 255) },
			size = 0.22,
			rate = 12,
			lifetime = 1.2,
			speed = 0.8,
			rise = -3,
		},
		swing = { rgb(230, 248, 255), rgb(120, 200, 255) },
	},
	GoldenBlade = {
		blade = rgb(255, 200, 70),
		material = M.Foil,
		reflectance = 0.3,
		edge = rgb(255, 240, 170),
		glow = rgb(255, 210, 110),
		sparkles = rgb(255, 225, 120),
		swing = { rgb(255, 240, 160), rgb(255, 170, 40) },
	},
	ThunderBlade = {
		blade = rgb(60, 62, 76),
		material = M.Metal,
		reflectance = 0.1,
		edge = rgb(255, 240, 90),
		edgeGlow = true,
		glow = rgb(200, 220, 255),
		bolts = rgb(190, 225, 255),
		particles = {
			texture = SPARKLES,
			colors = { rgb(255, 250, 170), rgb(170, 210, 255) },
			size = 0.35,
			rate = 10,
			lifetime = 0.2,
			speed = 6,
			emission = 1,
		},
		swing = { rgb(255, 250, 170), rgb(120, 170, 255) },
	},
	LavaBlade = {
		blade = rgb(60, 40, 34),
		material = M.CrackedLava,
		edge = rgb(255, 120, 30),
		edgeGlow = true,
		glow = rgb(255, 120, 40),
		fire = true,
		particles = {
			texture = FIRE,
			colors = { rgb(255, 200, 90), rgb(255, 80, 20) },
			size = 0.4,
			rate = 16,
			lifetime = 0.6,
			speed = 1.5,
			rise = 5,
			emission = 1,
		},
		swing = { rgb(255, 210, 90), rgb(255, 60, 10) },
	},
	GalaxyBlade = {
		blade = rgb(40, 24, 100),
		material = M.Neon,
		transparency = 0.1,
		edge = rgb(255, 140, 240),
		edgeGlow = true,
		glow = rgb(140, 110, 255),
		pulse = true,
		particles = {
			texture = SPARKLES,
			colors = { rgb(255, 255, 255), rgb(190, 210, 255), rgb(255, 170, 240) },
			size = 0.25,
			rate = 14,
			lifetime = 1.4,
			speed = 0.3,
			emission = 1,
		},
		swing = { rgb(255, 150, 240), rgb(80, 60, 220), rgb(40, 20, 90) },
	},
	ShadowBlade = {
		blade = rgb(20, 16, 26),
		material = M.Slate,
		edge = rgb(170, 70, 255),
		edgeGlow = true,
		glow = rgb(150, 60, 255),
		pulse = true,
		particles = {
			texture = SMOKE,
			colors = { rgb(60, 20, 90), rgb(20, 10, 30) },
			size = 0.8,
			rate = 10,
			lifetime = 1,
			speed = 0.6,
			rise = 1,
		},
		swing = { rgb(190, 90, 255), rgb(30, 10, 50) },
	},
	DiamondBlade = {
		blade = rgb(225, 250, 255),
		material = M.Glass,
		reflectance = 0.35,
		edge = rgb(255, 255, 255),
		edgeGlow = true,
		glow = rgb(200, 240, 255),
		sparkles = rgb(210, 245, 255),
		swing = { rgb(255, 255, 255), rgb(150, 230, 255) },
	},
} :: { [string]: SwordSkin }

SkinData.Beams = {
	ClassicZap = {
		color = rgb(255, 240, 90),
		glow = rgb(255, 240, 150),
		material = M.Neon,
		streak = { rgb(255, 255, 255) },
	},
	FireBlast = {
		color = rgb(255, 120, 40),
		glow = rgb(255, 150, 60),
		material = M.Neon,
		streak = { rgb(255, 220, 100), rgb(255, 60, 10) },
		particles = {
			texture = FIRE,
			colors = { rgb(255, 200, 90), rgb(255, 80, 20) },
			size = 0.6,
			rate = 60,
			lifetime = 0.35,
			speed = 0.5,
			rise = 4,
			emission = 1,
		},
		light = true,
	},
	FrostBeam = {
		color = rgb(150, 220, 255),
		glow = rgb(190, 235, 255),
		material = M.Neon,
		streak = { rgb(240, 250, 255), rgb(110, 190, 255) },
		particles = {
			texture = SPARKLES,
			colors = { rgb(255, 255, 255), rgb(170, 225, 255) },
			size = 0.3,
			rate = 40,
			lifetime = 0.6,
			speed = 0.5,
			rise = -4,
			emission = 1,
		},
	},
	RainbowBeam = {
		color = rgb(255, 120, 230),
		glow = rgb(255, 180, 240),
		material = M.Neon,
		streak = {
			rgb(255, 110, 110),
			rgb(255, 200, 90),
			rgb(130, 230, 130),
			rgb(110, 180, 255),
			rgb(190, 120, 255),
		},
		particles = {
			texture = SPARKLES,
			colors = { rgb(255, 150, 200), rgb(150, 220, 255), rgb(255, 240, 150) },
			size = 0.3,
			rate = 40,
			lifetime = 0.5,
			speed = 0.5,
			emission = 1,
		},
	},
	VoidRay = {
		color = rgb(120, 40, 200),
		glow = rgb(160, 80, 255),
		material = M.Neon,
		streak = { rgb(180, 90, 255), rgb(20, 10, 40) },
		particles = {
			texture = SMOKE,
			colors = { rgb(80, 30, 130), rgb(20, 10, 30) },
			size = 0.9,
			rate = 40,
			lifetime = 0.6,
			speed = 0.3,
		},
		light = true,
	},
	GoldenRay = {
		color = rgb(255, 205, 70),
		glow = rgb(255, 225, 140),
		material = M.Foil,
		streak = { rgb(255, 245, 180), rgb(255, 180, 40) },
		particles = {
			texture = SPARKLES,
			colors = { rgb(255, 230, 120), rgb(255, 255, 220) },
			size = 0.35,
			rate = 40,
			lifetime = 0.7,
			speed = 0.4,
			emission = 1,
		},
		light = true,
	},
} :: { [string]: BeamSkin }

SkinData.DefaultSword = "ClassicBlade"
SkinData.DefaultBeam = "ClassicZap"

function SkinData.sword(id: string?): SwordSkin
	return SkinData.Swords[id or SkinData.DefaultSword] or SkinData.Swords[SkinData.DefaultSword]
end

function SkinData.beam(id: string?): BeamSkin
	return SkinData.Beams[id or SkinData.DefaultBeam] or SkinData.Beams[SkinData.DefaultBeam]
end

-- A ParticleEmitter for a Particles style.
function SkinData.emitter(style: Particles): ParticleEmitter
	local colors = style.colors
	local points = {}
	for index, color in colors do
		table.insert(points, ColorSequenceKeypoint.new(if #colors == 1 then 0 else (index - 1) / (#colors - 1), color))
	end
	if #colors == 1 then
		table.insert(points, ColorSequenceKeypoint.new(1, colors[1]))
	end
	local e = Instance.new("ParticleEmitter")
	e.Texture = style.texture
	e.Color = ColorSequence.new(points)
	e.Size = NumberSequence.new(style.size, style.size * 0.2)
	e.Transparency = NumberSequence.new(0.1, 1)
	e.Rate = style.rate
	e.Lifetime = NumberRange.new(style.lifetime * 0.8, style.lifetime * 1.2)
	e.Speed = NumberRange.new(style.speed * 0.5, style.speed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, style.rise or 0, 0)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-60, 60)
	e.LightEmission = style.emission or 0
	return e
end

-- A ColorSequence through a list of colors.
function SkinData.sequence(colors: { Color3 }): ColorSequence
	if #colors == 1 then
		return ColorSequence.new(colors[1])
	end
	local points = {}
	for index, color in colors do
		table.insert(points, ColorSequenceKeypoint.new((index - 1) / (#colors - 1), color))
	end
	return ColorSequence.new(points)
end

return SkinData
