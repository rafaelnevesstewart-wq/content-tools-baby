-- Loads and saves each player's profile with a session lock, so the same
-- profile is never open on two servers at once (no duplicated storms).
--
-- In Studio without "Enable Studio Access to API Services", it falls back to
-- memory-only profiles and warns once.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Signal = require(Shared.Signal)

local STORE_NAME = "BottleAStorm_Profiles_v1"
local LOCK_TIMEOUT = 300 -- a lock older than this belongs to a crashed server
local LOAD_ATTEMPTS = 6
local RETRY_SECONDS = 5
local MAX_RECEIPTS = 50

local DataService = {}

-- Fires (player, data) once a profile is ready to use.
DataService.ProfileLoaded = Signal.new()

-- Called with (player, data) right before a profile is saved for the last time.
-- Handlers must not yield.
local releaseHandlers: { (Player, any) -> () } = {}

type Profile = {
	key: string,
	data: any,
	released: boolean,
}

local profiles: { [Player]: Profile } = {}
local store: DataStore? = nil
local memoryMode = false

local function defaultData()
	return {
		version = 1,
		sparks = 0,
		unclaimed = 0,
		jarTier = 1,
		pedestals = Config.Pedestals.Start,
		bootsLevel = 0,
		trapLevel = 0,
		raidShields = 0,
		climate = 0, -- Climate Shift level: 0 Temperate, 1 Arctic, 2 Volcano, 3 Space
		-- Season pass progress; reset when a new season starts. Claimed tiers use
		-- string keys ("5" = true) so the DataStore never sees an array with holes.
		season = { id = -1, xp = 0, premium = false, claimedFree = {}, claimedPremium = {} },
		thiefStyles = {}, -- unlocked style key -> true; data.thiefStyle is the equipped one
		storms = {}, -- { StormRecord }
		discovered = {}, -- storm id -> true
		recipes = {}, -- hybrid id -> true, the Storm Mixer recipes this player found
		receipts = {}, -- recent purchase ids, to never grant a purchase twice
		stats = {
			captured = 0,
			stolen = 0,
			sparksEarned = 0,
			mixed = 0,
			trades = 0,
			shifts = 0,
		},
	}
end

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

-- Adds keys that were introduced after this profile was first saved.
local function reconcile(data: any, template: any)
	for key, value in template do
		if data[key] == nil then
			data[key] = deepCopy(value)
		elseif type(value) == "table" and type(data[key]) == "table" and next(value) ~= nil then
			reconcile(data[key], value)
		end
	end
	return data
end

local function enterMemoryMode(reason: string)
	if not memoryMode then
		memoryMode = true
		warn(
			"[DataService] Saving is OFF ("
				.. reason
				.. "). Progress resets when you stop. "
				.. "In Studio, turn on Game Settings > Security > Enable Studio Access to API Services."
		)
	end
end

local function isApiAccessError(message: string): boolean
	return string.find(message, "StudioAccessToApisNotAllowed") ~= nil
		or string.find(message, "Studio Access to API Services") ~= nil
		or string.find(message, "must publish this place") ~= nil
end

-- Takes the session lock and returns the stored data (nil for a new player).
local function loadRecord(key: string): (boolean, any)
	for attempt = 1, LOAD_ATTEMPTS do
		if memoryMode or not store then
			return true, nil
		end
		local ignoreLock = attempt == LOAD_ATTEMPTS
		local lockedElsewhere = false
		local ok, result = pcall(function()
			return (store :: DataStore):UpdateAsync(key, function(old)
				lockedElsewhere = false
				local lock = type(old) == "table" and old.lock
				if
					lock
					and lock.jobId ~= game.JobId
					and os.time() - (lock.time or 0) < LOCK_TIMEOUT
					and not ignoreLock
				then
					lockedElsewhere = true
					return nil
				end
				local record = if type(old) == "table" then old else {}
				record.lock = { jobId = game.JobId, time = os.time() }
				return record
			end)
		end)
		if ok and not lockedElsewhere then
			return true, if type(result) == "table" then result.data else nil
		end
		if not ok then
			warn("[DataService] Load failed for " .. key .. ": " .. tostring(result))
			if isApiAccessError(tostring(result)) then
				enterMemoryMode("no API access")
				return true, nil
			end
		end
		task.wait(RETRY_SECONDS)
	end
	return false, nil
end

local function writeRecord(key: string, data: any, release: boolean): boolean
	if memoryMode or not store then
		return true
	end
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(key, function(old)
			local lock = type(old) == "table" and old.lock
			if lock and lock.jobId ~= game.JobId then
				-- Another server took over this profile. Never overwrite it.
				return nil
			end
			return {
				data = data,
				lock = if release then nil else { jobId = game.JobId, time = os.time() },
			}
		end)
	end)
	if not ok then
		warn("[DataService] Save failed for " .. key .. ": " .. tostring(err))
	end
	return ok
end

local function onPlayerAdded(player: Player)
	local key = "player_" .. player.UserId
	local ok, stored = loadRecord(key)

	if not player:IsDescendantOf(Players) then
		-- They left while we were loading: give the lock back untouched.
		if ok then
			writeRecord(key, stored, true)
		end
		return
	end
	if not ok then
		player:Kick("We couldn't load your storms. Please rejoin in a minute!")
		return
	end

	local data = reconcile(stored or defaultData(), defaultData())
	profiles[player] = { key = key, data = data, released = false }
	DataService.ProfileLoaded:Fire(player, data)
end

local function releaseProfile(player: Player)
	local profile = profiles[player]
	if not profile or profile.released then
		return
	end
	-- Mark first so nothing can change this profile while the save yields.
	profile.released = true
	for _, handler in releaseHandlers do
		local ok, err = pcall(handler, player, profile.data)
		if not ok then
			warn("[DataService] Release handler error: " .. tostring(err))
		end
	end
	writeRecord(profile.key, profile.data, true)
	profiles[player] = nil
end

-- Returns the live profile data, or nil if it's not loaded (or being released).
function DataService.get(player: Player): any
	local profile = profiles[player]
	if profile and not profile.released then
		return profile.data
	end
	return nil
end

function DataService.onRelease(handler: (Player, any) -> ())
	table.insert(releaseHandlers, handler)
end

-- Saves immediately. Used after Robux purchases.
function DataService.saveNow(player: Player): boolean
	local profile = profiles[player]
	if not profile or profile.released then
		return false
	end
	return writeRecord(profile.key, profile.data, false)
end

function DataService.hasReceipt(data: any, purchaseId: string): boolean
	return table.find(data.receipts, purchaseId) ~= nil
end

function DataService.addReceipt(data: any, purchaseId: string)
	table.insert(data.receipts, purchaseId)
	while #data.receipts > MAX_RECEIPTS do
		table.remove(data.receipts, 1)
	end
end

function DataService.isMemoryMode(): boolean
	return memoryMode
end

function DataService.init()
	if game.PlaceId == 0 then
		enterMemoryMode("place is not published")
	else
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore(STORE_NAME)
		end)
		if ok then
			store = result
		else
			enterMemoryMode(tostring(result))
		end
	end
end

function DataService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(releaseProfile)

	task.spawn(function()
		while true do
			task.wait(Config.AutosaveSeconds)
			for _, profile in profiles do
				if not profile.released then
					task.spawn(writeRecord, profile.key, profile.data, false)
				end
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() and memoryMode then
			return
		end
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				releaseProfile(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return DataService
