-- The Bed Wars Item Shop on every team island: blocks, swords, armor, bows,
-- tools (pickaxes, axes), TNT, fireballs, potions and other items bought with
-- the resources you carry, plus team upgrades bought with
-- Storm Crystals. The client window is ItemShop; this checks and pays.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local MatchData = require(Shared.MatchData)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Signal)

local Modules = script.Parent.Parent.Modules
local Juice = require(Modules.Juice)
local Notify = require(Modules.Notify)

local BlockService = require(script.Parent.BlockService)
local CombatService = require(script.Parent.CombatService)
local GadgetService = require(script.Parent.GadgetService)
local MatchService = require(script.Parent.MatchService)

local ItemShopService = {}

ItemShopService.Bought = Signal.new() -- (player, itemKey) bought an item in a match

local lastBuy: { [Player]: number } = {}

local function resourceEmoji(key: string): string
	for _, resource in MatchData.Resources do
		if resource.key == key then
			return resource.emoji
		end
	end
	return ""
end

local function tooFast(player: Player): boolean
	if os.clock() - (lastBuy[player] or 0) < 0.15 then
		return true
	end
	lastBuy[player] = os.clock()
	return false
end

local function pay(player: Player, cost: number, currency: string): string?
	local have = MatchService.resource(player, currency)
	if have < cost then
		return "You need " .. cost - have .. " more " .. resourceEmoji(currency) .. " " .. currency .. "."
	end
	MatchService.spend(player, currency, cost)
	return nil
end

-- Pickaxes and axes: each purchase is the next tier.
local function buyTool(player: Player, key: string): (boolean, string)
	local tier = GadgetService.nextTool(player, key)
	if not tier then
		return false, "You already have the best one!"
	end
	local problem = pay(player, tier.cost, tier.currency)
	if problem then
		return false, problem
	end
	GadgetService.give(player, key)
	Juice.sound(player, "coins")
	ItemShopService.Bought:Fire(player, key)
	return true, MatchData.Tools[key].emoji .. " Got the " .. tier.name .. "!"
end

local function buyItem(player: Player, key: any): (boolean, string)
	if type(key) == "string" and MatchData.Tools[key] then
		if not MatchService.isPlaying(player) or tooFast(player) then
			return false, "You can only shop during a match."
		end
		return buyTool(player, key)
	end
	local item = type(key) == "string" and MatchData.shopItem(key)
	if not item or not MatchService.isPlaying(player) or tooFast(player) then
		return false, "You can only shop during a match."
	end
	local have = MatchService.resource(player, item.currency)
	if have < item.cost then
		return false,
			"You need " .. item.cost - have .. " more " .. resourceEmoji(item.currency) .. " " .. item.currency .. "."
	end
	-- Check it can be given before paying.
	local isBlock = MatchData.Blocks[item.key] ~= nil
	local isGadget = GadgetService.handles(item.key)
	local gadgetProblem = if isGadget then GadgetService.problem(player, item.key) else nil
	if gadgetProblem then
		return false, gadgetProblem
	end
	if not isBlock and not isGadget then
		local problem = CombatService.check(player, item.key)
		if problem then
			return false, problem
		end
	end
	MatchService.spend(player, item.currency, item.cost)
	if isBlock then
		BlockService.add(player, item.key, item.amount or 1)
	elseif isGadget then
		GadgetService.give(player, item.key)
	else
		CombatService.give(player, item.key, item.amount)
	end
	Juice.sound(player, "coins")
	ItemShopService.Bought:Fire(player, item.key)
	return true, item.emoji .. " Bought " .. item.name .. "!"
end

local function buyUpgrade(player: Player, key: any): (boolean, string)
	local upgrade = type(key) == "string" and MatchData.upgrade(key)
	local team = MatchService.teamOf(player)
	if not upgrade or not team or not MatchService.isPlaying(player) or tooFast(player) then
		return false, "You can only buy upgrades during a match."
	end
	local level = team.upgrades[upgrade.key] or 0
	local cost = upgrade.costs[level + 1]
	if not cost then
		return false, "Your team already has the best " .. upgrade.name .. "!"
	end
	local have = MatchService.resource(player, "Crystals")
	if have < cost then
		return false, "You need " .. cost - have .. " more 💎 Storm Crystals."
	end
	MatchService.spend(player, "Crystals", cost)
	team.upgrades[upgrade.key] = level + 1
	-- Everyone on the team sees the level in their shop.
	for _, member in team.members do
		if member.Parent then
			member:SetAttribute("Upgrade_" .. upgrade.key, level + 1)
			Notify.player(
				member,
				upgrade.emoji
					.. " "
					.. player.DisplayName
					.. " bought "
					.. upgrade.name
					.. " "
					.. level + 1
					.. " for the team!",
				"success"
			)
		end
	end
	Juice.sound(player, "chime")
	return true, upgrade.emoji .. " " .. upgrade.name .. " " .. level + 1 .. "!"
end

function ItemShopService.start()
	Remotes.func("BuyMatchItem").OnServerInvoke = buyItem
	Remotes.func("BuyUpgrade").OnServerInvoke = buyUpgrade
	MatchService.MatchEnded:Connect(function()
		for _, player in Players:GetPlayers() do
			for _, upgrade in MatchData.Upgrades do
				player:SetAttribute("Upgrade_" .. upgrade.key, nil)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastBuy[player] = nil
	end)
end

return ItemShopService
