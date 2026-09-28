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
	"Paint",
	"Style",
	"Kits",
	"Trade",
	"Party",
	"Stats",
	"Challenges",
	"Clan",
	"ItemShop",
	"HUD",
	"Vote",
	"MatchHUD",
	"WeaponController",
	"BlockController",
	"BlockPhysics",
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
	"SpectateController",
	"BossHUD",
	"ZombieHUD",
	"EmoteWheel",
	"ShopStreet",
}

for _, name in order do
	local controller = require(Controllers:WaitForChild(name))
	controller.start()
end
