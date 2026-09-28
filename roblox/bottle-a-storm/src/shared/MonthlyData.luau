--!strict
-- 🏅 The monthly season (MonthlyService): everyone earns Season Points in
-- matches this month; the top players win prizes when the month ends (you
-- get yours the next time you join). Saved as data.monthly.

local SeasonData = require(script.Parent.SeasonData)

export type Prize = { upTo: number, label: string, sparks: number, kit: number?, title: string? }

local MonthlyData = {}

MonthlyData.Points = {
	Played = 2, -- finishing a match
	Won = 10,
	Kill = 1,
	FinalKill = 2, -- on top of the knockout
	Bed = 3,
}

-- By final rank: the first row you fit in (upTo = the last rank it covers).
MonthlyData.Prizes = {
	{ upTo = 1, label = "🥇 #1", sparks = 25000, kit = 5, title = "MonthlyChampion" },
	{ upTo = 3, label = "🥈 #2-3", sparks = 15000, kit = 4, title = "MonthlyTop10" },
	{ upTo = 10, label = "🏅 #4-10", sparks = 8000, kit = 4, title = "MonthlyTop10" },
	{ upTo = 100, label = "🎖️ #11-100", sparks = 2000 },
} :: { Prize }
MonthlyData.ThanksSparks = 300 -- everyone else who scored at least 1 point

-- "2026-09" style key for the month of `now` (UTC).
function MonthlyData.key(now: number): string
	return os.date("!%Y-%m", now) :: string
end

-- The month's name, e.g. "September".
function MonthlyData.name(now: number): string
	return os.date("!%B", now) :: string
end

-- Seconds until the month ends.
function MonthlyData.secondsLeft(now: number): number
	local date = os.date("!*t", now) :: any
	local year, month = date.year, date.month + 1
	if month > 12 then
		year, month = year + 1, 1
	end
	local nextMonth = os.time({ year = year, month = month, day = 1, hour = 0, min = 0, sec = 0 } :: any)
	-- os.time reads the table as local time; correct it to UTC.
	local offset = os.time(os.date("*t", now) :: any) - os.time(os.date("!*t", now) :: any)
	return math.max(0, nextMonth + offset - now)
end

function MonthlyData.prizeFor(rank: number): Prize?
	for _, prize in MonthlyData.Prizes do
		if rank <= prize.upTo then
			return prize
		end
	end
	return nil
end

-- The kit a prize gives (nil for Sparks only).
function MonthlyData.kitReward(prize: Prize): SeasonData.Reward?
	return if prize.kit then { kind = "kit", rarity = prize.kit } :: SeasonData.Reward else nil
end

return MonthlyData
