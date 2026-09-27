-- Spawns wild storms on the Wild Skies island and makes them roam. Rarer
-- storms are faster and run away from nearby players.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Signal = require(Shared.Signal)
local StormData = require(Shared.StormData)
local WeatherEvents = require(Shared.WeatherEvents)

local Modules = script.Parent.Parent.Modules
local Notify = require(Modules.Notify)
local StormModel = require(Modules.StormModel)

local StormSpawner = {}

-- (player, uid) when someone presses "Bottle" on a wild storm.
StormSpawner.BottleRequested = Signal.new()

export type WildStorm = {
	uid: string,
	def: StormData.StormDef,
	model: Model,
	root: BasePart,
	catcher: Player?,
	escapeUntil: number,
	expiresAt: number,
	burstUntil: number,
	alive: boolean,
	tween: Tween?,
}

local storms: { [string]: WildStorm } = {}
local count = 0
local folder: Folder
local rng = Random.new()
local event: WeatherEvents.WeatherEvent? = nil

local function hoverY(): number
	return Config.Wild.HoverHeight
end

local function randomPointInWild(): Vector3
	local radius = Config.World.WildRoamRadius * math.sqrt(rng:NextNumber())
	local angle = rng:NextNumber(0, math.pi * 2)
	return Vector3.new(math.cos(angle) * radius, hoverY(), math.sin(angle) * radius)
end

local function clampToWild(point: Vector3): Vector3
	local flat = Vector3.new(point.X, 0, point.Z)
	if flat.Magnitude > Config.World.WildRoamRadius then
		flat = flat.Unit * Config.World.WildRoamRadius
	end
	return Vector3.new(flat.X, hoverY(), flat.Z)
end

local function rollStorm(): StormData.StormDef
	local total = 0
	local weights = {}
	for index, rarity in StormData.Rarities do
		local weight = rarity.weight * (if event then event.rarityMultipliers[index] or 1 else 1)
		weights[index] = weight
		total += weight
	end
	local pick = rng:NextNumber(0, total)
	local rarityIndex = #weights
	for index, weight in weights do
		pick -= weight
		if pick <= 0 then
			rarityIndex = index
			break
		end
	end
	local options = {}
	for _, def in StormData.Storms do
		if def.rarity == rarityIndex then
			table.insert(options, def)
		end
	end
	return options[rng:NextInteger(1, #options)]
end

local function nearestPlayerWithin(position: Vector3, radius: number): Vector3?
	local best: Vector3? = nil
	local bestDistance = radius
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local distance = (root.Position - position).Magnitude
			if distance < bestDistance then
				bestDistance = distance
				best = root.Position
			end
		end
	end
	return best
end

local function pickTarget(storm: WildStorm): Vector3
	local position = storm.root.Position
	if storm.def.rarity >= 3 then
		local threat = nearestPlayerWithin(position, Config.Wild.DodgeRadius)
		if threat then
			local away = Vector3.new(position.X - threat.X, 0, position.Z - threat.Z)
			if away.Magnitude < 0.1 then
				away = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))
			end
			return clampToWild(position + away.Unit * rng:NextNumber(14, 24))
		end
	end
	local step = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))
	if step.Magnitude < 0.1 then
		step = Vector3.new(1, 0, 0)
	end
	return clampToWild(position + step.Unit * rng:NextNumber(10, 35))
end

local function roam(storm: WildStorm)
	local rarity = StormData.rarityOf(storm.def)
	while storm.alive do
		if storm.catcher then
			task.wait(0.25)
			continue
		end
		local from = storm.root.Position
		local target = pickTarget(storm)
		local flat = Vector3.new(target.X - from.X, 0, target.Z - from.Z)
		if flat.Magnitude > 1 then
			local speed = rarity.speed * (if os.clock() < storm.burstUntil then 2 else 1)
			local facing = CFrame.lookAt(from, from + flat)
			storm.root.CFrame = facing
			local tween = TweenService:Create(
				storm.root,
				TweenInfo.new(flat.Magnitude / speed, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{ CFrame = facing.Rotation + target }
			)
			storm.tween = tween
			tween:Play()
			tween.Completed:Wait()
			storm.tween = nil
		end
		if storm.alive and not storm.catcher then
			local pause = if os.clock() < storm.burstUntil then 0.1 else rng:NextNumber(0.8, 2.4)
			task.wait(pause)
		end
	end
end

local function spawnStorm(def: StormData.StormDef?)
	local chosen = def or rollStorm()
	local rarity = StormData.rarityOf(chosen)
	local uid = HttpService:GenerateGUID(false)
	local model = StormModel.build(chosen)
	model.Name = "Wild_" .. chosen.id
	model:SetAttribute("StormUid", uid)
	local root = model.PrimaryPart :: BasePart
	local position = randomPointInWild()
	model:PivotTo(CFrame.new(position) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))

	StormModel.nameTag(chosen).Parent = root

	local bottle = Instance.new("ProximityPrompt")
	bottle.Name = "BottlePrompt"
	bottle.ActionText = "Bottle"
	bottle.ObjectText = chosen.name .. " (" .. rarity.name .. ")"
	bottle.HoldDuration = 0
	bottle.MaxActivationDistance = Config.Capture.PromptDistance
	bottle.RequiresLineOfSight = false
	bottle.KeyboardKeyCode = Enum.KeyCode.E
	bottle.Parent = root
	bottle.Triggered:Connect(function(player)
		StormSpawner.BottleRequested:Fire(player, uid)
	end)

	local storm: WildStorm = {
		uid = uid,
		def = chosen,
		model = model,
		root = root,
		catcher = nil,
		escapeUntil = 0,
		expiresAt = os.clock() + (Config.Wild.Lifetime[chosen.rarity] or 120),
		burstUntil = 0,
		alive = true,
		tween = nil,
	}
	storms[uid] = storm
	count += 1
	model.Parent = folder
	task.spawn(roam, storm)

	if chosen.rarity >= 5 then
		Notify.all("✨ A LEGENDARY " .. chosen.name .. " appeared in the Wild Skies!", "rare")
	elseif chosen.rarity == 4 then
		Notify.all("💜 An Epic " .. chosen.name .. " is roaming the Wild Skies!", "info")
	end
end

function StormSpawner.get(uid: string): WildStorm?
	return storms[uid]
end

-- Stops the storm so a player can try to bottle it. Returns false if it's busy.
function StormSpawner.reserve(uid: string, player: Player): boolean
	local storm = storms[uid]
	if not storm or storm.catcher or os.clock() < storm.escapeUntil then
		return false
	end
	storm.catcher = player
	if storm.tween then
		storm.tween:Cancel()
	end
	local prompt = storm.root:FindFirstChild("BottlePrompt") :: ProximityPrompt?
	if prompt then
		prompt.Enabled = false
	end
	return true
end

-- Lets the storm go after a failed catch. It bolts away for a moment.
function StormSpawner.release(uid: string)
	local storm = storms[uid]
	if not storm then
		return
	end
	storm.catcher = nil
	storm.escapeUntil = os.clock() + Config.Capture.EscapeCooldown
	storm.burstUntil = os.clock() + 2.5
	storm.expiresAt = math.max(storm.expiresAt, os.clock() + 20)
	local prompt = storm.root:FindFirstChild("BottlePrompt") :: ProximityPrompt?
	if prompt then
		prompt.Enabled = true
	end
end

function StormSpawner.remove(uid: string)
	local storm = storms[uid]
	if not storm then
		return
	end
	storms[uid] = nil
	count -= 1
	storm.alive = false
	if storm.tween then
		storm.tween:Cancel()
	end
	storm.model:Destroy()
end

function StormSpawner.setEvent(newEvent: WeatherEvents.WeatherEvent?)
	event = newEvent
end

-- Spawns `amount` storms right away (used when an event starts).
function StormSpawner.burst(amount: number)
	for _ = 1, amount do
		spawnStorm(nil)
	end
end

function StormSpawner.spawnSpecific(def: StormData.StormDef)
	spawnStorm(def)
end

function StormSpawner.init()
	folder = Instance.new("Folder")
	folder.Name = "WildStorms"
	folder.Parent = workspace
end

function StormSpawner.start()
	task.spawn(function()
		while true do
			local rate = if event then event.spawnRateMultiplier else 1
			local cap = Config.Wild.MaxStorms + (if event then event.extraStorms else 0)
			-- Fill up quickly when the island is nearly empty.
			local wait = Config.Wild.SpawnInterval / rate
			if count < cap / 2 then
				wait /= 3
			end
			task.wait(wait)
			if count < cap then
				spawnStorm(nil)
			end
		end
	end)

	-- Storms drift away after a while so new ones can appear.
	task.spawn(function()
		while true do
			task.wait(1)
			local t = os.clock()
			for uid, storm in storms do
				if not storm.catcher and t >= storm.expiresAt then
					StormSpawner.remove(uid)
				end
			end
		end
	end)
end

return StormSpawner
