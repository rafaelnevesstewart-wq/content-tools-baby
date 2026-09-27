-- Grumpy clouds: little angry clouds that float around the Wild Skies, follow
-- players and drop raindrops on them (a splash pushes you and slows you for
-- a moment). Everyone gets a Cloud Blaster to pop them. Everyone who hit a
-- cloud gets Sparks when it pops; big Storm Grumps can also drop Storm Snacks
-- or a Rare storm for the player who popped it.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Signal)
local SkinData = require(Shared.SkinData)
local StormData = require(Shared.StormData)

local Modules = script.Parent.Parent.Modules
local Effects = require(Modules.Effects)
local Juice = require(Modules.Juice)
local Notify = require(Modules.Notify)
local StormModel = require(Modules.StormModel)

local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local MovementService = require(script.Parent.MovementService)
local RewardService = require(script.Parent.RewardService)

local GrumpService = {}

-- (player) for everyone who helped pop a grumpy cloud.
GrumpService.Popped = Signal.new()

local BLASTER_NAME = "Cloud Blaster"
local CENTER = Vector3.zero -- the Wild Skies island top

type Grump = {
	model: Model,
	root: BasePart,
	big: boolean,
	hp: number,
	maxHp: number,
	fill: Frame,
	damagers: { [Player]: boolean },
	expiresAt: number,
	nextShot: number,
	alive: boolean,
}

-- Grumpy clouds are built like storms, with a frown.
local SMALL: StormData.StormDef = {
	id = "GrumpyCloud",
	name = "Grumpy Cloud",
	rarity = 1,
	income = 0,
	colors = { Color3.fromRGB(150, 150, 185) },
	fx = "rain",
}
local BIG: StormData.StormDef = {
	id = "StormGrump",
	name = "Storm Grump",
	rarity = 3,
	income = 0,
	colors = { Color3.fromRGB(100, 100, 150) },
	fx = "rain",
}

local grumps: { Grump } = {}
local folder: Folder
local blasterTemplate: Tool
local lastBlast: { [Player]: number } = {}
local rng = Random.new()

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

local function onWildSkies(position: Vector3): boolean
	local flat = Vector3.new(position.X - CENTER.X, 0, position.Z - CENTER.Z)
	return flat.Magnitude <= Config.World.CenterRadius + 10 and position.Y > CENTER.Y - 20
end

local function raidGoing(): boolean
	local state = workspace:GetAttribute("RaidState")
	return state == "active" or state == "warning"
end

-- Living players on the Wild Skies, nearest first within `radius` of `from`.
local function nearestPlayer(from: Vector3, radius: number): (Player?, BasePart?)
	local best, bestRoot, bestDistance = nil, nil, radius
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 and onWildSkies(root.Position) then
			local distance = (root.Position - from).Magnitude
			if distance < bestDistance then
				best, bestRoot, bestDistance = player, root, distance
			end
		end
	end
	return best, bestRoot
end

local function randomSpot(): Vector3
	local radius = Config.World.WildRoamRadius * math.sqrt(rng:NextNumber())
	local angle = rng:NextNumber(0, math.pi * 2)
	return CENTER + Vector3.new(math.cos(angle) * radius, Config.Grumps.Height, math.sin(angle) * radius)
end

local function healthBar(root: BasePart, big: boolean): Frame
	local gui = Instance.new("BillboardGui")
	gui.Name = "GrumpTag"
	gui.Size = UDim2.fromOffset(150, 40)
	gui.StudsOffsetWorldSpace = Vector3.new(0, if big then 6 else 4.5, 0)
	gui.MaxDistance = 110
	gui.LightInfluence = 0
	gui.Parent = root
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0, 20)
	name.Font = Enum.Font.GothamBold
	name.TextSize = 17
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0.3
	name.Text = if big then "😠 Storm Grump" else "😠 Grumpy Cloud"
	name.Parent = gui
	local bar = Instance.new("Frame")
	bar.Position = UDim2.new(0.1, 0, 0, 24)
	bar.Size = UDim2.new(0.8, 0, 0, 10)
	bar.BackgroundColor3 = Color3.fromRGB(60, 50, 90)
	bar.BorderSizePixel = 0
	bar.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 5)
	corner.Parent = bar
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(255, 120, 150)
	fill.BorderSizePixel = 0
	fill.Parent = bar
	corner:Clone().Parent = fill
	return fill
end

local function remove(grump: Grump)
	if not grump.alive then
		return
	end
	grump.alive = false
	local index = table.find(grumps, grump)
	if index then
		table.remove(grumps, index)
	end
	grump.model:Destroy()
end

local function spawnGrump()
	local big = rng:NextNumber() < Config.Grumps.BigChance
	local model = StormModel.build(if big then BIG else SMALL, { angry = true, scale = if big then 1.3 else 1 })
	model.Name = if big then "StormGrump" else "GrumpyCloud"
	local root = model.PrimaryPart :: BasePart
	model:PivotTo(CFrame.new(randomSpot()))
	local hp = if big then Config.Grumps.BigHp else Config.Grumps.SmallHp
	local grump: Grump = {
		model = model,
		root = root,
		big = big,
		hp = hp,
		maxHp = hp,
		fill = healthBar(root, big),
		damagers = {},
		expiresAt = os.clock() + Config.Grumps.Lifetime,
		nextShot = os.clock() + rng:NextNumber(2, 4),
		alive = true,
	}
	model.Parent = folder
	table.insert(grumps, grump)
end

-- Floats toward the nearest player (or wanders), one short glide per second.
local function move(grump: Grump)
	local from = grump.root.Position
	local _, targetRoot = nearestPlayer(from, Config.Grumps.ChaseRadius)
	local goal
	if targetRoot then
		local offset = Vector3.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6))
		goal = Vector3.new(targetRoot.Position.X, CENTER.Y + Config.Grumps.Height, targetRoot.Position.Z) + offset
	else
		goal = randomSpot()
	end
	local step = goal - from
	local distance = math.min(step.Magnitude, Config.Grumps.Speed)
	if distance < 0.5 then
		return
	end
	local target = from + step.Unit * distance
	if not onWildSkies(target) then
		target = from:Lerp(CENTER + Vector3.new(0, Config.Grumps.Height, 0), 0.1)
	end
	local flat = Vector3.new(step.X, 0, step.Z)
	local facing = if flat.Magnitude > 0.1 then CFrame.lookAt(target, target + flat) else CFrame.new(target)
	TweenService:Create(grump.root, TweenInfo.new(1, Enum.EasingStyle.Linear), { CFrame = facing }):Play()
end

-- Drops a raindrop where the player is standing. Move and it misses!
local function shoot(grump: Grump)
	local target, targetRoot = nearestPlayer(grump.root.Position, Config.Grumps.ShootRange)
	if not target or not targetRoot then
		return
	end
	local landing = targetRoot.Position - Vector3.new(0, 2, 0)
	local drop = Instance.new("Part")
	drop.Name = "Raindrop"
	drop.Shape = Enum.PartType.Ball
	drop.Size = Vector3.one * (if grump.big then 2 else 1.3)
	drop.Color = Color3.fromRGB(110, 180, 255)
	drop.Material = Enum.Material.Neon
	drop.Transparency = 0.2
	drop.Anchored = true
	drop.CanCollide = false
	drop.CanTouch = false
	drop.CanQuery = false
	drop.CFrame = CFrame.new(grump.root.Position - Vector3.new(0, 1.5, 0))
	drop.Parent = workspace
	local tween = TweenService:Create(
		drop,
		TweenInfo.new(Config.Grumps.DropSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ CFrame = CFrame.new(landing) }
	)
	tween.Completed:Connect(function()
		drop:Destroy()
		Effects.splash(landing, nil)
		for _, player in Players:GetPlayers() do
			local root = rootOf(player)
			if root and (root.Position - landing).Magnitude <= Config.Grumps.SplashRadius + 2 then
				local away = root.Position - landing
				local flat = Vector3.new(away.X, 0, away.Z)
				local push = (if flat.Magnitude > 0.1 then flat.Unit else Vector3.new(1, 0, 0))
					* Config.Grumps.Knockback
				Juice.knock(player, push + Vector3.new(0, 22, 0))
				MovementService.soak(player, 1.5)
				Juice.float(player, "💧 Splash!", root.Position + Vector3.new(0, 3, 0), Color3.fromRGB(110, 180, 255))
			end
		end
	end)
	tween:Play()
end

local function pop(grump: Grump, popper: Player)
	local position = grump.root.Position
	remove(grump)
	Effects.confetti(position, 45)
	Effects.splash(position, nil)
	for player in grump.damagers do
		local data = DataService.get(player)
		if player.Parent and data then
			local amount = math.floor(
				if grump.big
					then math.max(
						Config.Grumps.BigRewardMin,
						IncomeService.rateOf(player) * Config.Grumps.BigRewardSeconds
					)
					else math.max(
						Config.Grumps.SmallRewardMin,
						IncomeService.rateOf(player) * Config.Grumps.SmallRewardSeconds
					)
			)
			IncomeService.addSparks(player, amount)
			data.stats.grumpsPopped += 1
			Juice.float(player, "POP! +⚡" .. Format.number(amount), position, Color3.fromRGB(255, 150, 200))
			Juice.sound(player, "coins")
			GrumpService.Popped:Fire(player)
		end
	end
	if grump.big and popper.Parent then
		local roll = rng:NextNumber()
		if roll < Config.Grumps.BigStormChance then
			local problem = RewardService.grant(popper, { kind = "storm", rarity = 3 }, nil)
			if not problem then
				Notify.all(
					"🌩️ " .. popper.DisplayName .. " popped a Storm Grump and found a storm inside!",
					"rare"
				)
			end
		elseif roll < Config.Grumps.BigStormChance + Config.Grumps.BigSnackChance then
			RewardService.grant(popper, { kind = "snacks" }, nil)
		end
	end
end

local function onBlast(player: Player, target: any)
	if typeof(target) ~= "Vector3" then
		return
	end
	local root = rootOf(player)
	local character = player.Character
	if not root or not character or not character:FindFirstChild(BLASTER_NAME) then
		return
	end
	if os.clock() - (lastBlast[player] or 0) < Config.Blaster.Cooldown or MovementService.isStunned(player) then
		return
	end
	lastBlast[player] = os.clock()

	local origin = root.Position + Vector3.new(0, 1.5, 0)
	local aim = target - origin
	if aim.Magnitude > Config.Blaster.Range then
		target = origin + aim.Unit * Config.Blaster.Range
	end
	local best: Grump? = nil
	local bestDistance = math.huge
	for _, grump in grumps do
		local reach = Config.Blaster.AimRadius + (if grump.big then 3 else 1.5)
		local distance = (grump.root.Position - target).Magnitude
		if distance <= reach and distance < bestDistance then
			best, bestDistance = grump, distance
		end
	end

	-- A sparkly pink beam.
	local endPoint = if best then best.root.Position else target
	local length = (endPoint - origin).Magnitude
	local beam = Instance.new("Part")
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanTouch = false
	beam.CanQuery = false
	beam.Material = Enum.Material.Neon
	local shooterData = DataService.get(player)
	local skin = SkinData.beam(shooterData and shooterData.cosmetics.fx)
	beam.Color = if shooterData and shooterData.cosmetics.fx then skin.color else Color3.fromRGB(255, 150, 210)
	beam.Size = Vector3.new(0.35, 0.35, length)
	beam.CFrame = CFrame.lookAt((origin + endPoint) / 2, endPoint)
	beam.Parent = workspace
	game:GetService("Debris"):AddItem(beam, 0.12)

	if not best then
		return
	end
	local grump = best :: Grump
	grump.hp -= 1
	grump.damagers[player] = true
	grump.fill.Size = UDim2.fromScale(math.max(0, grump.hp / grump.maxHp), 1)
	Juice.sound(player, "pop")
	if grump.hp <= 0 then
		pop(grump, player)
	end
end

local function makeBlaster(): Tool
	local tool = Instance.new("Tool")
	tool.Name = BLASTER_NAME
	tool.RequiresHandle = false
	tool.CanBeDropped = false
	tool.ToolTip = "Click a grumpy cloud to pop it"
	return tool
end

local function giveBlaster(player: Player)
	local backpack = player:WaitForChild("Backpack", 10)
	local character = player.Character
	if
		not backpack
		or backpack:FindFirstChild(BLASTER_NAME)
		or (character and character:FindFirstChild(BLASTER_NAME))
	then
		return
	end
	blasterTemplate:Clone().Parent = backpack
end

function GrumpService.init()
	folder = Instance.new("Folder")
	folder.Name = "Grumps"
	folder.Parent = workspace
	blasterTemplate = makeBlaster()
end

function GrumpService.start()
	Remotes.event("BlastCloud").OnServerEvent:Connect(onBlast)

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			task.wait(0.2) -- after the Jar and Zapper, so it's tool 3
			giveBlaster(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastBlast[player] = nil
		for _, grump in grumps do
			grump.damagers[player] = nil
		end
	end)

	-- Spawning, and hiding during a Mega-Storm.
	task.spawn(function()
		while true do
			task.wait(Config.Grumps.SpawnInterval)
			if raidGoing() then
				for _, grump in table.clone(grumps) do
					remove(grump)
				end
			elseif #grumps < Config.Grumps.MaxCount and #Players:GetPlayers() > 0 then
				spawnGrump()
			end
		end
	end)

	-- Moving (once a second) and dropping raindrops.
	task.spawn(function()
		local tick = 0
		while true do
			task.wait(0.2)
			tick += 1
			local t = os.clock()
			for _, grump in table.clone(grumps) do
				if t >= grump.expiresAt then
					remove(grump)
				else
					if tick % 5 == 0 then
						move(grump)
					end
					if t >= grump.nextShot then
						grump.nextShot = t + Config.Grumps.ShootEvery + rng:NextNumber(0, 1.5)
						shoot(grump)
					end
				end
			end
		end
	end)
end

return GrumpService
