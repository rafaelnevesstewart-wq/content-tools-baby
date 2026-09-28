-- 🏆 Weekend tournaments: a 1v1 knockout bracket in the castle's duel arena.
-- On Saturdays and Sundays (UTC) one opens every Config.Tournament.
-- EveryMinutes (admins can start one any time). Players sign up for a minute,
-- then fight one duel at a time; winners go through to the next round until
-- one champion is left. Everyone who joins gets a prize, and more the
-- further they get. Matches wait while a tournament is on. The bracket shows
-- on the board in the courtyard and on everyone's screen (TournamentHUD).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent.Parent.Modules
local Notify = require(Modules.Notify)
local WorldBuilder = require(Modules.WorldBuilder)

local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local LobbyService = require(script.Parent.LobbyService)
local MatchService = require(script.Parent.MatchService)

local TournamentService = {}

type Fight = { a: Player?, b: Player?, winner: Player? }

local state = "idle" -- "idle" | "signup" | "running"
local signupEndsAt = 0
local entrants: { Player } = {}
local rounds: { { Fight } } = {}
local current: Fight? = nil
local lastSlot = -1
local boardRows: { TextLabel } = {}
local boardTitle: TextLabel

local function nameOf(player: Player?): string
	return if player then player.DisplayName else "(bye)"
end

local function roundName(index: number, total: number): string
	if index == total then
		return "Final"
	elseif index == total - 1 then
		return "Semifinals"
	elseif index == total - 2 then
		return "Quarterfinals"
	end
	return "Round " .. index
end

-- Shares the bracket with every screen and the courtyard board.
local function publish()
	local list = {}
	for _, round in rounds do
		local fights = {}
		for _, fight in round do
			table.insert(fights, {
				a = nameOf(fight.a),
				b = nameOf(fight.b),
				winner = if fight.winner then fight.winner.DisplayName else nil,
				live = fight == current,
			})
		end
		table.insert(list, fights)
	end
	local names = {}
	for _, player in entrants do
		table.insert(names, player.DisplayName)
	end
	workspace:SetAttribute(
		"Tournament",
		HttpService:JSONEncode({
			state = state,
			signupEndsAt = signupEndsAt,
			entrants = names,
			rounds = list,
			max = Config.Tournament.MaxPlayers,
		})
	)
	-- The board: one line per fight.
	if boardTitle then
		boardTitle.Text = if state == "idle"
			then "🏆 Weekend Tournament\nSaturdays & Sundays!"
			elseif state == "signup" then "🏆 Sign up now! (" .. #entrants .. " joined)"
			else "🏆 Tournament"
		local lines = {}
		for index, round in list do
			table.insert(lines, "— " .. roundName(index, math.max(#list, 1)) .. " —")
			for _, fight in round do
				local a = if fight.winner == fight.a then "✅ " .. fight.a else fight.a
				local b = if fight.winner == fight.b then "✅ " .. fight.b else fight.b
				table.insert(lines, (if fight.live then "⚔️ " else "") .. a .. "  vs  " .. b)
			end
		end
		for index, row in boardRows do
			row.Text = lines[index] or ""
		end
	end
end

local function give(player: Player, sparks: number, text: string)
	if player.Parent then
		IncomeService.addSparks(player, sparks)
		Notify.player(player, text .. " +⚡" .. sparks, "success")
	end
end

local function openSignup(byName: string?)
	if state ~= "idle" then
		return false
	end
	state = "signup"
	entrants = {}
	rounds = {}
	current = nil
	signupEndsAt = workspace:GetServerTimeNow() + Config.Tournament.SignupSeconds
	Notify.all(
		"🏆 "
			.. (if byName then byName .. " started a" else "The Weekend")
			.. " Tournament! Press Join (top of the screen) in the next "
			.. Config.Tournament.SignupSeconds
			.. " seconds to fight for ⚡"
			.. Config.Tournament.Prizes.Champion
			.. "!",
		"rare"
	)
	publish()
	return true
end

local function stillIn(player: Player?): boolean
	return player ~= nil and player.Parent ~= nil and not player:GetAttribute("InMatch")
end

-- Runs one fight and waits for its winner (a missing player loses).
local function play(fight: Fight)
	local a, b = fight.a, fight.b
	if not stillIn(a) then
		fight.winner = if stillIn(b) then b else nil
		return
	end
	if not stillIn(b) then
		fight.winner = a
		return
	end
	local p1, p2 = a :: Player, b :: Player
	current = fight
	publish()
	Notify.all("🏆 Next up in the arena: " .. p1.DisplayName .. " vs " .. p2.DisplayName .. "!", "info")
	-- Give them a moment to be free (a finished duel sends people back first).
	local done = false
	local started = false
	for _ = 1, 20 do
		started = LobbyService.startDuel(p1, p2, function(winner)
			fight.winner = winner
			done = true
		end)
		if started then
			break
		end
		task.wait(0.5)
	end
	if not started then
		-- Someone couldn't fight (knocked out, busy): the other goes through.
		fight.winner = if LobbyService.isFree(p1) then p1 elseif LobbyService.isFree(p2) then p2 else p1
		done = true
	end
	local deadline = os.clock() + Config.Duel.Seconds + 30
	while not done and os.clock() < deadline do
		task.wait(0.25)
	end
	current = nil
	publish()
	task.wait(3)
end

local function run()
	state = "running"
	-- Shuffle, then pair up; odd players out get a bye.
	for i = #entrants, 2, -1 do
		local j = math.random(1, i)
		entrants[i], entrants[j] = entrants[j], entrants[i]
	end
	local players: { Player? } = table.clone(entrants) :: any
	local semifinalists: { Player } = {}
	while #players > 1 do
		local round: { Fight } = {}
		for i = 1, #players, 2 do
			table.insert(round, { a = players[i], b = players[i + 1] })
		end
		table.insert(rounds, round)
		publish()
		if #players <= 4 then
			for _, player in players do
				if player then
					table.insert(semifinalists, player)
				end
			end
		end
		local winners: { Player? } = {}
		for _, fight in round do
			if fight.b == nil then
				fight.winner = fight.a -- a bye
			else
				play(fight)
			end
			if fight.winner then
				table.insert(winners, fight.winner)
			end
		end
		players = winners
	end
	local champion = players[1]
	local final = rounds[#rounds] and rounds[#rounds][1]
	local runnerUp = if final and final.winner == final.a then final.b else final and final.a
	for _, player in entrants do
		local prizes = Config.Tournament.Prizes
		if player == champion then
			give(player, prizes.Champion, "🏆 You're the Tournament Champion!")
			local data = DataService.get(player)
			if data then
				data.stats.tournamentWins = (data.stats.tournamentWins or 0) + 1
			end
		elseif player == runnerUp then
			give(player, prizes.RunnerUp, "🥈 Runner-up in the tournament!")
		elseif table.find(semifinalists, player) then
			give(player, prizes.Semifinal, "🥉 You made the semifinals!")
		else
			give(player, prizes.Joined, "🏆 Thanks for joining the tournament!")
		end
	end
	if champion then
		Notify.all("🏆👑 " .. champion.DisplayName .. " won the tournament!", "rare")
	end
	task.wait(10)
	state = "idle"
	rounds = {}
	entrants = {}
	publish()
end

local function onAction(player: Player, action: any)
	if state ~= "signup" then
		return
	end
	local index = table.find(entrants, player)
	if action == "join" and not index then
		if player:GetAttribute("InMatch") then
			Notify.player(player, "🏆 Finish your match first!", "error")
		elseif #entrants >= Config.Tournament.MaxPlayers then
			Notify.player(player, "🏆 The bracket is full!", "error")
		else
			table.insert(entrants, player)
			Notify.player(player, "🏆 You're in! Your fights are in the duel arena.", "success")
		end
	elseif action == "leave" and index then
		table.remove(entrants, index)
	end
	publish()
end

local function buildBoard()
	local frame = WorldBuilder.LobbySpots.bracket
	local board = Instance.new("Part")
	board.Name = "TournamentBoard"
	board.Anchored = true
	board.Size = Vector3.new(12, 14, 0.6)
	board.CFrame = frame * CFrame.new(0, 9, 0)
	board.Color = Color3.fromRGB(40, 34, 30)
	board.Material = Enum.Material.Wood
	board.Parent = workspace
	for _, x in { -5, 5 } do
		local post = Instance.new("Part")
		post.Anchored = true
		post.Size = Vector3.new(0.7, 2, 0.7)
		post.CFrame = board.CFrame * CFrame.new(x, -8, 0)
		post.Color = Color3.fromRGB(96, 70, 48)
		post.Material = Enum.Material.Wood
		post.Parent = board
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(360, 420)
	gui.LightInfluence = 0.2
	gui.Parent = board
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = gui
	boardTitle = Instance.new("TextLabel")
	boardTitle.BackgroundTransparency = 1
	boardTitle.Size = UDim2.new(1, 0, 0, 60)
	boardTitle.Font = Enum.Font.GothamBold
	boardTitle.TextScaled = true
	boardTitle.TextColor3 = Color3.fromRGB(255, 210, 90)
	boardTitle.Parent = gui
	for i = 1, 14 do
		local row = Instance.new("TextLabel")
		row.LayoutOrder = i
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, 25)
		row.Font = Enum.Font.GothamBold
		row.TextScaled = true
		row.TextColor3 = Color3.fromRGB(240, 236, 226)
		row.Text = ""
		row.Parent = gui
		table.insert(boardRows, row)
	end
end

-- Admins can start one any time (👑 Admin panel).
function TournamentService.startNow(byName: string): boolean
	if MatchService.phase() == "playing" then
		return false
	end
	return openSignup(byName)
end

function TournamentService.start()
	buildBoard()
	Remotes.event("TournamentAction").OnServerEvent:Connect(onAction)
	MatchService.pausedBy = function(): string?
		return if state ~= "idle" then "🏆 A tournament is on in the lobby!" else nil
	end
	Players.PlayerRemoving:Connect(function(player)
		local index = table.find(entrants, player)
		if index and state == "signup" then
			table.remove(entrants, index)
			publish()
		end
	end)
	publish()
	task.spawn(function()
		while true do
			task.wait(5)
			if state == "idle" then
				-- Weekends (UTC): a new one every EveryMinutes, between matches.
				local now = os.time()
				local weekday = tonumber(os.date("!%w", now)) -- 0 = Sunday, 6 = Saturday
				local slot = math.floor(now / (Config.Tournament.EveryMinutes * 60))
				local phase = MatchService.phase()
				local cupOn = workspace:GetAttribute("ArenaCupOn") == true -- 🏟️ the 2v2 cup has the arena
				if
					(weekday == 0 or weekday == 6)
					and slot ~= lastSlot
					and phase ~= "playing"
					and phase ~= "ended"
					and not cupOn
				then
					lastSlot = slot
					openSignup(nil)
				end
			elseif state == "signup" and workspace:GetServerTimeNow() >= signupEndsAt then
				if #entrants >= Config.Tournament.MinPlayers then
					local ok, problem = pcall(run)
					if not ok then
						warn("[Bottle a Storm] Tournament failed: " .. tostring(problem))
						state = "idle"
						rounds = {}
						entrants = {}
						publish()
					end
				else
					Notify.all("🏆 Not enough players joined the tournament. Next time!", "info")
					state = "idle"
					entrants = {}
					publish()
				end
			end
		end
	end)
end

return TournamentService
