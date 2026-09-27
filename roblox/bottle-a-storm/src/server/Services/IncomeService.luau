-- Every storm on a pedestal earns Sparks each second. Sparks pile up on the
-- island's Collect pad until the owner steps on it (or go straight to the
-- wallet with the Auto-Collect pass). Also mirrors profile numbers onto
-- player attributes and leaderstats so the client UI can read them.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local ClimateData = require(Shared.ClimateData)
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)
local Products = require(Shared.Products)
local StormData = require(Shared.StormData)

local Modules = script.Parent.Parent.Modules
local Notify = require(Modules.Notify)

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)

local IncomeService = {}

local lastCollectToast: { [Player]: number } = {}

local function hasPass(player: Player, key: string): boolean
	return player:GetAttribute(Products.passAttribute(key)) == true
end

-- Sparks per second for this player right now, VIP included.
function IncomeService.rateOf(player: Player): number
	local data = DataService.get(player)
	if not data then
		return 0
	end
	local total = 0
	for _, record in data.storms do
		if not PlotService.isSlotStolen(player, record.slot) then
			total += StormData.earningOf(record)
		end
	end
	if hasPass(player, "VIP") then
		total *= Config.Income.VIPMultiplier
	end
	return total * ClimateData.at(data.climate).multiplier
end

-- Pushes the profile's numbers to attributes, leaderstats and the collect pad.
function IncomeService.sync(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	player:SetAttribute("Sparks", math.floor(data.sparks))
	player:SetAttribute("Unclaimed", math.floor(data.unclaimed))
	player:SetAttribute("IncomePerSec", IncomeService.rateOf(player))
	player:SetAttribute("JarTier", data.jarTier)
	player:SetAttribute("Pedestals", data.pedestals)
	player:SetAttribute("MaxPedestals", Economy.maxPedestals(hasPass(player, "DoubleSlots")))
	player:SetAttribute("BootsLevel", data.bootsLevel)
	player:SetAttribute("TrapLevel", data.trapLevel)
	player:SetAttribute("RaidShields", data.raidShields)
	player:SetAttribute("ThiefStyle", data.thiefStyle)
	player:SetAttribute("Climate", data.climate)
	local unlocked = {}
	for key in data.thiefStyles do
		table.insert(unlocked, key)
	end
	player:SetAttribute("UnlockedStyles", table.concat(unlocked, ","))
	player:SetAttribute("StormCount", #data.storms)
	local baseIncome = 0
	for _, record in data.storms do
		baseIncome += StormData.incomeOf(record)
	end
	player:SetAttribute("SnackCost", Economy.snackCost(baseIncome))

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local sparksValue = leaderstats:FindFirstChild("Sparks") :: IntValue
		local stormsValue = leaderstats:FindFirstChild("Storms") :: IntValue
		sparksValue.Value = math.floor(math.min(data.sparks, 2 ^ 53))
		stormsValue.Value = #data.storms
	end

	if hasPass(player, "AutoCollect") then
		PlotService.setCollectText(player, "💰 Auto-Collect ON")
	else
		PlotService.setCollectText(player, "💰 Collect\n⚡ " .. Format.number(data.unclaimed))
	end
end

function IncomeService.addSparks(player: Player, amount: number)
	local data = DataService.get(player)
	if data then
		data.sparks += amount
		data.stats.sparksEarned += amount
		IncomeService.sync(player)
	end
end

function IncomeService.collect(player: Player)
	local data = DataService.get(player)
	if not data or data.unclaimed < 1 then
		return
	end
	local amount = math.floor(data.unclaimed)
	data.unclaimed -= amount
	data.sparks += amount
	IncomeService.sync(player)
	if os.clock() - (lastCollectToast[player] or 0) > 3 then
		lastCollectToast[player] = os.clock()
		Notify.player(player, "💰 Collected ⚡" .. Format.number(amount) .. "!", "success")
	end
end

local function tick(dt: number)
	for _, player in Players:GetPlayers() do
		local data = DataService.get(player)
		if data and PlotService.getPlot(player) then
			local earned = IncomeService.rateOf(player) * dt
			if earned > 0 then
				data.stats.sparksEarned += earned
				if hasPass(player, "AutoCollect") then
					data.sparks += earned
				else
					data.unclaimed += earned
				end
			end
			IncomeService.sync(player)
		end
	end
end

local function createLeaderstats(player: Player)
	if player:FindFirstChild("leaderstats") then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local sparks = Instance.new("IntValue")
	sparks.Name = "Sparks"
	sparks.Parent = folder
	local stormCount = Instance.new("IntValue")
	stormCount.Name = "Storms"
	stormCount.Parent = folder
	folder.Parent = player
end

function IncomeService.start()
	DataService.ProfileLoaded:Connect(function(player)
		createLeaderstats(player)
		IncomeService.sync(player)
	end)
	PlotService.PlotAssigned:Connect(IncomeService.sync)
	PlotService.CollectTouched:Connect(IncomeService.collect)
	Players.PlayerRemoving:Connect(function(player)
		lastCollectToast[player] = nil
	end)

	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(Config.Income.TickSeconds)
			local t = os.clock()
			tick(t - last)
			last = t
		end
	end)
end

return IncomeService
