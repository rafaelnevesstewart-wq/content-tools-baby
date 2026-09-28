-- Client entry point.

local Controllers = script.Parent:WaitForChild("Controllers")

local order = {
	"Sfx",
	"Settings",
	"Aim",
	"Toasts",
	"Shop",
	"Season",
	"Rewards",
	"Market",
	"HolidayShop",
	"AdminPanel",
	"Style",
	"Kits",
	"Party",
	"Stats",
	"ItemShop",
	"HUD",
	"MatchHUD",
	"WeaponController",
	"BlockController",
	"KitController",
	"CameraController",
	"ForecastController",
	"StormAnimator",
	"FlashyFx",
	"AmbientController",
	"JuiceController",
	"KitFollower",
	"DamageFeed",
	"PetFollower",
	"TouchControls",
	"MusicController",
	"TournamentHUD",
}

for _, name in order do
	local controller = require(Controllers:WaitForChild(name))
	controller.start()
end
