-- The Bed Wars Item Shop on every team island: blocks, swords, armor, bows and
-- items bought with the resources you carry, plus team upgrades bought with
-- Storm Crystals. The client window is ItemShop; this checks and pays.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local MatchData = require(Shared.MatchData)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent.Parent.Modules
local Juice = require(Modules.Juice)
local Notify = require(Modules.Notify)

local BlockService = require(script.Parent.BlockService)
local CombatService = require(script.Parent.CombatService)
local MatchService = require(script.Parent.MatchService)

local ItemShopService = {}

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

local function buyItem(player: Player, key: any): (boolean, string)
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
	if not isBlock then
		local problem = CombatService.check(player, item.key)
		if problem then
			return false, problem
		end
	end
	MatchService.spend(player, item.currency, item.cost)
	if isBlock then
		BlockService.add(player, item.key, item.amount or 1)
	else
		CombatService.give(player, item.key, item.amount)
	end
	Juice.sound(player, "coins")
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
