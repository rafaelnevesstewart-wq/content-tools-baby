-- Trading storms and Sparks between two players in the same server.
--   1. A sends a request; B accepts or declines (it expires after 20 s).
--   2. Both pick up to 4 storms and some Sparks. Every change un-readies both sides.
--   3. When both press Ready, a 5 s countdown runs; any change stops it.
--   4. The server re-checks everything, swaps it all at once and saves both players.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local StormData = require(Shared.StormData)

local Modules = script.Parent.Parent.Modules
local Notify = require(Modules.Notify)

local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local PlotService = require(script.Parent.PlotService)

local TradeService = {}

type Offer = {
	storms: { string }, -- uids
	sparks: number,
	ready: boolean,
}

type Trade = {
	a: Player,
	b: Player,
	offers: { [Player]: Offer },
	version: number,
	countdownEndsAt: number?,
	closed: boolean,
}

local trades: { [Player]: Trade } = {}
local requests: { [Player]: { from: Player, at: number } } = {} -- keyed by the player asked
local lastRequest: { [Player]: number } = {}

local tradeRequest = Remotes.event("TradeRequest")
local tradeUpdate = Remotes.event("TradeUpdate")

local function partnerOf(trade: Trade, player: Player): Player
	return if trade.a == player then trade.b else trade.a
end

local function findRecord(data: any, uid: string): StormData.StormRecord?
	for _, record in data.storms do
		if record.uid == uid then
			return record
		end
	end
	return nil
end

local function offerRecords(player: Player, offer: Offer): { StormData.StormRecord }
	local data = DataService.get(player)
	local list = {}
	if data then
		for _, uid in offer.storms do
			local record = findRecord(data, uid)
			if record then
				table.insert(list, record)
			end
		end
	end
	return list
end

local function publicRecords(records: { StormData.StormRecord }): { any }
	local list = {}
	for _, record in records do
		table.insert(list, { uid = record.uid, id = record.id, mut = record.mut })
	end
	return list
end

-- What one side's window shows.
local function stateFor(trade: Trade, player: Player)
	local partner = partnerOf(trade, player)
	local mine = trade.offers[player]
	local theirs = trade.offers[partner]
	local data = DataService.get(player)
	local inventory = {}
	if data then
		for _, record in data.storms do
			table.insert(inventory, {
				uid = record.uid,
				id = record.id,
				mut = record.mut,
				stolen = PlotService.isSlotStolen(player, record.slot),
			})
		end
	end
	return {
		partnerName = partner.DisplayName,
		mine = { storms = publicRecords(offerRecords(player, mine)), sparks = mine.sparks, ready = mine.ready },
		theirs = { storms = publicRecords(offerRecords(partner, theirs)), sparks = theirs.sparks, ready = theirs.ready },
		inventory = inventory,
		countdownEndsAt = trade.countdownEndsAt,
	}
end

local function push(trade: Trade)
	for _, player in { trade.a, trade.b } do
		if player.Parent then
			tradeUpdate:FireClient(player, stateFor(trade, player))
		end
	end
end

local function close(trade: Trade, message: string?, kind: string?)
	if trade.closed then
		return
	end
	trade.closed = true
	for _, player in { trade.a, trade.b } do
		if trades[player] == trade then
			trades[player] = nil
		end
		if player.Parent then
			tradeUpdate:FireClient(player, nil)
			if message then
				Notify.player(player, message, kind or "info")
			end
		end
	end
end

-- Checks both sides can still do this trade. Returns an error message if not.
local function problem(trade: Trade): string?
	for _, player in { trade.a, trade.b } do
		local partner = partnerOf(trade, player)
		local data = DataService.get(player)
		local partnerData = DataService.get(partner)
		if not data or not partnerData then
			return "A player left."
		end
		local offer = trade.offers[player]
		for _, uid in offer.storms do
			local record = findRecord(data, uid)
			if not record then
				return player.DisplayName .. " no longer has one of those storms."
			end
			if PlotService.isSlotStolen(player, record.slot) then
				return player.DisplayName .. "'s storm is being stolen right now!"
			end
		end
		if offer.sparks > data.sparks then
			return player.DisplayName .. " doesn't have ⚡" .. Format.number(offer.sparks) .. "."
		end
		local after = #data.storms - #offer.storms + #trade.offers[partner].storms
		if after > data.pedestals then
			return player.DisplayName .. " doesn't have enough free pedestals."
		end
	end
	return nil
end

local function execute(trade: Trade)
	local issue = problem(trade)
	if issue then
		trade.offers[trade.a].ready = false
		trade.offers[trade.b].ready = false
		trade.countdownEndsAt = nil
		trade.version += 1
		push(trade)
		for _, player in { trade.a, trade.b } do
			Notify.player(player, "Trade stopped: " .. issue, "warn")
		end
		return
	end

	-- Take everything out of both profiles first, then hand it over.
	local moving: { [Player]: { StormData.StormRecord } } = {}
	for _, player in { trade.a, trade.b } do
		local data = DataService.get(player)
		local given: { StormData.StormRecord } = {}
		for _, uid in trade.offers[player].storms do
			for index, record in data.storms do
				if record.uid == uid then
					table.insert(given, table.remove(data.storms, index) :: StormData.StormRecord)
					break
				end
			end
		end
		moving[player] = given
		data.sparks -= trade.offers[player].sparks
	end
	for _, player in { trade.a, trade.b } do
		local partner = partnerOf(trade, player)
		local data = DataService.get(player)
		for _, record in moving[partner] do
			record.slot = PlotService.firstFreeSlot(player) :: number
			table.insert(data.storms, record)
			data.discovered[record.id] = true
		end
		data.sparks += trade.offers[partner].sparks
		data.stats.trades += 1
	end

	close(trade, nil)
	for _, player in { trade.a, trade.b } do
		PlotService.refreshAll(player)
		IncomeService.sync(player)
		Notify.player(player, "🤝 Trade with " .. partnerOf(trade, player).DisplayName .. " complete!", "success")
		task.spawn(DataService.saveNow, player)
	end
end

local function changed(trade: Trade)
	trade.offers[trade.a].ready = false
	trade.offers[trade.b].ready = false
	trade.countdownEndsAt = nil
	trade.version += 1
	push(trade)
end

local function startCountdown(trade: Trade)
	trade.countdownEndsAt = workspace:GetServerTimeNow() + Config.Trading.ConfirmSeconds
	local version = trade.version
	push(trade)
	task.delay(Config.Trading.ConfirmSeconds, function()
		if not trade.closed and trade.version == version and trade.countdownEndsAt then
			execute(trade)
		end
	end)
end

local function request(player: Player, targetUserId: any)
	if type(targetUserId) ~= "number" or trades[player] or not DataService.get(player) then
		return
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or target == player or not DataService.get(target) then
		return
	end
	if os.clock() - (lastRequest[player] or 0) < Config.Trading.RequestCooldown then
		Notify.player(player, "Wait a moment before sending another request.", "warn")
		return
	end
	if trades[target] then
		Notify.player(player, target.DisplayName .. " is already trading.", "warn")
		return
	end
	lastRequest[player] = os.clock()
	requests[target] = { from = player, at = os.clock() }
	tradeRequest:FireClient(target, player.UserId, player.DisplayName)
	Notify.player(player, "🤝 Trade request sent to " .. target.DisplayName .. ".", "info")
end

local function respond(player: Player, fromUserId: any, accept: any)
	local pending = requests[player]
	if not pending or pending.from.UserId ~= fromUserId then
		return
	end
	requests[player] = nil
	local from = pending.from
	if os.clock() - pending.at > Config.Trading.RequestSeconds or not from.Parent then
		Notify.player(player, "That trade request expired.", "warn")
		return
	end
	if accept ~= true then
		Notify.player(from, player.DisplayName .. " declined your trade.", "info")
		return
	end
	if trades[player] or trades[from] then
		Notify.player(player, "One of you is already trading.", "warn")
		return
	end
	local trade: Trade = {
		a = from,
		b = player,
		offers = {
			[from] = { storms = {}, sparks = 0, ready = false },
			[player] = { storms = {}, sparks = 0, ready = false },
		},
		version = 0,
		countdownEndsAt = nil,
		closed = false,
	}
	trades[from] = trade
	trades[player] = trade
	push(trade)
end

local function setStorms(player: Player, uids: any)
	local trade = trades[player]
	local data = DataService.get(player)
	if not trade or not data or type(uids) ~= "table" then
		return
	end
	local chosen = {}
	local seen = {}
	for _, uid in uids do
		if type(uid) == "string" and not seen[uid] and #chosen < Config.Trading.MaxStorms then
			local record = findRecord(data, uid)
			if record and not PlotService.isSlotStolen(player, record.slot) then
				seen[uid] = true
				table.insert(chosen, uid)
			end
		end
	end
	trade.offers[player].storms = chosen
	changed(trade)
end

local function setSparks(player: Player, amount: any)
	local trade = trades[player]
	local data = DataService.get(player)
	if not trade or not data or type(amount) ~= "number" or amount ~= amount then
		return
	end
	trade.offers[player].sparks = math.clamp(math.floor(amount), 0, math.floor(data.sparks))
	changed(trade)
end

local function setReady(player: Player, ready: any)
	local trade = trades[player]
	if not trade then
		return
	end
	local mine = trade.offers[player]
	local theirs = trade.offers[partnerOf(trade, player)]
	if #mine.storms == 0 and #theirs.storms == 0 and mine.sparks == 0 and theirs.sparks == 0 then
		Notify.player(player, "Add something to the trade first!", "warn")
		return
	end
	mine.ready = ready == true
	if not mine.ready then
		trade.countdownEndsAt = nil
		trade.version += 1
		push(trade)
		return
	end
	local issue = problem(trade)
	if issue then
		mine.ready = false
		Notify.player(player, issue, "warn")
		push(trade)
		return
	end
	if theirs.ready then
		startCountdown(trade)
	else
		push(trade)
	end
end

local actions: { [string]: (Player, ...any) -> () } = {
	request = request,
	respond = respond,
	setStorms = setStorms,
	setSparks = setSparks,
	ready = setReady,
	cancel = function(player)
		local trade = trades[player]
		if trade then
			close(trade, "Trade cancelled by " .. player.DisplayName .. ".", "info")
		end
	end,
}

function TradeService.isTrading(player: Player): boolean
	return trades[player] ~= nil
end

function TradeService.start()
	Remotes.event("TradeAction").OnServerEvent:Connect(function(player, action, ...)
		local handler = type(action) == "string" and actions[action]
		if handler then
			handler(player, ...)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local trade = trades[player]
		if trade then
			close(trade, player.DisplayName .. " left, so the trade was cancelled.", "warn")
		end
		requests[player] = nil
		lastRequest[player] = nil
	end)
end

return TradeService
