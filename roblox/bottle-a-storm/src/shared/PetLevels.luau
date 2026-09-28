--!strict
-- 🐾 Pet levels: the pet you bring gets XP as you play (PetLevelService).
-- Every level makes it a bit bigger and adds +1% to your match Sparks; at
-- level 5 it sparkles and at level 10 (the max) it glows gold.

local PetLevels = {}

PetLevels.MaxLevel = 10
PetLevels.BonusPerLevel = 0.01 -- match Sparks per level above 1
PetLevels.ScalePerLevel = 0.07 -- size per level above 1
PetLevels.SparkleLevel = 5
PetLevels.GoldLevel = 10

-- XP your pet gets for...
PetLevels.Xp = { play = 20, win = 40, kill = 5, bed = 10, duel = 5 }

-- XP needed to go from `level` to the next one.
function PetLevels.xpFor(level: number): number
	return 60 + level * 40
end

-- The saved level of a pet (1 if it has none yet).
function PetLevels.levelOf(data: any, petId: string?): number
	local entry = petId and data.petLevels and data.petLevels[petId]
	return if entry then entry.level else 1
end

function PetLevels.scale(level: number): number
	return 1 + (level - 1) * PetLevels.ScalePerLevel
end

return PetLevels
