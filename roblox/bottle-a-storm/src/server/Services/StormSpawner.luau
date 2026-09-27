-- Spawns wild storms on the Wild Skies island and makes them roam. Rarer
-- storms are faster and run away from nearby players. Also tracks jar hits
-- (dizzy stars), dodges and the "sucked into the jar" animation.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local StormData = require(Shared.StormData)
local WeatherEvents = require(Shared.WeatherEvents)

local Modules = script.Parent.Parent.Modules
local Notify = require(Modules.Notify)
local StormModel = require(Modules.StormModel)

local StormSpawner = {}

export type WildStorm = {
	uid: string,
	def: StormData.StormDef,
	model: Model,
	root: BasePart,
	catcher: Player?, -- set while it's being sucked into a jar
	expiresAt: number,
	burstUntil: number,
	stunnedUntil: number,
	fleeFrom: Vector3?,
	hits: { [Player]: { count: number, at: number } },
	dizzyAt: number,
	alive: boolean,
	tween: Tween?,
}

local storms: { [string]: WildStorm } = {}
local count = 0
local folder: Folder
local rng = Random.new()
local event: WeatherEvents.WeatherEvent? = nil
local paused = false

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
	local options = StormData.wildOfRarity(rarityIndex)
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
	local fleeFrom = storm.fleeFrom
	if fleeFrom then
		storm.fleeFrom = nil
		local away = Vector3.new(position.X - fleeFrom.X, 0, position.Z - fleeFrom.Z)
		if away.Magnitude < 0.1 then
			away = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))
		end
		return clampToWild(position + away.Unit * rng:NextNumber(16, 26))
	end
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
		if storm.catcher or os.clock() < storm.stunnedUntil then
			task.wait(0.1)
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
		if storm.alive and not storm.catcher and os.clock() >= storm.stunnedUntil then
			local pause = if os.clock() < storm.burstUntil then 0.1 else rng:NextNumber(0.8, 2.4)
			task.wait(pause)
		end
	end
end

local function spawnStorm(def: StormData.StormDef?)
	local chosen = def or rollStorm()
	local uid = HttpService:GenerateGUID(false)
	local model = StormModel.build(chosen)
	model.Name = "Wild_" .. chosen.id
	model:SetAttribute("StormUid", uid)
	local root = model.PrimaryPart :: BasePart
	local position = randomPointInWild()
	model:PivotTo(CFrame.new(position) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))

	StormModel.nameTag(chosen).Parent = root

	local storm: WildStorm = {
		uid = uid,
		def = chosen,
		model = model,
		root = root,
		catcher = nil,
		expiresAt = os.clock() + (Config.Wild.Lifetime[chosen.rarity] or 120),
		burstUntil = 0,
		stunnedUntil = 0,
		fleeFrom = nil,
		hits = {},
		dizzyAt = 0,
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

-- The wild storm closest to `point` (flat distance), if one is within reach.
function StormSpawner.findNear(point: Vector3, radius: number): WildStorm?
	local best: WildStorm? = nil
	local bestDistance = math.huge
	for _, storm in storms do
		if not storm.catcher then
			local offset = storm.root.Position - point
			local flat = Vector3.new(offset.X, 0, offset.Z).Magnitude
			local reach = radius + 2.5 * StormData.rarityOf(storm.def).scale
			if flat <= reach and math.abs(offset.Y) < 15 and flat < bestDistance then
				best = storm
				bestDistance = flat
			end
		end
	end
	return best
end

local function stopMoving(storm: WildStorm)
	if storm.tween then
		storm.tween:Cancel()
	end
end

-- A hit that didn't catch it: the storm freezes for a moment.
function StormSpawner.daze(uid: string, seconds: number)
	local storm = storms[uid]
	if storm then
		storm.stunnedUntil = os.clock() + seconds
		storm.expiresAt = math.max(storm.expiresAt, os.clock() + 20)
		stopMoving(storm)
	end
end

-- The storm dodged a jar: it dashes away from the thrower.
function StormSpawner.dodge(uid: string, from: Vector3)
	local storm = storms[uid]
	if storm then
		storm.fleeFrom = from
		storm.burstUntil = os.clock() + 1.5
		storm.stunnedUntil = 0
		stopMoving(storm)
	end
end

local function setDizzyText(storm: WildStorm, text: string?)
	local gui = storm.root:FindFirstChild("Dizzy") :: BillboardGui?
	if not text then
		if gui then
			gui:Destroy()
		end
		return
	end
	if not gui then
		local newGui = Instance.new("BillboardGui")
		newGui.Name = "Dizzy"
		newGui.Size = UDim2.fromOffset(160, 40)
		newGui.StudsOffsetWorldSpace = Vector3.new(0, 3.2 * StormData.rarityOf(storm.def).scale, 0)
		newGui.MaxDistance = 90
		newGui.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.Name = "Stars"
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.FredokaOne
		label.TextSize = 26
		label.TextColor3 = Color3.fromRGB(255, 230, 90)
		label.TextStrokeTransparency = 0.2
		label.Parent = newGui
		newGui.Parent = storm.root
		gui = newGui
	end
	((gui :: BillboardGui):FindFirstChild("Stars") :: TextLabel).Text = text
end

-- Counts a jar hit from `player`. Hits wear off after Config.Throw.DizzySeconds.
-- Returns how many hits this player has landed in a row.
function StormSpawner.addHit(uid: string, player: Player, needed: number): number
	local storm = storms[uid]
	if not storm then
		return 0
	end
	local now = os.clock()
	local entry = storm.hits[player]
	if not entry or now - entry.at > Config.Throw.DizzySeconds then
		entry = { count = 0, at = now }
		storm.hits[player] = entry
	end
	entry.count += 1
	entry.at = now
	storm.dizzyAt = now
	setDizzyText(storm, string.rep("💫", entry.count) .. " " .. entry.count .. "/" .. needed)
	return entry.count
end

-- Final hit: shrinks the storm into the jar, then removes it. Returns false
-- if someone else is already catching it.
function StormSpawner.capture(uid: string, player: Player): boolean
	local storm = storms[uid]
	if not storm or storm.catcher then
		return false
	end
	storm.catcher = player
	stopMoving(storm)
	setDizzyText(storm, nil)
	local model = storm.model
	local scale = Instance.new("NumberValue")
	scale.Value = 1
	scale.Changed:Connect(function(value)
		if model.Parent then
			model:ScaleTo(math.max(value, 0.05))
		end
	end)
	local tween = TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
		Value = 0.05,
	})
	tween.Completed:Connect(function()
		scale:Destroy()
		StormSpawner.remove(uid)
	end)
	tween:Play()
	return true
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
	if paused then
		return
	end
	for _ = 1, amount do
		spawnStorm(nil)
	end
end

function StormSpawner.spawnSpecific(def: StormData.StormDef)
	spawnStorm(def)
end

-- While paused (during a Mega-Storm) wild storms hide and none spawn.
function StormSpawner.setPaused(value: boolean)
	paused = value
	if paused then
		for uid, storm in storms do
			if not storm.catcher then
				StormSpawner.remove(uid)
			end
		end
	end
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
			if count < cap and not paused then
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
				elseif storm.dizzyAt > 0 and t - storm.dizzyAt > Config.Throw.DizzySeconds then
					storm.dizzyAt = 0
					storm.hits = {}
					setDizzyText(storm, nil)
				end
			end
		end
	end)
end

return StormSpawner
