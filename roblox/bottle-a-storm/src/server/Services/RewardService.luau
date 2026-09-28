-- Hands out rewards (Sparks, kits, cosmetics) for the battle pass, daily
-- login rewards, quests, the spin wheel and codes. Also gives brand-new
-- players their first kit.

local HttpService = game:GetService("HttpService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local CosmeticsData = require(Shared.CosmeticsData)
local Format = require(Shared.Format)
local SeasonData = require(Shared.SeasonData)
local StormData = require(Shared.StormData)

local Modules = script.Parent.Parent.Modules
local Notify = require(Modules.Notify)

local CosmeticService = require(script.Parent.CosmeticService)
local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local IndexService = require(script.Parent.IndexService)

local RewardService = {}

local rng = Random.new()
local quiet: { [Player]: boolean } = {} -- set while granting silently

local function tell(player: Player, text: string, kind: string)
	if not quiet[player] then
		Notify.player(player, text, kind)
	end
end

-- A random shiny variant, rarer ones less often.
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

-- A random kit of a rarity (from the ones Kit Crates can give).
function RewardService.randomKit(rarity: number): StormData.StormDef
	local options = StormData.ofRarity(rarity)
	if #options == 0 then
		options = StormData.ofRarity(1)
	end
	return options[rng:NextInteger(1, #options)]
end

-- Adds a kit to the player's collection. Returns an error message if it
-- couldn't.
function RewardService.giveKit(player: Player, def: StormData.StormDef, mutation: string?): string?
	local data = DataService.get(player)
	if not data then
		return "Your data isn't loaded yet."
	end
	local record: StormData.StormRecord = {
		uid = HttpService:GenerateGUID(false),
		id = def.id,
		mut = mutation,
		at = os.time(),
	}
	table.insert(data.storms, record)
	IndexService.discover(player, def.id)
	IncomeService.sync(player)
	tell(player, "🎁 " .. StormData.displayName(record) .. " joined your kits! Pick it in 🌪️ Kits.", "rare")
	return nil
end

-- Gives one reward. Returns an error message if it couldn't be given, in
-- which case nothing is used up. `theme` is needed for battle pass
-- exclusives. With `silent`, no pop-up messages (the caller announces it).
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
		local amount = reward.amount or 0
		data.sparks += amount
		IncomeService.sync(player)
		tell(player, "💰 +⚡" .. Format.number(amount) .. " Sparks!", "success")
	elseif reward.kind == "kit" then
		local def = RewardService.randomKit(reward.rarity or 3)
		return RewardService.giveKit(player, def, if reward.mutated then RewardService.randomMutation() else nil)
	elseif reward.kind == "exclusive" then
		local def = theme and StormData.get(theme.storms[reward.slot or 1])
		if not def then
			return "That kit is missing."
		end
		return RewardService.giveKit(player, def, nil)
	elseif reward.kind == "cosmetic" then
		local id = reward.id or (theme and theme.cosmetics[reward.slot or 1])
		local item = CosmeticsData.get(id)
		if not id or not item then
			return "That cosmetic is missing."
		end
		if data.cosmetics.owned[item.id] then
			-- Already have it (maybe from an earlier year): Sparks instead.
			local amount = Config.Rewards.DuplicateCosmeticSparks
			data.sparks += amount
			IncomeService.sync(player)
			tell(
				player,
				"You already had " .. item.name .. ", so here's ⚡" .. Format.number(amount) .. "!",
				"success"
			)
			return nil
		end
		local problem = CosmeticService.grant(player, item.id)
		if problem then
			return problem
		end
		tell(player, "🎨 New cosmetic: " .. item.emoji .. " " .. item.name .. "! It's on now.", "rare")
	end
	return nil
end

function RewardService.start()
	-- New players get a free first kit.
	DataService.ProfileLoaded:Connect(function(player)
		local data = DataService.get(player)
		local def = StormData.get(Config.Starter.StormId)
		if not data or data.starterGiven or not def then
			return
		end
		data.starterGiven = true
		if #data.storms == 0 then
			RewardService.giveKit(player, def, nil)
			Notify.player(player, "👋 Welcome to Bed Wars! Protect your cloud bed and break everyone else's!", "info")
		end
	end)
end

return RewardService
