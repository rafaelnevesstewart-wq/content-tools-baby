-- Entry point: loads every service, runs Init on all of them, then Start.
-- Each step is protected, so one broken service shows an error in Output
-- instead of stopping the whole game from starting.

local Services = {}
local ORDER = {
	"DataService",
	"ShopService",
	"PlayerService",
	"TitanService",
	"WorldService",
	"CycleService",
	"MonsterService",
	"CombatService",
	"QuestService",
	"StealService",
}

local folder = script.Parent:WaitForChild("Services")
for _, name in ORDER do
	Services[name] = require(folder:WaitForChild(name))
end

for _, name in ORDER do
	local service = Services[name]
	if service.Init then
		local ok, err = pcall(service.Init, service, Services)
		if not ok then
			warn(string.format("[Main] %s failed to start: %s", name, tostring(err)))
		end
	end
end

for _, name in ORDER do
	local service = Services[name]
	if service.Start then
		task.spawn(function()
			local ok, err = xpcall(service.Start, debug.traceback, service)
			if not ok then
				warn(string.format("[Main] %s stopped with an error: %s", name, tostring(err)))
			end
		end)
	end
end
