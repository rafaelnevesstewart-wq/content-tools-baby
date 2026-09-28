--!strict
-- 🎪 The Weekly Event: a special rule for every match this week (a new one
-- every Monday, UTC). EventService shares the current one as the workspace
-- attribute "WeeklyEvent"; the rules only apply in matches.

local ChallengeData = require(script.Parent.ChallengeData)

export type WeeklyEvent = { key: string, name: string, emoji: string, description: string }

local EventData = {}

EventData.List = {
	{ key = "LowGravity", name = "Low Gravity", emoji = "🌙", description = "Jump sky high and float down slowly!" },
	{ key = "Giants", name = "Giant Mode", emoji = "🦣", description = "Everyone is a giant!" },
	{ key = "OneHit", name = "One Hit", emoji = "💥", description = "Every hit is a knockout. Careful!" },
	{ key = "SpeedRush", name = "Speed Rush", emoji = "⚡", description = "Everyone runs 40% faster!" },
	{ key = "DoubleSparks", name = "Double Sparks", emoji = "💰", description = "Every match pays double Sparks!" },
} :: { WeeklyEvent }

EventData.LowGravity = 70 -- normal is 196.2
EventData.GiantScale = 1.5
EventData.OneHitDamage = 10 -- times normal damage
EventData.SpeedRush = 1.4
EventData.DoubleSparks = 2

-- This week's event.
function EventData.current(now: number): WeeklyEvent
	local week = ChallengeData.week(now)
	return EventData.List[week % #EventData.List + 1]
end

-- Whether the event on right now (the "WeeklyEvent" attribute) is `key`.
function EventData.is(key: string): boolean
	return workspace:GetAttribute("WeeklyEvent") == key
end

return EventData
