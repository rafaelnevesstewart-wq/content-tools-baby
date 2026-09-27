-- Climate Shift, the rebirth. When you have enough Sparks you can shift to the
-- next climate (Arctic, then Volcano, then Space):
--   * lose your Sparks, Boots of Wind and Lightning Rod level
--   * keep your storms, pedestals, jars, thief styles and passes
--   * earn a permanent x1.5 more (it stacks: x1.5, x2.25, x3.375)
--   * unlock that climate's sky island through its portal on the Wild Skies

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local ClimateData = require(Shared.ClimateData)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent.Parent.Modules
local Notify = require(Modules.Notify)
local WorldBuilder = require(Modules.WorldBuilder)

local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local MovementService = require(script.Parent.MovementService)

local ClimateService = {}

local lastPortal: { [Player]: number } = {}
local lastShift: { [Player]: number } = {}

local function shift(player: Player): (boolean, string)
	local data = DataService.get(player)
	if not data then
		return false, "Your data isn't loaded yet."
	end
	if os.clock() - (lastShift[player] or 0) < 2 then
		return false, "Slow down!"
	end
	lastShift[player] = os.clock()
	local nextClimate = ClimateData.List[data.climate + 2]
	if not nextClimate then
		return false, "You've already reached the last climate!"
	end
	if player:GetAttribute("Carrying") then
		return false, "You can't shift while carrying a stolen storm!"
	end
	if data.sparks < nextClimate.cost then
		return false, "You need ⚡" .. Format.number(nextClimate.cost - data.sparks) .. " more Sparks to shift."
	end

	data.sparks = 0
	data.unclaimed = 0
	data.bootsLevel = 0
	data.trapLevel = 0
	data.climate = nextClimate.level
	data.stats.shifts += 1
	IncomeService.sync(player)
	MovementService.refresh(player)
	task.spawn(DataService.saveNow, player)

	Notify.allExcept(
		player,
		"🌍 " .. player.DisplayName .. " shifted to the " .. nextClimate.emoji .. " " .. nextClimate.name .. "!",
		"rare"
	)
	return true,
		"🌍 Welcome to the "
			.. nextClimate.emoji
			.. " "
			.. nextClimate.name
			.. "! You now earn x"
			.. nextClimate.multiplier
			.. " forever. Its portal on the Wild Skies is open!"
end

local function playerFromHit(hit: BasePart): Player?
	local model = hit:FindFirstAncestorOfClass("Model")
	return if model then Players:GetPlayerFromCharacter(model) else nil
end

local function teleport(player: Player, destination: CFrame)
	local character = player.Character
	if character then
		character:PivotTo(destination)
	end
end

local function connectPortal(pad: BasePart)
	pad.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		if not player or os.clock() - (lastPortal[player] or 0) < 2 then
			return
		end
		lastPortal[player] = os.clock()
		local data = DataService.get(player)
		if not data then
			return
		end
		if player:GetAttribute("Carrying") then
			Notify.player(player, "Portals won't take stolen storms! Run home first.", "warn")
			return
		end
		if pad:GetAttribute("Destination") == "Wild" then
			teleport(player, WorldBuilder.WildArrival)
			return
		end
		local climateKey = pad:GetAttribute("Climate")
		local climate = if type(climateKey) == "string" then ClimateData.get(climateKey) else nil
		local biome = climate and WorldBuilder.Biomes[climate.key]
		if not climate or not biome then
			return
		end
		if data.climate < climate.level then
			Notify.player(
				player,
				"🔒 The "
					.. climate.name
					.. " opens at Climate Shift "
					.. climate.level
					.. ". Press 🌍 Climate to see what you need.",
				"warn"
			)
			return
		end
		teleport(player, biome.spawn)
		Notify.player(player, climate.emoji .. " Welcome to the " .. climate.name .. "!", "success")
	end)
end

function ClimateService.start()
	Remotes.func("ClimateShift").OnServerInvoke = shift

	local world = workspace:WaitForChild("World")
	for _, pad in world:WaitForChild("Portals"):GetChildren() do
		if pad:IsA("BasePart") then
			connectPortal(pad)
		end
	end
	for _, island in world:WaitForChild("Biomes"):GetChildren() do
		local back = island:FindFirstChild("ReturnPortal")
		if back and back:IsA("BasePart") then
			connectPortal(back)
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		lastPortal[player] = nil
		lastShift[player] = nil
	end)
end

return ClimateService
