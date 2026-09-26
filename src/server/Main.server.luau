-- Entry point: loads every service, runs Init on all of them, then Start.

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
	"StealService",
}

local folder = script.Parent:WaitForChild("Services")
for _, name in ORDER do
	Services[name] = require(folder:WaitForChild(name))
end

for _, name in ORDER do
	local service = Services[name]
	if service.Init then
		service:Init(Services)
	end
end

for _, name in ORDER do
	local service = Services[name]
	if service.Start then
		task.spawn(service.Start, service)
	end
end
