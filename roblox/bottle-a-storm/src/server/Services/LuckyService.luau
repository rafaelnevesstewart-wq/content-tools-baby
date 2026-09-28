-- Lucky Blocks mode: glowing ❓ blocks appear on every island (at the start
-- and every Config.Lucky.Interval seconds). Hit one 3 times with your sword or pickaxe
-- and it bursts open: usually something great (a diamond sword, armor, TNT,
-- resources...), sometimes a nasty surprise (an explosion, lightning, a
-- launch into the sky, getting frozen in ice).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Signal = require(Shared.Signal)

local Modules = script.Parent.Parent.Modules
local Effects = require(Modules.Effects)
local Juice = require(Modules.Juice)
local Notify = require(Modules.Notify)
local WorldBuilder = require(Modules.WorldBuilder)

local CombatService = require(script.Parent.CombatService)
local GadgetService = require(script.Parent.GadgetService)
local MatchService = require(script.Parent.MatchService)

local LuckyService = {}

-- (player) someone opened a lucky block.
LuckyService.Opened = Signal.new()

local GOLD = Color3.fromRGB(255, 200, 50)
local rng = Random.new()
local folder: Folder? = nil
local active = false
local round = 0 -- which match the spawner loop belongs to

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

---------------------------------------------------------------------------
-- Surprises
---------------------------------------------------------------------------

type Outcome = { weight: number, run: (Player, Vector3) -> string }

local function give(player: Player, keys: { string }): boolean
	for _, key in keys do
		if CombatService.give(player, key) == nil then
			return true
		end
	end
	return false
end

local OUTCOMES: { Outcome } = {
	{
		weight = 8,
		run = function(player)
			if give(player, { "DiamondSword", "IronSword", "StoneSword" }) then
				return "⚔️ A shiny new sword!"
			end
			MatchService.addResource(player, "Crystals", 3)
			return "💎 +3 Crystals!"
		end,
	},
	{
		weight = 8,
		run = function(player)
			if give(player, { "Iron", "Chain", "Diamond" }) then
				return "🛡️ New armor!"
			end
			MatchService.addResource(player, "Silver", 10)
			return "⚪ +10 Silver!"
		end,
	},
	{
		weight = 12,
		run = function(player)
			MatchService.addResource(player, "Silver", rng:NextInteger(8, 16))
			MatchService.addResource(player, "Copper", rng:NextInteger(20, 40))
			return "💰 A pile of Copper and Silver!"
		end,
	},
	{
		weight = 5,
		run = function(player)
			MatchService.addResource(player, "Crystals", rng:NextInteger(2, 4))
			return "💎 Crystals!"
		end,
	},
	{
		weight = 7,
		run = function(player)
			GadgetService.give(player, "TNT")
			GadgetService.give(player, "TNT")
			return "🧨 2 TNT!"
		end,
	},
	{
		weight = 7,
		run = function(player)
			for _ = 1, 3 do
				GadgetService.give(player, "Fireball")
			end
			return "🔥 3 Fireballs!"
		end,
	},
	{
		weight = 6,
		run = function(player)
			GadgetService.give(player, "SpeedPotion")
			GadgetService.give(player, "JumpPotion")
			return "🧪 Speed and Jump potions!"
		end,
	},
	{
		weight = 6,
		run = function(player)
			CombatService.give(player, "Bow")
			CombatService.give(player, "Arrows", 16)
			return "🏹 A bow and arrows!"
		end,
	},
	{
		weight = 5,
		run = function(player)
			if give(player, { "KnockbackStick" }) then
				return "🪄 A Knockback Stick!"
			end
			GadgetService.give(player, "InvisPotion")
			return "👻 An Invisibility Potion!"
		end,
	},
	{
		weight = 6,
		run = function(player)
			for _ = 1, 3 do
				CombatService.give(player, "StormApple")
			end
			return "🍎 3 Storm Apples!"
		end,
	},
	{
		weight = 5,
		run = function(player)
			local humanoid = humanoidOf(player)
			if humanoid then
				humanoid.Health = humanoid.MaxHealth
			end
			local character = player.Character
			if character then
				local shield = Instance.new("ForceField")
				shield.Parent = character
				Debris:AddItem(shield, 10)
			end
			return "💖 Full health and a 10 second shield!"
		end,
	},
	{
		weight = 4,
		run = function(player)
			GadgetService.give(player, "Pickaxe")
			GadgetService.give(player, "Axe")
			return "⛏️ Better tools!"
		end,
	},
	-- The nasty ones.
	{
		weight = 6,
		run = function(player, at)
			GadgetService.blast(player, at, 12, 34, 70)
			return "💥 BOOM! It was a trap!"
		end,
	},
	{
		weight = 5,
		run = function(player)
			local root = rootOf(player)
			local humanoid = humanoidOf(player)
			if root and humanoid then
				local bolt = Instance.new("Part")
				bolt.Anchored = true
				bolt.CanCollide = false
				bolt.CanQuery = false
				bolt.Material = Enum.Material.Neon
				bolt.Color = Color3.fromRGB(200, 225, 255)
				bolt.Size = Vector3.new(0.8, 120, 0.8)
				bolt.CFrame = CFrame.new(root.Position + Vector3.new(0, 60, 0))
				bolt.Parent = workspace
				TweenService:Create(bolt, TweenInfo.new(0.4), { Transparency = 1, Size = Vector3.new(3, 120, 3) })
					:Play()
				Debris:AddItem(bolt, 0.5)
				humanoid:TakeDamage(28)
				Juice.knock(player, Vector3.new(0, 40, 0))
				Juice.shake(player, 1)
			end
			return "⚡ Struck by lightning!"
		end,
	},
	{
		weight = 4,
		run = function(player)
			Juice.knock(player, Vector3.new(rng:NextNumber(-10, 10), 110, rng:NextNumber(-10, 10)))
			return "🚀 Blast off! Hope you land on something..."
		end,
	},
	{
		weight = 4,
		run = function(player)
			local root = rootOf(player)
			if root then
				root.Anchored = true
				local ice = Instance.new("Part")
				ice.Anchored = true
				ice.CanCollide = false
				ice.CanQuery = false
				ice.Material = Enum.Material.Ice
				ice.Color = Color3.fromRGB(170, 220, 255)
				ice.Transparency = 0.35
				ice.Size = Vector3.new(5, 7, 5)
				ice.CFrame = root.CFrame * CFrame.new(0, -0.5, 0)
				ice.Parent = workspace
				task.delay(3, function()
					ice:Destroy()
					if root.Parent then
						root.Anchored = false
					end
				end)
			end
			return "🧊 Frozen solid for 3 seconds!"
		end,
	},
	{
		weight = 2,
		run = function()
			return "🫥 ...it was empty. Unlucky!"
		end,
	},
}

local function pick(): Outcome
	local total = 0
	for _, outcome in OUTCOMES do
		total += outcome.weight
	end
	local roll = rng:NextNumber(0, total)
	for _, outcome in OUTCOMES do
		roll -= outcome.weight
		if roll <= 0 then
			return outcome
		end
	end
	return OUTCOMES[1]
end

---------------------------------------------------------------------------
-- The blocks
---------------------------------------------------------------------------

local function makeBlock(at: Vector3): Part
	local size = Config.Lucky.Size
	local block = Instance.new("Part")
	block.Name = "LuckyBlock"
	block.Anchored = true
	block.Size = Vector3.one * size
	block.CFrame = CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	block.Color = GOLD
	block.Material = Enum.Material.SmoothPlastic
	block.Reflectance = 0.1
	block:SetAttribute("Hits", 0)
	for _, face in Enum.NormalId:GetEnumItems() do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.CanvasSize = Vector2.new(100, 100)
		gui.LightInfluence = 0.2
		gui.Parent = block
		local frame = Instance.new("Frame")
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundTransparency = 1
		frame.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(150, 90, 10)
		stroke.Thickness = 8
		stroke.Parent = frame
		local mark = Instance.new("TextLabel")
		mark.BackgroundTransparency = 1
		mark.Size = UDim2.fromScale(1, 1)
		mark.Font = Enum.Font.GothamBlack
		mark.TextScaled = true
		mark.Text = "?"
		mark.TextColor3 = Color3.new(1, 1, 1)
		mark.TextStrokeColor3 = Color3.fromRGB(150, 90, 10)
		mark.TextStrokeTransparency = 0
		mark.Parent = frame
	end
	local light = Instance.new("PointLight")
	light.Color = GOLD
	light.Range = 12
	light.Brightness = 1.5
	light.Parent = block
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Color = ColorSequence.new(Color3.fromRGB(255, 240, 150))
	sparkles.Size = NumberSequence.new(0.4, 0)
	sparkles.Lifetime = NumberRange.new(0.8, 1.4)
	sparkles.Rate = 6
	sparkles.Speed = NumberRange.new(1, 2)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.LightEmission = 1
	sparkles.Parent = block
	-- It bobs gently so it's easy to spot.
	TweenService:Create(
		block,
		TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ CFrame = block.CFrame * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, math.rad(40), 0) }
	):Play()
	return block
end

local function groundAt(spot: Vector3): Vector3?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	if folder then
		table.insert(ignore, folder)
	end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(spot + Vector3.new(0, 40, 0), Vector3.new(0, -80, 0), params)
	return if hit then hit.Position else nil
end

-- Never on (or next to) a generator, bed, shop or spawn pad.
local function nearProtected(spot: Vector3): boolean
	for _, protected in MatchService.protectedSpots() do
		if ((protected - spot) * Vector3.new(1, 0, 1)).Magnitude < 12 then
			return true
		end
	end
	return false
end

local function count(): number
	return if folder then #folder:GetChildren() else 0
end

-- Drops blocks at random free spots on an island. `frame` is its top center.
local function scatter(frame: CFrame, amount: number, minR: number, maxR: number, blocked: (Vector3) -> boolean)
	local placed, tries = 0, 0
	while placed < amount and tries < amount * 25 and count() < Config.Lucky.MaxBlocks do
		tries += 1
		local angle = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(minR, maxR)
		local spot = Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
		local world = frame:PointToWorldSpace(spot)
		if not blocked(spot) and not nearProtected(world) then
			local ground = groundAt(world)
			if ground then
				placed += 1
				local block = makeBlock(ground + Vector3.new(0, Config.Lucky.Size / 2 + 0.3, 0))
				block.Parent = folder
				Effects.confetti(block.Position, 8)
			end
		end
	end
end

local function spawnBatch()
	for _, frame in MatchService.teamFrames() do
		scatter(frame, Config.Lucky.PerIsland, 14, Config.World.PlotRadius - 10, WorldBuilder.isPlotBlocked)
	end
	scatter(CFrame.new(), Config.Lucky.Middle, 25, Config.World.CenterRadius - 20, WorldBuilder.isWildBlocked)
end

local function open(block: BasePart, player: Player)
	LuckyService.Opened:Fire(player)
	local at = block.Position
	block:Destroy()
	Effects.confetti(at, 40)
	Juice.sound(player, "chime")
	local ok, message = pcall(pick().run, player, at)
	Notify.player(player, "🍀 " .. (if ok then message else "Lucky!"), if ok then "success" else "info")
end

-- A sword, pickaxe or axe hit near a lucky block. Returns whether one was hit.
local function hitBlock(player: Player, aim: Vector3): boolean
	if not active or not folder or not MatchService.isPlaying(player) then
		return false
	end
	local root = rootOf(player)
	if not root then
		return false
	end
	local best: BasePart? = nil
	local bestDistance = Config.Match.SwordRange + 2
	for _, block in folder:GetChildren() do
		if block:IsA("BasePart") then
			local offset = block.Position - root.Position
			local distance = offset.Magnitude
			local aimed = (block.Position - aim).Magnitude < 5 or root.CFrame.LookVector:Dot(offset.Unit) > 0.4
			if distance < bestDistance and aimed then
				best, bestDistance = block, distance
			end
		end
	end
	if not best then
		return false
	end
	local block = best :: BasePart
	local hits = (block:GetAttribute("Hits") or 0) + 1
	if hits >= Config.Lucky.Hits then
		open(block, player)
		return true
	end
	block:SetAttribute("Hits", hits)
	block.Color = GOLD:Lerp(Color3.fromRGB(255, 120, 40), hits / Config.Lucky.Hits)
	Juice.sound(player, "pop")
	local left = Config.Lucky.Hits - hits
	Juice.float(
		player,
		"❓ " .. left .. " more " .. (if left == 1 then "hit!" else "hits!"),
		block.Position + Vector3.new(0, 3, 0)
	)
	return true
end

---------------------------------------------------------------------------

function LuckyService.start()
	CombatService.Swung:Connect(function(player, aim)
		hitBlock(player, aim)
	end)
	GadgetService.hitLucky = hitBlock
	MatchService.MatchStarted:Connect(function()
		if workspace:GetAttribute("MatchMode") ~= "Lucky" then
			return
		end
		active = true
		round += 1
		local myRound = round
		local newFolder = Instance.new("Folder")
		newFolder.Name = "LuckyBlocks"
		newFolder.Parent = workspace
		folder = newFolder
		Notify.all("🍀 Lucky Blocks! Hit a ❓ block 3 times with your sword or pickaxe for a surprise.", "rare")
		task.spawn(function()
			task.wait(2)
			while active and round == myRound and MatchService.phase() == "playing" do
				pcall(spawnBatch)
				task.wait(Config.Lucky.Interval)
			end
		end)
	end)
	MatchService.MatchEnded:Connect(function()
		active = false
		round += 1
		if folder then
			folder:Destroy()
			folder = nil
		end
	end)
end

return LuckyService
