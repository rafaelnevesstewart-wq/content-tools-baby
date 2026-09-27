-- Server entry point. init() builds things, start() connects events.

local Services = script.Parent.Services

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config)

local TYCOON = {
	"DataService",
	"PlotService", -- builds the world, so it runs before anything that needs it
	"StormSpawner",
	"WeatherService",
	"MovementService",
	"IncomeService",
	"CaptureService",
	"RideService",
	"MoodService",
	"IndexService",
	"SeasonService",
	"RewardService",
	"MixService",
	"TradeService",
	"StealService",
	"GuardService",
	"BuddyService",
	"ObbyService",
	"FlightService",
	"GrumpService",
	"BalloonService",
	"WeatherMutationService",
	"ParadeService",
	"MarketService",
	"CommunityService",
	"LeaderboardService",
	"SpinService",
	"AdminService",
	"HolidayService",
	"RaidService",
	"DailyService",
	"EventService",
	"BattleService",
	"TitleService",
	"AuraService",
	"ClimateService",
	"ThemeService",
	"HouseService",
	"CosmeticService",
	"ShopService",
	"MonetizationService",
}

-- Bed Wars rounds. The storm-catching tycoon services are switched off (not
-- deleted): set Config.GameMode = "Tycoon" to bring them back.
local BED_WARS = {
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
	"FlightService",
	"MarketService",
	"CommunityService",
	"LeaderboardService",
	"SpinService",
	"AdminService",
	"HolidayService",
	"DailyService",
	"BattleService",
	"TitleService",
	"CosmeticService",
	"ShopService",
	"MonetizationService",
}

local order = if Config.GameMode == "BedWars" then BED_WARS else TYCOON

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

print("[Bottle a Storm] Server ready (" .. Config.GameMode .. ")")
