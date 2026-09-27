-- Riding your storms. Pick a mount with "Ride this storm" on one of your
-- pedestals, then press Q (or the Ride button) to hop on. The storm floats
-- under your feet, makes you faster by rarity, and gives a power that the
-- client runs (RideController): Updraft, Blink Dash, Surf Boost or Cloud Jump.
-- The storm stays on its pedestal and keeps earning while you ride it.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local StormData = require(Shared.StormData)

local Modules = script.Parent.Parent.Modules
local Notify = require(Modules.Notify)
local StormModel = require(Modules.StormModel)

local DataService = require(script.Parent.DataService)
local MovementService = require(script.Parent.MovementService)
local PlotService = require(script.Parent.PlotService)

local RideService = {}

type Mount = {
	model: Model,
	humanoid: Humanoid,
	hipHeight: number,
	uid: string,
}

local mounts: { [Player]: Mount } = {}
local lastToggle: { [Player]: number } = {}

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

local function clearAttributes(player: Player)
	player:SetAttribute("Riding", nil)
	player:SetAttribute("RideAbility", nil)
	player:SetAttribute("RideSpeed", nil)
end

function RideService.isRiding(player: Player): boolean
	return mounts[player] ~= nil
end

function RideService.dismount(player: Player)
	local mount = mounts[player]
	if not mount then
		return
	end
	mounts[player] = nil
	mount.model:Destroy()
	if mount.humanoid.Parent then
		mount.humanoid.HipHeight = mount.hipHeight
	end
	clearAttributes(player)
	MovementService.refresh(player)
end

local function mount(player: Player): (boolean, string?)
	local data = DataService.get(player)
	if not data then
		return false, nil
	end
	local record = findRecord(data, data.mountUid)
	if not record then
		return false, "Pick a storm to ride first: press R on one of your pedestals."
	end
	if player:GetAttribute("Carrying") then
		return false, "You can't ride while carrying a stolen storm!"
	end
	if PlotService.isSlotStolen(player, record.slot) then
		return false, "Someone is stealing that storm!"
	end
	local def = StormData.get(record.id)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not def or not character or not humanoid or not root or humanoid.Health <= 0 then
		return false, nil
	end

	local rarity = StormData.rarityOf(def)
	local model = StormModel.build(def, { mutation = record.mut, scale = Config.Ride.MountScale, anchored = false })
	model.Name = "RiddenStorm"

	-- Lift the character so the cloud fits under their feet.
	local radius = 2 * rarity.scale * Config.Ride.MountScale
	local lift = radius * 1.6
	local hipHeight = humanoid.HipHeight
	humanoid.HipHeight = hipHeight + lift
	local legs = if humanoid.RigType == Enum.HumanoidRigType.R6 then 2 else 0
	local feet = -(root.Size.Y / 2 + legs + hipHeight + lift)
	model:PivotTo(root.CFrame * CFrame.new(0, feet - radius * 0.6, 0))

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = model.PrimaryPart
	weld.Parent = model.PrimaryPart
	model.Parent = character

	mounts[player] = { model = model, humanoid = humanoid, hipHeight = hipHeight, uid = record.uid }
	local ability = StormData.abilityOf(def)
	player:SetAttribute("Riding", StormData.displayName(record))
	player:SetAttribute("RideAbility", ability)
	player:SetAttribute("RideSpeed", Config.Ride.SpeedByRarity[def.rarity] or 0)
	MovementService.refresh(player)
	return true, nil
end

local function onToggle(player: Player)
	if os.clock() - (lastToggle[player] or 0) < 0.5 then
		return
	end
	lastToggle[player] = os.clock()
	if mounts[player] then
		RideService.dismount(player)
		return
	end
	local ok, message = mount(player)
	if not ok and message then
		Notify.player(player, message, "warn")
	end
end

local function chooseMount(player: Player, slot: number)
	local data = DataService.get(player)
	local record = data and PlotService.stormInSlot(data, slot)
	local def = record and StormData.get(record.id)
	if not record or not def then
		return
	end
	data.mountUid = record.uid
	local info = StormData.AbilityInfo[StormData.abilityOf(def)]
	Notify.player(
		player,
		"🐎 "
			.. StormData.displayName(record)
			.. " is your ride! Press Q to ride. Its power: "
			.. info.emoji
			.. " "
			.. info.name
			.. " ("
			.. info.description
			.. ", Shift).",
		"success"
	)
	if mounts[player] then
		RideService.dismount(player)
		mount(player)
	end
end

function RideService.start()
	Remotes.event("ToggleRide").OnServerEvent:Connect(onToggle)
	PlotService.RideRequested:Connect(chooseMount)

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			-- The old mount was destroyed with the old character.
			mounts[player] = nil
			clearAttributes(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		mounts[player] = nil
		lastToggle[player] = nil
	end)

	-- Hop off if the storm was sold, stolen or mixed away, or you grabbed a stolen one.
	task.spawn(function()
		while true do
			task.wait(0.5)
			for player, current in mounts do
				local data = DataService.get(player)
				local record = data and findRecord(data, current.uid)
				if
					not record
					or player:GetAttribute("Carrying")
					or PlotService.isSlotStolen(player, record.slot)
					or not current.model.Parent
				then
					RideService.dismount(player)
				end
			end
		end
	end)
end

return RideService
