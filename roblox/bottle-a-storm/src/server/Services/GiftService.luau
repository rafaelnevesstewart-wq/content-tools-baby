-- 🎁 Gifting cosmetics: from 👥 Party, pick someone in the server and buy them
-- a cosmetic they don't have yet with your own Sparks. Only cosmetics sold
-- for Sparks can be gifted (not Robux, battle pass or achievement ones). The
-- gift goes straight on, both profiles are saved, and gifts count toward the
-- 🎁 Generous title.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local CosmeticsData = require(Shared.CosmeticsData)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent.Parent.Modules
local Juice = require(Modules.Juice)
local Notify = require(Modules.Notify)
local Usage = require(Modules.Usage)

local CosmeticService = require(script.Parent.CosmeticService)
local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)

local GiftService = {}

local lastGift: { [Player]: number } = {}

local function giftable(item: CosmeticsData.Item?): boolean
	return item ~= nil and item.cost > 0 and not item.robux and not item.season and not item.achievement
end

local function receiverOf(userId: any): Player?
	return if type(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
end

-- What you could gift them: every Sparks cosmetic they don't own yet.
local function getGifts(player: Player, userId: any): any
	local data = DataService.get(player)
	local receiver = receiverOf(userId)
	local theirs = receiver and DataService.get(receiver)
	if not data or not receiver or receiver == player or not theirs then
		return nil
	end
	local items = {}
	for _, item in CosmeticsData.Items do
		if giftable(item) and not theirs.cosmetics.owned[item.id] then
			table.insert(items, {
				id = item.id,
				name = item.name,
				emoji = item.emoji,
				cost = item.cost,
				category = item.category,
			})
		end
	end
	table.sort(items, function(a, b)
		return if a.cost ~= b.cost then a.cost < b.cost else a.name < b.name
	end)
	return { name = receiver.DisplayName, sparks = data.sparks, items = items }
end

local function sendGift(player: Player, userId: any, id: any): (boolean, string)
	local data = DataService.get(player)
	local receiver = receiverOf(userId)
	local theirs = receiver and DataService.get(receiver)
	local item = if type(id) == "string" then CosmeticsData.get(id) else nil
	if not data or not receiver or not theirs or receiver == player then
		return false, "They're not here anymore."
	end
	if os.clock() - (lastGift[player] or 0) < 1 then
		return false, "Slow down!"
	end
	lastGift[player] = os.clock()
	if not item or not giftable(item) then
		return false, "That one can't be gifted."
	end
	if theirs.cosmetics.owned[item.id] then
		return false, receiver.DisplayName .. " already has " .. item.name .. "!"
	end
	if data.sparks < item.cost then
		return false, "You need ⚡" .. Format.number(item.cost - data.sparks) .. " more Sparks."
	end
	data.sparks -= item.cost
	IncomeService.sync(player)
	local problem = CosmeticService.grant(receiver, item.id)
	if problem then
		data.sparks += item.cost -- give it back
		IncomeService.sync(player)
		return false, problem
	end
	data.stats.giftsGiven = (data.stats.giftsGiven or 0) + 1
	Usage.track("gift", player)
	Notify.player(
		receiver,
		"🎁 " .. player.DisplayName .. " gave you " .. item.emoji .. " " .. item.name .. "! It's on you now.",
		"rare"
	)
	Juice.sound(receiver, "win")
	Juice.sound(player, "coins")
	task.spawn(DataService.saveNow, player)
	task.spawn(DataService.saveNow, receiver)
	return true, "🎁 You gave " .. receiver.DisplayName .. " " .. item.emoji .. " " .. item.name .. "!"
end

function GiftService.start()
	Remotes.func("GetGifts").OnServerInvoke = getGifts
	Remotes.func("SendGift").OnServerInvoke = sendGift
	Players.PlayerRemoving:Connect(function(player)
		lastGift[player] = nil
	end)
end

return GiftService
