-- Secret Storm Mixer recipes. This lives on the server so players can't read
-- it from the game files; they have to discover the recipes (and share them).
-- The order of the two ingredients doesn't matter.

local Recipes = {}

Recipes.List = {
	{ a = "FogBun", b = "MistMouse", result = "GhostFog" },
	{ a = "DrizzleDot", b = "ThunderPup", result = "ZappyDrizzle" },
	{ a = "HailHopper", b = "SnowGlobeSam", result = "SleetSprite" },
	{ a = "BreezyBoi", b = "DustDevil", result = "SandTwister" },
	{ a = "TornadoTony", b = "ThunderPup", result = "Thundernado" },
	{ a = "RainbowSquall", b = "DrizzleDot", result = "DoubleRainbow" },
	{ a = "SandstormSultan", b = "HurricaneHana", result = "DesertCyclone" },
	{ a = "BlizzardKing", b = "TornadoTony", result = "FrostVortex" },
	{ a = "MonsoonDragon", b = "ThunderPup", result = "StormSerpent" },
	{ a = "RainbowSquall", b = "BlizzardKing", result = "AuroraSerpent" },
	{ a = "HurricaneHana", b = "MonsoonDragon", result = "TyphoonTitan" },
}

local byPair: { [string]: { a: string, b: string, result: string } } = {}
local byResult: { [string]: { a: string, b: string, result: string } } = {}

local function key(a: string, b: string): string
	return if a < b then a .. "+" .. b else b .. "+" .. a
end

for _, recipe in Recipes.List do
	byPair[key(recipe.a, recipe.b)] = recipe
	byResult[recipe.result] = recipe
end

function Recipes.find(a: string, b: string): { a: string, b: string, result: string }?
	return byPair[key(a, b)]
end

function Recipes.forResult(result: string): { a: string, b: string, result: string }?
	return byResult[result]
end

return Recipes
