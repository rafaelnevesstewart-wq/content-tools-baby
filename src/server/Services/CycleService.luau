-- Day (the Migration) and night (Nightfall). During Nightfall the herd stops,
-- beasts attack every titan, stealing is off, and at dawn the whole herd
-- shares loot based on how many titans survived.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)

local CycleService = {}
local S

local phase = "Day"
local nightNumber = 0
local stormUntil = 0
local beasts = {} -- list of beast records
local beastFolder
local slingCooldowns = {} -- [Player] = os.clock()

local function now(): number
	return workspace:GetServerTimeNow()
end

local DAY_LENGTH = RunService:IsStudio() and Config.Cycle.StudioDayLength or Config.Cycle.DayLength
local NIGHT_LENGTH = RunService:IsStudio() and Config.Cycle.StudioNightLength or Config.Cycle.NightLength

function CycleService:IsDay(): boolean
	return phase == "Day"
end

function CycleService:NightNumber(): number
	return nightNumber
end

function CycleService:IsStorm(): boolean
	return now() < stormUntil
end

function CycleService:IsBossNight(): boolean
	return phase == "Night" and nightNumber % Config.Cycle.BossEvery == 0
end

-- Lighting -------------------------------------------------------------------

local function tweenLighting(props)
	TweenService:Create(Lighting, TweenInfo.new(4), props):Play()
end

local function applyLighting()
	if phase == "Night" then
		tweenLighting({ ClockTime = 0, Brightness = 0.8, FogEnd = 500, FogColor = Color3.fromRGB(20, 25, 50), OutdoorAmbient = Color3.fromRGB(60, 60, 100) })
	elseif CycleService:IsStorm() then
		tweenLighting({
			ClockTime = 15,
			Brightness = 1.2,
			FogEnd = 700,
			FogColor = Color3.fromRGB(120, 110, 150),
			OutdoorAmbient = Color3.fromRGB(150, 130, 190),
		})
	else
		tweenLighting({
			ClockTime = 14,
			Brightness = 2,
			FogEnd = 2500,
			FogColor = Color3.fromRGB(190, 210, 230),
			OutdoorAmbient = Color3.fromRGB(128, 128, 128),
		})
	end
end

function CycleService:StartStorm(seconds: number, byPlayer: Player?)
	stormUntil = math.max(stormUntil, now()) + seconds
	ReplicatedStorage:SetAttribute("StormUntil", stormUntil)
	if byPlayer then
		S.PlayerService:NotifyAll(string.format("⚡ %s started a Storm! Rare mutations are more likely for everyone.", byPlayer.DisplayName))
	else
		S.PlayerService:NotifyAll("⚡ A storm rolls in! Rare mutations are more likely.")
	end
	applyLighting()
	task.delay(seconds + 0.5, function()
		if not self:IsStorm() then
			applyLighting()
		end
	end)
end

-- Beasts ---------------------------------------------------------------------

local function spawnBeast(isBoss: boolean)
	local def = isBoss and Config.Nightfall.Boss or Config.Nightfall.Beast
	local center = S.TitanService:HerdCenter()
	local a = math.random() * math.pi * 2
	local radius = Config.Nightfall.SpawnRadius * (isBoss and 1.3 or 1)
	local position = center + Vector3.new(math.cos(a) * radius, def.Size.Y / 2, math.sin(a) * radius)

	local body = Instance.new("Part")
	body.Name = isBoss and "StormKing" or "Gloomhound"
	body.Anchored = true
	body.CanCollide = false
	body.Size = def.Size
	body.Color = isBoss and Color3.fromRGB(60, 30, 90) or Color3.fromRGB(35, 35, 55)
	body.Material = Enum.Material.SmoothPlastic
	body.CFrame = CFrame.new(position)
	for _, side in { -1, 1 } do
		local eye = Instance.new("Part")
		eye.Anchored = false
		eye.CanCollide = false
		eye.Massless = true
		eye.Size = Vector3.one * def.Size.X * 0.18
		eye.Shape = Enum.PartType.Ball
		eye.Material = Enum.Material.Neon
		eye.Color = Color3.fromRGB(255, 50, 50)
		eye.CFrame = body.CFrame * CFrame.new(side * def.Size.X * 0.25, def.Size.Y * 0.25, -def.Size.Z / 2)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = eye
		weld.Parent = eye
		eye.Parent = body
	end

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(isBoss and 220 or 80, isBoss and 40 or 10)
	gui.StudsOffset = Vector3.new(0, def.Size.Y / 2 + 2, 0)
	gui.MaxDistance = isBoss and 600 or 150
	gui.Parent = body
	if isBoss then
		local title = Instance.new("TextLabel")
		title.BackgroundTransparency = 1
		title.Size = UDim2.fromScale(1, 0.6)
		title.Font = Enum.Font.FredokaOne
		title.TextScaled = true
		title.TextColor3 = Color3.fromRGB(255, 200, 255)
		title.TextStrokeTransparency = 0.3
		title.Text = "Storm King"
		title.Parent = gui
	end
	local back = Instance.new("Frame")
	back.BackgroundColor3 = Color3.fromRGB(30, 0, 0)
	back.BorderSizePixel = 0
	back.Size = UDim2.fromScale(1, isBoss and 0.35 or 1)
	back.Position = UDim2.fromScale(0, isBoss and 0.65 or 0)
	back.Parent = gui
	local bar = Instance.new("Frame")
	bar.BackgroundColor3 = Color3.fromRGB(230, 60, 60)
	bar.BorderSizePixel = 0
	bar.Size = UDim2.fromScale(1, 1)
	bar.Parent = back

	body.Parent = beastFolder
	local health = def.Health * (1 + nightNumber * 0.08) * (isBoss and math.max(1, #Players:GetPlayers() / 2) or 1)
	table.insert(beasts, {
		Part = body,
		Def = def,
		Health = health,
		MaxHealth = health,
		Bar = bar,
		IsBoss = isBoss,
		StunnedUntil = 0,
		NextAttack = 0,
	})
end

local function clearBeasts()
	for _, beast in beasts do
		beast.Part:Destroy()
	end
	table.clear(beasts)
end

local function damageBeast(beast, amount: number, attacker: Player?)
	beast.Health -= amount
	beast.Bar.Size = UDim2.fromScale(math.clamp(beast.Health / beast.MaxHealth, 0, 1), 1)
	if attacker then
		local session = S.PlayerService:GetSession(attacker)
		if session then
			session.NightDamage += amount
			if beast.IsBoss then
				session.BossDamage += amount
			end
		end
	end
	if beast.Health <= 0 then
		local index = table.find(beasts, beast)
		if index then
			table.remove(beasts, index)
		end
		beast.Part:Destroy()
		if attacker then
			local reward = beast.IsBoss and 500 or 10
			S.PlayerService:AddCoins(attacker, reward * (1 + nightNumber * 0.1))
		end
		if beast.IsBoss then
			S.PlayerService:NotifyAll("The Storm King has fallen!")
		end
	end
end

local function nearestLivingTitan(position: Vector3)
	local best, bestRecord, bestDistance = nil, nil, math.huge
	for player, record in S.TitanService:AllTitans() do
		if not record.Exhausted and record.Root and record.Root.Parent then
			local d = (record.Root.Position - position) * Vector3.new(1, 0, 1)
			if d.Magnitude < bestDistance then
				best, bestRecord, bestDistance = player, record, d.Magnitude
			end
		end
	end
	return best, bestRecord, bestDistance
end

local function stepBeasts(dt: number)
	local t = os.clock()
	for _, beast in table.clone(beasts) do
		if t >= beast.StunnedUntil then
			local part = beast.Part
			local owner, record, distance = nearestLivingTitan(part.Position)
			if owner and record then
				local reach = 11 * record.Scale + beast.Def.Size.Z / 2 + 1
				local target = Vector3.new(record.Root.Position.X, part.Position.Y, record.Root.Position.Z)
				if distance > reach then
					local direction = (target - part.Position).Unit
					local nextPosition = part.Position + direction * math.min(beast.Def.Speed * dt, distance - reach)
					part.CFrame = CFrame.lookAt(nextPosition, target)
				elseif t >= beast.NextAttack then
					beast.NextAttack = t + beast.Def.AttackEvery
					S.TitanService:Damage(owner, beast.Def.Damage)
				end
			end
		end
	end
end

-- Player tools and abilities -----------------------------------------------

function CycleService:GiveSling(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack or backpack:FindFirstChild("Pebble Sling") then
		return
	end
	local tool = Instance.new("Tool")
	tool.Name = "Pebble Sling"
	tool.CanBeDropped = false
	tool.ToolTip = "Click to fling pebbles at Nightfall beasts"
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.6, 1.6, 0.6)
	handle.Color = Color3.fromRGB(120, 80, 50)
	handle.Material = Enum.Material.Wood
	handle.CanCollide = false
	handle.Parent = tool
	tool.Activated:Connect(function()
		self:_sling(player, handle)
	end)
	tool.Parent = backpack
end

function CycleService:_sling(player: Player, handle: BasePart)
	local last = slingCooldowns[player] or 0
	if os.clock() - last < Config.Nightfall.SlingCooldown then
		return
	end
	slingCooldowns[player] = os.clock()
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	local best, bestDistance = nil, Config.Nightfall.SlingRange
	for _, beast in beasts do
		local d = (beast.Part.Position - hrp.Position).Magnitude - beast.Def.Size.Z / 2
		if d < bestDistance then
			best, bestDistance = beast, d
		end
	end
	if not best then
		return
	end
	local pebble = Instance.new("Part")
	pebble.Shape = Enum.PartType.Ball
	pebble.Size = Vector3.one * 0.8
	pebble.Anchored = true
	pebble.CanCollide = false
	pebble.Material = Enum.Material.Neon
	pebble.Color = Color3.fromRGB(255, 240, 180)
	pebble.Position = handle.Position
	pebble.Parent = workspace
	local tween = TweenService:Create(pebble, TweenInfo.new(0.2), { Position = best.Part.Position })
	tween:Play()
	tween.Completed:Once(function()
		pebble:Destroy()
	end)
	damageBeast(best, Config.Nightfall.SlingDamage, player)
end

function CycleService:Roar(player: Player)
	local profile = S.PlayerService:GetProfile(player)
	local session = S.PlayerService:GetSession(player)
	local record = S.TitanService:GetTitan(player)
	if not profile or not record then
		return
	end
	if profile.Stage < Config.Nightfall.RoarStage then
		S.PlayerService:Notify(player, "Titan Roar unlocks when your titan is an Adult.")
		return
	end
	if phase ~= "Night" then
		S.PlayerService:Notify(player, "Titan Roar only works during Nightfall.")
		return
	end
	if session.RoarNight == nightNumber then
		S.PlayerService:Notify(player, "Your titan already roared tonight.")
		return
	end
	session.RoarNight = nightNumber
	local stunned = 0
	for _, beast in beasts do
		if (beast.Part.Position - record.Root.Position).Magnitude <= Config.Nightfall.RoarRadius * record.Scale then
			beast.StunnedUntil = os.clock() + Config.Nightfall.RoarStun
			stunned += 1
		end
	end
	S.PlayerService:NotifyAll(string.format("%s's titan ROARS! %d beasts stunned.", player.DisplayName, stunned))
end

-- Phases ---------------------------------------------------------------------

local function setPhase(newPhase: string, length: number)
	phase = newPhase
	ReplicatedStorage:SetAttribute("Phase", phase)
	ReplicatedStorage:SetAttribute("PhaseEndsAt", now() + length)
	ReplicatedStorage:SetAttribute("NightNumber", nightNumber)
	ReplicatedStorage:SetAttribute("BossNight", CycleService:IsBossNight())
	applyLighting()
end

function CycleService:_runNight()
	nightNumber += 1
	for _, session in S.PlayerService:AllSessions() do
		session.NightDamage = 0
		session.BossDamage = 0
	end
	setPhase("Night", NIGHT_LENGTH)
	S.StealService:OnNightfall()
	for player in S.PlayerService:AllSessions() do
		S.TitanService:RefreshDeck(player) -- homesick Riders expire now
	end
	local boss = self:IsBossNight()
	S.PlayerService:NotifyAll(boss and "🌩 NIGHTFALL: The Storm King approaches! Protect the herd!" or "🌙 Nightfall! Beasts are coming. Protect the herd!")
	if boss then
		spawnBeast(true)
	end

	local endsAt = os.clock() + NIGHT_LENGTH
	local nextWave = os.clock() + 3
	while os.clock() < endsAt do
		if os.clock() >= nextWave then
			nextWave = os.clock() + Config.Nightfall.WaveInterval
			local titanCount = 0
			for _ in S.TitanService:AllTitans() do
				titanCount += 1
			end
			local count = math.min(2 + nightNumber // 2 + titanCount, Config.Nightfall.MaxBeasts - #beasts)
			for _ = 1, count do
				spawnBeast(false)
			end
		end
		task.wait(0.5)
	end
	self:_dawn(boss)
end

function CycleService:_dawn(wasBoss: boolean)
	clearBeasts()
	local survivors, total = 0, 0
	for player, record in S.TitanService:AllTitans() do
		total += 1
		local profile = S.PlayerService:GetProfile(player)
		if record.Exhausted then
			if profile then
				profile.NightsSurvivedStreak = 0
			end
		else
			survivors += 1
			if profile then
				profile.NightsSurvivedStreak += 1
			end
		end
	end

	local pool = Config.Nightfall.LootPerSurvivor * survivors * (1 + nightNumber * 0.1)
	if wasBoss then
		pool *= Config.Nightfall.BossLootMult
	end
	local share = total > 0 and math.floor(pool / total) or 0
	for player in S.PlayerService:AllSessions() do
		if share > 0 then
			S.PlayerService:AddCoins(player, share)
		end
		S.PlayerService:Notify(player, string.format("☀ Dawn! %d/%d titans survived. Herd loot: +%s coins each.", survivors, total, Util.formatNumber(share)))
	end

	if wasBoss then
		local top, topDamage = nil, 0
		for player, session in S.PlayerService:AllSessions() do
			player:SetAttribute("Guardian", nil)
			if session.BossDamage > topDamage then
				top, topDamage = player, session.BossDamage
			end
		end
		if top then
			top:SetAttribute("Guardian", true)
			S.PlayerService:NotifyAll(string.format("👑 %s is the Herd Guardian until the next Storm King!", top.DisplayName))
		end
		-- Survivors of a boss night get a bonus egg.
		for player, record in S.TitanService:AllTitans() do
			if not record.Exhausted and S.PlayerService:FreeEggSlots(player) > 0 then
				S.PlayerService:AddEgg(player, S.PlayerService:RollRarity(player, "Rare"))
			end
		end
	end
	S.TitanService:HealAll()
end

function CycleService:Init(services)
	S = services
	beastFolder = Instance.new("Folder")
	beastFolder.Name = "Beasts"
	beastFolder.Parent = workspace
	ReplicatedStorage:SetAttribute("Phase", phase)
	ReplicatedStorage:SetAttribute("PhaseEndsAt", now() + DAY_LENGTH)
	ReplicatedStorage:SetAttribute("NightNumber", 0)
	ReplicatedStorage:SetAttribute("StormUntil", 0)
	Players.PlayerRemoving:Connect(function(player)
		slingCooldowns[player] = nil
	end)
end

function CycleService:Start()
	RunService.Heartbeat:Connect(function(dt)
		if #beasts > 0 then
			stepBeasts(dt)
		end
	end)
	while true do
		setPhase("Day", DAY_LENGTH)
		if math.random() < Config.Cycle.StormChance then
			task.delay(20, function()
				self:StartStorm(Config.Cycle.StormLength)
			end)
		end
		task.wait(DAY_LENGTH)
		self:_runNight()
	end
end

return CycleService
