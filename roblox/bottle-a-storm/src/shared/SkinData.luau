--!strict
-- Looks for your Bed Wars weapons: sword skins (the blade of every sword you
-- hold, wood to diamond) and arrow effects (your bow's arrows). They're
-- cosmetics: see CosmeticsData, categories "sword" and "fx".

export type SwordSkin = {
	blade: Color3?, -- nil keeps the sword tier's own color (wood, stone, iron, diamond)
	material: Enum.Material?,
	transparency: number?,
	glow: Color3?, -- a light on the blade
	sparkles: Color3?,
	fire: boolean?,
}

export type BeamSkin = {
	color: Color3,
	glow: Color3,
	material: Enum.Material,
}

local rgb = Color3.fromRGB
local M = Enum.Material

local SkinData = {}

SkinData.Swords = {
	ClassicBlade = {},
	CrystalBlade = { blade = rgb(190, 160, 255), material = M.Glass, transparency = 0.2, glow = rgb(190, 160, 255) },
	FrostBlade = { blade = rgb(180, 225, 255), material = M.Ice, sparkles = rgb(220, 240, 255) },
	GoldenBlade = {
		blade = rgb(255, 205, 80),
		material = M.Foil,
		sparkles = rgb(255, 220, 90),
		glow = rgb(255, 210, 110),
	},
	LavaBlade = { blade = rgb(60, 40, 34), material = M.CrackedLava, glow = rgb(255, 120, 40), fire = true },
	GalaxyBlade = {
		blade = rgb(60, 40, 140),
		material = M.Neon,
		transparency = 0.2,
		sparkles = rgb(255, 255, 255),
		glow = rgb(140, 110, 255),
	},
	DiamondBlade = {
		blade = rgb(230, 250, 255),
		material = M.Glass,
		sparkles = rgb(200, 240, 255),
		glow = rgb(200, 240, 255),
	},
} :: { [string]: SwordSkin }

SkinData.Beams = {
	ClassicZap = { color = rgb(255, 240, 90), glow = rgb(255, 240, 150), material = M.Neon },
	FireBlast = { color = rgb(255, 120, 40), glow = rgb(255, 150, 60), material = M.Neon },
	FrostBeam = { color = rgb(150, 220, 255), glow = rgb(190, 235, 255), material = M.Neon },
	RainbowBeam = { color = rgb(255, 120, 230), glow = rgb(255, 180, 240), material = M.Neon },
	VoidRay = { color = rgb(120, 40, 200), glow = rgb(160, 80, 255), material = M.Neon },
	GoldenRay = { color = rgb(255, 205, 70), glow = rgb(255, 225, 140), material = M.Foil },
} :: { [string]: BeamSkin }

SkinData.DefaultSword = "ClassicBlade"
SkinData.DefaultBeam = "ClassicZap"

function SkinData.sword(id: string?): SwordSkin
	return SkinData.Swords[id or SkinData.DefaultSword] or SkinData.Swords[SkinData.DefaultSword]
end

function SkinData.beam(id: string?): BeamSkin
	return SkinData.Beams[id or SkinData.DefaultBeam] or SkinData.Beams[SkinData.DefaultBeam]
end

-- Dresses a sword's blade in a skin (CombatService, when it makes your sword).
function SkinData.applySword(blade: BasePart, id: string?)
	local skin = SkinData.sword(id)
	if skin.blade then
		blade.Color = skin.blade
	end
	if skin.material then
		blade.Material = skin.material
	end
	blade.Transparency = skin.transparency or 0
	if skin.glow then
		local light = Instance.new("PointLight")
		light.Color = skin.glow
		light.Range = 8
		light.Brightness = 1.2
		light.Parent = blade
	end
	if skin.sparkles then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = skin.sparkles
		sparkles.Parent = blade
	end
	if skin.fire then
		local fire = Instance.new("Fire")
		fire.Size = 2
		fire.Heat = 4
		fire.Color = rgb(255, 150, 50)
		fire.SecondaryColor = rgb(255, 60, 20)
		fire.Parent = blade
	end
end

return SkinData
