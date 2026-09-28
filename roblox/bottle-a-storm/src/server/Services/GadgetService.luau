-- Bed Wars gadgets: Storm TNT, Fireballs, potions (speed, jump,
-- invisibility), and pickaxes and axes that break placed blocks faster.
-- The client only aims and asks (WeaponController, BlockController);
-- everything is checked here.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
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
	potions: { [string]: number },
}

local kits: { [Player]: Kit } = {}
local lastUse: { [Player]: number } = {}
local lastMine: { [Player]: number } = {}
local effects: { [Player]: { [string]: number } } = {} -- potion -> ends at (os.clock)

local POTIONS = {
	SpeedPotion = { tool = "Speed Potion", color = Color3.fromRGB(120, 220, 255) },
	JumpPotion = { tool = "Jump Potion", color = Color3.fromRGB(140, 240, 120) },
	InvisPotion = { tool = "Invisibility Potion", color = Color3.fromRGB(200, 200, 230) },
}
local TOOL_NAMES = { "Pickaxe", "Axe", "Storm TNT", "Fireball", "Speed Potion", "Jump Potion", "Invisibility Potion" }

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

local function kitOf(player: Player): Kit
	local kit = kits[player]
	if not kit then
		kit = { pickaxe = 0, axe = 0, tnt = 0, fireballs = 0, potions = {} }
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

local function boom(owner: Player, center: Vector3, radius: number, maxDamage: number, knockback: number)
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
					direction * knockback * strength + Vector3.new(0, knockback * 0.5, 0)
				)
			end
			if distance < radius * 4 then
				Juice.shake(player, math.clamp(1 - distance / (radius * 4), 0.2, 1))
			end
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
			boom(player, cell, Config.Match.TNTRadius, Config.Match.TNTDamage, Config.Match.TNTKnockback)
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
		boom(player, position, Config.Match.FireballRadius, Config.Match.FireballDamage, Config.Match.FireballKnockback)
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
	humanoid.WalkSpeed = 16 * (if (active.SpeedPotion or 0) > now then Config.Match.SpeedBoost else 1)
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
			BlockService.hit(player, aim, info.tiers[tier].power, key == "Axe")
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
	elseif POTIONS[key] then
		drink(player, key)
	end
end

---------------------------------------------------------------------------
-- Shop hooks (used by ItemShopService)
---------------------------------------------------------------------------

function GadgetService.handles(key: string): boolean
	return key == "TNT" or key == "Fireball" or POTIONS[key] ~= nil or MatchData.Tools[key] ~= nil
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
	elseif POTIONS[key] then
		kit.potions[key] = (kit.potions[key] or 0) + 1
	end
	refreshTools(player)
end

function GadgetService.start()
	Remotes.event("UseGadget").OnServerEvent:Connect(onUse)
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
		kit.pickaxe = math.max(math.min(kit.pickaxe, 1), kit.pickaxe - 1)
		kit.axe = math.max(math.min(kit.axe, 1), kit.axe - 1)
		kit.tnt = 0
		kit.fireballs = 0
		kit.potions = {}
		effects[player] = nil
		for key in POTIONS do
			player:SetAttribute(key .. "Ends", nil)
		end
		player:SetAttribute("Invisible", nil)
		task.wait(0.1)
		refreshTools(player)
		applyMovement(player)
	end)
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
	end)
end

return GadgetService
