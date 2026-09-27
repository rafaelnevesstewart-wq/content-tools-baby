-- Client entry point.

local Controllers = script.Parent:WaitForChild("Controllers")

local order = {
	"Sfx",
	"Aim",
	"Toasts",
	"Shop",
	"Trade",
	"Climate",
	"Season",
	"Rewards",
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
	"AmbientController",
	"JuiceController",
	"TutorialController",
	"BuddyController",
}

for _, name in order do
	local controller = require(Controllers:WaitForChild(name))
	controller.start()
end
