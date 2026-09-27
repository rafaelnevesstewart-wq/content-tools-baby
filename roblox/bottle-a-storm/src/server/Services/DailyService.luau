-- Daily login rewards (a 7-day streak) and 3 daily quests. Both reset at
-- midnight UTC. Also answers the Rewards window (daily, quests, Storm Index).

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local RewardsData = require(Shared.RewardsData)
local StormData = require(Shared.StormData)

local Modules = script.Parent.Parent.Modules
local Notify = require(Modules.Notify)

local CaptureService = require(script.Parent.CaptureService)
local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local MixService = require(script.Parent.MixService)
local MoodService = require(script.Parent.MoodService)
local RaidService = require(script.Parent.RaidService)
local RewardService = require(script.Parent.RewardService)
local SeasonService = require(script.Parent.SeasonService)
local StealService = require(script.Parent.StealService)

local DailyService = {}

local rng = Random.new()
local lastClaim: { [Player]: number } = {}

local function today(): number
	return RewardsData.today(os.time())
end

-- Rounds to 2 significant digits so quest targets look tidy (12,345 -> 12,000).
local function tidy(value: number): number
	if value < 100 then
		return math.floor(value)
	end
	local digits = math.floor(math.log10(value)) - 1
	local unit = 10 ^ digits
	return math.floor(value / unit) * unit
end

-- Makes today's quests if the saved ones are from another day.
local function ensureQuests(player: Player, data: any)
	if data.quests.day == today() then
		return
	end
	local pool = table.clone(RewardsData.Quests)
	local list = {}
	for _ = 1, math.min(Config.Quests.PerDay, #pool) do
		local quest = table.remove(pool, rng:NextInteger(1, #pool))
		local target = quest.targets[rng:NextInteger(1, #quest.targets)]
		if quest.kind == "collect" then
			target = tidy(math.max(1000, IncomeService.rateOf(player) * 600))
		end
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
	ensureQuests(player, data)
	local ready = if dailyReady(data) then 1 else 0
	for _, quest in data.quests.list do
		if quest.progress >= quest.target and not quest.claimed then
			ready += 1
		end
	end
	player:SetAttribute("RewardsReady", ready)
	player:SetAttribute("DailyReady", dailyReady(data))
end

local function progress(player: Player, kind: string, amount: number)
	local data = DataService.get(player)
	if not data then
		return
	end
	ensureQuests(player, data)
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
	ensureQuests(player, data)
	local quest = data.quests.list[index]
	if not quest or quest.claimed or quest.progress < quest.target then
		return false, "That quest isn't finished yet."
	end
	quest.claimed = true
	local sparks =
		math.floor(math.max(Config.Quests.RewardMin, IncomeService.rateOf(player) * Config.Quests.RewardSeconds))
	data.sparks += sparks
	IncomeService.sync(player)
	SeasonService.addXp(player, Config.Quests.RewardStars)
	DailyService.sync(player)
	return true,
		"📜 Quest reward: ⚡"
			.. Format.number(sparks)
			.. " and "
			.. Config.Quests.RewardStars
			.. " ⭐ Season Stars!"
end

local function getRewards(player: Player)
	local data = DataService.get(player)
	if not data then
		return nil
	end
	ensureQuests(player, data)
	local quests = {}
	for _, quest in data.quests.list do
		local def = RewardsData.quest(quest.id)
		local target = if def and def.kind == "collect" then Format.number(quest.target) else tostring(quest.target)
		table.insert(quests, {
			text = if def then string.format(def.text, target) else quest.id,
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

	CaptureService.Caught:Connect(function(player, record)
		progress(player, "catch", 1)
		local def = StormData.get(record.id)
		if def and def.rarity >= 3 then
			progress(player, "catchRare", 1)
		end
	end)
	StealService.Stolen:Connect(function(player)
		progress(player, "steal", 1)
	end)
	MixService.Mixed:Connect(function(player)
		progress(player, "mix", 1)
	end)
	MoodService.Petted:Connect(function(player)
		progress(player, "pet", 1)
	end)
	IncomeService.Collected:Connect(function(player, amount)
		progress(player, "collect", amount)
	end)
	RaidService.Fought:Connect(function(player)
		progress(player, "raid", 1)
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
