-- Server entry point. init() builds things, start() connects events.

local Services = script.Parent.Services

local order = {
	"DataService",
	"PartyService",
	"ClanService",
	"VoteService",
	"MapService",
	"MatchService", -- builds the world, so it runs before anything that needs it
	"WeatherService",
	"MovementService",
	"IncomeService",
	"IndexService",
	"SeasonService",
	"RewardService",
	"BlockService",
	"CombatService",
	"GadgetService",
	"ItemShopService",
	"KitService",
	"KitPowerService",
	"ObbyService",
	"LobbyService",
	"TournamentService",
	"LuckyService",
	"BotService",
	"BossService",
	"ZombieService",
	"HillService",
	"ChallengeService",
	"SettingsService",
	"ChestService",
	"StatsService",
	"MarketService",
	"CommunityService",
	"LeaderboardService",
	"SpinService",
	"AdminService",
	"HolidayService",
	"DailyService",
	"TitleService",
	"ProgressionService",
	"CosmeticService",
	"TradeService",
	"PaintService",
	"EmoteService",
	"PetLevelService",
	"InviteService",
	"NewsService",
	"TauntService",
	"MountService",
	"MiniGameService",
	"BaseService",
	"MonetizationService",
}

local services = {}
for _, name in order do
	services[name] = require(Services:FindFirstChild(name))
end

-- One broken piece must never stop the rest of the game from starting, so
-- each step runs on its own and problems are printed to the Output.
local function run(name: string, step: string, fn: () -> ())
	local ok, problem = pcall(fn)
	if not ok then
		warn("[Bottle a Storm] " .. name .. "." .. step .. " failed: " .. tostring(problem))
	end
end

for _, name in order do
	local service = services[name]
	if service.init then
		run(name, "init", service.init)
	end
end

-- DataService starts last: loading profiles fires ProfileLoaded, and every
-- other service must already be listening by then.
for _, name in order do
	local service = services[name]
	if service.start and name ~= "DataService" then
		run(name, "start", service.start)
	end
end
services.DataService.start()

print("[Bottle a Storm: Bed Wars] Server ready")
