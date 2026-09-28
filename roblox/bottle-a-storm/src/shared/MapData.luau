--!strict
-- Map rotation: every match picks a new look for the sky islands (see
-- MapService). The lobby goes back to the Meadow between matches.

export type Map = {
	key: string,
	name: string,
	emoji: string,
	-- Terrain on the islands: the grass top and the dirt layer turn into these
	-- materials (nil keeps the Meadow look), in these colors.
	grass: Enum.Material?,
	dirt: Enum.Material?,
	colors: { [Enum.Material]: Color3 }?,
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
		grass = M.Basalt,
		dirt = M.CrackedLava,
		colors = { [M.Basalt] = rgb(62, 54, 52), [M.CrackedLava] = rgb(255, 110, 40), [M.Rock] = rgb(52, 44, 42) },
		tint = rgb(255, 228, 212),
		props = "volcano",
	},
	{
		key = "Ice",
		name = "Frozen Skies",
		emoji = "❄️",
		grass = M.Snow,
		dirt = M.Glacier,
		colors = { [M.Snow] = rgb(236, 244, 255), [M.Glacier] = rgb(170, 215, 255), [M.Rock] = rgb(130, 150, 175) },
		tint = rgb(222, 236, 255),
		props = "ice",
	},
	{
		key = "Candy",
		name = "Candy Skies",
		emoji = "🍭",
		grass = M.Salt,
		dirt = M.Sandstone,
		colors = { [M.Salt] = rgb(255, 190, 222), [M.Sandstone] = rgb(120, 76, 54), [M.Rock] = rgb(150, 100, 80) },
		tint = rgb(255, 238, 246),
		props = "candy",
	},
	{
		key = "Space",
		name = "Space Station",
		emoji = "🌌",
		grass = M.Pavement,
		dirt = M.Asphalt,
		colors = { [M.Pavement] = rgb(70, 70, 92), [M.Asphalt] = rgb(40, 38, 56), [M.Rock] = rgb(48, 46, 64) },
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
