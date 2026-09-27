-- Client entry point.

local Controllers = script.Parent:WaitForChild("Controllers")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local TYCOON = {
	"Sfx",
	"Aim",
	"Toasts",
	"Shop",
	"Trade",
	"Climate",
	"Season",
	"Rewards",
	"Market",
	"HolidayShop",
	"AdminPanel",
	"Style",
	"PedestalMenu",
	"Battle",
	"HUD",
	"BiomeController",
	"ThrowController",
	"CombatController",
	"RideController",
	"FlightController",
	"Mixer",
	"PromptController",
	"ForecastController",
	"StormAnimator",
	"FlashyFx",
	"PetAnimator",
	"AmbientController",
	"JuiceController",
	"TutorialController",
	"BuddyController",
}

-- Bed Wars: the match screens and weapons instead of the storm-catching
-- tutorial, jar throwing and island menus.
local BED_WARS = {
	"Sfx",
	"Aim",
	"Toasts",
	"Shop",
	"Season",
	"Rewards",
	"Market",
	"HolidayShop",
	"AdminPanel",
	"Style",
	"Battle",
	"Kits",
	"ItemShop",
	"HUD",
	"MatchHUD",
	"WeaponController",
	"BlockController",
	"RideController",
	"FlightController",
	"ForecastController",
	"StormAnimator",
	"FlashyFx",
	"PetAnimator",
	"AmbientController",
	"JuiceController",
	"BuddyController",
}

local order = if Config.GameMode == "BedWars" then BED_WARS else TYCOON

for _, name in order do
	local controller = require(Controllers:WaitForChild(name))
	controller.start()
end
