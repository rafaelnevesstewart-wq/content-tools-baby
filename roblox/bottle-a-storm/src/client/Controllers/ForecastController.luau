-- Fills in the weather forecast TV in the lobby: the match weather on now,
-- or what's coming next.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Format)
local WeatherEvents = require(Shared.WeatherEvents)

local ForecastController = {}

local function screens(): { Instance }
	local world = workspace:FindFirstChild("World")
	local tv = world and world:FindFirstChild("ForecastTV")
	local screen = tv and tv:FindFirstChild("Screen")
	if not screen then
		return {}
	end
	local found = {}
	for _, gui in screen:GetChildren() do
		local background = gui:IsA("SurfaceGui") and gui:FindFirstChild("Background")
		if background then
			table.insert(found, background)
		end
	end
	return found
end

local function text(now: number): (string, string)
	local current = WeatherEvents.get(workspace:GetAttribute("WeatherEvent"))
	if current then
		local left = (workspace:GetAttribute("WeatherEndsAt") or now) - now
		return current.emoji .. " " .. string.upper(current.name) .. " NOW!",
			current.description .. "  Ends in " .. Format.time(left)
	end
	local nextEvent = WeatherEvents.get(workspace:GetAttribute("NextWeather"))
	local nextAt = workspace:GetAttribute("NextWeatherAt")
	if nextEvent and type(nextAt) == "number" and nextAt > now then
		return "Next: " .. nextEvent.emoji .. " " .. nextEvent.name,
			"In " .. Format.time(nextAt - now) .. ". " .. nextEvent.description
	end
	if nextEvent then
		return "Next match: " .. nextEvent.emoji .. " " .. nextEvent.name, nextEvent.description
	end
	return "☀️ Clear skies", ""
end

function ForecastController.start()
	task.spawn(function()
		while true do
			local headline, detail = text(workspace:GetServerTimeNow())
			for _, background in screens() do
				local headlineLabel = background:FindFirstChild("Headline") :: TextLabel?
				local detailLabel = background:FindFirstChild("Detail") :: TextLabel?
				if headlineLabel then
					headlineLabel.Text = headline
				end
				if detailLabel then
					detailLabel.Text = detail
				end
			end
			task.wait(0.5)
		end
	end)
end

return ForecastController
