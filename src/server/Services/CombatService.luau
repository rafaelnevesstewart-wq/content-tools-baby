-- Weapons, spells, player health and PvP.
-- Clients only say "I attacked with X towards direction D" or "I cast Y";
-- the server checks cooldowns, ownership and range, then applies damage.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Util = require(ReplicatedStorage.Shared.Util)

local CombatService = {}
local S

local cooldowns = {} -- [Player] = { [key] = os.clock() when ready }
local shields = {} -- [Player] = { Amount, Until, Visual }
local lastHit = {} -- [Player] = { Attacker, Source, At }
local power = {} -- [Player] = current power (mana)
local recentKills = {} -- [killer] = { [victim UserId] = os.clock() of last rewarded kill }
local rng = Random.new()
local effectsFolder

local ARC_DOT = 0.35 -- how wide a melee swing is (dot product with facing)
local AIM_DOT = 0.96 -- how close to the aim line a ranged shot must be

-- Helpers ----------------------------------------------------------------------

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function ready(player: Player, key: string, cooldown: number): boolean
	local list = cooldowns[player]
	if not list then
		list = {}
		cooldowns[player] = list
	end
	local now = os.clock()
	if (list[key] or 0) > now then
		return false
	end
	list[key] = now + cooldown
	return true
end

local function upgradeLevel(player: Player, key: string): number
	local profile = S.PlayerService:GetProfile(player)
	return profile and profile.Upgrades[key] or 0
end

local function levelOf(player: Player): number
	local profile = S.PlayerService:GetProfile(player)
	return profile and profile.Level or 1
end

local function damageMult(player: Player): number
	return 1 + upgradeLevel(player, "Strength") * 0.1 + (levelOf(player) - 1) * Config.Leveling.DamagePerLevel
end

-- Strength as shown on the HUD: 100 = normal damage.
function CombatService:Strength(player: Player): number
	return math.floor(damageMult(player) * 100 + 0.5)
end

function CombatService:MaxPower(player: Player): number
	return Config.Power.Base + (levelOf(player) - 1) * Config.Leveling.PowerPerLevel
end

local function setPower(player: Player, amount: number)
	local maxPower = CombatService:MaxPower(player)
	power[player] = math.clamp(amount, 0, maxPower)
	player:SetAttribute("Power", math.floor(power[player]))
	player:SetAttribute("MaxPower", maxPower)
end

function CombatService:RefillOnLevelUp(player: Player)
	setPower(player, self:MaxPower(player))
	local humanoid = humanoidOf(player)
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = humanoid.MaxHealth
	end
end

function CombatService:InSafeZone(position: Vector3): boolean
	return Vector3.new(position.X, 0, position.Z).Magnitude < Config.Combat.SafeZoneRadius
end

-- Every living thing the attacker could hit: monsters and (for PvP) players.
local function targets(attacker: Player)
	local list = {}
	for _, monster in S.MonsterService:All() do
		table.insert(list, { Monster = monster, Position = monster.Root.Position, Radius = monster.Radius })
	end
	if Config.Combat.PvPEnabled then
		for _, other in Players:GetPlayers() do
			local hrp = rootOf(other)
			local humanoid = humanoidOf(other)
			if other ~= attacker and hrp and humanoid and humanoid.Health > 0 then
				table.insert(list, { Player = other, Position = hrp.Position, Radius = 2 })
			end
		end
	end
	return list
end

local function effectPart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	for key, value in props do
		p[key] = value
	end
	p.Parent = effectsFolder
	return p
end

local function fade(p: BasePart, duration: number, props)
	props = props or {}
	props.Transparency = 1
	TweenService:Create(p, TweenInfo.new(duration), props):Play()
	Debris:AddItem(p, duration + 0.1)
end

local function projectile(from: Vector3, to: Vector3, color: Color3, size: number, speed: number): number
	local travel = math.max(0.05, (to - from).Magnitude / speed)
	local ball = effectPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * size, Color = color, Position = from })
	TweenService:Create(ball, TweenInfo.new(travel, Enum.EasingStyle.Linear), { Position = to }):Play()
	Debris:AddItem(ball, travel + 0.05)
	return travel
end

local function burst(position: Vector3, radius: number, color: Color3)
	local sphere = effectPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 2, Color = color, Position = position, Transparency = 0.2 })
	fade(sphere, 0.45, { Size = Vector3.one * radius * 2 })
end

-- Damage -------------------------------------------------------------------------

-- Damages a player. attacker is the player responsible (nil for monsters).
function CombatService:DamagePlayer(victim: Player, amount: number, attacker: Player?, sourceName: string?)
	local humanoid = humanoidOf(victim)
	local hrp = rootOf(victim)
	if not humanoid or not hrp or humanoid.Health <= 0 then
		return
	end
	if victim.Character:FindFirstChildOfClass("ForceField") or self:InSafeZone(hrp.Position) then
		return
	end
	if attacker and (not Config.Combat.PvPEnabled or self:InSafeZone(rootOf(attacker) and rootOf(attacker).Position or hrp.Position)) then
		return
	end
	local shield = shields[victim]
	if shield and os.clock() < shield.Until then
		local absorbed = math.min(shield.Amount, amount)
		shield.Amount -= absorbed
		amount -= absorbed
		if shield.Amount <= 0 then
			self:_dropShield(victim)
		end
	end
	if amount <= 0 then
		return
	end
	lastHit[victim] = { Attacker = attacker, Source = sourceName, At = os.clock() }
	humanoid.Health = math.max(0, humanoid.Health - amount)
	Remotes.Ui:FireClient(victim, { Hurt = amount })
end

-- Lands one hit: rolls a critical, shows the damage number to the attacker,
-- and makes monsters flinch back from the blow.
local function hit(target, amount: number, attacker: Player)
	local crit = rng:NextNumber() < Config.Combat.CritChance
	if crit then
		amount *= Config.Combat.CritMult
	end
	amount = math.floor(amount + 0.5)
	if target.Monster then
		local monster = target.Monster
		if monster.Health <= 0 then
			return
		end
		local from = rootOf(attacker)
		local killed = S.MonsterService:Damage(monster, amount, attacker)
		if not killed then
			S.MonsterService:Flinch(monster, from and from.Position or nil, crit and 4 or 2)
		end
	elseif target.Player then
		local humanoid = humanoidOf(target.Player)
		local before = humanoid and humanoid.Health or 0
		CombatService:DamagePlayer(target.Player, amount, attacker)
		if not humanoid or humanoid.Health >= before then
			return -- blocked (safe zone, spawn shield, stone shield)
		end
	end
	Remotes.Ui:FireClient(attacker, { Hit = { Position = target.Position, Amount = amount, Crit = crit } })
end

-- Weapons ----------------------------------------------------------------------

local function buildTool(def)
	local tool = Instance.new("Tool")
	tool.Name = def.Name
	tool.CanBeDropped = false
	tool.ToolTip = def.Description
	tool:SetAttribute("WeaponKey", def.Key)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.5, 1.4, 0.5)
	handle.Color = Color3.fromRGB(70, 45, 30)
	handle.Material = Enum.Material.Wood
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	local function piece(size: Vector3, offset: CFrame, color: Color3, material: Enum.Material)
		local p = Instance.new("Part")
		p.Size = size
		p.Color = color
		p.Material = material
		p.CanCollide = false
		p.Massless = true
		p.CFrame = handle.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = p
		weld.Parent = p
		p.Parent = tool
		return p
	end

	local material = Enum.Material.Metal
	if def.Key == "Blade" then
		piece(Vector3.new(0.2, 4, 0.7), CFrame.new(0, 2.7, 0), def.Color, Enum.Material.Metal)
		piece(Vector3.new(1.6, 0.3, 0.4), CFrame.new(0, 0.75, 0), Color3.fromRGB(110, 90, 50), Enum.Material.Metal)
	elseif def.Key == "Sling" then
		piece(Vector3.new(1.4, 0.3, 0.3), CFrame.new(0, 0.9, 0), def.Color, Enum.Material.Fabric)
	elseif def.Key == "Crossbow" then
		piece(Vector3.new(0.4, 0.4, 3), CFrame.new(0, 0.6, -1), def.Color, Enum.Material.Marble)
		piece(Vector3.new(3, 0.25, 0.3), CFrame.new(0, 0.6, -2), def.Color, Enum.Material.Marble)
	elseif def.Key == "Cleaver" then
		handle.Size = Vector3.new(0.5, 3, 0.5)
		piece(Vector3.new(0.3, 2.4, 2.6), CFrame.new(0, 1.8, -1.2), def.Color, Enum.Material.Metal)
	elseif def.Key == "Spear" then
		handle.Size = Vector3.new(0.35, 6, 0.35)
		piece(Vector3.new(0.3, 1.6, 0.6), CFrame.new(0, 3.7, 0), def.Color, material)
	elseif def.Key == "Maul" then
		handle.Size = Vector3.new(0.5, 3.4, 0.5)
		piece(Vector3.new(2.4, 1.6, 1.6), CFrame.new(0, 2.2, 0), Color3.fromRGB(70, 75, 85), Enum.Material.Metal)
		piece(Vector3.new(2.5, 0.3, 1.7), CFrame.new(0, 2.2, 0), def.Color, Enum.Material.Neon)
	elseif def.Key == "Greatsword" then
		handle.Size = Vector3.new(0.45, 2, 0.45)
		piece(Vector3.new(0.3, 6, 1.1), CFrame.new(0, 4, 0), def.Color, Enum.Material.Metal)
		piece(Vector3.new(0.35, 5.6, 0.2), CFrame.new(0, 4, 0), Color3.fromRGB(200, 200, 205), Enum.Material.Metal)
		piece(Vector3.new(2.6, 0.4, 0.5), CFrame.new(0, 1, 0), Color3.fromRGB(120, 90, 30), Enum.Material.Metal)
	elseif def.Key == "Reaper" then
		handle.Size = Vector3.new(0.4, 5, 0.4)
		piece(Vector3.new(0.2, 0.8, 3.6), CFrame.new(0, 2.6, -1.6) * CFrame.Angles(0.3, 0, 0), def.Color, material)
	end
	return tool
end

function CombatService:GiveWeapons(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local profile = S.PlayerService:GetProfile(player)
	if not backpack or not profile then
		return
	end
	local character = player.Character
	for _, def in Config.Weapons do
		local owned = def.Currency == "Free" or table.find(profile.Weapons, def.Key)
		local has = backpack:FindFirstChild(def.Name) or (character and character:FindFirstChild(def.Name))
		if owned and not has then
			buildTool(def).Parent = backpack
		end
	end
end

function CombatService:ApplyStats(player: Player)
	local humanoid = humanoidOf(player)
	if not humanoid then
		return
	end
	local maxHealth = Config.Combat.BaseHealth + upgradeLevel(player, "Armor") * 20 + (levelOf(player) - 1) * Config.Leveling.HealthPerLevel
	local wasFull = humanoid.Health >= humanoid.MaxHealth - 0.01
	humanoid.MaxHealth = maxHealth
	if wasFull then
		humanoid.Health = maxHealth
	end
	humanoid.WalkSpeed = Config.Combat.BaseWalkSpeed + upgradeLevel(player, "Swiftness") * 1.5
end

function CombatService:OnCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	humanoid.BreakJointsOnDeath = false -- we ragdoll the body instead (see _onDied)
	self:ApplyStats(player)
	humanoid.Health = humanoid.MaxHealth
	setPower(player, self:MaxPower(player))
	self:GiveWeapons(player)
	local forceField = Instance.new("ForceField")
	forceField.Visible = true
	forceField.Parent = character
	Debris:AddItem(forceField, Config.Combat.SpawnProtection)
	humanoid.Died:Connect(function()
		self:_onDied(player, character)
	end)
end

-- The body goes limp, darkens and crumbles into smoke.
local function ragdoll(character: Model)
	for _, motor in character:GetDescendants() do
		if motor:IsA("Motor6D") and motor.Part0 and motor.Part1 then
			local a0 = Instance.new("Attachment")
			a0.CFrame = motor.C0
			a0.Parent = motor.Part0
			local a1 = Instance.new("Attachment")
			a1.CFrame = motor.C1
			a1.Parent = motor.Part1
			local socket = Instance.new("BallSocketConstraint")
			socket.Attachment0 = a0
			socket.Attachment1 = a1
			socket.LimitsEnabled = true
			socket.TwistLimitsEnabled = true
			socket.Parent = motor.Part1
			motor.Enabled = false
		end
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.AssemblyLinearVelocity += hrp.CFrame.LookVector * -18 + Vector3.new(0, 10, 0)
		local smoke = Instance.new("ParticleEmitter")
		smoke.Color = ColorSequence.new(Color3.fromRGB(40, 10, 10), Color3.fromRGB(15, 15, 15))
		smoke.Size = NumberSequence.new(1.5, 4)
		smoke.Transparency = NumberSequence.new(0.3, 1)
		smoke.Lifetime = NumberRange.new(1.5, 2.5)
		smoke.Speed = NumberRange.new(1, 3)
		smoke.Rate = 25
		smoke.SpreadAngle = Vector2.new(180, 180)
		smoke.Parent = hrp
	end
	task.delay(1, function()
		for _, p in character:GetDescendants() do
			if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
				TweenService:Create(p, TweenInfo.new(Config.Combat.RespawnTime - 1.5), { Color = Color3.fromRGB(20, 18, 18), Transparency = 0.6 }):Play()
			end
		end
	end)
end

function CombatService:_onDied(victim: Player, character: Model)
	S.StealService:DropCarried(victim, "knocked out")
	self:_dropShield(victim)
	pcall(ragdoll, character)
	local last = lastHit[victim]
	lastHit[victim] = nil
	local recent = last and os.clock() - last.At <= 10
	local by = nil
	if recent and last.Attacker then
		by = last.Attacker.DisplayName
	elseif recent and last.Source then
		by = "a " .. last.Source
	end
	Remotes.Ui:FireClient(victim, { Died = { By = by, Respawn = Config.Combat.RespawnTime } })
	if not recent or not last.Attacker or not last.Attacker.Parent then
		return
	end
	local killer = last.Attacker
	-- No reward for farming the same player over and over.
	local killerLog = recentKills[killer] or {}
	recentKills[killer] = killerLog
	local lastKill = killerLog[victim.UserId]
	if lastKill and os.clock() - lastKill < Config.Combat.PvPRepeatCooldown then
		S.PlayerService:Notify(killer, string.format("You defeated %s again. No reward for a while: find new rivals!", victim.DisplayName))
		return
	end
	killerLog[victim.UserId] = os.clock()
	local victimProfile = S.PlayerService:GetProfile(victim)
	local reward = Config.Combat.KillRewardBase + (victimProfile and victimProfile.Stage or 1) * Config.Combat.KillRewardPerStage
	S.PlayerService:AddCoins(killer, reward)
	local killerProfile = S.PlayerService:GetProfile(killer)
	if killerProfile then
		killerProfile.Kills += 1
	end
	local xp = Config.Leveling.PlayerKillXP + (victimProfile and victimProfile.Level or 1) * Config.Leveling.PlayerKillXPPerLevel
	S.PlayerService:Notify(killer, string.format("You defeated %s! +%d coins, +%d XP", victim.DisplayName, reward, xp))
	S.PlayerService:AddXP(killer, xp)
	S.PlayerService:Notify(victim, string.format("%s defeated you.", killer.DisplayName))
end

-- Swings the sword arm (or raises it to shoot) by turning the shoulder joint.
-- Done on the server so every player sees it.
local swinging = {} -- [Motor6D] = true while mid-swing
local function swingArm(character: Model, ranged: boolean, duration: number)
	local motor = character:FindFirstChild("RightShoulder", true) or character:FindFirstChild("Right Shoulder", true)
	if not motor or not motor:IsA("Motor6D") or swinging[motor] then
		return
	end
	swinging[motor] = true
	local rest = motor.C0
	local steps
	if ranged then
		-- Arm up to aim, a small kick back as it fires, then down.
		steps = {
			{ rest * CFrame.Angles(math.rad(90), 0, 0), 0.25 },
			{ rest * CFrame.Angles(math.rad(100), 0, 0), 0.15 },
			{ rest, 0.6 },
		}
	else
		-- Wind up over the shoulder, chop down across the body, recover.
		steps = {
			{ rest * CFrame.Angles(math.rad(150), 0, math.rad(-25)), 0.3 },
			{ rest * CFrame.Angles(math.rad(-15), 0, math.rad(35)), 0.25 },
			{ rest, 0.45 },
		}
	end
	task.spawn(function()
		for _, step in steps do
			local tween = TweenService:Create(motor, TweenInfo.new(duration * step[2], Enum.EasingStyle.Quad), { C0 = step[1] })
			tween:Play()
			tween.Completed:Wait()
			if not motor.Parent then
				break
			end
		end
		motor.C0 = rest
		swinging[motor] = nil
	end)
end

function CombatService:Attack(player: Player, arg)
	if type(arg) ~= "table" or type(arg.Key) ~= "string" then
		return
	end
	local def = Util.find(Config.Weapons, "Key", arg.Key)
	local character = player.Character
	local hrp = rootOf(player)
	local humanoid = humanoidOf(player)
	if not def or not hrp or not humanoid or humanoid.Health <= 0 then
		return
	end
	local tool = character:FindFirstChildOfClass("Tool")
	if not tool or tool:GetAttribute("WeaponKey") ~= def.Key then
		return
	end
	if not ready(player, "Weapon", def.Cooldown) then
		return
	end
	swingArm(character, def.Kind == "Ranged", math.min(def.Cooldown, 0.6))
	local damage = def.Damage * damageMult(player)
	local handle = tool:FindFirstChild("Handle")
	local origin = handle and handle.Position or hrp.Position

	if def.Kind == "Melee" then
		local facing = hrp.CFrame.LookVector
		-- Slash effect.
		local slash = effectPart({
			Size = Vector3.new(def.Range * 1.4, 0.2, 1.2),
			CFrame = hrp.CFrame * CFrame.new(0, 0.5, -def.Range * 0.5) * CFrame.Angles(0, 0, math.rad(25)),
			Color = def.Color,
			Transparency = 0.3,
		})
		fade(slash, 0.2)
		local aim = typeof(arg.Dir) == "Vector3" and Vector3.new(arg.Dir.X, 0, arg.Dir.Z) or facing
		aim = aim.Magnitude > 0.1 and aim.Unit or facing
		local hits, dealt = 0, 0
		for _, target in targets(player) do
			local offset = target.Position - hrp.Position
			local flat = Vector3.new(offset.X, 0, offset.Z)
			local direction = flat.Magnitude > 0.1 and flat.Unit or facing
			local distance = offset.Magnitude - target.Radius
			if distance <= def.Range + 1.5 and (direction:Dot(facing) > ARC_DOT or direction:Dot(aim) > ARC_DOT) then
				hit(target, damage, player)
				hits += 1
				dealt += damage
				if hits >= 3 and def.Key ~= "Cleaver" then
					break
				end
			end
		end
		if def.Shock then
			local center = hrp.Position + facing * def.Range * 0.6
			burst(center, 12, def.Color)
			for _, target in targets(player) do
				if (target.Position - center).Magnitude <= 12 + target.Radius then
					hit(target, damage * 0.5, player)
				end
			end
		end
		if def.Lifesteal and dealt > 0 then
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + dealt * def.Lifesteal)
		end
		return
	end

	-- Ranged: fire along the aim direction the client sent.
	local direction = typeof(arg.Dir) == "Vector3" and arg.Dir.Magnitude > 0.5 and arg.Dir.Unit or hrp.CFrame.LookVector
	local candidates = {}
	for _, target in targets(player) do
		local offset = target.Position - origin
		local distance = offset.Magnitude
		if distance <= def.Range + target.Radius and offset.Unit:Dot(direction) > AIM_DOT - target.Radius / math.max(distance, 1) then
			table.insert(candidates, { Target = target, Distance = distance })
		end
	end
	table.sort(candidates, function(a, b)
		return a.Distance < b.Distance
	end)
	local first = candidates[1]
	local endPoint = first and first.Target.Position or origin + direction * def.Range
	local travel = projectile(origin, endPoint, def.Color, def.Key == "Spear" and 1 or 0.6, 220)
	if not first then
		return
	end
	task.delay(travel, function()
		local pierce = def.Key == "Spear" and 3 or 1
		for i = 1, math.min(pierce, #candidates) do
			hit(candidates[i].Target, damage, player)
		end
	end)
end

-- Spells -------------------------------------------------------------------------

function CombatService:_dropShield(player: Player)
	local shield = shields[player]
	shields[player] = nil
	if shield and shield.Visual then
		shield.Visual:Destroy()
	end
end

local function spellPower(def, level: number, base: string, perLevel: string): number
	return def[base] + def[perLevel] * (level - 1)
end

function CombatService:Cast(player: Player, arg)
	if type(arg) ~= "table" or type(arg.Key) ~= "string" then
		return
	end
	local def = Util.find(Config.Spells, "Key", arg.Key)
	local profile = S.PlayerService:GetProfile(player)
	local hrp = rootOf(player)
	local humanoid = humanoidOf(player)
	if not def or not profile or not hrp or not humanoid or humanoid.Health <= 0 then
		return
	end
	local level = profile.Spells[def.Key] or 0
	if level <= 0 then
		S.PlayerService:Notify(player, def.Name .. " isn't unlocked yet. Get it in the Shop.")
		return
	end
	local have = power[player] or 0
	if have < def.PowerCost then
		S.PlayerService:Notify(player, string.format("Not enough power for %s (%d needed).", def.Name, def.PowerCost))
		return
	end
	if not ready(player, def.Key, def.Cooldown) then
		return
	end
	setPower(player, have - def.PowerCost)
	S.QuestService:Progress(player, "Spell", 1)
	local direction = typeof(arg.Dir) == "Vector3" and arg.Dir.Magnitude > 0.5 and arg.Dir.Unit or hrp.CFrame.LookVector
	local mult = damageMult(player)

	if def.Key == "Fireball" then
		local damage = spellPower(def, level, "Damage", "DamagePerLevel") * mult
		-- Land on the first thing along the aim line, or the ground at max range.
		local impact = hrp.Position + direction * def.Range
		local best = def.Range
		for _, target in targets(player) do
			local offset = target.Position - hrp.Position
			local along = offset:Dot(direction)
			if along > 0 and along < best and (offset - direction * along).Magnitude < target.Radius + 4 then
				best = along
				impact = target.Position
			end
		end
		local ray = workspace:Raycast(hrp.Position, impact - hrp.Position, RaycastParams.new())
		if ray and not ray.Instance:IsDescendantOf(player.Character) then
			impact = ray.Position
		end
		local travel = projectile(hrp.Position + Vector3.new(0, 2, 0), impact, def.Color, 2.2, 120)
		task.delay(travel, function()
			burst(impact, def.Radius, def.Color)
			for _, target in targets(player) do
				if (target.Position - impact).Magnitude <= def.Radius + target.Radius then
					hit(target, damage, player)
				end
			end
		end)
	elseif def.Key == "Lightning" then
		local damage = spellPower(def, level, "Damage", "DamagePerLevel") * mult
		local struck = {}
		local from = nil
		local best, bestScore = nil, -1
		for _, target in targets(player) do
			local offset = target.Position - hrp.Position
			if offset.Magnitude <= def.Range then
				local score = offset.Unit:Dot(direction)
				if score > 0.85 and score > bestScore then
					best, bestScore = target, score
				end
			end
		end
		local current = best
		for _ = 0, def.Chains do
			if not current then
				break
			end
			table.insert(struck, current)
			local top = from or (current.Position + Vector3.new(0, 60, 0))
			-- Zigzag bolt.
			local points = { top }
			for i = 1, 5 do
				local p = top:Lerp(current.Position, i / 6) + Vector3.new(math.random(-3, 3), 0, math.random(-3, 3))
				table.insert(points, p)
			end
			table.insert(points, current.Position)
			for i = 1, #points - 1 do
				local a, b = points[i], points[i + 1]
				local seg = effectPart({ Size = Vector3.new(0.5, 0.5, (b - a).Magnitude), CFrame = CFrame.lookAt((a + b) / 2, b), Color = def.Color })
				fade(seg, 0.35)
			end
			hit(current, damage, player)
			from = current.Position
			local nextTarget, nextDistance = nil, 45
			for _, candidate in targets(player) do
				local already = false
				for _, s in struck do
					if (s.Monster and s.Monster == candidate.Monster) or (s.Player and s.Player == candidate.Player) then
						already = true
					end
				end
				local d = (candidate.Position - current.Position).Magnitude
				if not already and d < nextDistance then
					nextTarget, nextDistance = candidate, d
				end
			end
			current = nextTarget
		end
		if #struck == 0 then
			S.PlayerService:Notify(player, "No target in sight for Lightning Strike.")
			cooldowns[player][def.Key] = os.clock() + 1
			setPower(player, (power[player] or 0) + def.PowerCost) -- refund
		end
	elseif def.Key == "FrostNova" then
		local damage = spellPower(def, level, "Damage", "DamagePerLevel") * mult
		local ring = effectPart({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1, 4, 4),
			CFrame = CFrame.new(hrp.Position - Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			Color = def.Color,
			Material = Enum.Material.Ice,
			Transparency = 0.2,
		})
		fade(ring, 0.6, { Size = Vector3.new(1, def.Radius * 2, def.Radius * 2) })
		for _, target in targets(player) do
			if (target.Position - hrp.Position).Magnitude <= def.Radius + target.Radius then
				hit(target, damage, player)
				if target.Monster then
					S.MonsterService:Stun(target.Monster, def.Stun)
				elseif target.Player then
					self:_freeze(target.Player, def.Stun)
				end
			end
		end
	elseif def.Key == "Shield" then
		self:_dropShield(player)
		local visual = Instance.new("Part")
		visual.Shape = Enum.PartType.Ball
		visual.Size = Vector3.one * 8
		visual.Color = def.Color
		visual.Material = Enum.Material.ForceField
		visual.CanCollide = false
		visual.CanQuery = false
		visual.Massless = true
		visual.CFrame = hrp.CFrame
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hrp
		weld.Part1 = visual
		weld.Parent = visual
		visual.Parent = player.Character
		shields[player] = { Amount = spellPower(def, level, "Absorb", "AbsorbPerLevel"), Until = os.clock() + def.Duration, Visual = visual }
		task.delay(def.Duration, function()
			local shield = shields[player]
			if shield and shield.Visual == visual then
				self:_dropShield(player)
			end
		end)
	elseif def.Key == "Heal" then
		local amount = spellPower(def, level, "Heal", "HealPerLevel")
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + amount)
		local glow = Instance.new("ParticleEmitter")
		glow.Color = ColorSequence.new(def.Color)
		glow.LightEmission = 1
		glow.Rate = 0
		glow.Speed = NumberRange.new(3, 6)
		glow.Lifetime = NumberRange.new(0.8, 1.2)
		glow.Size = NumberSequence.new(0.6, 0)
		glow.SpreadAngle = Vector2.new(180, 180)
		glow.Parent = hrp
		glow:Emit(30)
		Debris:AddItem(glow, 2)
	end
end

function CombatService:_freeze(player: Player, seconds: number)
	local humanoid = humanoidOf(player)
	if not humanoid or player.Character:FindFirstChildOfClass("ForceField") then
		return
	end
	local jumpPower, jumpHeight = humanoid.JumpPower, humanoid.JumpHeight
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	task.delay(seconds, function()
		if humanoid.Parent then
			humanoid.JumpPower = jumpPower
			humanoid.JumpHeight = jumpHeight
			self:ApplyStats(player)
		end
	end)
end

function CombatService:Init(services)
	S = services
	Players.RespawnTime = Config.Combat.RespawnTime
	effectsFolder = Instance.new("Folder")
	effectsFolder.Name = "Effects"
	effectsFolder.Parent = workspace
	Players.PlayerRemoving:Connect(function(player)
		cooldowns[player] = nil
		shields[player] = nil
		lastHit[player] = nil
		power[player] = nil
		recentKills[player] = nil
	end)
end

function CombatService:Start()
	-- Power slowly refills.
	while true do
		local dt = task.wait(0.25)
		for _, player in Players:GetPlayers() do
			if power[player] then
				local humanoid = humanoidOf(player)
				if humanoid and humanoid.Health > 0 then
					setPower(player, power[player] + Config.Power.RegenPerSecond * dt)
				end
			end
		end
	end
end

return CombatService
