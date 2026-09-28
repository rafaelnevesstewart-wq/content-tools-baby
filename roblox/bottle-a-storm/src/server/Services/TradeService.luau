-- 🤝 Trading kits, cosmetics and Sparks with another player in the server
-- (press 🤝 Trade next to them in the 👥 Party window). Both put in what
-- they offer, both press Ready, then both press Confirm. Changing an offer
-- un-readies both. Everything is checked again right before the swap, and
-- both profiles are saved straight after. Robux cosmetics and free ones
-- can't be traded. Trades are only possible outside matches.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local CosmeticsData = require(Shared.CosmeticsData)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local StormData = require(Shared.StormData)

local Modules = script.Parent.Parent.Modules
local Notify = require(Modules.Notify)

local CosmeticService = require(script.Parent.CosmeticService)
local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local IndexService = require(script.Parent.IndexService)
local MatchService = require(script.Parent.MatchService)

local TradeService = {}

type Offer = { kits: { string }, cosmetics: { string }, sparks: number }
type Trade = {
	a: Player,
	b: Player,
	offers: { [Player]: Offer },
	ready: { [Player]: boolean },
	confirmed: { [Player]: boolean },
}

local tradeOf: { [Player]: Trade } = {}
local requests: { [Player]: { [Player]: number } } = {} -- asked -> asker -> when
local lastAction: { [Player]: number } = {}

local function partner(trade: Trade, player: Player): Player
	return if trade.a == player then trade.b else trade.a
end

local function tradeable(item: CosmeticsData.Item?): boolean
	return item ~= nil and not item.robux and item.cost > 0
end

local function findKit(data: any, uid: string): (StormData.StormRecord?, number?)
	for index, record in data.storms do
		if record.uid == uid then
			return record, index
		end
	end
	return nil, nil
end

-- What a player can put in a trade.
local function inventory(player: Player): any
	local data = DataService.get(player)
	if not data then
		return nil
	end
	local kits = {}
	for _, record in data.storms do
		local def = StormData.get(record.id)
		if def then
			table.insert(kits, {
				uid = record.uid,
				name = StormData.displayName(record),
				rarity = def.rarity,
				rarityName = StormData.rarityOf(def).name,
			})
		end
	end
	table.sort(kits, function(x, y)
		return x.rarity > y.rarity
	end)
	local cosmetics = {}
	for id in data.cosmetics.owned do
		local item = CosmeticsData.get(id)
		if item and tradeable(item) then
			table.insert(cosmetics, { id = id, name = item.name, emoji = item.emoji })
		end
	end
	table.sort(cosmetics, function(x, y)
		return x.name < y.name
	end)
	return { kits = kits, cosmetics = cosmetics, sparks = data.sparks }
end

local function describe(player: Player, offer: Offer): { string }
	local data = DataService.get(player)
	local lines = {}
	for _, uid in offer.kits do
		local record = data and findKit(data, uid)
		table.insert(lines, "🌪️ " .. (if record then StormData.displayName(record) else "?"))
	end
	for _, id in offer.cosmetics do
		local item = CosmeticsData.get(id)
		table.insert(lines, if item then item.emoji .. " " .. item.name else id)
	end
	if offer.sparks > 0 then
		table.insert(lines, "⚡ " .. Format.number(offer.sparks) .. " Sparks")
	end
	return lines
end

local function send(trade: Trade)
	for _, player in { trade.a, trade.b } do
		local other = partner(trade, player)
		if player.Parent then
			Remotes.event("TradeUpdate"):FireClient(player, {
				open = true,
				partner = other.DisplayName,
				mine = describe(player, trade.offers[player]),
				theirs = describe(other, trade.offers[other]),
				mineRaw = trade.offers[player],
				readyMine = trade.ready[player] == true,
				readyTheirs = trade.ready[other] == true,
				confirmMine = trade.confirmed[player] == true,
				confirmTheirs = trade.confirmed[other] == true,
			})
		end
	end
end

local function close(trade: Trade, message: string)
	for _, player in { trade.a, trade.b } do
		if tradeOf[player] == trade then
			tradeOf[player] = nil
		end
		if player.Parent then
			Remotes.event("TradeUpdate"):FireClient(player, { open = false, message = message })
		end
	end
end

local function unready(trade: Trade)
	trade.ready = {}
	trade.confirmed = {}
end

-- Checks both offers are still real. Returns a problem, or nil.
local function check(trade: Trade): string?
	for _, player in { trade.a, trade.b } do
		local data = DataService.get(player)
		local otherData = DataService.get(partner(trade, player))
		if not data or not otherData or not player.Parent then
			return "Someone left."
		end
		local offer = trade.offers[player]
		if offer.sparks > data.sparks then
			return player.DisplayName .. " doesn't have that many Sparks anymore."
		end
		for _, uid in offer.kits do
			if not findKit(data, uid) then
				return player.DisplayName .. " doesn't have a kit they offered anymore."
			end
		end
		for _, id in offer.cosmetics do
			if not data.cosmetics.owned[id] or not tradeable(CosmeticsData.get(id)) then
				return player.DisplayName .. " doesn't have a cosmetic they offered anymore."
			end
			if otherData.cosmetics.owned[id] then
				return partner(trade, player).DisplayName .. " already has " .. id .. "."
			end
		end
	end
	return nil
end

local function execute(trade: Trade)
	local problem = check(trade)
	if problem then
		close(trade, "Trade cancelled: " .. problem)
		return
	end
	local moves = {}
	for _, giver in { trade.a, trade.b } do
		local receiver = partner(trade, giver)
		table.insert(moves, {
			giver = giver,
			receiver = receiver,
			from = DataService.get(giver),
			to = DataService.get(receiver),
			offer = trade.offers[giver],
		})
	end
	for _, move in moves do
		local from, to, offer = move.from, move.to, move.offer
		for _, uid in offer.kits do
			local record, index = findKit(from, uid)
			if record and index then
				table.remove(from.storms, index)
				table.insert(to.storms, record)
				if from.kit == uid then
					from.kit = nil
				end
				IndexService.discover(move.receiver, record.id)
			end
		end
		for _, id in offer.cosmetics do
			from.cosmetics.owned[id] = nil
			to.cosmetics.owned[id] = true
		end
		from.sparks -= offer.sparks
		to.sparks += offer.sparks
	end
	for _, player in { trade.a, trade.b } do
		IncomeService.sync(player)
		CosmeticService.refreshAll(player)
		task.spawn(DataService.saveNow, player)
	end
	close(trade, "🤝 Trade complete!")
	Notify.player(trade.a, "🤝 Trade with " .. trade.b.DisplayName .. " complete!", "success")
	Notify.player(trade.b, "🤝 Trade with " .. trade.a.DisplayName .. " complete!", "success")
end

local function busy(player: Player): boolean
	return tradeOf[player] ~= nil or player:GetAttribute("InMatch") == true or DataService.get(player) == nil
end

local function onAction(player: Player, action: any, a: any, b: any)
	if type(action) ~= "string" or os.clock() - (lastAction[player] or 0) < 0.2 then
		return
	end
	lastAction[player] = os.clock()
	local trade = tradeOf[player]

	if action == "request" or action == "accept" or action == "decline" then
		local other = type(a) == "number" and Players:GetPlayerByUserId(a)
		if not other or other == player then
			return
		end
		if action == "request" then
			if busy(player) or busy(other) then
				Notify.player(player, "🤝 One of you is busy (in a match or another trade).", "error")
				return
			end
			requests[other] = requests[other] or {}
			requests[other][player] = os.clock()
			Remotes.event("TradeInvite"):FireClient(other, player.UserId, player.DisplayName)
			Notify.player(player, "🤝 Trade request sent to " .. other.DisplayName .. "!", "info")
		elseif action == "accept" then
			local sent = requests[player] and requests[player][other]
			if requests[player] then
				requests[player][other] = nil
			end
			if not sent or os.clock() - sent > Config.Trade.RequestSeconds then
				Notify.player(player, "🤝 That request ran out.", "error")
			elseif busy(player) or busy(other) then
				Notify.player(player, "🤝 One of you is busy right now.", "error")
			else
				local newTrade: Trade = {
					a = other,
					b = player,
					offers = {
						[other] = { kits = {}, cosmetics = {}, sparks = 0 },
						[player] = { kits = {}, cosmetics = {}, sparks = 0 },
					},
					ready = {},
					confirmed = {},
				}
				tradeOf[other] = newTrade
				tradeOf[player] = newTrade
				send(newTrade)
			end
		else
			if requests[player] and requests[player][other] then
				requests[player][other] = nil
				Notify.player(other, "🤝 " .. player.DisplayName .. " said no thanks.", "info")
			end
		end
		return
	end

	if not trade then
		return
	end
	local data = DataService.get(player)
	local offer = trade.offers[player]
	if not data then
		return
	end
	if action == "cancel" then
		close(trade, "Trade cancelled.")
		return
	elseif action == "add" or action == "remove" then
		local list = if a == "kit" then offer.kits elseif a == "cosmetic" then offer.cosmetics else nil
		if not list or type(b) ~= "string" then
			return
		end
		local index = table.find(list, b)
		if action == "remove" then
			if index then
				table.remove(list, index)
			end
		elseif not index and #offer.kits + #offer.cosmetics < Config.Trade.MaxItems then
			local owned = if a == "kit"
				then findKit(data, b) ~= nil
				else data.cosmetics.owned[b] == true and tradeable(CosmeticsData.get(b))
			local otherData = DataService.get(partner(trade, player))
			if a == "cosmetic" and otherData and otherData.cosmetics.owned[b] then
				Notify.player(player, "🤝 They already have that one!", "error")
				return
			end
			if owned then
				table.insert(list, b)
			end
		end
		unready(trade)
	elseif action == "sparks" then
		if type(a) ~= "number" or a ~= a then
			return
		end
		offer.sparks = math.clamp(math.floor(a), 0, data.sparks)
		unready(trade)
	elseif action == "ready" then
		trade.ready[player] = not trade.ready[player]
		trade.confirmed = {}
	elseif action == "confirm" then
		if trade.ready[trade.a] and trade.ready[trade.b] then
			trade.confirmed[player] = true
			if trade.confirmed[trade.a] and trade.confirmed[trade.b] then
				execute(trade)
				return
			end
		end
	end
	send(trade)
end

function TradeService.start()
	Remotes.event("TradeAction").OnServerEvent:Connect(onAction)
	Remotes.func("GetTradeInventory").OnServerInvoke = inventory
	Players.PlayerRemoving:Connect(function(player)
		local trade = tradeOf[player]
		if trade then
			close(trade, "Trade cancelled: " .. player.DisplayName .. " left.")
		end
		requests[player] = nil
		lastAction[player] = nil
		for _, list in requests do
			list[player] = nil
		end
	end)
	-- A match starting cancels trades.
	MatchService.MatchStarted:Connect(function()
		local seen: { [Trade]: boolean } = {}
		for _, trade in tradeOf do
			if not seen[trade] then
				seen[trade] = true
				close(trade, "Trade cancelled: a match is starting.")
			end
		end
	end)
end

return TradeService
