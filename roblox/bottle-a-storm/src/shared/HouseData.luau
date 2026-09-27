--!strict
-- House styles for the building over your pedestals (cosmetic category
-- "house"). Every island has a house: an open pavilion on the ground floor,
-- plus a floor for each floor you build (see Config.Floors).

export type Surface = { color: Color3, material: Enum.Material, transparency: number? }

export type Style = {
	pillar: Surface,
	slab: Surface,
	rail: Surface,
	roof: Surface,
	roofType: string, -- "pitched" | "flat" | "castle" | "dome"
	trim: Surface?, -- a glowing or shiny strip along each floor's edge
	light: Color3?, -- lamps under each floor
}

local rgb = Color3.fromRGB
local M = Enum.Material

local HouseData = {}

HouseData.Styles = {
	ClassicHouse = {
		pillar = { color = rgb(238, 232, 222), material = M.Concrete },
		slab = { color = rgb(150, 112, 78), material = M.WoodPlanks },
		rail = { color = rgb(238, 232, 222), material = M.Concrete },
		roof = { color = rgb(170, 78, 58), material = M.Slate },
		roofType = "pitched",
		light = rgb(255, 220, 160),
	},
	LogCabin = {
		pillar = { color = rgb(110, 76, 48), material = M.Wood },
		slab = { color = rgb(130, 92, 60), material = M.WoodPlanks },
		rail = { color = rgb(100, 70, 44), material = M.Wood },
		roof = { color = rgb(70, 56, 46), material = M.WoodPlanks },
		roofType = "pitched",
		light = rgb(255, 190, 120),
	},
	StoneCastle = {
		pillar = { color = rgb(128, 124, 118), material = M.Cobblestone },
		slab = { color = rgb(110, 106, 100), material = M.Slate },
		rail = { color = rgb(128, 124, 118), material = M.Cobblestone },
		roof = { color = rgb(120, 116, 110), material = M.Cobblestone },
		roofType = "castle",
		light = rgb(255, 170, 90),
	},
	ModernGlass = {
		pillar = { color = rgb(245, 245, 248), material = M.SmoothPlastic },
		slab = { color = rgb(230, 232, 236), material = M.Marble },
		rail = { color = rgb(170, 220, 255), material = M.Glass, transparency = 0.5 },
		roof = { color = rgb(245, 245, 248), material = M.SmoothPlastic },
		roofType = "flat",
		trim = { color = rgb(120, 200, 255), material = M.Neon },
		light = rgb(220, 240, 255),
	},
	CandyHouse = {
		pillar = { color = rgb(255, 190, 215), material = M.SmoothPlastic },
		slab = { color = rgb(160, 235, 205), material = M.SmoothPlastic },
		rail = { color = rgb(255, 245, 250), material = M.SmoothPlastic },
		roof = { color = rgb(255, 140, 190), material = M.SmoothPlastic },
		roofType = "dome",
		trim = { color = rgb(255, 230, 130), material = M.Neon },
		light = rgb(255, 200, 230),
	},
	CrystalPalace = {
		pillar = { color = rgb(170, 225, 255), material = M.Glass, transparency = 0.2 },
		slab = { color = rgb(200, 235, 255), material = M.Ice },
		rail = { color = rgb(170, 225, 255), material = M.Glass, transparency = 0.4 },
		roof = { color = rgb(150, 210, 255), material = M.Glass, transparency = 0.25 },
		roofType = "dome",
		trim = { color = rgb(120, 220, 255), material = M.Neon },
		light = rgb(160, 220, 255),
	},
	SkyTemple = {
		pillar = { color = rgb(245, 242, 235), material = M.Marble },
		slab = { color = rgb(235, 230, 220), material = M.Marble },
		rail = { color = rgb(255, 205, 80), material = M.Foil },
		roof = { color = rgb(255, 200, 70), material = M.Foil },
		roofType = "pitched",
		trim = { color = rgb(255, 210, 90), material = M.Neon },
		light = rgb(255, 225, 150),
	},
	LavaFortress = {
		pillar = { color = rgb(40, 34, 32), material = M.Basalt },
		slab = { color = rgb(60, 40, 34), material = M.CrackedLava },
		rail = { color = rgb(40, 34, 32), material = M.Basalt },
		roof = { color = rgb(50, 36, 32), material = M.Basalt },
		roofType = "castle",
		trim = { color = rgb(255, 110, 30), material = M.Neon },
		light = rgb(255, 120, 50),
	},
} :: { [string]: Style }

HouseData.Default = "ClassicHouse"

return HouseData
