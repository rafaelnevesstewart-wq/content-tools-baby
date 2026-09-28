-- Animates flashy effects on this screen for anything tagged "FlashyFx"
-- (kit storms, cloud beds, cosmetics). Read from attributes and names:
--   Bolts (Color3 attribute)  lightning bolts crackle around it
--   Rainbow (true)            puffs / parts cycle through the rainbow
--   Pulse: a PointLight named "PulseLight" throbs
--   Spin: every Weld named "SpinWeld" turns (its "Speed" attribute, rad/s)
--   RotorSpeed (number, on an anchored Model): the whole model turns around
--   its PrimaryPart's Y axis (windmill sails)
-- Only things near the camera are animated.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local FlashyFx = {}

local DRAW_DISTANCE = 180

type Spin = { weld: Weld, base: CFrame, speed: number }
type Entry = {
	instance: Instance,
	spins: { Spin },
	rainbow: { BasePart },
	pulses: { PointLight },
	bolts: Color3?,
	rotor: { base: CFrame, speed: number }?,
	nextBolt: number,
	phase: number,
}

local tracked: { [Instance]: Entry } = {}
local rng = Random.new()

local function pivotOf(instance: Instance): Vector3?
	if instance:IsA("Model") then
		return instance:GetPivot().Position
	elseif instance:IsA("BasePart") then
		return instance.Position
	end
	return nil
end

local function add(instance: Instance)
	task.wait() -- let its children replicate
	if not instance.Parent then
		return
	end
	local entry: Entry = {
		instance = instance,
		spins = {},
		rainbow = {},
		pulses = {},
		bolts = nil,
		rotor = nil,
		nextBolt = os.clock() + rng:NextNumber(0.2, 1.5),
		phase = rng:NextNumber(0, 1),
	}
	local rainbowAll = instance:GetAttribute("Rainbow") == true
	for _, item in instance:GetDescendants() do
		if item:IsA("Weld") and item.Name == "SpinWeld" then
			local speed = item:GetAttribute("Speed")
			table.insert(
				entry.spins,
				{ weld = item, base = item.C0, speed = if type(speed) == "number" then speed else 1.5 }
			)
		elseif item:IsA("PointLight") and item.Name == "PulseLight" then
			table.insert(entry.pulses, item)
		elseif item:IsA("BasePart") then
			if
				item:GetAttribute("Rainbow") == true
				or (rainbowAll and (item.Name == "Puff" or item.Name == "CloudPuff"))
			then
				table.insert(entry.rainbow, item)
			end
		end
	end
	local rotorSpeed = instance:GetAttribute("RotorSpeed")
	if instance:IsA("Model") and type(rotorSpeed) == "number" and instance.PrimaryPart then
		entry.rotor = { base = instance:GetPivot(), speed = rotorSpeed }
	end
	local bolts = instance:GetAttribute("Bolts")
	entry.bolts = if typeof(bolts) == "Color3" then bolts else nil
	tracked[instance] = entry
end

-- A jagged bolt between two points: a few bright segments and a flash.
local function bolt(from: Vector3, to: Vector3, color: Color3)
	local points = { from }
	local steps = 4
	for i = 1, steps - 1 do
		local base = from:Lerp(to, i / steps)
		table.insert(
			points,
			base + Vector3.new(rng:NextNumber(-0.8, 0.8), rng:NextNumber(-0.8, 0.8), rng:NextNumber(-0.8, 0.8))
		)
	end
	table.insert(points, to)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local segment = Instance.new("Part")
		segment.Anchored = true
		segment.CanCollide = false
		segment.CanTouch = false
		segment.CanQuery = false
		segment.CastShadow = false
		segment.Material = Enum.Material.Neon
		segment.Color = color
		segment.Size = Vector3.new(0.15, 0.15, (b - a).Magnitude)
		segment.CFrame = CFrame.lookAt((a + b) / 2, b)
		segment.Parent = workspace
		Debris:AddItem(segment, 0.1)
		if i == 2 then
			local flash = Instance.new("PointLight")
			flash.Color = color
			flash.Range = 14
			flash.Brightness = 4
			flash.Parent = segment
		end
	end
end

function FlashyFx.start()
	for _, instance in CollectionService:GetTagged("FlashyFx") do
		task.spawn(add, instance)
	end
	CollectionService:GetInstanceAddedSignal("FlashyFx"):Connect(function(instance)
		task.spawn(add, instance)
	end)
	CollectionService:GetInstanceRemovedSignal("FlashyFx"):Connect(function(instance)
		tracked[instance] = nil
	end)

	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local eye = camera.CFrame.Position
		local t = os.clock()
		for instance, entry in tracked do
			if not instance.Parent then
				tracked[instance] = nil
				continue
			end
			local pivot = pivotOf(instance)
			if not pivot or (pivot - eye).Magnitude > DRAW_DISTANCE then
				continue
			end
			local rotor = entry.rotor
			if rotor and instance:IsA("Model") then
				instance:PivotTo(rotor.base * CFrame.Angles(0, t * rotor.speed, 0))
			end
			for _, spin in entry.spins do
				spin.weld.C0 = spin.base * CFrame.Angles(0, t * spin.speed, 0)
			end
			for index, part in entry.rainbow do
				part.Color = Color3.fromHSV((t * 0.15 + entry.phase + index * 0.07) % 1, 0.55, 1)
			end
			for _, light in entry.pulses do
				light.Brightness = 1.6 + math.sin(t * 3 + entry.phase * 6) * 1.2
			end
			local color = entry.bolts
			if color and t >= entry.nextBolt then
				entry.nextBolt = t + rng:NextNumber(0.35, 1.6)
				local extent = if instance:IsA("Model") then instance:GetExtentsSize().Magnitude * 0.35 else 3
				local from = pivot
					+ Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.5, 1), rng:NextNumber(-1, 1)) * extent
				local to = pivot
					+ Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 0.3), rng:NextNumber(-1, 1)) * extent
				bolt(from, to, color)
			end
		end
	end)
end

return FlashyFx
