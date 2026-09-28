-- Bed Wars fighting: swords (wood to diamond), armor, bows, Storm Apples and
-- Wind Pearls. Players have 100 health. Hits push the other player back.
-- What you carry resets when you die, except armor. The client only aims and
-- asks (WeaponController); every hit is checked here.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local MatchData = require(Shared.MatchData)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Signal)

local Modules = script.Parent.Parent.Modules
local ItemModels = require(Modules.ItemModels)
local Juice = require(Modules.Juice)
local Notify = require(Modules.Notify)

local BlockService = require(script.Parent.BlockService)
local CosmeticService = require(script.Parent.CosmeticService)
local DataService = require(script.Parent.DataService)
local MatchService = require(script.Parent.MatchService)
local WeatherService = require(script.Parent.WeatherService)

local CombatService = {}

-- (attacker) whenever a player hurts an enemy (an invisible player shows up).
CombatService.Attacked = Signal.new()

type Gear = { sword: number, armor: number, bow: boolean, arrows: number, apples: number, pearls: number }

local gear: { [Player]: Gear } = {}
local lastSwing: { [Player]: number } = {}
local lastShot: { [Player]: number } = {}

local ITEM_TOOLS = { "Sword", "Bow", "Storm Apple", "Wind Pearl" }

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

local function gearOf(player: Player): Gear
	local g = gear[player]
	if not g then
		g = { sword = 1, armor = 1, bow = false, arrows = 0, apples = 0, pearls = 0 }
		gear[player] = g
	end
	return g
end

local function publish(player: Player)
	local g = gearOf(player)
	player:SetAttribute("SwordTier", g.sword)
	player:SetAttribute("ArmorTier", g.armor)
	player:SetAttribute("Arrows", g.arrows)
	player:SetAttribute("Apples", g.apples)
	player:SetAttribute("Pearls", g.pearls)
end

---------------------------------------------------------------------------
-- Tools
---------------------------------------------------------------------------

local function removeTool(player: Player, name: string)
	for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
		local tool = container and container:FindFirstChild(name)
		if tool then
			tool:Destroy()
		end
	end
end

local function hasTool(player: Player, name: string): boolean
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	return (backpack ~= nil and backpack:FindFirstChild(name) ~= nil)
		or (character ~= nil and character:FindFirstChild(name) ~= nil)
end

local function giveTool(player: Player, tool: Tool)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		tool.Parent = backpack
	end
end

-- Makes the tools match the player's gear.
local function refreshTools(player: Player)
	local g = gearOf(player)
	local sword = player.Character and player.Character:FindFirstChild("Sword")
	local wasHolding = sword ~= nil
	removeTool(player, "Sword")
	local data = DataService.get(player)
	local newSword = ItemModels.sword(g.sword, data and data.cosmetics.sword)
	giveTool(player, newSword)
	if wasHolding then
		local humanoid = humanoidOf(player)
		if humanoid then
			humanoid:EquipTool(newSword)
		end
	end
	if g.bow and not hasTool(player, "Bow") then
		giveTool(player, ItemModels.bow())
	elseif not g.bow then
		removeTool(player, "Bow")
	end
	if g.apples > 0 and not hasTool(player, "Storm Apple") then
		giveTool(player, ItemModels.apple())
	elseif g.apples <= 0 then
		removeTool(player, "Storm Apple")
	end
	if g.pearls > 0 and not hasTool(player, "Wind Pearl") then
		giveTool(player, ItemModels.pearl())
	elseif g.pearls <= 0 then
		removeTool(player, "Wind Pearl")
	end
	publish(player)
end

-- Armor you can see: a chestplate with a team-colored emblem, shoulder
-- pauldrons, a belt, shin guards and a helmet with a plume in your team's
-- color. Cloth armor is a tunic and hood in your team's color; chain is
-- riveted grey plate; iron is polished steel; diamond is shining crystal.
local ARMOR_LOOK: { [string]: { color: Color3?, material: Enum.Material, reflectance: number, trim: Color3 } } = {
	Cloth = { color = nil, material = Enum.Material.Fabric, reflectance = 0, trim = Color3.fromRGB(90, 70, 50) },
	Chain = {
		color = Color3.fromRGB(150, 152, 158),
		material = Enum.Material.DiamondPlate,
		reflectance = 0.05,
		trim = Color3.fromRGB(96, 98, 104),
	},
	Iron = {
		color = Color3.fromRGB(205, 208, 214),
		material = Enum.Material.Metal,
		reflectance = 0.15,
		trim = Color3.fromRGB(150, 120, 60),
	},
	Diamond = {
		color = Color3.fromRGB(110, 225, 240),
		material = Enum.Material.Glass,
		reflectance = 0.25,
		trim = Color3.fromRGB(230, 250, 255),
	},
}

local function dressArmor(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local old = character:FindFirstChild("MatchArmor")
	if old then
		old:Destroy()
	end
	local team = MatchService.teamOf(player)
	local teamColor = if team then team.info.color else Color3.new(1, 1, 1)
	local armor = MatchData.Armor[gearOf(player).armor]
	local look = ARMOR_LOOK[armor.key] or ARMOR_LOOK.Cloth
	local color = look.color or teamColor
	local folder = Instance.new("Folder")
	folder.Name = "MatchArmor"
	local function plate(to: BasePart?, size: Vector3, offset: CFrame, overrides: { [string]: any }?): Part?
		if not to then
			return nil
		end
		local p = Instance.new("Part")
		p.Size = size
		p.CFrame = to.CFrame * offset
		p.Color = color
		p.Material = look.material
		p.Reflectance = look.reflectance
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		local extra: { [string]: any } = overrides or {}
		for key, value in extra do
			(p :: any)[key] = value
		end
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = to
		weld.Part1 = p
		weld.Parent = p
		p.Parent = folder
		return p
	end
	local function find(...: string): BasePart?
		for _, name in { ... } do
			local found = character:FindFirstChild(name)
			if found and found:IsA("BasePart") then
				return found
			end
		end
		return nil
	end
	local torso = find("UpperTorso", "Torso")
	local lower = find("LowerTorso")
	local head = find("Head")
	if torso then
		local size = torso.Size
		plate(torso, size + Vector3.new(0.18, 0.08, 0.18), CFrame.new())
		-- A raised ridge down the middle and a team emblem on the chest.
		plate(torso, Vector3.new(0.2, size.Y * 0.8, 0.12), CFrame.new(0, 0, -size.Z / 2 - 0.12), { Color = look.trim })
		plate(
			torso,
			Vector3.new(0.5, 0.5, 0.08),
			CFrame.new(0, size.Y * 0.15, -size.Z / 2 - 0.17) * CFrame.Angles(0, 0, math.rad(45)),
			{ Color = teamColor, Material = Enum.Material.SmoothPlastic, Reflectance = 0 }
		)
	end
	-- Rounded pauldrons on the shoulders.
	for _, arm in { find("RightUpperArm", "Right Arm"), find("LeftUpperArm", "Left Arm") } do
		if arm then
			local size = arm.Size
			local pauldron =
				plate(arm, Vector3.new(size.X + 0.35, 0.55, size.Z + 0.35), CFrame.new(0, size.Y * 0.35, 0))
			if pauldron then
				local mesh = Instance.new("SpecialMesh")
				mesh.MeshType = Enum.MeshType.Sphere
				mesh.Parent = pauldron
			end
			plate(
				arm,
				Vector3.new(size.X + 0.12, 0.12, size.Z + 0.12),
				CFrame.new(0, size.Y * 0.12, 0),
				{ Color = look.trim }
			)
		end
	end
	if lower then
		plate(lower, Vector3.new(lower.Size.X + 0.2, 0.35, lower.Size.Z + 0.2), CFrame.new(0, 0, 0), {
			Color = Color3.fromRGB(70, 50, 36),
			Material = Enum.Material.Fabric,
			Reflectance = 0,
		})
		plate(lower, Vector3.new(0.4, 0.3, 0.1), CFrame.new(0, 0, -lower.Size.Z / 2 - 0.13), { Color = look.trim })
	end
	for _, shin in { find("RightLowerLeg", "Right Leg"), find("LeftLowerLeg", "Left Leg") } do
		if shin then
			plate(
				shin,
				Vector3.new(shin.Size.X + 0.12, shin.Size.Y * 0.7, 0.2),
				CFrame.new(0, 0, -shin.Size.Z / 2 - 0.05)
			)
		end
	end
	if head then
		local size = head.Size
		if armor.key == "Cloth" then
			-- A soft hood.
			local hood = plate(head, size + Vector3.new(0.25, 0.1, 0.25), CFrame.new(0, 0.12, 0.08))
			if hood then
				local mesh = Instance.new("SpecialMesh")
				mesh.MeshType = Enum.MeshType.Sphere
				mesh.Scale = Vector3.new(1, 1, 1)
				mesh.Parent = hood
			end
		else
			-- A domed helmet with a brow band, a nose guard and a plume.
			local dome =
				plate(head, Vector3.new(size.X + 0.3, size.Y * 0.8, size.Z + 0.3), CFrame.new(0, size.Y * 0.25, 0))
			if dome then
				local mesh = Instance.new("SpecialMesh")
				mesh.MeshType = Enum.MeshType.Sphere
				mesh.Parent = dome
			end
			plate(
				head,
				Vector3.new(size.X + 0.32, 0.18, size.Z + 0.32),
				CFrame.new(0, size.Y * 0.1, 0),
				{ Color = look.trim }
			)
			plate(head, Vector3.new(0.14, size.Y * 0.45, 0.12), CFrame.new(0, -size.Y * 0.05, -size.Z / 2 - 0.12))
			plate(head, Vector3.new(0.18, 0.7, 0.9), CFrame.new(0, size.Y * 0.75, 0.1), {
				Color = teamColor,
				Material = Enum.Material.Fabric,
				Reflectance = 0,
			})
		end
	end
	if armor.key == "Diamond" then
		local chest = folder:FindFirstChildWhichIsA("BasePart")
		if chest then
			local sparkles = Instance.new("Sparkles")
			sparkles.SparkleColor = Color3.fromRGB(200, 250, 255)
			sparkles.Parent = chest
		end
	end
	folder.Parent = character
end

---------------------------------------------------------------------------
-- Damage
---------------------------------------------------------------------------

local function damage(victim: Player, attacker: Player, amount: number, push: Vector3)
	local humanoid = humanoidOf(victim)
	local character = victim.Character
	if not humanoid or humanoid.Health <= 0 or not character or character:FindFirstChildOfClass("ForceField") then
		return
	end
	local armor = MatchData.Armor[gearOf(victim).armor]
	local protection = MatchService.upgradeLevel(victim, "Protection")
	local taken = math.max(0.3, armor.taken - 0.06 * protection)
	MatchService.recordHit(victim, attacker)
	humanoid:TakeDamage(amount * taken)
	CombatService.Attacked:Fire(attacker)
	Juice.knock(victim, push * WeatherService.knockbackMultiplier())
	Juice.sound(victim, "zap")
	Juice.sound(attacker, "pop")
end

local function arrowEffect(player: Player): string?
	local data = DataService.get(player)
	return data and data.cosmetics.fx
end

local function onSwing(player: Player, aim: any)
	if not MatchService.isPlaying(player) or not (player.Character and player.Character:FindFirstChild("Sword")) then
		return
	end
	if os.clock() - (lastSwing[player] or 0) < Config.Match.HitCooldown then
		return
	end
	lastSwing[player] = os.clock()
	local root = rootOf(player)
	if not root then
		return
	end
	-- Hit the closest enemy in front of you.
	local best: Player? = nil
	local bestDistance = Config.Match.SwordRange
	for _, other in Players:GetPlayers() do
		local otherRoot = rootOf(other)
		if other ~= player and otherRoot and MatchService.isEnemy(player, other) and MatchService.isPlaying(other) then
			local offset = otherRoot.Position - root.Position
			local distance = offset.Magnitude
			local facing = root.CFrame.LookVector:Dot(offset.Unit)
			if distance <= bestDistance and facing > 0.2 then
				best, bestDistance = other, distance
			end
		end
	end
	if best then
		local sword = MatchData.Swords[gearOf(player).sword]
		local amount = sword.damage + 4 * MatchService.upgradeLevel(player, "Sharpness")
		local otherRoot = rootOf(best) :: BasePart
		local flat = (otherRoot.Position - root.Position) * Vector3.new(1, 0, 1)
		local direction = if flat.Magnitude > 0.1 then flat.Unit else root.CFrame.LookVector
		damage(best, player, amount, direction * Config.Match.Knockback + Vector3.new(0, 14, 0))
		return
	end
	-- Nobody there: maybe a block.
	if typeof(aim) == "Vector3" then
		BlockService.hit(player, aim)
	end
end

local function arrow(from: Vector3, to: Vector3, effect: string?)
	local distance = (to - from).Magnitude
	local model = ItemModels.arrow(effect)
	local shaft = model.PrimaryPart :: BasePart
	-- Models face -Z; the arrow's point is at its -Z end.
	shaft.CFrame = CFrame.lookAt(from, to)
	model.Parent = workspace
	local tween = TweenService:Create(shaft, TweenInfo.new(math.max(0.05, distance / 180), Enum.EasingStyle.Linear), {
		CFrame = CFrame.lookAt(to, to + (to - from).Unit),
	})
	tween:Play()
	-- It sticks where it lands for a moment.
	Debris:AddItem(model, distance / 180 + 3)
end

local function onShoot(player: Player, aim: any)
	local g = gearOf(player)
	if not MatchService.isPlaying(player) or typeof(aim) ~= "Vector3" or not g.bow or g.arrows <= 0 then
		if MatchService.isPlaying(player) and g.bow and g.arrows <= 0 then
			Notify.player(player, "🏹 Out of arrows! Buy more in the Item Shop.", "warn")
		end
		return
	end
	if not (player.Character and player.Character:FindFirstChild("Bow")) then
		return
	end
	if os.clock() - (lastShot[player] or 0) < Config.Match.BowCooldown then
		return
	end
	lastShot[player] = os.clock()
	local root = rootOf(player)
	if not root then
		return
	end
	g.arrows -= 1
	publish(player)
	local origin = root.Position + Vector3.new(0, 1.5, 0)
	local direction = aim - origin
	if direction.Magnitude < 0.1 then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance }
	local result = workspace:Raycast(origin, direction.Unit * Config.Match.BowRange, params)
	local hitPoint = if result then result.Position else origin + direction.Unit * Config.Match.BowRange
	arrow(origin, hitPoint, arrowEffect(player))
	if result then
		local model = result.Instance:FindFirstAncestorOfClass("Model")
		local victim = model and Players:GetPlayerFromCharacter(model)
		if victim and MatchService.isEnemy(player, victim) and MatchService.isPlaying(victim) then
			damage(victim, player, Config.Match.BowDamage, direction.Unit * 18 + Vector3.new(0, 10, 0))
		end
	end
end

local function onUse(player: Player, key: any, aim: any)
	local g = gearOf(player)
	if not MatchService.isPlaying(player) then
		return
	end
	if key == "StormApple" and g.apples > 0 then
		local humanoid = humanoidOf(player)
		if humanoid and humanoid.Health > 0 then
			g.apples -= 1
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + Config.Match.AppleHeal)
			Juice.sound(player, "chime")
			refreshTools(player)
		end
	elseif key == "WindPearl" and g.pearls > 0 and typeof(aim) == "Vector3" then
		local root = rootOf(player)
		if not root then
			return
		end
		local offset = aim - root.Position
		if offset.Magnitude > Config.Match.PearlRange then
			aim = root.Position + offset.Unit * Config.Match.PearlRange
		end
		g.pearls -= 1
		refreshTools(player)
		local target: Vector3 = aim
		task.delay(0.5, function()
			local character = player.Character
			if character and MatchService.isPlaying(player) then
				character:PivotTo(CFrame.new(target + Vector3.new(0, 3, 0)))
				Juice.sound(player, "chime")
			end
		end)
	end
end

-- Hurts an enemy with armor and upgrades counted (explosions use this).
function CombatService.hurt(victim: Player, attacker: Player, amount: number, push: Vector3)
	if victim == attacker or MatchService.isEnemy(attacker, victim) then
		damage(victim, attacker, if victim == attacker then amount * 0.3 else amount, push)
	end
end

---------------------------------------------------------------------------
-- Shop hooks (used by ItemShopService)
---------------------------------------------------------------------------

-- Why a weapon, armor or item can't be given right now (nil if it can).
function CombatService.check(player: Player, key: string): string?
	local g = gearOf(player)
	local swordTier = MatchData.swordTier(key)
	local armorTier = MatchData.armorTier(key)
	if swordTier and g.sword >= swordTier then
		return "You already have a sword that good!"
	elseif armorTier and g.armor >= armorTier then
		return "You already have armor that good!"
	elseif key == "Bow" and g.bow then
		return "You already have a bow."
	elseif key == "Arrows" and not g.bow then
		return "Buy a bow first!"
	elseif
		not swordTier
		and not armorTier
		and key ~= "Bow"
		and key ~= "Arrows"
		and key ~= "StormApple"
		and key ~= "WindPearl"
	then
		return "Unknown item."
	end
	return nil
end

-- Gives a weapon, armor or item. Returns an error message if it can't.
function CombatService.give(player: Player, key: string, amount: number?): string?
	local problem = CombatService.check(player, key)
	if problem then
		return problem
	end
	local g = gearOf(player)
	local swordTier = MatchData.swordTier(key)
	local armorTier = MatchData.armorTier(key)
	if swordTier then
		g.sword = swordTier
	elseif armorTier then
		g.armor = armorTier
		dressArmor(player)
	elseif key == "Bow" then
		g.bow = true
	elseif key == "Arrows" then
		g.arrows += amount or 8
	elseif key == "StormApple" then
		g.apples += 1
	elseif key == "WindPearl" then
		g.pearls += 1
	end
	refreshTools(player)
	return nil
end

function CombatService.start()
	Remotes.event("Swing").OnServerEvent:Connect(onSwing)
	Remotes.event("ShootBow").OnServerEvent:Connect(onShoot)
	Remotes.event("UseItem").OnServerEvent:Connect(onUse)

	MatchService.PlayerSpawned:Connect(function(player)
		-- Everything but armor resets when you respawn.
		local g = gearOf(player)
		g.sword = 1
		g.bow = false
		g.arrows = 0
		g.apples = 0
		g.pearls = 0
		task.wait(0.1)
		refreshTools(player)
		dressArmor(player)
	end)
	-- A new sword skin shows right away.
	CosmeticService.Changed:Connect(function(player, category)
		if category == "sword" and gear[player] and MatchService.isPlaying(player) then
			refreshTools(player)
		end
	end)
	MatchService.MatchEnded:Connect(function()
		for player in gear do
			for _, name in ITEM_TOOLS do
				removeTool(player, name)
			end
			for _, attribute in { "SwordTier", "ArmorTier", "Arrows", "Apples", "Pearls" } do
				player:SetAttribute(attribute, nil)
			end
		end
		gear = {}
	end)
	Players.PlayerRemoving:Connect(function(player)
		gear[player] = nil
		lastSwing[player] = nil
		lastShot[player] = nil
	end)
end

return CombatService
