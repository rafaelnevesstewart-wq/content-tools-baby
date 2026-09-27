--!strict
-- Looks for the Storm Jar (the one you throw, the thrown jar and every jar
-- on your pedestals) and for beams and projectiles (Zapper, Cloud Blaster,
-- water balloons). They're cosmetics: see CosmeticsData, categories "jar"
-- and "fx".

export type JarSkin = {
	glass: Color3,
	material: Enum.Material,
	transparency: number,
	lid: Color3,
	lidMaterial: Enum.Material,
	glow: Color3?, -- a light inside the jar
	sparkles: Color3?,
	fire: boolean?,
}

export type BeamSkin = {
	color: Color3,
	glow: Color3, -- the flash light / balloon tint
	material: Enum.Material,
}

local rgb = Color3.fromRGB
local M = Enum.Material

local SkinData = {}

SkinData.Jars = {
	GlassJar = {
		glass = rgb(200, 235, 255),
		material = M.Glass,
		transparency = 0.35,
		lid = rgb(190, 140, 70),
		lidMaterial = M.Metal,
	},
	CrystalJar = {
		glass = rgb(190, 160, 255),
		material = M.Glass,
		transparency = 0.25,
		lid = rgb(230, 230, 245),
		lidMaterial = M.Marble,
		glow = rgb(190, 160, 255),
	},
	FrostJar = {
		glass = rgb(180, 225, 255),
		material = M.Ice,
		transparency = 0.2,
		lid = rgb(240, 248, 255),
		lidMaterial = M.Glacier,
		sparkles = rgb(220, 240, 255),
	},
	GoldenJar = {
		glass = rgb(255, 215, 110),
		material = M.Glass,
		transparency = 0.3,
		lid = rgb(255, 200, 60),
		lidMaterial = M.Foil,
		sparkles = rgb(255, 220, 90),
		glow = rgb(255, 210, 110),
	},
	LavaJar = {
		glass = rgb(60, 40, 34),
		material = M.CrackedLava,
		transparency = 0.1,
		lid = rgb(40, 34, 32),
		lidMaterial = M.Basalt,
		glow = rgb(255, 120, 40),
		fire = true,
	},
	GalaxyJar = {
		glass = rgb(60, 40, 140),
		material = M.Neon,
		transparency = 0.45,
		lid = rgb(30, 24, 60),
		lidMaterial = M.Metal,
		sparkles = rgb(255, 255, 255),
		glow = rgb(140, 110, 255),
	},
	DiamondJar = {
		glass = rgb(230, 250, 255),
		material = M.Glass,
		transparency = 0.1,
		lid = rgb(200, 240, 255),
		lidMaterial = M.Neon,
		sparkles = rgb(200, 240, 255),
		glow = rgb(200, 240, 255),
	},
} :: { [string]: JarSkin }

SkinData.Beams = {
	ClassicZap = { color = rgb(255, 240, 90), glow = rgb(255, 240, 150), material = M.Neon },
	FireBlast = { color = rgb(255, 120, 40), glow = rgb(255, 150, 60), material = M.Neon },
	FrostBeam = { color = rgb(150, 220, 255), glow = rgb(190, 235, 255), material = M.Neon },
	RainbowBeam = { color = rgb(255, 120, 230), glow = rgb(255, 180, 240), material = M.Neon },
	VoidRay = { color = rgb(120, 40, 200), glow = rgb(160, 80, 255), material = M.Neon },
	GoldenRay = { color = rgb(255, 205, 70), glow = rgb(255, 225, 140), material = M.Foil },
} :: { [string]: BeamSkin }

SkinData.DefaultJar = "GlassJar"
SkinData.DefaultBeam = "ClassicZap"

function SkinData.jar(id: string?): JarSkin
	return SkinData.Jars[id or SkinData.DefaultJar] or SkinData.Jars[SkinData.DefaultJar]
end

function SkinData.beam(id: string?): BeamSkin
	return SkinData.Beams[id or SkinData.DefaultBeam] or SkinData.Beams[SkinData.DefaultBeam]
end

-- Dresses a jar's glass and lid parts in a skin (used on the server for the
-- Storm Jar tool, thrown jars and pedestal jars).
function SkinData.applyJar(glass: BasePart, lid: BasePart?, id: string?)
	local skin = SkinData.jar(id)
	glass.Color = skin.glass
	glass.Material = skin.material
	glass.Transparency = skin.transparency
	for _, child in glass:GetChildren() do
		if child.Name == "JarSkinFx" then
			child:Destroy()
		end
	end
	if lid then
		lid.Color = skin.lid
		lid.Material = skin.lidMaterial
	end
	if skin.glow then
		local light = Instance.new("PointLight")
		light.Name = "JarSkinFx"
		light.Color = skin.glow
		light.Range = 8
		light.Brightness = 1.2
		light.Parent = glass
	end
	if skin.sparkles then
		local sparkles = Instance.new("Sparkles")
		sparkles.Name = "JarSkinFx"
		sparkles.SparkleColor = skin.sparkles
		sparkles.Parent = glass
	end
	if skin.fire then
		local fire = Instance.new("Fire")
		fire.Name = "JarSkinFx"
		fire.Size = math.max(2, glass.Size.Magnitude * 0.6)
		fire.Heat = 6
		fire.Color = rgb(255, 150, 50)
		fire.SecondaryColor = rgb(255, 60, 20)
		fire.Parent = glass
	end
end

return SkinData
