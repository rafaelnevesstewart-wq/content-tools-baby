-- 🧟 Zombie Survival (a match mode: everyone on one team). Waves of zombies
-- climb onto your island and go for you, or for your bed if nobody's near.
-- Each wave has more (and tougher) zombies, with a big Brute every 5th
-- wave. Survive all the waves to win; if your bed breaks and everyone is
-- knocked out, the zombies win. Knocking out a zombie gives Copper, and
-- every cleared wave gives Sparks.

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
}

local zombies: { Zombie } = {}
local byModel: { [Model]: Zombie } = {}
local folder: Folder? = nil
local round = 0
local pending = 0 -- zombies still being made (their avatars load first)
local rng = Random.new()

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
		MatchService.addResource(killer, "Copper", Config.Zombies.KillCopper)
		local data = DataService.get(killer)
		if data then
			data.stats.zombiesKilled = (data.stats.zombiesKilled or 0) + 1
		end
		Juice.sound(killer, "kill")
	end
	Debris:AddItem(zombie.model, 2)
	publish()
end

local makeZombie: (MatchService.MatchTeam, number, boolean, number) -> ()

local function spawnZombie(team: MatchService.MatchTeam, wave: number, brute: boolean, myRound: number)
	pending += 1
	local ok, problem = pcall(makeZombie, team, wave, brute, myRound)
	if round == myRound then
		pending -= 1
	end
	if not ok then
		warn("[Bottle a Storm] A zombie failed to rise: " .. tostring(problem))
	end
end

makeZombie = function(team: MatchService.MatchTeam, wave: number, brute: boolean, myRound: number)
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
	local settings = Config.Zombies
	local health = settings.Health + settings.HealthPerWave * (wave - 1)
	if brute then
		health *= settings.BruteHealth
		pcall(function()
			model:ScaleTo(1.45)
		end)
	end
	model.Name = if brute then "🧟 Brute" else "🧟 Zombie"
	humanoid.DisplayName = model.Name
	humanoid.MaxHealth = health
	humanoid.Health = health
	humanoid.WalkSpeed = settings.Speed + settings.SpeedPerWave * (wave - 1) - (if brute then 2 else 0)
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
		damage = (settings.Damage + settings.DamagePerWave * (wave - 1)) * (if brute then 2 else 1),
		lastSwing = 0,
		breaking = 0,
		lastPosition = root.Position,
		stuckFor = 0,
		lastHitBy = nil,
		dead = false,
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
	local bestDistance = Config.Zombies.SightRange
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
		BlockService.hitAt(ahead, 1)
		BlockService.hitAt(ahead + Vector3.new(0, 3, 0), 1)
		zombie.stuckFor = 0.5
	end
	local player, target = nearestPlayer(position)
	if player and target then
		zombie.breaking = 0
		local distance = (target.Position - position).Magnitude
		zombie.humanoid:MoveTo(target.Position)
		if distance <= Config.Zombies.Reach and os.clock() - zombie.lastSwing >= Config.Zombies.HitCooldown then
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
		if zombie.breaking >= Config.Zombies.BedBreakSeconds then
			zombie.breaking = 0
			MatchService.breakBedByBot(team, "🧟 The zombies", "")
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

local function runWaves(team: MatchService.MatchTeam, myRound: number)
	local settings = Config.Zombies
	local function stillOn(): boolean
		return round == myRound and MatchService.phase() == "playing"
	end
	workspace:SetAttribute("ZombieWaves", settings.Waves)
	publish(0, workspace:GetServerTimeNow() + settings.FirstDelay)
	Notify.all("🧟 Zombie Survival! Defend your bed for " .. settings.Waves .. " waves. Build walls, fast!", "rare")
	task.wait(settings.FirstDelay)
	for wave = 1, settings.Waves do
		if not stillOn() then
			return
		end
		local brutes = if wave % 5 == 0 then math.max(1, math.floor(playingCount() / 2)) else 0
		local count = settings.BaseCount + settings.PerWave * (wave - 1) + settings.PerPlayer * (playingCount() - 1)
		publish(wave, 0)
		Notify.all(
			"🧟 Wave " .. wave .. " of " .. settings.Waves .. (if brutes > 0 then ": a Brute is coming!" else "!"),
			"warn"
		)
		for _, player in Players:GetPlayers() do
			Juice.sound(player, "boom")
		end
		for i = 1, count + brutes do
			if not stillOn() then
				return
			end
			task.spawn(spawnZombie, team, wave, i > count, myRound)
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
			end
		end
		if wave == settings.Waves then
			Notify.all("🧟🏆 You survived every wave! The island is safe!", "rare")
			MatchService.declareWinner(team)
			return
		end
		Notify.all(
			"🧟 Wave "
				.. wave
				.. " cleared! +⚡"
				.. settings.WaveSparks * wave
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
		if workspace:GetAttribute("MatchMode") ~= "Zombies" then
			return
		end
		local team = MatchService.teamsInMatch()[1]
		if not team then
			return
		end
		local myRound = round
		local newFolder = Instance.new("Folder")
		newFolder.Name = "Zombies"
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
