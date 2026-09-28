-- The co-op wave modes (everyone on one team):
--   🧟 Zombie Survival: waves of zombies climb onto your island and go for
--      you, or for your bed if nobody's near, with a big Brute every 5th wave.
--   🏰 Castle Defense: your bed starts inside a stone castle. Storm monsters
--      (Storm Imps, fast Twisters, Storm Golems and, in the last wave, the
--      Storm King) smash through the walls to reach it. Between waves everyone
--      gets Stone Bricks to repair the walls.
-- Each wave has more (and tougher) monsters. Survive all the waves to win; if
-- your bed breaks and everyone is knocked out, they win. Knocking one out
-- gives Copper, and every cleared wave gives Sparks. The wave is shared as
-- attributes (ZombieWave, ZombiesLeft, ...; "HordeKind" says which mode) for
-- ZombieHUD.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent.Parent.Modules
local Juice = require(Modules.Juice)
local Notify = require(Modules.Notify)

local BlockService = require(script.Parent.BlockService)
local CombatService = require(script.Parent.CombatService)
local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local MatchService = require(script.Parent.MatchService)

local ZombieService = {}

local WALK = "rbxassetid://507777826"
local SKIN = Color3.fromRGB(116, 160, 92)

type Settings = typeof(Config.Zombies)

-- A kind of monster: its name, look and how it differs from a normal one.
type Kind = {
	name: string,
	health: number, -- times normal
	damage: number,
	speed: number, -- added to the speed
	scale: number,
	boss: boolean?,
}

local KINDS: { [string]: Kind } = {
	Zombie = { name = "🧟 Zombie", health = 1, damage = 1, speed = 0, scale = 1 },
	Brute = { name = "🧟 Brute", health = 4, damage = 2, speed = -2, scale = 1.45 },
	Imp = { name = "⛈️ Storm Imp", health = 1, damage = 1, speed = 0, scale = 1 },
	Twister = { name = "🌪️ Twister", health = 0.6, damage = 0.7, speed = 6, scale = 0.8 },
	Golem = { name = "⛰️ Storm Golem", health = 5, damage = 2, speed = -3, scale = 1.6 },
	King = { name = "👑 Storm King", health = 14, damage = 3, speed = -2, scale = 2.2, boss = true },
}

type Zombie = {
	model: Model,
	root: BasePart,
	humanoid: Humanoid,
	damage: number,
	lastSwing: number,
	breaking: number,
	lastPosition: Vector3,
	stuckFor: number,
	lastHitBy: Player?,
	dead: boolean,
	kind: string,
}

local zombies: { Zombie } = {}
local byModel: { [Model]: Zombie } = {}
local folder: Folder? = nil
local round = 0
local pending = 0 -- zombies still being made (their avatars load first)
local rng = Random.new()
local hordeKind = "Zombies" -- or "Castle"

local function settingsOf(): Settings
	return if hordeKind == "Castle" then Config.Castle :: any else Config.Zombies
end

local function publish(wave: number?, breakUntil: number?)
	local alive = 0
	for _, zombie in zombies do
		if not zombie.dead then
			alive += 1
		end
	end
	if wave then
		workspace:SetAttribute("ZombieWave", wave)
	end
	workspace:SetAttribute("ZombiesLeft", alive)
	if breakUntil ~= nil then
		workspace:SetAttribute("ZombieBreakUntil", breakUntil)
	end
end

local function clear()
	round += 1
	pending = 0
	for _, zombie in zombies do
		zombie.dead = true
	end
	zombies = {}
	byModel = {}
	if folder then
		folder:Destroy()
		folder = nil
	end
	workspace:SetAttribute("ZombieWave", nil)
	workspace:SetAttribute("ZombiesLeft", nil)
	workspace:SetAttribute("ZombieBreakUntil", nil)
	workspace:SetAttribute("ZombieWaves", nil)
	workspace:SetAttribute("HordeKind", nil)
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

---------------------------------------------------------------------------
-- Zombies
---------------------------------------------------------------------------

local function onKilled(zombie: Zombie)
	if zombie.dead then
		return
	end
	zombie.dead = true
	byModel[zombie.model] = nil
	local killer = zombie.lastHitBy
	if killer and killer.Parent and MatchService.isPlaying(killer) then
		MatchService.addResource(
			killer,
			"Copper",
			settingsOf().KillCopper * (if KINDS[zombie.kind].boss then 10 else 1)
		)
		local data = DataService.get(killer)
		if data then
			local stat = if hordeKind == "Castle" then "stormsKilled" else "zombiesKilled"
			data.stats[stat] = (data.stats[stat] or 0) + 1
		end
		if KINDS[zombie.kind].boss then
			Notify.all("👑 " .. killer.DisplayName .. " defeated the Storm King!", "rare")
		end
		Juice.sound(killer, "kill")
	end
	Debris:AddItem(zombie.model, 2)
	publish()
end

local makeZombie: (MatchService.MatchTeam, number, string, number) -> ()

local function spawnZombie(team: MatchService.MatchTeam, wave: number, kind: string, myRound: number)
	pending += 1
	local ok, problem = pcall(makeZombie, team, wave, kind, myRound)
	if round == myRound then
		pending -= 1
	end
	if not ok then
		warn("[Bottle a Storm] A zombie failed to rise: " .. tostring(problem))
	end
end

-- Storm monsters: dark storm-colored bodies with glowing eyes, a crackling
-- light and storm clouds puffing off them (Twisters are see-through wind,
-- Golems are rock).
local STORM_LOOK: { [string]: { body: Color3, material: Enum.Material, glow: Color3, transparency: number } } = {
	Imp = {
		body = Color3.fromRGB(60, 70, 110),
		material = Enum.Material.SmoothPlastic,
		glow = Color3.fromRGB(140, 200, 255),
		transparency = 0,
	},
	Twister = {
		body = Color3.fromRGB(190, 225, 240),
		material = Enum.Material.Glass,
		glow = Color3.fromRGB(220, 250, 255),
		transparency = 0.35,
	},
	Golem = {
		body = Color3.fromRGB(96, 96, 104),
		material = Enum.Material.Slate,
		glow = Color3.fromRGB(255, 190, 90),
		transparency = 0,
	},
	King = {
		body = Color3.fromRGB(40, 36, 70),
		material = Enum.Material.Basalt,
		glow = Color3.fromRGB(255, 220, 90),
		transparency = 0,
	},
}

local function dressStorm(model: Model, kind: string)
	local look = STORM_LOOK[kind]
	if not look then
		return
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.Color = look.body
			part.Material = look.material
			part.Transparency = look.transparency
		elseif part:IsA("Decal") then
			part.Transparency = 1
		end
	end
	local head = model:FindFirstChild("Head") :: BasePart?
	if head then
		for _, side in { -1, 1 } do
			local eye = Instance.new("Part")
			eye.Name = "Eye"
			eye.Shape = Enum.PartType.Ball
			eye.Size = Vector3.one * 0.28
			eye.Material = Enum.Material.Neon
			eye.Color = look.glow
			eye.CanCollide = false
			eye.CanQuery = false
			eye.Massless = true
			eye.CFrame = head.CFrame * CFrame.new(side * 0.22, 0.1, -0.55)
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = head
			weld.Part1 = eye
			weld.Parent = eye
			eye.Parent = model
		end
	end
	local torso = model:FindFirstChild("UpperTorso") :: BasePart?
	if torso then
		local light = Instance.new("PointLight")
		light.Color = look.glow
		light.Range = if kind == "King" then 24 else 10
		light.Brightness = 2
		light.Parent = torso
		local clouds = Instance.new("ParticleEmitter")
		clouds.Texture = "rbxasset://textures/particles/smoke_main.dds"
		clouds.Color = ColorSequence.new(look.body:Lerp(Color3.new(0, 0, 0), 0.2))
		clouds.Size = NumberSequence.new(1.2, 2.6)
		clouds.Transparency = NumberSequence.new(0.5, 1)
		clouds.Lifetime = NumberRange.new(0.6, 1)
		clouds.Rate = if kind == "Twister" then 30 else 10
		clouds.Speed = NumberRange.new(1, 3)
		clouds.SpreadAngle = Vector2.new(180, 180)
		clouds.Parent = torso
		if kind == "King" then
			local crown = Instance.new("Part")
			crown.Name = "Crown"
			crown.Size = Vector3.new(1.1, 0.5, 1.1)
			crown.Material = Enum.Material.Foil
			crown.Color = Color3.fromRGB(240, 196, 70)
			crown.CanCollide = false
			crown.CanQuery = false
			crown.Massless = true
			if head then
				crown.CFrame = head.CFrame * CFrame.new(0, 0.75, 0)
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = head
				weld.Part1 = crown
				weld.Parent = crown
			end
			crown.Parent = model
		end
	end
end

makeZombie = function(team: MatchService.MatchTeam, wave: number, kind: string, myRound: number)
	local ok, model = pcall(function()
		local description = Instance.new("HumanoidDescription")
		description.HeadColor = SKIN
		description.LeftArmColor = SKIN
		description.RightArmColor = SKIN
		description.TorsoColor = if rng:NextNumber() < 0.5
			then Color3.fromRGB(90, 70, 60)
			else Color3.fromRGB(70, 80, 100)
		description.LeftLegColor = Color3.fromRGB(60, 56, 70)
		description.RightLegColor = Color3.fromRGB(60, 56, 70)
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model or round ~= myRound or not folder or MatchService.phase() ~= "playing" then
		if ok and model then
			model:Destroy()
		end
		return
	end
	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	if not humanoid or not root then
		model:Destroy()
		return
	end
	local settings = settingsOf()
	local info = KINDS[kind]
	local health = (settings.Health + settings.HealthPerWave * (wave - 1)) * info.health
	dressStorm(model, kind)
	if info.scale ~= 1 then
		pcall(function()
			model:ScaleTo(info.scale)
		end)
	end
	model.Name = info.name
	humanoid.DisplayName = model.Name
	humanoid.MaxHealth = health
	humanoid.Health = health
	humanoid.WalkSpeed = settings.Speed
		+ settings.SpeedPerWave * (wave - 1)
		+ info.speed
		+ (if workspace:GetAttribute("IsNight") then settings.NightSpeed else 0)
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	humanoid.NameDisplayDistance = 60
	humanoid.BreakJointsOnDeath = false
	-- Somewhere on the island's edge.
	local angle = rng:NextNumber(0, math.pi * 2)
	local edge = Config.World.PlotRadius - 6
	model:PivotTo(team.frame * CFrame.new(math.cos(angle) * edge, 4, math.sin(angle) * edge))
	model.Parent = folder
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	local animation = Instance.new("Animation")
	animation.AnimationId = WALK
	pcall(function()
		local track = animator:LoadAnimation(animation)
		track.Looped = true
		track:Play(0.1, 1, 0.8) -- a slow shamble
	end)
	local zombie: Zombie = {
		model = model,
		root = root,
		humanoid = humanoid,
		damage = (settings.Damage + settings.DamagePerWave * (wave - 1)) * info.damage,
		lastSwing = 0,
		breaking = 0,
		lastPosition = root.Position,
		stuckFor = 0,
		lastHitBy = nil,
		dead = false,
		kind = kind,
	}
	table.insert(zombies, zombie)
	byModel[model] = zombie
	humanoid.Died:Connect(function()
		onKilled(zombie)
	end)
	publish()
end

local function nearestPlayer(position: Vector3): (Player?, BasePart?)
	local best: Player? = nil
	local bestRoot: BasePart? = nil
	local bestDistance = settingsOf().SightRange
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and MatchService.isPlaying(player) and not player:GetAttribute("Invisible") then
			local distance = (root.Position - position).Magnitude
			if distance < bestDistance then
				best, bestRoot, bestDistance = player, root, distance
			end
		end
	end
	return best, bestRoot
end

local function think(zombie: Zombie, team: MatchService.MatchTeam, dt: number)
	local position = zombie.root.Position
	if position.Y < Config.World.VoidKillY then
		zombie.lastHitBy = nil
		zombie.humanoid.Health = 0
		return
	end
	-- Stuck on a wall of blocks? Claw at it.
	local moved = flat(position - zombie.lastPosition).Magnitude
	zombie.lastPosition = position
	if zombie.humanoid.MoveDirection.Magnitude > 0.1 and moved < 0.25 then
		zombie.stuckFor += dt
	else
		zombie.stuckFor = 0
	end
	if zombie.stuckFor > 1 then
		zombie.humanoid.Jump = true
		local ahead = position + zombie.root.CFrame.LookVector * 3
		local power = math.max(1, math.floor(KINDS[zombie.kind].damage))
		BlockService.hitAt(ahead, power)
		BlockService.hitAt(ahead + Vector3.new(0, 3, 0), power)
		zombie.stuckFor = 0.5
	end
	local player, target = nearestPlayer(position)
	if player and target then
		zombie.breaking = 0
		local distance = (target.Position - position).Magnitude
		zombie.humanoid:MoveTo(target.Position)
		local settings = settingsOf()
		if
			distance <= settings.Reach * KINDS[zombie.kind].scale
			and os.clock() - zombie.lastSwing >= settings.HitCooldown
		then
			zombie.lastSwing = os.clock()
			local push = flat(target.Position - position)
			push = (if push.Magnitude > 0.1 then push.Unit else Vector3.xAxis) * 30 + Vector3.new(0, 10, 0)
			CombatService.hurtByBot(player, zombie.damage, push, zombie.model.Name, "")
		end
		return
	end
	-- Nobody close: go for the bed.
	if not team.bedAlive then
		zombie.humanoid:MoveTo(team.frame.Position)
		return
	end
	local bed = (team.frame * CFrame.new(0, 0, 22)).Position
	if flat(bed - position).Magnitude < 6 then
		zombie.humanoid:MoveTo(position)
		zombie.breaking += dt
		if zombie.breaking >= settingsOf().BedBreakSeconds then
			zombie.breaking = 0
			MatchService.breakBedByBot(
				team,
				if hordeKind == "Castle" then "⛈️ The storm monsters" else "🧟 The zombies",
				""
			)
		end
	else
		zombie.breaking = 0
		zombie.humanoid:MoveTo(bed)
	end
end

---------------------------------------------------------------------------
-- Waves
---------------------------------------------------------------------------

local function playingCount(): number
	local count = 0
	for _, player in Players:GetPlayers() do
		if MatchService.isPlaying(player) then
			count += 1
		end
	end
	return count
end

-- 🏰 The castle: a ring of Stone Brick walls around your bed with a tower at
-- each corner and a gate facing your spawn.
local function buildCastle(team: MatchService.MatchTeam)
	local builder = team.members[1]
	if not builder then
		return
	end
	local size = Config.Match.BlockSize
	local bed = team.frame * CFrame.new(0, 0, 22)
	local half = Config.Castle.WallHalf
	for x = -half, half do
		for z = -half, half do
			local edge = math.abs(x) == half or math.abs(z) == half
			local corner = math.abs(x) == half and math.abs(z) == half
			-- The gate: a gap in the wall that faces your spawn (-Z).
			local gate = z == -half and math.abs(x) <= 1
			if edge and not gate then
				local height = if corner then Config.Castle.WallHeight + 2 else Config.Castle.WallHeight
				for y = 0, height - 1 do
					-- Battlements: every other block on top of the wall.
					if y < Config.Castle.WallHeight - 1 or corner or (x + z) % 2 == 0 then
						local point = (bed * CFrame.new(x * size, size / 2 + y * size, z * size)).Position
						BlockService.placeFor(builder, point, "StoneBricks")
					end
				end
			end
		end
	end
end

local function kindsFor(wave: number, total: number, count: number): { string }
	local list = {}
	local castle = hordeKind == "Castle"
	for i = 1, count do
		if castle and wave >= 3 and i % 3 == 0 then
			table.insert(list, "Twister")
		else
			table.insert(list, if castle then "Imp" else "Zombie")
		end
	end
	local bigEvery = if castle then 4 else 5
	if wave % bigEvery == 0 or (castle and wave == total) then
		for _ = 1, math.max(1, math.floor(playingCount() / 2)) do
			table.insert(list, if castle then "Golem" else "Brute")
		end
	end
	if castle and wave == total then
		table.insert(list, "King")
	end
	return list
end

local function runWaves(team: MatchService.MatchTeam, myRound: number)
	local settings = settingsOf()
	local castle = hordeKind == "Castle"
	local function stillOn(): boolean
		return round == myRound and MatchService.phase() == "playing"
	end
	workspace:SetAttribute("ZombieWaves", settings.Waves)
	workspace:SetAttribute("HordeKind", hordeKind)
	publish(0, workspace:GetServerTimeNow() + settings.FirstDelay)
	if castle then
		buildCastle(team)
		Notify.all(
			"🏰 Castle Defense! Storm monsters will attack your castle for "
				.. settings.Waves
				.. " waves. Guard the gate and fix the walls!",
			"rare"
		)
	else
		Notify.all(
			"🧟 Zombie Survival! Defend your bed for " .. settings.Waves .. " waves. Build walls, fast!",
			"rare"
		)
	end
	task.wait(settings.FirstDelay)
	for wave = 1, settings.Waves do
		if not stillOn() then
			return
		end
		local count = settings.BaseCount + settings.PerWave * (wave - 1) + settings.PerPlayer * (playingCount() - 1)
		local kinds = kindsFor(wave, settings.Waves, count)
		publish(wave, 0)
		local warning = ""
		if table.find(kinds, "King") then
			warning = ": 👑 THE STORM KING IS COMING!"
		elseif table.find(kinds, "Golem") then
			warning = ": a Storm Golem is coming!"
		elseif table.find(kinds, "Brute") then
			warning = ": a Brute is coming!"
		end
		Notify.all(
			(if castle then "⛈️" else "🧟")
				.. " Wave "
				.. wave
				.. " of "
				.. settings.Waves
				.. warning
				.. (if warning == "" then "!" else ""),
			"warn"
		)
		for _, player in Players:GetPlayers() do
			Juice.sound(player, "boom")
		end
		for _, kind in kinds do
			if not stillOn() then
				return
			end
			task.spawn(spawnZombie, team, wave, kind, myRound)
			task.wait(0.5)
		end
		-- Wait until they're all down.
		repeat
			task.wait(1)
			local alive = 0
			for _, zombie in zombies do
				if not zombie.dead then
					alive += 1
				end
			end
		until (alive == 0 and pending == 0) or not stillOn()
		if not stillOn() then
			return
		end
		zombies = {}
		for _, member in team.members do
			if member.Parent and MatchService.isPlaying(member) then
				IncomeService.addSparks(member, settings.WaveSparks * wave)
				if castle then
					BlockService.add(member, "StoneBricks", Config.Castle.RepairBlocks)
				end
			end
		end
		if wave == settings.Waves then
			Notify.all(
				if castle
					then "🏰🏆 The castle stands! You beat every storm wave!"
					else "🧟🏆 You survived every wave! The island is safe!",
				"rare"
			)
			MatchService.declareWinner(team)
			return
		end
		Notify.all(
			(if castle then "⛈️" else "🧟")
				.. " Wave "
				.. wave
				.. " cleared! +⚡"
				.. settings.WaveSparks * wave
				.. (if castle then " and " .. Config.Castle.RepairBlocks .. " Stone Bricks to fix the walls" else "")
				.. ". Next wave in "
				.. settings.BreakSeconds
				.. "s.",
			"success"
		)
		publish(wave, workspace:GetServerTimeNow() + settings.BreakSeconds)
		task.wait(settings.BreakSeconds)
	end
end

function ZombieService.start()
	CombatService.addTargets({
		enemiesOf = function(player: Player): { BasePart }
			local list = {}
			if MatchService.isPlaying(player) then
				for _, zombie in zombies do
					if not zombie.dead then
						table.insert(list, zombie.root)
					end
				end
			end
			return list
		end,
		botOf = function(part: Instance): Model?
			local model = part:FindFirstAncestorOfClass("Model")
			while model and not byModel[model] do
				local parent = model.Parent
				model = if parent then parent:FindFirstAncestorOfClass("Model") else nil
			end
			return model
		end,
		hurt = function(model: Model, attacker: Player, amount: number, push: Vector3)
			local zombie = byModel[model]
			if not zombie or zombie.dead or not MatchService.isPlaying(attacker) then
				return
			end
			zombie.lastHitBy = attacker
			local head = model:FindFirstChild("Head") :: BasePart?
			if head then
				Remotes.event("DamageShown"):FireClient(attacker, head.Position, math.floor(amount + 0.5))
			end
			Juice.sound(attacker, "hit")
			zombie.humanoid:TakeDamage(amount)
			zombie.root.AssemblyLinearVelocity += push * 0.6
		end,
	})

	MatchService.MatchStarted:Connect(function()
		clear()
		local mode = workspace:GetAttribute("MatchMode")
		if mode ~= "Zombies" and mode ~= "Castle" then
			return
		end
		hordeKind = mode
		local team = MatchService.teamsInMatch()[1]
		if not team then
			return
		end
		local myRound = round
		local newFolder = Instance.new("Folder")
		newFolder.Name = if mode == "Castle" then "StormMonsters" else "Zombies"
		newFolder.Parent = workspace
		folder = newFolder
		task.spawn(function()
			local ok, problem = pcall(runWaves, team, myRound)
			if not ok then
				warn("[Bottle a Storm] Zombie waves failed: " .. tostring(problem))
			end
		end)
		task.spawn(function()
			local last = os.clock()
			while round == myRound do
				task.wait(0.2)
				local dt = os.clock() - last
				last = os.clock()
				if MatchService.phase() == "playing" then
					for _, zombie in table.clone(zombies) do
						if not zombie.dead and zombie.model.Parent then
							pcall(think, zombie, team, dt)
						end
					end
				end
			end
		end)
	end)
	MatchService.MatchEnded:Connect(clear)
end

return ZombieService
