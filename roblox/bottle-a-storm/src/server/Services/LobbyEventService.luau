-- 📅 Lobby events take turns, one at a time, so there's always one clear
-- thing going on: 🎨 Build Contest → 🎭 Costume Party → 🏟️ 2v2 Arena Cup →
-- ... with a short break between them. The Arena Cup waits for a gap
-- between matches (it's skipped when it can't start). What's on and what's
-- next is shared as "LobbyEvent" (JSON) for the chip at the top right.

local HttpService = game:GetService("HttpService")

local ArenaCupService = require(script.Parent.ArenaCupService)
local ContestService = require(script.Parent.ContestService)
local CostumeService = require(script.Parent.CostumeService)

local LobbyEventService = {}

local FIRST_AFTER = 90 -- seconds after the server starts
local GAP = 4 * 60 -- seconds between one event ending and the next

type Event = { key: string, label: string, startNow: () -> boolean, isRunning: () -> boolean }

local EVENTS: { Event } = {
	{
		key = "Contest",
		label = "🎨 Build Contest",
		startNow = ContestService.startNow,
		isRunning = ContestService.isRunning,
	},
	{
		key = "Costume",
		label = "🎭 Costume Party",
		startNow = CostumeService.startNow,
		isRunning = CostumeService.isRunning,
	},
	{
		key = "ArenaCup",
		label = "🏟️ 2v2 Arena Cup",
		startNow = ArenaCupService.startNow,
		isRunning = ArenaCupService.isRunning,
	},
}

local nextIndex = 1
local nextAt = 0

local function running(): Event?
	for _, event in EVENTS do
		if event.isRunning() then
			return event
		end
	end
	return nil
end

local function publish()
	local now = running()
	local upcoming = EVENTS[nextIndex]
	workspace:SetAttribute(
		"LobbyEvent",
		HttpService:JSONEncode({
			now = if now then now.label else nil,
			next = upcoming.label,
			nextAt = nextAt,
		})
	)
end

-- Tries the events in turn from the next one; true if one started.
local function startNext(): boolean
	for _ = 1, #EVENTS do
		local event = EVENTS[nextIndex]
		nextIndex = nextIndex % #EVENTS + 1
		if event.startNow() then
			return true
		end
	end
	return false
end

function LobbyEventService.start()
	nextAt = workspace:GetServerTimeNow() + FIRST_AFTER
	publish()
	task.spawn(function()
		local wasRunning = false
		while true do
			task.wait(2)
			local isRunning = running() ~= nil
			if isRunning then
				wasRunning = true
			elseif wasRunning then
				-- One just ended: a break, then the next.
				wasRunning = false
				nextAt = workspace:GetServerTimeNow() + GAP
			elseif workspace:GetServerTimeNow() >= nextAt then
				if not startNext() then
					nextAt = workspace:GetServerTimeNow() + 30 -- try again soon
				end
			end
			publish()
		end
	end)
end

return LobbyEventService
