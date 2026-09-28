-- Bed Wars rounds. Players wait in the lobby (the middle island). When enough
-- are here, a match starts: teams are made (solos with few players, teams of
-- 2 when fuller), each team gets an island with a cloud bed, a resource
-- generator and an item shop. While your bed stands you respawn; once it's
-- broken, your next death knocks you out. The last team standing wins, then
-- everyone goes back to the lobby for the next match.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Teams = game:GetService("Teams")
local HttpService = game:GetService("HttpService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local MatchData = require(Shared.MatchData)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Signal)

local Modules = script.Parent.Parent.Modules
local Effects = require(Modules.Effects)
local Juice = require(Modules.Juice)
local Notify = require(Modules.Notify)
local WorldBuilder = require(Modules.WorldBuilder)

local CosmeticService = require(script.Parent.CosmeticService)
local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local MapService = require(script.Parent.MapService)
local PartyService = require(script.Parent.PartyService)
local SeasonService = require(script.Parent.SeasonService)
local WeatherService = require(script.Parent.WeatherService)

local MatchService = {}

-- (player, team) each time a player (re)spawns in a match: gear them up.
MatchService.PlayerSpawned = Signal.new()
-- () when a match starts / ends (cleanup).
MatchService.MatchStarted = Signal.new()
MatchService.MatchEnded = Signal.new()
-- (killer, victim, final)
MatchService.Killed = Signal.new()
-- (killer, final) when a player knocks out a bot
MatchService.BotKilled = Signal.new()
-- (breaker, team)
MatchService.BedBroken = Signal.new()
-- (player) for everyone on the winning team, and everyone who played.
MatchService.Won = Signal.new()
MatchService.Played = Signal.new()
-- (player, resourceKey, amount) when someone picks up from a generator.
MatchService.Collected = Signal.new()

export type Stock = { [string]: number }
export type Generator = {
	pad: BasePart,
	label: TextLabel,
	stock: Stock,
	timers: Stock,
	kinds: { [string]: { every: number, cap: number } },
	team: any?,
}
export type MatchTeam = {
	info: MatchData.TeamInfo,
	members: { Player },
	alive: { [Player]: boolean },
	bedAlive: boolean,
	frame: CFrame,
	spawn: CFrame,
	bed: Model?,
	generator: Generator?,
	upgrades: { [string]: number },
	roblox: Team,
	folder: Folder,
	botTotal: number, -- bots on this team (BotService runs them)
	botsIn: number, -- bots not knocked out for good yet
}

local islands: { WorldBuilder.PlotInfo } = {}
local teams: { MatchTeam } = {}
local teamByPlayer: { [Player]: MatchTeam } = {}
local eliminated: { [Player]: boolean } = {}
local lastHit: { [Player]: { by: Player, at: number } } = {}
local middleGenerators: { Generator } = {}
local phase = "waiting"
local phaseEndsAt = 0
local startedAt = 0
local startedTeams = 0
local suddenDeath = false
local matchFolder: Folder
local spectatorSpot: CFrame
local lobbySpot: CFrame

local function now(): number
	return workspace:GetServerTimeNow()
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

---------------------------------------------------------------------------
-- State for the HUD
---------------------------------------------------------------------------

local function aliveCount(team: MatchTeam): number
	local count = team.botsIn or 0
	for player in team.alive do
		if player.Parent then
			count += 1
		end
	end
	return count
end

local function publish()
	workspace:SetAttribute("MatchPhase", phase)
	workspace:SetAttribute("MatchTimer", phaseEndsAt)
	workspace:SetAttribute("MatchStartedAt", startedAt)
	local list = {}
	for _, team in teams do
		table.insert(list, {
			key = team.info.key,
			bed = team.bedAlive,
			alive = aliveCount(team),
			total = #team.members + (team.botTotal or 0),
		})
	end
	workspace:SetAttribute("MatchTeams", HttpService:JSONEncode(list))
end

---------------------------------------------------------------------------
-- Public helpers
---------------------------------------------------------------------------

function MatchService.phase(): string
	return phase
end

-- How many teams the current (or last) match started with.
function MatchService.teamCount(): number
	return startedTeams
end

-- Places nobody may dig or drop things on: beds, generators, shops and
-- spawn pads.
function MatchService.protectedSpots(): { Vector3 }
	local spots = {}
	for _, team in teams do
		table.insert(spots, team.spawn.Position - Vector3.new(0, 4, 0))
		table.insert(spots, (team.frame * CFrame.new(0, 0, 22)).Position) -- bed
		table.insert(spots, (team.frame * CFrame.new(-14, 0, -12)).Position) -- shop
		if team.generator then
			table.insert(spots, team.generator.pad.Position)
		end
	end
	for _, generator in middleGenerators do
		table.insert(spots, generator.pad.Position)
	end
	return spots
end

-- Called (in order, before the map theme is undone) when a match is over.
MatchService.beforeReset = {} :: { () -> () }

-- The island top-center frames of the teams in this match (-Z faces the
-- middle island).
function MatchService.teamFrames(): { CFrame }
	local frames = {}
	for _, team in teams do
		table.insert(frames, team.frame)
	end
	return frames
end

function MatchService.teamOf(player: Player): MatchTeam?
	return teamByPlayer[player]
end

-- In the match and not knocked out.
function MatchService.isPlaying(player: Player): boolean
	return phase == "playing" and teamByPlayer[player] ~= nil and not eliminated[player]
end

function MatchService.isEnemy(a: Player, b: Player): boolean
	local ta, tb = teamByPlayer[a], teamByPlayer[b]
	return ta ~= nil and tb ~= nil and ta ~= tb
end

function MatchService.recordHit(victim: Player, attacker: Player)
	lastHit[victim] = { by = attacker, at = os.clock() }
end

function MatchService.upgradeLevel(player: Player, key: string): number
	local team = teamByPlayer[player]
	return if team then team.upgrades[key] or 0 else 0
end

-- Resources you carry (player attributes "Res_Copper" etc.).
function MatchService.resource(player: Player, key: string): number
	local value = player:GetAttribute("Res_" .. key)
	return if type(value) == "number" then value else 0
end

function MatchService.addResource(player: Player, key: string, amount: number)
	player:SetAttribute("Res_" .. key, MatchService.resource(player, key) + amount)
end

function MatchService.spend(player: Player, key: string, amount: number): boolean
	local have = MatchService.resource(player, key)
	if have < amount then
		return false
	end
	player:SetAttribute("Res_" .. key, have - amount)
	return true
end

local function clearResources(player: Player)
	for _, resource in MatchData.Resources do
		player:SetAttribute("Res_" .. resource.key, nil)
	end
end

---------------------------------------------------------------------------
-- Rewards
---------------------------------------------------------------------------

local function reward(player: Player, kind: string)
	local data = DataService.get(player)
	local prize = MatchData.Rewards[kind]
	if not data or not prize or not player.Parent then
		return
	end
	local sparks = math.floor(prize.sparks * IncomeService.multiplier(player))
	IncomeService.addSparks(player, sparks)
	SeasonService.addXp(player, prize.stars)
	local root = rootOf(player)
	if root then
		Juice.float(player, "+⚡" .. Format.number(sparks), root.Position + Vector3.new(0, 4, 0))
	end
end

local function addStat(player: Player, key: string)
	local data = DataService.get(player)
	if data then
		data.stats[key] = (data.stats[key] or 0) + 1
		IncomeService.sync(player) -- the Wins / Kills leaderboard columns
	end
end

---------------------------------------------------------------------------
-- Building team bases
---------------------------------------------------------------------------

local function part(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

local function billboard(parent: BasePart, offset: number, text: string): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(240, 60)
	gui.StudsOffset = Vector3.new(0, offset, 0)
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	gui.AlwaysOnTop = true
	gui.Parent = parent
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = gui
	return label
end

-- Marks a part so blocks can't be placed inside it (see BlockService).
local function noBuild(p: BasePart)
	CollectionService:AddTag(p, "NoBuild")
end

local function breakBed(team: MatchTeam, breaker: Player?, bot: { name: string, teamKey: string }?)
	if not team.bedAlive or phase ~= "playing" then
		return
	end
	team.bedAlive = false
	local bed = team.bed
	if bed then
		Effects.confetti(bed:GetPivot().Position, 60)
		Effects.splash(bed:GetPivot().Position, Color3.new(1, 1, 1))
		bed:Destroy()
		team.bed = nil
	end
	if breaker then
		Notify.all(
			"🛏️ "
				.. team.info.emoji
				.. " "
				.. team.info.name
				.. "'s cloud bed was destroyed by "
				.. breaker.DisplayName
				.. "!",
			"rare"
		)
		Remotes.event("KillFeed"):FireAllClients({
			killer = breaker.DisplayName,
			killerTeam = breaker:GetAttribute("TeamKey"),
			bed = team.info.key,
		})
		reward(breaker, "Bed")
		addStat(breaker, "bedsBroken")
		for _, other in Players:GetPlayers() do
			Juice.sound(other, "bedBreak")
		end
		MatchService.BedBroken:Fire(breaker, team)
	elseif bot then
		Notify.all(
			"🛏️ "
				.. team.info.emoji
				.. " "
				.. team.info.name
				.. "'s cloud bed was destroyed by "
				.. bot.name
				.. "!",
			"rare"
		)
		Remotes.event("KillFeed"):FireAllClients({ killer = bot.name, killerTeam = bot.teamKey, bed = team.info.key })
		for _, other in Players:GetPlayers() do
			Juice.sound(other, "bedBreak")
		end
	else
		Notify.all("🛏️ " .. team.info.emoji .. " " .. team.info.name .. "'s cloud bed broke!", "warn")
	end
	for _, member in team.members do
		if member.Parent then
			Notify.player(member, "💔 Your cloud bed is gone! If you die now, you're out.", "warn")
			Juice.shake(member, 1)
			Juice.sound(member, "oops")
		end
	end
	publish()
end

local function cloudBed(team: MatchTeam): Model
	local bed = Instance.new("Model")
	bed.Name = "CloudBed"
	local frame = team.frame * CFrame.new(0, 0, 22)
	-- A wooden bed: legs, side rails, slats, a paneled headboard and a
	-- footboard. Nothing here blocks the "Break the bed" prompt; only placed
	-- blocks do.
	local wood = Color3.fromRGB(112, 80, 54)
	local darkWood = Color3.fromRGB(84, 58, 40)
	local function board(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?)
		return part(bed, {
			Name = name,
			CanQuery = false,
			Size = size,
			CFrame = frame * offset,
			Color = color,
			Material = material or Enum.Material.Wood,
		})
	end
	for _, x in { -2.8, 2.8 } do
		for _, z in { -4.3, 4.3 } do
			local tall = z > 0
			board(
				"Post",
				Vector3.new(0.6, if tall then 4.4 else 2.2, 0.6),
				CFrame.new(x, if tall then 2.2 else 1.1, z),
				darkWood
			)
			board("Knob", Vector3.new(0.7, 0.3, 0.7), CFrame.new(x, if tall then 4.55 else 2.35, z), darkWood)
		end
		board("Rail", Vector3.new(0.35, 0.7, 8.6), CFrame.new(x, 1.15, 0), wood)
	end
	board("Slats", Vector3.new(5.4, 0.25, 8.4), CFrame.new(0, 1, 0), wood, Enum.Material.WoodPlanks)
	board("Headboard", Vector3.new(5.2, 2.6, 0.3), CFrame.new(0, 2.6, 4.3), wood, Enum.Material.WoodPlanks)
	board("HeadRail", Vector3.new(5.8, 0.35, 0.45), CFrame.new(0, 4, 4.3), darkWood)
	board("Footboard", Vector3.new(5.2, 1, 0.3), CFrame.new(0, 1.7, -4.3), wood, Enum.Material.WoodPlanks)
	-- A blanket in the team's color hanging over the sides; the cloud
	-- mattress is added by CosmeticService.dressBed once the team is known.
	local blanket = team.info.color:Lerp(Color3.new(0, 0, 0), 0.08)
	board("Blanket", Vector3.new(6, 0.3, 5.4), CFrame.new(0, 3.25, -1.3), blanket, Enum.Material.Fabric).CanCollide =
		false
	for _, x in { -3.05, 3.05 } do
		board("BlanketSide", Vector3.new(0.2, 1.6, 5.4), CFrame.new(x, 2.5, -1.3), blanket, Enum.Material.Fabric).CanCollide =
			false
	end
	board(
		"BlanketFold",
		Vector3.new(6.05, 0.35, 0.8),
		CFrame.new(0, 3.35, 1.35),
		Color3.fromRGB(245, 242, 235),
		Enum.Material.Fabric
	).CanCollide =
		false
	local pillow = board(
		"Pillow",
		Vector3.new(3.4, 0.9, 1.6),
		CFrame.new(0, 3.1, 3.1),
		Color3.fromRGB(250, 248, 242),
		Enum.Material.Fabric
	)
	pillow.CanCollide = false
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = pillow
	local hitbox = part(bed, {
		Name = "BedHitbox",
		Size = Vector3.new(6.5, 4, 9.5),
		CFrame = frame * CFrame.new(0, 2, 0),
		Transparency = 1,
		CanCollide = false,
	})
	noBuild(hitbox)
	local light = Instance.new("PointLight")
	light.Color = team.info.color
	light.Range = 12
	light.Brightness = 1
	light.Parent = hitbox
	billboard(hitbox, 4, team.info.emoji .. " " .. team.info.name .. "'s Cloud Bed")
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BedPrompt"
	prompt.ActionText = "Break the bed"
	prompt.ObjectText = team.info.name .. "'s Cloud Bed"
	prompt.HoldDuration = Config.Match.BedBreakSeconds
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = true -- blocks around the bed protect it
	prompt:SetAttribute("Team", team.info.key)
	prompt.Parent = hitbox
	prompt.Triggered:Connect(function(player)
		if MatchService.isPlaying(player) and teamByPlayer[player] ~= team then
			breakBed(team, player)
		end
	end)
	bed.PrimaryPart = hitbox
	bed.Parent = team.folder
	return bed
end

local function makeGenerator(
	parent: Instance,
	at: CFrame,
	color: Color3,
	kinds: { [string]: { every: number, cap: number } },
	team: MatchTeam?
): Generator
	-- Nothing may cover a generator: clear any rock or ground bump above
	-- the island's surface around it, so you can always stand on the pad.
	pcall(function()
		workspace.Terrain:FillBlock(at * CFrame.new(0, 6, 0), Vector3.new(14, 12, 14), Enum.Material.Air)
	end)
	-- A stone pedestal with an iron rim, four little pillars with glowing
	-- orbs, and a glowing plate you stand on to pick things up.
	local base = part(parent, {
		Name = "GeneratorBase",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.8, 8, 8),
		CFrame = at * CFrame.new(0, 0.4, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(120, 118, 114),
		Material = Enum.Material.Cobblestone,
	})
	noBuild(base)
	part(parent, {
		Name = "GeneratorRim",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 8.5, 8.5),
		CFrame = at * CFrame.new(0, 0.7, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(70, 72, 78),
		Material = Enum.Material.Metal,
	})
	for i = 0, 3 do
		local corner = at * CFrame.Angles(0, i * math.pi / 2 + math.pi / 4, 0) * CFrame.new(0, 0, 3.6)
		part(parent, {
			Name = "GeneratorPillar",
			Size = Vector3.new(0.5, 1.6, 0.5),
			CFrame = corner * CFrame.new(0, 1.6, 0),
			Color = Color3.fromRGB(95, 94, 92),
			Material = Enum.Material.Slate,
		})
		local orb = part(parent, {
			Name = "GeneratorOrb",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.6,
			CFrame = corner * CFrame.new(0, 2.7, 0),
			Color = color,
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 6
		light.Brightness = 0.8
		light.Parent = orb
	end
	local pad = part(parent, {
		Name = "Generator",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.1, 6.2, 6.2),
		CFrame = at * CFrame.new(0, 0.85, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.25,
		CanCollide = false,
	})
	noBuild(pad)
	local generator: Generator = {
		pad = pad,
		label = billboard(pad, 3.5, ""),
		stock = {},
		timers = {},
		kinds = kinds,
		team = team,
	}
	for key in kinds do
		generator.stock[key] = 0
		generator.timers[key] = 0
	end
	return generator
end

local function generatorText(generator: Generator): string
	local parts = {}
	for _, resource in MatchData.Resources do
		if generator.kinds[resource.key] then
			table.insert(parts, resource.emoji .. " " .. generator.stock[resource.key])
		end
	end
	return table.concat(parts, "   ")
end

-- A market stall: a planked counter, posts, a striped awning in the team's
-- colors, crates and a barrel, and a shopkeeper behind the counter.
local function shopStand(team: MatchTeam)
	local at = team.frame * CFrame.new(-14, 0, -12)
	local wood = Color3.fromRGB(110, 78, 52)
	local stand = part(team.folder, {
		Name = "ItemShop",
		Size = Vector3.new(6, 3, 2.2),
		CFrame = at * CFrame.new(0, 1.5, -1),
		Color = wood,
		Material = Enum.Material.WoodPlanks,
	})
	noBuild(stand)
	part(team.folder, {
		Name = "CounterTop",
		Size = Vector3.new(6.4, 0.3, 2.6),
		CFrame = at * CFrame.new(0, 3.15, -1),
		Color = Color3.fromRGB(86, 60, 40),
		Material = Enum.Material.Wood,
	})
	part(team.folder, {
		Name = "BackWall",
		Size = Vector3.new(6, 5, 0.3),
		CFrame = at * CFrame.new(0, 2.5, 2.4),
		Color = wood,
		Material = Enum.Material.WoodPlanks,
	})
	for _, y in { 2.2, 3.6 } do
		part(team.folder, {
			Name = "Shelf",
			Size = Vector3.new(5.6, 0.2, 0.8),
			CFrame = at * CFrame.new(0, y, 2),
			Color = Color3.fromRGB(86, 60, 40),
			Material = Enum.Material.Wood,
		})
	end
	for _, x in { -3, 3 } do
		for _, z in { -2.2, 2.4 } do
			part(team.folder, {
				Name = "Post",
				Size = Vector3.new(0.45, 6.6, 0.45),
				CFrame = at * CFrame.new(x, 3.3, z),
				Color = Color3.fromRGB(80, 56, 38),
				Material = Enum.Material.Wood,
			})
		end
	end
	-- The striped awning, sloping down toward the front.
	for i = 0, 6 do
		part(team.folder, {
			Name = "Awning",
			Size = Vector3.new(1, 0.15, 5.6),
			CFrame = at * CFrame.new(-3 + i, 6.8, 0.1) * CFrame.Angles(math.rad(-12), 0, 0),
			Color = if i % 2 == 0 then team.info.color else Color3.fromRGB(245, 242, 235),
			Material = Enum.Material.Fabric,
			CanCollide = false,
		})
	end
	-- Crates and a barrel beside the stall.
	for index, offset in { Vector3.new(-4.4, 0.8, -0.6), Vector3.new(-4.2, 0.8, 1.2), Vector3.new(-4.3, 2.4, 0.3) } do
		part(team.folder, {
			Name = "Crate",
			Size = Vector3.one * 1.6,
			CFrame = at * CFrame.new(offset) * CFrame.Angles(0, math.rad(index * 11), 0),
			Color = Color3.fromRGB(150, 112, 70),
			Material = Enum.Material.WoodPlanks,
		})
	end
	part(team.folder, {
		Name = "Barrel",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2.2, 1.7, 1.7),
		CFrame = at * CFrame.new(4.3, 1.1, -0.4) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(120, 84, 52),
		Material = Enum.Material.Wood,
	})
	-- Goods on the counter: glowing potion bottles and apples.
	for index, color in { Color3.fromRGB(120, 220, 255), Color3.fromRGB(140, 240, 120), Color3.fromRGB(200, 170, 255) } do
		local bottle = part(team.folder, {
			Name = "Bottle",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.7,
			CFrame = at * CFrame.new(-2 + index * 0.9, 3.65, -1.3),
			Color = color,
			Material = Enum.Material.Glass,
			Transparency = 0.2,
			CanCollide = false,
		})
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 4
		light.Brightness = 0.6
		light.Parent = bottle
	end
	billboard(stand, 6.5, "🛒 Item Shop")
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ItemShopPrompt"
	prompt.ActionText = "Open the Item Shop"
	prompt.ObjectText = "🛒 Swords, armor, blocks"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = stand
	-- The shopkeeper (a plain Roblox avatar) stands behind the counter.
	local folder = team.folder
	task.spawn(function()
		local ok, keeper = pcall(function()
			local description = Instance.new("HumanoidDescription")
			description.HeadColor = Color3.fromRGB(234, 184, 146)
			description.TorsoColor = team.info.color
			description.LeftArmColor = Color3.fromRGB(234, 184, 146)
			description.RightArmColor = Color3.fromRGB(234, 184, 146)
			description.LeftLegColor = Color3.fromRGB(70, 60, 55)
			description.RightLegColor = Color3.fromRGB(70, 60, 55)
			return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
		end)
		if not ok or not keeper or not folder.Parent then
			return
		end
		keeper.Name = "Shopkeeper"
		for _, p in keeper:GetDescendants() do
			if p:IsA("BasePart") then
				p.Anchored = p.Name == "HumanoidRootPart"
				p.CanCollide = false
			end
		end
		local humanoid = keeper:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.DisplayName = "Shopkeeper"
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
		keeper:PivotTo(at * CFrame.new(0, 3, 1.1)) -- facing the customers
		keeper.Parent = folder
	end)
end

local function setUpTeam(info: MatchData.TeamInfo, island: WorldBuilder.PlotInfo): MatchTeam
	local folder = Instance.new("Folder")
	folder.Name = "Team_" .. info.key
	folder.Parent = matchFolder
	local robloxTeam = Instance.new("Team")
	robloxTeam.Name = info.name
	robloxTeam.TeamColor = BrickColor.new(info.brick :: any)
	robloxTeam.AutoAssignable = false
	robloxTeam.Parent = Teams
	local team: MatchTeam = {
		info = info,
		members = {},
		alive = {},
		bedAlive = true,
		frame = island.cframe,
		spawn = island.cframe * CFrame.new(0, 4, -22) * CFrame.Angles(0, math.pi, 0),
		bed = nil,
		generator = nil,
		upgrades = {},
		roblox = robloxTeam,
		folder = folder,
		botTotal = 0,
		botsIn = 0,
	}
	team.bed = cloudBed(team)
	team.generator = makeGenerator(folder, island.cframe * CFrame.new(0, 0, -4), info.color, {
		Copper = Config.Match.Generator.Copper,
		Silver = Config.Match.Generator.Silver,
	}, team)
	shopStand(team)
	local spawnPad = part(folder, {
		Name = "SpawnPad",
		Size = Vector3.new(6, 0.3, 6),
		CFrame = island.cframe * CFrame.new(0, 0.15, -22),
		Color = info.color,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	})
	noBuild(spawnPad)
	return team
end

local function buildMiddle()
	middleGenerators = {}
	local function ring(count: number, radius: number, offset: number, color: Color3, kinds)
		for i = 1, count do
			local angle = (i - 1) / count * math.pi * 2 + offset
			local at = CFrame.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
			table.insert(middleGenerators, makeGenerator(matchFolder, at, color, kinds, nil))
		end
	end
	ring(Config.Match.Crystals.count, Config.Match.Crystals.radius, math.pi / 4, Color3.fromRGB(90, 220, 240), {
		Crystals = Config.Match.Crystals,
	})
	ring(Config.Match.Cores.count, Config.Match.Cores.radius, 0, Color3.fromRGB(255, 225, 80), {
		Cores = Config.Match.Cores,
	})
end

---------------------------------------------------------------------------
-- Generators
---------------------------------------------------------------------------

local function tierMultiplier(): number
	local elapsed = now() - startedAt
	local tiers = Config.Match.TierUpAt
	if elapsed >= tiers[2] then
		return 2
	elseif elapsed >= tiers[1] then
		return 1.5
	end
	return 1
end

local function runGenerator(generator: Generator, dt: number, speed: number)
	for key, kind in generator.kinds do
		generator.timers[key] += dt * speed
		while generator.timers[key] >= kind.every do
			generator.timers[key] -= kind.every
			generator.stock[key] = math.min(kind.cap, generator.stock[key] + 1)
		end
	end
	-- Whoever stands on the pad picks everything up.
	local total = 0
	for _, amount in generator.stock do
		total += amount
	end
	if total > 0 then
		for _, player in Players:GetPlayers() do
			local root = rootOf(player)
			local offset = root and (root.Position - generator.pad.Position)
			-- Anywhere on or right next to the pad counts (even on a block over it).
			if
				root
				and offset
				and MatchService.isPlaying(player)
				and (offset * Vector3.new(1, 0, 1)).Magnitude < 6
				and math.abs(offset.Y) < 8
			then
				for key, amount in generator.stock do
					if amount > 0 then
						MatchService.addResource(player, key, amount)
						MatchService.Collected:Fire(player, key, amount)
						generator.stock[key] = 0
					end
				end
				Juice.sound(player, "coins")
				break
			end
		end
	end
	generator.label.Text = generatorText(generator)
end

---------------------------------------------------------------------------
-- Spawning, deaths and winning
---------------------------------------------------------------------------

-- Moves a character safely: it's held still while the area around the
-- destination loads on the player's screen, so nobody drops through ground
-- that hasn't appeared yet.
local function teleport(player: Player, character: Model, target: CFrame)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.Anchored = true
	end
	character:PivotTo(target)
	task.spawn(function()
		pcall(function()
			player:RequestStreamAroundAsync(target.Position, 5)
		end)
		task.wait(0.4)
		if root and root.Parent then
			root.Anchored = false
			root.AssemblyLinearVelocity = Vector3.zero
		end
	end)
end

local function spawnInto(player: Player, character: Model)
	local team = teamByPlayer[player]
	if phase == "playing" and team and not eliminated[player] then
		teleport(player, character, team.spawn)
		local shield = Instance.new("ForceField")
		shield.Visible = true
		shield.Parent = character
		task.delay(Config.Match.SpawnProtection, function()
			shield:Destroy()
		end)
		MatchService.PlayerSpawned:Fire(player, team)
	elseif phase == "playing" and team and eliminated[player] then
		teleport(player, character, spectatorSpot)
	else
		teleport(player, character, lobbySpot)
	end
end

local endMatch: (MatchTeam?) -> ()

local function checkWin()
	if phase ~= "playing" then
		return
	end
	local standing = {}
	for _, team in teams do
		if aliveCount(team) > 0 then
			table.insert(standing, team)
		end
	end
	if startedTeams >= 2 and #standing <= 1 then
		endMatch(standing[1])
	elseif #standing == 0 then
		endMatch(nil)
	end
end

---------------------------------------------------------------------------
-- Bots (BotService runs them; the match keeps score here)
---------------------------------------------------------------------------

local lastBotHit: { [Player]: { name: string, teamKey: string, at: number } } = {}

function MatchService.teamsInMatch(): { MatchTeam }
	return teams
end

-- A bot hit this player (so a knockout soon after is the bot's).
function MatchService.recordBotHit(victim: Player, name: string, teamKey: string)
	lastBotHit[victim] = { name = name, teamKey = teamKey, at = os.clock() }
	lastHit[victim] = nil
end

-- A bot breaks a team's bed.
function MatchService.breakBedByBot(team: MatchTeam, name: string, teamKey: string)
	breakBed(team, nil, { name = name, teamKey = teamKey })
end

-- A bot was knocked out (by `killer`, a player, if any). Returns whether it's
-- out for good (its bed is gone).
function MatchService.botKnockedOut(team: MatchTeam, name: string, killer: Player?, position: Vector3?): boolean
	if phase ~= "playing" then
		return true
	end
	local final = not team.bedAlive
	if final then
		team.botsIn = math.max(0, team.botsIn - 1)
	end
	if killer and position then
		CosmeticService.knockout(killer, position)
	end
	Remotes.event("KillFeed"):FireAllClients({
		killer = if killer then killer.DisplayName else nil,
		killerTeam = if killer then killer:GetAttribute("TeamKey") else nil,
		victim = name,
		victimTeam = team.info.key,
		final = final,
		weapon = "Sword",
	})
	if killer then
		MatchService.BotKilled:Fire(killer, final)
		Juice.sound(killer, "kill")
		reward(killer, if final then "FinalKill" else "Kill")
		addStat(killer, "kills")
		if final then
			addStat(killer, "finalKills")
		end
	end
	publish()
	checkWin()
	return final
end

-- Set by CombatService: what last hurt a player (for the kill feed).
MatchService.weaponOf = function(_victim: Player): string?
	return nil
end

local function onDied(player: Player)
	if not MatchService.isPlaying(player) then
		return
	end
	addStat(player, "deaths")
	local team = teamByPlayer[player] :: MatchTeam
	local hit = lastHit[player]
	local killer = if hit and os.clock() - hit.at < 12 and hit.by.Parent then hit.by else nil
	lastHit[player] = nil
	local botHit = lastBotHit[player]
	lastBotHit[player] = nil
	local botKiller = if not killer and botHit and os.clock() - botHit.at < 12 then botHit else nil
	local final = not team.bedAlive
	local root = rootOf(player)
	if killer and root then
		CosmeticService.knockout(killer, root.Position)
	end
	if final then
		eliminated[player] = true
		team.alive[player] = nil
		player:SetAttribute("Spectating", true)
	end
	clearResources(player)
	Remotes.event("KillFeed"):FireAllClients({
		killer = if killer then killer.DisplayName elseif botKiller then botKiller.name else nil,
		killerTeam = if killer then killer:GetAttribute("TeamKey") elseif botKiller then botKiller.teamKey else nil,
		victim = player.DisplayName,
		victimTeam = team.info.key,
		final = final,
		weapon = if killer then MatchService.weaponOf(player) else nil,
	})
	Juice.sound(player, "oof")
	if killer then
		Juice.sound(killer, "kill")
		reward(killer, if final then "FinalKill" else "Kill")
		addStat(killer, "kills")
		if final then
			addStat(killer, "finalKills")
		end
		MatchService.Killed:Fire(killer, player, final)
	end
	if final then
		Notify.player(player, "💀 You're out! Watch the rest of the match from the sky box.", "warn")
	end
	publish()
	checkWin()
end

local function resetToLobby()
	-- Services put the ground back (dug holes) before the map theme is undone.
	for _, cleanup in MatchService.beforeReset do
		local ok, problem = pcall(cleanup)
		if not ok then
			warn("[Bottle a Storm] Cleanup failed: " .. tostring(problem))
		end
	end
	MatchService.MatchEnded:Fire()
	pcall(MapService.reset)
	for _, team in teams do
		team.folder:Destroy()
		team.roblox:Destroy()
	end
	for _, generator in middleGenerators do
		generator.pad:Destroy()
	end
	middleGenerators = {}
	teams = {}
	teamByPlayer = {}
	eliminated = {}
	lastHit = {}
	lastBotHit = {}
	suddenDeath = false
	phase = "waiting"
	phaseEndsAt = 0
	startedAt = 0
	for _, player in Players:GetPlayers() do
		player.Team = nil
		player.Neutral = true
		player:SetAttribute("TeamKey", nil)
		player:SetAttribute("InMatch", nil)
		player:SetAttribute("Spectating", nil)
		clearResources(player)
		task.spawn(function()
			player:LoadCharacter()
		end)
	end
	publish()
end

endMatch = function(winner: MatchTeam?)
	if phase ~= "playing" then
		return
	end
	phase = "ended"
	phaseEndsAt = now() + Config.Match.EndSeconds
	workspace:SetAttribute("MatchWinner", if winner then winner.info.key else "")
	if winner then
		local names = {}
		for _, member in winner.members do
			if member.Parent then
				table.insert(names, member.DisplayName)
				reward(member, "Win")
				addStat(member, "wins")
				MatchService.Won:Fire(member)
			end
		end
		Notify.all(
			"🏆 " .. winner.info.emoji .. " " .. winner.info.name .. " WINS! (" .. table.concat(names, ", ") .. ")",
			"rare"
		)
	else
		Notify.all("🏁 The match is over!", "info")
	end
	for _, team in teams do
		for _, member in team.members do
			if member.Parent then
				reward(member, "Played")
				addStat(member, "matches")
				MatchService.Played:Fire(member)
			end
		end
	end
	publish()
	task.delay(Config.Match.EndSeconds, resetToLobby)
end

-- Set by TournamentService: a reason to hold off starting matches (a
-- tournament is on in the lobby), or nil.
MatchService.pausedBy = function(): string?
	return nil
end

-- Players needed to start: bots fill in, so one is enough when they're on.
local function neededPlayers(): number
	if Config.Bots.Enabled then
		return 1
	end
	return if RunService:IsStudio() then Config.Match.StudioMinPlayers else Config.Match.MinPlayers
end

-- Set by BotService: how many extra all-bot teams a match gets.
MatchService.botTeamsFor = function(_players: number, _teams: number): number
	return 0
end

local function eligible(): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		if DataService.get(player) and player.Character then
			table.insert(list, player)
		end
	end
	return list
end

-- The team size with the most votes among `players` (nil when nobody voted).
local function pickMode(players: { Player })
	local counts: { [string]: number } = {}
	for _, player in players do
		local vote = player:GetAttribute("ModeVote")
		if type(vote) == "string" and MatchData.mode(vote) then
			counts[vote] = (counts[vote] or 0) + 1
		end
	end
	local best, bestCount = nil, 0
	for _, mode in MatchData.Modes do
		if (counts[mode.key] or 0) > bestCount then
			best, bestCount = mode, counts[mode.key]
		end
	end
	return best, counts
end

local function publishVotes()
	local _, counts = pickMode(Players:GetPlayers())
	workspace:SetAttribute("ModeVotes", HttpService:JSONEncode(counts))
end

local function startMatch()
	local players = eligible()
	if #players == 0 then
		phase = "waiting"
		publish()
		return
	end
	-- Shuffle, then split into teams of the voted size, parties together.
	for i = #players, 2, -1 do
		local j = math.random(1, i)
		players[i], players[j] = players[j], players[i]
	end
	local mode = pickMode(players)
	local size = if mode then mode.size elseif #players <= Config.Match.SoloUpTo then 1 else 2
	local maxTeams = math.min(#MatchData.Teams, #islands)
	-- Co-op modes (🧟 Zombie Survival): everyone on one team.
	local teamCount = if mode and mode.coop
		then 1
		else math.clamp(math.ceil(#players / size), math.min(2, #players), maxTeams)
	local capacity = math.ceil(#players / teamCount)
	workspace:SetAttribute("MatchMode", if mode then mode.key else (if size == 1 then "Solo" else "Duo"))
	Teams:ClearAllChildren()
	teams = {}
	buildMiddle()
	local mapOk, mapProblem = pcall(MapService.apply, islands)
	if not mapOk then
		warn("[Bottle a Storm] The map theme failed: " .. tostring(mapProblem))
	end
	local botTeams = math.clamp(MatchService.botTeamsFor(#players, teamCount), 0, maxTeams - teamCount)
	local total = teamCount + botTeams
	local playerTeams: { MatchTeam } = {}
	for i = 1, total do
		local islandIndex = math.floor((i - 1) * #islands / total) + 1
		local team = setUpTeam(MatchData.Teams[i], islands[islandIndex])
		table.insert(teams, team)
		if i <= teamCount then
			table.insert(playerTeams, team)
		else
			team.botTotal = math.clamp(size, 1, 2)
			team.botsIn = team.botTotal
		end
	end
	local function roomiest(): MatchTeam
		local best = playerTeams[1]
		for _, team in playerTeams do
			if #team.members < #best.members then
				best = team
			end
		end
		return best
	end
	local groups = PartyService.groups(players)
	table.sort(groups, function(a, b)
		return #a > #b
	end)
	for _, group in groups do
		local target = roomiest()
		for _, player in group do
			if #target.members >= capacity then
				target = roomiest()
			end
			table.insert(target.members, player)
			teamByPlayer[player] = target
		end
	end
	for _, player in players do
		local team = teamByPlayer[player] :: MatchTeam
		team.alive[player] = true
		player.Neutral = false
		player.Team = team.roblox
		player:SetAttribute("TeamKey", team.info.key)
		player:SetAttribute("InMatch", true)
		player:SetAttribute("Spectating", nil)
		clearResources(player)
	end
	for _, team in teams do
		if team.bed then
			CosmeticService.dressBed(team.bed, team.frame * CFrame.new(0, 0, 22), team.members)
		end
	end
	startedTeams = total
	phase = "playing"
	startedAt = now()
	phaseEndsAt = startedAt + Config.Match.MaxSeconds
	workspace:SetAttribute("MatchWinner", nil)
	publish()
	MatchService.MatchStarted:Fire()
	Notify.all(
		"⚔️ BED WARS! "
			.. teamCount
			.. " teams. Protect your cloud bed, collect resources, and break the others' beds!",
		"rare"
	)
	for _, player in players do
		task.spawn(function()
			player:LoadCharacter()
		end)
	end
end

function MatchService.startNow(): boolean
	if phase == "playing" or phase == "ended" then
		return false
	end
	startMatch()
	return true
end

-- Ends the match with `team` as the winner (co-op modes decide this).
function MatchService.declareWinner(team: MatchTeam)
	if phase == "playing" then
		endMatch(team)
	end
end

function MatchService.endNow(): boolean
	if phase ~= "playing" then
		return false
	end
	-- The team with the most players standing wins.
	local best: MatchTeam? = nil
	for _, team in teams do
		if not best or aliveCount(team) > aliveCount(best) then
			best = team
		end
	end
	endMatch(best)
	return true
end

---------------------------------------------------------------------------

local function buildSpectatorBox()
	local box = Instance.new("Model")
	box.Name = "SpectatorBox"
	local center = Vector3.new(0, 150, 0)
	local floor = Instance.new("Part")
	floor.Anchored = true
	floor.Size = Vector3.new(30, 1, 30)
	floor.CFrame = CFrame.new(center)
	floor.Material = Enum.Material.Glass
	floor.Color = Color3.fromRGB(200, 230, 255)
	floor.Transparency = 0.5
	floor.Parent = box
	for _, side in { Vector3.new(15, 3, 0), Vector3.new(-15, 3, 0), Vector3.new(0, 3, 15), Vector3.new(0, 3, -15) } do
		local wall = Instance.new("Part")
		wall.Anchored = true
		wall.Size = if side.X ~= 0 then Vector3.new(1, 6, 30) else Vector3.new(30, 6, 1)
		wall.CFrame = CFrame.new(center + side)
		wall.Material = Enum.Material.Glass
		wall.Color = Color3.fromRGB(200, 230, 255)
		wall.Transparency = 0.7
		wall.Parent = box
	end
	box.Parent = workspace
	spectatorSpot = CFrame.new(center + Vector3.new(0, 4, 0))
end

function MatchService.init()
	islands = WorldBuilder.build()
	matchFolder = Instance.new("Folder")
	matchFolder.Name = "Match"
	matchFolder.Parent = workspace
	Players.RespawnTime = Config.Match.RespawnSeconds
	lobbySpot = WorldBuilder.LobbySpots.spawn + Vector3.new(0, 4, 0)
	buildSpectatorBox()
	publish()
end

function MatchService.start()
	Remotes.event("VoteMode").OnServerEvent:Connect(function(player, key)
		if phase ~= "playing" and type(key) == "string" and MatchData.mode(key) then
			player:SetAttribute("ModeVote", key)
			publishVotes()
		end
	end)
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			task.defer(spawnInto, player, character)
			local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
			if humanoid then
				humanoid.Died:Connect(function()
					onDied(player)
				end)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local team = teamByPlayer[player]
		if team then
			team.alive[player] = nil
			teamByPlayer[player] = nil
			publish()
			checkWin()
		end
		eliminated[player] = nil
		lastHit[player] = nil
		task.defer(publishVotes)
	end)

	-- The round loop.
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(0.2)
			local dt = os.clock() - last
			last = os.clock()
			local t = now()
			-- An error in one step never stops the rounds.
			local ok, problem = pcall(function()
				if phase == "waiting" then
					local needed = neededPlayers()
					local count = #eligible()
					local paused = MatchService.pausedBy()
					workspace:SetAttribute("MatchNeeded", needed)
					workspace:SetAttribute("MatchReady", count)
					workspace:SetAttribute("MatchPaused", paused)
					if count >= needed and not paused then
						-- Alone with bots: a longer wait, to enjoy the lobby first.
						local countdown = if count < Config.Match.MinPlayers
							then Config.Bots.SoloCountdown
							else Config.Match.CountdownSeconds
						phase = "starting"
						phaseEndsAt = t + countdown
						publish()
						Notify.all("⚔️ A Bed Wars match starts in " .. countdown .. " seconds!", "info")
					end
				elseif phase == "starting" then
					local needed = neededPlayers()
					if #eligible() < needed or MatchService.pausedBy() then
						phase = "waiting"
						publish()
					elseif t >= phaseEndsAt then
						local started, startProblem = pcall(startMatch)
						if not started then
							-- Something broke while setting up: clean up and try again later.
							warn("[Bottle a Storm] Couldn't start the match: " .. tostring(startProblem))
							phase = "playing" -- so resetToLobby's checks run
							pcall(resetToLobby)
							phase = "waiting"
							publish()
						end
					end
				elseif phase == "playing" then
					local multiplier = tierMultiplier()
					for _, team in teams do
						local generator = team.generator
						if generator then
							runGenerator(
								generator,
								dt,
								(1 + 0.5 * (team.upgrades.Forge or 0)) * WeatherService.generatorMultiplier(false)
							)
						end
						-- Healing Aura: teammates heal on their own island.
						if (team.upgrades.HealAura or 0) > 0 then
							for player in team.alive do
								local root = rootOf(player)
								local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
								if root and humanoid and humanoid.Health > 0 then
									local flat = (root.Position - team.frame.Position) * Vector3.new(1, 0, 1)
									if flat.Magnitude < Config.World.PlotRadius then
										humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + dt * 2)
									end
								end
							end
						end
					end
					for _, generator in middleGenerators do
						runGenerator(generator, dt, multiplier * WeatherService.generatorMultiplier(true))
					end
					if not suddenDeath and t - startedAt >= Config.Match.SuddenDeathAt then
						suddenDeath = true
						Notify.all("⚠️ SUDDEN DEATH! Every cloud bed has broken!", "rare")
						for _, team in teams do
							breakBed(team, nil)
						end
					end
					if t >= phaseEndsAt then
						MatchService.endNow()
					end
				end
			end)
			if not ok then
				warn("[Bottle a Storm] Match loop problem: " .. tostring(problem))
			end
		end
	end)
end

return MatchService
