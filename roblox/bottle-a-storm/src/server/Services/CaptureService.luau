-- The bottling minigame. The server checks you can catch the storm, freezes
-- it, and lets your client run the tug-of-war. It only accepts a win that
-- took a believable amount of time while you stayed close to the storm.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

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

type Session = {
	uid: string,
	def: StormData.StormDef,
	startedAt: number,
}

local sessions: { [Player]: Session } = {}
local rng = Random.new()

local captureStart = Remotes.event("CaptureStart")
local captureResult = Remotes.event("CaptureResult")
local captureEnd = Remotes.event("CaptureEnd")

local function rootPosition(player: Player): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return if root then root.Position else nil
end

local function rollMutation(): string?
	local event = WeatherService.current()
	local chance = Config.Capture.MutationChance * (if event then event.mutationChanceMultiplier else 1)
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

local function endSession(player: Player, caught: boolean)
	local session = sessions[player]
	if not session then
		return
	end
	sessions[player] = nil
	captureEnd:FireClient(player, session.uid)
	if not caught then
		StormSpawner.release(session.uid)
	end
end

CaptureService.rollMutation = rollMutation

function CaptureService.isCapturing(player: Player): boolean
	return sessions[player] ~= nil
end

local function begin(player: Player, uid: string)
	local data = DataService.get(player)
	if not data or sessions[player] then
		return
	end
	if player:GetAttribute("Carrying") then
		Notify.player(player, "Your hands are full! Bring that stolen storm home first.", "warn")
		return
	end
	if MovementService.isStunned(player) then
		return
	end
	local storm = StormSpawner.get(uid)
	local position = rootPosition(player)
	if not storm or not position then
		return
	end
	if (storm.root.Position - position).Magnitude > Config.Capture.PromptDistance + 8 then
		return
	end

	local def = storm.def
	local rarity = StormData.rarityOf(def)
	local jar = Config.Jars[data.jarTier] or Config.Jars[1]
	if def.rarity > jar.maxRarity then
		Notify.player(
			player,
			"Your " .. jar.name .. " is too weak for " .. rarity.name .. " storms. Upgrade your jar in the Shop!",
			"warn"
		)
		return
	end
	if not PlotService.firstFreeSlot(player) then
		Notify.player(player, "Your island is full! Buy a pedestal or sell a storm first.", "warn")
		return
	end
	if not StormSpawner.reserve(uid, player) then
		Notify.player(player, "Someone else is already bottling that storm!", "warn")
		return
	end

	sessions[player] = { uid = uid, def = def, startedAt = os.clock() }
	captureStart:FireClient(player, {
		uid = uid,
		name = def.name,
		rarity = rarity.name,
		color = rarity.color,
		pull = rarity.pull,
		power = jar.power,
	})

	task.delay(Config.Capture.Timeout, function()
		local session = sessions[player]
		if session and session.uid == uid then
			Notify.player(player, "The " .. def.name .. " wriggled free!", "warn")
			endSession(player, false)
		end
	end)
end

local function finish(player: Player, uid: any, success: any)
	local session = sessions[player]
	if not session or session.uid ~= uid then
		return
	end
	local def = session.def
	local elapsed = os.clock() - session.startedAt
	local storm = StormSpawner.get(uid)
	local position = rootPosition(player)
	local closeEnough = storm ~= nil
		and position ~= nil
		and (storm.root.Position - position).Magnitude <= Config.Capture.MaxDistance

	if success ~= true or elapsed < Config.Capture.MinSeconds or not closeEnough then
		Notify.player(player, "💨 The " .. def.name .. " escaped!", "warn")
		endSession(player, false)
		return
	end

	local data = DataService.get(player)
	local slot = PlotService.firstFreeSlot(player)
	if not data or not slot then
		Notify.player(player, "Your island filled up! The storm escaped.", "warn")
		endSession(player, false)
		return
	end

	local mutation = rollMutation()
	local record: StormData.StormRecord = {
		uid = HttpService:GenerateGUID(false),
		id = def.id,
		mut = mutation,
		slot = slot,
		at = os.time(),
	}
	table.insert(data.storms, record)
	data.stats.captured += 1
	local firstTime = not data.discovered[def.id]
	data.discovered[def.id] = true

	endSession(player, true)
	StormSpawner.remove(uid)
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

function CaptureService.start()
	StormSpawner.BottleRequested:Connect(begin)
	captureResult.OnServerEvent:Connect(finish)

	local function cancel(player: Player)
		if sessions[player] then
			endSession(player, false)
		end
	end
	Players.PlayerRemoving:Connect(cancel)
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			cancel(player)
			local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
			if humanoid then
				humanoid.Died:Connect(function()
					cancel(player)
				end)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return CaptureService
