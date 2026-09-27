-- Brings island pets to life on this screen (see server Modules/PetModels):
-- legs swing while they walk, tails wag, wings flap, and now and then they
-- lower their head to graze or peck. Only pets near the camera animate.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local PetAnimator = {}

local DRAW_DISTANCE = 150

type Joint = { weld: Weld, base: CFrame, phase: number }
type Pet = {
	root: BasePart,
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
}

local pets: { [Model]: Pet } = {}
local rng = Random.new()

local function add(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local root = model:WaitForChild("Root", 5)
	task.wait(0.2) -- let the joints replicate
	if not root or not root:IsA("BasePart") or not model.Parent then
		return
	end
	local pet: Pet = {
		root = root,
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
	}
	for _, item in model:GetDescendants() do
		if item:IsA("Weld") then
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

function PetAnimator.start()
	for _, model in CollectionService:GetTagged("IslandPet") do
		task.spawn(add, model)
	end
	CollectionService:GetInstanceAddedSignal("IslandPet"):Connect(function(model)
		task.spawn(add, model)
	end)
	CollectionService:GetInstanceRemovedSignal("IslandPet"):Connect(function(model)
		pets[model :: Model] = nil
	end)

	RunService.RenderStepped:Connect(function(dt)
		local camera = workspace.CurrentCamera
		if not camera or dt <= 0 then
			return
		end
		local eye = camera.CFrame.Position
		local t = os.clock()
		for model, pet in pets do
			if not model.Parent then
				pets[model] = nil
				continue
			end
			local position = pet.root.Position
			local moved = Vector3.new(position.X - pet.lastPosition.X, 0, position.Z - pet.lastPosition.Z).Magnitude
			pet.lastPosition = position
			pet.speed += (moved / dt - pet.speed) * math.min(1, dt * 8)
			if (position - eye).Magnitude > DRAW_DISTANCE then
				continue
			end
			local walking = math.clamp(pet.speed / 2, 0, 1)
			pet.walk += dt * (4 + pet.speed * 2.2)

			-- Legs: a trotting swing while moving.
			for _, joint in pet.legs do
				local swing = math.sin(pet.walk + joint.phase) * 0.6 * walking
				joint.weld.C0 = joint.base * CFrame.Angles(swing, 0, 0)
			end

			-- Head: a little bob, or a slow dip to graze when standing still.
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
	end)
end

return PetAnimator
