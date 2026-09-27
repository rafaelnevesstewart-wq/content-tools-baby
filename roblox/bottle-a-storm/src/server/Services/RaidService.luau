-- The Mega-Storm raid. Every 45 minutes a boss storm attacks the Wild Skies
-- and the whole server has 3 minutes to beat it with Storm Launchers.
--   Win:  everyone who fought gets an Epic or Legendary storm.
--   Lose: every island loses one random storm (Raid Shields and new players are safe).
-- Stealing is off and wild storms hide while it runs.

local Debris = game:GetService("Debris")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local RaidData = require(Shared.RaidData)
local StormData = require(Shared.StormData)
local Signal = require(Shared.Signal)

local Modules = script.Parent.Parent.Modules
local Notify = require(Modules.Notify)
local StormModel = require(Modules.StormModel)

local CaptureService = require(script.Parent.CaptureService)
local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local IndexService = require(script.Parent.IndexService)
local MovementService = require(script.Parent.MovementService)
local PlotService = require(script.Parent.PlotService)
local SeasonService = require(script.Parent.SeasonService)
local StealService = require(script.Parent.StealService)
local StormSpawner = require(script.Parent.StormSpawner)
local WeatherService = require(script.Parent.WeatherService)

local RaidService = {}

-- (player) for everyone who dealt damage when a raid ends.
RaidService.Fought = Signal.new()

local LAUNCHER_NAME = "Storm Launcher"
local SPAWN_HEIGHT = 230
local ARRIVE_SECONDS = 3

local RAID_LIGHTING = {
	ClockTime = 17.6,
	Ambient = Color3.fromRGB(80, 75, 105),
	OutdoorAmbient = Color3.fromRGB(105, 100, 135),
	AtmosphereColor = Color3.fromRGB(95, 95, 120),
}

local phase = "idle" -- "idle" | "warning" | "active"
local raidId = 0
local boss: RaidData.Boss? = nil
local bossModel: Model? = nil
local bossSpawnedAt = 0
local bossLeavingAt: number? = nil
local hp = 0
local maxHp = 0
local startsAt = 0
local endsAt = 0
local interval = Config.Raid.Interval
local warnedAt: { [number]: boolean } = {}

local damage: { [Player]: number } = {}
local lastShot: { [Player]: number } = {}
local lastRangeWarning: { [Player]: number } = {}
local joinedAt: { [Player]: number } = {}
local rng = Random.new()
local launcherTemplate: Tool

local function now(): number
	return workspace:GetServerTimeNow()
end

local function publish()
	workspace:SetAttribute("RaidState", phase)
	workspace:SetAttribute("RaidBoss", if boss then boss.id else "")
	workspace:SetAttribute("RaidHp", math.ceil(hp))
	workspace:SetAttribute("RaidMaxHp", math.ceil(maxHp))
	workspace:SetAttribute("RaidStartsAt", startsAt)
	workspace:SetAttribute("RaidEndsAt", endsAt)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

local function isAlive(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

-- Over the Wild Skies island: standing on it, or flying above it (flying
-- doesn't make you safe from the Mega-Storm).
local function onWildSkies(position: Vector3): boolean
	local flat = Vector3.new(position.X, 0, position.Z).Magnitude
	return flat <= Config.World.CenterRadius + 5 and position.Y > -15 and position.Y < Config.Flight.MaxHeight + 30
end

-- Living players on (or flying over) the Wild Skies island.
local function fighters(): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root and isAlive(player) and onWildSkies(root.Position) then
			table.insert(list, player)
		end
	end
	return list
end

-- Bigger collections hit harder: x1 with no income, about x6 at 100K Sparks/s.
local function damageMultiplier(player: Player): number
	return 1 + math.log10(1 + IncomeService.rateOf(player))
end

local function bossRoot(): BasePart?
	return if bossModel then bossModel.PrimaryPart else nil
end

local function makePart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	for key, value in props do
		if key ~= "Parent" then
			(part :: any)[key] = value
		end
	end
	part.Parent = props.Parent or workspace
	return part
end

local function beam(from: Vector3, to: Vector3, color: Color3, width: number, seconds: number)
	local distance = (to - from).Magnitude
	local part = makePart({
		Name = "RaidBeam",
		Size = Vector3.new(width, width, distance),
		CFrame = CFrame.lookAt((from + to) / 2, to),
		Color = color,
		Material = Enum.Material.Neon,
	})
	Debris:AddItem(part, seconds)
end

-- The color of the player's best storm, for their launcher shots.
local function shotColor(player: Player): Color3
	local data = DataService.get(player)
	local best: StormData.StormRecord? = nil
	if data then
		for _, record in data.storms do
			if not best or StormData.incomeOf(record) > StormData.incomeOf(best) then
				best = record
			end
		end
	end
	local def = if best then StormData.get(best.id) else nil
	return if def then def.colors[1] else Color3.fromRGB(255, 214, 70)
end

---------------------------------------------------------------------------
-- The boss
---------------------------------------------------------------------------

local function spawnBoss(chosen: RaidData.Boss)
	local def: StormData.StormDef = {
		id = chosen.id,
		name = chosen.name,
		rarity = 5,
		income = 0,
		colors = chosen.colors,
		fx = chosen.fx,
	}
	local model = StormModel.build(def, { scale = 6, angry = true })
	model.Name = "MegaStorm"
	model:PivotTo(CFrame.new(0, SPAWN_HEIGHT, 0))

	local tag = Instance.new("BillboardGui")
	tag.Name = "BossTag"
	tag.Size = UDim2.fromOffset(420, 90)
	tag.StudsOffsetWorldSpace = Vector3.new(0, 30, 0)
	tag.MaxDistance = 1500
	tag.AlwaysOnTop = true
	tag.LightInfluence = 0
	local lines = {
		{ text = chosen.emoji .. " " .. chosen.name, size = 34, color = Color3.new(1, 1, 1) },
		{ text = "MEGA-STORM", size = 22, color = Color3.fromRGB(255, 110, 110) },
	}
	for index, line in lines do
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0, if index == 1 then 0 else 0.55)
		label.Size = UDim2.fromScale(1, if index == 1 then 0.55 else 0.45)
		label.Font = Enum.Font.GothamBold
		label.TextSize = line.size
		label.Text = line.text
		label.TextColor3 = line.color
		label.TextStrokeTransparency = 0.2
		label.Parent = tag
	end
	tag.Parent = model.PrimaryPart

	bossModel = model
	bossSpawnedAt = os.clock()
	bossLeavingAt = nil
	model.Parent = workspace
end

-- Descends from the sky, bobs and slowly spins; flies off when it wins.
local function animateBoss()
	local root = bossRoot()
	if not root then
		return
	end
	local t = os.clock()
	local arrive = math.clamp((t - bossSpawnedAt) / ARRIVE_SECONDS, 0, 1)
	local y = SPAWN_HEIGHT + (Config.Raid.BossHeight - SPAWN_HEIGHT) * (1 - (1 - arrive) ^ 2)
	if bossLeavingAt then
		y += ((t - bossLeavingAt) ^ 2) * 25
	end
	y += math.sin(t * 1.3) * 3
	root.CFrame = CFrame.new(0, y, 0) * CFrame.Angles(0, t * 0.35, 0)
end

-- Keeps animating (flying away) until it's destroyed.
local function removeBoss(delaySeconds: number)
	local model = bossModel
	if model then
		task.delay(delaySeconds, function()
			if bossModel == model then
				bossModel = nil
			end
			model:Destroy()
		end)
	end
end

---------------------------------------------------------------------------
-- Boss attacks
---------------------------------------------------------------------------

local function lightning(enraged: boolean)
	local targets = fighters()
	local count = math.min(#targets, Config.Raid.MaxStrikeTargets + (if enraged then 2 else 0))
	for i = 1, count do
		local pick = rng:NextInteger(i, #targets)
		targets[i], targets[pick] = targets[pick], targets[i]
		local root = rootOf(targets[i])
		if root then
			local radius = Config.Raid.StrikeRadius
			-- Flying players get struck in the air: the red circle appears
			-- right under them, at their height.
			local height = if root.Position.Y > 10 then root.Position.Y - 3 else 0.2
			local ground = Vector3.new(root.Position.X, height, root.Position.Z)
			local warning = makePart({
				Name = "StrikeWarning",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.3, radius * 2, radius * 2),
				CFrame = CFrame.new(ground) * CFrame.Angles(0, 0, math.rad(90)),
				Color = Color3.fromRGB(255, 70, 70),
				Material = Enum.Material.Neon,
				Transparency = 0.45,
			})
			task.delay(Config.Raid.StrikeWarning, function()
				warning:Destroy()
				local from = bossRoot()
				if phase ~= "active" or not from then
					return
				end
				beam(from.Position, ground, Color3.fromRGB(255, 240, 110), 1.6, 0.25)
				for _, player in Players:GetPlayers() do
					local target = rootOf(player)
					if target then
						local offset = target.Position - ground
						local flat = Vector3.new(offset.X, 0, offset.Z).Magnitude
						if flat <= radius and offset.Y > -6 and offset.Y < 25 then
							MovementService.stun(player, Config.Raid.StrikeStun)
							Notify.player(player, "⚡ Struck by lightning! Dodge the red circles!", "warn")
						end
					end
				end
			end)
		end
	end
end

local function gust(currentBoss: RaidData.Boss, id: number)
	Notify.all("🌬️ " .. currentBoss.name .. " is taking a deep breath... HOLD ON!", "warn")
	task.wait(2)
	if phase ~= "active" or raidId ~= id then
		return
	end
	for _, player in fighters() do
		local root = rootOf(player)
		if root then
			local outward = Vector3.new(root.Position.X, 0, root.Position.Z)
			if outward.Magnitude < 1 then
				outward = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))
			end
			local attachment = Instance.new("Attachment")
			attachment.Name = "GustAttachment"
			attachment.Parent = root
			local push = Instance.new("LinearVelocity")
			push.Attachment0 = attachment
			push.RelativeTo = Enum.ActuatorRelativeTo.World
			push.MaxForce = 1e7
			push.VectorVelocity = outward.Unit * Config.Raid.GustSpeed + Vector3.new(0, 25, 0)
			push.Parent = root
			Debris:AddItem(push, Config.Raid.GustSeconds)
			Debris:AddItem(attachment, Config.Raid.GustSeconds)
		end
	end
end

local function attackLoop(id: number, currentBoss: RaidData.Boss)
	local attacks = 0
	while phase == "active" and raidId == id and hp > 0 do
		local enraged = hp / maxHp <= Config.Raid.EnrageAt
		task.wait(if enraged then Config.Raid.EnragedAttackInterval else Config.Raid.AttackInterval)
		if phase ~= "active" or raidId ~= id or hp <= 0 then
			break
		end
		attacks += 1
		if attacks % Config.Raid.GustEvery == 0 then
			gust(currentBoss, id)
		else
			lightning(enraged)
		end
	end
end

---------------------------------------------------------------------------
-- Storm Launcher
---------------------------------------------------------------------------

local function shoot(player: Player)
	local target = bossRoot()
	local root = rootOf(player)
	if phase ~= "active" or hp <= 0 or not target or not root then
		return
	end
	if os.clock() - (lastShot[player] or 0) < Config.Raid.ShotCooldown or MovementService.isStunned(player) then
		return
	end
	if not onWildSkies(root.Position) then
		if os.clock() - (lastRangeWarning[player] or 0) > 4 then
			lastRangeWarning[player] = os.clock()
			Notify.player(player, "Get onto the Wild Skies island to hit the Mega-Storm!", "warn")
		end
		return
	end
	lastShot[player] = os.clock()

	local amount = Config.Raid.ShotDamage * damageMultiplier(player)
	damage[player] = (damage[player] or 0) + amount
	player:SetAttribute("RaidDamage", math.floor(damage[player]))
	hp = math.max(0, hp - amount)
	workspace:SetAttribute("RaidHp", math.ceil(hp))

	local shot = makePart({
		Name = "LauncherShot",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2, 2, 2),
		CFrame = CFrame.new(root.Position + Vector3.new(0, 2, 0)),
		Color = shotColor(player),
		Material = Enum.Material.Neon,
	})
	TweenService:Create(shot, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = target.Position,
	}):Play()
	Debris:AddItem(shot, 0.4)
end

local function giveLauncher(player: Player, equip: boolean)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	if
		not backpack
		or backpack:FindFirstChild(LAUNCHER_NAME)
		or (character and character:FindFirstChild(LAUNCHER_NAME))
	then
		return
	end
	local tool = launcherTemplate:Clone()
	tool.Activated:Connect(function()
		shoot(player)
	end)
	tool.Parent = backpack
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if equip and humanoid then
		humanoid:EquipTool(tool)
	end
end

local function removeLaunchers()
	for _, player in Players:GetPlayers() do
		for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
			local tool = container and container:FindFirstChild(LAUNCHER_NAME)
			if tool then
				tool:Destroy()
			end
		end
	end
end

---------------------------------------------------------------------------
-- Rewards and penalties
---------------------------------------------------------------------------

local function randomStormOfRarity(rarity: number): StormData.StormDef
	local options = StormData.wildOfRarity(rarity)
	return options[rng:NextInteger(1, #options)]
end

local function reward(player: Player, isMVP: boolean)
	local data = DataService.get(player)
	if not data then
		return
	end
	local legendaryChance = if isMVP then Config.Raid.MVPLegendaryChance else Config.Raid.LegendaryChance
	local def = randomStormOfRarity(if rng:NextNumber() < legendaryChance then 5 else 4)
	local record: StormData.StormRecord = {
		uid = HttpService:GenerateGUID(false),
		id = def.id,
		mut = CaptureService.rollMutation(),
		slot = 0,
		at = os.time(),
		mood = Config.Mood.Start,
	}
	local name = StormData.displayName(record)
	local slot = PlotService.firstFreeSlot(player)
	if slot then
		record.slot = slot
		table.insert(data.storms, record)
		IndexService.discover(player, def.id)
		PlotService.refreshSlot(player, slot)
		Notify.player(player, "🎁 Raid reward: " .. name .. " is on your island!", "rare")
	else
		local sparks = math.floor(StormData.incomeOf(record) * Config.Raid.FullIslandRewardSeconds)
		data.sparks += sparks
		Notify.player(
			player,
			"🎁 Your island was full, so your " .. name .. " became ⚡" .. Format.number(sparks) .. "!",
			"rare"
		)
	end
	IncomeService.sync(player)
end

local function penalize(player: Player, currentBoss: RaidData.Boss)
	local data = DataService.get(player)
	if not data or not PlotService.getPlot(player) then
		return
	end
	if os.clock() - (joinedAt[player] or 0) < Config.Raid.NewPlayerGraceSeconds then
		Notify.player(player, "You just arrived, so the Mega-Storm left your island alone this time.", "info")
		return
	end
	if data.raidShields > 0 then
		data.raidShields -= 1
		IncomeService.sync(player)
		Notify.player(player, "🛡️ Your Raid Shield kept your storms safe!", "success")
		return
	end
	local candidates = {}
	for index, record in data.storms do
		if not PlotService.isSlotStolen(player, record.slot) then
			table.insert(candidates, index)
		end
	end
	if #candidates == 0 then
		return
	end
	local index = candidates[rng:NextInteger(1, #candidates)]
	local record = table.remove(data.storms, index) :: StormData.StormRecord
	PlotService.refreshSlot(player, record.slot)
	IncomeService.sync(player)
	Notify.player(
		player,
		"🌪️ " .. currentBoss.name .. " blew away your " .. StormData.displayName(record) .. "!",
		"warn"
	)
end

local function scoreboard(): { Player }
	local ranked = {}
	for player, amount in damage do
		if player.Parent and amount > 0 then
			table.insert(ranked, player)
		end
	end
	table.sort(ranked, function(a, b)
		return damage[a] > damage[b]
	end)
	return ranked
end

---------------------------------------------------------------------------
-- Phases
---------------------------------------------------------------------------

local function beginWarning()
	phase = "warning"
	boss = RaidData.Bosses[rng:NextInteger(1, #RaidData.Bosses)]
	warnedAt = {}
	publish()
	WeatherService.setLightingOverride(RAID_LIGHTING)
	Notify.all(
		"⚠️ A MEGA-STORM is coming in " .. Config.Raid.WarningSeconds .. "s! Everyone to the Wild Skies!",
		"rare"
	)
end

local function beginFight()
	local currentBoss = boss :: RaidData.Boss
	phase = "active"
	raidId += 1
	damage = {}
	maxHp = 0
	for _, player in Players:GetPlayers() do
		player:SetAttribute("RaidDamage", 0)
		maxHp += Config.Raid.HpPerPlayer * damageMultiplier(player)
	end
	maxHp = math.max(maxHp, Config.Raid.HpPerPlayer)
	hp = maxHp
	endsAt = now() + Config.Raid.Duration

	StealService.cancelAll("🌪️ The Mega-Storm blew that storm back to its owner!")
	StormSpawner.setPaused(true)
	spawnBoss(currentBoss)
	for _, player in Players:GetPlayers() do
		giveLauncher(player, true)
	end
	publish()
	Notify.all(currentBoss.emoji .. " " .. currentBoss.taunt .. " Click to fire your Storm Launcher!", "rare")
	task.spawn(attackLoop, raidId, currentBoss)
end

local function finish(won: boolean)
	local currentBoss = boss :: RaidData.Boss
	local ranked = scoreboard()
	phase = "idle"
	removeLaunchers()
	StormSpawner.setPaused(false)
	WeatherService.setLightingOverride(nil)

	local lines = {}
	for i = 1, math.min(3, #ranked) do
		table.insert(lines, i .. ". " .. ranked[i].DisplayName .. " (" .. Format.number(damage[ranked[i]]) .. ")")
	end
	local top = if #lines > 0 then "  Top damage: " .. table.concat(lines, "  ") else ""
	for _, player in ranked do
		SeasonService.addXp(player, Config.Season.RaidFightXp + (if won then Config.Season.RaidWinXp else 0))
		RaidService.Fought:Fire(player)
	end

	if won then
		local root = bossRoot()
		if root then
			local explosion = Instance.new("Explosion")
			explosion.Position = root.Position
			explosion.BlastRadius = 0
			explosion.BlastPressure = 0
			explosion.DestroyJointRadiusPercent = 0
			explosion.Parent = workspace
		end
		removeBoss(0.3)
		Notify.all("🏆 VICTORY! " .. currentBoss.name .. " is defeated!" .. top, "rare")
		for index, player in ranked do
			reward(player, index == 1)
		end
		for _, player in Players:GetPlayers() do
			if not damage[player] then
				Notify.player(player, "Your server beat the Mega-Storm! Fight next time to win a reward storm.", "info")
			end
		end
	else
		bossLeavingAt = os.clock()
		removeBoss(4)
		Notify.all("💀 " .. currentBoss.winLine .. top, "warn")
		for _, player in Players:GetPlayers() do
			penalize(player, currentBoss)
		end
	end

	for _, player in Players:GetPlayers() do
		player:SetAttribute("RaidDamage", nil)
	end
	boss = nil
	hp = 0
	maxHp = 0
	endsAt = 0
	startsAt = math.max(startsAt + interval, now() + Config.Raid.WarningSeconds + 5)
	publish()
end

function RaidService.isActive(): boolean
	return phase == "active"
end

function RaidService.init()
	launcherTemplate = Instance.new("Tool")
	launcherTemplate.Name = LAUNCHER_NAME
	launcherTemplate.RequiresHandle = false
	launcherTemplate.CanBeDropped = false
	launcherTemplate.ToolTip = "Click to blast the Mega-Storm"

	local studio = RunService:IsStudio()
	interval = if studio then Config.Raid.StudioInterval else Config.Raid.Interval
	startsAt = now() + (if studio then Config.Raid.StudioFirstDelay else Config.Raid.FirstDelay)
	publish()
end

function RaidService.start()
	local function onPlayer(player: Player)
		joinedAt[player] = os.clock()
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid", 10)
			player:WaitForChild("Backpack", 10)
			task.wait()
			if phase == "active" then
				giveLauncher(player, false)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		damage[player] = nil
		lastShot[player] = nil
		lastRangeWarning[player] = nil
		joinedAt[player] = nil
	end)

	RunService.Heartbeat:Connect(animateBoss)

	task.spawn(function()
		while true do
			task.wait(0.25)
			local t = now()
			if phase == "idle" and t >= startsAt - Config.Raid.WarningSeconds then
				beginWarning()
			elseif phase == "warning" then
				local left = math.ceil(startsAt - t)
				for _, mark in { 30, 10 } do
					if left <= mark and not warnedAt[mark] then
						warnedAt[mark] = true
						Notify.all("⚠️ Mega-Storm in " .. mark .. " seconds!", "warn")
					end
				end
				if t >= startsAt then
					beginFight()
				end
			elseif phase == "active" then
				if hp <= 0 then
					finish(true)
				elseif t >= endsAt then
					finish(false)
				end
			end
		end
	end)
end

return RaidService
