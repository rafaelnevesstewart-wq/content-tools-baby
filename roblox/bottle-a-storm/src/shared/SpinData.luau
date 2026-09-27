--!strict
-- The daily prize wheel: one free spin a day, more with the Robux "3 Spins"
-- product. Rewards use the season pass format (see SeasonData.Reward).

local SeasonData = require(script.Parent.SeasonData)

export type Prize = {
	label: string,
	reward: SeasonData.Reward,
	weight: number,
	color: Color3,
}

local rgb = Color3.fromRGB

local SpinData = {}

SpinData.Prizes = {
	{
		label = "⚡ 10 min",
		reward = { kind = "sparks", minutes = 10, min = 1000 },
		weight = 24,
		color = rgb(70, 90, 130),
	},
	{ label = "🍪 Snacks", reward = { kind = "snacks" }, weight = 14, color = rgb(150, 100, 70) },
	{
		label = "⚡ 30 min",
		reward = { kind = "sparks", minutes = 30, min = 3000 },
		weight = 14,
		color = rgb(80, 110, 160),
	},
	{ label = "🛡️ Shield", reward = { kind = "shield", amount = 1 }, weight = 8, color = rgb(90, 130, 110) },
	{ label = "🫙 Rare", reward = { kind = "storm", rarity = 3 }, weight = 12, color = rgb(60, 110, 190) },
	{
		label = "⚡ 1 hour",
		reward = { kind = "sparks", minutes = 60, min = 8000 },
		weight = 8,
		color = rgb(100, 130, 180),
	},
	{ label = "💜 Epic", reward = { kind = "storm", rarity = 4 }, weight = 5, color = rgb(130, 70, 190) },
	{
		label = "✨ Mutated",
		reward = { kind = "storm", rarity = 3, mutated = true },
		weight = 7,
		color = rgb(190, 110, 60),
	},
	{
		label = "⚡ 3 hours",
		reward = { kind = "sparks", minutes = 180, min = 20000 },
		weight = 3,
		color = rgb(170, 140, 50),
	},
	{ label = "🌟 LEGEND", reward = { kind = "storm", rarity = 5 }, weight = 1, color = rgb(210, 160, 30) },
} :: { Prize }

SpinData.SpinSeconds = 4 -- how long the wheel spins on screen

return SpinData
