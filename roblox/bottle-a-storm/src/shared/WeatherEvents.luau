--!strict
-- Server-wide weather events. The forecast TV counts down to the next one.

export type WeatherEvent = {
	key: string,
	name: string,
	emoji: string,
	description: string,
	rarityMultipliers: { number }, -- spawn weight multiplier per rarity index
	spawnRateMultiplier: number,
	extraStorms: number, -- raises the wild storm cap while the event runs
	mutationChanceMultiplier: number,
	mutationBoosts: { [string]: number }, -- mutation id -> weight multiplier
	lighting: {
		ClockTime: number,
		Ambient: Color3,
		OutdoorAmbient: Color3,
		AtmosphereColor: Color3,
	},
}

local WeatherEvents = {}

WeatherEvents.List = {
	{
		key = "RainbowHour",
		name = "Rainbow Hour",
		emoji = "🌈",
		description = "Rare, Epic and Legendary storms are 3x more common!",
		rarityMultipliers = { 1, 1, 3, 3, 3 },
		spawnRateMultiplier = 1,
		extraStorms = 4,
		mutationChanceMultiplier = 1.5,
		mutationBoosts = { Prismatic = 5 },
		lighting = {
			ClockTime = 16,
			Ambient = Color3.fromRGB(170, 130, 190),
			OutdoorAmbient = Color3.fromRGB(230, 180, 230),
			AtmosphereColor = Color3.fromRGB(255, 190, 230),
		},
	},
	{
		key = "ThunderFrenzy",
		name = "Thunder Frenzy",
		emoji = "⛈️",
		description = "Storms spawn twice as fast and Charged mutations are everywhere!",
		rarityMultipliers = { 1, 1, 1.5, 1.5, 1.5 },
		spawnRateMultiplier = 2,
		extraStorms = 8,
		mutationChanceMultiplier = 3,
		mutationBoosts = { Charged = 3 },
		lighting = {
			ClockTime = 18.2,
			Ambient = Color3.fromRGB(90, 90, 130),
			OutdoorAmbient = Color3.fromRGB(120, 120, 170),
			AtmosphereColor = Color3.fromRGB(120, 120, 170),
		},
	},
	{
		key = "MeteorNight",
		name = "Meteor Night",
		emoji = "🌠",
		description = "Epic and Legendary storms fall from the sky!",
		rarityMultipliers = { 1, 1, 2, 5, 5 },
		spawnRateMultiplier = 1.25,
		extraStorms = 4,
		mutationChanceMultiplier = 1,
		mutationBoosts = { Void = 5, Golden = 2 },
		lighting = {
			ClockTime = 0,
			Ambient = Color3.fromRGB(110, 100, 170),
			OutdoorAmbient = Color3.fromRGB(140, 130, 200),
			AtmosphereColor = Color3.fromRGB(70, 60, 130),
		},
	},
} :: { WeatherEvent }

local byKey: { [string]: WeatherEvent } = {}
for _, event in WeatherEvents.List do
	byKey[event.key] = event
end

function WeatherEvents.get(key: string?): WeatherEvent?
	if key == nil or key == "" then
		return nil
	end
	return byKey[key]
end

return WeatherEvents
