-- Quests from the board in town and treasure chests out in the wild.
-- Quests: three at a time, tracked on screen, claimed for coins and XP. A new
-- set is posted every few minutes. Chests: scattered ahead of the herd; hold
-- to open, the lid swings up and coins spill out.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local QuestService = {}
local S

local rng = Random.new()
local chests = {} -- list of chest models
local chestFolder

-- Quests -------------------------------------------------------------------------

local function newQuests(profile)
	local templates = table.clone(Config.Quests.Templates)
	local list = {}
	for _ = 1, 3 do
		local template = table.remove(templates, rng:NextInteger(1, #templates))
		local goal = template.Goals[rng:NextInteger(1, #template.Goals)]
		local bonus = 1 + (profile.Level - 1) * Config.Quests.LevelBonus
		table.insert(list, {
			Stat = template.Stat,
			Text = string.format(template.Text, goal),
			Goal = goal,
			Progress = 0,
			Coins = math.floor(goal * template.CoinsEach * bonus),
			XP = math.floor(goal * template.XPEach * bonus),
			Claimed = false,
		})
	end
	profile.Quests = { List = list, RefreshAt = os.time() + Config.Quests.RefreshMinutes * 60 }
end

local function ensureQuests(player: Player)
	local profile = S.PlayerService:GetProfile(player)
	if not profile then
		return nil
	end
	if type(profile.Quests) ~= "table" or type(profile.Quests.List) ~= "table" or os.time() >= (profile.Quests.RefreshAt or 0) then
		newQuests(profile)
		S.PlayerService:Notify(player, "📜 New quests are up! Check the quest list on the right.")
		S.PlayerService:MarkDirty(player)
	end
	return profile.Quests
end

-- Counts progress towards any quest that tracks this stat.
function QuestService:Progress(player: Player, stat: string, amount: number)
	local quests = ensureQuests(player)
	if not quests or amount <= 0 then
		return
	end
	for _, quest in quests.List do
		if quest.Stat == stat and not quest.Claimed and quest.Progress < quest.Goal then
			quest.Progress = math.min(quest.Goal, quest.Progress + amount)
			if quest.Progress >= quest.Goal then
				S.PlayerService:Notify(player, "✅ Quest complete: " .. quest.Text .. ". Claim your reward!")
			end
			S.PlayerService:MarkDirty(player)
		end
	end
end

function QuestService:Claim(player: Player, index)
	local quests = ensureQuests(player)
	local quest = quests and type(index) == "number" and quests.List[index]
	if not quest or quest.Claimed or quest.Progress < quest.Goal then
		return
	end
	quest.Claimed = true
	S.PlayerService:AddCoins(player, quest.Coins)
	S.PlayerService:Notify(player, string.format("📜 Quest reward: +%d coins, +%d XP", quest.Coins, quest.XP))
	S.PlayerService:AddXP(player, quest.XP)
end

-- The snapshot the HUD shows.
function QuestService:Snapshot(player: Player)
	local quests = ensureQuests(player)
	if not quests then
		return nil
	end
	return { List = quests.List, RefreshIn = math.max(0, quests.RefreshAt - os.time()) }
end

-- Treasure chests ------------------------------------------------------------------

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.FilterDescendantsInstances = { workspace.Terrain }

local function groundAt(x: number, z: number): number
	local hit = workspace:Raycast(Vector3.new(x, 600, z), Vector3.new(0, -1200, 0), groundParams)
	return hit and hit.Position.Y or 0
end

local function spotAhead(): CFrame
	local a = S.TitanService:GetAngle() + rng:NextNumber(0.05, 0.5)
	local r = Config.Herd.PathRadius + rng:NextNumber(-260, 260)
	local x, z = math.cos(a) * r, math.sin(a) * r
	return CFrame.new(x, groundAt(x, z), z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
end

local function chestPart(props, model: Model)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		p[key] = value
	end
	p.Parent = model
	return p
end

local spawnChest

local function openChest(model: Model, player: Player)
	if model:GetAttribute("Opened") then
		return
	end
	model:SetAttribute("Opened", true)
	local prompt = model:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then
		prompt.Enabled = false
	end

	-- Lid swings open on its back hinge.
	local lid = model:FindFirstChild("Lid")
	local base = model:FindFirstChild("Base")
	if lid and base then
		local hinge = base.CFrame * CFrame.new(0, 1.1, 1.35)
		local value = Instance.new("CFrameValue")
		value.Value = CFrame.new()
		local closed = hinge:ToObjectSpace(lid.CFrame)
		value.Changed:Connect(function(rotation)
			lid.CFrame = hinge * rotation * closed
		end)
		TweenService:Create(value, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Value = CFrame.Angles(math.rad(-100), 0, 0) }):Play()
		Debris:AddItem(value, 1)
	end

	if base then
		local glint = Instance.new("ParticleEmitter")
		glint.Color = ColorSequence.new(Color3.fromRGB(255, 215, 80))
		glint.LightEmission = 1
		glint.Size = NumberSequence.new(0.5, 0)
		glint.Speed = NumberRange.new(10, 18)
		glint.Lifetime = NumberRange.new(0.7, 1.2)
		glint.SpreadAngle = Vector2.new(35, 35)
		glint.EmissionDirection = Enum.NormalId.Top
		glint.Acceleration = Vector3.new(0, -35, 0)
		glint.Rate = 0
		glint.Parent = base
		glint:Emit(40)
		local sound = Instance.new("Sound")
		sound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
		sound.Volume = 0.8
		sound.PlaybackSpeed = 0.8
		sound.Parent = base
		sound:Play()
	end

	local profile = S.PlayerService:GetProfile(player)
	local stage = profile and profile.Stage or 1
	local coins = math.max(Config.Chests.CoinsBase + stage * Config.Chests.CoinsPerStage, S.PlayerService:Income(player) * Config.Chests.IncomeSeconds)
	coins = math.floor(coins * rng:NextNumber(0.85, 1.25))
	S.PlayerService:AddCoins(player, coins)
	local food = S.PlayerService:AddFood(player, rng:NextInteger(2, 5))
	S.PlayerService:Notify(player, string.format("💰 Treasure! +%d coins, +%d XP%s", coins, Config.Chests.XP, food > 0 and (", +" .. food .. " food") or ""))
	S.PlayerService:AddXP(player, Config.Chests.XP)
	QuestService:Progress(player, "Chest", 1)

	task.delay(3, function()
		local index = table.find(chests, model)
		if index then
			table.remove(chests, index)
		end
		model:Destroy()
		spawnChest()
	end)
end

spawnChest = function()
	local cf = spotAhead()
	local model = Instance.new("Model")
	model.Name = "TreasureChest"
	local wood = Color3.fromRGB(105, 65, 35)
	local gold = Color3.fromRGB(220, 175, 60)
	local base = chestPart(
		{ Name = "Base", Size = Vector3.new(4, 2.2, 2.6), CFrame = cf * CFrame.new(0, 1.1, 0), Color = wood, Material = Enum.Material.WoodPlanks },
		model
	)
	chestPart({ Name = "Band", Size = Vector3.new(4.1, 0.3, 2.7), CFrame = cf * CFrame.new(0, 1.6, 0), Color = gold, Material = Enum.Material.Metal }, model)
	local lid = chestPart(
		{ Name = "Lid", Size = Vector3.new(4.1, 0.9, 2.7), CFrame = cf * CFrame.new(0, 2.65, 0), Color = wood, Material = Enum.Material.WoodPlanks },
		model
	)
	local trim = chestPart(
		{ Name = "LidTrim", Size = Vector3.new(0.4, 0.95, 2.75), CFrame = cf * CFrame.new(0, 2.65, 0), Color = gold, Material = Enum.Material.Metal },
		model
	)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = lid
	weld.Part1 = trim
	weld.Parent = trim
	trim.Anchored = false
	chestPart({ Name = "Lock", Size = Vector3.new(0.6, 0.7, 0.2), CFrame = cf * CFrame.new(0, 2.1, -1.4), Color = gold, Material = Enum.Material.Metal }, model)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 200, 90)
	light.Range = 10
	light.Brightness = 0.8
	light.Parent = base

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open"
	prompt.ObjectText = "Treasure Chest"
	prompt.HoldDuration = Config.Chests.HoldTime
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(player)
		openChest(model, player)
	end)
	prompt.Parent = base
	model.PrimaryPart = base
	model.Parent = chestFolder
	table.insert(chests, model)
end

-- Chests the herd has walked past move up ahead again.
local function recycleChests()
	local herdAngle = S.TitanService:GetAngle()
	for _, model in chests do
		if not model:GetAttribute("Opened") and model.PrimaryPart then
			local p = model.PrimaryPart.Position
			local behind = (math.atan2(p.Z, p.X) - herdAngle + math.pi) % (math.pi * 2) - math.pi
			if behind < -0.4 then
				model:PivotTo(spotAhead() * CFrame.new(0, 1.1, 0))
			end
		end
	end
end

function QuestService:Init(services)
	S = services
	chestFolder = Instance.new("Folder")
	chestFolder.Name = "Chests"
	chestFolder.Parent = workspace
end

function QuestService:Start()
	task.wait(2) -- let the map finish building
	for _ = 1, Config.Chests.Count do
		spawnChest()
	end
	while true do
		task.wait(5)
		recycleChests()
		for _, player in Players:GetPlayers() do
			ensureQuests(player)
		end
	end
end

return QuestService
