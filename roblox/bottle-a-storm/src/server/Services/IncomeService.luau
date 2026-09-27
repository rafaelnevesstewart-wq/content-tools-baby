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
local Signal = require(Shared.Signal)
local StormData = require(Shared.StormData)

local Modules = script.Parent.Parent.Modules
local Juice = require(Modules.Juice)
local Notify = require(Modules.Notify)

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local WeatherService = require(script.Parent.WeatherService)

local IncomeService = {}

-- (player, amount) whenever Sparks reach a player's wallet from their storms.
IncomeService.Collected = Signal.new()

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
	local event = WeatherService.current()
	local eventBonus = if event then event.incomeMultiplier or 1 else 1
	local indexBonus = 1 + Config.Index.RowBonus * (data.indexRows or 0)
	local groupBonus = if player:GetAttribute("InGroup") == true then 1 + Config.Group.Bonus else 1
	local abuseUntil = workspace:GetAttribute("AbuseUntil")
	local abuseBonus = if type(abuseUntil) == "number" and abuseUntil > workspace:GetServerTimeNow()
		then Config.Admin.AbuseIncomeMultiplier
		else 1
	local beginnerBonus = if (data.playSeconds or 0) < Config.Beginner.BoostSeconds
		then Config.Beginner.Multiplier
		else 1
	return total
		* ClimateData.at(data.climate).multiplier
		* eventBonus
		* indexBonus
		* beginnerBonus
		* groupBonus
		* abuseBonus
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
	player:SetAttribute("Captured", data.stats.captured)
	player:SetAttribute("IndexRows", data.indexRows or 0)
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
	local pad = PlotService.collectPadPosition(player)
	if pad then
		Juice.float(player, "+⚡" .. Format.number(amount), pad + Vector3.new(0, 3, 0), Color3.fromRGB(255, 200, 60))
	end
	if os.clock() - (lastCollectToast[player] or 0) > 1.2 then
		lastCollectToast[player] = os.clock()
		Juice.sound(player, "coins")
	end
	IncomeService.Collected:Fire(player, amount)
end

-- While you were away, your storms kept earning at a reduced rate.
local function payOffline(player: Player)
	local data = DataService.get(player)
	if not data or not data.lastSeen then
		return
	end
	local away = os.time() - data.lastSeen
	data.lastSeen = os.time()
	if away < Config.Offline.MinSeconds then
		return
	end
	local seconds = math.min(away, Config.Offline.MaxHours * 3600)
	local amount = math.floor(IncomeService.rateOf(player) * seconds * Config.Offline.Rate)
	if amount < 1 then
		return
	end
	data.sparks += amount
	IncomeService.sync(player)
	Juice.welcome(player, amount, away)
end

-- Storms level up the longer you own them (see StormData.LevelSeconds).
local function levelUp(player: Player, record: StormData.StormRecord)
	local level = StormData.levelOf(record)
	PlotService.refreshSlot(player, record.slot)
	local position = PlotService.slotPosition(player, record.slot)
	if position then
		Juice.float(player, "LEVEL UP! Lv " .. level, position + Vector3.new(0, 7, 0), Color3.fromRGB(120, 200, 255))
	end
	Juice.sound(player, "chime")
	Notify.player(
		player,
		"⬆️ "
			.. StormData.displayName(record)
			.. " reached Lv "
			.. level
			.. "! It now earns +"
			.. math.floor((StormData.levelMultiplier(record) - 1) * 100 + 0.5)
			.. "% more.",
		"success"
	)
end

local function growStorms(player: Player, data: any, dt: number)
	for _, record in data.storms do
		if not PlotService.isSlotStolen(player, record.slot) then
			local before = StormData.levelOf(record)
			record.xp = (record.xp or 0) + dt
			if StormData.levelOf(record) > before then
				levelUp(player, record)
			end
		end
	end
end

local function tick(dt: number)
	for _, player in Players:GetPlayers() do
		local data = DataService.get(player)
		if data and PlotService.getPlot(player) then
			data.lastSeen = os.time()
			local wasBoosted = (data.playSeconds or 0) < Config.Beginner.BoostSeconds
			data.playSeconds = (data.playSeconds or 0) + dt
			local boostLeft = Config.Beginner.BoostSeconds - data.playSeconds
			if boostLeft > 0 and not player:GetAttribute("BoostEndsAt") then
				-- For the HUD timer. Set once per visit so it doesn't change every second.
				player:SetAttribute("BoostEndsAt", workspace:GetServerTimeNow() + boostLeft)
			elseif boostLeft <= 0 and player:GetAttribute("BoostEndsAt") then
				player:SetAttribute("BoostEndsAt", nil)
			end
			if wasBoosted and boostLeft <= 0 then
				Notify.player(player, "🚀 Your Beginner Boost is over. You're a real storm catcher now!", "info")
			end
			growStorms(player, data, dt)
			local earned = IncomeService.rateOf(player) * dt
			if earned > 0 then
				data.stats.sparksEarned += earned
				if hasPass(player, "AutoCollect") then
					data.sparks += earned
					IncomeService.Collected:Fire(player, earned)
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
	PlotService.PlotAssigned:Connect(function(player)
		IncomeService.sync(player)
		payOffline(player)
	end)
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
