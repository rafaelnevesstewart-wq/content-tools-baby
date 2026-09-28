-- 🏟️ The 2v2 Arena Cup: every so often (LobbyEventService, between matches,
-- when no 1v1 tournament is on) sign-ups open for a minute. Players join from the chip
-- at the top right; party members are paired together, everyone else is
-- paired in the order they joined. Teams of two fight in the castle's duel
-- arena, one fight at a time, in a knockout bracket: knock both enemies out
-- (or out of the ring) to win. The champions win the most Sparks.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent.Parent.Modules
local Busy = require(Modules.Busy)
local Juice = require(Modules.Juice)
local Notify = require(Modules.Notify)
local WorldBuilder = require(Modules.WorldBuilder)
local Usage = require(Modules.Usage)

local CombatService = require(script.Parent.CombatService)
local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local LobbyService = require(script.Parent.LobbyService)
local MatchService = require(script.Parent.MatchService)

local ArenaCupService = {}

local SIGNUP_SECONDS = 60
local FIGHT_SECONDS = 90
local MAX_PLAYERS = 8
local PRIZES = { Champion = 1500, RunnerUp = 700, Joined = 150 }

type Team = { players: { Player }, name: string }
type Fight = { a: Team?, b: Team?, winner: Team? }

local state = "idle" -- "idle" | "signup" | "running"
local signupEndsAt = 0
local signups: { Player } = {}
local rounds: { { Fight } } = {}
local current: Fight? = nil
-- The fight going on: who's on which side, and who's still standing.
local side: { [Player]: Team } = {}
local standing: { [Player]: boolean } = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

local function publish()
	local list = {}
	for _, round in rounds do
		local fights = {}
		for _, fight in round do
			table.insert(fights, {
				a = if fight.a then fight.a.name else "(bye)",
				b = if fight.b then fight.b.name else "(bye)",
				winner = if fight.winner then fight.winner.name else nil,
				live = fight == current,
			})
		end
		table.insert(list, fights)
	end
	local names = {}
	for _, player in signups do
		table.insert(names, player.DisplayName)
	end
	workspace:SetAttribute("ArenaCupOn", state ~= "idle")
	workspace:SetAttribute(
		"ArenaCup",
		HttpService:JSONEncode({ state = state, signupEndsAt = signupEndsAt, players = names, rounds = list })
	)
end

local function give(player: Player, sparks: number, text: string)
	if player.Parent then
		IncomeService.addSparks(player, sparks)
		Notify.player(player, text .. " +⚡" .. sparks, "success")
	end
end

-- Pairs the sign-ups: party members together first.
local function makeTeams(): { Team }
	local left = table.clone(signups)
	local teams: { Team } = {}
	local function pair(a: Player, b: Player)
		table.insert(teams, { players = { a, b }, name = a.DisplayName .. " & " .. b.DisplayName })
	end
	local i = 1
	while i <= #left do
		local a = left[i]
		local party = a:GetAttribute("Party")
		local partner: number? = nil
		if type(party) == "string" then
			for j = i + 1, #left do
				local b = left[j]
				if b:GetAttribute("Party") == party then
					partner = j
					break
				end
			end
		end
		if partner then
			local b = table.remove(left, partner) :: Player
			table.remove(left, i)
			pair(a, b)
		else
			i += 1
		end
	end
	for k = 1, #left - 1, 2 do
		pair(left[k], left[k + 1])
	end
	if #left % 2 == 1 then
		Notify.player(left[#left], "🏟️ Sorry, there was nobody left to pair you with this time!", "info")
	end
	return teams
end

local function inFight(player: Player): boolean
	return side[player] ~= nil and standing[player] == true
end

local function spot(sideSign: number, index: number): CFrame
	local spots = WorldBuilder.LobbySpots
	local center = spots.arena + Vector3.new(0, 4, 0)
	local at = center + Vector3.new(sideSign * (spots.arenaRadius - 3), 0, (index - 1.5) * 5)
	return CFrame.lookAt(at, center)
end

local function place(player: Player, cframe: CFrame)
	local character = player.Character
	local root = rootOf(player)
	if character and root then
		root.AssemblyLinearVelocity = Vector3.zero
		character:PivotTo(cframe)
	end
end

local function teamLeft(team: Team): number
	local count = 0
	for _, player in team.players do
		if standing[player] and player.Parent then
			count += 1
		end
	end
	return count
end

local function health(team: Team): number
	local total = 0
	for _, player in team.players do
		local humanoid = humanoidOf(player)
		if standing[player] and humanoid then
			total += humanoid.Health
		end
	end
	return total
end

local function playFight(fight: Fight): Team?
	local a, b = fight.a, fight.b
	if not a or not b then
		return a or b
	end
	current = fight
	publish()
	-- Take the arena: no new 1v1 duels, and let any going on finish first.
	LobbyService.arenaTaken = true
	local waitUntil = os.clock() + 60
	while LobbyService.duelsGoingOn() > 0 and os.clock() < waitUntil do
		task.wait(1)
	end
	side = {}
	standing = {}
	for sideIndex, team in { a, b } do
		for index, player in team.players do
			-- (Someone busy elsewhere, like the boat race, sits this one out.)
			if player.Parent and Busy.reason(player) == nil then
				side[player] = team
				standing[player] = true
				player:SetAttribute("Dueling", "🏟️ 2v2")
				local humanoid = humanoidOf(player)
				if humanoid then
					humanoid.Health = humanoid.MaxHealth
				end
				CombatService.lobbyGear(player, Config.Duel.SwordTier)
				place(player, spot(if sideIndex == 1 then -1 else 1, index))
				local root = rootOf(player)
				if root then
					root.Anchored = true
				end
			end
		end
	end
	LobbyService.arenaTaken = true
	Notify.all("🏟️ Arena Cup: " .. a.name .. " vs " .. b.name .. "!", "rare")
	task.wait(3)
	for player in side do
		local root = rootOf(player)
		if root then
			root.Anchored = false
		end
		Notify.player(player, "🏟️ FIGHT! Knock both of them out (or out of the ring)!", "success")
		Juice.sound(player, "zap")
	end
	local endsAt = os.clock() + FIGHT_SECONDS
	while os.clock() < endsAt and teamLeft(a) > 0 and teamLeft(b) > 0 do
		task.wait(0.25)
		-- Stepping out of the ring, dying or leaving: you're out of this fight.
		for player in side do
			if standing[player] then
				local root = rootOf(player)
				local humanoid = humanoidOf(player)
				local spots = WorldBuilder.LobbySpots
				local flat = if root then (root.Position - spots.arena) * Vector3.new(1, 0, 1) else nil
				if
					not player.Parent
					or not root
					or not humanoid
					or humanoid.Health <= 0
					or (flat and flat.Magnitude > spots.arenaRadius + 6)
					or root.Position.Y < spots.arena.Y - 10
				then
					standing[player] = false
					if player.Parent then
						Notify.player(player, "🏟️ You're out of this fight! Cheer on your teammate.", "info")
					end
				end
			end
		end
	end
	local winner = if teamLeft(a) > teamLeft(b)
		then a
		elseif teamLeft(b) > teamLeft(a) then b
		elseif health(a) >= health(b) then a
		else b
	for player in side do
		if player.Parent then
			player:SetAttribute("Dueling", nil)
			local root = rootOf(player)
			if root then
				root.Anchored = false
			end
		end
	end
	side = {}
	standing = {}
	LobbyService.arenaTaken = false
	Notify.all("🏟️ " .. winner.name .. " win the fight!", "success")
	-- Back to the courtyard, healed.
	task.delay(1.5, function()
		for index, team in { a, b } do
			for slot, player in team.players do
				local humanoid = humanoidOf(player)
				if player.Parent and humanoid and humanoid.Health > 0 and not player:GetAttribute("InMatch") then
					humanoid.Health = humanoid.MaxHealth
					place(player, WorldBuilder.LobbySpots.spawn + Vector3.new(index * 8 - 12 + slot * 3, 4, 0))
					CombatService.lobbyGear(player, 1)
				end
			end
		end
	end)
	task.wait(3)
	return winner
end

local function run()
	local teams = makeTeams()
	if #teams < 2 then
		Notify.all("🏟️ Not enough pairs joined the Arena Cup. Next time!", "info")
		return
	end
	state = "running"
	for i = #teams, 2, -1 do
		local j = math.random(1, i)
		teams[i], teams[j] = teams[j], teams[i]
	end
	-- First round: pairs of teams (a lone team gets a bye).
	local first = {}
	for i = 1, #teams, 2 do
		table.insert(first, { a = teams[i], b = teams[i + 1] })
	end
	rounds = { first }
	publish()
	local runnerUp: Team? = nil
	local champion: Team? = nil
	while true do
		local round = rounds[#rounds]
		local winners: { Team } = {}
		for _, fight in round do
			local winner = playFight(fight)
			fight.winner = winner
			current = nil
			publish()
			if winner then
				table.insert(winners, winner)
			end
			if #round == 1 and fight.a and fight.b then
				runnerUp = if winner == fight.a then fight.b else fight.a
			end
		end
		if #winners <= 1 then
			champion = winners[1]
			break
		end
		local nextRound = {}
		for i = 1, #winners, 2 do
			table.insert(nextRound, { a = winners[i], b = winners[i + 1] })
		end
		table.insert(rounds, nextRound)
		publish()
	end
	-- Prizes.
	for _, player in signups do
		give(player, PRIZES.Joined, "🏟️ Thanks for joining the Arena Cup!")
	end
	if runnerUp then
		for _, player in runnerUp.players do
			give(player, PRIZES.RunnerUp, "🥈 Arena Cup runners-up!")
		end
	end
	if champion then
		for _, player in champion.players do
			give(player, PRIZES.Champion, "🏆 You won the 2v2 Arena Cup!")
			local data = DataService.get(player)
			if data then
				data.stats.arenaCups = (data.stats.arenaCups or 0) + 1
			end
			Juice.sound(player, "win")
		end
		Notify.all("🏆 " .. champion.name .. " won the 2v2 Arena Cup!", "rare")
	end
end

local function openSignup()
	state = "signup"
	signups = {}
	rounds = {}
	signupEndsAt = workspace:GetServerTimeNow() + SIGNUP_SECONDS
	publish()
	Notify.all("🏟️ The 2v2 Arena Cup is open! Tap 🏟️ at the top right to join (bring a friend!).", "rare")
end

local function onAction(player: Player, action: any)
	if state ~= "signup" then
		return
	end
	local index = table.find(signups, player)
	if action == "join" and not index then
		if #signups >= MAX_PLAYERS then
			Notify.player(player, "🏟️ The Arena Cup is full!", "error")
			return
		end
		local busy = Busy.reason(player)
		if busy and not player:GetAttribute("Dueling") then
			Notify.player(player, "🏟️ You can join when you're not " .. busy .. ".", "info")
			return
		end
		table.insert(signups, player)
		Usage.track("arenaCupJoin", player)
		Notify.player(player, "🏟️ You're in! The cup starts when sign-ups close.", "success")
	elseif action == "leave" and index then
		table.remove(signups, index)
	end
	publish()
end

-- Opens sign-ups now (LobbyEventService takes turns with the other lobby
-- events; admins can start one from 🧪 Test). False if it can't right now:
-- one is on, a match is playing, or a 1v1 tournament has the arena.
function ArenaCupService.startNow(): boolean
	local phase = MatchService.phase()
	local tournament = workspace:GetAttribute("Tournament")
	local tournamentOn = type(tournament) == "string" and not string.find(tournament, '"state":"idle"', 1, true)
	if state ~= "idle" or phase == "playing" or phase == "ended" or tournamentOn then
		return false
	end
	openSignup()
	return true
end

function ArenaCupService.isRunning(): boolean
	return state ~= "idle"
end

function ArenaCupService.start()
	Remotes.event("ArenaCupAction").OnServerEvent:Connect(onAction)
	CombatService.duelFoe = function(player: Player, other: Player): boolean
		return inFight(player) and inFight(other) and side[player] ~= side[other]
	end
	-- Matches wait while the cup is on (after whatever else holds them).
	local before = MatchService.pausedBy
	MatchService.pausedBy = function(): string?
		return before() or (if state ~= "idle" then "🏟️ The 2v2 Arena Cup is on in the lobby!" else nil)
	end
	Players.PlayerRemoving:Connect(function(player)
		local index = table.find(signups, player)
		if index and state == "signup" then
			table.remove(signups, index)
			publish()
		end
	end)
	publish()
	task.spawn(function()
		while true do
			task.wait(5)
			if state == "signup" and workspace:GetServerTimeNow() >= signupEndsAt then
				local ok, problem = pcall(run)
				if not ok then
					warn("[Bottle a Storm] Arena Cup failed: " .. tostring(problem))
				end
				state = "idle"
				rounds = {}
				signups = {}
				current = nil
				side = {}
				standing = {}
				LobbyService.arenaTaken = false
				publish()
			end
		end
	end)
end

return ArenaCupService
