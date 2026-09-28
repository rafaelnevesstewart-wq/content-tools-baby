-- 🗺️ The daily treasure hunt: every day 5 spots around the lobby islands get
-- a buried treasure (TreasureData). Your screen shows your next clue; find
-- the dirt mound with an ❌ and hold E to dig. Each treasure pays Sparks and
-- the last one gives a Rare kit too. Only your next clue's treasure counts
-- (they're in order). Progress is saved as data.treasure.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local RewardsData = require(Shared.RewardsData)
local TreasureData = require(Shared.TreasureData)

local Modules = script.Parent.Parent.Modules
local Effects = require(Modules.Effects)
local Juice = require(Modules.Juice)
local Notify = require(Modules.Notify)

local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local RewardService = require(script.Parent.RewardService)

local TreasureService = {}

local day = -1
local spots: { TreasureData.Spot } = {}
local folder: Folder? = nil

local function treasureOf(data: any): any
	data.treasure = data.treasure or { day = -1, found = 0 }
	if data.treasure.day ~= day then
		data.treasure.day = day
		data.treasure.found = 0
	end
	return data.treasure
end

local function publish(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local found = treasureOf(data).found
	local spot = spots[found + 1]
	player:SetAttribute("TreasureStep", if spot then found + 1 else nil)
	player:SetAttribute("TreasureClue", if spot then spot.clue else nil)
end

local function dig(player: Player, index: number)
	local data = DataService.get(player)
	if not data then
		return
	end
	local treasure = treasureOf(data)
	if index <= treasure.found then
		Notify.player(player, "🗺️ You already dug this one up today!", "info")
		return
	end
	if index > treasure.found + 1 then
		Notify.player(player, "🗺️ Nothing here... yet. Follow your clues in order!", "info")
		return
	end
	treasure.found = index
	local spot = spots[index]
	Effects.confetti(spot.position + Vector3.new(0, 2, 0), 30)
	Juice.sound(player, "coins")
	local sparks = TreasureData.StepSparks[index] or 200
	data.sparks += sparks
	IncomeService.sync(player)
	if index >= #spots then
		data.sparks += TreasureData.FinalSparks
		IncomeService.sync(player)
		data.stats.treasureHunts = (data.stats.treasureHunts or 0) + 1
		RewardService.grant(player, { kind = "kit", rarity = TreasureData.FinalKitRarity })
		Juice.sound(player, "win")
		Notify.player(
			player,
			"🏴‍☠️ You found ALL of today's treasure! +⚡"
				.. sparks + TreasureData.FinalSparks
				.. " and a Rare kit! New clues tomorrow.",
			"rare"
		)
	else
		Notify.player(
			player,
			"💰 Treasure! +⚡"
				.. sparks
				.. ". Next clue ("
				.. index + 1
				.. "/"
				.. #spots
				.. "): "
				.. spots[index + 1].clue,
			"success"
		)
	end
	publish(player)
end

-- A dirt mound with an ❌ on it for each of today's spots.
local function build()
	if folder then
		folder:Destroy()
	end
	local newFolder = Instance.new("Folder")
	newFolder.Name = "Treasure"
	for index, spot in spots do
		-- Find the ground (or the courtyard floor) right under the spot.
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local characters = {}
		for _, player in Players:GetPlayers() do
			if player.Character then
				table.insert(characters, player.Character)
			end
		end
		params.FilterDescendantsInstances = characters
		local hit = workspace:Raycast(spot.position + Vector3.new(0, 4, 0), Vector3.new(0, -12, 0), params)
		local ground = if hit then hit.Position else spot.position
		local mound = Instance.new("Part")
		mound.Name = "TreasureMound"
		mound.Anchored = true
		mound.CanCollide = false
		mound.Size = Vector3.new(4, 1, 4)
		mound.CFrame = CFrame.new(ground + Vector3.new(0, 0.2, 0))
		mound.Color = Color3.fromRGB(110, 80, 52)
		mound.Material = Enum.Material.Ground
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = mound
		for _, angle in { 45, -45 } do
			local stroke = Instance.new("Part")
			stroke.Anchored = true
			stroke.CanCollide = false
			stroke.CanQuery = false
			stroke.Size = Vector3.new(2.6, 0.1, 0.4)
			stroke.CFrame = CFrame.new(ground + Vector3.new(0, 0.72, 0)) * CFrame.Angles(0, math.rad(angle), 0)
			stroke.Color = Color3.fromRGB(200, 40, 40)
			stroke.Material = Enum.Material.SmoothPlastic
			stroke.Parent = mound
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Dig"
		prompt.ObjectText = "🗺️ Something is buried here"
		prompt.HoldDuration = 1.2
		prompt.MaxActivationDistance = 9
		prompt.RequiresLineOfSight = false
		prompt.Parent = mound
		prompt.Triggered:Connect(function(player)
			dig(player, index)
		end)
		mound.Parent = newFolder
	end
	newFolder.Parent = workspace
	folder = newFolder
end

local function refreshDay()
	local today = RewardsData.today(os.time())
	if today == day then
		return
	end
	day = today
	spots = TreasureData.forDay(today)
	build()
	for _, player in Players:GetPlayers() do
		publish(player)
	end
end

function TreasureService.start()
	task.defer(refreshDay) -- after the islands are built
	DataService.ProfileLoaded:Connect(function(player)
		publish(player)
	end)
	task.spawn(function()
		while true do
			task.wait(60)
			refreshDay()
		end
	end)
end

return TreasureService
