--!strict
-- Daily login rewards and the daily quest pool. Rewards use the same format
-- as the season pass (see SeasonData.Reward).

local Config = require(script.Parent.Config)
local SeasonData = require(script.Parent.SeasonData)

export type Quest = {
	id: string,
	text: string, -- "%s" is replaced with the target
	kind: string, -- what counts: catch, catchRare, steal, mix, pet, collect, raid, grump
	-- (Bed Wars: kill, finalKill, bed, win, play)
	targets: { number }, -- one is picked at random; collect is scaled to income instead
}

local RewardsData = {}

-- Day 1 to 7 of a login streak. After day 7 it starts again at day 1.
RewardsData.Daily = {
	{ kind = "sparks", minutes = 5, min = 500 },
	{ kind = "snacks" },
	{ kind = "sparks", minutes = 10, min = 1500 },
	{ kind = "shield", amount = 1 },
	{ kind = "sparks", minutes = 20, min = 5000 },
	{ kind = "storm", rarity = 3 },
	{ kind = "storm", rarity = 4 },
} :: { SeasonData.Reward }

RewardsData.Quests = {
	{ id = "catch", text = "Catch %s storms", kind = "catch", targets = { 8, 12, 15 } },
	{ id = "catchRare", text = "Catch %s Rare-or-better storms", kind = "catchRare", targets = { 2, 3, 5 } },
	{ id = "steal", text = "Steal %s storms", kind = "steal", targets = { 1, 2, 3 } },
	{ id = "mix", text = "Mix storms %s times", kind = "mix", targets = { 1, 2, 3 } },
	{ id = "pet", text = "Pet your storms %s times", kind = "pet", targets = { 5, 8, 10 } },
	{ id = "collect", text = "Collect ⚡%s", kind = "collect", targets = { 0 } },
	{ id = "raid", text = "Fight in a Mega-Storm", kind = "raid", targets = { 1 } },
	{ id = "grump", text = "Pop %s grumpy clouds", kind = "grump", targets = { 5, 8, 12 } },
} :: { Quest }

-- Bed Wars has its own login rewards and quests.
if Config.GameMode == "BedWars" then
	RewardsData.Daily = {
		{ kind = "sparks", minutes = 0, min = 500 },
		{ kind = "sparks", minutes = 0, min = 1000 },
		{ kind = "storm", rarity = 2 },
		{ kind = "sparks", minutes = 0, min = 2000 },
		{ kind = "sparks", minutes = 0, min = 4000 },
		{ kind = "storm", rarity = 3 },
		{ kind = "storm", rarity = 4 },
	} :: { SeasonData.Reward }
	RewardsData.Quests = {
		{ id = "bwKill", text = "Knock out %s players", kind = "kill", targets = { 3, 5, 8 } },
		{ id = "bwFinal", text = "Get %s final kills", kind = "finalKill", targets = { 1, 2, 3 } },
		{ id = "bwBed", text = "Break %s cloud beds", kind = "bed", targets = { 1, 2 } },
		{ id = "bwWin", text = "Win %s matches", kind = "win", targets = { 1, 2 } },
		{ id = "bwPlay", text = "Play %s matches", kind = "play", targets = { 2, 3, 5 } },
	} :: { Quest }
end

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

-- Short text for a reward, e.g. "⚡ 10 min of Sparks".
function RewardsData.describe(reward: SeasonData.Reward): string
	if reward.kind == "sparks" then
		return "⚡ " .. (reward.minutes or 0) .. " min of Sparks"
	elseif reward.kind == "snacks" then
		return "🍪 Storm Snacks"
	elseif reward.kind == "shield" then
		return "🛡️ Raid Shield x" .. (reward.amount or 1)
	elseif reward.kind == "storm" then
		local names = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Cosmic" }
		return "🫙 Random " .. (names[reward.rarity or 3] or "") .. " storm"
	end
	return "🌟 Exclusive storm"
end

return RewardsData
