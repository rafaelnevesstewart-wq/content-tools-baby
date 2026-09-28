--!strict
-- The daily prize wheel: one free spin a day, more with the Robux "3 Spins"
-- product. Prizes are Sparks and kits, in the battle pass reward format (see
-- SeasonData.Reward).

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
	{ label = "⚡ 200", reward = { kind = "sparks", amount = 200 }, weight = 22, color = rgb(70, 90, 130) },
	{ label = "🎁 Uncommon", reward = { kind = "kit", rarity = 2 }, weight = 14, color = rgb(70, 140, 80) },
	{ label = "⚡ 500", reward = { kind = "sparks", amount = 500 }, weight = 16, color = rgb(80, 110, 160) },
	{ label = "💙 Rare kit", reward = { kind = "kit", rarity = 3 }, weight = 12, color = rgb(60, 110, 190) },
	{ label = "⚡ 1,000", reward = { kind = "sparks", amount = 1000 }, weight = 12, color = rgb(100, 130, 180) },
	{ label = "💜 Epic kit", reward = { kind = "kit", rarity = 4 }, weight = 5, color = rgb(130, 70, 190) },
	{
		label = "✨ Shiny",
		reward = { kind = "kit", rarity = 3, mutated = true },
		weight = 7,
		color = rgb(190, 110, 60),
	},
	{ label = "⚡ 2,500", reward = { kind = "sparks", amount = 2500 }, weight = 7, color = rgb(120, 140, 190) },
	{ label = "⚡ 6,000", reward = { kind = "sparks", amount = 6000 }, weight = 3, color = rgb(170, 140, 50) },
	{ label = "🌟 LEGEND", reward = { kind = "kit", rarity = 5 }, weight = 1, color = rgb(210, 160, 30) },
} :: { Prize }

SpinData.SpinSeconds = 4 -- how long the wheel spins on screen

return SpinData
