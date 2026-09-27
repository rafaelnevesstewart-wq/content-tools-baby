--!strict
-- Storm battles: each storm's weather type, attack and HP. Shared so the
-- battle window can show the same numbers the server uses.
--
-- Weather types go in a circle; each beats the next one:
--   Wind blows away Rain, Rain soaks Thunder, Thunder melts Ice, Ice freezes Wind.

local StormData = require(script.Parent.StormData)

export type Element = {
	key: string,
	name: string,
	emoji: string,
	move: string, -- attack name shown in the battle log
	beats: string,
	color: Color3,
}

local BattleData = {}

BattleData.Elements = {
	Wind = {
		key = "Wind",
		name = "Wind",
		emoji = "🌪️",
		move = "Gust Slam",
		beats = "Rain",
		color = Color3.fromRGB(150, 220, 200),
	},
	Rain = {
		key = "Rain",
		name = "Rain",
		emoji = "🌧️",
		move = "Splash Wave",
		beats = "Thunder",
		color = Color3.fromRGB(120, 170, 255),
	},
	Thunder = {
		key = "Thunder",
		name = "Thunder",
		emoji = "⚡",
		move = "Zap Bolt",
		beats = "Ice",
		color = Color3.fromRGB(255, 210, 70),
	},
	Ice = {
		key = "Ice",
		name = "Ice",
		emoji = "❄️",
		move = "Hail Storm",
		beats = "Wind",
		color = Color3.fromRGB(170, 225, 255),
	},
} :: { [string]: Element }

-- Riding powers already group storms by weather, so battles reuse them.
local BY_ABILITY: { [string]: string } = {
	Updraft = "Wind",
	CloudJump = "Rain",
	BlinkDash = "Thunder",
	Surf = "Ice",
}

function BattleData.elementOf(def: StormData.StormDef): Element
	return BattleData.Elements[BY_ABILITY[StormData.abilityOf(def)] or "Wind"]
end

-- `strong` (x1.5) when `attacker` beats `defender`, 1 / strong the other way
-- round, else 1.
function BattleData.advantage(attacker: Element, defender: Element, strong: number): number
	if attacker.beats == defender.key then
		return strong
	elseif defender.beats == attacker.key then
		return 1 / strong
	end
	return 1
end

-- Attack power: rarer, mutated and higher-level storms hit harder.
function BattleData.attackOf(record: { id: string, mut: string?, xp: number? }): number
	local def = StormData.get(record.id)
	if not def then
		return 0
	end
	local mutation = StormData.getMutation(record.mut)
	local mutationBoost = if mutation then math.sqrt(mutation.multiplier) else 1
	return 10 * 1.6 ^ (def.rarity - 1) * mutationBoost * StormData.levelMultiplier(record)
end

function BattleData.hpOf(record: { id: string, mut: string?, xp: number? }): number
	return BattleData.attackOf(record) * 6
end

return BattleData
