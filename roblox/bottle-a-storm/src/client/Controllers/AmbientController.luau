-- Floating extras that make the sky feel alive: little drifting islets,
-- rainbows, flocks of birds and balloons. Everything here is made on this
-- player's screen only, so it costs the server nothing.

local RunService = game:GetService("RunService")

local AmbientController = {}

local PASTELS = {
	Color3.fromRGB(255, 170, 200),
	Color3.fromRGB(160, 230, 190),
	Color3.fromRGB(200, 170, 255),
	Color3.fromRGB(255, 200, 150),
	Color3.fromRGB(255, 235, 140),
	Color3.fromRGB(150, 210, 255),
}
local RAINBOW = {
	Color3.fromRGB(255, 110, 120),
	Color3.fromRGB(255, 175, 90),
	Color3.fromRGB(255, 235, 110),
	Color3.fromRGB(130, 225, 140),
	Color3.fromRGB(120, 180, 255),
	Color3.fromRGB(190, 140, 255),
}

local rng = Random.new(7)
local folder: Folder

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = folder
	return p
end

-- A random spot around the world, away from the player islands' ring.
local function skySpot(minR: number, maxR: number): Vector3
	local angle = rng:NextNumber(0, math.pi * 2)
	local r = rng:NextNumber(minR, maxR)
	local height = if rng:NextNumber() < 0.5 then rng:NextNumber(40, 95) else rng:NextNumber(-75, -35)
	return Vector3.new(math.cos(angle) * r, height, math.sin(angle) * r)
end

type Mover = { parts: { { part: BasePart, offset: CFrame } }, update: (number, number) -> CFrame }
local movers: { Mover } = {}

local function addMover(parts: { { part: BasePart, offset: CFrame } }, update: (number, number) -> CFrame)
	table.insert(movers, { parts = parts, update = update })
end

local function buildIslets()
	for _ = 1, 10 do
		local home = skySpot(170, 520)
		local radius = rng:NextNumber(5, 9)
		local grass = part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(2, radius * 2, radius * 2),
			Color = Color3.fromRGB(140, 215, 130),
			Material = Enum.Material.Grass,
		})
		local rock = part({
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(radius * 1.6, radius * 1.6, radius * 1.6),
			Color = Color3.fromRGB(150, 130, 150),
		})
		local treeTop = part({
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(4, 4, 4),
			Color = PASTELS[rng:NextInteger(1, #PASTELS)],
		})
		local phase = rng:NextNumber(0, 6)
		addMover({
			{ part = grass, offset = CFrame.Angles(0, 0, math.rad(90)) },
			{ part = rock, offset = CFrame.new(0, -radius * 0.55, 0) },
			{ part = treeTop, offset = CFrame.new(radius * 0.3, 3.5, 0) },
		}, function(t)
			return CFrame.new(home + Vector3.new(0, math.sin(t * 0.5 + phase) * 2.5, 0))
				* CFrame.Angles(0, t * 0.05 + phase, 0)
		end)
	end
end

local function buildRainbow(from: Vector3, to: Vector3, height: number)
	local anchor = part({ Size = Vector3.new(1, 1, 1), Transparency = 1, CFrame = CFrame.new(from) })
	local direction = (to - from).Unit
	for band, color in RAINBOW do
		local inset = (band - 1) * 2.4
		local a = Instance.new("Attachment")
		a.Parent = anchor
		a.WorldPosition = from + direction * inset
		a.Axis = Vector3.new(0, 1, 0)
		local b = Instance.new("Attachment")
		b.Parent = anchor
		b.WorldPosition = to - direction * inset
		b.Axis = Vector3.new(0, 1, 0)
		local beam = Instance.new("Beam")
		beam.Attachment0 = a
		beam.Attachment1 = b
		beam.CurveSize0 = height - inset
		beam.CurveSize1 = -(height - inset)
		beam.Width0 = 2.6
		beam.Width1 = 2.6
		beam.Segments = 40
		beam.FaceCamera = true
		beam.LightEmission = 0.5
		beam.Color = ColorSequence.new(color)
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.15, 0.35),
			NumberSequenceKeypoint.new(0.85, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		})
		beam.Parent = anchor
	end
end

local function buildBirds()
	for _ = 1, 9 do
		local center = skySpot(60, 400)
		center = Vector3.new(center.X, rng:NextNumber(60, 110), center.Z)
		local radius = rng:NextNumber(40, 110)
		local speed = rng:NextNumber(0.15, 0.3) * (if rng:NextNumber() < 0.5 then -1 else 1)
		local phase = rng:NextNumber(0, 6)
		local color = if rng:NextNumber() < 0.5 then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(90, 80, 110)
		local left = part({ Size = Vector3.new(2.4, 0.25, 0.8), Color = color })
		local right = part({ Size = Vector3.new(2.4, 0.25, 0.8), Color = color })
		local wing = { flap = 0 }
		local function wingOffset(side: number): CFrame
			return CFrame.Angles(0, 0, side * wing.flap) * CFrame.new(side * 1.1, 0, 0)
		end
		-- The wings are placed inside update, so no parts list is needed.
		addMover({}, function(t)
			wing.flap = 0.25 + math.sin(t * 9 + phase) * 0.35
			local angle = t * speed + phase
			local position = center
				+ Vector3.new(math.cos(angle) * radius, math.sin(t * 0.7 + phase) * 4, math.sin(angle) * radius)
			local ahead = center
				+ Vector3.new(
					math.cos(angle + 0.05 * math.sign(speed)) * radius,
					0,
					math.sin(angle + 0.05 * math.sign(speed)) * radius
				)
			local frame = CFrame.lookAt(position, Vector3.new(ahead.X, position.Y, ahead.Z))
			left.CFrame = frame * wingOffset(-1)
			right.CFrame = frame * wingOffset(1)
			return frame
		end)
	end
end

local function buildBalloons()
	for _ = 1, 10 do
		local balloon = part({
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(4, 4, 4),
			Color = PASTELS[rng:NextInteger(1, #PASTELS)],
			Material = Enum.Material.SmoothPlastic,
			Reflectance = 0.1,
		})
		local string_ = part({ Size = Vector3.new(0.08, 5, 0.08), Color = Color3.fromRGB(245, 245, 245) })
		local start = skySpot(60, 480)
		local speed = rng:NextNumber(2.5, 4.5)
		local offset = rng:NextNumber(0, 200)
		addMover({
			{ part = balloon, offset = CFrame.new() },
			{ part = string_, offset = CFrame.new(0, -4.5, 0) },
		}, function(t)
			-- Rise from below the islands to high above, then start again.
			local y = -80 + ((t * speed + offset) % 240)
			local drift = Vector3.new(math.sin(t * 0.3 + offset) * 6, 0, math.cos(t * 0.25 + offset) * 6)
			return CFrame.new(Vector3.new(start.X, y, start.Z) + drift)
				* CFrame.Angles(0, 0, math.sin(t + offset) * 0.1)
		end)
	end
end

function AmbientController.start()
	folder = Instance.new("Folder")
	folder.Name = "Ambient"
	folder.Parent = workspace

	buildIslets()
	buildRainbow(Vector3.new(-150, -10, -330), Vector3.new(60, -10, -380), 90)
	buildRainbow(Vector3.new(330, -10, 120), Vector3.new(360, -10, -80), 80)
	buildRainbow(Vector3.new(-380, -10, 200), Vector3.new(-220, -10, 380), 85)
	buildBirds()
	buildBalloons()

	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for _, mover in movers do
			local frame = mover.update(t, 0)
			for _, item in mover.parts do
				item.part.CFrame = frame * item.offset
			end
		end
	end)
end

return AmbientController
