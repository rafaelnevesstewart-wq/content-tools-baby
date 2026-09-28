-- Daily login rewards (a 7-day streak) and 3 daily quests. Both reset at
-- midnight UTC. Also answers the Rewards window (daily, quests, Kit
-- Collection).

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local RewardsData = require(Shared.RewardsData)

local Modules = script.Parent.Parent.Modules
local Notify = require(Modules.Notify)

local BlockService = require(script.Parent.BlockService)
local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local MatchService = require(script.Parent.MatchService)
local RewardService = require(script.Parent.RewardService)
local SeasonService = require(script.Parent.SeasonService)

local DailyService = {}

local rng = Random.new()
local lastClaim: { [Player]: number } = {}

local function today(): number
	return RewardsData.today(os.time())
end

-- Makes today's quests if the saved ones are from another day.
local function ensureQuests(data: any)
	local known = true
	for _, quest in data.quests.list do
		known = known and RewardsData.quest(quest.id) ~= nil
	end
	if data.quests.day == today() and known then
		return
	end
	local pool = table.clone(RewardsData.Quests)
	local list = {}
	for _ = 1, math.min(Config.Quests.PerDay, #pool) do
		local quest = table.remove(pool, rng:NextInteger(1, #pool))
		local target = quest.targets[rng:NextInteger(1, #quest.targets)]
		table.insert(list, { id = quest.id, target = target, progress = 0, claimed = false })
	end
	data.quests = { day = today(), list = list }
end

local function dailyReady(data: any): boolean
	return data.daily.lastDay < today()
end

-- The streak day you'd get if you claimed now (1-7).
local function nextStreak(data: any): number
	if data.daily.lastDay == today() - 1 then
		return data.daily.streak % #RewardsData.Daily + 1
	end
	return 1
end

function DailyService.sync(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	ensureQuests(data)
	local ready = if dailyReady(data) then 1 else 0
	if data.spin.day < today() or data.spin.extra > 0 then
		ready += 1 -- a wheel spin is waiting
	end
	for _, quest in data.quests.list do
		if quest.progress >= quest.target and not quest.claimed then
			ready += 1
		end
	end
	player:SetAttribute("RewardsReady", ready)
	player:SetAttribute("DailyReady", dailyReady(data))
	player:SetAttribute("FreeSpin", data.spin.day < today())
	player:SetAttribute("ExtraSpins", data.spin.extra)
end

local function progress(player: Player, kind: string, amount: number)
	local data = DataService.get(player)
	if not data then
		return
	end
	ensureQuests(data)
	for _, quest in data.quests.list do
		local def = RewardsData.quest(quest.id)
		if def and def.kind == kind and quest.progress < quest.target then
			quest.progress = math.min(quest.target, quest.progress + amount)
			if quest.progress >= quest.target then
				Notify.player(player, "📜 Quest complete! Claim your reward in 🎁 Rewards.", "rare")
			end
			DailyService.sync(player)
		end
	end
end

local function claimDaily(player: Player): (boolean, string)
	local data = DataService.get(player)
	if not data or os.clock() - (lastClaim[player] or 0) < 0.5 then
		return false, "Slow down!"
	end
	lastClaim[player] = os.clock()
	if not dailyReady(data) then
		return false, "You already claimed today's reward. Come back tomorrow!"
	end
	local streak = nextStreak(data)
	local problem = RewardService.grant(player, RewardsData.Daily[streak], nil)
	if problem then
		return false, problem
	end
	data.daily = { lastDay = today(), streak = streak }
	DailyService.sync(player)
	return true, "📅 Day " .. streak .. " reward claimed!"
end

local function claimQuest(player: Player, index: any): (boolean, string)
	local data = DataService.get(player)
	if not data or type(index) ~= "number" or os.clock() - (lastClaim[player] or 0) < 0.3 then
		return false, "Can't claim that."
	end
	lastClaim[player] = os.clock()
	ensureQuests(data)
	local quest = data.quests.list[index]
	if not quest or quest.claimed or quest.progress < quest.target then
		return false, "That quest isn't finished yet."
	end
	quest.claimed = true
	local sparks = Config.Quests.RewardSparks
	data.sparks += sparks
	IncomeService.sync(player)
	SeasonService.addXp(player, Config.Quests.RewardStars)
	DailyService.sync(player)
	return true,
		"📜 Quest reward: ⚡"
			.. Format.number(sparks)
			.. " and "
			.. Config.Quests.RewardStars
			.. " ⭐ battle pass stars!"
end

local function getRewards(player: Player)
	local data = DataService.get(player)
	if not data then
		return nil
	end
	ensureQuests(data)
	local quests = {}
	for _, quest in data.quests.list do
		local def = RewardsData.quest(quest.id)
		table.insert(quests, {
			text = if def then string.format(def.text, Format.number(quest.target)) else quest.id,
			progress = math.floor(quest.progress),
			target = quest.target,
			claimed = quest.claimed,
		})
	end
	local discovered = {}
	for id in data.discovered do
		table.insert(discovered, id)
	end
	return {
		dailyReady = dailyReady(data),
		nextStreak = nextStreak(data),
		streak = data.daily.streak,
		quests = quests,
		discovered = discovered,
		rows = data.indexRows or 0,
	}
end

function DailyService.start()
	Remotes.func("GetRewards").OnServerInvoke = getRewards
	Remotes.func("ClaimDaily").OnServerInvoke = claimDaily
	Remotes.func("ClaimQuest").OnServerInvoke = claimQuest
	DataService.ProfileLoaded:Connect(DailyService.sync)

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

	Players.PlayerRemoving:Connect(function(player)
		lastClaim[player] = nil
	end)

	-- Notice midnight for players who stay online.
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				DailyService.sync(player)
			end
		end
	end)
end

return DailyService
