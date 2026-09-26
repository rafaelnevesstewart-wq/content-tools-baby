-- Monsters: packs that roam near the herd by day and hunt in waves at night.
-- They chase and bite players on the ground; at night they also attack titans.
-- Built from parts (no imported meshes): dark hides, glowing eyes, jaws of teeth.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local MonsterService = {}
local S

local monsters = {} -- list of monster records
local folder
local rng = Random.new()

local function wrapPi(a: number): number
	a = (a + math.pi) % (math.pi * 2)
	return a - math.pi
end

local function part(props, parent: Instance, sphere: boolean?)
	local p = Instance.new(props.ClassName or "Part")
	props.ClassName = nil
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.Slate
	for key, value in props do
		p[key] = value
	end
	if sphere then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	p.Parent = parent
	return p
end

-- Builds a monster at the origin, facing -Z. Returns the model and its height.
local function buildModel(kind: string, def)
	local k = def.Size
	local model = Instance.new("Model")
	model.Name = def.Name
	local legLength = 3 * k
	local hipY = legLength + 1.2 * k
	local root = part({ Name = "Root", Size = Vector3.new(2, 2, 2) * k, Transparency = 1, CFrame = CFrame.new(0, hipY, 0) }, model)
	model.PrimaryPart = root
	local base = CFrame.new(0, hipY, 0)
	local hide = def.Color
	local dark = hide:Lerp(Color3.new(0, 0, 0), 0.4)
	local bone = Color3.fromRGB(220, 210, 185)
	local material = kind == "Golem" and Enum.Material.Rock or Enum.Material.Slate
	local golem = kind == "Golem"

	part({ Name = "Body", Size = Vector3.new(4, 3.4, 7.5) * k, CFrame = base, Color = hide, Material = material }, model, not golem)
	part(
		{ Name = "Chest", Size = Vector3.new(4.4, 3.8, 3.4) * k, CFrame = base * CFrame.new(0, 0.4 * k, -2.6 * k), Color = hide, Material = material },
		model,
		not golem
	)
	local headCF = base * CFrame.new(0, 1.1 * k, -5.2 * k) * CFrame.Angles(-0.15, 0, 0)
	part({ Name = "Head", Size = Vector3.new(2.8, 2.4, 3.6) * k, CFrame = headCF, Color = hide, Material = material }, model, not golem)
	part({
		Name = "Jaw",
		Size = Vector3.new(2.3, 0.8, 3.2) * k,
		CFrame = headCF * CFrame.new(0, -1.3 * k, -0.4 * k) * CFrame.Angles(0.35, 0, 0),
		Color = dark,
		Material = material,
	}, model, not golem)
	part({
		Name = "Mouth",
		Size = Vector3.new(2.1, 0.7, 2.8) * k,
		CFrame = headCF * CFrame.new(0, -0.8 * k, -0.6 * k),
		Color = Color3.fromRGB(70, 5, 5),
		Material = Enum.Material.SmoothPlastic,
	}, model, true)
	for i = -2, 2 do
		part({
			ClassName = "WedgePart",
			Name = "Fang",
			Size = Vector3.new(0.25, 0.8, 0.25) * k,
			CFrame = headCF * CFrame.new(i * 0.4 * k, -0.9 * k, -1.9 * k + math.abs(i) * 0.2 * k) * CFrame.Angles(math.pi, 0, 0),
			Color = bone,
			Material = Enum.Material.SmoothPlastic,
		}, model)
	end
	for _, side in { -1, 1 } do
		local eye = part({
			Name = "Eye",
			Size = Vector3.new(0.8, 0.35, 0.3) * k,
			CFrame = headCF * CFrame.new(side * 0.8 * k, 0.5 * k, -1.7 * k) * CFrame.Angles(0, 0, side * 0.3),
			Color = def.Eye,
			Material = Enum.Material.Neon,
		}, model)
		if side == 1 then
			local light = Instance.new("PointLight")
			light.Color = def.Eye
			light.Range = 10 * k
			light.Brightness = 2
			light.Parent = eye
		end
		-- Ears or horns.
		if kind == "Gloomhound" or kind == "Gloomling" then
			part({
				ClassName = "WedgePart",
				Name = "Ear",
				Size = Vector3.new(0.3, 1.4, 0.9) * k,
				CFrame = headCF * CFrame.new(side * 0.9 * k, 1.5 * k, 0.4 * k),
				Color = dark,
			}, model)
		else
			part({
				Name = "Horn",
				Size = Vector3.new(0.6, 2.6, 0.6) * k,
				CFrame = headCF * CFrame.new(side * 1.1 * k, 1.4 * k, 0.3 * k) * CFrame.Angles(-0.5, 0, -side * 0.6),
				Color = bone,
			}, model, true)
		end
	end
	-- Spikes along the spine.
	for i = 0, 4 do
		part({
			ClassName = "WedgePart",
			Name = "Spine",
			Size = Vector3.new(0.3, (kind == "Thornback" and 2.4 or 1.2) * k, 1.4 * k),
			CFrame = base * CFrame.new(0, 1.7 * k, (i - 2) * 1.3 * k),
			Color = kind == "Thornback" and bone or dark,
		}, model)
	end
	-- Legs.
	local legs = {}
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			local leg = part({
				Name = "Leg",
				Size = Vector3.new(0.9 * k, legLength + 0.6 * k, 0.9 * k) * (golem and 1.6 or 1),
				CFrame = CFrame.new(x * 1.5 * k, legLength / 2, z * 2.6 * k),
				Color = dark,
				Material = material,
			}, model)
			table.insert(legs, { Part = leg, Offset = CFrame.new(x * 1.5 * k, legLength / 2 - hipY, z * 2.6 * k), Phase = (x * z > 0) and 0 or math.pi })
		end
	end
	-- Tail.
	part({
		Name = "Tail",
		Size = Vector3.new(0.8, 0.8, 4) * k,
		CFrame = base * CFrame.new(0, 0.4 * k, 5 * k) * CFrame.Angles(0.4, 0, 0),
		Color = dark,
		Material = material,
	}, model, true)

	if def.Boss then
		for i = 0, 5 do
			local a = i / 6 * math.pi * 2
			part({
				Name = "CrownHorn",
				Size = Vector3.new(0.5, 3, 0.5) * k,
				CFrame = headCF * CFrame.new(math.cos(a) * 1.1 * k, 2 * k, math.sin(a) * 1.1 * k) * CFrame.Angles(math.sin(a) * 0.4, 0, -math.cos(a) * 0.4),
				Color = Color3.fromRGB(200, 150, 255),
				Material = Enum.Material.Neon,
			}, model, true)
		end
		local storm = Instance.new("ParticleEmitter")
		storm.Rate = 25
		storm.Lifetime = NumberRange.new(1, 2)
		storm.Speed = NumberRange.new(4, 8)
		storm.Size = NumberSequence.new(1.5, 0)
		storm.LightEmission = 1
		storm.Color = ColorSequence.new(Color3.fromRGB(200, 150, 255))
		storm.SpreadAngle = Vector2.new(180, 180)
		storm.Parent = root
	end
	return model, root, hipY, legs
end

local function healthBar(root: BasePart, def)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(def.Boss and 240 or 110, def.Boss and 44 or 26)
	gui.StudsOffset = Vector3.new(0, 3 * def.Size + 1, 0)
	gui.MaxDistance = def.Boss and 700 or 160
	gui.LightInfluence = 0
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.fromScale(1, 0.55)
	name.Font = Enum.Font.Creepster
	name.TextScaled = true
	name.TextColor3 = def.Eye
	name.TextStrokeTransparency = 0.2
	name.Text = def.Name
	name.Parent = gui
	local back = Instance.new("Frame")
	back.BackgroundColor3 = Color3.fromRGB(25, 0, 0)
	back.BorderSizePixel = 0
	back.Size = UDim2.fromScale(1, 0.35)
	back.Position = UDim2.fromScale(0, 0.62)
	back.Parent = gui
	local bar = Instance.new("Frame")
	bar.BackgroundColor3 = Color3.fromRGB(200, 30, 30)
	bar.BorderSizePixel = 0
	bar.Size = UDim2.fromScale(1, 1)
	bar.Parent = back
	gui.Parent = root
	return bar
end

-- API --------------------------------------------------------------------------

function MonsterService:All()
	return monsters
end

function MonsterService:Spawn(kind: string, position: Vector3, isNight: boolean)
	local def = Config.Monsters[kind]
	local model, root, hipY, legs = buildModel(kind, def)
	local nightScale = isNight and (1 + S.CycleService:NightNumber() * 0.08) or 1
	local health = def.Health * nightScale
	if def.Boss then
		health *= math.max(1, #Players:GetPlayers() / 2)
	end
	local monster = {
		Kind = kind,
		Def = def,
		Model = model,
		Root = root,
		HipY = hipY,
		Legs = legs,
		Health = health,
		MaxHealth = health,
		Night = isNight,
		StunnedUntil = 0,
		NextAttack = 0,
		Home = position,
		Wander = position,
		Yaw = rng:NextNumber(0, math.pi * 2),
		Radius = 3 * def.Size,
	}
	monster.Bar = healthBar(root, def)
	model:PivotTo(CFrame.new(position.X, hipY, position.Z) * CFrame.Angles(0, monster.Yaw, 0))
	model.Parent = folder
	table.insert(monsters, monster)
	return monster
end

function MonsterService:Position(monster): Vector3
	return monster.Root.Position
end

function MonsterService:Stun(monster, seconds: number)
	monster.StunnedUntil = math.max(monster.StunnedUntil, os.clock() + seconds)
end

function MonsterService:StunNear(position: Vector3, radius: number, seconds: number): number
	local count = 0
	for _, monster in monsters do
		if (monster.Root.Position - position).Magnitude <= radius + monster.Radius then
			self:Stun(monster, seconds)
			count += 1
		end
	end
	return count
end

local function remove(monster)
	local index = table.find(monsters, monster)
	if index then
		table.remove(monsters, index)
	end
end

-- Falls apart into loose pieces when it dies.
local function collapse(monster)
	local model = monster.Model
	local gui = monster.Root:FindFirstChildOfClass("BillboardGui")
	if gui then
		gui:Destroy()
	end
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CanCollide = p.Name ~= "Root"
			p.AssemblyLinearVelocity = Vector3.new(rng:NextNumber(-8, 8), rng:NextNumber(4, 14), rng:NextNumber(-8, 8))
		elseif p:IsA("PointLight") then
			p:Destroy()
		end
	end
	Debris:AddItem(model, 4)
end

-- Returns true if the hit killed it.
function MonsterService:Damage(monster, amount: number, attacker: Player?): boolean
	if monster.Health <= 0 then
		return false
	end
	monster.Health -= amount
	monster.Bar.Size = UDim2.fromScale(math.clamp(monster.Health / monster.MaxHealth, 0, 1), 1)
	if attacker then
		monster.LastAttacker = attacker
		local session = S.PlayerService:GetSession(attacker)
		if session then
			session.NightDamage += amount
			if monster.Def.Boss then
				session.BossDamage += amount
			end
		end
	end
	if monster.Health > 0 then
		return false
	end
	remove(monster)
	collapse(monster)
	if attacker and attacker.Parent then
		local reward = math.floor(monster.Def.Reward * (1 + S.CycleService:NightNumber() * 0.1))
		S.PlayerService:AddCoins(attacker, reward)
		local food = S.PlayerService:AddFood(attacker, rng:NextInteger(1, 3) * math.ceil(monster.Def.Size))
		local xp = math.floor(monster.Def.XP * (monster.Night and (1 + S.CycleService:NightNumber() * 0.1) or 1))
		S.PlayerService:Notify(
			attacker,
			string.format("Killed a %s! +%d XP, +%d coins%s", monster.Def.Name, xp, reward, food > 0 and (", +" .. food .. " food") or "")
		)
		S.PlayerService:AddXP(attacker, xp)
		Remotes.Ui:FireClient(attacker, { XPGain = xp, At = monster.Root.Position })
	end
	if monster.Def.Boss then
		S.PlayerService:NotifyAll("The Storm King has fallen!")
	end
	return true
end

function MonsterService:SpawnWave(nightNumber: number)
	local titanCount = 0
	for _ in S.TitanService:AllTitans() do
		titanCount += 1
	end
	local count = math.min(2 + nightNumber // 2 + titanCount, Config.Nightfall.MaxMonsters - #monsters)
	local center = S.TitanService:HerdCenter()
	for _ = 1, count do
		local a = rng:NextNumber(0, math.pi * 2)
		local kinds = Config.NightMonsterKinds
		self:Spawn(kinds[rng:NextInteger(1, #kinds)], center + Vector3.new(math.cos(a), 0, math.sin(a)) * Config.Nightfall.SpawnRadius, true)
	end
end

function MonsterService:SpawnBoss()
	local center = S.TitanService:HerdCenter()
	local a = rng:NextNumber(0, math.pi * 2)
	self:Spawn("StormKing", center + Vector3.new(math.cos(a), 0, math.sin(a)) * Config.Nightfall.SpawnRadius * 1.3, true)
end

function MonsterService:ClearNight()
	for _, monster in table.clone(monsters) do
		if monster.Night then
			remove(monster)
			monster.Model:Destroy()
		end
	end
end

-- AI ---------------------------------------------------------------------------

local function nearestPlayer(position: Vector3, range: number)
	local best, bestDistance = nil, range
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		-- Only players on the ground can be reached (not riding high on a titan).
		if hrp and humanoid and humanoid.Health > 0 and hrp.Position.Y < 14 and not S.CombatService:InSafeZone(hrp.Position) then
			local d = ((hrp.Position - position) * Vector3.new(1, 0, 1)).Magnitude
			if d < bestDistance then
				best, bestDistance = player, d
			end
		end
	end
	return best, bestDistance
end

local function nearestLivingTitan(position: Vector3)
	local best, bestRecord, bestDistance = nil, nil, math.huge
	for player, record in S.TitanService:AllTitans() do
		if not record.Exhausted and record.Root and record.Root.Parent then
			local d = ((record.Root.Position - position) * Vector3.new(1, 0, 1)).Magnitude
			if d < bestDistance then
				best, bestRecord, bestDistance = player, record, d
			end
		end
	end
	return best, bestRecord, bestDistance
end

local function step(monster, dt: number, t: number)
	local def = monster.Def
	local position = monster.Root.Position
	local flat = Vector3.new(position.X, 0, position.Z)
	local goal, reach, onArrive = nil, 0, nil
	local speed = def.Speed

	if t < monster.StunnedUntil then
		return
	end

	local target, distance = nearestPlayer(position, def.Aggro)
	if target then
		local hrp = target.Character.HumanoidRootPart
		goal = Vector3.new(hrp.Position.X, 0, hrp.Position.Z)
		reach = monster.Radius + 3
		onArrive = function()
			S.CombatService:DamagePlayer(target, def.Damage, nil, def.Name)
		end
	elseif monster.Night then
		local owner, record, titanDistance = nearestLivingTitan(position)
		if owner then
			goal = Vector3.new(record.Root.Position.X, 0, record.Root.Position.Z)
			distance = titanDistance
			reach = 11 * record.Scale + monster.Radius
			onArrive = function()
				S.TitanService:Damage(owner, def.Damage)
			end
		end
	end
	if not goal then
		-- Wander around home.
		if (monster.Wander - flat).Magnitude < 4 then
			local a = rng:NextNumber(0, math.pi * 2)
			monster.Wander = monster.Home + Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(10, 50)
			if monster.Starter and monster.Wander.Magnitude < Config.StarterMonsters.InnerRadius then
				monster.Wander = monster.Wander.Unit * Config.StarterMonsters.InnerRadius -- stay out of town
			end
		end
		goal = monster.Wander
		distance = (goal - flat).Magnitude
		speed *= 0.35
	end

	local moving = false
	local delta = goal - flat
	if distance > reach and delta.Magnitude > 0.1 then
		flat += delta.Unit * math.min(speed * dt, distance - reach)
		moving = true
	end
	if delta.Magnitude > 0.1 then
		monster.Yaw = math.atan2(-delta.X, -delta.Z)
	end
	if onArrive and distance <= reach + 0.5 and t >= monster.NextAttack then
		monster.NextAttack = t + def.AttackEvery
		monster.LungeUntil = t + 0.25
		onArrive()
	end

	-- Gait: body bobs and legs swing while moving; a quick lunge on attack.
	local bob = moving and math.abs(math.sin(t * speed * 0.5)) * 0.4 * def.Size or 0
	local lunge = (monster.LungeUntil and t < monster.LungeUntil) and 1.5 * def.Size or 0
	local cf = CFrame.new(flat.X, monster.HipY + bob, flat.Z) * CFrame.Angles(0, monster.Yaw, 0) * CFrame.new(0, 0, -lunge)
	monster.Model:PivotTo(cf)
	if moving then
		for _, leg in monster.Legs do
			local swing = math.sin(t * speed * 0.5 + leg.Phase) * 0.5
			leg.Part.CFrame = cf * leg.Offset * CFrame.new(0, 1.5 * def.Size, 0) * CFrame.Angles(swing, 0, 0) * CFrame.new(0, -1.5 * def.Size, 0)
		end
	end
end

-- Keeps weak Gloomlings prowling just outside town, day and night.
local function keepStarterPack()
	local count = 0
	for _, monster in monsters do
		if monster.Starter then
			count += 1
		end
	end
	local def = Config.StarterMonsters
	for _ = count + 1, def.Count do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(def.InnerRadius, def.OuterRadius)
		local monster = MonsterService:Spawn(def.Kind, Vector3.new(math.cos(a) * r, 0, math.sin(a) * r), false)
		monster.Starter = true
	end
end

-- Keeps a pack of day monsters roaming just ahead of the herd.
local function keepDayPack()
	local herdAngle = S.TitanService:GetAngle()
	local dayCount = 0
	for _, monster in table.clone(monsters) do
		if not monster.Night and not monster.Starter then
			local p = monster.Root.Position
			local a = math.atan2(p.Z, p.X)
			if wrapPi(a - herdAngle) < -0.45 then
				remove(monster)
				monster.Model:Destroy()
			else
				dayCount += 1
			end
		end
	end
	for _ = dayCount + 1, Config.DayMonsters.Count do
		local a = herdAngle + rng:NextNumber(0.1, 0.5)
		local r = Config.Herd.PathRadius + rng:NextNumber(-200, 200)
		local kinds = Config.DayMonsters.Kinds
		MonsterService:Spawn(kinds[rng:NextInteger(1, #kinds)], Vector3.new(math.cos(a) * r, 0, math.sin(a) * r), false)
	end
end

function MonsterService:Init(services)
	S = services
	folder = Instance.new("Folder")
	folder.Name = "Monsters"
	folder.Parent = workspace
end

function MonsterService:Start()
	RunService.Heartbeat:Connect(function(dt)
		local t = os.clock()
		for _, monster in table.clone(monsters) do
			if monster.Model.Parent then
				step(monster, dt, t)
			end
		end
	end)
	while true do
		keepDayPack()
		keepStarterPack()
		task.wait(3)
	end
end

return MonsterService
