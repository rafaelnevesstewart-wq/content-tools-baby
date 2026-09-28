--!strict
-- 🧙 Classes (ClassService): pick one in the lobby before a match. Each has a
-- little bonus and a starting item every time you spawn. Your pick is saved
-- (data.class) and shown as the "MatchClass" attribute while you play.

export type Class = {
	key: string,
	name: string,
	emoji: string,
	description: string,
	taken: number, -- damage you take (1 = normal)
	sword: number, -- sword and stick damage you deal
	bow: number, -- bow damage you deal
}

local ClassData = {}

ClassData.List = {
	{
		key = "Knight",
		name = "Knight",
		emoji = "🛡️",
		description = "Tough: takes 15% less damage and hits 10% harder with swords. Spawns with a Stone Sword.",
		taken = 0.85,
		sword = 1.1,
		bow = 1,
	},
	{
		key = "Archer",
		name = "Archer",
		emoji = "🏹",
		description = "Bow damage +25%. Spawns with a Bow and 8 arrows.",
		taken = 1,
		sword = 1,
		bow = 1.25,
	},
	{
		key = "Builder",
		name = "Builder",
		emoji = "🧱",
		description = "Spawns with 16 Cloud Wool and gets a better pickaxe right away.",
		taken = 1,
		sword = 1,
		bow = 1,
	},
	{
		key = "Healer",
		name = "Healer",
		emoji = "💚",
		description = "Heals you and teammates close by, a little every 2 seconds. Swords hit 10% softer.",
		taken = 1,
		sword = 0.9,
		bow = 1,
	},
} :: { Class }

ClassData.Default = "Knight"
ClassData.HealAmount = 2 -- every HealEvery seconds
ClassData.HealEvery = 2
ClassData.HealRange = 14
ClassData.BuilderWool = 16
ClassData.ArcherArrows = 8

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

-- Multiplier on damage `attacker` deals with `weapon`.
function ClassData.dealt(attacker: Player, weapon: string?): number
	local class = ClassData.of(attacker)
	if not class then
		return 1
	end
	return if weapon == "Bow"
		then class.bow
		elseif weapon == nil or weapon == "Sword" or weapon == "Knockback Stick" then class.sword
		else 1
end

-- Multiplier on damage `victim` takes.
function ClassData.taken(victim: Player): number
	local class = ClassData.of(victim)
	return if class then class.taken else 1
end

return ClassData
