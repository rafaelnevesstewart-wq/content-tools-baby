-- Stealing: grab a jar from someone else's pedestal and carry it home. The
-- storm only changes owner when the thief reaches their own island. If the
-- thief is zapped, dies, or anyone leaves, the storm goes back.
-- Also hands out the Zapper tool everyone uses to stop thieves.

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local StormData = require(Shared.StormData)

local Modules = script.Parent.Parent.Modules
local Notify = require(Modules.Notify)
local StormModel = require(Modules.StormModel)

local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local MovementService = require(script.Parent.MovementService)
local PlotService = require(script.Parent.PlotService)
local RideService = require(script.Parent.RideService)

local StealService = {}

type Carry = {
	owner: Player,
	slot: number,
	uid: string,
	name: string,
	visual: Model?,
}

local carries: { [Player]: Carry } = {}
local lastZap: { [Player]: number } = {}
local zapperTemplate: Tool

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

local function attachVisual(thief: Player, record: StormData.StormRecord): Model?
	local character = thief.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	local def = StormData.get(record.id)
	if not head or not def then
		return nil
	end
	local visual = Instance.new("Model")
	visual.Name = "CarriedStorm"
	local rarity = StormData.rarityOf(def)
	local jarScale = rarity.scale * 0.35
	local jar = StormModel.buildJar(jarScale, false)
	local storm = StormModel.build(def, { mutation = record.mut, scale = 0.35, anchored = false })

	local above = head.CFrame * CFrame.new(0, 1.2, 0)
	jar:PivotTo(above)
	storm:PivotTo(above * CFrame.new(0, 3.6 * jarScale, 0))
	jar.Parent = visual
	storm.Parent = visual

	for _, part in { jar.PrimaryPart, storm.PrimaryPart } do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = part
		weld.Parent = part
	end
	visual.Parent = character
	return visual
end

local function clearCarry(thief: Player): Carry?
	local carry = carries[thief]
	if not carry then
		return nil
	end
	carries[thief] = nil
	if carry.visual then
		carry.visual:Destroy()
	end
	thief:SetAttribute("Carrying", nil)
	MovementService.refresh(thief)
	return carry
end

-- Puts the storm back on its owner's pedestal.
local function cancel(thief: Player, reason: string?)
	local carry = clearCarry(thief)
	if not carry then
		return
	end
	PlotService.setSlotStolen(carry.owner, carry.slot, false)
	IncomeService.sync(carry.owner)
	if reason then
		if thief.Parent then
			Notify.player(thief, reason, "warn")
		end
		if carry.owner.Parent then
			Notify.player(carry.owner, "🛡️ Your " .. carry.name .. " is safe again!", "success")
		end
	end
end

local function bank(thief: Player)
	local carry = carries[thief]
	if not carry then
		return
	end
	local ownerData = DataService.get(carry.owner)
	local thiefData = DataService.get(thief)
	local newSlot = PlotService.firstFreeSlot(thief)
	if not ownerData or not thiefData or not newSlot then
		cancel(thief, "Your island is full! The storm flew back home.")
		return
	end
	local index: number? = nil
	for i, record in ownerData.storms do
		if record.uid == carry.uid then
			index = i
			break
		end
	end
	if not index then
		cancel(thief, nil)
		return
	end

	local record = table.remove(ownerData.storms, index) :: StormData.StormRecord
	record.slot = newSlot
	table.insert(thiefData.storms, record)
	thiefData.stats.stolen += 1
	thiefData.discovered[record.id] = true

	clearCarry(thief)
	PlotService.setSlotStolen(carry.owner, carry.slot, false)
	PlotService.refreshSlot(thief, newSlot)
	IncomeService.sync(carry.owner)
	IncomeService.sync(thief)

	Notify.player(thief, "😈 You stole " .. carry.name .. "!", "rare")
	Notify.player(carry.owner, "💔 " .. thief.DisplayName .. " stole your " .. carry.name .. "!", "warn")
end

local function begin(thief: Player, owner: Player, slot: number)
	if thief == owner or carries[thief] or not DataService.get(thief) then
		return
	end
	if MovementService.isStunned(thief) then
		return
	end
	if workspace:GetAttribute("RaidState") == "active" then
		Notify.player(thief, "No stealing during the Mega-Storm! Team up and fight it!", "warn")
		return
	end
	local ownerData = DataService.get(owner)
	local record = ownerData and PlotService.stormInSlot(ownerData, slot)
	if not record or PlotService.isSlotStolen(owner, slot) then
		return
	end
	if PlotService.isLocked(owner) then
		Notify.player(thief, "🔒 That island is locked!", "warn")
		return
	end
	local root = rootOf(thief)
	local pedestal = PlotService.slotPosition(owner, slot)
	if not root or not pedestal or (root.Position - pedestal).Magnitude > Config.Steal.PromptDistance + 6 then
		return
	end
	if not PlotService.firstFreeSlot(thief) then
		Notify.player(thief, "Your island is full! Make room before you steal.", "warn")
		return
	end

	local name = StormData.displayName(record)
	carries[thief] = {
		owner = owner,
		slot = slot,
		uid = record.uid,
		name = name,
		visual = attachVisual(thief, record),
	}
	RideService.dismount(thief)
	thief:SetAttribute("Carrying", name)
	PlotService.setSlotStolen(owner, slot, true)
	MovementService.refresh(thief)
	IncomeService.sync(owner)

	Notify.player(thief, "🏃 Run home with " .. name .. "! Don't get zapped!", "info")
	Notify.player(owner, "🚨 " .. thief.DisplayName .. " is stealing your " .. name .. "! Zap them!", "warn")

	if ownerData.trapLevel > 0 then
		MovementService.stun(thief, ownerData.trapLevel * Config.Traps.StunPerLevel)
		Notify.player(thief, "⚡ A Lightning Rod trap zapped you!", "warn")
	end
end

local function beam(from: Vector3, to: Vector3)
	local distance = (to - from).Magnitude
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(255, 240, 90)
	part.Size = Vector3.new(0.4, 0.4, distance)
	part.CFrame = CFrame.lookAt((from + to) / 2, to)
	part.Parent = workspace
	Debris:AddItem(part, 0.2)
end

local function zap(player: Player)
	local root = rootOf(player)
	if not root or MovementService.isStunned(player) then
		return
	end
	if os.clock() - (lastZap[player] or 0) < Config.Zapper.Cooldown then
		return
	end
	lastZap[player] = os.clock()

	local target: Player? = nil
	local best = Config.Zapper.Range
	for thief in carries do
		local thiefRoot = rootOf(thief)
		if thief ~= player and thiefRoot then
			local distance = (thiefRoot.Position - root.Position).Magnitude
			if distance <= best then
				best = distance
				target = thief
			end
		end
	end
	if not target then
		Notify.player(player, "No thief in range. The Zapper only hits players carrying a stolen storm.", "info")
		return
	end
	local targetRoot = rootOf(target)
	if targetRoot then
		beam(root.Position, targetRoot.Position)
	end
	cancel(target, "⚡ " .. player.DisplayName .. " zapped you! The storm flew back.")
	MovementService.stun(target, Config.Zapper.StunSeconds)
	Notify.player(player, "⚡ Zap! You stopped " .. target.DisplayName .. ".", "success")
end

local function makeZapper(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Zapper"
	tool.RequiresHandle = false
	tool.CanBeDropped = false
	tool.ToolTip = "Zap thieves carrying a stolen storm"
	return tool
end

local function giveZapper(player: Player)
	local backpack = player:WaitForChild("Backpack", 10)
	if not backpack or backpack:FindFirstChild("Zapper") then
		return
	end
	local tool = zapperTemplate:Clone()
	tool.Activated:Connect(function()
		zap(player)
	end)
	tool.Parent = backpack
end

-- Sends every carried storm back home (used when a Mega-Storm arrives).
function StealService.cancelAll(reason: string)
	for thief in carries do
		cancel(thief, reason)
	end
end

function StealService.isCarrying(player: Player): boolean
	return carries[player] ~= nil
end

function StealService.init()
	zapperTemplate = makeZapper()
end

function StealService.start()
	PlotService.StealRequested:Connect(begin)

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			cancel(player, nil)
			local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
			if humanoid then
				humanoid.Died:Connect(function()
					cancel(player, "💥 You dropped the storm and it flew home.")
				end)
			end
			task.wait()
			giveZapper(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		cancel(player, nil)
		lastZap[player] = nil
		for thief, carry in carries do
			if carry.owner == player then
				cancel(thief, "The owner left, so the storm vanished back to them.")
			end
		end
	end)

	-- Bank the storm when the thief makes it home.
	task.spawn(function()
		while true do
			task.wait(0.2)
			for thief, carry in carries do
				local root = rootOf(thief)
				if root and PlotService.isOnPlot(thief, root.Position) then
					bank(thief)
				elseif
					root
					and PlotService.isLocked(carry.owner)
					and PlotService.isOnPlot(carry.owner, root.Position)
				then
					-- The owner locked up before the thief got off the island.
					cancel(thief, "🔒 The lock shield knocked the storm out of your hands!")
				end
			end
		end
	end)
end

return StealService
