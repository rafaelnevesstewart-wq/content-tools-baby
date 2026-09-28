--!strict
-- Holiday events: limited-time themed events on real calendar dates (UTC).
-- While one is on, every Bed Wars match earns the event currency (playing,
-- knockouts, beds, wins), the lobby gets themed decorations, and the event
-- shop (🏪 Market → event tab) sells its exclusive kits. Outside the dates
-- nothing shows.

export type ShopItem = {
	label: string,
	cost: number, -- event currency
	stormId: string?, -- an exclusive kit, or...
	reward: { [string]: any }?, -- ...a battle pass style reward
}

export type Holiday = {
	key: string,
	name: string,
	emoji: string,
	currency: string, -- "Candy"
	currencyEmoji: string,
	from: { month: number, day: number },
	to: { month: number, day: number }, -- may wrap past New Year
	decor: string, -- "pumpkins" | "snowmen" | "umbrellas"
	storms: { string }, -- exclusive kits: Epic, Legendary
	shop: { ShopItem },
}

local HolidayData = {}

HolidayData.List = {
	{
		key = "Halloween",
		name = "Spooky Skies",
		emoji = "🎃",
		currency = "Candy",
		currencyEmoji = "🍬",
		from = { month = 10, day = 15 },
		to = { month = 11, day = 5 },
		decor = "pumpkins",
		storms = { "SpookyFog", "PhantomSquall" },
		shop = {},
	},
	{
		key = "Winter",
		name = "Frosty Skies",
		emoji = "🎄",
		currency = "Snowflakes",
		currencyEmoji = "❄️",
		from = { month = 12, day = 10 },
		to = { month = 1, day = 6 },
		decor = "snowmen",
		storms = { "FrostbiteFlurry", "JollyNoreaster" },
		shop = {},
	},
	{
		key = "Summer",
		name = "Sunny Skies",
		emoji = "🏖️",
		currency = "Seashells",
		currencyEmoji = "🐚",
		from = { month = 6, day = 20 },
		to = { month = 7, day = 20 },
		decor = "umbrellas",
		storms = { "BeachBreeze", "TropicalTyphoon" },
		shop = {},
	},
} :: { Holiday }

-- Every event's shop has the same layout: its two kits and a few extras.
for _, holiday in HolidayData.List do
	holiday.shop = {
		{ label = "Epic event kit", cost = 60, stormId = holiday.storms[1] },
		{ label = "LEGENDARY event kit", cost = 300, stormId = holiday.storms[2] },
		{ label = "💙 Random Rare kit", cost = 25, reward = { kind = "kit", rarity = 3 } },
		{ label = "⚡ 1,000 Sparks", cost = 15, reward = { kind = "sparks", amount = 1000 } },
	}
end

-- Event currency earned in matches.
HolidayData.Points = { Played = 3, Kill = 2, FinalKill = 4, Bed = 5, Win = 8 }

function HolidayData.get(key: string?): Holiday?
	for _, holiday in HolidayData.List do
		if holiday.key == key then
			return holiday
		end
	end
	return nil
end

local function inRange(month: number, day: number, holiday: Holiday): boolean
	local value = month * 100 + day
	local from = holiday.from.month * 100 + holiday.from.day
	local to = holiday.to.month * 100 + holiday.to.day
	if from <= to then
		return value >= from and value <= to
	end
	return value >= from or value <= to -- wraps past New Year
end

-- The holiday on right now (UTC), if any, and a key unique to this year's run
-- (so the currency resets each year).
function HolidayData.active(now: number): (Holiday?, string?)
	local date = os.date("!*t", now)
	for _, holiday in HolidayData.List do
		if inRange(date.month, date.day, holiday) then
			local year = if holiday.from.month > holiday.to.month and date.month <= holiday.to.month
				then date.year - 1
				else date.year
			return holiday, holiday.key .. year
		end
	end
	return nil, nil
end

-- When the running holiday ends (os.time), for the countdown.
function HolidayData.endsAt(now: number, holiday: Holiday): number
	local date = os.date("!*t", now)
	local year = if holiday.to.month < date.month then date.year + 1 else date.year
	return os.time({ year = year, month = holiday.to.month, day = holiday.to.day, hour = 23, min = 59, sec = 59 })
end

return HolidayData
