-- Loads and saves player profiles with DataStoreService.
-- If a load fails the player still plays, but that session is never saved,
-- so a DataStore outage cannot wipe real progress.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local DataService = {}

local store = nil
local canSave = {} -- [Player] = boolean

local function defaultProfile()
	return {
		Coins = 100,
		Food = 0,
		Species = Config.SpeciesOrder[math.random(1, #Config.SpeciesOrder)],
		TitanMutation = "Normal",
		Stage = 1,
		Growth = 0,
		Molts = 0,
		Riders = {},
		Eggs = {},
		NightsSurvivedStreak = 0,
		TamedCount = 0,
		RescuedCount = 0,
		LastOnline = 0,
		LastFreeEggDay = 0,
		GrowthSnackUntil = 0,
		NextId = 1,
		PurchaseIds = {},
		OwnedSkins = { "Classic" },
		EquippedSkin = "Classic",
	}
end

-- Fills in any fields added after a profile was first saved.
local function reconcile(profile)
	for key, value in defaultProfile() do
		if profile[key] == nil then
			profile[key] = value
		end
	end
	return profile
end

local function keyFor(player: Player): string
	return "player_" .. player.UserId
end

function DataService:Init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStore unavailable, progress will not save:", result)
	end
end

function DataService:Load(player: Player)
	if not store then
		canSave[player] = false
		return defaultProfile()
	end
	-- One attempt in Studio, where DataStores are often switched off.
	local attempts = RunService:IsStudio() and 1 or 3
	for attempt = 1, attempts do
		local ok, result = pcall(function()
			return store:GetAsync(keyFor(player))
		end)
		if ok then
			canSave[player] = true
			if type(result) == "table" then
				return reconcile(result)
			end
			return defaultProfile()
		end
		warn(string.format("[DataService] Load attempt %d failed for %s: %s", attempt, player.Name, tostring(result)))
		task.wait(attempt)
	end
	canSave[player] = false
	return defaultProfile()
end

-- Strips session-only fields before writing.
local function serialize(profile)
	local copy = table.clone(profile)
	copy.Riders = {}
	for _, rider in profile.Riders do
		local r = table.clone(rider)
		r.InTransit = nil
		table.insert(copy.Riders, r)
	end
	copy.Eggs = {}
	for _, egg in profile.Eggs do
		local e = table.clone(egg)
		e.InTransit = nil
		table.insert(copy.Eggs, e)
	end
	return copy
end

function DataService:Save(player: Player, profile)
	if not store or not canSave[player] or not profile then
		return
	end
	profile.LastOnline = os.time()
	local data = serialize(profile)
	local ok, err = pcall(function()
		store:SetAsync(keyFor(player), data)
	end)
	if not ok then
		warn("[DataService] Save failed for", player.Name, err)
	end
end

function DataService:Release(player: Player)
	canSave[player] = nil
end

return DataService
