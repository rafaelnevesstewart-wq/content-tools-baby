--!strict
-- 🖌️ The Paint Shop: colors you can pick for your sword blades and your
-- armor (PaintService). Your team's color still shows on the armor's trim,
-- tabard and plume, so everyone can tell the teams apart.

export type Paint = { name: string, color: Color3 }

local rgb = Color3.fromRGB

local PaintData = {}

PaintData.Colors = {
	{ name = "Snow White", color = rgb(240, 242, 246) },
	{ name = "Shadow Black", color = rgb(34, 34, 40) },
	{ name = "Ruby Red", color = rgb(200, 30, 50) },
	{ name = "Sunset Orange", color = rgb(240, 120, 40) },
	{ name = "Gold", color = rgb(236, 190, 60) },
	{ name = "Lime", color = rgb(140, 220, 70) },
	{ name = "Emerald", color = rgb(40, 160, 90) },
	{ name = "Ocean Teal", color = rgb(40, 170, 170) },
	{ name = "Sky Blue", color = rgb(110, 180, 250) },
	{ name = "Royal Blue", color = rgb(50, 80, 200) },
	{ name = "Violet", color = rgb(140, 80, 220) },
	{ name = "Bubblegum Pink", color = rgb(250, 130, 190) },
	{ name = "Chocolate", color = rgb(110, 70, 45) },
	{ name = "Steel Grey", color = rgb(130, 136, 146) },
	{ name = "Mint", color = rgb(160, 240, 210) },
	{ name = "Lava", color = rgb(255, 80, 20) },
} :: { Paint }

-- The paint slots and what they color.
PaintData.Slots = {
	{ key = "blade", name = "🗡️ Sword blade" },
	{ key = "armor", name = "🛡️ Armor" },
}

function PaintData.color(index: any): Color3?
	local paint = if type(index) == "number" then PaintData.Colors[index] else nil
	return if paint then paint.color else nil
end

return PaintData
