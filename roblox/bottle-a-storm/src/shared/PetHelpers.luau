--!strict
-- 🐾 Pets that help in matches (PetHelperService): the pet you bring does a
-- little job every few seconds. Higher pet levels make it stronger (+10% per
-- level above 1, so level 10 is almost double).
--   heal     heals you when you're hurt
--   blocks   brings you Cloud Wool
--   resource brings you Copper or Silver
--   scout    warns you when an enemy gets near your bed
--   breath   breathes fire at the nearest enemy

export type Helper = {
	job: string,
	every: number, -- seconds
	amount: number,
	resource: string?,
	text: string, -- what it does, for your screen
}

local PetHelpers = {}

PetHelpers.ByKind = {
	Ducks = { job = "heal", every = 4, amount = 3, text = "🩹 heals you" },
	Deer = { job = "heal", every = 5, amount = 5, text = "🩹 heals you" },
	Bunnies = { job = "blocks", every = 12, amount = 2, text = "🧱 brings you wool" },
	CloudSheep = { job = "blocks", every = 14, amount = 3, text = "☁️ brings you wool" },
	Cat = { job = "resource", every = 6, amount = 1, resource = "Copper", text = "🟠 finds Copper" },
	Corgi = { job = "resource", every = 18, amount = 1, resource = "Silver", text = "⚪ fetches Silver" },
	Fox = { job = "scout", every = 2, amount = 30, text = "👁️ guards your bed" },
	StormDragon = { job = "breath", every = 6, amount = 6, text = "🔥 breathes fire at enemies" },
} :: { [string]: Helper }

PetHelpers.PerLevel = 0.1
PetHelpers.BreathRange = 16
PetHelpers.ScoutCooldown = 20

-- How strong a pet's job is at `level`.
function PetHelpers.power(helper: Helper, level: number): number
	return helper.amount * (1 + (level - 1) * PetHelpers.PerLevel)
end

return PetHelpers
