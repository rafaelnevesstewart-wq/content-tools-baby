-- Client entry point.

local Controllers = script.Parent:WaitForChild("Controllers")

local order = {
	"Sfx",
	"Toasts",
	"Shop",
	"Trade",
	"Climate",
	"Season",
	"HUD",
	"BiomeController",
	"ThrowController",
	"RideController",
	"Mixer",
	"PromptController",
	"ForecastController",
	"StormAnimator",
	"AmbientController",
	"JuiceController",
}

for _, name in order do
	local controller = require(Controllers:WaitForChild(name))
	controller.start()
end
