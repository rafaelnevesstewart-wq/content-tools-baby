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
	local count = 0
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
			total = #team.members,
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

local function breakBed(team: MatchTeam, breaker: Player?)
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
		reward(breaker, "Bed")
		addStat(breaker, "bedsBroken")
		MatchService.BedBroken:Fire(breaker, team)
	else
		Notify.all("🛏️ " .. team.info.emoji .. " " .. team.info.name .. "'s cloud bed broke!", "warn")
	end
	for _, member in team.members do
		if member.Parent then
			Notify.player(member, "💔 Your cloud bed is gone! If you die now, you're out.", "warn")
			Juice.shake(member, 1)
			Juice.sound(member, "zap")
		end
	end
	publish()
end

local function cloudBed(team: MatchTeam): Model
	local bed = Instance.new("Model")
	bed.Name = "CloudBed"
	local frame = team.frame * CFrame.new(0, 0, 22)
	part(bed, {
		Name = "Frame",
		CanQuery = false, -- so only placed blocks hide the bed from breakers
		Size = Vector3.new(6, 1.2, 9),
		CFrame = frame * CFrame.new(0, 0.6, 0),
		Color = Color3.fromRGB(120, 88, 60),
		Material = Enum.Material.Wood,
	})
	-- A blanket in the team's color; the cloud mattress is added by
	-- CosmeticService.dressBed once the team's players are known.
	part(bed, {
		Name = "Blanket",
		CanQuery = false,
		Size = Vector3.new(6.2, 0.4, 4.6),
		CFrame = frame * CFrame.new(0, 3.3, -2),
		Color = team.info.color,
		Material = Enum.Material.Fabric,
		CanCollide = false,
	})
	part(bed, {
		Name = "Pillow",
		CanQuery = false, -- so only placed blocks hide the bed from breakers
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(3, 3, 3),
		CFrame = frame * CFrame.new(0, 2.8, 3.4),
		Color = Color3.new(1, 1, 1),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	})
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
	local pad = part(parent, {
		Name = "Generator",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.5, 7, 7),
		CFrame = at * CFrame.new(0, 0.25, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.2,
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

local function shopStand(team: MatchTeam)
	local at = team.frame * CFrame.new(-14, 0, -12)
	local stand = part(team.folder, {
		Name = "ItemShop",
		Size = Vector3.new(4, 3, 4),
		CFrame = at * CFrame.new(0, 1.5, 0),
		Color = Color3.fromRGB(96, 70, 48),
		Material = Enum.Material.WoodPlanks,
	})
	noBuild(stand)
	part(team.folder, {
		Name = "Awning",
		Size = Vector3.new(6, 0.4, 6),
		CFrame = at * CFrame.new(0, 6, 0),
		Color = team.info.color,
		Material = Enum.Material.Fabric,
	})
	for _, x in { -2.6, 2.6 } do
		part(team.folder, {
			Size = Vector3.new(0.4, 6, 0.4),
			CFrame = at * CFrame.new(x, 3, -2.6),
			Color = Color3.fromRGB(96, 70, 48),
			Material = Enum.Material.Wood,
		})
	end
	billboard(stand, 5, "🛒 Item Shop")
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ItemShopPrompt"
	prompt.ActionText = "Open the Item Shop"
	prompt.ObjectText = "🛒 Swords, armor, blocks"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = stand
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
			if root and MatchService.isPlaying(player) and (root.Position - generator.pad.Position).Magnitude < 5 then
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

local function spawnInto(player: Player, character: Model)
	local team = teamByPlayer[player]
	if phase == "playing" and team and not eliminated[player] then
		character:PivotTo(team.spawn)
		local shield = Instance.new("ForceField")
		shield.Visible = true
		shield.Parent = character
		task.delay(Config.Match.SpawnProtection, function()
			shield:Destroy()
		end)
		MatchService.PlayerSpawned:Fire(player, team)
	elseif phase == "playing" and team and eliminated[player] then
		character:PivotTo(spectatorSpot)
	else
		character:PivotTo(lobbySpot)
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

local function onDied(player: Player)
	if not MatchService.isPlaying(player) then
		return
	end
	local team = teamByPlayer[player] :: MatchTeam
	local hit = lastHit[player]
	local killer = if hit and os.clock() - hit.at < 12 and hit.by.Parent then hit.by else nil
	lastHit[player] = nil
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
	local tag = if final then "  💀 FINAL KILL!" else ""
	if killer then
		Notify.all(
			"⚔️ " .. killer.DisplayName .. " knocked out " .. player.DisplayName .. tag,
			if final then "rare" else "info"
		)
		reward(killer, if final then "FinalKill" else "Kill")
		addStat(killer, "kills")
		if final then
			addStat(killer, "finalKills")
		end
		MatchService.Killed:Fire(killer, player, final)
	else
		Notify.all("💨 " .. player.DisplayName .. " fell out of the sky" .. tag, "info")
	end
	if final then
		Notify.player(player, "💀 You're out! Watch the rest of the match from the sky box.", "warn")
	end
	publish()
	checkWin()
end

local function resetToLobby()
	MatchService.MatchEnded:Fire()
	MapService.reset()
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
	local teamCount = math.clamp(math.ceil(#players / size), math.min(2, #players), maxTeams)
	local capacity = math.ceil(#players / teamCount)
	workspace:SetAttribute("MatchMode", if mode then mode.key else (if size == 1 then "Solo" else "Duo"))
	Teams:ClearAllChildren()
	teams = {}
	buildMiddle()
	MapService.apply(islands)
	for i = 1, teamCount do
		local islandIndex = math.floor((i - 1) * #islands / teamCount) + 1
		table.insert(teams, setUpTeam(MatchData.Teams[i], islands[islandIndex]))
	end
	local function roomiest(): MatchTeam
		local best = teams[1]
		for _, team in teams do
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
	startedTeams = teamCount
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
	lobbySpot = CFrame.new(0, 4, -(Config.World.CenterRadius - 20))
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
			if phase == "waiting" then
				local needed = if RunService:IsStudio() then Config.Match.StudioMinPlayers else Config.Match.MinPlayers
				local count = #eligible()
				workspace:SetAttribute("MatchNeeded", needed)
				workspace:SetAttribute("MatchReady", count)
				if count >= needed then
					phase = "starting"
					phaseEndsAt = t + Config.Match.CountdownSeconds
					publish()
					Notify.all(
						"⚔️ A Bed Wars match starts in " .. Config.Match.CountdownSeconds .. " seconds!",
						"info"
					)
				end
			elseif phase == "starting" then
				local needed = if RunService:IsStudio() then Config.Match.StudioMinPlayers else Config.Match.MinPlayers
				if #eligible() < needed then
					phase = "waiting"
					publish()
				elseif t >= phaseEndsAt then
					startMatch()
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
		end
	end)
end

return MatchService
