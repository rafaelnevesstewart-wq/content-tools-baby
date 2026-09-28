-- Server entry point. init() builds things, start() connects events.

local Services = script.Parent.Services

local order = {
	"DataService",
	"MatchService", -- builds the world, so it runs before anything that needs it
	"WeatherService",
	"MovementService",
	"IncomeService",
	"IndexService",
	"SeasonService",
	"RewardService",
	"BlockService",
	"CombatService",
	"ItemShopService",
	"KitService",
	"ObbyService",
	"MarketService",
	"CommunityService",
	"LeaderboardService",
	"SpinService",
	"AdminService",
	"HolidayService",
	"DailyService",
	"TitleService",
	"CosmeticService",
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

print("[Bottle a Storm: Bed Wars] Server ready")
