--!strict
-- Daily login rewards and the daily quest pool. Rewards use the same format
-- as the battle pass (see SeasonData.Reward).

local SeasonData = require(script.Parent.SeasonData)

export type Quest = {
	id: string,
	text: string, -- "%s" is replaced with the target
	kind: string, -- what counts: kill, finalKill, bed, win, play, block, crystal
	targets: { number }, -- one is picked at random
}

local RewardsData = {}

-- Day 1 to 7 of a login streak. After day 7 it starts again at day 1.
RewardsData.Daily = {
	{ kind = "sparks", amount = 200 },
	{ kind = "sparks", amount = 400 },
	{ kind = "kit", rarity = 2 },
	{ kind = "sparks", amount = 800 },
	{ kind = "sparks", amount = 1500 },
	{ kind = "kit", rarity = 3 },
	{ kind = "kit", rarity = 4 },
} :: { SeasonData.Reward }

RewardsData.Quests = {
	{ id = "bwKill", text = "Knock out %s players", kind = "kill", targets = { 3, 5, 8 } },
	{ id = "bwFinal", text = "Get %s final kills", kind = "finalKill", targets = { 1, 2, 3 } },
	{ id = "bwBed", text = "Break %s cloud beds", kind = "bed", targets = { 1, 2 } },
	{ id = "bwWin", text = "Win %s matches", kind = "win", targets = { 1, 2 } },
	{ id = "bwPlay", text = "Play %s matches", kind = "play", targets = { 2, 3, 5 } },
	{ id = "bwBlocks", text = "Place %s blocks", kind = "block", targets = { 30, 60, 100 } },
	{ id = "bwCrystals", text = "Collect %s Storm Crystals", kind = "crystal", targets = { 4, 8, 12 } },
} :: { Quest }

function RewardsData.quest(id: string): Quest?
	for _, quest in RewardsData.Quests do
		if quest.id == id then
			return quest
		end
	end
	return nil
end

-- Days since 1970 (UTC). Daily rewards and quests reset when this changes.
function RewardsData.today(now: number): number
	return math.floor(now / 86400)
end

-- Short text for a reward, e.g. "⚡ 500 Sparks".
function RewardsData.describe(reward: SeasonData.Reward): string
	if reward.kind == "sparks" then
		return "⚡ " .. tostring(reward.amount or 0) .. " Sparks"
	elseif reward.kind == "kit" then
		local names = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Cosmic" }
		return (if reward.mutated then "✨ Shiny " else "🎁 Random ") .. (names[reward.rarity or 3] or "") .. " kit"
	elseif reward.kind == "cosmetic" then
		return "🎨 Cosmetic"
	end
	return "🌟 Exclusive kit"
end

return RewardsData
