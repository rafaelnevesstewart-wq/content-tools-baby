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
local SkinData = require(Shared.SkinData)

local Modules = script.Parent.Parent.Modules
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

local function handlePart(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Name = "Handle"
	p.CanCollide = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

local function makeSword(tier: number, skin: string?): Tool
	local sword = MatchData.Swords[tier]
	local tool = Instance.new("Tool")
	tool.Name = "Sword"
	tool.ToolTip = sword.name .. " (" .. sword.damage .. " damage)"
	tool.CanBeDropped = false
	tool.Grip = CFrame.new(0, 0, -1.5, 0, 0, 1, 1, 0, 0, 0, 1, 0)
	local blade = handlePart({ Size = Vector3.new(0.3, 0.8, 4), Color = sword.color, Material = sword.material })
	SkinData.applySword(blade, skin) -- the Sword Skin cosmetic
	blade.Parent = tool
	-- The guard always shows the tier, whatever the skin.
	local guard = handlePart({
		Name = "Guard",
		Size = Vector3.new(0.4, 1.8, 0.3),
		Color = sword.color,
		Material = sword.material,
	})
	guard.CFrame = blade.CFrame * CFrame.new(0, 0, 1.4)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = blade
	weld.Part1 = guard
	weld.Parent = guard
	guard.Parent = tool
	return tool
end

local function simpleTool(name: string, tip: string, size: Vector3, color: Color3, material: Enum.Material): Tool
	local tool = Instance.new("Tool")
	tool.Name = name
	tool.ToolTip = tip
	tool.CanBeDropped = false
	handlePart({ Size = size, Color = color, Material = material, Shape = Enum.PartType.Block }).Parent = tool
	return tool
end

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
	local newSword = makeSword(g.sword, data and data.cosmetics.sword)
	giveTool(player, newSword)
	if wasHolding then
		local humanoid = humanoidOf(player)
		if humanoid then
			humanoid:EquipTool(newSword)
		end
	end
	if g.bow and not hasTool(player, "Bow") then
		giveTool(
			player,
			simpleTool(
				"Bow",
				"Click to shoot (needs arrows)",
				Vector3.new(0.3, 3.4, 0.3),
				Color3.fromRGB(120, 86, 58),
				Enum.Material.Wood
			)
		)
	elseif not g.bow then
		removeTool(player, "Bow")
	end
	if g.apples > 0 and not hasTool(player, "Storm Apple") then
		local apple = simpleTool(
			"Storm Apple",
			"Eat to heal 40",
			Vector3.one * 0.9,
			Color3.fromRGB(210, 40, 40),
			Enum.Material.SmoothPlastic
		)
		apple.Handle.Shape = Enum.PartType.Ball
		giveTool(player, apple)
	elseif g.apples <= 0 then
		removeTool(player, "Storm Apple")
	end
	if g.pearls > 0 and not hasTool(player, "Wind Pearl") then
		local pearl = simpleTool(
			"Wind Pearl",
			"Throw to teleport where it lands",
			Vector3.one * 0.8,
			Color3.fromRGB(150, 90, 230),
			Enum.Material.Neon
		)
		pearl.Handle.Shape = Enum.PartType.Ball
		giveTool(player, pearl)
	elseif g.pearls <= 0 then
		removeTool(player, "Wind Pearl")
	end
	publish(player)
end

-- Armor you can see: a chest plate and helmet in the tier's color (cloth is
-- your team's color).
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
	local armor = MatchData.Armor[gearOf(player).armor]
	local color = armor.color or (if team then team.info.color else Color3.new(1, 1, 1))
	local folder = Instance.new("Folder")
	folder.Name = "MatchArmor"
	local function plate(to: BasePart?, size: Vector3, offset: CFrame)
		if not to then
			return
		end
		local p = Instance.new("Part")
		p.Size = size
		p.CFrame = to.CFrame * offset
		p.Color = color
		p.Material = if armor.key == "Cloth" then Enum.Material.Fabric else Enum.Material.Metal
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = to
		weld.Part1 = p
		weld.Parent = p
		p.Parent = folder
	end
	local torso = (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) :: BasePart?
	local head = character:FindFirstChild("Head") :: BasePart?
	if torso then
		plate(torso, torso.Size + Vector3.new(0.15, 0.1, 0.15), CFrame.new())
	end
	if head then
		plate(head, Vector3.new(head.Size.X + 0.2, 0.5, head.Size.Z + 0.2), CFrame.new(0, head.Size.Y / 2, 0))
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

local function beamColor(player: Player): Color3
	local data = DataService.get(player)
	return SkinData.beam(data and data.cosmetics.fx).color
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

local function arrow(from: Vector3, to: Vector3, color: Color3)
	local distance = (to - from).Magnitude
	local shaft = Instance.new("Part")
	shaft.Anchored = true
	shaft.CanCollide = false
	shaft.CanQuery = false
	shaft.CanTouch = false
	shaft.Size = Vector3.new(0.15, 0.15, 2)
	shaft.Color = color
	shaft.Material = Enum.Material.Neon
	shaft.CFrame = CFrame.lookAt(from, to)
	shaft.Parent = workspace
	local tween = TweenService:Create(shaft, TweenInfo.new(math.max(0.05, distance / 180), Enum.EasingStyle.Linear), {
		CFrame = CFrame.lookAt(to, to + (to - from).Unit),
	})
	tween:Play()
	Debris:AddItem(shaft, distance / 180 + 0.3)
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
	arrow(origin, hitPoint, beamColor(player))
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
