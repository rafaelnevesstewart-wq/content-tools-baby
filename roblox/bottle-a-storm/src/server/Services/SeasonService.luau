-- "Stormy Seasons" pass. Season Stars (XP) come from playing: time online,
-- catching, stealing, mixing and raids. Every tier unlocks a free reward and a
-- premium reward; players claim them in the Season window. A new season
-- (new theme and exclusive storms) starts every 4 weeks and resets progress.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local SeasonData = require(Shared.SeasonData)

local Modules = script.Parent.Parent.Modules
local Notify = require(Modules.Notify)

local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local RewardService = require(script.Parent.RewardService)

local SeasonService = {}

local lastClaim: { [Player]: number } = {}

local function currentSeason(): (number, SeasonData.Theme, number)
	return SeasonData.current(os.time())
end

-- Starts a fresh pass if the saved one is from an older season.
local function ensure(data: any): any
	local number = currentSeason()
	if data.season.id ~= number then
		data.season = { id = number, xp = 0, premium = false, claimedFree = {}, claimedPremium = {} }
	end
	return data.season
end

local function claimable(season: any): number
	local tier = SeasonData.tierFor(season.xp)
	local count = 0
	for t = 1, tier do
		local rewards = SeasonData.Rewards[t]
		if rewards and rewards.free and not season.claimedFree[tostring(t)] then
			count += 1
		end
		if rewards and rewards.premium and season.premium and not season.claimedPremium[tostring(t)] then
			count += 1
		end
	end
	return count
end

function SeasonService.sync(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local season = ensure(data)
	player:SetAttribute("SeasonXp", season.xp)
	player:SetAttribute("SeasonTier", SeasonData.tierFor(season.xp))
	player:SetAttribute("SeasonPremium", season.premium)
	player:SetAttribute("SeasonClaimable", claimable(season))
end

function SeasonService.addXp(player: Player, amount: number)
	local data = DataService.get(player)
	if not data or amount <= 0 then
		return
	end
	local season = ensure(data)
	local before = SeasonData.tierFor(season.xp)
	season.xp = math.min(season.xp + amount, SeasonData.Tiers * SeasonData.XpPerTier)
	local after = SeasonData.tierFor(season.xp)
	if after > before then
		Notify.player(player, "⭐ Season tier " .. after .. "! Claim your reward in 🎟️ Season.", "rare")
	end
	SeasonService.sync(player)
end

function SeasonService.grantPremium(player: Player): boolean
	local data = DataService.get(player)
	if not data then
		return false
	end
	local season = ensure(data)
	if season.premium then
		-- Bought twice: turn the second one into tier skips so it isn't wasted.
		SeasonService.addXp(player, Config.Season.DuplicatePremiumTiers * Config.Season.SkipTierXp)
		Notify.player(
			player,
			"You already had Premium, so you got " .. Config.Season.DuplicatePremiumTiers .. " tier skips!",
			"success"
		)
		return true
	end
	season.premium = true
	SeasonService.sync(player)
	Notify.player(player, "🎟️ Season Premium unlocked! Claim your premium rewards in 🎟️ Season.", "rare")
	return true
end

local function claim(player: Player, tier: any, track: any): (boolean, string)
	local data = DataService.get(player)
	if not data or type(tier) ~= "number" or (track ~= "free" and track ~= "premium") then
		return false, "Can't claim that."
	end
	if os.clock() - (lastClaim[player] or 0) < 0.3 then
		return false, "Slow down!"
	end
	lastClaim[player] = os.clock()
	local season = ensure(data)
	local _, theme = currentSeason()
	tier = math.floor(tier)
	local rewards = SeasonData.Rewards[tier]
	local reward = rewards and (if track == "free" then rewards.free else rewards.premium)
	local claimed = if track == "free" then season.claimedFree else season.claimedPremium
	if not reward then
		return false, "There's no reward there."
	end
	if SeasonData.tierFor(season.xp) < tier then
		return false, "Reach tier " .. tier .. " first!"
	end
	if track == "premium" and not season.premium then
		return false, "That's a Season Premium reward."
	end
	if claimed[tostring(tier)] then
		return false, "Already claimed!"
	end
	local problem = RewardService.grant(player, reward, theme)
	if problem then
		return false, problem
	end
	claimed[tostring(tier)] = true
	IncomeService.sync(player)
	SeasonService.sync(player)
	return true, "Claimed!"
end

local function getSeason(player: Player)
	local data = DataService.get(player)
	if not data then
		return nil
	end
	local season = ensure(data)
	local claimedFree, claimedPremium = {}, {}
	for key in season.claimedFree do
		table.insert(claimedFree, tonumber(key))
	end
	for key in season.claimedPremium do
		table.insert(claimedPremium, tonumber(key))
	end
	return {
		id = season.id,
		xp = season.xp,
		premium = season.premium,
		claimedFree = claimedFree,
		claimedPremium = claimedPremium,
	}
end

function SeasonService.start()
	Remotes.func("GetSeason").OnServerInvoke = getSeason
	Remotes.func("SeasonClaim").OnServerInvoke = claim
	DataService.ProfileLoaded:Connect(SeasonService.sync)
	Players.PlayerRemoving:Connect(function(player)
		lastClaim[player] = nil
	end)

	-- Stars for time played; also notices when a new season begins.
	task.spawn(function()
		local seasonNumber = currentSeason()
		while true do
			task.wait(60)
			local number, theme = currentSeason()
			if number ~= seasonNumber then
				seasonNumber = number
				Notify.all(
					theme.emoji .. " A new season began: " .. theme.name .. "! New exclusive storms in 🎟️ Season.",
					"rare"
				)
			end
			for _, player in Players:GetPlayers() do
				SeasonService.addXp(player, Config.Season.PlaytimeXpPerMinute)
			end
		end
	end)
end

return SeasonService
