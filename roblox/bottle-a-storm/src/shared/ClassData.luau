--!strict
-- 🧙 Classes (ClassService): pick one in the lobby before a match. Each has a
-- little bonus and a starting item every time you spawn. Your pick is saved
-- (data.class) and shown as the "MatchClass" attribute while you play.
--
-- 🎓 Class levels: every class you play earns XP (data.classXp) and levels up
-- to ClassData.MaxLevel; each level makes its perks a bit stronger
-- (ClassData.perks). Your level is "MatchClassLevel" while you play.

export type Class = {
	key: string,
	name: string,
	emoji: string,
	description: string,
}

export type Perks = {
	taken: number, -- damage you take (1 = normal)
	sword: number, -- sword and stick damage you deal
	bow: number, -- bow damage you deal
	arrows: number, -- Archer: arrows at spawn
	wool: number, -- Builder: Cloud Wool at spawn
	heal: number, -- Healer: health every HealEvery seconds
	range: number, -- Healer: how far the healing reaches
}

local ClassData = {}

ClassData.List = {
	{
		key = "Knight",
		name = "Knight",
		emoji = "🛡️",
		description = "Tough: takes less damage and hits harder with swords. Spawns with a Stone Sword.",
	},
	{ key = "Archer", name = "Archer", emoji = "🏹", description = "Stronger arrows. Spawns with a Bow and arrows." },
	{ key = "Builder", name = "Builder", emoji = "🧱", description = "Spawns with Cloud Wool and a better pickaxe." },
	{
		key = "Healer",
		name = "Healer",
		emoji = "💚",
		description = "Heals you and teammates close by every 2 seconds. Swords hit 10% softer.",
	},
} :: { Class }

ClassData.Default = "Knight"
ClassData.HealEvery = 2
ClassData.MaxLevel = 10
-- Class XP for...
ClassData.Xp = { play = 25, win = 40, kill = 5, bed = 10 }

-- XP needed to go from `level` to the next one.
function ClassData.xpFor(level: number): number
	return 80 + level * 40
end

-- What a class does at a level (1 to MaxLevel).
function ClassData.perks(key: string?, level: number): Perks
	local up = math.clamp(level, 1, ClassData.MaxLevel) - 1
	local perks: Perks = { taken = 1, sword = 1, bow = 1, arrows = 0, wool = 0, heal = 0, range = 0 }
	if key == "Knight" then
		perks.taken = 0.85 - 0.01 * up -- 15% less, up to 24% at level 10
		perks.sword = 1.1 + 0.01 * up
	elseif key == "Archer" then
		perks.bow = 1.25 + 0.025 * up -- +25%, up to about +47%
		perks.arrows = 8 + up
	elseif key == "Builder" then
		perks.wool = 16 + 2 * up -- 16 wool, up to 34
	elseif key == "Healer" then
		perks.sword = 0.9
		perks.heal = 2 + math.floor(up / 3) -- 2, up to 5
		perks.range = 14 + up
	end
	return perks
end

-- A short line about the perks at a level, for the class cards.
function ClassData.summary(key: string, level: number): string
	local perks = ClassData.perks(key, level)
	if key == "Knight" then
		return string.format(
			"-%d%% damage taken, +%d%% sword damage",
			math.floor((1 - perks.taken) * 100 + 0.5),
			math.floor((perks.sword - 1) * 100 + 0.5)
		)
	elseif key == "Archer" then
		return string.format("+%d%% bow damage, %d arrows", math.floor((perks.bow - 1) * 100 + 0.5), perks.arrows)
	elseif key == "Builder" then
		return perks.wool .. " Cloud Wool and a Stone Pickaxe"
	elseif key == "Healer" then
		return "Heals " .. perks.heal .. " every 2s within " .. perks.range .. " studs"
	end
	return ""
end

function ClassData.get(key: string?): Class?
	for _, class in ClassData.List do
		if class.key == key then
			return class
		end
	end
	return nil
end

-- The class a player is playing right now (nil outside matches).
function ClassData.of(player: Player): Class?
	return ClassData.get(player:GetAttribute("MatchClass") :: string?)
end

-- The perks of the class a player is playing right now.
function ClassData.playing(player: Player): Perks
	local level = player:GetAttribute("MatchClassLevel")
	return ClassData.perks(player:GetAttribute("MatchClass") :: string?, if type(level) == "number" then level else 1)
end

-- Multiplier on damage `attacker` deals with `weapon`.
function ClassData.dealt(attacker: Player, weapon: string?): number
	if not ClassData.of(attacker) then
		return 1
	end
	local perks = ClassData.playing(attacker)
	return if weapon == "Bow"
		then perks.bow
		elseif weapon == nil or weapon == "Sword" or weapon == "Knockback Stick" then perks.sword
		else 1
end

-- Multiplier on damage `victim` takes.
function ClassData.taken(victim: Player): number
	return if ClassData.of(victim) then ClassData.playing(victim).taken else 1
end

return ClassData
