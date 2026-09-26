-- Builds each player's titan, walks the whole herd around the migration loop,
-- and draws the Riders and eggs that live on each titan's deck.
--
-- A titan is one unanchored physics assembly held by rigid AlignPosition and
-- AlignOrientation constraints. Because it really moves (instead of being
-- teleported), players standing on the deck are carried along with it.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)

local TitanService = {}
local S

local titans = {} -- [Player] = record
local lanesTaken = {} -- [laneIndex] = Player
local angle = 0 -- herd position along the loop, radians
local herdFolder

local function laneOffset(lane: number): number
	-- 1 -> 0, 2 -> +1, 3 -> -1, 4 -> +2, ...
	if lane % 2 == 0 then
		return lane // 2
	end
	return -((lane - 1) // 2)
end

local function newPart(props)
	local part = Instance.new("Part")
	part.Anchored = false
	part.CanCollide = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		part[key] = value
	end
	return part
end

local function sphereMesh(part: BasePart)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return mesh
end

local function attach(root: BasePart, part: BasePart, offset: CFrame, parent: Instance)
	part.CFrame = root.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	part.Parent = parent
	return part
end

local function addPrompt(parent: Instance, props, attributes)
	local prompt = Instance.new("ProximityPrompt")
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 12
	for key, value in props do
		prompt[key] = value
	end
	for key, value in attributes or {} do
		prompt:SetAttribute(key, value)
	end
	prompt.Parent = parent
	return prompt
end

local function billboard(parent: BasePart, size: UDim2, offset: Vector3, maxDistance: number)
	local gui = Instance.new("BillboardGui")
	gui.Size = size
	gui.StudsOffset = offset
	gui.AlwaysOnTop = false
	gui.MaxDistance = maxDistance
	gui.LightInfluence = 0
	gui.Parent = parent
	return gui
end

local function label(parent: Instance, text: string, color: Color3, size: UDim2, position: UDim2)
	local textLabel = Instance.new("TextLabel")
	textLabel.BackgroundTransparency = 1
	textLabel.Size = size
	textLabel.Position = position
	textLabel.Font = Enum.Font.FredokaOne
	textLabel.TextScaled = true
	textLabel.TextColor3 = color
	textLabel.TextStrokeTransparency = 0.3
	textLabel.Text = text
	textLabel.Parent = parent
	return textLabel
end

-- Placement ------------------------------------------------------------------

function TitanService:GetAngle(): number
	return angle
end

function TitanService:HerdCenter(): Vector3
	local r = Config.Herd.PathRadius
	return Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
end

local function targetCFrame(record, t: number): CFrame
	local r = Config.Herd.PathRadius + laneOffset(record.Lane) * Config.Herd.LaneSpacing
	local s = record.Scale
	local y = 12 * s
	if record.Exhausted then
		y -= 4 * s
	elseif S.CycleService:IsDay() then
		y += math.sin(t * 2 + record.Lane) * 0.25 * s
	end
	local position = Vector3.new(math.cos(angle) * r, y, math.sin(angle) * r)
	local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
	return CFrame.lookAt(position, position + tangent)
end

-- Building -------------------------------------------------------------------

local function mutationStyle(profile)
	return Util.mutation(profile.TitanMutation)
end

local function build(record, player: Player)
	local profile = S.PlayerService:GetProfile(player)
	local stage = Config.Stages[profile.Stage]
	local species = Config.Species[profile.Species] or Config.Species.Shellback
	local mutation = mutationStyle(profile)
	local s = stage.Scale
	record.Scale = s

	local model = Instance.new("Model")
	model.Name = player.Name .. "_Titan"
	model:SetAttribute("OwnerUserId", player.UserId)

	local root = newPart({
		Name = "Root",
		Size = Vector3.new(4, 4, 4),
		Transparency = 1,
		Massless = false,
		CFrame = targetCFrame(record, os.clock()),
	})
	root.Parent = model
	model.PrimaryPart = root

	local body = Vector3.new(16, 10, 22) * s
	local shellColor = mutation.Color or species.ShellColor
	local shellMaterial = mutation.Material or Enum.Material.SmoothPlastic
	local bodyColor = mutation.Color and species.BodyColor:Lerp(mutation.Color, 0.5) or species.BodyColor

	local bodyPart = attach(root, newPart({ Name = "Body", Size = body, Color = bodyColor }), CFrame.new(), model)
	sphereMesh(bodyPart)
	attach(root, newPart({ Name = "Hull", Size = body * 0.85, Transparency = 1, CanCollide = true }), CFrame.new(), model)

	local shell = attach(
		root,
		newPart({ Name = "Shell", Size = Vector3.new(body.X * 1.05, body.Y * 0.9, body.Z * 0.95), Color = shellColor, Material = shellMaterial }),
		CFrame.new(0, body.Y * 0.3, 0),
		model
	)
	sphereMesh(shell)
	if mutation.Rainbow then
		CollectionService:AddTag(shell, "RainbowPart")
		CollectionService:AddTag(bodyPart, "RainbowPart")
	end

	local head = attach(
		root,
		newPart({ Name = "Head", Size = Vector3.new(7, 6, 7) * s, Color = bodyColor }),
		CFrame.new(0, body.Y * 0.1, -(body.Z / 2 + 2.2 * s)),
		model
	)
	sphereMesh(head)
	for _, side in { -1, 1 } do
		local eye = attach(
			root,
			newPart({ Name = "Eye", Size = Vector3.one * 1.2 * s, Color = Color3.new(0.05, 0.05, 0.05) }),
			CFrame.new(side * 2 * s, body.Y * 0.1 + 1.2 * s, -(body.Z / 2 + 5.2 * s)),
			model
		)
		sphereMesh(eye)
	end

	local legHeight = 10 * s
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			attach(
				root,
				newPart({ Name = "Leg", Size = Vector3.new(3.5 * s, legHeight, 3.5 * s), Color = bodyColor:Lerp(Color3.new(0, 0, 0), 0.2) }),
				CFrame.new(x * body.X * 0.32, -12 * s + legHeight / 2, z * body.Z * 0.3),
				model
			)
		end
	end

	-- Deck: the part players stand and build on.
	local deckSize = Vector3.new(body.X * 0.78, 1, body.Z * 0.72)
	local deckY = body.Y * 0.72
	local deck = attach(
		root,
		newPart({ Name = "Deck", Size = deckSize, CanCollide = true, Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(150, 110, 70) }),
		CFrame.new(0, deckY, 0),
		model
	)
	record.Deck = deck
	record.DeckSize = deckSize

	-- Rails, with a gap on each side where the ladders arrive.
	local railHeight = 2.5
	local gap = 5
	local sideLength = (deckSize.Z - gap) / 2
	local railColor = Color3.fromRGB(110, 80, 50)
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			attach(
				root,
				newPart({ Name = "Rail", Size = Vector3.new(0.6, railHeight, sideLength), CanCollide = true, Color = railColor, Material = Enum.Material.Wood }),
				CFrame.new(x * deckSize.X / 2, deckY + railHeight / 2 + 0.5, z * (gap / 2 + sideLength / 2)),
				model
			)
		end
	end
	for _, z in { -1, 1 } do
		attach(
			root,
			newPart({ Name = "Rail", Size = Vector3.new(deckSize.X, railHeight, 0.6), CanCollide = true, Color = railColor, Material = Enum.Material.Wood }),
			CFrame.new(0, deckY + railHeight / 2 + 0.5, z * deckSize.Z / 2),
			model
		)
	end

	-- Ladders so anyone on the ground can climb aboard (thieves included).
	local rootY = 12 * s
	local deckTop = rootY + deckY + 0.5
	local ladderHeight = math.max(2, math.floor((deckTop - 1) / 2) * 2)
	for _, x in { -1, 1 } do
		local truss = Instance.new("TrussPart")
		truss.Name = "Ladder"
		truss.Size = Vector3.new(2, ladderHeight, 2)
		truss.Anchored = false
		truss.Massless = true
		truss.CanCollide = true
		truss.Color = Color3.fromRGB(120, 90, 60)
		attach(root, truss, CFrame.new(x * (deckSize.X / 2 + 1.4), (1 + ladderHeight / 2) - rootY, 0), model)
	end

	-- Leap post at the back of the deck: jump across to a neighbouring titan.
	local post = attach(
		root,
		newPart({ Name = "LeapPost", Size = Vector3.new(1.5, 5, 1.5), CanCollide = true, Color = Color3.fromRGB(230, 200, 90), Material = Enum.Material.Neon }),
		CFrame.new(0, deckY + 3, deckSize.Z / 2 - 2),
		model
	)
	local leap = addPrompt(post, { ActionText = "Leap", ObjectText = "To the nearest titan", HoldDuration = 0.3 })
	leap.Triggered:Connect(function(who)
		S.StealService:Leap(who)
	end)

	local feed = addPrompt(
		head,
		{ ActionText = "Feed", ObjectText = "Your titan", MaxActivationDistance = 14 * s },
		{ OwnerOnly = true, OwnerUserId = player.UserId }
	)
	feed.Triggered:Connect(function(who)
		if who == player then
			S.PlayerService:_onAction(player, "Feed")
		end
	end)

	-- Name plate and health bar.
	local gui = billboard(head, UDim2.fromOffset(260, 90), Vector3.new(0, 6 * s, 0), 400)
	record.NameLabel = label(gui, "", Color3.new(1, 1, 1), UDim2.new(1, 0, 0.4, 0), UDim2.new())
	record.InfoLabel = label(gui, "", Color3.fromRGB(255, 230, 150), UDim2.new(1, 0, 0.25, 0), UDim2.new(0, 0, 0.4, 0))
	local barBack = Instance.new("Frame")
	barBack.Size = UDim2.new(0.8, 0, 0.18, 0)
	barBack.Position = UDim2.new(0.1, 0, 0.72, 0)
	barBack.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
	barBack.BorderSizePixel = 0
	barBack.Parent = gui
	local bar = Instance.new("Frame")
	bar.Size = UDim2.fromScale(1, 1)
	bar.BackgroundColor3 = Color3.fromRGB(90, 220, 90)
	bar.BorderSizePixel = 0
	bar.Parent = barBack
	record.HealthBar = bar

	local items = Instance.new("Folder")
	items.Name = "DeckItems"
	items.Parent = model
	record.Items = items

	local attachment = Instance.new("Attachment")
	attachment.Parent = root
	local alignPosition = Instance.new("AlignPosition")
	alignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
	alignPosition.Attachment0 = attachment
	alignPosition.RigidityEnabled = true
	alignPosition.Position = root.Position
	alignPosition.Parent = root
	local alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrientation.Attachment0 = attachment
	alignOrientation.RigidityEnabled = true
	alignOrientation.CFrame = root.CFrame
	alignOrientation.Parent = root
	record.AlignPosition = alignPosition
	record.AlignOrientation = alignOrientation

	record.Model = model
	record.Root = root
	record.Head = head
	model.Parent = herdFolder
	pcall(function()
		root:SetNetworkOwner(nil)
	end)

	local maxHealth = stage.MaxHealth
	if record.MaxHealth then
		record.Health = math.max(1, math.floor(record.Health / record.MaxHealth * maxHealth))
	else
		record.Health = maxHealth
	end
	record.MaxHealth = maxHealth
end

local function riderPosition(record, index: number, count: number): CFrame
	local size = record.DeckSize
	local cols = count > 12 and 4 or 3
	local col = (index - 1) % cols
	local row = (index - 1) // cols
	local x = (col - (cols - 1) / 2) * size.X * 0.8 / cols
	local z = size.Z * 0.32 - row * size.Z * (count > 12 and 0.13 or 0.17)
	return CFrame.new(x, 2, z)
end

local function eggPosition(record, index: number, count: number): CFrame
	local size = record.DeckSize
	local x = (index - (count + 1) / 2) * size.X * 0.22
	return CFrame.new(x, 1.8, -size.Z * 0.38)
end

function TitanService:RefreshDeck(player: Player)
	local record = titans[player]
	if not record or not record.Items then
		return
	end
	local profile = S.PlayerService:GetProfile(player)
	record.Items:ClearAllChildren()
	local nightNumber = S.CycleService:NightNumber()

	local visibleRiders = {}
	for _, rider in profile.Riders do
		if not rider.InTransit then
			table.insert(visibleRiders, rider)
		end
	end
	for index, rider in visibleRiders do
		local def = Util.riderDef(rider.Name)
		local mutation = Util.mutation(rider.Mutation)
		local rarity = Util.rarity(def.Rarity)
		local ball = newPart({
			Name = "Rider",
			Size = Vector3.one * 2.6,
			Color = mutation.Color or def.Color,
			Material = mutation.Material or Enum.Material.SmoothPlastic,
		})
		sphereMesh(ball)
		attach(record.Deck, ball, riderPosition(record, index, #visibleRiders), record.Items)
		if mutation.Rainbow then
			CollectionService:AddTag(ball, "RainbowPart")
		end
		local gui = billboard(ball, UDim2.fromOffset(150, 44), Vector3.new(0, 2.6, 0), 90)
		local prefix = rider.Mutation ~= "Normal" and (rider.Mutation .. " ") or ""
		label(gui, prefix .. rider.Name, rarity.Color, UDim2.new(1, 0, 0.55, 0), UDim2.new())
		label(
			gui,
			"+" .. Util.formatNumber(S.PlayerService:RiderIncome(rider)) .. "/s",
			Color3.fromRGB(255, 230, 120),
			UDim2.new(1, 0, 0.45, 0),
			UDim2.new(0, 0, 0.55, 0)
		)

		local release = addPrompt(
			ball,
			{ ActionText = "Release", ObjectText = rider.Name, HoldDuration = 1.2, KeyboardKeyCode = Enum.KeyCode.R },
			{ OwnerUserId = player.UserId, OwnerOnly = true }
		)
		local riderId = rider.Id
		release.Triggered:Connect(function(who)
			if who == player then
				S.PlayerService:ReleaseRider(player, riderId)
			end
		end)
		local steal = addPrompt(ball, { ActionText = "Steal", ObjectText = rider.Name, HoldDuration = 0.8 }, { OwnerUserId = player.UserId, OthersOnly = true })
		steal.Triggered:Connect(function(who)
			S.StealService:TrySteal(who, player, "Rider", riderId)
		end)
		if rider.HomeUserId and rider.HomesickUntilNight and nightNumber < rider.HomesickUntilNight then
			local callHome = addPrompt(
				ball,
				{ ActionText = "Call Home", ObjectText = rider.Name .. " misses you", HoldDuration = 0.5 },
				{ OwnerUserId = player.UserId, OnlyUserId = rider.HomeUserId }
			)
			callHome.Triggered:Connect(function(who)
				S.StealService:CallHome(who, player, riderId)
			end)
		end
	end

	local visibleEggs = {}
	for _, egg in profile.Eggs do
		if not egg.InTransit then
			table.insert(visibleEggs, egg)
		end
	end
	for index, egg in visibleEggs do
		local rarity = Util.rarity(egg.Rarity)
		local shell = newPart({ Name = "Egg", Size = Vector3.new(2.2, 2.8, 2.2), Color = rarity.Color })
		sphereMesh(shell)
		attach(record.Deck, shell, eggPosition(record, index, #visibleEggs), record.Items)
		local gui = billboard(shell, UDim2.fromOffset(140, 40), Vector3.new(0, 2.6, 0), 90)
		label(gui, egg.Rarity .. " Egg", rarity.Color, UDim2.new(1, 0, 0.55, 0), UDim2.new())
		local timer = label(gui, "", Color3.new(1, 1, 1), UDim2.new(1, 0, 0.45, 0), UDim2.new(0, 0, 0.55, 0))
		timer:SetAttribute("HatchAt", egg.HatchAt)
		CollectionService:AddTag(timer, "EggTimer")

		local eggId = egg.Id
		local steal = addPrompt(
			shell,
			{ ActionText = "Steal", ObjectText = egg.Rarity .. " Egg", HoldDuration = 0.8 },
			{ OwnerUserId = player.UserId, OthersOnly = true }
		)
		steal.Triggered:Connect(function(who)
			S.StealService:TrySteal(who, player, "Egg", eggId)
		end)
	end
	self:UpdateBillboard(player)
end

function TitanService:UpdateBillboard(player: Player)
	local record = titans[player]
	if not record or not record.NameLabel then
		return
	end
	local profile = S.PlayerService:GetProfile(player)
	local species = (Config.Species[profile.Species] or Config.Species.Shellback).DisplayName
	local mutation = profile.TitanMutation ~= "Normal" and (profile.TitanMutation .. " ") or ""
	local crown = player:GetAttribute("Guardian") and "👑 " or ""
	record.NameLabel.Text = string.format("%s%s's %s%s", crown, player.DisplayName, mutation, species)
	local info = Config.Stages[profile.Stage].Name
	if profile.Molts > 0 then
		info ..= string.format("  •  Molt %d", profile.Molts)
	end
	if S.PlayerService:IsLocked(player) then
		info ..= "  •  🔒 Shell Lock"
	end
	if record.Exhausted then
		info ..= "  •  Exhausted"
	end
	record.InfoLabel.Text = info
	record.HealthBar.Size = UDim2.fromScale(math.clamp(record.Health / record.MaxHealth, 0, 1), 1)
end

-- Lifecycle ------------------------------------------------------------------

function TitanService:SpawnTitan(player: Player)
	if titans[player] then
		return
	end
	local lane = 1
	while lanesTaken[lane] do
		lane += 1
	end
	lanesTaken[lane] = player
	local record = { Player = player, Lane = lane, Exhausted = false }
	titans[player] = record
	build(record, player)
	self:RefreshDeck(player)
end

function TitanService:RemoveTitan(player: Player)
	local record = titans[player]
	if not record then
		return
	end
	if record.Model then
		record.Model:Destroy()
	end
	lanesTaken[record.Lane] = nil
	titans[player] = nil
end

function TitanService:Rebuild(player: Player)
	local record = titans[player]
	if not record then
		return
	end
	-- Remember who was standing on the old deck so they can be put back.
	local riders = {}
	for _, other in Players:GetPlayers() do
		local hrp = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		if hrp and self:IsOnDeck(record, hrp.Position) then
			table.insert(riders, other)
		end
	end
	if record.Model then
		record.Model:Destroy()
	end
	build(record, player)
	self:RefreshDeck(player)
	for _, other in riders do
		self:PlaceOnDeck(other, record)
	end
end

function TitanService:GetTitan(player: Player)
	return titans[player]
end

function TitanService:AllTitans()
	return titans
end

function TitanService:PlaceOnDeck(player: Player, record)
	record = record or titans[player]
	local character = player.Character
	if not record or not record.Deck or not character then
		return
	end
	local offset = CFrame.new(math.random(-2, 2), 4, record.DeckSize.Z * 0.1)
	character:PivotTo(record.Deck.CFrame * offset)
end

function TitanService:IsOnDeck(record, position: Vector3): boolean
	if not record or not record.Deck or not record.Deck.Parent then
		return false
	end
	local p = record.Deck.CFrame:PointToObjectSpace(position)
	local size = record.DeckSize
	return math.abs(p.X) <= size.X / 2 + 1 and math.abs(p.Z) <= size.Z / 2 + 1 and p.Y >= -1 and p.Y <= 12
end

function TitanService:TitanUnder(position: Vector3)
	for player, record in titans do
		if self:IsOnDeck(record, position) then
			return player, record
		end
	end
	return nil, nil
end

function TitanService:IsNearOwnTitan(player: Player): boolean
	local record = titans[player]
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not record or not record.Root or not hrp then
		return false
	end
	return (hrp.Position - record.Root.Position).Magnitude <= 30 * record.Scale + 10
end

function TitanService:Neighbors(player: Player)
	local record = titans[player]
	local result = {}
	if not record then
		return result
	end
	local mine = laneOffset(record.Lane)
	for other, otherRecord in titans do
		if other ~= player and math.abs(laneOffset(otherRecord.Lane) - mine) == 1 then
			table.insert(result, other)
		end
	end
	return result
end

-- Health (Nightfall) ---------------------------------------------------------

function TitanService:GetHealth(player: Player)
	local record = titans[player]
	if not record then
		return 0, 1
	end
	return record.Health, record.MaxHealth
end

function TitanService:Damage(player: Player, amount: number)
	local record = titans[player]
	if not record or record.Exhausted then
		return
	end
	record.Health = math.max(0, record.Health - amount)
	if record.Health <= 0 then
		record.Exhausted = true
		S.PlayerService:Notify(player, "Your titan is exhausted! Help the herd survive until dawn.")
	end
	self:UpdateBillboard(player)
	S.PlayerService:MarkDirty(player)
end

function TitanService:HealAll()
	for player, record in titans do
		record.Health = record.MaxHealth
		record.Exhausted = false
		self:UpdateBillboard(player)
		S.PlayerService:MarkDirty(player)
	end
end

-- Movement -------------------------------------------------------------------

function TitanService:Init(services)
	S = services
	herdFolder = Instance.new("Folder")
	herdFolder.Name = "Herd"
	herdFolder.Parent = workspace
end

function TitanService:Start()
	local billboardClock = 0
	RunService.Heartbeat:Connect(function(dt)
		if S.CycleService:IsDay() then
			angle = (angle + Config.Herd.DaySpeed / Config.Herd.PathRadius * dt) % (math.pi * 2)
		end
		local t = os.clock()
		for _, record in titans do
			if record.AlignPosition and record.AlignPosition.Parent then
				local cf = targetCFrame(record, t)
				record.AlignPosition.Position = cf.Position
				record.AlignOrientation.CFrame = cf
			end
		end
		billboardClock += dt
		if billboardClock >= 1 then
			billboardClock = 0
			for player in titans do
				self:UpdateBillboard(player)
			end
		end
	end)
end

return TitanService
