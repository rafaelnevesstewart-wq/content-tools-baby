-- Your 📊 Stats page: wins, knockouts, beds, streaks, rank and your
-- favorite weapon (the one you've knocked out the most players with).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local ProgressionData = require(Shared.ProgressionData)
local Remotes = require(Shared.Remotes)

local CombatService = require(script.Parent.CombatService)
local DataService = require(script.Parent.DataService)
local MatchService = require(script.Parent.MatchService)

local StatsService = {}

local function favorite(weaponKills: { [string]: number }): (string?, number)
	local best, bestCount = nil, 0
	for weapon, count in weaponKills do
		if count > bestCount then
			best, bestCount = weapon, count
		end
	end
	return best, bestCount
end

local function getStats(player: Player): any
	local data = DataService.get(player)
	if not data then
		return nil
	end
	local stats = data.stats
	local weaponKills = stats.weaponKills or {}
	local weapon, weaponCount = favorite(weaponKills)
	local rank = ProgressionData.rankOf(stats.rankPoints or 0)
	return {
		wins = stats.wins or 0,
		matches = stats.matches or 0,
		kills = stats.kills or 0,
		finalKills = stats.finalKills or 0,
		deaths = stats.deaths or 0,
		bedsBroken = stats.bedsBroken or 0,
		duelsWon = stats.duelsWon or 0,
		obbyClears = stats.obbyClears or 0,
		sparksEarned = stats.sparksEarned or 0,
		winStreak = data.winStreak or 0,
		bestStreak = data.bestStreak or 0,
		level = data.level or 1,
		prestige = data.prestige or 0,
		rankPoints = stats.rankPoints or 0,
		rank = rank.emoji .. " " .. rank.name,
		favorite = weapon,
		favoriteKills = weaponCount,
		weaponKills = weaponKills,
		chests = data.chest and data.chest.opened or 0,
	}
end

function StatsService.start()
	Remotes.func("GetStats").OnServerInvoke = getStats
	MatchService.Killed:Connect(function(killer, victim)
		local data = DataService.get(killer)
		if data then
			local weapon = CombatService.lastWeaponOn(victim) or "Sword"
			data.stats.weaponKills = data.stats.weaponKills or {}
			data.stats.weaponKills[weapon] = (data.stats.weaponKills[weapon] or 0) + 1
		end
	end)
end

return StatsService
