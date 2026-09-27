-- Admin Abuse: the game's owner (and anyone in Config.Admin.UserIds, or anyone
-- in Studio) gets a 👑 Admin panel to start server-wide events: Admin Abuse
-- (double Sparks, 10x luck and storm rains for 30 minutes), luck, a storm
-- rain, a Mega-Storm, a Golden Hunt, a Storm Race, any weather, or Sparks for
-- everyone. Admin Abuse also starts by itself once a week (Config.Admin).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local WeatherEvents = require(Shared.WeatherEvents)

local Modules = script.Parent.Parent.Modules
local Notify = require(Modules.Notify)

local EventService = require(script.Parent.EventService)
local IncomeService = require(script.Parent.IncomeService)
local MatchService = require(script.Parent.MatchService)
local RaidService = require(script.Parent.RaidService)
local StormSpawner = require(script.Parent.StormSpawner)
local WeatherService = require(script.Parent.WeatherService)

local AdminService = {}

local lastWeekly = -1
local BED_WARS = Config.GameMode == "BedWars"

local function now(): number
	return workspace:GetServerTimeNow()
end

local function isAdmin(player: Player): boolean
	return RunService:IsStudio()
		or player.UserId == game.CreatorId
		or table.find(Config.Admin.UserIds, player.UserId) ~= nil
end

local function startLuck(minutes: number)
	workspace:SetAttribute("LuckUntil", now() + minutes * 60)
end

local function startAbuse(byName: string?)
	local minutes = Config.Admin.AbuseMinutes
	workspace:SetAttribute("AbuseUntil", now() + minutes * 60)
	startLuck(minutes)
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
			.. " Sparks, x"
			.. Config.Admin.LuckMultiplier
			.. " luck and storm rains!",
		"rare"
	)
end

local function abuseOn(): boolean
	local untilTime = workspace:GetAttribute("AbuseUntil")
	return type(untilTime) == "number" and untilTime > now()
end

local commands: { [string]: (Player, any) -> (boolean, string) } = {
	abuse = function(player)
		startAbuse(player.DisplayName)
		return true, "Admin Abuse started!"
	end,
	luck = function(player)
		startLuck(Config.Admin.LuckMinutes)
		Notify.all(
			"🍀 "
				.. player.DisplayName
				.. " turned on x"
				.. Config.Admin.LuckMultiplier
				.. " STORM LUCK for "
				.. Config.Admin.LuckMinutes
				.. " minutes!",
			"rare"
		)
		return true, "Luck is on."
	end,
	rain = function(player)
		StormSpawner.stormRain(Config.Admin.StormRainCount)
		Notify.all("🌧️ " .. player.DisplayName .. " made it rain storms on the Wild Skies!", "rare")
		return true, "Storm rain!"
	end,
	boss = function()
		if RaidService.startSoon() then
			return true, "The Mega-Storm is coming!"
		end
		return false, "A Mega-Storm is already on."
	end,
	golden = function()
		if EventService.startGolden() then
			return true, "Golden Hunt started!"
		end
		return false, "Another event is running right now."
	end,
	race = function()
		if EventService.startRace() then
			return true, "Storm Race starting!"
		end
		return false, "Another event is running right now."
	end,
	weather = function(player, key)
		if type(key) ~= "string" or not WeatherEvents.get(key) then
			return false, "Unknown weather."
		end
		WeatherService.summon(key, player.DisplayName)
		return true, "Weather started."
	end,
	startmatch = function(player)
		if MatchService.startNow() then
			Notify.all("⚔️ " .. player.DisplayName .. " started a Bed Wars match!", "rare")
			return true, "Match started!"
		end
		return false, "A match is already on."
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

	-- Storm rains during Admin Abuse, and the weekly automatic Admin Abuse.
	task.spawn(function()
		local lastRain = 0
		while true do
			task.wait(5)
			if abuseOn() and BED_WARS == false and os.clock() - lastRain >= Config.Admin.StormRainEvery then
				lastRain = os.clock()
				StormSpawner.stormRain(Config.Admin.StormRainCount)
				Notify.all("🌧️ ADMIN ABUSE storm rain on the Wild Skies!", "info")
			end
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
