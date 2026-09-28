--!strict
-- Match weather: events that shake up a Bed Wars match while it runs (see
-- WeatherService for when they happen). The forecast TV in the lobby and the
-- HUD show what's on and what's next.

export type WeatherEvent = {
	key: string,
	name: string,
	emoji: string,
	description: string,
	generators: number?, -- every generator runs this much faster
	middle: number?, -- only the middle island's Crystal and Core generators
	knockback: number?, -- hits push this much harder
	sparks: number?, -- Sparks from matches are multiplied by this
	gravity: number?, -- share of normal gravity (lower = jump higher)
	lighting: {
		ClockTime: number,
		Ambient: Color3,
		OutdoorAmbient: Color3,
		AtmosphereColor: Color3,
		AtmosphereDensity: number?,
	},
}

local WeatherEvents = {}

WeatherEvents.List = {
	{
		key = "Thunderstorm",
		name = "Thunderstorm",
		emoji = "⛈️",
		description = "Every generator runs twice as fast. Stock up!",
		generators = 2,
		lighting = {
			ClockTime = 18.2,
			Ambient = Color3.fromRGB(90, 90, 130),
			OutdoorAmbient = Color3.fromRGB(120, 120, 170),
			AtmosphereColor = Color3.fromRGB(120, 120, 170),
		},
	},
	{
		key = "RainbowHour",
		name = "Rainbow Hour",
		emoji = "🌈",
		description = "Double Sparks for every knockout, bed and win!",
		sparks = 2,
		lighting = {
			ClockTime = 16,
			Ambient = Color3.fromRGB(170, 130, 190),
			OutdoorAmbient = Color3.fromRGB(230, 180, 230),
			AtmosphereColor = Color3.fromRGB(255, 190, 230),
		},
	},
	{
		key = "Windstorm",
		name = "Windstorm",
		emoji = "🌬️",
		description = "Hits knock people 60% farther. Careful near the edge!",
		knockback = 1.6,
		lighting = {
			ClockTime = 14,
			Ambient = Color3.fromRGB(150, 165, 175),
			OutdoorAmbient = Color3.fromRGB(190, 205, 215),
			AtmosphereColor = Color3.fromRGB(200, 215, 225),
		},
	},
	{
		key = "FogNight",
		name = "Fog Night",
		emoji = "🌫️",
		description = "Thick fog! Nobody can see you sneaking up on their bed.",
		lighting = {
			ClockTime = 21,
			Ambient = Color3.fromRGB(120, 125, 150),
			OutdoorAmbient = Color3.fromRGB(140, 145, 175),
			AtmosphereColor = Color3.fromRGB(200, 205, 225),
			AtmosphereDensity = 0.62,
		},
	},
	{
		key = "MeteorNight",
		name = "Meteor Shower",
		emoji = "🌠",
		description = "The middle island's Crystal and Core generators run 3x faster!",
		middle = 3,
		lighting = {
			ClockTime = 0,
			Ambient = Color3.fromRGB(110, 100, 170),
			OutdoorAmbient = Color3.fromRGB(140, 130, 200),
			AtmosphereColor = Color3.fromRGB(70, 60, 130),
		},
	},
	{
		key = "MoonGravity",
		name = "Moon Gravity",
		emoji = "🌙",
		description = "Low gravity: jump super high and fly farther when hit!",
		gravity = 0.45,
		lighting = {
			ClockTime = 23,
			Ambient = Color3.fromRGB(120, 130, 170),
			OutdoorAmbient = Color3.fromRGB(150, 160, 210),
			AtmosphereColor = Color3.fromRGB(110, 120, 170),
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
