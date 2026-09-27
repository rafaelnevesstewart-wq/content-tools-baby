-- Client entry point.

local Controllers = script.Parent:WaitForChild("Controllers")

local order = {
	"Toasts",
	"Shop",
	"HUD",
	"CaptureMinigame",
	"PromptController",
	"ForecastController",
}

for _, name in order do
	local controller = require(Controllers:WaitForChild(name))
	controller.start()
end
