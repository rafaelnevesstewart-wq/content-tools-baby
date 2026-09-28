-- 🌟 Challenges (see ChallengeData): a tough Daily Challenge and 5 Weekly
-- Challenges that count as you play. Claim each reward in the 🌟 window;
-- finish all the weekly ones for a bonus (a shiny Legendary kit, Sparks and
-- the Challenger title).

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local ChallengeData = require(Shared.ChallengeData)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local RewardsData = require(Shared.RewardsData)

local Modules = script.Parent.Parent.Modules
local Notify = require(Modules.Notify)

local BlockService = require(script.Parent.BlockService)
local BossService = require(script.Parent.BossService)
local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local LobbyService = require(script.Parent.LobbyService)
local LuckyService = require(script.Parent.LuckyService)
local MatchService = require(script.Parent.MatchService)
local RewardService = require(script.Parent.RewardService)
local SeasonService = require(script.Parent.SeasonService)

local ChallengeService = {}

local rng = Random.new()
local lastClaim: { [Player]: number } = {}

local function make(challenge: ChallengeData.Challenge): any
	return {
		id = challenge.id,
		target = challenge.targets[rng:NextInteger(1, #challenge.targets)],
		progress = 0,
		claimed = false,
	}
end

-- New challenges when the day or week has changed.
local function ensure(data: any)
	local c = data.challenges
	local now = os.time()
	local today = RewardsData.today(now)
	if c.day ~= today or not c.daily or not ChallengeData.find(c.daily.id) then
		c.day = today
		c.daily = make(ChallengeData.Daily[rng:NextInteger(1, #ChallengeData.Daily)])
	end
	local week = ChallengeData.week(now)
	local known = c.weekly ~= nil
	for _, entry in c.weekly or {} do
		known = known and ChallengeData.find(entry.id) ~= nil
	end
	if c.week ~= week or not known then
		c.week = week
		c.bonusClaimed = false
		local pool = table.clone(ChallengeData.Weekly)
		c.weekly = {}
		for _ = 1, math.min(ChallengeData.WeeklyCount, #pool) do
			local picked = table.remove(pool, rng:NextInteger(1, #pool)) :: ChallengeData.Challenge
			table.insert(c.weekly, make(picked))
		end
	end
end

local function progress(player: Player, kind: string, amount: number)
	local data = DataService.get(player)
	if not data then
		return
	end
	ensure(data)
	local c = data.challenges
	local entries = table.clone(c.weekly)
	table.insert(entries, c.daily)
	for _, entry in entries do
		local def = ChallengeData.find(entry.id)
		if def and def.kind == kind and entry.progress < entry.target then
			entry.progress = math.min(entry.target, entry.progress + amount)
			if entry.progress >= entry.target then
				Notify.player(player, "🌟 Challenge complete! Claim it in 🌟 Challenges.", "rare")
			end
		end
	end
end

local function describe(entry: any): any
	local def = ChallengeData.find(entry.id)
	return {
		text = if def then string.format(def.text, Format.number(entry.target)) else entry.id,
		progress = math.floor(entry.progress),
		target = entry.target,
		claimed = entry.claimed,
	}
end

local function getChallenges(player: Player): any
	local data = DataService.get(player)
	if not data then
		return nil
	end
	ensure(data)
	local c = data.challenges
	local weekly = {}
	local allDone = true
	for _, entry in c.weekly do
		table.insert(weekly, describe(entry))
		allDone = allDone and entry.claimed
	end
	local now = os.time()
	return {
		daily = describe(c.daily),
		weekly = weekly,
		bonusReady = allDone and not c.bonusClaimed,
		bonusClaimed = c.bonusClaimed,
		dayEndsIn = 86400 - now % 86400,
		weekEndsIn = (ChallengeData.week(now) + 1) * 7 * 86400 - 3 * 86400 - now,
		rewards = {
			daily = "⚡" .. Format.number(ChallengeData.DailySparks) .. " + an Epic kit",
			weekly = "⚡" .. Format.number(ChallengeData.WeeklySparks) .. " + " .. ChallengeData.WeeklyStars .. " ⭐",
			bonus = "⚡"
				.. Format.number(ChallengeData.BonusSparks)
				.. " + a shiny Legendary kit + the Challenger title",
		},
	}
end

local function claim(player: Player, which: any): (boolean, string)
	local data = DataService.get(player)
	if not data or os.clock() - (lastClaim[player] or 0) < 0.5 then
		return false, "Slow down!"
	end
	lastClaim[player] = os.clock()
	ensure(data)
	local c = data.challenges
	if which == "daily" then
		local entry = c.daily
		if entry.claimed or entry.progress < entry.target then
			return false, "Finish the challenge first!"
		end
		entry.claimed = true
		IncomeService.addSparks(player, ChallengeData.DailySparks)
		RewardService.grant(player, ChallengeData.DailyReward)
		return true, "🌟 Daily Challenge reward claimed!"
	elseif which == "bonus" then
		for _, entry in c.weekly do
			if not entry.claimed then
				return false, "Claim all the weekly challenges first!"
			end
		end
		if c.bonusClaimed then
			return false, "You already got this week's bonus!"
		end
		c.bonusClaimed = true
		data.stats.weeklyCleared = (data.stats.weeklyCleared or 0) + 1
		IncomeService.addSparks(player, ChallengeData.BonusSparks)
		RewardService.grant(player, ChallengeData.BonusReward)
		Notify.all("🌟 " .. player.DisplayName .. " finished every Weekly Challenge!", "rare")
		return true, "🌟 Weekly bonus claimed! You're a Challenger!"
	elseif type(which) == "number" then
		local entry = c.weekly[which]
		if not entry or entry.claimed or entry.progress < entry.target then
			return false, "Finish the challenge first!"
		end
		entry.claimed = true
		IncomeService.addSparks(player, ChallengeData.WeeklySparks)
		SeasonService.addXp(player, ChallengeData.WeeklyStars)
		return true, "🌟 Weekly Challenge reward claimed!"
	end
	return false, "Can't do that."
end

function ChallengeService.start()
	Remotes.func("GetChallenges").OnServerInvoke = getChallenges
	Remotes.func("ClaimChallenge").OnServerInvoke = claim

	MatchService.Killed:Connect(function(killer, _victim, final)
		progress(killer, "kill", 1)
		if final then
			progress(killer, "finalKill", 1)
		end
	end)
	MatchService.BedBroken:Connect(function(breaker)
		progress(breaker, "bed", 1)
	end)
	MatchService.Won:Connect(function(player)
		progress(player, "win", 1)
	end)
	MatchService.Played:Connect(function(player)
		progress(player, "play", 1)
	end)
	BlockService.Placed:Connect(function(player)
		progress(player, "block", 1)
	end)
	MatchService.Collected:Connect(function(player, key, amount)
		if key == "Crystals" then
			progress(player, "crystal", amount)
		end
	end)
	LobbyService.DuelWon:Connect(function(winner)
		progress(winner, "duel", 1)
	end)
	LuckyService.Opened:Connect(function(player)
		progress(player, "lucky", 1)
	end)
	BossService.Defeated:Connect(function(helpers)
		for _, player in helpers do
			progress(player, "boss", 1)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastClaim[player] = nil
	end)
end

return ChallengeService
