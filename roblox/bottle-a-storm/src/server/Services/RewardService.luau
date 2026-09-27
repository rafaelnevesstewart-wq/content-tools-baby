-- Hands out rewards (Sparks, Storm Snacks, Raid Shields, storms) for the
-- season pass, daily login rewards and quests. Also gives brand-new players
-- their free starter storm.

local HttpService = game:GetService("HttpService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local SeasonData = require(Shared.SeasonData)
local StormData = require(Shared.StormData)

local Modules = script.Parent.Parent.Modules
local Notify = require(Modules.Notify)

local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local IndexService = require(script.Parent.IndexService)
local MoodService = require(script.Parent.MoodService)
local PlotService = require(script.Parent.PlotService)

local RewardService = {}

local rng = Random.new()
local quiet: { [Player]: boolean } = {} -- set while granting silently

local function tell(player: Player, text: string, kind: string)
	if not quiet[player] then
		Notify.player(player, text, kind)
	end
end

function RewardService.randomMutation(): string
	local total = 0
	for _, mutation in StormData.Mutations do
		total += mutation.weight
	end
	local pick = rng:NextNumber(0, total)
	for _, mutation in StormData.Mutations do
		pick -= mutation.weight
		if pick <= 0 then
			return mutation.id
		end
	end
	return StormData.Mutations[1].id
end

local BED_WARS = Config.GameMode == "BedWars"

-- Is there room for one more storm? (In Bed Wars storms are kits, so there's
-- no pedestal limit.)
function RewardService.hasRoom(player: Player): boolean
	return BED_WARS or PlotService.firstFreeSlot(player) ~= nil
end

-- Puts a storm on a free pedestal (in Bed Wars: into your kit collection).
-- Returns an error message if there's no room.
function RewardService.giveStorm(player: Player, def: StormData.StormDef, mutation: string?, mood: number?): string?
	local data = DataService.get(player)
	local slot = if BED_WARS then 0 else PlotService.firstFreeSlot(player)
	if not data then
		return "Your data isn't loaded yet."
	end
	if not slot then
		return "Your island is full! Make room for the storm first."
	end
	local record: StormData.StormRecord = {
		uid = HttpService:GenerateGUID(false),
		id = def.id,
		mut = mutation,
		slot = slot,
		at = os.time(),
		mood = mood or Config.Mood.Start,
	}
	table.insert(data.storms, record)
	PlotService.refreshSlot(player, slot)
	IndexService.discover(player, def.id)
	IncomeService.sync(player)
	tell(
		player,
		"🎁 "
			.. StormData.displayName(record)
			.. (if BED_WARS then " joined your kits! Pick it in 🌪️ Kits." else " is on your island!"),
		"rare"
	)
	return nil
end

-- Gives one reward. Returns an error message if it couldn't be given, in
-- which case nothing is used up. `theme` is needed for season exclusives.
-- With `silent`, no pop-up messages (the caller announces it later).
function RewardService.grant(
	player: Player,
	reward: SeasonData.Reward,
	theme: SeasonData.Theme?,
	silent: boolean?
): string?
	if silent then
		quiet[player] = true
		local ok, result = pcall(RewardService.grant, player, reward, theme, false)
		quiet[player] = nil
		return if ok then result else "Something went wrong."
	end
	local data = DataService.get(player)
	if not data then
		return "Your data isn't loaded yet."
	end
	if reward.kind == "sparks" then
		local amount = math.floor(math.max(reward.min or 0, IncomeService.rateOf(player) * 60 * (reward.minutes or 0)))
		data.sparks += amount
		IncomeService.sync(player)
		tell(player, "💰 +⚡" .. Format.number(amount) .. " Sparks!", "success")
	elseif reward.kind == "snacks" then
		if #data.storms == 0 then
			return "You don't have any storms to feed yet. Catch one first!"
		end
		MoodService.feedAll(player)
		tell(player, "🍪 Snack time! All your storms are Happy.", "success")
	elseif reward.kind == "shield" then
		data.raidShields += reward.amount or 1
		IncomeService.sync(player)
		tell(player, "🛡️ +" .. (reward.amount or 1) .. " Raid Shield!", "success")
	elseif reward.kind == "storm" then
		local options = StormData.wildOfRarity(reward.rarity or 3)
		local def = options[rng:NextInteger(1, #options)]
		return RewardService.giveStorm(player, def, if reward.mutated then RewardService.randomMutation() else nil)
	elseif reward.kind == "exclusive" then
		local def = theme and StormData.get(theme.storms[reward.slot or 1])
		if not def then
			return "That storm is missing."
		end
		return RewardService.giveStorm(player, def, nil)
	end
	return nil
end

function RewardService.start()
	-- New players get a free, happy starter storm so they earn right away
	-- (in Bed Wars it's their first kit).
	local signal = if BED_WARS then DataService.ProfileLoaded else PlotService.PlotAssigned
	signal:Connect(function(player)
		local data = DataService.get(player)
		local def = StormData.get(Config.Starter.StormId)
		if not data or data.starterGiven or not def then
			return
		end
		data.starterGiven = true
		if #data.storms == 0 then
			RewardService.giveStorm(player, def, nil, 100)
			Notify.player(
				player,
				if BED_WARS
					then "👋 Welcome to Bed Wars! Protect your cloud bed and break everyone else's!"
					else "👋 Welcome! Follow the arrow to the Wild Skies to catch more storms!",
				"info"
			)
		end
	end)
end

return RewardService
