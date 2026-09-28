--!strict
-- 🎟️ Custom private matches (CustomMatchService): in a private server, its
-- owner picks the rules for every match there. The rules are shared as the
-- workspace attribute "CustomRules" (JSON: option key -> choice); anything
-- not set uses the first choice (the normal game).

local HttpService = game:GetService("HttpService")

local EventData = require(script.Parent.EventData)
local MapData = require(script.Parent.MapData)
local MatchData = require(script.Parent.MatchData)

export type Option = { key: string, name: string, choices: { string }, labels: { [string]: string } }

local CustomData = {}

local function option(key: string, name: string): Option
	return { key = key, name = name, choices = {}, labels = {} }
end

local function add(o: Option, choice: string, label: string)
	table.insert(o.choices, choice)
	o.labels[choice] = label
end

local mode = option("mode", "🎮 Mode")
add(mode, "Vote", "🗳️ Players vote")
for _, m in MatchData.Modes do
	add(mode, m.key, m.emoji .. " " .. m.name)
end

local map = option("map", "🗺️ Map")
add(map, "Vote", "🗳️ Vote or random")
for _, m in MapData.List do
	add(map, m.key, m.emoji .. " " .. m.name)
end

local event = option("event", "🎪 Special rule")
add(event, "Weekly", "📅 This week's event")
add(event, "None", "🚫 None")
for _, e in EventData.List do
	add(event, e.key, e.emoji .. " " .. e.name)
end

local generators = option("generators", "⛏️ Generator speed")
add(generators, "1", "Normal")
add(generators, "2", "⏩ Double")
add(generators, "3", "⏩⏩ Triple")

local bots = option("bots", "🤖 Bots")
add(bots, "Vote", "🗳️ Players vote")
add(bots, "Off", "🚫 No bots")
add(bots, "Easy", "🟢 Easy")
add(bots, "Normal", "🟡 Normal")
add(bots, "Hard", "🔴 Hard")

local boss = option("boss", "🐉 Storm Dragon boss")
add(boss, "On", "✅ On")
add(boss, "Off", "🚫 Off")

CustomData.Options = { mode, map, event, generators, bots, boss } :: { Option }

function CustomData.option(key: string): Option?
	for _, o in CustomData.Options do
		if o.key == key then
			return o
		end
	end
	return nil
end

-- All the rules in play (every option, defaults filled in).
function CustomData.rules(): { [string]: string }
	local raw = workspace:GetAttribute("CustomRules")
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, if type(raw) == "string" then raw else "{}")
	local saved = if ok and type(decoded) == "table" then decoded else {}
	local rules = {}
	for _, o in CustomData.Options do
		local value = saved[o.key]
		rules[o.key] = if type(value) == "string" and o.labels[value] then value else o.choices[1]
	end
	return rules
end

-- The choice for one option (its first choice when it's not changed).
function CustomData.get(key: string): string
	return CustomData.rules()[key] or ""
end

-- Whether anything is different from the normal game.
function CustomData.changed(): boolean
	for key, value in CustomData.rules() do
		local o = CustomData.option(key)
		if o and value ~= o.choices[1] then
			return true
		end
	end
	return false
end

return CustomData
