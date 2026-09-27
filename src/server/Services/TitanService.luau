-- Builds each player's titan, walks the whole herd around the migration loop,
-- and draws the Riders and eggs that live on each titan's deck.
--
-- A titan is one unanchored physics assembly held by rigid AlignPosition and
-- AlignOrientation constraints. Because it really moves (instead of being
-- teleported), players standing on the deck are carried along with it.
--
-- Titan parts sit in the "Titans" collision group, which only collides with
-- players. The rigid constraints would otherwise fight the terrain, buildings
-- and other titans, and fling everyone on the deck into the sky.

local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local CreatureModels = require(script.Parent.CreatureModels)
local Organic = require(script.Parent.Organic)

-- Parts that stay visible when a custom 3D model replaces the titan's body.
local TITAN_KEEP = {
	Root = true,
	Hull = true,
	Deck = true,
	Rail = true,
	LadderClimb = true,
	LadderRail = true,
	LadderRung = true,
	LadderPlank = true,
	LadderBase = true,
	Lantern = true,
	LanternPost = true,
	Mast = true,
	Banner = true,
	Saddle = true,
	SaddleBack = true,
	LeapPost = true,
}
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

local function herdCFrame(record, t: number): CFrame
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

-- Driving ----------------------------------------------------------------------

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.FilterDescendantsInstances = { workspace.Terrain }

local function groundY(x: number, z: number): number
	local hit = workspace:Raycast(Vector3.new(x, 800, z), Vector3.new(0, -1600, 0), groundParams)
	return hit and hit.Position.Y or 0
end

local function yawOf(cf: CFrame): number
	local look = cf.LookVector
	return math.atan2(-look.X, -look.Z)
end

-- Moves a titan that is being driven, or walking back to the herd after
-- its rider got off. Returns the titan's new target CFrame.
local function stepFree(record, dt: number, t: number): CFrame
	local s = record.Scale
	local cf = record.FreeCF or herdCFrame(record, t)
	local position = cf.Position
	local yaw = record.Yaw or yawOf(cf)
	local moving = false
	if record.Mode == "Driven" then
		local input = record.DriveInput
		yaw -= input.Steer * Config.Drive.TurnRate * dt
		local forward = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
		local speed = record.Exhausted and Config.Drive.Speed * 0.4 or Config.Drive.Speed
		position += forward * input.Throttle * speed * dt
		local flat = Vector3.new(position.X, 0, position.Z)
		if flat.Magnitude > Config.Drive.MaxRadius then
			flat = flat.Unit * Config.Drive.MaxRadius
		end
		position = Vector3.new(flat.X, position.Y, flat.Z)
		moving = input.Throttle ~= 0 or input.Steer ~= 0
	else -- Returning
		local target = herdCFrame(record, t)
		local delta = Vector3.new(target.X - position.X, 0, target.Z - position.Z)
		if delta.Magnitude < 4 then
			record.Mode = "Herd"
			record.FreeCF = nil
			record.Yaw = nil
			return target
		end
		position += delta.Unit * math.min(delta.Magnitude, Config.Drive.ReturnSpeed * dt)
		yaw = math.atan2(-delta.X, -delta.Z)
		moving = true
	end
	local y = groundY(position.X, position.Z) + 12 * s
	if record.Exhausted then
		y -= 4 * s
	elseif moving then
		y += math.sin(t * 4) * 0.35 * s
	end
	record.Yaw = yaw
	record.FreeCF = CFrame.new(position.X, y, position.Z) * CFrame.Angles(0, yaw, 0)
	return record.FreeCF
end

local function currentTarget(record, dt: number, t: number): CFrame
	if record.Mode == "Herd" then
		return herdCFrame(record, t)
	end
	return stepFree(record, dt, t)
end

function TitanService:_onSaddle(record, saddle: VehicleSeat)
	local occupant = saddle.Occupant
	if occupant then
		local who = Players:GetPlayerFromCharacter(occupant.Parent)
		if who ~= record.Player then
			task.defer(function()
				occupant.Sit = false
				occupant.Jump = true
			end)
			if who then
				S.PlayerService:Notify(who, "Only the titan's owner can ride in the saddle.")
			end
			return
		end
		if record.Mode == "Herd" then
			record.FreeCF = herdCFrame(record, os.clock())
			record.Yaw = yawOf(record.FreeCF)
		end
		record.Mode = "Driven"
		record.DriveInput = { Throttle = 0, Steer = 0 }
		pcall(function()
			record.Root:SetNetworkOwner(nil)
		end)
		S.PlayerService:Notify(record.Player, "You're driving your titan! W/S to walk, A/D to turn, Jump to get off.")
	elseif record.Mode == "Driven" then
		record.Mode = "Returning"
		record.DriveInput = nil
		S.PlayerService:Notify(record.Player, "Your titan heads back to the herd.")
	end
end

function TitanService:SetDriveInput(player: Player, throttle, steer)
	local record = titans[player]
	if not record or record.Mode ~= "Driven" or type(throttle) ~= "number" or type(steer) ~= "number" then
		return
	end
	if throttle ~= throttle or steer ~= steer then -- NaN
		return
	end
	record.DriveInput = { Throttle = math.clamp(throttle, -1, 1), Steer = math.clamp(steer, -1, 1) }
end

function TitanService:IsDriving(player: Player): boolean
	local record = titans[player]
	return record ~= nil and record.Mode == "Driven"
end

-- Building -------------------------------------------------------------------

-- Works out the colours and materials for a titan from its species, equipped
-- skin and mutation. On the Classic skin the mutation paints the shell; on any
-- other skin the skin wins and the mutation shows as a glowing aura instead.
local function resolveLook(profile, species, mutation)
	local skin = Util.find(Config.Skins, "Key", profile.EquippedSkin) or Config.Skins[1]
	local look = {
		Skin = skin,
		Body = skin.BodyColor or species.BodyColor,
		BodyMat = skin.BodyMaterial or species.SkinMaterial or Enum.Material.Leather,
		Belly = skin.BellyColor or species.BellyColor,
		Shell = skin.ShellColor or species.ShellColor,
		ShellMat = skin.ShellMaterial or species.ShellMaterial or Enum.Material.Slate,
		Accent = skin.AccentColor or species.AccentColor,
		AccentMat = skin.AccentMaterial or Enum.Material.Slate,
		Galaxy = skin.Galaxy == true,
		Rainbow = false,
	}
	if skin.Key == "Classic" then
		if mutation.Color then
			look.Shell = mutation.Color
			look.ShellMat = mutation.Material or look.ShellMat
			look.Body = look.Body:Lerp(mutation.Color, 0.3)
		end
		look.Rainbow = mutation.Rainbow == true
	end
	return look
end

local function particles(parent: BasePart, props)
	local emitter = Instance.new("ParticleEmitter")
	emitter.LightEmission = 1
	emitter.SpreadAngle = Vector2.new(180, 180)
	for key, value in props do
		emitter[key] = value
	end
	emitter.Parent = parent
	return emitter
end

local function light(parent: BasePart, color: Color3, range: number, brightness: number)
	local pointLight = Instance.new("PointLight")
	pointLight.Color = color
	pointLight.Range = range
	pointLight.Brightness = brightness
	pointLight.Parent = parent
	return pointLight
end

local function addEffects(shell: BasePart, look, mutation, s: number)
	local effect = look.Skin.Effect
	if effect == "Sparkles" then
		particles(shell, {
			Rate = 8,
			Lifetime = NumberRange.new(1, 2),
			Speed = NumberRange.new(1, 3),
			Size = NumberSequence.new(0.6 * s),
			Color = ColorSequence.new(look.Accent),
		})
	elseif effect == "Embers" then
		particles(shell, {
			Rate = 18,
			Lifetime = NumberRange.new(1.5, 3),
			Speed = NumberRange.new(2, 5),
			SpreadAngle = Vector2.new(30, 30),
			Acceleration = Vector3.new(0, 4, 0),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5 * s), NumberSequenceKeypoint.new(1, 0) }),
			Color = ColorSequence.new(Color3.fromRGB(255, 180, 60), Color3.fromRGB(255, 60, 0)),
		})
		light(shell, Color3.fromRGB(255, 120, 40), 20 * s, 2)
	elseif effect == "Lights" then
		light(shell, look.Accent, 22 * s, 2)
	elseif effect == "Stars" then
		particles(shell, {
			Rate = 14,
			Lifetime = NumberRange.new(2, 4),
			Speed = NumberRange.new(0.5, 1.5),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.7 * s), NumberSequenceKeypoint.new(1, 0) }),
			Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(180, 160, 255)),
		})
		light(shell, Color3.fromRGB(150, 110, 255), 18 * s, 1.5)
	end

	-- Mutation aura.
	if mutation.Name ~= "Normal" then
		local color = mutation.Rainbow
				and ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
					ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 240, 80)),
					ColorSequenceKeypoint.new(0.66, Color3.fromRGB(80, 220, 255)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 90, 255)),
				})
			or ColorSequence.new(mutation.Color)
		particles(shell, {
			Rate = 10,
			Lifetime = NumberRange.new(1.5, 2.5),
			Speed = NumberRange.new(3, 6),
			SpreadAngle = Vector2.new(40, 40),
			Acceleration = Vector3.new(0, 3, 0),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8 * s), NumberSequenceKeypoint.new(1, 0) }),
			Transparency = NumberSequence.new(0.2, 1),
			Color = color,
		})
		light(shell, mutation.Color or Color3.fromRGB(255, 255, 255), 16 * s, 1)
	end
end

local function build(record, player: Player)
	local profile = S.PlayerService:GetProfile(player)
	local stage = Config.Stages[profile.Stage]
	local species = Config.Species[profile.Species] or Config.Species.Shellback
	local mutation = Util.mutation(profile.TitanMutation)
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
		CFrame = record.Mode == "Herd" and herdCFrame(record, os.clock()) or (record.FreeCF or herdCFrame(record, os.clock())),
	})
	root.Parent = model
	model.PrimaryPart = root

	local body = Vector3.new(16, 10, 22) * s
	local look = resolveLook(profile, species, mutation)

	local function blob(name: string, size: Vector3, color: Color3, material: Enum.Material?, offset: CFrame)
		local part = attach(root, newPart({ Name = name, Size = size, Color = color, Material = material or Enum.Material.Leather }), offset, model)
		return Organic.shape(part, true)
	end
	local function tagShell(part: BasePart)
		local tag = look.Rainbow and "RainbowPart" or look.Galaxy and "GalaxyPart" or nil
		if tag then
			CollectionService:AddTag(part, tag)
			for _, lumpPart in part:GetChildren() do
				if lumpPart:IsA("BasePart") then
					CollectionService:AddTag(lumpPart, tag)
				end
			end
		end
	end
	-- Height of the shell's surface above the root at a given (x, z).
	local shellCenterY, shellA, shellB, shellC = body.Y * 0.3, body.X * 0.525, body.Y * 0.45, body.Z * 0.475
	local function shellSurfaceY(x: number, z: number): number
		local k = 1 - (x / shellA) ^ 2 - (z / shellC) ^ 2
		return shellCenterY + shellB * math.sqrt(math.max(0, k))
	end

	-- Body, belly and shell.
	blob("Body", body, look.Body, look.BodyMat, CFrame.new())
	blob("Belly", Vector3.new(body.X * 0.86, body.Y * 0.55, body.Z * 0.88), look.Belly, look.BodyMat, CFrame.new(0, -body.Y * 0.22, 0))
	attach(root, newPart({ Name = "Hull", Size = body * 0.85, Transparency = 1, CanCollide = true }), CFrame.new(), model)
	local shell = blob("Shell", Vector3.new(shellA * 2, shellB * 2, shellC * 2), look.Shell, look.ShellMat, CFrame.new(0, shellCenterY, 0))
	tagShell(shell)
	blob("ShellRim", Vector3.new(body.X * 1.14, 1.8 * s, body.Z * 1.04), look.Accent, look.AccentMat, CFrame.new(0, body.Y * 0.08, 0))
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		local px, pz = math.cos(a) * shellA * 0.84, math.sin(a) * shellC * 0.84
		local plate = blob(
			"ShellPlate",
			Vector3.new(4, 1.2, 4) * s,
			look.Shell:Lerp(Color3.new(0, 0, 0), 0.2),
			look.ShellMat,
			CFrame.new(px, shellSurfaceY(px, pz) - 0.2 * s, pz) * CFrame.Angles(math.sin(a) * 0.6, 0, -math.cos(a) * 0.6)
		)
		tagShell(plate)
	end

	-- Head: heavy brow, glowing slit eyes, a jaw full of teeth and horns.
	local headOffset = CFrame.new(0, body.Y * 0.15, -(body.Z / 2 + 2.6 * s))
	local head = blob("Head", Vector3.new(7.5, 6.2, 8) * s, look.Body, look.BodyMat, headOffset)
	local dark = look.Body:Lerp(Color3.new(0, 0, 0), 0.35)
	local bone = Color3.fromRGB(225, 215, 190)
	local eyeColor = look.Skin.Key == "Classic" and Color3.fromRGB(255, 150, 20) or look.Accent
	for _, side in { -1, 1 } do
		local eyeOffset = headOffset * CFrame.new(side * 2.2 * s, 1 * s, -3.3 * s) * CFrame.Angles(0, 0, side * 0.25)
		blob("EyeSocket", Vector3.new(2.4, 1.4, 1.2) * s, Color3.fromRGB(15, 10, 10), nil, eyeOffset)
		local eye = blob("Eye", Vector3.new(1.9, 0.7, 0.6) * s, eyeColor, Enum.Material.Neon, eyeOffset * CFrame.new(0, 0, -0.45 * s))
		if side == 1 then
			light(eye, eyeColor, 14 * s, 1.5)
		end
		blob(
			"Brow",
			Vector3.new(3, 1, 2.2) * s,
			dark,
			look.BodyMat,
			headOffset * CFrame.new(side * 2.1 * s, 1.9 * s, -2.9 * s) * CFrame.Angles(0.3, 0, -side * 0.35)
		)
		-- Curved horns in two segments.
		local hornBase = headOffset * CFrame.new(side * 2.6 * s, 2.6 * s, 0.5 * s) * CFrame.Angles(-0.6, 0, -side * 0.5)
		blob("Horn", Vector3.new(1.4, 4, 1.4) * s, bone, Enum.Material.Slate, hornBase)
		blob(
			"Horn",
			Vector3.new(0.9, 3.2, 0.9) * s,
			bone:Lerp(dark, 0.3),
			Enum.Material.Slate,
			hornBase * CFrame.new(0, 2.8 * s, 0.4 * s) * CFrame.Angles(-0.7, 0, 0)
		)
	end
	-- Jaws and teeth.
	local snoutOffset = headOffset * CFrame.new(0, -1.1 * s, -3.4 * s)
	if profile.Species ~= "Tuskhorn" then
		blob("Snout", Vector3.new(5, 2.8, 4) * s, look.Body, look.BodyMat, snoutOffset)
	end
	blob("Jaw", Vector3.new(4.6, 1.4, 4.4) * s, dark, look.BodyMat, snoutOffset * CFrame.new(0, -1.9 * s, 0.2 * s) * CFrame.Angles(0.18, 0, 0))
	blob("Mouth", Vector3.new(4.2, 0.9, 3.6) * s, Color3.fromRGB(60, 10, 10), nil, snoutOffset * CFrame.new(0, -1.2 * s, 0))
	for i = -3, 3 do
		local x = i * 0.6 * s
		local tooth = Instance.new("WedgePart")
		tooth.Name = "Tooth"
		tooth.Size = Vector3.new(0.35, 0.9, 0.35) * s
		tooth.Color = bone
		tooth.Anchored = false
		tooth.CanCollide = false
		tooth.Massless = true
		attach(root, tooth, snoutOffset * CFrame.new(x, -1.1 * s, -1.7 * s + math.abs(i) * 0.25 * s) * CFrame.Angles(math.pi, 0, 0), model)
		if i % 2 == 0 then
			local lower = tooth:Clone()
			attach(root, lower, snoutOffset * CFrame.new(x + 0.3 * s, -1.6 * s, -1.6 * s + math.abs(i) * 0.25 * s), model)
		end
	end
	-- Hot breath from the nostrils.
	local nostril = blob("Nostril", Vector3.new(1.4, 0.6, 0.6) * s, Color3.fromRGB(20, 15, 15), nil, snoutOffset * CFrame.new(0, 0.6 * s, -1.9 * s))
	particles(nostril, {
		Rate = 3,
		Lifetime = NumberRange.new(1.5, 2.5),
		Speed = NumberRange.new(2, 4),
		SpreadAngle = Vector2.new(15, 15),
		EmissionDirection = Enum.NormalId.Front,
		LightEmission = 0,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6 * s), NumberSequenceKeypoint.new(1, 2.5 * s) }),
		Transparency = NumberSequence.new(0.6, 1),
		Color = ColorSequence.new(Color3.fromRGB(200, 200, 200)),
	})
	-- Battle scars.
	for i = 1, 3 do
		local side = i % 2 == 0 and -1 or 1
		attach(
			root,
			newPart({ Name = "Scar", Size = Vector3.new(0.3, 0.3, 4 * s), Color = look.Belly:Lerp(Color3.fromRGB(150, 70, 70), 0.4) }),
			CFrame.new(side * body.X * 0.49, -body.Y * 0.05 + i * 0.8 * s, (i - 2) * 3 * s) * CFrame.Angles(0.5 * side, 0, 0),
			model
		)
	end

	-- Species features.
	if profile.Species == "Shellback" then
		for _, side in { -1, 1 } do
			for i = -2, 2 do
				local pz = i * shellC * 0.3
				local px = side * shellA * 0.92
				blob(
					"Spike",
					Vector3.new(1.4, 3.4, 1.4) * s,
					look.Accent,
					look.AccentMat,
					CFrame.new(px, shellSurfaceY(px * 0.95, pz) + 0.6 * s, pz) * CFrame.Angles(0, 0, -side * 0.7)
				)
			end
		end
		for i = -2, 2 do
			blob(
				"RidgeSpike",
				Vector3.new(1.6, 4.5, 2.2) * s,
				look.Accent,
				look.AccentMat,
				CFrame.new(0, shellSurfaceY(0, i * shellC * 0.35) + 1.4 * s, i * shellC * 0.35)
			)
		end
	elseif profile.Species == "Mossback" then
		for i = 0, 13 do
			local a = i / 14 * math.pi * 2
			local px, pz = math.cos(a) * shellA * 0.95, math.sin(a) * shellC * 0.95
			blob("Moss", Vector3.new(3, 2, 3) * s, Color3.fromRGB(50, 80, 40), Enum.Material.Grass, CFrame.new(px, shellSurfaceY(px * 0.9, pz * 0.9), pz))
			if i % 2 == 0 then
				blob("Thorn", Vector3.new(0.6, 2.2, 0.6) * s, look.Accent, look.AccentMat, CFrame.new(px, shellSurfaceY(px * 0.9, pz * 0.9) + 1.1 * s, pz))
			end
		end
		blob("Beard", Vector3.new(4, 3, 2) * s, Color3.fromRGB(50, 80, 40), Enum.Material.Grass, headOffset * CFrame.new(0, -3.4 * s, -2 * s))
	elseif profile.Species == "Tuskhorn" then
		for _, side in { -1, 1 } do
			blob(
				"Tusk",
				Vector3.new(1.1, 1.1, 6) * s,
				look.Accent,
				look.AccentMat,
				headOffset * CFrame.new(side * 1.8 * s, -2.2 * s, -4.5 * s) * CFrame.Angles(0.5, side * 0.2, 0)
			)
			blob(
				"Ear",
				Vector3.new(0.7, 6, 5.5) * s,
				dark,
				look.BodyMat,
				headOffset * CFrame.new(side * 4 * s, 0.5 * s, 0.5 * s) * CFrame.Angles(0, side * 0.35, side * 0.15)
			)
		end
		for i = 1, 4 do
			local size = (3.2 - i * 0.45) * s
			blob(
				"Trunk",
				Vector3.new(size, size, size * 1.3),
				look.Body,
				look.BodyMat,
				headOffset * CFrame.new(0, -0.8 * s - i * 1.4 * s, -3.6 * s - i * 0.5 * s)
			)
		end
	elseif profile.Species == "Driftfin" then
		for _, side in { -1, 1 } do
			local fin = Instance.new("WedgePart")
			fin.Size = Vector3.new(0.6, 5, 8) * s
			fin.Color = look.Accent
			fin.Material = look.AccentMat
			fin.Anchored = false
			fin.CanCollide = false
			fin.Massless = true
			attach(root, fin, CFrame.new(side * body.X * 0.52, -body.Y * 0.05, 0) * CFrame.Angles(0, 0, side * 1.2), model)
			for i = -2, 2 do
				blob("GlowSpot", Vector3.one * 0.9 * s, look.Accent, Enum.Material.Neon, CFrame.new(side * body.X * 0.49, body.Y * 0.1, i * body.Z * 0.14))
			end
		end
	end

	-- Crown for the Golden King skin.
	if look.Skin.Crown then
		local crownBase = headOffset * CFrame.new(0, 3.4 * s, 0)
		blob("Crown", Vector3.new(3.8, 1, 3.8) * s, look.Shell, look.ShellMat, crownBase)
		for i = 0, 4 do
			local a = i / 5 * math.pi * 2
			blob(
				"CrownPoint",
				Vector3.new(0.8, 2, 0.8) * s,
				look.Shell,
				look.ShellMat,
				crownBase * CFrame.new(math.cos(a) * 1.5 * s, 1 * s, math.sin(a) * 1.5 * s)
			)
		end
		blob("CrownGem", Vector3.one * 0.9 * s, look.Accent, Enum.Material.Neon, crownBase * CFrame.new(0, 0.3 * s, -1.9 * s))
	end

	-- Heavy legs with clawed feet.
	local legHeight = 10 * s
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			local legOffset = CFrame.new(x * body.X * 0.32, -12 * s + legHeight / 2, z * body.Z * 0.3)
			attach(
				root,
				newPart({
					Name = "Leg",
					Shape = Enum.PartType.Cylinder,
					Size = Vector3.new(legHeight, 4.2 * s, 4.2 * s),
					Color = look.Body,
					Material = look.BodyMat,
				}),
				legOffset * CFrame.Angles(0, 0, math.pi / 2),
				model
			)
			local footOffset = CFrame.new(x * body.X * 0.32, -12 * s + 0.9 * s, z * body.Z * 0.3 - 0.4 * s)
			blob("Foot", Vector3.new(5.4, 1.8, 6) * s, look.Body:Lerp(Color3.new(0, 0, 0), 0.12), look.BodyMat, footOffset)
			for toe = -1, 1 do
				blob(
					"Claw",
					Vector3.new(0.8, 0.8, 2.6) * s,
					Color3.fromRGB(35, 30, 28),
					Enum.Material.Slate,
					footOffset * CFrame.new(toe * 1.6 * s, -0.2 * s, -3 * s) * CFrame.Angles(0.35, 0, 0)
				)
			end
		end
	end

	-- Tail.
	local tailSizes = { Vector3.new(3.6, 3, 4.5), Vector3.new(2.6, 2.2, 3.6), Vector3.new(1.6, 1.4, 2.6) }
	local tailZ = body.Z / 2
	for i, size in tailSizes do
		tailZ += size.Z * s * 0.6
		blob("Tail", size * s, look.Body, look.BodyMat, CFrame.new(0, -body.Y * 0.1 - i * 0.6 * s, tailZ))
		blob("TailSpike", Vector3.new(0.7, 2.2, 0.9) * s, look.Accent, look.AccentMat, CFrame.new(0, -body.Y * 0.1 - i * 0.6 * s + size.Y * s * 0.5, tailZ))
	end

	addEffects(shell, look, mutation, s)

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

	-- Ladders on both sides so anyone on the ground can climb aboard (thieves
	-- included). An invisible truss does the climbing; the rails and rungs are
	-- what players see. A plank bridges the ladder top to the deck, and a
	-- "Climb" prompt at the bottom lifts you straight up (handy on mobile).
	local rootY = 12 * s
	local deckTop = rootY + deckY + 0.5
	local ladderX = body.X * 0.58 + 1.5
	local ladderHeight = math.max(4, math.floor((deckTop - 0.5) / 2) * 2)
	local ground = -rootY
	local wood = Color3.fromRGB(160, 112, 64)
	for _, side in { -1, 1 } do
		local x = side * ladderX
		local truss = Instance.new("TrussPart")
		truss.Name = "LadderClimb"
		truss.Size = Vector3.new(2, ladderHeight, 2)
		truss.Transparency = 1
		truss.Anchored = false
		truss.Massless = true
		truss.CanCollide = true
		attach(root, truss, CFrame.new(x, ground + 0.5 + ladderHeight / 2, 0), model)
		for _, z in { -1.3, 1.3 } do
			attach(
				root,
				newPart({ Name = "LadderRail", Size = Vector3.new(0.5, ladderHeight, 0.5), Color = wood, Material = Enum.Material.Wood }),
				CFrame.new(x + side * 0.4, ground + 0.5 + ladderHeight / 2, z),
				model
			)
		end
		for y = 1.5, ladderHeight, 2 do
			attach(
				root,
				newPart({ Name = "LadderRung", Size = Vector3.new(0.4, 0.4, 2.6), Color = wood:Lerp(Color3.new(1, 1, 1), 0.15), Material = Enum.Material.Wood }),
				CFrame.new(x + side * 0.4, ground + y, 0),
				model
			)
		end
		local inner = deckSize.X / 2 - 0.5
		local plankLength = ladderX - inner + 1
		attach(
			root,
			newPart({ Name = "LadderPlank", Size = Vector3.new(plankLength, 0.6, 4), CanCollide = true, Color = wood, Material = Enum.Material.WoodPlanks }),
			CFrame.new(side * (inner + plankLength / 2), deckY + 0.2, 0),
			model
		)
		local base = attach(root, newPart({ Name = "LadderBase", Size = Vector3.new(3, 3, 3), Transparency = 1 }), CFrame.new(x, ground + 1.5, 0), model)
		local climb = addPrompt(base, { ActionText = "Climb", ObjectText = "Titan ladder", HoldDuration = 0, MaxActivationDistance = 10 })
		climb.Triggered:Connect(function(who)
			TitanService:PlaceOnDeck(who, record)
		end)
	end

	-- Lanterns on the deck corners and a flag at the front.
	for _, cx in { -1, 1 } do
		for _, cz in { -1, 1 } do
			local offset = CFrame.new(cx * (deckSize.X / 2 - 1), deckY + 2.5, cz * (deckSize.Z / 2 - 1))
			attach(root, newPart({ Name = "LanternPost", Size = Vector3.new(0.5, 4, 0.5), Color = wood, Material = Enum.Material.Wood }), offset, model)
			local lamp = attach(
				root,
				newPart({ Name = "Lantern", Size = Vector3.one * 1.3, Color = Color3.fromRGB(255, 210, 120), Material = Enum.Material.Neon }),
				offset * CFrame.new(0, 2.4, 0),
				model
			)
			light(lamp, Color3.fromRGB(255, 200, 120), 16, 1.2)
		end
	end
	local mastOffset = CFrame.new(0, deckY + 4.5, -deckSize.Z / 2 - 1)
	attach(root, newPart({ Name = "Mast", Size = Vector3.new(0.4, 8, 0.4), Color = wood, Material = Enum.Material.Wood }), mastOffset, model)
	attach(
		root,
		newPart({ Name = "Banner", Size = Vector3.new(0.2, 2.2, 3.6), Color = look.Accent, Material = Enum.Material.Fabric }),
		mastOffset * CFrame.new(0, 2.6, 1.9),
		model
	)

	-- Saddle: the owner sits here to drive the titan.
	local saddle = Instance.new("VehicleSeat")
	saddle.Name = "Saddle"
	saddle.Size = Vector3.new(3, 1.2, 3)
	saddle.Color = Color3.fromRGB(90, 40, 30)
	saddle.Material = Enum.Material.Fabric
	saddle.Anchored = false
	saddle.Massless = true
	saddle.CanCollide = true
	saddle.MaxSpeed = 0
	saddle.Torque = 0
	saddle.TurnSpeed = 0
	saddle.HeadsUpDisplay = false
	attach(root, saddle, CFrame.new(0, deckY + 1.1, -deckSize.Z * 0.2), model)
	attach(
		root,
		newPart({ Name = "SaddleBack", Size = Vector3.new(3, 2, 0.6), Color = Color3.fromRGB(70, 30, 22), Material = Enum.Material.Fabric }),
		CFrame.new(0, deckY + 2.2, -deckSize.Z * 0.2 + 1.5),
		model
	)
	saddle:GetPropertyChangedSignal("Occupant"):Connect(function()
		TitanService:_onSaddle(record, saddle)
	end)

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

	-- A real 3D model from ServerStorage > CreatureModels, if one is set up,
	-- replaces the built-in body. It stands on the ground with its back
	-- under the deck; everything players stand on stays as it is.
	local groundToDeck = 12 * s + deckY
	local custom = CreatureModels.place({ "Titan_" .. profile.Species, "Titan" }, groundToDeck, root.CFrame * CFrame.new(0, deckY - groundToDeck / 2, 0))
	if custom then
		CreatureModels.hideBuiltIn(model, TITAN_KEEP, items)
		CreatureModels.attach(custom, root, true)
		custom.Name = "CustomBody"
		custom.Parent = model
	end

	record.Model = model
	record.Root = root
	record.Head = head
	local function setGroup(descendant: Instance)
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = "Titans"
		end
	end
	for _, descendant in model:GetDescendants() do
		setGroup(descendant)
	end
	model.DescendantAdded:Connect(setGroup)
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
			Material = mutation.Material or Enum.Material.Fabric,
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
	local crown = player:GetAttribute("Guardian") and "[Guardian] " or ""
	record.NameLabel.Text = string.format("%s%s's %s%s", crown, player.DisplayName, mutation, species)
	local info = Config.Stages[profile.Stage].Name
	if profile.Molts > 0 then
		info ..= string.format("  •  Molt %d", profile.Molts)
	end
	if S.PlayerService:IsLocked(player) then
		info ..= "•  Shell Lock"
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
	local record = { Player = player, Lane = lane, Exhausted = false, Mode = "Herd" }
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
	if record.Mode == "Driven" then
		record.Mode = "Returning"
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
	-- Carry the deck's motion, not the speed of whatever fall came before.
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.AssemblyLinearVelocity = record.Deck.AssemblyLinearVelocity
			descendant.AssemblyAngularVelocity = Vector3.zero
		end
	end
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
	PhysicsService:RegisterCollisionGroup("Titans")
	PhysicsService:RegisterCollisionGroup("Players")
	for _, group in PhysicsService:GetRegisteredCollisionGroups() do
		if group.name ~= "Players" then
			PhysicsService:CollisionGroupSetCollidable("Titans", group.name, false)
		end
	end
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
				local cf = currentTarget(record, dt, t)
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
