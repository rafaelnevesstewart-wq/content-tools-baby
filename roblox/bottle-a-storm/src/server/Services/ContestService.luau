-- 🎨 Build contests on Base Island (taking turns with the other lobby events,
-- LobbyEventService; ContestData): a theme is picked and everyone with a plot
-- has 10 minutes to build it. Then every base with enough blocks is entered
-- and players vote 1-5 stars on each (visit them from the 🎨 window). The best
-- average wins Sparks and counts toward the 🏗️ Master Builder title; everyone
-- who entered or voted gets a little too.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local ContestData = require(Shared.ContestData)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent.Parent.Modules
local Juice = require(Modules.Juice)
local Notify = require(Modules.Notify)
local Usage = require(Modules.Usage)

local BaseService = require(script.Parent.BaseService)
local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)

local ContestService = {}

type Entry = { player: Player, name: string, plot: number, blocks: number }

local phase = "break"
local theme = ""
local endsAt = 0
local entries: { [number]: Entry } = {} -- userId -> entry (while voting)
local votes: { [number]: { [number]: number } } = {} -- voter userId -> entrant userId -> stars
local lastAction: { [Player]: number } = {}

local function publish()
	local count = 0
	for _ in entries do
		count += 1
	end
	workspace:SetAttribute(
		"Contest",
		HttpService:JSONEncode({ phase = phase, theme = theme, endsAt = endsAt, entries = count })
	)
end

local function pay(player: Player, amount: number)
	if player.Parent then
		IncomeService.addSparks(player, amount)
	end
end

-- Waits `seconds`, or less if an admin skips ahead (🧪 Test).
local skipping = false
local function waitPhase(seconds: number)
	local ends = os.clock() + seconds
	skipping = false
	while os.clock() < ends and not skipping do
		task.wait(0.5)
	end
	skipping = false
end

-- Ends the current phase early (admins, for testing).
function ContestService.skip()
	skipping = true
end

local function tally()
	local results = {}
	for userId, entry in entries do
		local sum, count = 0, 0
		for _, given in votes do
			local stars = given[userId]
			if stars then
				sum += stars
				count += 1
			end
		end
		table.insert(results, { entry = entry, average = if count > 0 then sum / count else 0, count = count })
		pay(entry.player, ContestData.EntrySparks)
	end
	table.sort(results, function(a, b)
		if a.average ~= b.average then
			return a.average > b.average
		elseif a.count ~= b.count then
			return a.count > b.count
		end
		return a.entry.blocks > b.entry.blocks
	end)
	local lines = {}
	for place, result in results do
		local prize = ContestData.Prizes[place]
		if not prize or result.count == 0 then
			break
		end
		local player = result.entry.player
		pay(player, prize)
		local medal = ({ "🥇", "🥈", "🥉" })[place]
		table.insert(lines, medal .. " " .. result.entry.name .. string.format(" (%.1f⭐)", result.average))
		if place == 1 then
			local data = DataService.get(player)
			if data then
				data.stats.contestWins = (data.stats.contestWins or 0) + 1
			end
			Juice.sound(player, "win")
		end
		Notify.player(
			player,
			medal .. " You placed #" .. place .. " in the build contest! +⚡" .. Format.number(prize),
			"rare"
		)
	end
	if #lines > 0 then
		Notify.all("🎨 Build contest results: " .. table.concat(lines, "  "), "rare")
	else
		Notify.all("🎨 The build contest is over, but nobody voted!", "info")
	end
end

local function runContest()
	theme = ContestData.Themes[math.random(1, #ContestData.Themes)]
	phase = "build"
	entries = {}
	votes = {}
	endsAt = workspace:GetServerTimeNow() + ContestData.BuildSeconds
	publish()
	Notify.all(
		"🎨 BUILD CONTEST! Theme: "
			.. theme
			.. ". Claim a plot on 🏗️ Base Island and build it in "
			.. ContestData.BuildSeconds // 60
			.. " minutes!",
		"rare"
	)
	waitPhase(ContestData.BuildSeconds - 60)
	Notify.all("🎨 1 minute left to build " .. theme .. "!", "info")
	waitPhase(60)
	for _, entry in BaseService.entries() do
		if entry.blocks >= ContestData.MinBlocks then
			entries[entry.player.UserId] = {
				player = entry.player,
				name = entry.player.DisplayName,
				plot = entry.plot,
				blocks = entry.blocks,
			}
			Usage.track("contestEntry", entry.player)
		end
	end
	if next(entries) == nil then
		Notify.all("🎨 Nobody entered the build contest this time. Next one soon!", "info")
		return
	end
	phase = "vote"
	endsAt = workspace:GetServerTimeNow() + ContestData.VoteSeconds
	publish()
	Notify.all("🎨 Time to vote! Open 🎨 Contest, visit each base and give it stars.", "rare")
	waitPhase(ContestData.VoteSeconds)
	tally()
end

local function info(player: Player): any
	local list = {}
	local mine = votes[player.UserId] or {}
	for userId, entry in entries do
		if entry.player.Parent then
			table.insert(list, {
				userId = userId,
				name = entry.name,
				blocks = entry.blocks,
				stars = mine[userId],
				you = entry.player == player,
			})
		end
	end
	table.sort(list, function(a, b)
		return a.name < b.name
	end)
	return { phase = phase, theme = theme, endsAt = endsAt, entries = list }
end

local function onAction(player: Player, action: any, userId: any, stars: any): any
	if action == "info" then
		return info(player)
	end
	if os.clock() - (lastAction[player] or 0) < 0.3 then
		return false, "Slow down!"
	end
	lastAction[player] = os.clock()
	local entry = if type(userId) == "number" then entries[userId] else nil
	if not entry or not entry.player.Parent then
		return false, "That base isn't in the contest."
	end
	if action == "visit" then
		local character = player.Character
		if not character or player:GetAttribute("InMatch") then
			return false, "You can visit bases from the lobby."
		end
		character:PivotTo(BaseService.visitFrame(entry.plot))
		return true, "🏗️ This is " .. entry.name .. "'s base!"
	elseif action == "vote" then
		if phase ~= "vote" then
			return false, "Voting hasn't started yet."
		end
		if entry.player == player then
			return false, "You can't vote for your own base!"
		end
		if type(stars) ~= "number" or stars ~= stars then
			return false, "Pick 1 to 5 stars."
		end
		local given = votes[player.UserId]
		if not given then
			given = {}
			votes[player.UserId] = given
			pay(player, ContestData.VoterSparks)
		end
		given[userId] = math.clamp(math.floor(stars), 1, 5)
		return true, "⭐ You gave " .. entry.name .. " " .. given[userId] .. " stars!"
	end
	return false, "Can't do that."
end

local running = false

-- Starts a contest now (LobbyEventService takes turns with the other lobby
-- events; admins can start one from 🧪 Test). False if one is already on.
function ContestService.startNow(): boolean
	if running then
		return false
	end
	running = true
	task.spawn(function()
		local ok, problem = pcall(runContest)
		if not ok then
			warn("[Bottle a Storm] Build contest failed: " .. tostring(problem))
		end
		phase = "break"
		entries = {}
		votes = {}
		endsAt = 0
		publish()
		running = false
	end)
	return true
end

function ContestService.isRunning(): boolean
	return running
end

function ContestService.start()
	Remotes.func("Contest").OnServerInvoke = onAction
	publish()
	Players.PlayerRemoving:Connect(function(player)
		lastAction[player] = nil
	end)
end

return ContestService
