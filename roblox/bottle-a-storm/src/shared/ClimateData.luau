--!strict
-- Climate Shift (rebirth). Each shift needs a pile of Sparks, resets your
-- Sparks, Boots and Lightning Rod, gives a permanent x1.5 income bonus (it
-- stacks) and unlocks a new sky island with its own storms.

export type Climate = {
	level: number,
	key: string,
	name: string,
	emoji: string,
	cost: number, -- Sparks you need to shift into this climate
	multiplier: number, -- permanent income bonus at this climate
	-- The biome island (not for Temperate):
	angle: number?, -- degrees around the world center
	distance: number?,
	height: number?,
	ground: Color3?,
	groundMaterial: Enum.Material?,
	rock: Color3?,
	tint: Color3?, -- screen tint while you're on the island
	gravity: number?, -- nil = normal gravity
}

local ClimateData = {}

ClimateData.List = {
	{
		level = 0,
		key = "Temperate",
		name = "Temperate Skies",
		emoji = "🌤️",
		cost = 0,
		multiplier = 1,
	},
	{
		level = 1,
		key = "Arctic",
		name = "Arctic Skies",
		emoji = "❄️",
		cost = 5_000_000,
		multiplier = 1.5,
		angle = 30,
		distance = 620,
		height = 120,
		ground = Color3.fromRGB(235, 245, 255),
		groundMaterial = Enum.Material.Snow,
		rock = Color3.fromRGB(150, 185, 215),
		tint = Color3.fromRGB(215, 235, 255),
	},
	{
		level = 2,
		key = "Volcano",
		name = "Volcano Skies",
		emoji = "🌋",
		cost = 100_000_000,
		multiplier = 2.25,
		angle = 150,
		distance = 620,
		height = 190,
		ground = Color3.fromRGB(70, 55, 55),
		groundMaterial = Enum.Material.Basalt,
		rock = Color3.fromRGB(60, 40, 40),
		tint = Color3.fromRGB(255, 215, 190),
	},
	{
		level = 3,
		key = "Space",
		name = "Space Skies",
		emoji = "🌌",
		cost = 2_000_000_000,
		multiplier = 3.375,
		angle = 270,
		distance = 620,
		height = 260,
		ground = Color3.fromRGB(45, 40, 70),
		groundMaterial = Enum.Material.Slate,
		rock = Color3.fromRGB(30, 25, 50),
		tint = Color3.fromRGB(200, 190, 255),
		gravity = 60,
	},
} :: { Climate }

ClimateData.BiomeRadius = 75
ClimateData.RoamRadius = 60

local byKey: { [string]: Climate } = {}
for _, climate in ClimateData.List do
	byKey[climate.key] = climate
end

-- The climate a player is at (0 = Temperate).
function ClimateData.at(level: number?): Climate
	return ClimateData.List[(level or 0) + 1] or ClimateData.List[1]
end

function ClimateData.get(key: string?): Climate?
	if key == nil then
		return nil
	end
	return byKey[key]
end

-- Where a biome island's top center is.
function ClimateData.center(climate: Climate): Vector3
	local angle = math.rad(climate.angle or 0)
	local distance = climate.distance or 0
	return Vector3.new(math.cos(angle) * distance, climate.height or 0, math.sin(angle) * distance)
end

return ClimateData
