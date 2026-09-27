-- Server-wide weather events on a timer. Publishes the current and next event
-- as workspace attributes; the forecast TV and HUD count down from those.

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local WeatherEvents = require(Shared.WeatherEvents)

local Modules = script.Parent.Parent.Modules
local Notify = require(Modules.Notify)

local StormSpawner = require(script.Parent.StormSpawner)

local WeatherService = {}

local current: WeatherEvents.WeatherEvent? = nil
local endsAt = 0
local nextEvent: WeatherEvents.WeatherEvent = WeatherEvents.List[1]
local nextAt = 0
local rng = Random.new()

type LightingState = {
	ClockTime: number,
	Ambient: Color3,
	OutdoorAmbient: Color3,
	AtmosphereColor: Color3,
}
local baseline: LightingState

local function now(): number
	return workspace:GetServerTimeNow()
end

local function publish()
	workspace:SetAttribute("WeatherEvent", if current then current.key else "")
	workspace:SetAttribute("WeatherEndsAt", endsAt)
	workspace:SetAttribute("NextWeather", nextEvent.key)
	workspace:SetAttribute("NextWeatherAt", nextAt)
end

local function applyLighting(state: LightingState)
	local info = TweenInfo.new(4, Enum.EasingStyle.Sine)
	TweenService:Create(Lighting, info, {
		ClockTime = state.ClockTime,
		Ambient = state.Ambient,
		OutdoorAmbient = state.OutdoorAmbient,
	}):Play()
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		TweenService:Create(atmosphere, info, { Color = state.AtmosphereColor }):Play()
	end
end

local function pickNext(except: string?): WeatherEvents.WeatherEvent
	local options = {}
	for _, event in WeatherEvents.List do
		if event.key ~= except then
			table.insert(options, event)
		end
	end
	return options[rng:NextInteger(1, #options)]
end

local function startEvent(event: WeatherEvents.WeatherEvent, summonedBy: string?)
	current = event
	endsAt = now() + Config.Weather.Duration
	nextEvent = pickNext(event.key)
	nextAt = endsAt + Config.Weather.Interval
	StormSpawner.setEvent(event)
	StormSpawner.burst(math.ceil(event.extraStorms / 2))
	applyLighting(event.lighting)
	publish()
	local who = if summonedBy then summonedBy .. " summoned " else ""
	Notify.all(event.emoji .. " " .. who .. string.upper(event.name) .. "! " .. event.description, "rare")
end

local function endEvent()
	local ended = current
	current = nil
	endsAt = 0
	StormSpawner.setEvent(nil)
	applyLighting(baseline)
	publish()
	if ended then
		Notify.all(ended.emoji .. " " .. ended.name .. " is over. Check the forecast TV for the next one!", "info")
	end
end

function WeatherService.current(): WeatherEvents.WeatherEvent?
	return current
end

-- Starts an event right away (the Robux "Summon Weather" product). If one is
-- already running, it gets longer instead.
function WeatherService.summon(key: string, byName: string?)
	local event = WeatherEvents.get(key)
	if not event then
		return
	end
	if current then
		endsAt += Config.Weather.Duration
		nextAt = endsAt + Config.Weather.Interval
		publish()
		local who = if byName then byName .. " extended " else "Extended "
		Notify.all(
			current.emoji .. " " .. who .. current.name .. " by " .. Config.Weather.Duration // 60 .. " minutes!",
			"rare"
		)
	else
		startEvent(event, byName)
	end
end

function WeatherService.init()
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	baseline = {
		ClockTime = Lighting.ClockTime,
		Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient,
		AtmosphereColor = if atmosphere then atmosphere.Color else Color3.fromRGB(200, 225, 255),
	}
	nextEvent = pickNext(nil)
	nextAt = now() + Config.Weather.FirstEventDelay
	publish()
end

function WeatherService.start()
	task.spawn(function()
		while true do
			task.wait(1)
			local t = now()
			if current and t >= endsAt then
				endEvent()
			elseif not current and t >= nextAt then
				startEvent(nextEvent, nil)
			end
		end
	end)
end

return WeatherService
