--!strict
-- 🎖️ The Clan Pass: every season (the same seasons as the battle pass),
-- your whole clan earns Clan XP together as members play, and every member
-- claims each tier's reward for themselves once the clan gets there
-- (ClanService).

local SeasonData = require(script.Parent.SeasonData)

type Reward = SeasonData.Reward

local ClanPassData = {}

ClanPassData.XpPerTier = 150

-- Clan XP for each thing a member does in a match.
ClanPassData.Xp = { play = 5, win = 15, kill = 2, finalKill = 3, bed = 5, boss = 10 }

local function sparks(amount: number): Reward
	return { kind = "sparks", amount = amount }
end

local function kit(rarity: number, mutated: boolean?): Reward
	return { kind = "kit", rarity = rarity, mutated = mutated }
end

ClanPassData.Tiers = {
	sparks(500),
	kit(2),
	sparks(1000),
	kit(3),
	sparks(1500),
	kit(3, true),
	sparks(2500),
	kit(4),
	sparks(3500),
	kit(4, true),
	sparks(5000),
	kit(5),
	sparks(7500),
	kit(5, true),
	kit(6, true), -- the top tier: a shiny Mythic kit
} :: { Reward }

function ClanPassData.xpFor(tier: number): number
	return tier * ClanPassData.XpPerTier
end

function ClanPassData.describe(reward: Reward): string
	if reward.kind == "sparks" then
		return "⚡" .. tostring(reward.amount)
	end
	local names = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Cosmic" }
	return (if reward.mutated then "✨ Shiny " else "🌪️ ") .. (names[reward.rarity or 1] or "") .. " kit"
end

return ClanPassData
