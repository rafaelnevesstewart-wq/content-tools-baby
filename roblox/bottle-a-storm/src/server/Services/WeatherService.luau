-- Match weather (see WeatherEvents): during a Bed Wars match, an event starts
-- every few minutes and changes the fight for a while (faster generators,
-- fog, double Sparks, stronger knockback, low gravity...). A summoned Rainbow
-- Hour (Robux) works any time. Publishes the current and next event as
-- workspace attributes for the forecast TV and HUD. Between events the sky
-- follows a day and night cycle (Config.DayNight).

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local WeatherEvents = require(Shared.WeatherEvents)

local Modules = script.Parent.Parent.Modules
local Notify = require(Modules.Notify)

local WeatherService = {}

local current: WeatherEvents.WeatherEvent? = nil
local endsAt = 0
local nextEvent: WeatherEvents.WeatherEvent = WeatherEvents.List[1]
local nextAt = 0
local rng = Random.new()
local NORMAL_GRAVITY = 196.2
local summoned = false -- summoned events keep going between matches

type LightingState = {
	ClockTime: number,
	Ambient: Color3,
	OutdoorAmbient: Color3,
	AtmosphereColor: Color3,
	AtmosphereDensity: number?,
}
local baseline: LightingState
local tweeningUntil = 0 -- the day cycle waits while a lighting tween plays

local NIGHT_AMBIENT = Color3.fromRGB(38, 44, 70)
local NIGHT_OUTDOOR = Color3.fromRGB(58, 64, 96)

local function now(): number
	return workspace:GetServerTimeNow()
end

local function publish()
	workspace:SetAttribute("WeatherEvent", if current then current.key else "")
	workspace:SetAttribute("WeatherEndsAt", endsAt)
	workspace:SetAttribute("NextWeather", nextEvent.key)
	workspace:SetAttribute("NextWeatherAt", nextAt)
end

-- 0 in the day, 1 at night, in between at dawn and dusk.
local function nightness(clock: number): number
	if clock >= 7 and clock <= 17 then
		return 0
	elseif clock > 17 and clock < 19 then
		return (clock - 17) / 2
	elseif clock > 5 and clock < 7 then
		return (7 - clock) / 2
	end
	return 1
end

-- What the sky looks like at time `t` with no event on: day runs from 7:00 to
-- 18:00, then night until 7:00 again.
local function dayState(t: number): LightingState
	local cycle = Config.DayNight.CycleSeconds
	local dayShare = 1 - Config.DayNight.NightShare
	local phase = (t % cycle) / cycle
	local clock
	if phase < dayShare then
		clock = 7 + phase / dayShare * 11
	else
		clock = (18 + (phase - dayShare) / Config.DayNight.NightShare * 13) % 24
	end
	local night = nightness(clock)
	return {
		ClockTime = clock,
		Ambient = baseline.Ambient:Lerp(NIGHT_AMBIENT, night),
		OutdoorAmbient = baseline.OutdoorAmbient:Lerp(NIGHT_OUTDOOR, night),
		AtmosphereColor = baseline.AtmosphereColor,
		AtmosphereDensity = baseline.AtmosphereDensity,
	}
end

local function applyLighting(requested: LightingState)
	local state = requested
	tweeningUntil = os.clock() + 4.2
	local info = TweenInfo.new(4, Enum.EasingStyle.Sine)
	TweenService:Create(Lighting, info, {
		ClockTime = state.ClockTime,
		Ambient = state.Ambient,
		OutdoorAmbient = state.OutdoorAmbient,
	}):Play()
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		TweenService:Create(atmosphere, info, {
			Color = state.AtmosphereColor,
			Density = state.AtmosphereDensity or baseline.AtmosphereDensity or atmosphere.Density,
		}):Play()
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

local function inMatch(): boolean
	return workspace:GetAttribute("MatchPhase") == "playing"
end

local function startEvent(event: WeatherEvents.WeatherEvent, summonedBy: string?, duration: number?)
	current = event
	summoned = summonedBy ~= nil
	endsAt = now() + (duration or Config.Weather.Duration)
	nextEvent = pickNext(event.key)
	nextAt = endsAt + Config.Weather.Interval
	workspace.Gravity = NORMAL_GRAVITY * (event.gravity or 1)
	applyLighting(event.lighting)
	publish()
	local who = if summonedBy then summonedBy .. " summoned " else ""
	Notify.all(event.emoji .. " " .. who .. string.upper(event.name) .. "! " .. event.description, "rare")
end

local function endEvent()
	local ended = current
	current = nil
	endsAt = 0
	workspace.Gravity = NORMAL_GRAVITY
	applyLighting(dayState(now() + 4))
	publish()
	if ended then
		Notify.all(ended.emoji .. " " .. ended.name .. " is over.", "info")
	end
end

function WeatherService.current(): WeatherEvents.WeatherEvent?
	return current
end

-- The weather's effect on match numbers (1 when no event is on).
function WeatherService.generatorMultiplier(middle: boolean): number
	local event = current
	if not event then
		return 1
	end
	return (event.generators or 1) * (if middle then event.middle or 1 else 1)
end

function WeatherService.knockbackMultiplier(): number
	return if current then current.knockback or 1 else 1
end

function WeatherService.sparksMultiplier(): number
	return if current then current.sparks or 1 else 1
end

-- Starts an event right away (admins, and the Robux "Summon Rainbow Hour").
-- If one is already running, it gets longer instead.
function WeatherService.summon(key: string, byName: string?, duration: number?)
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
		startEvent(event, byName, duration)
	end
end

function WeatherService.init()
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	baseline = {
		ClockTime = Lighting.ClockTime,
		Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient,
		AtmosphereColor = if atmosphere then atmosphere.Color else Color3.fromRGB(200, 225, 255),
		AtmosphereDensity = if atmosphere then atmosphere.Density else nil,
	}
	nextEvent = pickNext(nil)
	nextAt = 0 -- set when a match starts
	publish()
end

function WeatherService.start()
	-- The day and night cycle, whenever no event sets the sky.
	task.spawn(function()
		while true do
			task.wait(0.5)
			if not current and os.clock() >= tweeningUntil then
				local state = dayState(now())
				Lighting.ClockTime = state.ClockTime
				Lighting.Ambient = state.Ambient
				Lighting.OutdoorAmbient = state.OutdoorAmbient
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			local t = now()
			local playing = inMatch()
			if playing and nextAt == 0 then
				-- A match just started: the first event comes a little later.
				nextAt = t + Config.Weather.FirstEventDelay
				publish()
			elseif not playing and nextAt ~= 0 then
				nextAt = 0
				publish()
			end
			if current and (t >= endsAt or (not playing and not summoned)) then
				endEvent()
			elseif not current and playing and t >= nextAt then
				startEvent(nextEvent, nil, nil)
			end
		end
	end)
end

return WeatherService
