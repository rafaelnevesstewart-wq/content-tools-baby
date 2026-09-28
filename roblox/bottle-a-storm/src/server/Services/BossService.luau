-- 🐉 The Storm Dragon: a boss that attacks the middle island during
-- matches (first after Config.Boss.FirstAt seconds, then every
-- Config.Boss.Every). It circles above the middle island spitting fireballs
-- at anyone standing there, then lands to stomp (that's your chance to hit it
-- with swords; bows, fireballs and TNT work any time). Beat it and everyone
-- who helped gets Sparks, and the team that did the most damage gets a pile
-- of Crystals and Cores. If nobody beats it, it flies away.
--
-- 🐍 On the 🌊 Bubble Reef map the boss is the Sea Serpent instead: a long
-- wriggling serpent that swims around the middle island spitting water
-- bubbles, then rears up and slams down a tidal wave. Same fight, same loot.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local CustomData = require(Shared.CustomData)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Signal)

local Modules = script.Parent.Parent.Modules
local Effects = require(Modules.Effects)
local Juice = require(Modules.Juice)
local Notify = require(Modules.Notify)

local BlockService = require(script.Parent.BlockService)
local CombatService = require(script.Parent.CombatService)
local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local MatchService = require(script.Parent.MatchService)

local BossService = {}

-- (helpers, damage, kind) the boss was beaten: everyone who hurt it, how
-- much each did, and "Dragon" or "Serpent".
BossService.Defeated = Signal.new()

local PURPLE = Color3.fromRGB(70, 48, 118)
local BELLY = Color3.fromRGB(150, 128, 206)
local WING = Color3.fromRGB(46, 30, 84)
local HORN = Color3.fromRGB(230, 220, 200)

-- wing: -1 left, 1 right (flaps); seg: which body segment it rides on (the
-- serpent's body wriggles, 0 is the head).
type Piece = { part: BasePart, offset: CFrame, wing: number?, seg: number? }

type Boss = {
	kind: string, -- "Dragon" | "Serpent"
	name: string,
	model: Model,
	body: BasePart,
	head: BasePart,
	pieces: { Piece },
	health: number,
	maxHealth: number,
	damage: { [Player]: number },
	pose: CFrame,
	state: string, -- "arrive" | "fly" | "land" | "leave"
	stateEndsAt: number,
	angle: number,
	nextFire: number,
	nextStomp: number,
	dead: boolean,
	label: TextLabel,
}

local boss: Boss? = nil
local round = 0

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

---------------------------------------------------------------------------
-- The model
---------------------------------------------------------------------------

local function buildDragon(): Boss
	local model = Instance.new("Model")
	model.Name = "StormDragon"
	local pieces: { Piece } = {}
	local function add(
		name: string,
		size: Vector3,
		offset: CFrame,
		color: Color3,
		material: Enum.Material,
		shape: string?,
		wing: number?
	): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.Size = size
		p.Color = color
		p.Material = material
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if shape == "ball" then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = p
		elseif shape == "wedge" then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Wedge
			mesh.Parent = p
		end
		p.Parent = model
		table.insert(pieces, { part = p, offset = offset, wing = wing })
		return p
	end
	local body = add("Body", Vector3.new(8, 7, 16), CFrame.new(), PURPLE, Enum.Material.Slate, "ball")
	add("Belly", Vector3.new(6.6, 5, 13), CFrame.new(0, -1.4, 0), BELLY, Enum.Material.SmoothPlastic, "ball")
	-- A row of spikes down the back.
	for i = -2, 2 do
		add(
			"Spike",
			Vector3.new(0.6, 1.8, 1.8),
			CFrame.new(0, 3.6 - math.abs(i) * 0.3, i * 2.6) * CFrame.Angles(0, math.rad(90), 0),
			HORN,
			Enum.Material.SmoothPlastic,
			"wedge"
		)
	end
	add(
		"Neck",
		Vector3.new(3, 3, 7),
		CFrame.new(0, 2.4, -8.6) * CFrame.Angles(math.rad(30), 0, 0),
		PURPLE,
		Enum.Material.Slate,
		"ball"
	)
	local head = add("Head", Vector3.new(4.4, 3.6, 5.4), CFrame.new(0, 4.6, -12.6), PURPLE, Enum.Material.Slate, "ball")
	add("Snout", Vector3.new(3.2, 2.2, 3.6), CFrame.new(0, 3.9, -15.6), PURPLE, Enum.Material.Slate, "ball")
	add("Jaw", Vector3.new(2.8, 1, 3.4), CFrame.new(0, 2.9, -15), BELLY, Enum.Material.SmoothPlastic, "ball")
	for _, side in { -1, 1 } do
		local eye = add(
			"Eye",
			Vector3.new(0.9, 0.9, 0.9),
			CFrame.new(side * 1.5, 5.3, -14.2),
			Color3.fromRGB(255, 220, 60),
			Enum.Material.Neon,
			"ball"
		)
		eye.CanQuery = false
		add(
			"Horn",
			Vector3.new(0.7, 1, 3.4),
			CFrame.new(side * 1.3, 6.4, -11.4) * CFrame.Angles(math.rad(35), side * math.rad(10), 0),
			HORN,
			Enum.Material.SmoothPlastic,
			"wedge"
		)
		-- Legs tucked under the body.
		for _, z in { -4, 4 } do
			add("Leg", Vector3.new(1.6, 3.4, 1.6), CFrame.new(side * 2.6, -3.6, z), PURPLE, Enum.Material.Slate, "ball")
			add(
				"Claw",
				Vector3.new(1.4, 0.6, 2),
				CFrame.new(side * 2.6, -5.2, z - 0.5),
				HORN,
				Enum.Material.SmoothPlastic
			)
		end
		-- The wings: a bone and a leathery membrane, flapped in `pose`.
		add(
			"WingBone",
			Vector3.new(15, 0.8, 0.8),
			CFrame.new(side * 7.5, 0.4, -2.8),
			PURPLE,
			Enum.Material.Slate,
			nil,
			side
		)
		add("Wing", Vector3.new(15, 0.3, 10), CFrame.new(side * 7.5, 0, 2), WING, Enum.Material.Fabric, nil, side).Transparency =
			0.05
	end
	-- The tail, getting thinner, with a spade at the tip.
	for i, size in { 3.4, 2.4, 1.6 } do
		add(
			"Tail",
			Vector3.new(size, size, 6),
			CFrame.new(0, 0.3 + i * 0.5, 6 + i * 4.6),
			PURPLE,
			Enum.Material.Slate,
			"ball"
		)
	end
	add(
		"TailTip",
		Vector3.new(0.6, 3, 3),
		CFrame.new(0, 2, 21) * CFrame.Angles(0, math.rad(90), math.rad(45)),
		HORN,
		Enum.Material.SmoothPlastic
	)

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 140, 60)
	light.Range = 22
	light.Brightness = 2
	light.Parent = head
	local breath = Instance.new("Fire")
	breath.Size = 3
	breath.Heat = 4
	breath.Color = Color3.fromRGB(255, 140, 40)
	breath.SecondaryColor = Color3.fromRGB(160, 60, 255)
	breath.Parent = head

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(260, 44)
	gui.StudsOffset = Vector3.new(0, 11, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 400
	gui.Parent = body
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 200, 255)
	label.TextStrokeTransparency = 0.2
	label.Parent = gui

	model.PrimaryPart = body
	return {
		kind = "Dragon",
		name = "🐉 Storm Dragon",
		model = model,
		body = body,
		head = head,
		pieces = pieces,
		health = 0,
		maxHealth = 0,
		damage = {},
		pose = CFrame.new(0, 160, -320),
		state = "arrive",
		stateEndsAt = 0,
		angle = 0,
		nextFire = 0,
		nextStomp = 0,
		dead = false,
		label = label,
	}
end

-- 🐍 The Sea Serpent: a big finned head and a long tail of shrinking
-- segments with fins, in teal and gold.
local SEA = Color3.fromRGB(40, 150, 150)
local SEA_BELLY = Color3.fromRGB(230, 210, 140)
local FIN = Color3.fromRGB(60, 200, 190)
local SEGMENTS = 12

local function buildSerpent(): Boss
	local model = Instance.new("Model")
	model.Name = "SeaSerpent"
	local pieces: { Piece } = {}
	local function add(
		name: string,
		size: Vector3,
		offset: CFrame,
		color: Color3,
		material: Enum.Material,
		seg: number,
		shape: string?
	): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.Size = size
		p.Color = color
		p.Material = material
		if shape then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = if shape == "ball" then Enum.MeshType.Sphere else Enum.MeshType.Wedge
			mesh.Parent = p
		end
		p.Parent = model
		table.insert(pieces, { part = p, offset = offset, seg = seg })
		return p
	end
	local head = add("Head", Vector3.new(6, 5, 9), CFrame.new(0, 0, -2), SEA, Enum.Material.Glass, 0, "ball")
	add("Jaw", Vector3.new(4.6, 1.6, 6), CFrame.new(0, -2, -3.6), SEA_BELLY, Enum.Material.SmoothPlastic, 0, "ball")
	for _, side in { -1, 1 } do
		local eye = add(
			"Eye",
			Vector3.one * 1.2,
			CFrame.new(side * 2.2, 1, -5),
			Color3.fromRGB(255, 240, 120),
			Enum.Material.Neon,
			0,
			"ball"
		)
		eye.CanQuery = false
		add(
			"Fin",
			Vector3.new(0.4, 3, 4),
			CFrame.new(side * 3.2, 1.2, 0.5) * CFrame.Angles(0, 0, side * math.rad(-40)),
			FIN,
			Enum.Material.Glass,
			0,
			"wedge"
		)
	end
	add(
		"Crest",
		Vector3.new(0.5, 3.4, 6),
		CFrame.new(0, 3.4, 0) * CFrame.Angles(0, math.pi, 0),
		Color3.fromRGB(240, 196, 70),
		Enum.Material.Foil,
		0,
		"wedge"
	)
	local body: Part = head
	for i = 1, SEGMENTS do
		local size = 5.4 - i * 0.3
		local segment = add("Segment", Vector3.new(size, size, 4.6), CFrame.new(), SEA, Enum.Material.Glass, i, "ball")
		if i == 1 then
			body = segment
		end
		add(
			"Belly",
			Vector3.new(size * 0.8, size * 0.5, 4),
			CFrame.new(0, -size * 0.3, 0),
			SEA_BELLY,
			Enum.Material.SmoothPlastic,
			i,
			"ball"
		)
		if i % 2 == 0 then
			add(
				"BackFin",
				Vector3.new(0.3, size * 0.6, 2.6),
				CFrame.new(0, size * 0.6, 0) * CFrame.Angles(0, math.pi, 0),
				FIN,
				Enum.Material.Glass,
				i,
				"wedge"
			)
		end
	end
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(120, 230, 255)
	light.Range = 24
	light.Brightness = 2
	light.Parent = head
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	bubbles.Color = ColorSequence.new(Color3.fromRGB(210, 240, 255))
	bubbles.Size = NumberSequence.new(0.5, 1)
	bubbles.Transparency = NumberSequence.new(0.2, 1)
	bubbles.Lifetime = NumberRange.new(1, 2)
	bubbles.Rate = 12
	bubbles.Speed = NumberRange.new(2, 4)
	bubbles.Parent = head
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(260, 44)
	gui.StudsOffset = Vector3.new(0, 9, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 400
	gui.Parent = head
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(180, 255, 250)
	label.TextStrokeTransparency = 0.2
	label.Parent = gui
	model.PrimaryPart = head
	return {
		kind = "Serpent",
		name = "🐍 Sea Serpent",
		model = model,
		body = body,
		head = head,
		pieces = pieces,
		health = 0,
		maxHealth = 0,
		damage = {},
		pose = CFrame.new(0, 160, -320),
		state = "arrive",
		stateEndsAt = 0,
		angle = 0,
		nextFire = 0,
		nextStomp = 0,
		dead = false,
		label = label,
	}
end

-- Puts every piece where it belongs for the boss's pose (wings flapping, the
-- serpent's body wriggling).
local function place(b: Boss, t: number)
	local flap = if b.state == "land" then math.sin(t * 2) * 0.15 else math.sin(t * 5) * 0.55
	for _, piece in b.pieces do
		if piece.seg then
			-- The serpent's segments follow the head in a wriggling line.
			local seg = piece.seg
			local sway = math.min(1, seg / 3)
			local wiggle = CFrame.new(
				math.sin(t * 3 - seg * 0.55) * 2.4 * sway,
				math.sin(t * 2 - seg * 0.5) * 0.9 * sway,
				seg * 3.8
			)
			piece.part.CFrame = b.pose * wiggle * piece.offset
		elseif piece.wing then
			local side = piece.wing
			local shoulder = CFrame.new(side * 3.6, 2.4, -1)
			local fromShoulder = shoulder:Inverse() * piece.offset
			piece.part.CFrame = b.pose * shoulder * CFrame.Angles(0, 0, side * flap) * fromShoulder
		else
			piece.part.CFrame = b.pose * piece.offset
		end
	end
end

local function publish(b: Boss?)
	if b and not b.dead then
		workspace:SetAttribute("BossHealth", math.max(0, math.floor(b.health)))
		workspace:SetAttribute("BossMax", b.maxHealth)
		workspace:SetAttribute("BossName", b.name)
		b.label.Text = b.name .. "  " .. math.max(0, math.floor(b.health)) .. " / " .. b.maxHealth
	else
		workspace:SetAttribute("BossHealth", nil)
		workspace:SetAttribute("BossMax", nil)
		workspace:SetAttribute("BossName", nil)
	end
end

---------------------------------------------------------------------------
-- Attacks
---------------------------------------------------------------------------

local function onMiddle(position: Vector3): boolean
	return Vector3.new(position.X, 0, position.Z).Magnitude < Config.World.CenterRadius + 5
		and position.Y > -20
		and position.Y < 60
end

local function hurtNear(name: string, center: Vector3, radius: number, damage: number, knock: number)
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root and MatchService.isPlaying(player) then
			local offset = root.Position - center
			if offset.Magnitude <= radius then
				local flat = offset * Vector3.new(1, 0, 1)
				local direction = if flat.Magnitude > 0.1 then flat.Unit else Vector3.xAxis
				CombatService.hurtByBot(player, damage, direction * knock + Vector3.new(0, knock * 0.6, 0), name, "")
			end
		end
	end
end

local function fireball(b: Boss, target: Vector3)
	local water = b.kind == "Serpent"
	local ball = Instance.new("Part")
	ball.Name = if water then "WaterBubble" else "DragonFireball"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * (if water then 3 else 2.4)
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.Material = if water then Enum.Material.Glass else Enum.Material.Neon
	ball.Color = if water then Color3.fromRGB(120, 210, 255) else Color3.fromRGB(255, 120, 40)
	ball.Transparency = if water then 0.3 else 0
	if not water then
		local fire = Instance.new("Fire")
		fire.Size = 4
		fire.Color = Color3.fromRGB(255, 150, 40)
		fire.SecondaryColor = Color3.fromRGB(170, 70, 255)
		fire.Parent = ball
	end
	local mouth = if water then CFrame.new(0, -1, -7) else CFrame.new(0, 3.5, -16)
	local from = (b.pose * mouth).Position
	Effects.lob(ball, from, target, 1.3, function()
		Effects.confetti(target, 20)
		local flash = Instance.new("Part")
		flash.Shape = Enum.PartType.Ball
		flash.Anchored = true
		flash.CanCollide = false
		flash.CanQuery = false
		flash.Material = Enum.Material.Neon
		flash.Color = if water then Color3.fromRGB(140, 220, 255) else Color3.fromRGB(255, 150, 60)
		flash.Size = Vector3.one * 2
		flash.CFrame = CFrame.new(target)
		flash.Parent = workspace
		TweenService:Create(flash, TweenInfo.new(0.35), { Size = Vector3.one * 14, Transparency = 1 }):Play()
		Debris:AddItem(flash, 0.4)
		BlockService.explode(target, 6, 2, { Obsidian = true })
		hurtNear(b.name, target, 7, Config.Boss.FireballDamage, 40)
	end)
end

local function stomp(b: Boss)
	local ground = Vector3.new(b.pose.Position.X, 0.5, b.pose.Position.Z)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Material = Enum.Material.Neon
	ring.Color = if b.kind == "Serpent" then Color3.fromRGB(90, 200, 255) else Color3.fromRGB(190, 140, 255)
	ring.Transparency = 0.3
	ring.Size = Vector3.new(0.4, 4, 4)
	ring.CFrame = CFrame.new(ground) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = workspace
	TweenService:Create(ring, TweenInfo.new(0.5), { Size = Vector3.new(0.4, 36, 36), Transparency = 1 }):Play()
	Debris:AddItem(ring, 0.6)
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root and (root.Position - ground).Magnitude < 60 then
			Juice.shake(player, 1)
			Juice.sound(player, "boom")
		end
	end
	hurtNear(b.name, ground, Config.Boss.StompRadius, Config.Boss.StompDamage, 70)
end

-- A player on the middle island to shoot at (or nil).
local function pickTarget(): Vector3?
	local options = {}
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if
			root
			and MatchService.isPlaying(player)
			and onMiddle(root.Position)
			and not player:GetAttribute("Invisible")
		then
			table.insert(options, root.Position)
		end
	end
	if #options == 0 then
		return nil
	end
	local target = options[math.random(1, #options)]
	return target - Vector3.new(0, 2.5, 0)
end

---------------------------------------------------------------------------
-- Winning and losing
---------------------------------------------------------------------------

local function remove(b: Boss)
	b.dead = true
	if boss == b then
		boss = nil
	end
	publish(nil)
end

local function defeated(b: Boss)
	remove(b)
	local position = b.body.Position
	Effects.confetti(position, 120)
	for _, piece in b.pieces do
		piece.part.Anchored = false
		piece.part.CanCollide = true
		piece.part.AssemblyLinearVelocity = Vector3.new(math.random(-30, 30), math.random(20, 50), math.random(-30, 30))
	end
	Debris:AddItem(b.model, 6)
	-- Who helped, and which team hit it hardest.
	local helpers: { Player } = {}
	local byTeam: { [any]: number } = {}
	for player, amount in b.damage do
		if player.Parent then
			table.insert(helpers, player)
			local team = MatchService.teamOf(player)
			if team then
				byTeam[team] = (byTeam[team] or 0) + amount
			end
		end
	end
	local bestTeam, bestAmount = nil, 0
	for team, amount in byTeam do
		if amount > bestAmount then
			bestTeam, bestAmount = team, amount
		end
	end
	for _, player in helpers do
		IncomeService.addSparks(player, Config.Boss.HelperSparks)
		Notify.player(player, "You helped beat the " .. b.name .. "! +⚡" .. Config.Boss.HelperSparks, "success")
		if b.kind == "Serpent" then
			local data = DataService.get(player)
			if data then
				data.stats.serpentsBeaten = (data.stats.serpentsBeaten or 0) + 1
			end
		end
	end
	if bestTeam then
		for _, member in bestTeam.members do
			if member.Parent and MatchService.isPlaying(member) then
				for key, amount in Config.Boss.TeamLoot do
					MatchService.addResource(member, key, amount)
				end
				Notify.player(member, "Your team did the most damage: boss loot (💎 Crystals and ⚡ Cores)!", "rare")
				Juice.sound(member, "win")
			end
		end
		Notify.all(
			"The "
				.. b.name
				.. " was defeated! "
				.. bestTeam.info.emoji
				.. " "
				.. bestTeam.info.name
				.. " did the most damage!",
			"rare"
		)
	else
		Notify.all("The " .. b.name .. " was defeated!", "rare")
	end
	BossService.Defeated:Fire(helpers, b.damage, b.kind)
end

local function hurt(b: Boss, attacker: Player, amount: number)
	if b.dead or b.state == "arrive" or b.state == "leave" then
		return
	end
	b.health -= amount
	b.damage[attacker] = (b.damage[attacker] or 0) + amount
	Remotes.event("DamageShown"):FireClient(attacker, b.head.Position, math.floor(amount + 0.5))
	Juice.sound(attacker, "hit")
	CombatService.Attacked:Fire(attacker)
	publish(b)
	if b.health <= 0 then
		defeated(b)
	end
end

---------------------------------------------------------------------------
-- Flying around
---------------------------------------------------------------------------

local function spawnBoss()
	if boss or MatchService.phase() ~= "playing" then
		return
	end
	local b = if workspace:GetAttribute("MapTheme") == "Reef" then buildSerpent() else buildDragon()
	local playing = 0
	for _, player in Players:GetPlayers() do
		if MatchService.isPlaying(player) then
			playing += 1
		end
	end
	b.maxHealth = Config.Boss.BaseHealth + Config.Boss.HealthPerPlayer * playing
	b.health = b.maxHealth
	b.state = "arrive"
	b.stateEndsAt = os.clock() + 4
	b.model.Parent = workspace
	place(b, os.clock())
	boss = b
	publish(b)
	Notify.all(
		if b.kind == "Serpent"
			then "🐍 A Sea Serpent is swimming around the middle island! Beat it for loot!"
			else "🐉 A Storm Dragon is attacking the middle island! Beat it for loot!",
		"rare"
	)
	for _, player in Players:GetPlayers() do
		Juice.sound(player, "boom")
	end
end

local function step(b: Boss, dt: number)
	local t = os.clock()
	local circle = Config.Boss.CircleRadius
	if b.state == "arrive" then
		local goal = CFrame.lookAt(
			Vector3.new(circle, Config.Boss.FlyHeight, 0),
			Vector3.new(circle, Config.Boss.FlyHeight, -10)
		)
		b.pose = b.pose:Lerp(goal, math.min(1, dt * 1.2))
		if t >= b.stateEndsAt then
			b.state = "fly"
			b.stateEndsAt = t + Config.Boss.FlySeconds
			b.angle = 0
		end
	elseif b.state == "fly" then
		b.angle += dt * 0.35
		local position = Vector3.new(
			math.cos(b.angle) * circle,
			Config.Boss.FlyHeight + math.sin(t * 1.3) * 3,
			math.sin(b.angle) * circle
		)
		local ahead = Vector3.new(math.cos(b.angle + 0.1) * circle, position.Y, math.sin(b.angle + 0.1) * circle)
		local goal = CFrame.lookAt(position, ahead) * CFrame.Angles(0, 0, math.rad(-15)) -- banking
		b.pose = b.pose:Lerp(goal, math.min(1, dt * 3))
		if t >= b.nextFire then
			b.nextFire = t + Config.Boss.FireEvery
			local target = pickTarget()
			if target then
				fireball(b, target)
			end
		end
		if t >= b.stateEndsAt then
			b.state = "land"
			b.stateEndsAt = t + Config.Boss.LandSeconds
			b.nextStomp = t + 2.5
		end
	elseif b.state == "land" then
		-- (The serpent rears up high over the middle.)
		local height = if b.kind == "Serpent" then 9 else 6.5
		local goal = CFrame.lookAt(Vector3.new(0, height, 0), Vector3.new(0, height, -10))
		b.pose = b.pose:Lerp(goal, math.min(1, dt * 1.5))
		if t >= b.nextStomp and (b.pose.Position - goal.Position).Magnitude < 2 then
			b.nextStomp = t + Config.Boss.StompEvery
			stomp(b)
		end
		if t >= b.stateEndsAt then
			b.state = "fly"
			b.stateEndsAt = t + Config.Boss.FlySeconds
		end
	elseif b.state == "leave" then
		b.pose = b.pose:Lerp(CFrame.new(0, 220, -600), math.min(1, dt * 0.6))
		if t >= b.stateEndsAt then
			remove(b)
			b.model:Destroy()
			return
		end
	end
	place(b, t)
end

function BossService.start()
	if not Config.Boss.Enabled then
		return
	end
	CombatService.addTargets({
		enemiesOf = function(player: Player): { BasePart }
			local b = boss
			if b and not b.dead and MatchService.isPlaying(player) then
				return { b.body, b.head }
			end
			return {}
		end,
		botOf = function(part: Instance): Model?
			local b = boss
			if b and not b.dead and part:IsDescendantOf(b.model) then
				return b.model
			end
			return nil
		end,
		hurt = function(model: Model, attacker: Player, amount: number)
			local b = boss
			if b and model == b.model and MatchService.isPlaying(attacker) then
				hurt(b, attacker, amount)
			end
		end,
	})

	MatchService.MatchStarted:Connect(function()
		round += 1
		local myRound = round
		local mode = workspace:GetAttribute("MatchMode")
		if mode == "Zombies" or mode == "Castle" or CustomData.get("boss") == "Off" then
			return -- the monsters are enough trouble (or the private server turned it off)
		end
		task.spawn(function()
			task.wait(Config.Boss.FirstAt)
			while round == myRound and MatchService.phase() == "playing" do
				spawnBoss()
				local b = boss
				local started = os.clock()
				-- It gives up after a while.
				while b and not b.dead and round == myRound and os.clock() - started < Config.Boss.StaySeconds do
					task.wait(1)
				end
				if b and not b.dead and round == myRound then
					b.state = "leave"
					b.stateEndsAt = os.clock() + 5
					Notify.all(
						if b.kind == "Serpent"
							then "🐍 The Sea Serpent swam away... it'll be back!"
							else "🐉 The Storm Dragon flew away... it'll be back!",
						"info"
					)
				end
				task.wait(Config.Boss.Every)
			end
		end)
	end)
	MatchService.MatchEnded:Connect(function()
		round += 1
		local b = boss
		if b then
			remove(b)
			b.model:Destroy()
		end
	end)

	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(1 / 30)
			local dt = os.clock() - last
			last = os.clock()
			local b = boss
			if b and not b.dead then
				local ok, problem = pcall(step, b, dt)
				if not ok then
					warn("[Bottle a Storm] The dragon tripped: " .. tostring(problem))
				end
			end
		end
	end)
end

return BossService
