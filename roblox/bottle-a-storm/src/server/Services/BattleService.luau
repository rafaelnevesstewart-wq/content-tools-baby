-- Storm battles: challenge another player; your 3 strongest storms fight
-- theirs, one at a time. The server works out the whole fight up front and
-- sends it to both players' battle windows to play back. Nobody loses a
-- storm: the winner gets Sparks and the loser a small thank-you.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local BattleData = require(Shared.BattleData)
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local RewardsData = require(Shared.RewardsData)
local StormData = require(Shared.StormData)

local Modules = script.Parent.Parent.Modules
local Notify = require(Modules.Notify)

local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)

local BattleService = {}

type Fighter = {
	name: string,
	id: string,
	mut: string?,
	level: number,
	element: string,
	attack: number,
	hp: number,
	maxHp: number,
}

local pending: { [Player]: { from: Player, at: number } } = {} -- invites waiting on the target
local lastRequest: { [Player]: number } = {}
local busyUntil: { [Player]: number } = {} -- in a battle, then on cooldown
local rng = Random.new()

local function teamOf(data: any): { Fighter }
	local records = table.clone(data.storms)
	table.sort(records, function(a, b)
		return BattleData.attackOf(a) > BattleData.attackOf(b)
	end)
	local team = {}
	for i = 1, math.min(Config.Battle.TeamSize, #records) do
		local record = records[i]
		local def = StormData.get(record.id)
		if def then
			local hp = BattleData.hpOf(record)
			table.insert(team, {
				name = StormData.displayName(record),
				id = record.id,
				mut = record.mut,
				level = StormData.levelOf(record),
				element = BattleData.elementOf(def).key,
				attack = BattleData.attackOf(record),
				hp = hp,
				maxHp = hp,
			})
		end
	end
	return team
end

local function totalHp(team: { Fighter }): number
	local sum = 0
	for _, fighter in team do
		sum += math.max(0, fighter.hp) / fighter.maxHp
	end
	return sum
end

-- Plays out the fight. Returns the list of hits and the winning side (1 or 2).
local function simulate(teams: { { Fighter } }): ({ any }, number)
	local events = {}
	local front = { 1, 1 }
	-- The side with the stronger lead storm goes first (a coin flip if equal).
	local lead1, lead2 = teams[1][1].attack, teams[2][1].attack
	local side = if lead1 > lead2 then 1 elseif lead2 > lead1 then 2 else rng:NextInteger(1, 2)
	local turns = 0
	while front[1] <= #teams[1] and front[2] <= #teams[2] and turns < Config.Battle.MaxTurns do
		turns += 1
		local other = 3 - side
		local attacker = teams[side][front[side]]
		local defender = teams[other][front[other]]
		local advantage = BattleData.advantage(
			BattleData.Elements[attacker.element],
			BattleData.Elements[defender.element],
			Config.Battle.AdvantageMultiplier
		)
		local crit = rng:NextNumber() < Config.Battle.CritChance
		local damage = math.max(
			1,
			math.floor(
				attacker.attack
					* rng:NextNumber(0.85, 1.15)
					* advantage
					* (if crit then Config.Battle.CritMultiplier else 1)
			)
		)
		defender.hp -= damage
		local fainted = defender.hp <= 0
		table.insert(events, {
			side = side,
			attacker = front[side],
			defender = front[other],
			damage = damage,
			crit = crit,
			effect = if advantage > 1 then 1 elseif advantage < 1 then -1 else 0,
			hp = math.max(0, math.floor(defender.hp)),
			fainted = fainted,
		})
		if fainted then
			front[other] += 1
		end
		side = other
	end
	local winner
	if front[1] > #teams[1] then
		winner = 2
	elseif front[2] > #teams[2] then
		winner = 1
	else
		-- Out of turns: whoever has more HP left wins.
		winner = if totalHp(teams[1]) >= totalHp(teams[2]) then 1 else 2
	end
	return events, winner
end

-- Pays the winner (and a little to the loser), up to a daily limit.
local function payout(player: Player, won: boolean)
	local data = DataService.get(player)
	if not data then
		return
	end
	local today = RewardsData.today(os.time())
	if data.battles.day ~= today then
		data.battles = { day = today, wins = 0, losses = 0 }
	end
	local key = if won then "wins" else "losses"
	local count = data.battles[key] or 0
	if won then
		data.stats.battlesWon += 1
	end
	if count >= Config.Battle.PrizesPerDay then
		Notify.player(
			player,
			if won
				then "🏆 You won! (You've had today's " .. Config.Battle.PrizesPerDay .. " prize wins. More tomorrow!)"
				else "Good fight! Train your storms and try again.",
			"info"
		)
		return
	end
	data.battles[key] = count + 1
	local rate = IncomeService.rateOf(player)
	local amount = if won
		then math.max(Config.Battle.PrizeMin, rate * Config.Battle.PrizeSeconds)
		else math.max(Config.Battle.ConsolationMin, rate * Config.Battle.ConsolationSeconds)
	amount = math.floor(amount)
	IncomeService.addSparks(player, amount)
	if won then
		Notify.player(player, "🏆 You won the battle! +⚡" .. Format.number(amount), "rare")
	else
		Notify.player(player, "💪 Good fight! +⚡" .. Format.number(amount) .. " for trying.", "info")
	end
end

-- nil if `player` can battle now, else why not (written for `viewer`).
local function whyNot(player: Player, viewer: Player): string?
	local data = DataService.get(player)
	local you = player == viewer
	local name = player.DisplayName
	if workspace:GetAttribute("RaidState") == "active" then
		return "No battles during the Mega-Storm!"
	elseif not data then
		return if you then "Your island isn't ready yet." else name .. " isn't ready yet."
	elseif #data.storms == 0 then
		return if you then "You need at least one storm to battle!" else name .. " has no storms yet."
	elseif (busyUntil[player] or 0) > os.clock() then
		return if you
			then "Your storms are resting after a battle. Try again soon!"
			else name .. "'s storms are resting after a battle. Try again soon!"
	end
	return nil
end

local function start(a: Player, b: Player)
	local dataA, dataB = DataService.get(a), DataService.get(b)
	if not dataA or not dataB then
		return
	end
	local teams = { teamOf(dataA), teamOf(dataB) }
	if #teams[1] == 0 or #teams[2] == 0 then
		return
	end
	-- Copy the teams before the fight changes their HP.
	local shown = {}
	for index, team in teams do
		local list = {}
		for _, fighter in team do
			table.insert(list, {
				name = fighter.name,
				id = fighter.id,
				mut = fighter.mut,
				level = fighter.level,
				element = fighter.element,
				maxHp = math.floor(fighter.maxHp),
			})
		end
		shown[index] = list
	end
	local events, winner = simulate(teams)
	local players = { a, b }
	local battle = {
		sides = {
			{ userId = a.UserId, name = a.DisplayName, team = shown[1] },
			{ userId = b.UserId, name = b.DisplayName, team = shown[2] },
		},
		events = events,
		winner = winner,
	}
	local seconds = #events * Config.Battle.PlaybackTurnSeconds + 2.5
	for _, player in players do
		busyUntil[player] = os.clock() + seconds + Config.Battle.Cooldown
		Remotes.event("BattlePlay"):FireClient(player, battle)
	end
	-- Pay out once the fight has finished playing on screen.
	task.delay(seconds, function()
		for index, player in players do
			if player.Parent then
				payout(player, index == winner)
			end
		end
		local winnerPlayer = players[winner]
		if winnerPlayer.Parent then
			Notify.allExcept(winnerPlayer, "⚔️ " .. winnerPlayer.DisplayName .. " won a storm battle!", "info")
		end
	end)
end

local function request(player: Player, targetId: any)
	if type(targetId) ~= "number" or os.clock() - (lastRequest[player] or 0) < Config.Battle.RequestCooldown then
		return
	end
	lastRequest[player] = os.clock()
	local target = Players:GetPlayerByUserId(targetId)
	if not target or target == player then
		return
	end
	local why = whyNot(player, player) or whyNot(target, player)
	if why then
		Notify.player(player, why, "warn")
		return
	end
	pending[target] = { from = player, at = os.clock() }
	Remotes.event("BattleInvite"):FireClient(target, player.UserId, player.DisplayName)
	Notify.player(player, "⚔️ Challenge sent to " .. target.DisplayName .. "!", "info")
end

local function respond(player: Player, fromId: any, accept: any)
	local invite = pending[player]
	if not invite or invite.from.UserId ~= fromId then
		return
	end
	pending[player] = nil
	local from = invite.from
	if not from.Parent or os.clock() - invite.at > Config.Battle.RequestSeconds then
		Notify.player(player, "That challenge ran out.", "info")
		return
	end
	if accept ~= true then
		Notify.player(from, player.DisplayName .. " said no to the battle this time.", "info")
		return
	end
	local why = whyNot(from, from) or whyNot(player, from)
	if why then
		Notify.player(from, why, "warn")
		Notify.player(player, whyNot(player, player) or whyNot(from, player) or why, "warn")
		return
	end
	start(from, player)
end

function BattleService.start()
	Remotes.event("BattleAction").OnServerEvent:Connect(function(player, action, a, b)
		if action == "request" then
			request(player, a)
		elseif action == "respond" then
			respond(player, a, b)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		pending[player] = nil
		lastRequest[player] = nil
		busyUntil[player] = nil
	end)
end

return BattleService
