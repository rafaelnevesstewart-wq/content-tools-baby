-- Walks everyone's pet after its owner on this screen, and brings it to
-- life (see server Modules/PetModels): legs swing while it walks, tails wag,
-- wings flap, hoppers hop, and a pet that's standing still sniffs the ground
-- now and then. Walkers follow the ground; flyers hover over your shoulder.
-- A pet hides while its owner is invisible (potion), and other players'
-- pets can be hidden in ⚙️ Settings.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Settings = require(script.Parent.Settings)

local player = Players.LocalPlayer

local PetFollower = {}

local DRAW_DISTANCE = 150

type Joint = { weld: Weld, base: CFrame, phase: number }
type Pet = {
	model: Model,
	root: BasePart,
	parts: { BasePart },
	legs: { Joint },
	necks: { Joint },
	tails: { Joint },
	wings: { Joint },
	lastPosition: Vector3,
	speed: number,
	walk: number, -- gait angle
	grazeUntil: number,
	nextGraze: number,
	flies: boolean,
	hops: boolean,
	height: number,
	hidden: boolean,
	position: Vector3,
	facing: Vector3,
}

local pets: { [Model]: Pet } = {}
local rng = Random.new()
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.IgnoreWater = false

local function add(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local root = model:WaitForChild("Root", 5)
	task.wait(0.2) -- let the joints replicate
	if not root or not root:IsA("BasePart") or not model.Parent then
		return
	end
	local height = model:GetAttribute("Height")
	local pet: Pet = {
		model = model,
		root = root,
		parts = {},
		legs = {},
		necks = {},
		tails = {},
		wings = {},
		lastPosition = root.Position,
		speed = 0,
		walk = 0,
		grazeUntil = 0,
		nextGraze = os.clock() + rng:NextNumber(3, 8),
		flies = model:GetAttribute("Flies") == true,
		hops = model:GetAttribute("Hops") == true,
		height = if type(height) == "number" then height else 1,
		hidden = false,
		position = root.Position,
		facing = root.CFrame.LookVector,
	}
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") and item ~= root then
			table.insert(pet.parts, item)
		elseif item:IsA("Weld") then
			local phase = item:GetAttribute("Phase")
			local joint = { weld = item, base = item.C0, phase = if type(phase) == "number" then phase else 0 }
			if item.Name == "Leg" then
				table.insert(pet.legs, joint)
			elseif item.Name == "Neck" then
				table.insert(pet.necks, joint)
			elseif item.Name == "Tail" then
				table.insert(pet.tails, joint)
			elseif item.Name == "Wing" then
				table.insert(pet.wings, joint)
			end
		end
	end
	pets[model] = pet
end

local function setHidden(pet: Pet, hidden: boolean)
	if pet.hidden == hidden then
		return
	end
	pet.hidden = hidden
	for _, part in pet.parts do
		part.LocalTransparencyModifier = if hidden then 1 else 0
	end
	for _, item in pet.model:GetDescendants() do
		-- The level tag, sparkles and glow.
		if item:IsA("BillboardGui") or item:IsA("Sparkles") or item:IsA("PointLight") then
			item.Enabled = not hidden
		end
	end
end

-- Where the ground is under a spot (or nil over the void).
local function groundAt(spot: Vector3, fromY: number): number?
	local hit = workspace:Raycast(Vector3.new(spot.X, fromY + 4, spot.Z), Vector3.new(0, -40, 0), params)
	return if hit then hit.Position.Y else nil
end

local function follow(pet: Pet, ownerRoot: BasePart, dt: number, t: number)
	local owner = ownerRoot.CFrame
	local slot = (owner * CFrame.new(2.8, 0, 3)).Position
	local current = pet.position
	local flat = Vector3.new(slot.X - current.X, 0, slot.Z - current.Z)
	local distance = flat.Magnitude
	if distance > 60 or math.abs(slot.Y - current.Y) > 40 then
		-- Left far behind (a teleport or respawn): catch up at once.
		current = slot
		distance = 0
	elseif distance > 0.8 then
		local speed = math.clamp(distance * 4, 10, 70)
		current += flat.Unit * math.min(distance - 0.6, speed * dt)
		pet.facing = flat.Unit
	else
		local look = owner.LookVector * Vector3.new(1, 0, 1)
		if look.Magnitude > 0.01 then
			pet.facing = pet.facing:Lerp(look.Unit, math.min(1, dt * 3))
		end
	end
	local y: number
	if pet.flies then
		y = ownerRoot.Position.Y + 2.5 + math.sin(t * 2) * 0.4
	else
		local ground = groundAt(current, ownerRoot.Position.Y)
		y = if ground then ground + pet.height else ownerRoot.Position.Y - 3 + pet.height
		if pet.hops and pet.speed > 1 then
			y += math.abs(math.sin(pet.walk * 0.8)) * 0.9
		end
	end
	current = Vector3.new(current.X, current.Y + (y - current.Y) * math.min(1, dt * 12), current.Z)
	pet.position = current
	local facing = if pet.facing.Magnitude > 0.01 then pet.facing.Unit else Vector3.zAxis
	pet.root.CFrame = CFrame.lookAt(current, current + facing)
end

local function animate(pet: Pet, dt: number, t: number)
	local walking = math.clamp(pet.speed / 2, 0, 1)
	pet.walk += dt * (4 + math.min(pet.speed, 20) * 1.2)

	-- Legs: a trotting swing while moving (hoppers tuck theirs).
	for _, joint in pet.legs do
		local swing = if pet.hops
			then -math.abs(math.sin(pet.walk * 0.8)) * 0.5 * walking
			else math.sin(pet.walk + joint.phase) * 0.6 * walking
		joint.weld.C0 = joint.base * CFrame.Angles(swing, 0, 0)
	end

	-- Head: a little bob, or a slow dip to sniff when standing still.
	if walking < 0.1 and t >= pet.nextGraze and not pet.flies then
		pet.grazeUntil = t + rng:NextNumber(1.5, 3)
		pet.nextGraze = pet.grazeUntil + rng:NextNumber(4, 10)
	end
	local grazing = t < pet.grazeUntil and walking < 0.1
	for _, joint in pet.necks do
		local target = if grazing
			then 0.55 + math.sin(t * 6) * 0.05
			else math.sin(t * 2) * 0.06 + walking * math.sin(pet.walk * 2) * 0.05
		joint.weld.C0 = joint.base * CFrame.Angles(target, math.sin(t * 0.7) * 0.15, 0)
	end

	-- Tail: wags faster while walking.
	for _, joint in pet.tails do
		joint.weld.C0 = joint.base * CFrame.Angles(0, math.sin(t * (3 + walking * 6)) * 0.35, 0)
	end

	-- Wings: flap hard when flying, flutter now and then otherwise.
	for index, joint in pet.wings do
		local side = if index % 2 == 0 then 1 else -1
		local flap = if pet.flies then math.sin(t * 8) * 0.6 else math.max(0, math.sin(t * 1.3)) ^ 8 * 0.5
		joint.weld.C0 = joint.base * CFrame.Angles(0, 0, side * flap)
	end
end

function PetFollower.start()
	for _, model in CollectionService:GetTagged("FollowerPet") do
		task.spawn(add, model)
	end
	CollectionService:GetInstanceAddedSignal("FollowerPet"):Connect(function(model)
		task.spawn(add, model)
	end)
	CollectionService:GetInstanceRemovedSignal("FollowerPet"):Connect(function(model)
		pets[model :: Model] = nil
	end)

	RunService.RenderStepped:Connect(function(dt)
		local camera = workspace.CurrentCamera
		if not camera or dt <= 0 then
			return
		end
		-- The ground check skips pets and players.
		local ignore: { Instance } = {}
		local folder = workspace:FindFirstChild("Pets")
		if folder then
			table.insert(ignore, folder)
		end
		for _, other in Players:GetPlayers() do
			if other.Character then
				table.insert(ignore, other.Character)
			end
		end
		params.FilterDescendantsInstances = ignore

		local eye = camera.CFrame.Position
		local t = os.clock()
		local showOthers = Settings.get("othersPets") == true
		for model, pet in pets do
			if not model.Parent then
				pets[model] = nil
				continue
			end
			local owner = Players:GetPlayerByUserId(model:GetAttribute("OwnerId") or 0)
			local character = owner and owner.Character
			local ownerRoot = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local hidden = not owner
				or not ownerRoot
				or owner:GetAttribute("Invisible") == true
				or (owner ~= player and not showOthers)
			setHidden(pet, hidden)
			if hidden or not ownerRoot then
				continue
			end
			follow(pet, ownerRoot, dt, t)

			local position = pet.root.Position
			local moved = Vector3.new(position.X - pet.lastPosition.X, 0, position.Z - pet.lastPosition.Z).Magnitude
			pet.lastPosition = position
			pet.speed += (moved / dt - pet.speed) * math.min(1, dt * 8)
			if (position - eye).Magnitude <= DRAW_DISTANCE then
				animate(pet, dt, t)
			end
		end
	end)
end

return PetFollower
