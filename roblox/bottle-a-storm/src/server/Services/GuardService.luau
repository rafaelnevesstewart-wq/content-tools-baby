-- Guard pets: pick one storm (Options menu -> Guard) to fly laps above your
-- island. When a thief carries one of your storms near it, the guard zaps
-- them. Rarer guards zap more often.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local StormData = require(Shared.StormData)

local Modules = script.Parent.Parent.Modules
local Notify = require(Modules.Notify)
local StormModel = require(Modules.StormModel)

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local StealService = require(script.Parent.StealService)

local GuardService = {}

type Guard = {
	uid: string,
	name: string,
	cooldown: number,
	model: Model,
	root: BasePart,
	angle: number,
	lastZap: number,
}

local guards: { [Player]: Guard } = {}
local folder: Folder

local function findRecord(data: any, uid: string?): StormData.StormRecord?
	if not uid then
		return nil
	end
	for _, record in data.storms do
		if record.uid == uid then
			return record
		end
	end
	return nil
end

local function removeGuard(player: Player)
	local guard = guards[player]
	if guard then
		guards[player] = nil
		guard.model:Destroy()
	end
	if player.Parent then
		player:SetAttribute("GuardUid", nil)
	end
end

-- Builds (or rebuilds) the flying guard from the saved guardUid.
local function showGuard(player: Player)
	removeGuard(player)
	local data = DataService.get(player)
	local plot = PlotService.getPlot(player)
	local record = data and findRecord(data, data.guardUid)
	local def = record and StormData.get(record.id)
	if not plot or not record or not def then
		return
	end
	local model = StormModel.build(def, { mutation = record.mut, anchored = true })
	model.Name = "Guard_" .. player.UserId
	StormModel.nameTag(def, record.mut, "🛡️ " .. player.DisplayName .. "'s Guard").Parent = model.PrimaryPart
	model:PivotTo(plot.cframe * CFrame.new(0, Config.Guard.OrbitHeight, 0))
	model.Parent = folder
	player:SetAttribute("GuardUid", record.uid)
	guards[player] = {
		uid = record.uid,
		name = StormData.displayName(record),
		cooldown = Config.Guard.CooldownByRarity[def.rarity] or 8,
		model = model,
		root = model.PrimaryPart :: BasePart,
		angle = 0,
		lastZap = 0,
	}
end

local function choose(player: Player, slot: number)
	local data = DataService.get(player)
	local record = data and PlotService.stormInSlot(data, slot)
	if not data or not record then
		return
	end
	if data.guardUid == record.uid then
		data.guardUid = nil
		removeGuard(player)
		Notify.player(player, "🛡️ " .. StormData.displayName(record) .. " is off guard duty.", "info")
		return
	end
	data.guardUid = record.uid
	showGuard(player)
	local def = StormData.get(record.id)
	local cooldown = def and Config.Guard.CooldownByRarity[def.rarity] or 8
	Notify.player(
		player,
		"🛡️ "
			.. StormData.displayName(record)
			.. " is guarding your island! It zaps thieves every "
			.. cooldown
			.. "s. Rarer storms zap faster.",
		"success"
	)
end

-- Checks guards still exist (sold, traded, mixed or stolen storms stop
-- guarding) and zaps thieves near them.
local function check()
	for player, guard in guards do
		local data = DataService.get(player)
		if not data or not findRecord(data, guard.uid) then
			if data then
				data.guardUid = nil
			end
			removeGuard(player)
			continue
		end
		if os.clock() - guard.lastZap < guard.cooldown then
			continue
		end
		local position = guard.root.Position
		for _, thief in StealService.thievesFrom(player) do
			local character = thief.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and (root.Position - position).Magnitude <= Config.Guard.Range then
				guard.lastZap = os.clock()
				StealService.zapThief(thief, player.DisplayName .. "'s guard " .. guard.name, position, nil)
				Notify.player(
					player,
					"🛡️ Your guard " .. guard.name .. " zapped " .. thief.DisplayName .. "!",
					"success"
				)
				break
			end
		end
	end
end

-- Flies each guard in a slow circle above its island.
local function fly(dt: number)
	for player, guard in guards do
		local plot = PlotService.getPlot(player)
		if plot then
			guard.angle += dt * 0.35
			local offset = Vector3.new(math.cos(guard.angle), 0, math.sin(guard.angle)) * Config.Guard.OrbitRadius
			local position = plot.cframe.Position + offset + Vector3.new(0, Config.Guard.OrbitHeight, 0)
			local ahead = Vector3.new(-math.sin(guard.angle), 0, math.cos(guard.angle))
			guard.root.CFrame = CFrame.lookAt(position, position + ahead)
		end
	end
end

function GuardService.init()
	folder = Instance.new("Folder")
	folder.Name = "Guards"
	folder.Parent = workspace
end

function GuardService.start()
	PlotService.GuardRequested:Connect(choose)
	PlotService.PlotAssigned:Connect(showGuard)
	Players.PlayerRemoving:Connect(removeGuard)
	RunService.Heartbeat:Connect(fly)
	task.spawn(function()
		while true do
			task.wait(0.25)
			check()
		end
	end)
end

return GuardService
