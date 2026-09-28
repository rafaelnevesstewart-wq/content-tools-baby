--!strict
-- Map rotation: every match picks a new look for the sky islands (see
-- MapService). The lobby goes back to the Meadow between matches.

export type Map = {
	key: string,
	name: string,
	emoji: string,
	ground: Color3?, -- nil keeps the Meadow look
	groundMaterial: Enum.Material?,
	rim: Color3?,
	rimMaterial: Enum.Material?,
	rock: Color3?,
	rockMaterial: Enum.Material?,
	tint: Color3?, -- a color wash over the whole screen
	props: string?, -- what MapService scatters on the islands
}

local rgb = Color3.fromRGB
local M = Enum.Material

local MapData = {}

MapData.List = {
	{ key = "Meadow", name = "Meadow Skies", emoji = "🌿" },
	{
		key = "Volcano",
		name = "Volcano Skies",
		emoji = "🌋",
		ground = rgb(70, 58, 52),
		groundMaterial = M.Basalt,
		rim = rgb(255, 110, 40),
		rimMaterial = M.CrackedLava,
		rock = rgb(45, 38, 36),
		rockMaterial = M.Basalt,
		tint = rgb(255, 228, 212),
		props = "volcano",
	},
	{
		key = "Ice",
		name = "Frozen Skies",
		emoji = "❄️",
		ground = rgb(236, 244, 255),
		groundMaterial = M.Snow,
		rim = rgb(170, 215, 255),
		rimMaterial = M.Ice,
		rock = rgb(150, 190, 230),
		rockMaterial = M.Glacier,
		tint = rgb(222, 236, 255),
		props = "ice",
	},
	{
		key = "Candy",
		name = "Candy Skies",
		emoji = "🍭",
		ground = rgb(255, 190, 222),
		groundMaterial = M.SmoothPlastic,
		rim = rgb(255, 250, 255),
		rimMaterial = M.SmoothPlastic,
		rock = rgb(110, 70, 50),
		rockMaterial = M.SmoothPlastic,
		tint = rgb(255, 238, 246),
		props = "candy",
	},
	{
		key = "Space",
		name = "Space Station",
		emoji = "🌌",
		ground = rgb(62, 62, 82),
		groundMaterial = M.Slate,
		rim = rgb(150, 90, 255),
		rimMaterial = M.Neon,
		rock = rgb(36, 36, 50),
		rockMaterial = M.Slate,
		tint = rgb(214, 212, 255),
		props = "space",
	},
} :: { Map }

function MapData.get(key: string?): Map?
	for _, map in MapData.List do
		if map.key == key then
			return map
		end
	end
	return nil
end

return MapData
