-- Bed Wars gadgets: Storm TNT, Fireballs, Rocket Launchers, the Grappling
-- Hook (the client does the pulling), the 🪂 Glider (hold jump while falling;
-- GlideController flies it) and Parachutes (fall off the map and one opens
-- over your island), potions (speed, jump, invisibility), and pickaxes and axes that break placed blocks faster and
-- dig into the ground. Everyone always has at least a Wood Pickaxe.
-- The client only aims and asks (WeaponController, BlockController);
-- everything is checked here.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local EventData = require(Shared.EventData)
local MatchData = require(Shared.MatchData)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent.Parent.Modules
local ItemModels = require(Modules.ItemModels)
local Effects = require(Modules.Effects)
local Juice = require(Modules.Juice)
local Notify = require(Modules.Notify)

local BlockService = require(script.Parent.BlockService)
local CombatService = require(script.Parent.CombatService)
local MatchService = require(script.Parent.MatchService)

local GadgetService = {}

type Kit = {
	pickaxe: number, -- 0 = none
	axe: number,
	tnt: number,
	fireballs: number,
	rockets: number,
	grapple: boolean,
	glider: boolean,
	parachutes: number,
	potions: { [string]: number },
}

local kits: { [Player]: Kit } = {}
-- Ground dug up this match: the terrain as it was, to put back afterwards.
local dug: { { region: Region3, materials: any, occupancies: any } } = {}
local dugCells: { [string]: boolean } = {}
local lastUse: { [Player]: number } = {}
local lastMine: { [Player]: number } = {}
local effects: { [Player]: { [string]: number } } = {} -- potion -> ends at (os.clock)

local POTIONS = {
	SpeedPotion = { tool = "Speed Potion", color = Color3.fromRGB(120, 220, 255) },
	JumpPotion = { tool = "Jump Potion", color = Color3.fromRGB(140, 240, 120) },
	InvisPotion = { tool = "Invisibility Potion", color = Color3.fromRGB(200, 200, 230) },
}
local TOOL_NAMES = {
	"Pickaxe",
	"Axe",
	"Storm TNT",
	"Fireball",
	"Rocket Launcher",
	"Grappling Hook",
	"Speed Potion",
	"Jump Potion",
	"Invisibility Potion",
}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

local function kitOf(player: Player): Kit
	local kit = kits[player]
	if not kit then
		kit = {
			pickaxe = 0,
			axe = 0,
			tnt = 0,
			fireballs = 0,
			rockets = 0,
			grapple = false,
			glider = false,
			parachutes = 0,
			potions = {},
		}
		kits[player] = kit
	end
	return kit
end

---------------------------------------------------------------------------
-- Tools in the backpack
---------------------------------------------------------------------------

local function findTool(player: Player, name: string): Tool?
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	local tool = (backpack and backpack:FindFirstChild(name)) or (character and character:FindFirstChild(name))
	return if tool and tool:IsA("Tool") then tool else nil
end

-- Adds or removes a tool so it matches the count (and refreshes its tip).
local function sync(player: Player, name: string, count: number, build: () -> Tool)
	local tool = findTool(player, name)
	if count > 0 and not tool then
		local backpack = player:FindFirstChildOfClass("Backpack")
		if backpack then
			build().Parent = backpack
		end
	elseif count <= 0 and tool then
		tool:Destroy()
	end
end

local function refreshTools(player: Player)
	local kit = kitOf(player)
	for key, info in MatchData.Tools do
		local tier = if key == "Pickaxe" then kit.pickaxe else kit.axe
		local existing = findTool(player, key)
		if existing and existing:GetAttribute("Tier") ~= tier then
			existing:Destroy()
		end
		if tier > 0 then
			local data = info.tiers[tier]
			sync(player, key, 1, function()
				local tool = if key == "Pickaxe" then ItemModels.pickaxe(data) else ItemModels.axe(data)
				tool:SetAttribute("Tier", tier)
				return tool
			end)
		end
	end
	sync(player, "Storm TNT", kit.tnt, ItemModels.tnt)
	sync(player, "Fireball", kit.fireballs, ItemModels.fireball)
	sync(player, "Rocket Launcher", kit.rockets, ItemModels.rocketLauncher)
	sync(player, "Grappling Hook", if kit.grapple then 1 else 0, ItemModels.grapple)
	player:SetAttribute("Rockets", if kit.rockets > 0 then kit.rockets else nil)
	player:SetAttribute("Glider", if kit.glider then true else nil)
	player:SetAttribute("Parachutes", if kit.parachutes > 0 then kit.parachutes else nil)
	for key, potion in POTIONS do
		sync(player, potion.tool, kit.potions[key] or 0, function()
			local tool = ItemModels.potion(potion.tool, potion.color)
			tool:SetAttribute("Potion", key)
			return tool
		end)
	end
	player:SetAttribute("PickaxeTier", kit.pickaxe)
	player:SetAttribute("AxeTier", kit.axe)
end

---------------------------------------------------------------------------
-- Explosions
---------------------------------------------------------------------------

local function boom(
	owner: Player,
	center: Vector3,
	radius: number,
	maxDamage: number,
	knockback: number,
	weapon: string
)
	local flash = Instance.new("Part")
	flash.Shape = Enum.PartType.Ball
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanQuery = false
	flash.CanTouch = false
	flash.Material = Enum.Material.Neon
	flash.Color = Color3.fromRGB(255, 170, 60)
	flash.Size = Vector3.one * 2
	flash.CFrame = CFrame.new(center)
	flash.Parent = workspace
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 160, 60)
	light.Range = radius * 3
	light.Brightness = 6
	light.Parent = flash
	TweenService:Create(flash, TweenInfo.new(0.35), { Size = Vector3.one * radius * 2, Transparency = 1 }):Play()
	Debris:AddItem(flash, 0.4)
	Effects.confetti(center, 30)
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root and MatchService.isPlaying(player) then
			local offset = root.Position - center
			local distance = offset.Magnitude
			if distance <= radius then
				local strength = 1 - distance / radius * 0.6
				local direction = if distance > 0.1 then offset.Unit else Vector3.yAxis
				CombatService.hurt(
					player,
					owner,
					maxDamage * strength,
					direction * knockback * strength + Vector3.new(0, knockback * 0.5, 0),
					weapon
				)
			end
			if distance < radius * 4 then
				Juice.shake(player, math.clamp(1 - distance / (radius * 4), 0.2, 1))
				Juice.sound(player, "boom")
			end
		end
	end
	-- Bots get blown around too.
	for _, botRoot in CombatService.bots.enemiesOf(owner) do
		local offset = botRoot.Position - center
		local distance = offset.Magnitude
		local bot = CombatService.bots.botOf(botRoot)
		if bot and distance <= radius then
			local strength = 1 - distance / radius * 0.6
			local direction = if distance > 0.1 then offset.Unit else Vector3.yAxis
			CombatService.bots.hurt(
				bot,
				owner,
				maxDamage * strength,
				direction * knockback * strength + Vector3.new(0, knockback * 0.5, 0),
				weapon
			)
		end
	end
end

---------------------------------------------------------------------------
-- Using gadgets
---------------------------------------------------------------------------

local function placeTNT(player: Player, point: Vector3)
	local kit = kitOf(player)
	local root = rootOf(player)
	if kit.tnt <= 0 or not root then
		return
	end
	local cell = BlockService.snap(point)
	if (cell - root.Position).Magnitude > Config.Match.BlockReach or not BlockService.canPlace(cell) then
		return
	end
	kit.tnt -= 1
	refreshTools(player)
	local tnt = ItemModels.tntBlock(Config.Match.BlockSize * 0.9)
	tnt.CFrame = CFrame.new(cell)
	tnt.Parent = workspace
	local sparks = Instance.new("Sparkles")
	sparks.SparkleColor = Color3.fromRGB(255, 220, 90)
	sparks.Parent = tnt
	-- It blinks faster and faster before it goes off.
	task.spawn(function()
		local started = os.clock()
		while tnt.Parent and os.clock() - started < Config.Match.TNTFuse do
			tnt.Color = if tnt.Color == Color3.new(1, 1, 1) then Color3.fromRGB(200, 40, 40) else Color3.new(1, 1, 1)
			task.wait(math.max(0.06, 0.4 * (1 - (os.clock() - started) / Config.Match.TNTFuse)))
		end
		tnt:Destroy()
		if MatchService.phase() == "playing" then
			BlockService.explode(cell, Config.Match.TNTRadius, math.huge, { Obsidian = true })
			boom(player, cell, Config.Match.TNTRadius, Config.Match.TNTDamage, Config.Match.TNTKnockback, "TNT")
		end
	end)
end

local function throwFireball(player: Player, aim: Vector3)
	local kit = kitOf(player)
	local root = rootOf(player)
	if kit.fireballs <= 0 or not root then
		return
	end
	kit.fireballs -= 1
	refreshTools(player)
	local origin = root.Position + Vector3.new(0, 1.5, 0)
	local direction = aim - origin
	if direction.Magnitude < 0.1 then
		direction = root.CFrame.LookVector
	end
	direction = direction.Unit
	local ball = Instance.new("Part")
	ball.Name = "Fireball"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * 1.4
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.Material = Enum.Material.Neon
	ball.Color = Color3.fromRGB(255, 120, 30)
	ball.CFrame = CFrame.new(origin)
	ball.Parent = workspace
	local fire = Instance.new("Fire")
	fire.Size = 4
	fire.Heat = 8
	fire.Parent = ball
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { ball }
	if player.Character then
		table.insert(ignore, player.Character)
	end
	params.FilterDescendantsInstances = ignore
	task.spawn(function()
		local position = origin
		local travelled = 0
		local step = Config.Match.FireballSpeed / 30
		while travelled < Config.Match.FireballRange do
			local hit = workspace:Raycast(position, direction * step, params)
			if hit then
				position = hit.Position
				break
			end
			position += direction * step
			travelled += step
			ball.CFrame = CFrame.new(position)
			task.wait(1 / 30)
		end
		ball:Destroy()
		BlockService.explode(position, Config.Match.FireballRadius, 2, { StoneBricks = true, Obsidian = true })
		boom(
			player,
			position,
			Config.Match.FireballRadius,
			Config.Match.FireballDamage,
			Config.Match.FireballKnockback,
			"Fireball"
		)
	end)
end

-- A rocket: flies straight and fast, then a big blast (breaks stronger
-- blocks than a fireball).
local function fireRocket(player: Player, aim: Vector3)
	local kit = kitOf(player)
	local root = rootOf(player)
	if kit.rockets <= 0 or not root then
		return
	end
	kit.rockets -= 1
	refreshTools(player)
	local origin = root.Position + Vector3.new(0, 2, 0)
	local direction = aim - origin
	if direction.Magnitude < 0.1 then
		direction = root.CFrame.LookVector
	end
	direction = direction.Unit
	local rocket = Instance.new("Part")
	rocket.Name = "Rocket"
	rocket.Size = Vector3.new(0.6, 0.6, 2.4)
	rocket.Anchored = true
	rocket.CanCollide = false
	rocket.CanQuery = false
	rocket.CanTouch = false
	rocket.Color = Color3.fromRGB(200, 60, 50)
	rocket.Material = Enum.Material.SmoothPlastic
	rocket.CFrame = CFrame.lookAt(origin, origin + direction)
	rocket.Parent = workspace
	local tail = Instance.new("Attachment")
	tail.Position = Vector3.new(0, 0, 1.2)
	tail.Parent = rocket
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(220, 220, 220), Color3.fromRGB(120, 120, 120))
	smoke.Size = NumberSequence.new(0.8, 2.5)
	smoke.Transparency = NumberSequence.new(0.3, 1)
	smoke.Lifetime = NumberRange.new(0.6, 1)
	smoke.Rate = 60
	smoke.Speed = NumberRange.new(1, 2)
	smoke.Parent = tail
	local flame = Instance.new("Fire")
	flame.Size = 2
	flame.Heat = 0
	flame.Parent = rocket
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { rocket }
	if player.Character then
		table.insert(ignore, player.Character)
	end
	params.FilterDescendantsInstances = ignore
	Juice.sound(player, "throw")
	task.spawn(function()
		local position = origin
		local travelled = 0
		local step = Config.Match.RocketSpeed / 30
		while travelled < Config.Match.RocketRange do
			local hit = workspace:Raycast(position, direction * step, params)
			if hit then
				position = hit.Position
				break
			end
			position += direction * step
			travelled += step
			rocket.CFrame = CFrame.lookAt(position, position + direction)
			task.wait(1 / 30)
		end
		rocket:Destroy()
		if MatchService.phase() == "playing" then
			BlockService.explode(position, Config.Match.RocketRadius * 0.6, 4, { Obsidian = true })
			boom(
				player,
				position,
				Config.Match.RocketRadius,
				Config.Match.RocketDamage,
				Config.Match.RocketKnockback,
				"Rocket"
			)
		end
	end)
end

-- Invisible: body, face, armor, cosmetics and name all hidden for everyone
-- else. The client shows you a see-through version of yourself.
local function setInvisible(player: Player, on: boolean)
	local character = player.Character
	if not character then
		return
	end
	player:SetAttribute("Invisible", if on then true else nil)
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			if on then
				part:SetAttribute("VisibleTransparency", part.Transparency)
				part.Transparency = 1
			elseif part:GetAttribute("VisibleTransparency") ~= nil then
				part.Transparency = part:GetAttribute("VisibleTransparency")
				part:SetAttribute("VisibleTransparency", nil)
			end
		elseif part:IsA("Decal") then
			part.Transparency = if on then 1 else 0
		elseif part:IsA("BillboardGui") or part:IsA("ParticleEmitter") or part:IsA("Trail") then
			part.Enabled = not on
		end
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = if on
			then Enum.HumanoidDisplayDistanceType.None
			else Enum.HumanoidDisplayDistanceType.Viewer
	end
end

local function applyMovement(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local active = effects[player] or {}
	local now = os.clock()
	local rush = if EventData.is("SpeedRush") then EventData.SpeedRush else 1 -- 🎪 weekly event
	humanoid.WalkSpeed = 16 * rush * (if (active.SpeedPotion or 0) > now then Config.Match.SpeedBoost else 1)
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 50 * (if (active.JumpPotion or 0) > now then Config.Match.JumpBoost else 1)
end

local function drink(player: Player, key: string)
	local kit = kitOf(player)
	local count = kit.potions[key] or 0
	if count <= 0 or not POTIONS[key] then
		return
	end
	kit.potions[key] = count - 1
	refreshTools(player)
	effects[player] = effects[player] or {}
	local endsAt = os.clock() + Config.Match.PotionSeconds
	effects[player][key] = endsAt
	player:SetAttribute(key .. "Ends", workspace:GetServerTimeNow() + Config.Match.PotionSeconds)
	Juice.sound(player, "chime")
	if key == "InvisPotion" then
		setInvisible(player, true)
		Notify.player(player, "👻 You're invisible! Attacking shows you again.", "info")
	end
	applyMovement(player)
	task.delay(Config.Match.PotionSeconds + 0.05, function()
		local active = effects[player]
		if active and active[key] == endsAt then
			active[key] = nil
			player:SetAttribute(key .. "Ends", nil)
			if key == "InvisPotion" then
				setInvisible(player, false)
			end
			applyMovement(player)
		end
	end)
end

-- Set by LuckyService: hits a lucky block near `aim` (true if it did).
GadgetService.hitLucky = function(_player: Player, _aim: Vector3): boolean
	return false
end

-- Digs a hole in the island ground at `aim`. Returns whether it dug.
local function dig(player: Player, aim: Vector3, power: number): boolean
	local root = rootOf(player)
	if not root or (aim - root.Position).Magnitude > Config.Match.BlockReach or aim.Y < Config.Match.DigDepth then
		return false
	end
	for _, spot in MatchService.protectedSpots() do
		if (spot - aim).Magnitude < Config.Match.DigKeepAway then
			Notify.player(player, "⛏️ You can't dig next to beds, generators, shops or spawns.", "error")
			return false
		end
	end
	local terrain = workspace.Terrain
	-- Remember the ground here (in fixed 8-stud cells) before the first dig.
	local base = Vector3.new(math.floor(aim.X / 8) * 8, math.floor(aim.Y / 8) * 8, math.floor(aim.Z / 8) * 8)
	local region = Region3.new(base - Vector3.one * 4, base + Vector3.one * 12)
	local materials, occupancies = terrain:ReadVoxels(region, 4)
	local solid = false
	local size = materials.Size
	for x = 1, size.X do
		for y = 1, size.Y do
			for z = 1, size.Z do
				local material = materials[x][y][z]
				if material ~= Enum.Material.Air and material ~= Enum.Material.Water then
					solid = true
				end
			end
		end
	end
	if not solid then
		return false
	end
	local cell = tostring(base)
	if not dugCells[cell] then
		dugCells[cell] = true
		table.insert(dug, { region = region, materials = materials, occupancies = occupancies })
	end
	terrain:FillBall(aim, Config.Match.DigRadius + power * 0.2, Enum.Material.Air)
	Juice.sound(player, "pop")
	return true
end

-- Puts every dug hole back, newest first so overlapping cells end up as
-- they were at the start.
local function refill()
	for index = #dug, 1, -1 do
		local entry = dug[index]
		pcall(function()
			workspace.Terrain:WriteVoxels(entry.region, 4, entry.materials, entry.occupancies)
		end)
	end
	dug = {}
	dugCells = {}
end

local function mine(player: Player, aim: Vector3)
	local kit = kitOf(player)
	local character = player.Character
	if os.clock() - (lastMine[player] or 0) < Config.Match.HitCooldown then
		return
	end
	lastMine[player] = os.clock()
	for key, info in MatchData.Tools do
		local tier = if key == "Pickaxe" then kit.pickaxe else kit.axe
		if tier > 0 and character and character:FindFirstChild(key) then
			local power = info.tiers[tier].power
			-- A placed block first, then a lucky block, then the ground.
			if not BlockService.hit(player, aim, power, key == "Axe") and not GadgetService.hitLucky(player, aim) then
				dig(player, aim, power)
			end
			return
		end
	end
end

local function onUse(player: Player, key: any, aim: any)
	if not MatchService.isPlaying(player) or type(key) ~= "string" or typeof(aim) ~= "Vector3" then
		return
	end
	if key == "Mine" then
		mine(player, aim)
		return
	end
	if os.clock() - (lastUse[player] or 0) < 0.4 then
		return
	end
	lastUse[player] = os.clock()
	if key == "TNT" then
		placeTNT(player, aim)
	elseif key == "Fireball" then
		throwFireball(player, aim)
	elseif key == "Rocket" then
		fireRocket(player, aim)
	elseif POTIONS[key] then
		drink(player, key)
	end
end

---------------------------------------------------------------------------
-- 🪂 Gliders and parachutes
---------------------------------------------------------------------------

local PARACHUTE_BELOW = -35 -- a parachute opens when you fall below this
local lastGlide: { [Player]: number } = {}

local function torsoOf(player: Player): BasePart?
	local character = player.Character
	local torso = character and (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso"))
	return if torso and torso:IsA("BasePart") then torso else nil
end

local function teamColor(player: Player): Color3
	local team = MatchService.teamOf(player)
	return if team then team.info.color else Color3.fromRGB(120, 200, 255)
end

local function removeWorn(player: Player, name: string)
	local character = player.Character
	local model = character and character:FindFirstChild(name)
	if model then
		model:Destroy()
	end
end

-- Your screen says when you start and stop gliding; everyone sees the wings.
local function onGlide(player: Player, on: any)
	if on == true then
		local torso = torsoOf(player)
		if not kitOf(player).glider or not MatchService.isPlaying(player) or not torso then
			return
		end
		if os.clock() - (lastGlide[player] or 0) < 0.2 or (player.Character :: Model):FindFirstChild("GliderWings") then
			return
		end
		lastGlide[player] = os.clock()
		ItemModels.gliderWings(torso, teamColor(player))
	else
		removeWorn(player, "GliderWings")
	end
end

-- Falling off the map with a parachute: it opens high over your own island
-- and you float down (your screen slows the fall while "Parachuting").
local function openParachute(player: Player, kit: Kit)
	local team = MatchService.teamOf(player)
	local character = player.Character
	local root = rootOf(player)
	local torso = torsoOf(player)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not team or not character or not root or not torso or not humanoid then
		return
	end
	kit.parachutes -= 1
	refreshTools(player)
	removeWorn(player, "GliderWings")
	root.AssemblyLinearVelocity = Vector3.zero
	character:PivotTo(CFrame.new(team.spawn.Position + Vector3.new(0, 45, 0)) * team.spawn.Rotation)
	player:SetAttribute("Parachuting", true)
	ItemModels.parachute(torso, teamColor(player))
	Juice.sound(player, "chime")
	Notify.player(player, "🪂 Your parachute opened! Float back to your island.", "success")
	task.spawn(function()
		local started = os.clock()
		task.wait(0.8)
		while os.clock() - started < 20 and humanoid.Health > 0 and character.Parent do
			if humanoid.FloorMaterial ~= Enum.Material.Air then
				break
			end
			task.wait(0.15)
		end
		player:SetAttribute("Parachuting", nil)
		removeWorn(player, "Parachute")
	end)
end

local function watchFalls()
	while true do
		task.wait(0.2)
		for player, kit in kits do
			local root = rootOf(player)
			if
				kit.parachutes > 0
				and root
				and root.Position.Y < PARACHUTE_BELOW
				and not player:GetAttribute("Parachuting")
				and MatchService.isPlaying(player)
			then
				openParachute(player, kit)
			end
		end
	end
end

---------------------------------------------------------------------------
-- Shop hooks (used by ItemShopService)
---------------------------------------------------------------------------

-- A blast that hurts and throws players near it (lucky blocks use this).
function GadgetService.blast(owner: Player, center: Vector3, radius: number, damage: number, knockback: number)
	boom(owner, center, radius, damage, knockback, "Lucky Block")
end

-- Why a gadget can't be bought right now (nil if it can).
function GadgetService.problem(player: Player, key: string): string?
	if key == "GrapplingHook" and kitOf(player).grapple then
		return "You already have a grappling hook."
	end
	if key == "Glider" and kitOf(player).glider then
		return "You already have a glider."
	end
	if key == "Parachute" and kitOf(player).parachutes >= 3 then
		return "You can carry 3 parachutes at most."
	end
	return nil
end

function GadgetService.handles(key: string): boolean
	return key == "TNT"
		or key == "Fireball"
		or key == "RocketLauncher"
		or key == "GrapplingHook"
		or key == "Glider"
		or key == "Parachute"
		or POTIONS[key] ~= nil
		or MatchData.Tools[key] ~= nil
end

-- The next tier of a tool (or nil when it's maxed).
function GadgetService.nextTool(player: Player, key: string): MatchData.ToolTier?
	local info = MatchData.Tools[key]
	if not info then
		return nil
	end
	local kit = kitOf(player)
	local tier = if key == "Pickaxe" then kit.pickaxe else kit.axe
	return info.tiers[tier + 1]
end

function GadgetService.give(player: Player, key: string)
	local kit = kitOf(player)
	if key == "Pickaxe" then
		kit.pickaxe = math.min(kit.pickaxe + 1, #MatchData.Tools.Pickaxe.tiers)
	elseif key == "Axe" then
		kit.axe = math.min(kit.axe + 1, #MatchData.Tools.Axe.tiers)
	elseif key == "TNT" then
		kit.tnt += 1
	elseif key == "Fireball" then
		kit.fireballs += 1
	elseif key == "RocketLauncher" then
		kit.rockets += 3
	elseif key == "GrapplingHook" then
		kit.grapple = true
	elseif key == "Glider" then
		kit.glider = true
	elseif key == "Parachute" then
		kit.parachutes = math.min(kit.parachutes + 1, 3)
	elseif POTIONS[key] then
		kit.potions[key] = (kit.potions[key] or 0) + 1
	end
	refreshTools(player)
end

function GadgetService.start()
	Remotes.event("UseGadget").OnServerEvent:Connect(onUse)
	Remotes.event("Glide").OnServerEvent:Connect(onGlide)
	task.spawn(watchFalls)
	CombatService.Attacked:Connect(function(attacker)
		local active = effects[attacker]
		if active and active.InvisPotion then
			active.InvisPotion = nil
			attacker:SetAttribute("InvisPotionEnds", nil)
			setInvisible(attacker, false)
		end
	end)
	MatchService.PlayerSpawned:Connect(function(player)
		-- Tools drop one tier; everything else is lost.
		local kit = kitOf(player)
		kit.pickaxe = math.max(1, kit.pickaxe - 1) -- never less than a Wood Pickaxe
		kit.axe = math.max(math.min(kit.axe, 1), kit.axe - 1)
		kit.tnt = 0
		kit.fireballs = 0
		kit.rockets = 0 -- (the grappling hook, glider and parachutes are kept)
		kit.potions = {}
		effects[player] = nil
		for key in POTIONS do
			player:SetAttribute(key .. "Ends", nil)
		end
		player:SetAttribute("Invisible", nil)
		player:SetAttribute("Parachuting", nil)
		task.wait(0.1)
		refreshTools(player)
		applyMovement(player)
	end)
	table.insert(MatchService.beforeReset, refill)
	MatchService.MatchEnded:Connect(function()
		for player in kits do
			for _, name in TOOL_NAMES do
				local tool = findTool(player, name)
				if tool then
					tool:Destroy()
				end
			end
			for key in POTIONS do
				player:SetAttribute(key .. "Ends", nil)
			end
			player:SetAttribute("PickaxeTier", nil)
			player:SetAttribute("AxeTier", nil)
			player:SetAttribute("Glider", nil)
			player:SetAttribute("Parachutes", nil)
			player:SetAttribute("Parachuting", nil)
			removeWorn(player, "GliderWings")
			removeWorn(player, "Parachute")
			player:SetAttribute("Invisible", nil)
		end
		kits = {}
		effects = {}
	end)
	Players.PlayerRemoving:Connect(function(player)
		kits[player] = nil
		effects[player] = nil
		lastUse[player] = nil
		lastMine[player] = nil
		lastGlide[player] = nil
	end)
end

return GadgetService
