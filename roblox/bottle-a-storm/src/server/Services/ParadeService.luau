-- Storm Parade (like Steal a Brainrot's conveyor): storms float along a sky
-- river across the Wild Skies, each with a price. Walk up and press E to buy
-- one before it drifts away. First come, first served.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local StormData = require(Shared.StormData)

local Modules = script.Parent.Parent.Modules
local Notify = require(Modules.Notify)
local StormModel = require(Modules.StormModel)

local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local PlotService = require(script.Parent.PlotService)
local RewardService = require(script.Parent.RewardService)

local ParadeService = {}

type Entry = {
	def: StormData.StormDef,
	mutation: string?,
	price: number,
	model: Model,
	sold: boolean,
}

local folder: Folder
local entries: { Entry } = {}
local rng = Random.new()

local function raidGoing(): boolean
	local state = workspace:GetAttribute("RaidState")
	return state == "active" or state == "warning"
end

local function rollDef(): StormData.StormDef
	local weights = Config.Parade.RarityWeights
	local total = 0
	for _, weight in weights do
		total += weight
	end
	local pick = rng:NextNumber(0, total)
	local rarity = #weights
	for index, weight in weights do
		pick -= weight
		if pick <= 0 then
			rarity = index
			break
		end
	end
	local options = StormData.wildOfRarity(rarity)
	return options[rng:NextInteger(1, #options)]
end

local function remove(entry: Entry)
	local index = table.find(entries, entry)
	if index then
		table.remove(entries, index)
	end
	entry.model:Destroy()
end

local function buy(player: Player, entry: Entry)
	if entry.sold or not entry.model.Parent then
		return
	end
	local data = DataService.get(player)
	if not data then
		return
	end
	if not PlotService.firstFreeSlot(player) then
		Notify.player(player, "Your island is full! Buy a pedestal or sell a storm first.", "warn")
		return
	end
	if data.sparks < entry.price then
		Notify.player(player, "You need ⚡" .. Format.number(entry.price - data.sparks) .. " more Sparks.", "warn")
		return
	end
	entry.sold = true
	data.sparks -= entry.price
	local problem = RewardService.giveStorm(player, entry.def, entry.mutation, nil)
	if problem then
		data.sparks += entry.price -- couldn't place it: refund
		entry.sold = false
		Notify.player(player, problem, "warn")
		IncomeService.sync(player)
		return
	end
	IncomeService.sync(player)
	remove(entry)
	local name = StormData.displayName({ id = entry.def.id, mut = entry.mutation })
	if entry.def.rarity >= 4 or entry.mutation then
		Notify.allExcept(
			player,
			"🌊 " .. player.DisplayName .. " grabbed a " .. name .. " from the Storm Parade!",
			"rare"
		)
	end
end

local function spawnOne()
	local def = rollDef()
	local mutation: string? = nil
	if rng:NextNumber() < Config.Parade.MutationChance then
		mutation = RewardService.randomMutation()
	end
	local price = math.max(
		Config.Parade.MinPrice,
		math.floor(StormData.incomeOf({ id = def.id, mut = mutation }) * Config.Parade.PriceSeconds)
	)
	local model = StormModel.build(def, { mutation = mutation, scale = 0.8 })
	model.Name = "Parade_" .. def.id
	local root = model.PrimaryPart :: BasePart
	local z = Config.Parade.Z
	local startAt = CFrame.new(-Config.Parade.HalfLength, Config.Parade.Height, z) * CFrame.Angles(0, -math.pi / 2, 0)
	local endAt = CFrame.new(Config.Parade.HalfLength, Config.Parade.Height, z) * CFrame.Angles(0, -math.pi / 2, 0)
	model:PivotTo(startAt)
	StormModel.nameTag(def, mutation, "⚡ " .. Format.number(price) .. "  ·  press E to buy").Parent = root

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Buy for ⚡" .. Format.number(price)
	prompt.ObjectText = StormData.displayName({ id = def.id, mut = mutation })
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = root

	local entry: Entry = { def = def, mutation = mutation, price = price, model = model, sold = false }
	prompt.Triggered:Connect(function(player)
		buy(player, entry)
	end)
	table.insert(entries, entry)
	model.Parent = folder

	local distance = Config.Parade.HalfLength * 2
	local tween = TweenService:Create(
		root,
		TweenInfo.new(distance / Config.Parade.Speed, Enum.EasingStyle.Linear),
		{ CFrame = endAt }
	)
	tween.Completed:Connect(function()
		if model.Parent then
			remove(entry)
		end
	end)
	tween:Play()
	if def.rarity >= 4 then
		Notify.all(
			"🌊 A "
				.. StormData.rarityOf(def).name
				.. " "
				.. def.name
				.. " is floating down the Storm Parade! ⚡"
				.. Format.number(price),
			"rare"
		)
	end
end

function ParadeService.init()
	folder = Instance.new("Folder")
	folder.Name = "Parade"
	folder.Parent = workspace
end

function ParadeService.start()
	task.spawn(function()
		while true do
			task.wait(Config.Parade.SpawnEvery)
			if raidGoing() then
				for _, entry in table.clone(entries) do
					remove(entry)
				end
			elseif #entries < Config.Parade.MaxStorms and #Players:GetPlayers() > 0 then
				spawnOne()
			end
		end
	end)
end

return ParadeService
