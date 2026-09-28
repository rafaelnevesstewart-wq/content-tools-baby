-- 📈 Play stats: counts what people do (matches by mode and map, fishing,
-- boat races, puzzles, lobby events...) so the owner can see what's popular
-- (👑 Admin → 📈 Stats). Counts add up per day in a data store (all servers
-- together); with a player they're also sent to Roblox's own analytics
-- (Creator Dashboard → Analytics → Custom events).

local AnalyticsService = game:GetService("AnalyticsService")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Usage = {}

local FLUSH_SECONDS = 300
local pending: { [string]: number } = {}
local store: DataStore? = nil
local started = false

local function dayKey(time: number): string
	return "day_" .. os.date("!%Y-%m-%d", time)
end

local function flush()
	local counts = pending
	pending = {}
	if not store or next(counts) == nil then
		return
	end
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(dayKey(os.time()), function(old)
			local merged = if type(old) == "table" then old else {}
			for key, amount in counts do
				merged[key] = (merged[key] or 0) + amount
			end
			return merged
		end)
	end)
	if not ok then
		-- Keep them for next time.
		for key, amount in counts do
			pending[key] = (pending[key] or 0) + amount
		end
		warn("[Usage] Couldn't save play stats: " .. tostring(err))
	end
end

local function start()
	if started then
		return
	end
	started = true
	if game.PlaceId ~= 0 then
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore("BottleAStorm_Usage_v1")
		end)
		store = if ok then result else nil
	end
	task.spawn(function()
		while true do
			task.wait(FLUSH_SECONDS)
			flush()
		end
	end)
	if not RunService:IsStudio() then
		game:BindToClose(flush)
	end
end

-- Counts one of `key` (or `amount`). With `player`, it's also sent to
-- Roblox analytics as a custom event.
function Usage.track(key: string, player: Player?, amount: number?)
	start()
	pending[key] = (pending[key] or 0) + (amount or 1)
	if player then
		pcall(function()
			(AnalyticsService :: any):LogCustomEvent(player, key, amount or 1)
		end)
	end
end

-- The counts for the last `days` days (today included, with what this
-- server hasn't saved yet), biggest first.
function Usage.report(days: number): { { key: string, count: number } }
	start()
	local totals: { [string]: number } = {}
	for key, amount in pending do
		totals[key] = (totals[key] or 0) + amount
	end
	if store then
		for back = 0, days - 1 do
			local ok, counts = pcall(function()
				return (store :: DataStore):GetAsync(dayKey(os.time() - back * 86400))
			end)
			if ok and type(counts) == "table" then
				for key, amount in counts do
					if type(amount) == "number" then
						totals[key] = (totals[key] or 0) + amount
					end
				end
			end
		end
	end
	local list = {}
	for key, count in totals do
		table.insert(list, { key = key, count = count })
	end
	table.sort(list, function(a, b)
		return a.count > b.count
	end)
	return list
end

return Usage
