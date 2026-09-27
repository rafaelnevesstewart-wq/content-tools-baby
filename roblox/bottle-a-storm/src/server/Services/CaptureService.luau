-- Catching storms by throwing your Storm Jar. The client sends where you
-- clicked; the server picks the storm near that spot, flies the jar there
-- and decides the result:
--   * too strong for your jar -> it bounces off
--   * dodge roll (rarer storms dodge more; better jars dodge less)
--   * a hit adds dizzy stars; enough hits in a row and the storm is bottled

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local StormData = require(Shared.StormData)

local Modules = script.Parent.Parent.Modules
local Notify = require(Modules.Notify)

local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local MovementService = require(script.Parent.MovementService)
local PlotService = require(script.Parent.PlotService)
local StormSpawner = require(script.Parent.StormSpawner)
local WeatherService = require(script.Parent.WeatherService)

local CaptureService = {}

local JAR_NAME = "Storm Jar"

local lastThrow: { [Player]: number } = {}
local lastHint: { [Player]: number } = {}
local tipShown: { [Player]: boolean } = {}
local rng = Random.new()
local jarTemplate: Tool

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

-- Messages that could repeat on every throw are limited to one per 2 seconds.
local function hint(player: Player, text: string, kind: string)
	if os.clock() - (lastHint[player] or 0) > 2 then
		lastHint[player] = os.clock()
		Notify.player(player, text, kind)
	end
end

local function rollMutation(): string?
	local event = WeatherService.current()
	local chance = Config.Throw.MutationChance * (if event then event.mutationChanceMultiplier else 1)
	if rng:NextNumber() >= chance then
		return nil
	end
	local total = 0
	local weights = {}
	for index, mutation in StormData.Mutations do
		local boost = if event then event.mutationBoosts[mutation.id] or 1 else 1
		weights[index] = mutation.weight * boost
		total += weights[index]
	end
	local pick = rng:NextNumber(0, total)
	for index, weight in weights do
		pick -= weight
		if pick <= 0 then
			return StormData.Mutations[index].id
		end
	end
	return StormData.Mutations[1].id
end
CaptureService.rollMutation = rollMutation

-- A little glass jar flying in an arc from `from` to `to`.
local function flyJar(from: Vector3, to: Vector3, onLanded: (() -> ())?)
	local jar = Instance.new("Part")
	jar.Name = "ThrownJar"
	jar.Size = Vector3.new(1, 1.3, 1)
	jar.Material = Enum.Material.Glass
	jar.Color = Color3.fromRGB(200, 235, 255)
	jar.Transparency = 0.3
	jar.Anchored = true
	jar.CanCollide = false
	jar.CanTouch = false
	jar.CanQuery = false
	jar.CFrame = CFrame.new(from)
	jar.Parent = workspace

	local distance = (to - from).Magnitude
	local duration = math.clamp(distance / Config.Throw.Speed, 0.15, 0.8)
	local height = math.min(distance * 0.2, 10)
	local progress = Instance.new("NumberValue")
	progress.Changed:Connect(function(alpha)
		local position = from:Lerp(to, alpha) + Vector3.new(0, math.sin(alpha * math.pi) * height, 0)
		jar.CFrame = CFrame.new(position) * CFrame.Angles(alpha * 8, alpha * 5, 0)
	end)
	local tween = TweenService:Create(progress, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Value = 1 })
	tween.Completed:Connect(function()
		progress:Destroy()
		jar:Destroy()
		if onLanded then
			onLanded()
		end
	end)
	tween:Play()
end

local function bottle(player: Player, storm: StormSpawner.WildStorm)
	local data = DataService.get(player)
	local slot = PlotService.firstFreeSlot(player)
	if not data or not slot then
		hint(player, "Your island is full! Buy a pedestal or sell a storm first.", "warn")
		return
	end
	if not StormSpawner.capture(storm.uid, player) then
		return
	end
	local def = storm.def
	local mutation = rollMutation()
	local record: StormData.StormRecord = {
		uid = HttpService:GenerateGUID(false),
		id = def.id,
		mut = mutation,
		slot = slot,
		at = os.time(),
		mood = Config.Mood.Start,
	}
	table.insert(data.storms, record)
	data.stats.captured += 1
	local firstTime = not data.discovered[def.id]
	data.discovered[def.id] = true
	PlotService.refreshSlot(player, slot)
	IncomeService.sync(player)

	local name = StormData.displayName(record)
	local message = "🫙 You bottled " .. name .. "! +" .. Format.number(StormData.incomeOf(record)) .. " ⚡/s"
	if firstTime then
		message ..= "  (NEW!)"
	end
	Notify.player(player, message, if mutation or def.rarity >= 4 then "rare" else "success")
	if def.rarity >= 5 or (mutation and def.rarity >= 3) then
		Notify.allExcept(player, "🎉 " .. player.DisplayName .. " bottled " .. name .. "!", "rare")
	end
end

-- The jar reached the storm: bounce, dodge, dizzy or caught.
local function resolveHit(player: Player, uid: string, thrownFrom: Vector3)
	local storm = StormSpawner.get(uid)
	local data = DataService.get(player)
	if not storm or storm.catcher or not data then
		return
	end
	local def = storm.def
	local rarity = StormData.rarityOf(def)
	local jar = Config.Jars[data.jarTier] or Config.Jars[1]

	if def.rarity > jar.maxRarity then
		StormSpawner.dodge(uid, thrownFrom)
		hint(
			player,
			"💥 Bounced off! Your "
				.. jar.name
				.. " is too weak for "
				.. rarity.name
				.. " storms. Upgrade it in the Shop!",
			"warn"
		)
		return
	end

	local dodgeChance = (Config.Throw.DodgeChance[def.rarity] or 0) * (1 - Config.Throw.JarDodgeReduction * jar.power)
	if rng:NextNumber() < dodgeChance then
		StormSpawner.dodge(uid, thrownFrom)
		hint(player, "💨 " .. def.name .. " dodged your jar!", "info")
		return
	end

	-- A jar stronger than it needs to be saves one hit.
	local needed = Config.Throw.HitsNeeded[def.rarity] or 1
	if jar.maxRarity > def.rarity then
		needed -= 1
	end
	needed = math.max(1, needed)

	local hits = StormSpawner.addHit(uid, player, needed)
	if hits >= needed then
		bottle(player, storm)
	else
		StormSpawner.daze(uid, Config.Throw.DazeSeconds)
	end
end

local function onThrow(player: Player, target: any)
	if typeof(target) ~= "Vector3" then
		return
	end
	local data = DataService.get(player)
	local root = rootOf(player)
	local character = player.Character
	if not data or not root or not character or not character:FindFirstChild(JAR_NAME) then
		return
	end
	if os.clock() - (lastThrow[player] or 0) < Config.Throw.Cooldown or MovementService.isStunned(player) then
		return
	end
	if player:GetAttribute("Carrying") then
		hint(player, "Your hands are full! Bring that stolen storm home first.", "warn")
		return
	end
	lastThrow[player] = os.clock()

	local origin = root.Position + Vector3.new(0, 1.5, 0)
	local aim = target - origin
	if aim.Magnitude > Config.Throw.Range then
		target = origin + aim.Unit * Config.Throw.Range
	end

	local storm = StormSpawner.findNear(target, Config.Throw.AimRadius)
	if not storm then
		flyJar(origin, target, nil)
		return
	end
	if not PlotService.firstFreeSlot(player) then
		hint(player, "Your island is full! Buy a pedestal or sell a storm first.", "warn")
		return
	end
	local uid = storm.uid
	flyJar(origin, storm.root.Position, function()
		resolveHit(player, uid, origin)
	end)
end

local function makeJarTool(): Tool
	local tool = Instance.new("Tool")
	tool.Name = JAR_NAME
	tool.CanBeDropped = false
	tool.ToolTip = "Click a storm to throw your jar at it"
	tool.Grip = CFrame.new(0, -0.2, 0)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.9, 1.2, 0.9)
	handle.Material = Enum.Material.Glass
	handle.Color = Color3.fromRGB(200, 235, 255)
	handle.Transparency = 0.3
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	local lid = Instance.new("Part")
	lid.Name = "Lid"
	lid.Size = Vector3.new(0.75, 0.2, 0.75)
	lid.Material = Enum.Material.Metal
	lid.Color = Color3.fromRGB(190, 140, 70)
	lid.CanCollide = false
	lid.Massless = true
	lid.CFrame = handle.CFrame * CFrame.new(0, 0.7, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = lid
	weld.Parent = lid
	lid.Parent = tool
	return tool
end

local function giveJar(player: Player)
	local backpack = player:WaitForChild("Backpack", 10)
	local character = player.Character
	if not backpack or backpack:FindFirstChild(JAR_NAME) or (character and character:FindFirstChild(JAR_NAME)) then
		return
	end
	jarTemplate:Clone().Parent = backpack
	if not tipShown[player] then
		tipShown[player] = true
		Notify.player(player, "🫙 Hold your Storm Jar (press 1), then click or tap a storm to throw it!", "info")
	end
end

function CaptureService.init()
	jarTemplate = makeJarTool()
end

function CaptureService.start()
	Remotes.event("ThrowJar").OnServerEvent:Connect(onThrow)

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid", 10)
			task.wait()
			giveJar(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastThrow[player] = nil
		lastHint[player] = nil
		tipShown[player] = nil
	end)
end

return CaptureService
