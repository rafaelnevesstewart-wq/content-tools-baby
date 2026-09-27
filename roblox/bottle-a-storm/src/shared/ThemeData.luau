--!strict
-- Island themes, bought with Sparks in the Shop. A theme recolors your
-- island's ground, underside, trees, bushes, flowers and mushrooms.
-- Meadow is the free starting look (the colors WorldBuilder builds with).

export type Theme = {
	key: string,
	name: string,
	emoji: string,
	cost: number,
	description: string,
	ground: Color3?, -- nil keeps the original colors (Meadow)
	groundMaterial: Enum.Material?,
	underside: Color3?,
	trunk: Color3?,
	leaves: { Color3 }?, -- tree tops and bushes pick from these
	flowers: { Color3 }?, -- petals and mushroom caps pick from these
}

local rgb = Color3.fromRGB

local ThemeData = {}

ThemeData.List = {
	{
		key = "Meadow",
		name = "Meadow",
		emoji = "🌷",
		cost = 0,
		description = "The classic green island with candy trees.",
	},
	{
		key = "Candy",
		name = "Candy Land",
		emoji = "🍭",
		cost = 5000,
		description = "Pink frosting ground, peppermint trunks and gumdrop trees.",
		ground = rgb(255, 190, 215),
		groundMaterial = Enum.Material.SmoothPlastic,
		underside = rgb(140, 90, 70),
		trunk = rgb(255, 245, 250),
		leaves = { rgb(255, 140, 190), rgb(160, 235, 200), rgb(200, 170, 255), rgb(255, 230, 130) },
		flowers = { rgb(255, 90, 140), rgb(120, 200, 255), rgb(255, 200, 80) },
	},
	{
		key = "Beach",
		name = "Sunny Beach",
		emoji = "🏖️",
		cost = 25000,
		description = "Warm sand, palm-green trees and bright tropical flowers.",
		ground = rgb(240, 220, 160),
		groundMaterial = Enum.Material.Sand,
		underside = rgb(200, 165, 115),
		trunk = rgb(165, 120, 75),
		leaves = { rgb(90, 190, 110), rgb(120, 210, 120), rgb(70, 170, 100) },
		flowers = { rgb(255, 120, 90), rgb(255, 200, 60), rgb(255, 110, 170) },
	},
	{
		key = "Snowy",
		name = "Snowy Peak",
		emoji = "⛄",
		cost = 100000,
		description = "Fresh snow, frosty trees and icy blue flowers.",
		ground = rgb(240, 248, 255),
		groundMaterial = Enum.Material.Snow,
		underside = rgb(170, 200, 230),
		trunk = rgb(125, 95, 75),
		leaves = { rgb(235, 245, 255), rgb(200, 230, 215), rgb(215, 235, 250) },
		flowers = { rgb(140, 200, 255), rgb(190, 170, 255), rgb(255, 255, 255) },
	},
	{
		key = "Space",
		name = "Starry Space",
		emoji = "🪐",
		cost = 500000,
		description = "A deep purple island with glowing alien plants.",
		ground = rgb(70, 50, 120),
		groundMaterial = Enum.Material.SmoothPlastic,
		underside = rgb(40, 30, 75),
		trunk = rgb(100, 90, 150),
		leaves = { rgb(150, 110, 255), rgb(90, 220, 255), rgb(255, 120, 230) },
		flowers = { rgb(120, 255, 220), rgb(255, 230, 120), rgb(255, 120, 255) },
	},
} :: { Theme }

function ThemeData.get(key: string?): Theme?
	for _, theme in ThemeData.List do
		if theme.key == key then
			return theme
		end
	end
	return nil
end

return ThemeData
