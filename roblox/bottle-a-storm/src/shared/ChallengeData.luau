--!strict
-- 🌟 Challenges: one tough Daily Challenge (a new one every day) and 5
-- Weekly Challenges (new ones every Monday, UTC). Finish all 5 weekly ones
-- for a special bonus. ChallengeService tracks them; the "kind" says what
-- counts (the same kinds as daily quests, plus duel, lucky and boss).

local SeasonData = require(script.Parent.SeasonData)

export type Challenge = {
	id: string,
	text: string, -- "%s" is replaced with the target
	kind: string, -- kill, finalKill, bed, win, play, block, crystal, duel, lucky, boss
	targets: { number },
}

local ChallengeData = {}

ChallengeData.Daily = {
	{ id = "dKill", text = "Knock out %s players", kind = "kill", targets = { 12, 15 } },
	{ id = "dFinal", text = "Get %s final kills", kind = "finalKill", targets = { 5, 6 } },
	{ id = "dBed", text = "Break %s cloud beds", kind = "bed", targets = { 3, 4 } },
	{ id = "dWin", text = "Win %s matches", kind = "win", targets = { 3 } },
	{ id = "dDuel", text = "Win %s duels in the lobby arena", kind = "duel", targets = { 3, 5 } },
	{ id = "dLucky", text = "Open %s lucky blocks", kind = "lucky", targets = { 6, 8 } },
} :: { Challenge }

ChallengeData.Weekly = {
	{ id = "wKill", text = "Knock out %s players", kind = "kill", targets = { 50, 75 } },
	{ id = "wFinal", text = "Get %s final kills", kind = "finalKill", targets = { 15, 20 } },
	{ id = "wBed", text = "Break %s cloud beds", kind = "bed", targets = { 10, 15 } },
	{ id = "wWin", text = "Win %s matches", kind = "win", targets = { 10, 15 } },
	{ id = "wPlay", text = "Play %s matches", kind = "play", targets = { 25, 30 } },
	{ id = "wBlocks", text = "Place %s blocks", kind = "block", targets = { 400, 600 } },
	{ id = "wCrystals", text = "Collect %s Storm Crystals", kind = "crystal", targets = { 50, 80 } },
	{ id = "wDuel", text = "Win %s lobby duels", kind = "duel", targets = { 10, 15 } },
	{ id = "wLucky", text = "Open %s lucky blocks", kind = "lucky", targets = { 25, 40 } },
	{ id = "wBoss", text = "Help defeat %s Storm Dragons", kind = "boss", targets = { 2, 3 } },
} :: { Challenge }

ChallengeData.WeeklyCount = 5

-- Rewards (the battle pass reward format).
ChallengeData.DailyReward = { kind = "kit", rarity = 4 } :: SeasonData.Reward
ChallengeData.DailySparks = 1500
ChallengeData.WeeklySparks = 2500
ChallengeData.WeeklyStars = 400 -- battle pass stars
-- Finish all weekly challenges: a shiny Legendary kit, Sparks and a title.
ChallengeData.BonusReward = { kind = "kit", rarity = 5, mutated = true } :: SeasonData.Reward
ChallengeData.BonusSparks = 10000

function ChallengeData.find(id: string): Challenge?
	for _, list in { ChallengeData.Daily, ChallengeData.Weekly } do
		for _, challenge in list do
			if challenge.id == id then
				return challenge
			end
		end
	end
	return nil
end

-- Weeks since 1970, starting on Mondays (UTC).
function ChallengeData.week(now: number): number
	return math.floor((math.floor(now / 86400) + 3) / 7)
end

return ChallengeData
