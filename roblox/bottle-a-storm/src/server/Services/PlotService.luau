-- Gives every player a Sky Island, builds their pedestals and jar displays,
-- runs the base lock and keeps intruders out of locked islands.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Signal)
local StormData = require(Shared.StormData)

local Modules = script.Parent.Parent.Modules
local Notify = require(Modules.Notify)
local StormModel = require(Modules.StormModel)
local WorldBuilder = require(Modules.WorldBuilder)

local DataService = require(script.Parent.DataService)

local PlotService = {}

-- (thief, owner, slot)
PlotService.StealRequested = Signal.new()
-- (owner, slot)
PlotService.SellRequested = Signal.new()
-- (owner)
PlotService.CollectTouched = Signal.new()
-- (owner, slot) when the owner picks a storm to guard their island
PlotService.GuardRequested = Signal.new()
-- (owner, slot) the owner picked a storm to follow them around as a buddy.
PlotService.BuddyRequested = Signal.new()
-- (owner, slot) when the owner picks a storm to ride
PlotService.RideRequested = Signal.new()
-- (owner, slot) when the owner pets one of their storms
PlotService.PetRequested = Signal.new()
-- (player) when a player gets an island
PlotService.PlotAssigned = Signal.new()

export type Plot = {
	index: number,
	cframe: CFrame,
	model: Model,
	owner: Player?,
	pedestals: { [number]: Model },
	stolenSlots: { [number]: boolean },
	lockedUntil: number,
	lockReadyAt: number,
	barrier: Part,
	mixer: Model,
	sign: TextLabel,
	collectLabel: TextLabel,
	pedestalFolder: Folder,
}

local plots: { Plot } = {}
local stealHoldStart: { [Player]: number } = {}
local plotByPlayer: { [Player]: Plot } = {}

local COLUMNS = 5
local SPACING = 11

local function now(): number
	return workspace:GetServerTimeNow()
end

local function localSlotPosition(slot: number): Vector3
	local row = (slot - 1) // COLUMNS
	local column = (slot - 1) % COLUMNS
	return Vector3.new((column - (COLUMNS - 1) / 2) * SPACING, 0, 4 + row * SPACING)
end

local function makePart(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		if key ~= "Parent" then
			(p :: any)[key] = value
		end
	end
	p.Parent = props.Parent
	return p
end

local function billboard(parent: Instance, offset: Vector3, size: UDim2): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Size = size
	gui.StudsOffset = offset
	gui.MaxDistance = 120
	gui.LightInfluence = 0
	gui.Parent = parent
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.2
	text.Parent = gui
	return text
end

local function prompt(parent: Instance, name: string, action: string, hold: number, key: Enum.KeyCode): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = action
	p.HoldDuration = hold
	p.KeyboardKeyCode = key
	p.MaxActivationDistance = Config.Steal.PromptDistance
	p.RequiresLineOfSight = false
	p.Parent = parent
	return p
end

local function playerFromHit(hit: BasePart): Player?
	local model = hit:FindFirstAncestorOfClass("Model")
	return if model then Players:GetPlayerFromCharacter(model) else nil
end

-- Decorates an empty island with the pads, sign and lock barrier.
local function buildPlotProps(info: WorldBuilder.PlotInfo): Plot
	local cframe = info.cframe
	local props = Instance.new("Folder")
	props.Name = "Props"
	props.Parent = info.model

	local pedestalFolder = Instance.new("Folder")
	pedestalFolder.Name = "Pedestals"
	pedestalFolder.Parent = info.model

	local plot: Plot

	-- Collect pad
	local collectPad = makePart({
		Name = "CollectPad",
		Size = Vector3.new(10, 0.6, 10),
		CFrame = cframe * CFrame.new(-20, 0.3, -18),
		Color = Color3.fromRGB(255, 210, 60),
		Material = Enum.Material.Neon,
		Parent = props,
	})
	local collectLabel = billboard(collectPad, Vector3.new(0, 4, 0), UDim2.fromOffset(200, 70))
	collectLabel.Text = "💰 Collect"
	local lastTouch: { [Player]: number } = {}
	collectPad.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		if player and player == plot.owner and os.clock() - (lastTouch[player] or 0) > 0.5 then
			lastTouch[player] = os.clock()
			PlotService.CollectTouched:Fire(player)
		end
	end)

	-- Lock button
	local lockButton = makePart({
		Name = "LockButton",
		Size = Vector3.new(6, 3, 6),
		CFrame = cframe * CFrame.new(20, 1.5, -18),
		Color = Color3.fromRGB(90, 200, 255),
		Material = Enum.Material.SmoothPlastic,
		Parent = props,
	})
	billboard(lockButton, Vector3.new(0, 4, 0), UDim2.fromOffset(200, 60)).Text = "🔒 Lock Base"
	local lockPrompt = prompt(lockButton, "LockPrompt", "Lock Base", 0, Enum.KeyCode.E)
	lockPrompt.ObjectText = "Keeps thieves out for " .. Config.Lock.Duration .. "s"
	lockPrompt.Triggered:Connect(function(player)
		if player == plot.owner then
			PlotService.lock(player, Config.Lock.Duration, false)
		else
			Notify.player(player, "That's not your island's lock!", "warn")
		end
	end)

	-- Storm Mixer cauldron. The client opens the mixer window when the prompt fires.
	local mixer = Instance.new("Model")
	mixer.Name = "StormMixer"
	local pot = makePart({
		Name = "Pot",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(4, 8, 8),
		CFrame = cframe * CFrame.new(0, 2, -14) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(60, 55, 80),
		Material = Enum.Material.Metal,
		Parent = mixer,
	})
	local swirl = makePart({
		Name = "Swirl",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(6, 6, 6),
		CFrame = cframe * CFrame.new(0, 4.5, -14),
		Color = Color3.fromRGB(170, 90, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.25,
		CanCollide = false,
		Parent = mixer,
	})
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Name = "Bubbles"
	bubbles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	bubbles.Color = ColorSequence.new(Color3.fromRGB(220, 170, 255))
	bubbles.Size = NumberSequence.new(0.4)
	bubbles.Rate = 6
	bubbles.Speed = NumberRange.new(2, 4)
	bubbles.Lifetime = NumberRange.new(0.8, 1.4)
	bubbles.LightEmission = 0.6
	bubbles.Parent = swirl
	billboard(swirl, Vector3.new(0, 5, 0), UDim2.fromOffset(200, 50)).Text = "🧪 Storm Mixer"
	local mixPrompt = prompt(pot, "MixerPrompt", "Mix Storms", 0, Enum.KeyCode.E)
	mixPrompt.ObjectText = "Combine two storms"
	mixer.PrimaryPart = pot
	mixer.Parent = props

	-- Welcome arch over the bridge entrance
	local archFrame = cframe * CFrame.new(0, 0, -(Config.World.PlotRadius - 6))
	for _, side in { -1, 1 } do
		makePart({
			Name = "ArchPost",
			Size = Vector3.new(1.5, 14, 1.5),
			CFrame = archFrame * CFrame.new(8 * side, 7, 0),
			Color = Color3.fromRGB(235, 225, 200),
			Material = Enum.Material.Wood,
			Parent = props,
		})
	end
	local board = makePart({
		Name = "ArchBoard",
		Size = Vector3.new(18, 4, 1),
		CFrame = archFrame * CFrame.new(0, 13, 0),
		Color = Color3.fromRGB(90, 150, 230),
		Material = Enum.Material.SmoothPlastic,
		Parent = props,
	})
	local sign = billboard(board, Vector3.new(0, 0, 0), UDim2.fromOffset(320, 60))
	sign.Text = "Empty Island"

	-- Lock barrier: invisible until the island is locked.
	local barrierSize = (Config.World.PlotRadius + 4) * 2
	local barrier = makePart({
		Name = "Barrier",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(barrierSize, barrierSize, barrierSize),
		CFrame = cframe,
		Color = Color3.fromRGB(110, 210, 255),
		Material = Enum.Material.ForceField,
		Transparency = 1,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		CastShadow = false,
		Parent = props,
	})

	plot = {
		index = info.index,
		cframe = cframe,
		model = info.model,
		owner = nil,
		pedestals = {},
		stolenSlots = {},
		lockedUntil = 0,
		lockReadyAt = 0,
		barrier = barrier,
		mixer = mixer,
		sign = sign,
		collectLabel = collectLabel,
		pedestalFolder = pedestalFolder,
	}
	return plot
end

local function stormInSlot(data: any, slot: number): StormData.StormRecord?
	for _, record in data.storms do
		if record.slot == slot then
			return record
		end
	end
	return nil
end
PlotService.stormInSlot = stormInSlot

local function buildPedestal(plot: Plot, slot: number): Model
	local model = Instance.new("Model")
	model.Name = "Pedestal" .. slot
	local frame = plot.cframe * CFrame.new(localSlotPosition(slot))

	local base = makePart({
		Name = "Base",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, 7.5, 7.5),
		CFrame = frame * CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(235, 235, 245),
		Material = Enum.Material.Marble,
		Parent = model,
	})
	base:SetAttribute("Slot", slot)
	base:SetAttribute("PlotIndex", plot.index)
	base:SetAttribute("OwnerUserId", if plot.owner then plot.owner.UserId else 0)
	base:SetAttribute("HasStorm", false)
	base:SetAttribute("BeingStolen", false)
	model.PrimaryPart = base

	-- Prompts are shown or hidden per player by the client (PromptController);
	-- the server checks every trigger.
	-- Owners press E to pet; everyone else presses E to steal. The client
	-- shows the right one (PromptController).
	local pet = prompt(base, "PetPrompt", "Pet", 0.4, Enum.KeyCode.E)
	pet.Triggered:Connect(function(player)
		if player == plot.owner then
			PlotService.PetRequested:Fire(player, slot)
		end
	end)
	local steal = prompt(base, "StealPrompt", "Steal", Config.Steal.HoldSeconds, Enum.KeyCode.E)
	steal.PromptButtonHoldBegan:Connect(function(player)
		stealHoldStart[player] = os.clock()
	end)
	steal.Triggered:Connect(function(player)
		if plot.owner and player ~= plot.owner then
			PlotService.StealRequested:Fire(player, plot.owner, slot)
		end
	end)
	-- Opens the Ride / Guard / Sell menu on the owner's screen (PedestalMenu).
	-- The choice comes back through the PedestalAction remote.
	prompt(base, "OptionsPrompt", "Options", 0, Enum.KeyCode.F)

	CollectionService:AddTag(base, "Pedestal")
	model.Parent = plot.pedestalFolder
	return model
end

-- "Lv 3 · 😄 Happy · +125 ⚡/s"
local function moodSubtitle(record: StormData.StormRecord): string
	local tier = StormData.moodOf(record)
	return "Lv "
		.. StormData.levelOf(record)
		.. " · "
		.. tier.emoji
		.. " "
		.. tier.name
		.. " · +"
		.. Format.number(StormData.earningOf(record))
		.. " ⚡/s"
end

-- Rebuilds the jar display for one slot from the owner's data.

local function refreshSlot(plot: Plot, slot: number)
	local pedestal = plot.pedestals[slot]
	if not pedestal then
		return
	end
	local base = pedestal.PrimaryPart :: BasePart
	local existing = pedestal:FindFirstChild("Display")
	if existing then
		existing:Destroy()
	end
	local oldAlert = base:FindFirstChild("StolenAlert")
	if oldAlert then
		oldAlert:Destroy()
	end

	local data = if plot.owner then DataService.get(plot.owner) else nil
	local record = if data then stormInSlot(data, slot) else nil
	local beingStolen = plot.stolenSlots[slot] == true
	base:SetAttribute("OwnerUserId", if plot.owner then plot.owner.UserId else 0)
	base:SetAttribute("HasStorm", record ~= nil)
	-- For the owner's Options menu: which storm is here.
	base:SetAttribute("StormId", if record then record.id else nil)
	base:SetAttribute("StormMut", if record then record.mut else nil)
	base:SetAttribute("StormUid", if record then record.uid else nil)
	base:SetAttribute("StormLevel", if record then StormData.levelOf(record) else nil)
	base:SetAttribute("BeingStolen", beingStolen)

	local options = base:FindFirstChild("OptionsPrompt") :: ProximityPrompt?
	local steal = base:FindFirstChild("StealPrompt") :: ProximityPrompt?

	if beingStolen then
		local alert = billboard(base, Vector3.new(0, 6, 0), UDim2.fromOffset(240, 50))
		alert.Parent.Name = "StolenAlert"
		alert.Text = "🚨 BEING STOLEN!"
		alert.TextColor3 = Color3.fromRGB(255, 90, 90)
		return
	end
	if not record then
		return
	end
	local def = StormData.get(record.id)
	if not def then
		return
	end

	local rarity = StormData.rarityOf(def)
	local display = Instance.new("Model")
	display.Name = "Display"
	local top = base.Position + Vector3.new(0, 1, 0)
	local facing = CFrame.lookAt(top, top + plot.cframe.LookVector)

	local jarScale = rarity.scale * 0.55
	local jar = StormModel.buildJar(jarScale, true)
	jar:PivotTo(facing)
	jar.Parent = display

	local storm = StormModel.build(def, { mutation = record.mut, scale = 0.55 })
	storm:PivotTo(facing * CFrame.new(0, 3.6 * jarScale, 0))
	storm.Parent = display

	local tag = StormModel.nameTag(def, record.mut, moodSubtitle(record))
	local moodLine = tag:FindFirstChild("Line4") :: TextLabel?
	if moodLine then
		moodLine.TextColor3 = StormData.moodOf(record).color
	end
	tag.StudsOffsetWorldSpace = Vector3.new(0, 9 * jarScale, 0)
	tag.Parent = storm.PrimaryPart

	display.Parent = pedestal

	local objectText = StormData.displayName(record) .. " (" .. rarity.name .. ")"
	if options then
		options.ObjectText = objectText
	end
	if steal then
		steal.ObjectText = objectText
	end
end

local function refreshPedestals(plot: Plot)
	local data = if plot.owner then DataService.get(plot.owner) else nil
	local count = if data then data.pedestals else 0
	for slot = 1, math.max(count, #plot.pedestals) do
		if slot <= count and not plot.pedestals[slot] then
			plot.pedestals[slot] = buildPedestal(plot, slot)
		elseif slot > count and plot.pedestals[slot] then
			plot.pedestals[slot]:Destroy()
			plot.pedestals[slot] = nil
		end
	end
	for slot in plot.pedestals do
		refreshSlot(plot, slot)
	end
end

-- Repairs profiles whose storms point at missing or shared slots.
local function sanitizeStorms(data: any)
	local used: { [number]: boolean } = {}
	local valid = {}
	local misplaced = {}
	for _, record in data.storms do
		if StormData.get(record.id) then
			if
				type(record.slot) == "number"
				and record.slot >= 1
				and record.slot <= data.pedestals
				and not used[record.slot]
			then
				used[record.slot] = true
				table.insert(valid, record)
			else
				table.insert(misplaced, record)
			end
		end
	end
	for _, record in misplaced do
		local slot = 1
		while used[slot] do
			slot += 1
		end
		if slot > data.pedestals then
			data.pedestals = math.min(slot, Config.Pedestals.MaxWithPass)
		end
		if slot <= data.pedestals then
			used[slot] = true
			record.slot = slot
			table.insert(valid, record)
		end
	end
	data.storms = valid
end

function PlotService.spawnCFrame(player: Player): CFrame?
	local plot = plotByPlayer[player]
	if not plot then
		return nil
	end
	return plot.cframe * CFrame.new(0, 4, -30)
end

local function teleportHome(player: Player)
	local character = player.Character
	local spawnAt = PlotService.spawnCFrame(player)
	if character and spawnAt then
		character:PivotTo(spawnAt)
	end
end

local function assignPlot(player: Player, data: any)
	local free: Plot? = nil
	for _, plot in plots do
		if plot.owner == nil then
			free = plot
			break
		end
	end
	if not free then
		player:Kick("This server is full. Please join another one!")
		return
	end
	local plot = free :: Plot
	sanitizeStorms(data)
	plot.owner = player
	plot.lockedUntil = 0
	plot.lockReadyAt = 0
	plot.stolenSlots = {}
	plot.model:SetAttribute("OwnerUserId", player.UserId)
	plot.model:SetAttribute("LockedUntil", 0)
	plot.model:SetAttribute("LockReadyAt", 0)
	plot.sign.Text = player.DisplayName .. "'s Island"
	plotByPlayer[player] = plot
	refreshPedestals(plot)
	teleportHome(player)
	PlotService.PlotAssigned:Fire(player)
end

local function clearPlot(player: Player)
	local plot = plotByPlayer[player]
	if not plot then
		return
	end
	plotByPlayer[player] = nil
	plot.owner = nil
	plot.stolenSlots = {}
	plot.lockedUntil = 0
	plot.barrier.Transparency = 1
	plot.model:SetAttribute("OwnerUserId", 0)
	plot.sign.Text = "Empty Island"
	plot.collectLabel.Text = "💰 Collect"
	for slot, pedestal in plot.pedestals do
		pedestal:Destroy()
		plot.pedestals[slot] = nil
	end
end

function PlotService.getPlot(player: Player): Plot?
	return plotByPlayer[player]
end

function PlotService.refreshSlot(player: Player, slot: number)
	local plot = plotByPlayer[player]
	if plot then
		refreshSlot(plot, slot)
	end
end

function PlotService.refreshAll(player: Player)
	local plot = plotByPlayer[player]
	if plot then
		refreshPedestals(plot)
	end
end

function PlotService.firstFreeSlot(player: Player): number?
	local data = DataService.get(player)
	if not data then
		return nil
	end
	for slot = 1, data.pedestals do
		if not stormInSlot(data, slot) then
			return slot
		end
	end
	return nil
end

function PlotService.setSlotStolen(owner: Player, slot: number, stolen: boolean)
	local plot = plotByPlayer[owner]
	if plot then
		plot.stolenSlots[slot] = if stolen then true else nil
		refreshSlot(plot, slot)
	end
end

function PlotService.isSlotStolen(owner: Player, slot: number): boolean
	local plot = plotByPlayer[owner]
	return plot ~= nil and plot.stolenSlots[slot] == true
end

function PlotService.slotPosition(owner: Player, slot: number): Vector3?
	local plot = plotByPlayer[owner]
	local pedestal = plot and plot.pedestals[slot]
	return if pedestal and pedestal.PrimaryPart then pedestal.PrimaryPart.Position else nil
end

-- When the player started holding a Steal prompt (to check the hold wasn't faked).
function PlotService.stealHoldStartedAt(player: Player): number?
	return stealHoldStart[player]
end

-- Updates just the mood/income line on a pedestal's label (no rebuild).
function PlotService.updateSlotLabel(owner: Player, slot: number)
	local plot = plotByPlayer[owner]
	local pedestal = plot and plot.pedestals[slot]
	local data = DataService.get(owner)
	local record = data and stormInSlot(data, slot)
	local display = pedestal and pedestal:FindFirstChild("Display")
	local tag = display and display:FindFirstChild("NameTag", true)
	local line = tag and tag:FindFirstChild("Line4") :: TextLabel?
	if line and record then
		line.Text = moodSubtitle(record)
		line.TextColor3 = StormData.moodOf(record).color
	end
end

-- The jar display on a pedestal (for the escape wobble).
function PlotService.slotDisplay(owner: Player, slot: number): Model?
	local plot = plotByPlayer[owner]
	local pedestal = plot and plot.pedestals[slot]
	return if pedestal then pedestal:FindFirstChild("Display") :: Model? else nil
end

-- A warning over a pedestal, or nil to remove it. Also relabels the Pet prompt.
function PlotService.setSlotAlert(owner: Player, slot: number, text: string?, petAction: string?)
	local plot = plotByPlayer[owner]
	local pedestal = plot and plot.pedestals[slot]
	local base = pedestal and pedestal.PrimaryPart
	if not base then
		return
	end
	local old = base:FindFirstChild("SlotAlert")
	if old then
		old:Destroy()
	end
	if text then
		local label = billboard(base, Vector3.new(0, 7.5, 0), UDim2.fromOffset(280, 50))
		label.Parent.Name = "SlotAlert"
		label.Text = text
		label.TextColor3 = Color3.fromRGB(255, 120, 90)
	end
	local pet = base:FindFirstChild("PetPrompt") :: ProximityPrompt?
	if pet then
		pet.ActionText = petAction or "Pet"
	end
end

-- The owner's mixer, for the mixing animation and the distance check.
function PlotService.getMixer(owner: Player): Model?
	local plot = plotByPlayer[owner]
	return if plot then plot.mixer else nil
end

function PlotService.isLocked(owner: Player): boolean
	local plot = plotByPlayer[owner]
	return plot ~= nil and plot.lockedUntil > now()
end

-- True when the position is on (or just above) the island owned by `owner`.
function PlotService.isOnPlot(owner: Player, position: Vector3): boolean
	local plot = plotByPlayer[owner]
	if not plot then
		return false
	end
	local offset = position - plot.cframe.Position
	local flat = Vector3.new(offset.X, 0, offset.Z).Magnitude
	return flat <= Config.World.PlotRadius and offset.Y > -10 and offset.Y < 40
end

function PlotService.collectPadPosition(player: Player): Vector3?
	local plot = plotByPlayer[player]
	local gui = plot and plot.collectLabel.Parent
	local pad = gui and gui.Parent
	return if pad and pad:IsA("BasePart") then pad.Position else nil
end

function PlotService.setCollectText(player: Player, text: string)
	local plot = plotByPlayer[player]
	if plot then
		plot.collectLabel.Text = text
	end
end

-- Free locks have a cooldown; `emergency` (the Robux lock) skips it.
function PlotService.lock(player: Player, duration: number, emergency: boolean): boolean
	local plot = plotByPlayer[player]
	if not plot then
		return false
	end
	local t = now()
	if not emergency and t < plot.lockReadyAt then
		local wait = math.ceil(plot.lockReadyAt - t)
		Notify.player(player, "Your lock is recharging. Ready in " .. Format.time(wait) .. ".", "warn")
		return false
	end
	plot.lockedUntil = math.max(plot.lockedUntil, t + duration)
	if emergency then
		plot.lockReadyAt = math.max(plot.lockReadyAt, plot.lockedUntil)
	else
		plot.lockReadyAt = plot.lockedUntil + Config.Lock.Cooldown
	end
	plot.model:SetAttribute("LockedUntil", plot.lockedUntil)
	plot.model:SetAttribute("LockReadyAt", plot.lockReadyAt)
	plot.barrier.Transparency = 0.55
	Notify.player(player, "🔒 Island locked for " .. Format.time(plot.lockedUntil - t) .. "!", "success")
	return true
end

-- Pushes anyone who isn't the owner out of locked islands.
local function enforceLocks()
	local t = now()
	for _, plot in plots do
		if plot.owner and plot.lockedUntil > 0 then
			if t >= plot.lockedUntil then
				plot.lockedUntil = 0
				plot.barrier.Transparency = 1
				Notify.player(plot.owner, "🔓 Your island lock ended. Stay alert!", "warn")
			else
				for _, player in Players:GetPlayers() do
					local character = player.Character
					local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
					-- Thieves still holding a storm are handled by StealService.
					if player ~= plot.owner and root and not player:GetAttribute("Carrying") then
						local offset = root.Position - plot.cframe.Position
						local flat = Vector3.new(offset.X, 0, offset.Z)
						if flat.Magnitude < Config.World.PlotRadius + 4 and offset.Y > -10 and offset.Y < 60 then
							local out = plot.cframe * CFrame.new(0, 4, -(Config.World.PlotRadius + 12))
							-- Drop them on their side of the bridge, facing away from the island.
							character:PivotTo(plot.cframe.Rotation + out.Position)
							Notify.player(player, "⚡ That island is locked!", "warn")
						end
					end
				end
			end
		end
	end
end

function PlotService.init()
	for _, info in WorldBuilder.build() do
		table.insert(plots, buildPlotProps(info))
	end
end

function PlotService.start()
	-- Choices from the owner's pedestal Options menu.
	Remotes.event("PedestalAction").OnServerEvent:Connect(function(player, slot, action)
		local plot = plotByPlayer[player]
		if not plot or type(slot) ~= "number" or not plot.pedestals[slot] then
			return
		end
		local pedestal = plot.pedestals[slot].PrimaryPart
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not pedestal or not root or (root.Position - pedestal.Position).Magnitude > 25 then
			return
		end
		if action == "ride" then
			PlotService.RideRequested:Fire(player, slot)
		elseif action == "guard" then
			PlotService.GuardRequested:Fire(player, slot)
		elseif action == "buddy" then
			PlotService.BuddyRequested:Fire(player, slot)
		elseif action == "sell" then
			PlotService.SellRequested:Fire(player, slot)
		end
	end)
	DataService.ProfileLoaded:Connect(assignPlot)
	DataService.onRelease(function(player)
		clearPlot(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		clearPlot(player)
		stealHoldStart[player] = nil
	end)

	local function onCharacter(player: Player, character: Model)
		character:WaitForChild("HumanoidRootPart", 10)
		task.wait()
		if player.Character == character then
			teleportHome(player)
		end
	end
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end

	task.spawn(function()
		while true do
			task.wait(0.2)
			enforceLocks()
		end
	end)
end

return PlotService
