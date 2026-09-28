-- 🤖 Bots: computer players that fill empty teams, so a match can start with
-- just one real player (MatchService adds all-bot teams until there are
-- Config.Bots.MinTeams). Each bot is an avatar in its team's colors with a
-- sword. It goes after enemies it can see; otherwise it walks across the
-- bridges to the nearest enemy bed and breaks it, swinging at any blocks in
-- its way. It respawns while its bed stands, just like a player, and gets a
-- better sword as the match goes on. How tough they are (Easy, Normal, Hard)
-- is voted in the lobby.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local MatchData = require(Shared.MatchData)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent.Parent.Modules
local ItemModels = require(Modules.ItemModels)
local Juice = require(Modules.Juice)

local BlockService = require(script.Parent.BlockService)
local VoteService = require(script.Parent.VoteService)
local CombatService = require(script.Parent.CombatService)
local MatchService = require(script.Parent.MatchService)

local BotService = {}

-- Roblox's standard R15 animations (the same ones players use).
local ANIMATIONS = {
	idle = "rbxassetid://507766666",
	walk = "rbxassetid://507777826",
	hold = "rbxassetid://507768375",
	slash = "rbxassetid://522635514",
}
local SKIN = {
	Color3.fromRGB(255, 219, 172),
	Color3.fromRGB(234, 184, 146),
	Color3.fromRGB(198, 134, 66),
	Color3.fromRGB(141, 85, 36),
	Color3.fromRGB(94, 58, 34),
}

type Bot = {
	model: Model,
	root: BasePart,
	humanoid: Humanoid,
	team: MatchService.MatchTeam,
	name: string, -- shown in the kill feed, e.g. "🤖 Bolt"
	route: { Vector3 },
	routeGoal: Vector3?,
	lastPosition: Vector3,
	stuckFor: number,
	lastSwing: number,
	breaking: number,
	lastHitBy: Player?,
	lastHitAt: number,
	dead: boolean,
	tracks: { [string]: AnimationTrack },
}

local bots: { Bot } = {}
local byModel: { [Model]: Bot } = {}
local folder: Folder? = nil
local matchStartedAt = 0
local round = 0
local rng = Random.new()
local nameIndex = 0
-- How tough bots are this match (voted in the lobby).
local level = Config.Bots.Difficulties.Normal

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function nextName(): string
	nameIndex += 1
	local names = Config.Bots.Names
	return "🤖 " .. names[(nameIndex - 1) % #names + 1]
end

local function swordTier(): number
	return math.clamp(1 + math.floor((os.clock() - matchStartedAt) / 150), 1, 3)
end

local function play(bot: Bot, name: string)
	local track = bot.tracks[name]
	if track and not track.IsPlaying then
		track:Play(0.15)
	end
end

local function stop(bot: Bot, name: string)
	local track = bot.tracks[name]
	if track and track.IsPlaying then
		track:Stop(0.15)
	end
end

---------------------------------------------------------------------------
-- Getting around: islands and bridges
---------------------------------------------------------------------------

-- Which island a point is on: the middle (nil frame) or a team island.
local function islandOf(point: Vector3): CFrame?
	local best: CFrame? = nil
	local bestDistance = flat(point).Magnitude - Config.World.CenterRadius
	for _, team in MatchService.teamsInMatch() do
		local distance = flat(point - team.frame.Position).Magnitude - Config.World.PlotRadius
		if distance < bestDistance then
			best, bestDistance = team.frame, distance
		end
	end
	return best
end

-- Waypoints from `from` to `to`: off your island over its bridge, across the
-- middle island, and over the other bridge (bridges point at the middle).
local function routeTo(from: Vector3, to: Vector3): { Vector3 }
	local start = islandOf(from)
	local finish = islandOf(to)
	local route = {}
	local function add(point: Vector3)
		table.insert(route, Vector3.new(point.X, 3, point.Z))
	end
	if start ~= finish then
		if start then
			local out = flat(start.Position).Unit
			add(start:PointToWorldSpace(Vector3.new(9, 0, -12))) -- around the generator
			add(start.Position - out * (Config.World.PlotRadius - 4))
			add(out * (Config.World.CenterRadius - 8))
		end
		if finish then
			local out = flat(finish.Position).Unit
			add(out * (Config.World.CenterRadius - 8))
			add(finish.Position - out * (Config.World.PlotRadius - 4))
			add(finish:PointToWorldSpace(Vector3.new(9, 0, -12)))
		end
	end
	add(to)
	return route
end

---------------------------------------------------------------------------
-- Fighting
---------------------------------------------------------------------------

local function alive(bot: Bot): boolean
	return not bot.dead and bot.humanoid.Health > 0 and bot.model.Parent ~= nil
end

local function isEnemyPlayer(bot: Bot, player: Player): boolean
	local team = MatchService.teamOf(player)
	return team ~= nil and team ~= bot.team and MatchService.isPlaying(player) and not player:GetAttribute("Invisible")
end

local function hurtBot(bot: Bot, attacker: Player?, amount: number, push: Vector3)
	if not alive(bot) then
		return
	end
	if attacker then
		bot.lastHitBy = attacker
		bot.lastHitAt = os.clock()
		local head = bot.model:FindFirstChild("Head") :: BasePart?
		if head then
			Remotes.event("DamageShown"):FireClient(attacker, head.Position, math.floor(amount + 0.5))
		end
		Juice.sound(attacker, "hit")
		CombatService.Attacked:Fire(attacker)
	end
	bot.humanoid:TakeDamage(amount)
	bot.root.AssemblyLinearVelocity += push * 0.8
end

-- The closest enemy (player or bot) this bot can see: its root and either the
-- player or the bot.
local function nearestEnemy(bot: Bot): (BasePart?, Player?, Bot?)
	local position = bot.root.Position
	local bestRoot: BasePart? = nil
	local bestPlayer: Player? = nil
	local bestBot: Bot? = nil
	-- Bots can't see as far at night.
	local bestDistance = level.sight * (if workspace:GetAttribute("IsNight") then 0.6 else 1)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and isEnemyPlayer(bot, player) and math.abs(root.Position.Y - position.Y) < 14 then
			local distance = (root.Position - position).Magnitude
			if distance < bestDistance then
				bestRoot, bestPlayer, bestBot, bestDistance = root, player, nil, distance
			end
		end
	end
	for _, other in bots do
		if other ~= bot and other.team ~= bot.team and alive(other) then
			local distance = (other.root.Position - position).Magnitude
			if distance < bestDistance and math.abs(other.root.Position.Y - position.Y) < 14 then
				bestRoot, bestPlayer, bestBot, bestDistance = other.root, nil, other, distance
			end
		end
	end
	return bestRoot, bestPlayer, bestBot
end

local function swingSound(bot: Bot)
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxasset://sounds/swordslash.wav"
	sound.Volume = 0.5
	sound.RollOffMaxDistance = 60
	sound.Parent = bot.root
	sound:Play()
	Debris:AddItem(sound, 2)
end

local function swingAt(bot: Bot, targetRoot: BasePart, player: Player?, other: Bot?)
	if os.clock() - bot.lastSwing < level.cooldown then
		return
	end
	bot.lastSwing = os.clock()
	local track = bot.tracks.slash
	if track then
		track:Play(0.05)
	end
	swingSound(bot)
	local offset = flat(targetRoot.Position - bot.root.Position)
	local direction = if offset.Magnitude > 0.1 then offset.Unit else bot.root.CFrame.LookVector
	local amount = MatchData.Swords[swordTier()].damage * level.damage
	local push = direction * Config.Match.Knockback * 0.8 + Vector3.new(0, 12, 0)
	if player then
		CombatService.hurtByBot(player, amount, push, bot.name, bot.team.info.key)
	elseif other then
		hurtBot(other, nil, amount, push)
	end
end

---------------------------------------------------------------------------
-- Life and death
---------------------------------------------------------------------------

local spawnBot: (MatchService.MatchTeam, string, number) -> ()

local function onDied(bot: Bot, myRound: number)
	if bot.dead then
		return
	end
	bot.dead = true
	local killer = if bot.lastHitBy
			and os.clock() - bot.lastHitAt < 12
			and bot.lastHitBy.Parent
		then bot.lastHitBy
		else nil
	local final = MatchService.botKnockedOut(bot.team, bot.name, killer, bot.root.Position)
	byModel[bot.model] = nil
	local index = table.find(bots, bot)
	if index then
		table.remove(bots, index)
	end
	Debris:AddItem(bot.model, 2)
	if not final then
		task.delay(Config.Match.RespawnSeconds, function()
			if round == myRound and MatchService.phase() == "playing" then
				spawnBot(bot.team, bot.name, myRound)
			end
		end)
	end
end

local function makeModel(team: MatchService.MatchTeam, name: string): Model?
	local ok, model = pcall(function()
		local description = Instance.new("HumanoidDescription")
		local skin = SKIN[rng:NextInteger(1, #SKIN)]
		description.HeadColor = skin
		description.LeftArmColor = skin
		description.RightArmColor = skin
		description.TorsoColor = team.info.color
		description.LeftLegColor = team.info.color:Lerp(Color3.new(0, 0, 0), 0.5)
		description.RightLegColor = team.info.color:Lerp(Color3.new(0, 0, 0), 0.5)
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		return nil
	end
	model.Name = name
	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy() -- the server plays the animations below
	end
	return model
end

spawnBot = function(team: MatchService.MatchTeam, name: string, myRound: number)
	local model = makeModel(team, name)
	if not model or round ~= myRound or not folder or MatchService.phase() ~= "playing" then
		if model then
			model:Destroy()
		end
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	if not humanoid or not root then
		model:Destroy()
		return
	end
	humanoid.DisplayName = name
	humanoid.MaxHealth = level.health
	humanoid.Health = level.health
	humanoid.WalkSpeed = level.speed
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	humanoid.NameDisplayDistance = 80
	humanoid.BreakJointsOnDeath = false
	model:SetAttribute("BotTeam", team.info.key)
	local offset = Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
	model:PivotTo(team.spawn + offset)
	model.Parent = folder
	pcall(function()
		root:SetNetworkOwner(nil) -- the server moves bots smoothly
	end)
	local sword = ItemModels.sword(swordTier())
	sword.Parent = model
	pcall(function()
		humanoid:EquipTool(sword)
	end)

	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	local tracks: { [string]: AnimationTrack } = {}
	for key, id in ANIMATIONS do
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local ok, track = pcall(function()
			return animator:LoadAnimation(animation)
		end)
		if ok and track then
			track.Priority = if key == "slash"
				then Enum.AnimationPriority.Action
				elseif key == "hold" then Enum.AnimationPriority.Idle
				else Enum.AnimationPriority.Core
			track.Looped = key ~= "slash"
			tracks[key] = track
		end
	end
	local bot: Bot = {
		model = model,
		root = root,
		humanoid = humanoid,
		team = team,
		name = name,
		route = {},
		routeGoal = nil,
		lastPosition = root.Position,
		stuckFor = 0,
		lastSwing = 0,
		breaking = 0,
		lastHitBy = nil,
		lastHitAt = 0,
		dead = false,
		tracks = tracks,
	}
	table.insert(bots, bot)
	byModel[model] = bot
	play(bot, "idle")
	play(bot, "hold")
	humanoid.Died:Connect(function()
		onDied(bot, myRound)
	end)
end

---------------------------------------------------------------------------
-- Thinking
---------------------------------------------------------------------------

-- The nearest enemy team whose bed still stands.
local function nearestBed(bot: Bot): MatchService.MatchTeam?
	local best: MatchService.MatchTeam? = nil
	local bestDistance = math.huge
	for _, team in MatchService.teamsInMatch() do
		if team ~= bot.team and team.bedAlive then
			local distance = (team.frame.Position - bot.root.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = team, distance
			end
		end
	end
	return best
end

-- Any enemy left anywhere (once every bed is gone).
local function anyEnemy(bot: Bot): Vector3?
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and isEnemyPlayer(bot, player) then
			return root.Position
		end
	end
	for _, other in bots do
		if other.team ~= bot.team and alive(other) then
			return other.root.Position
		end
	end
	return nil
end

local function walkTo(bot: Bot, point: Vector3)
	bot.humanoid:MoveTo(point)
	stop(bot, "idle")
	play(bot, "walk")
end

local function standStill(bot: Bot)
	bot.humanoid:MoveTo(bot.root.Position)
	stop(bot, "walk")
	play(bot, "idle")
end

local function think(bot: Bot, dt: number)
	local position = bot.root.Position
	if position.Y < Config.World.VoidKillY then
		bot.humanoid.Health = 0
		return
	end
	-- Stuck against something (a wall of blocks)? Jump and hack at it.
	local moved = flat(position - bot.lastPosition).Magnitude
	bot.lastPosition = position
	local wantsToMove = bot.humanoid.MoveDirection.Magnitude > 0.1
	if wantsToMove and moved < 0.3 then
		bot.stuckFor += dt
	else
		bot.stuckFor = 0
	end
	if bot.stuckFor > 0.8 then
		bot.humanoid.Jump = true
		local ahead = position + bot.root.CFrame.LookVector * 3
		if BlockService.hitAt(ahead, 1) or BlockService.hitAt(ahead + Vector3.new(0, 3, 0), 1) then
			local track = bot.tracks.slash
			if track then
				track:Play(0.05)
			end
		end
		if bot.stuckFor > 4 then
			-- Try a slightly different way.
			bot.stuckFor = 0
			bot.route = {}
			walkTo(bot, position + Vector3.new(rng:NextNumber(-8, 8), 0, rng:NextNumber(-8, 8)))
			return
		end
	end

	-- 1. Fight anyone close enough.
	local targetRoot, player, other = nearestEnemy(bot)
	if targetRoot then
		bot.route = {}
		bot.breaking = 0
		local distance = (targetRoot.Position - position).Magnitude
		if distance > Config.Bots.Reach - 1.5 then
			walkTo(bot, targetRoot.Position)
		else
			standStill(bot)
			local look = flat(targetRoot.Position - position)
			if look.Magnitude > 0.1 then
				bot.root.CFrame = CFrame.lookAt(position, position + look.Unit)
			end
		end
		if distance <= Config.Bots.Reach then
			swingAt(bot, targetRoot, player, other)
		end
		return
	end

	-- 2. King of the Hill: most bots head for the hill.
	if workspace:GetAttribute("MatchMode") == "Hill" and bot.name:len() % 3 ~= 0 then
		local hill = Vector3.new(0, 3, 0)
		if flat(hill - position).Magnitude < 6 then
			standStill(bot)
			return
		end
		if not bot.routeGoal or (bot.routeGoal - hill).Magnitude > 1 or #bot.route == 0 then
			bot.route = routeTo(position, hill)
			bot.routeGoal = hill
		end
		local nextPoint = bot.route[1]
		while nextPoint and flat(nextPoint - position).Magnitude < 4 do
			table.remove(bot.route, 1)
			nextPoint = bot.route[1]
		end
		if nextPoint then
			walkTo(bot, nextPoint)
		end
		return
	end

	-- 3. Go break the nearest enemy bed (or hunt whoever is left).
	local bedTeam = nearestBed(bot)
	local goal = if bedTeam then (bedTeam.frame * CFrame.new(0, 0, 22)).Position else anyEnemy(bot)
	if not goal then
		standStill(bot)
		return
	end
	if bedTeam and flat(goal - position).Magnitude < 6 then
		standStill(bot)
		bot.breaking += dt
		if bot.breaking >= level.bedBreak then
			bot.breaking = 0
			MatchService.breakBedByBot(bedTeam, bot.name, bot.team.info.key)
		elseif os.clock() - bot.lastSwing > 0.6 then
			bot.lastSwing = os.clock()
			local track = bot.tracks.slash
			if track then
				track:Play(0.05)
			end
		end
		return
	end
	bot.breaking = 0
	if not bot.routeGoal or (bot.routeGoal - goal).Magnitude > 10 or #bot.route == 0 then
		bot.route = routeTo(position, goal)
		bot.routeGoal = goal
	end
	local nextPoint = bot.route[1]
	while nextPoint and flat(nextPoint - position).Magnitude < 4 do
		table.remove(bot.route, 1)
		nextPoint = bot.route[1]
	end
	if nextPoint then
		walkTo(bot, nextPoint)
	end
end

---------------------------------------------------------------------------

local function clearAll()
	round += 1
	for _, bot in bots do
		bot.dead = true
	end
	bots = {}
	byModel = {}
	if folder then
		folder:Destroy()
		folder = nil
	end
end

-- Where every living bot is, and its team (King of the Hill counts them).
function BotService.positions(): { { team: MatchService.MatchTeam, position: Vector3 } }
	local list = {}
	for _, bot in bots do
		if alive(bot) then
			table.insert(list, { team = bot.team, position = bot.root.Position })
		end
	end
	return list
end

function BotService.start()
	MatchService.botTeamsFor = function(_players: number, teams: number): number
		if not Config.Bots.Enabled or workspace:GetAttribute("MatchMode") == "Zombies" then
			return 0
		end
		return math.max(0, Config.Bots.MinTeams - teams)
	end
	CombatService.addTargets({
		enemiesOf = function(player: Player): { BasePart }
			local team = MatchService.teamOf(player)
			local list = {}
			for _, bot in bots do
				if bot.team ~= team and alive(bot) then
					table.insert(list, bot.root)
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
		hurt = function(model: Model, attacker: Player, amount: number, push: Vector3, _weapon: string)
			local bot = byModel[model]
			if bot and bot.team ~= MatchService.teamOf(attacker) then
				hurtBot(bot, attacker, amount, push)
			end
		end,
	})

	MatchService.MatchStarted:Connect(function()
		clearAll()
		local myRound = round
		matchStartedAt = os.clock()
		local difficulty = VoteService.winner("bots") or "Normal"
		level = Config.Bots.Difficulties[difficulty] or Config.Bots.Difficulties.Normal
		workspace:SetAttribute("BotDifficulty", difficulty)
		local newFolder = Instance.new("Folder")
		newFolder.Name = "Bots"
		newFolder.Parent = workspace
		folder = newFolder
		for _, team in MatchService.teamsInMatch() do
			for _ = 1, team.botTotal do
				task.spawn(spawnBot, team, nextName(), myRound)
			end
		end
	end)
	MatchService.MatchEnded:Connect(clearAll)

	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(0.2)
			local dt = os.clock() - last
			last = os.clock()
			if MatchService.phase() == "playing" then
				for _, bot in table.clone(bots) do
					if alive(bot) then
						local ok, problem = pcall(think, bot, dt)
						if not ok then
							warn("[Bottle a Storm] A bot got confused: " .. tostring(problem))
						end
					end
				end
			end
		end
	end)
end

return BotService
