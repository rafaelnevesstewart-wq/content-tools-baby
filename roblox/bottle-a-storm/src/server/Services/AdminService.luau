-- Admin Abuse: the game's owner (and anyone in Config.Admin.UserIds, or anyone
-- in Studio) gets a 👑 Admin panel: start or end a Bed Wars match, start
-- Admin Abuse (double match Sparks for 30 minutes), any match weather, or
-- give everyone Sparks. Admin Abuse also starts by itself once a week
-- (Config.Admin).
--
-- 🧪 Test: start any feature right away instead of waiting for it (the
-- boss, a disaster, the lobby events, night, a shooting star, a special
-- rule) and start your own guide, treasure hunt and puzzles over.
--
-- 🗂️ Players: look anyone up (in this server or not) by name or user id, give
-- someone Sparks, or restore an online player's profile from a backup.
-- 📈 Stats: what people have been doing today and this week (Usage).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local WeatherEvents = require(Shared.WeatherEvents)

local Modules = script.Parent.Parent.Modules
local Notify = require(Modules.Notify)
local Usage = require(Modules.Usage)

local ArenaCupService = require(script.Parent.ArenaCupService)
local BossService = require(script.Parent.BossService)
local ContestService = require(script.Parent.ContestService)
local CostumeService = require(script.Parent.CostumeService)
local DataService = require(script.Parent.DataService)
local DisasterService = require(script.Parent.DisasterService)
local EventService = require(script.Parent.EventService)
local GuideService = require(script.Parent.GuideService)
local IncomeService = require(script.Parent.IncomeService)
local MatchService = require(script.Parent.MatchService)
local TournamentService = require(script.Parent.TournamentService)
local TreasureService = require(script.Parent.TreasureService)
local WeatherService = require(script.Parent.WeatherService)
local WishService = require(script.Parent.WishService)

local AdminService = {}

local lastWeekly = -1

local function now(): number
	return workspace:GetServerTimeNow()
end

local function isAdmin(player: Player): boolean
	return RunService:IsStudio()
		or player.UserId == game.CreatorId
		or table.find(Config.Admin.UserIds, player.UserId) ~= nil
end

local function startAbuse(byName: string?)
	local minutes = Config.Admin.AbuseMinutes
	workspace:SetAttribute("AbuseUntil", now() + minutes * 60)
	for _, player in Players:GetPlayers() do
		IncomeService.sync(player)
	end
	Notify.all(
		"👑 ADMIN ABUSE"
			.. (if byName then " by " .. byName else "")
			.. "! For "
			.. minutes
			.. " minutes: x"
			.. Config.Admin.AbuseIncomeMultiplier
			.. " Sparks from every match!",
		"rare"
	)
end

local function abuseOn(): boolean
	local untilTime = workspace:GetAttribute("AbuseUntil")
	return type(untilTime) == "number" and untilTime > now()
end

-- 🌙 Night for a few minutes (then the normal day cycle, or the map's own
-- time of day, comes back).
local nightToken = 0
local function nightNow()
	nightToken += 1
	local token = nightToken
	local before = workspace:GetAttribute("FixedClock")
	workspace:SetAttribute("FixedClock", 0)
	task.delay(180, function()
		if nightToken == token and workspace:GetAttribute("FixedClock") == 0 then
			workspace:SetAttribute("FixedClock", before)
		end
	end)
end

-- An online player by name (or display name, or user id).
local function findOnline(text: string): Player?
	local lower = string.lower(text)
	for _, player in Players:GetPlayers() do
		if
			string.lower(player.Name) == lower
			or string.lower(player.DisplayName) == lower
			or tostring(player.UserId) == text
		then
			return player
		end
	end
	return nil
end

local function summary(name: string, userId: number, data: any, online: boolean): string
	local stats = data.stats or {}
	local owned = 0
	for _ in (data.cosmetics and data.cosmetics.owned) or {} do
		owned += 1
	end
	local backups = DataService.backupsOf(userId)
	local lines = {
		name .. " (" .. userId .. ")" .. (if online then " · online" else " · offline"),
		"⚡ "
			.. Format.number(data.sparks or 0)
			.. " Sparks · level "
			.. tostring(data.level or 1)
			.. " · prestige "
			.. tostring(data.prestige or 0),
		"🏆 "
			.. tostring(stats.wins or 0)
			.. " wins · "
			.. tostring(stats.matches or 0)
			.. " matches · "
			.. tostring(stats.kills or 0)
			.. " knockouts",
		"🎨 " .. owned .. " cosmetics · 🌪️ " .. #(data.storms or {}) .. " kits · 🧙 " .. tostring(
			data.class or "Knight"
		),
		"🛡️ Backups: " .. #backups .. (if backups[1]
			then " (newest " .. os.date("!%Y-%m-%d %H:%M UTC", backups[1].time) .. ")"
			else ""),
	}
	return table.concat(lines, "\n")
end

local function yes(ok: boolean, good: string, bad: string): (boolean, string)
	return ok, if ok then good else bad
end

local commands: { [string]: (Player, any) -> (boolean, string) } = {
	-- 🧪 Test
	boss = function()
		return yes(BossService.spawnNow(), "The boss is coming!", "Start a match first (or it's already here).")
	end,
	disaster = function(_player, key)
		return yes(
			type(key) == "string" and DisasterService.runNow(key),
			"Disaster started!",
			"Start a match first (disasters only happen in matches)."
		)
	end,
	contest = function()
		return yes(ContestService.startNow(), "Build contest started!", "A build contest is already on.")
	end,
	costume = function()
		return yes(CostumeService.startNow(), "Costume party started!", "A costume party is already on.")
	end,
	skip = function()
		ContestService.skip()
		CostumeService.skip()
		return true, "Skipped ahead (build contest and costume party)."
	end,
	arenacup = function()
		return yes(
			ArenaCupService.startNow(),
			"Arena Cup sign-ups are open!",
			"Not now: it's on, or a match/tournament is."
		)
	end,
	night = function()
		nightNow()
		return true, "Night for 3 minutes!"
	end,
	star = function()
		WishService.starNow()
		return true, "A shooting star is on its way!"
	end,
	rule = function(_player, key)
		EventService.force(if type(key) == "string" and key ~= "" then key else nil)
		return true,
			if type(key) == "string" and key ~= "" then "Special rule set: " .. key else "Back to this week's rule."
	end,
	-- 🗂️ Players
	lookup = function(_player, text)
		if type(text) ~= "string" or text == "" then
			return false, "Type a name or user id."
		end
		local online = findOnline(text)
		if online then
			local data = DataService.get(online)
			if not data then
				return false, "Their profile is still loading."
			end
			return true, summary(online.DisplayName, online.UserId, data, true)
		end
		local userId = tonumber(text)
		if not userId then
			local ok, id = pcall(function()
				return Players:GetUserIdFromNameAsync(text)
			end)
			userId = if ok then id else nil
		end
		if not userId then
			return false, "Nobody called " .. text .. "."
		end
		local data = DataService.peek(userId)
		if not data then
			return false, "No saved profile for " .. text .. " (or no data store access in Studio)."
		end
		return true, summary(text, userId, data, false)
	end,
	give = function(player, arg)
		local target = type(arg) == "table" and type(arg.name) == "string" and findOnline(arg.name)
		local amount = type(arg) == "table" and tonumber(arg.amount)
		if not target then
			return false, "They need to be in this server."
		end
		if not amount or amount <= 0 or amount > 1e9 then
			return false, "Pick an amount."
		end
		IncomeService.addSparks(target, math.floor(amount))
		Notify.player(
			target,
			"💸 " .. player.DisplayName .. " gave you ⚡" .. Format.number(math.floor(amount)) .. "!",
			"rare"
		)
		return true, "Gave " .. target.DisplayName .. " ⚡" .. Format.number(math.floor(amount)) .. "."
	end,
	restore = function(_player, name)
		local target = type(name) == "string" and findOnline(name)
		if not target then
			return false, "They need to be in this server."
		end
		return DataService.restore(target, 1)
	end,
	-- 📈 Stats
	stats = function(_player, days)
		local span = if days == 7 then 7 else 1
		local list = Usage.report(span)
		if #list == 0 then
			return true,
				"Nothing counted yet (counts save every 5 minutes; no data store in unpublished Studio places)."
		end
		local lines = { if span == 7 then "📈 The last 7 days" else "📈 Today" }
		for index, entry in list do
			if index > 40 then
				break
			end
			table.insert(lines, entry.key .. ": " .. Format.number(entry.count))
		end
		return true, table.concat(lines, "\n")
	end,
	restart = function(player)
		GuideService.restart(player)
		TreasureService.restart(player)
		local data = DataService.get(player)
		if data then
			data.puzzles = { day = -1, done = {} }
			data.wishes = { day = -1, count = 0 }
			data.starter = nil
			player:SetAttribute("StarterPack", true)
		end
		return true, "Your guide, treasure hunt, puzzles, wishes and starter pack start over."
	end,

	abuse = function(player)
		startAbuse(player.DisplayName)
		return true, "Admin Abuse started!"
	end,
	weather = function(player, key)
		if type(key) ~= "string" or not WeatherEvents.get(key) then
			return false, "Unknown weather."
		end
		WeatherService.summon(key, player.DisplayName, nil)
		return true, "Weather started."
	end,
	startmatch = function(player)
		if MatchService.startNow() then
			Notify.all("⚔️ " .. player.DisplayName .. " started a Bed Wars match!", "rare")
			return true, "Match started!"
		end
		return false, "A match is already on."
	end,
	tournament = function(player)
		if TournamentService.startNow(player.DisplayName) then
			return true, "Tournament sign-ups are open!"
		end
		return false, "Wait for the match (or tournament) to end."
	end,
	endmatch = function()
		if MatchService.endNow() then
			return true, "Match ended."
		end
		return false, "No match is running."
	end,
	sparks = function(player, amount)
		if type(amount) ~= "number" or amount <= 0 or amount > 1e9 then
			return false, "Pick an amount."
		end
		amount = math.floor(amount)
		for _, other in Players:GetPlayers() do
			IncomeService.addSparks(other, amount)
		end
		Notify.all("💸 " .. player.DisplayName .. " gave everyone ⚡" .. Format.number(amount) .. "!", "rare")
		return true, "Sent!"
	end,
}

local function onCommand(player: Player, command: any, arg: any): (boolean, string)
	if not isAdmin(player) then
		return false, "Admins only."
	end
	local run = type(command) == "string" and commands[command]
	if not run then
		return false, "Unknown command."
	end
	return run(player, arg)
end

function AdminService.start()
	Remotes.func("AdminCommand").OnServerInvoke = onCommand
	local function mark(player: Player)
		player:SetAttribute("IsAdmin", isAdmin(player))
	end
	Players.PlayerAdded:Connect(mark)
	for _, player in Players:GetPlayers() do
		mark(player)
	end

	-- The weekly automatic Admin Abuse.
	task.spawn(function()
		while true do
			task.wait(5)
			local date = os.date("!*t", os.time())
			local week = os.time() // (7 * 86400)
			if
				date.wday == Config.Admin.WeeklyDay
				and date.hour == Config.Admin.WeeklyHour
				and date.min < 5
				and week ~= lastWeekly
				and not abuseOn()
			then
				lastWeekly = week
				startAbuse(nil)
			end
		end
	end)
end

return AdminService
