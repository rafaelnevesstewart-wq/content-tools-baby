-- Server entry point. init() builds things, start() connects events.

local Services = script.Parent.Services

local order = {
	"DataService",
	"PlotService", -- builds the world, so it runs before anything that needs it
	"StormSpawner",
	"WeatherService",
	"MovementService",
	"IncomeService",
	"CaptureService",
	"StealService",
	"ShopService",
	"MonetizationService",
}

local services = {}
for _, name in order do
	services[name] = require(Services:FindFirstChild(name))
end

for _, name in order do
	local service = services[name]
	if service.init then
		service.init()
	end
end

-- DataService starts last: loading profiles fires ProfileLoaded, and every
-- other service must already be listening by then.
for _, name in order do
	local service = services[name]
	if service.start and name ~= "DataService" then
		service.start()
	end
end
services.DataService.start()

print("[Bottle a Storm] Server ready")
