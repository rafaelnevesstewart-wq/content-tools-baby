-- Island pets built as little animals: textured bodies (fur, feathers, wool,
-- scales), heads, ears, tails and legs on joints. Joints are Welds with these
-- names so every player's screen can animate them (PetAnimator):
--   "Leg"  swings while walking (its "Phase" attribute offsets the gait)
--   "Neck" bobs, and dips down now and then to graze or peck
--   "Tail" wags         "Wing" flaps
-- build() returns the model; its PrimaryPart "Root" is an invisible anchored
-- part at the body's center, `height` studs above the ground.

local PetModels = {}

export type Kind = {
	speed: number, -- walking speed
	height: number, -- body center above the ground
	hop: boolean?, -- moves in hops (rabbits)
	fly: boolean?, -- flies instead of walking
	build: (Model, BasePart) -> (),
}

local rgb = Color3.fromRGB
local FUR = Enum.Material.Fabric
local SMOOTH = Enum.Material.SmoothPlastic

local function piece(model: Model, props: { [string]: any }): BasePart
	local className = props.ClassName or "Part"
	local p = Instance.new(className) :: BasePart
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		if key ~= "ClassName" then
			(p :: any)[key] = value
		end
	end
	p.Parent = model
	return p
end

-- An ellipsoid body part.
local function oval(model: Model, size: Vector3, color: Color3, cframe: CFrame, material: Enum.Material?): BasePart
	local p = piece(model, { Size = size, Color = color, CFrame = cframe, Material = material or FUR })
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- A pointed ear or horn (a wedge standing up).
local function wedge(model: Model, size: Vector3, color: Color3, cframe: CFrame, material: Enum.Material?): BasePart
	return piece(
		model,
		{ ClassName = "WedgePart", Size = size, Color = color, CFrame = cframe, Material = material or FUR }
	)
end

local function stick(to: BasePart, part: BasePart)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = to
	weld.Part1 = part
	weld.Parent = part
end

-- Joins `part` to `parent` at `at` (world), with `part` hanging from its
-- point `pivot` (part space). The animator turns the Weld's C0.
local function joint(name: string, parent: BasePart, part: BasePart, at: CFrame, pivot: CFrame, phase: number?)
	part.CFrame = at * pivot:Inverse()
	local weld = Instance.new("Weld")
	weld.Name = name
	weld.Part0 = parent
	weld.Part1 = part
	weld.C0 = parent.CFrame:ToObjectSpace(at)
	weld.C1 = pivot
	if phase then
		weld:SetAttribute("Phase", phase)
	end
	weld.Parent = part
end

-- Four legs (or two with `front` false) hanging under the body.
local function legs(
	model: Model,
	body: BasePart,
	spread: number,
	front: number,
	back: number,
	hipY: number,
	length: number,
	width: number,
	color: Color3,
	paw: Color3?,
	two: boolean?
)
	local spots = if two
		then { { -spread, 0, 0 }, { spread, 0, math.pi } }
		else { { -spread, front, 0 }, { spread, front, math.pi }, { -spread, back, math.pi }, { spread, back, 0 } }
	for _, spot in spots do
		local leg = oval(model, Vector3.new(width, length, width), color, body.CFrame)
		leg.Name = "LegPart"
		joint(
			"Leg",
			body,
			leg,
			body.CFrame * CFrame.new(spot[1], hipY, spot[2]),
			CFrame.new(0, length / 2 - width * 0.3, 0),
			spot[3]
		)
		if paw then
			local foot = oval(
				model,
				Vector3.new(width * 1.25, width * 0.6, width * 1.5),
				paw,
				leg.CFrame * CFrame.new(0, -length / 2, -width * 0.25)
			)
			stick(leg, foot)
		end
	end
end

local function eyes(model: Model, head: BasePart, at: CFrame, spread: number, size: number, color: Color3?)
	for _, side in { -1, 1 } do
		local eye = oval(
			model,
			Vector3.one * size,
			color or rgb(20, 14, 10),
			at * CFrame.new(side * spread, 0, 0),
			Enum.Material.Glass
		)
		stick(head, eye)
		local shine = oval(
			model,
			Vector3.one * size * 0.35,
			rgb(255, 255, 255),
			at * CFrame.new(side * spread + size * 0.15, size * 0.18, -size * 0.35),
			Enum.Material.Neon
		)
		stick(head, shine)
	end
end

-- A head on a neck joint, centered at `neckAt`. Returns the head part.
local function head(model: Model, body: BasePart, neckAt: CFrame, size: Vector3, color: Color3): BasePart
	local h = oval(model, size, color, neckAt)
	h.Name = "HeadPart"
	joint("Neck", body, h, neckAt, CFrame.new()) -- turns around its own center
	return h
end

local function tail(body: BasePart, at: CFrame, part: BasePart, pivot: CFrame)
	joint("Tail", body, part, at, pivot)
end

PetModels.Kinds = {
	-- A mallard duck.
	Ducks = {
		speed = 3,
		height = 1.05,
		build = function(model, root)
			local c = root.CFrame
			local body = oval(model, Vector3.new(1.3, 1, 2), rgb(126, 108, 88), c)
			stick(root, body)
			stick(body, oval(model, Vector3.new(1.05, 0.85, 0.9), rgb(112, 60, 44), c * CFrame.new(0, 0.05, -0.75)))
			stick(body, oval(model, Vector3.new(1.1, 0.5, 1.6), rgb(226, 222, 212), c * CFrame.new(0, -0.3, 0.05)))
			for _, side in { -1, 1 } do
				local wing = oval(model, Vector3.new(0.25, 0.65, 1.4), rgb(92, 86, 78), c)
				wing.Name = "WingPart"
				joint("Wing", body, wing, c * CFrame.new(side * 0.6, 0.25, -0.3), CFrame.new(0, 0.25, -0.5))
				stick(
					wing,
					oval(
						model,
						Vector3.new(0.27, 0.2, 0.5),
						rgb(70, 90, 190),
						wing.CFrame * CFrame.new(0, -0.15, 0.3),
						Enum.Material.Glass
					)
				)
			end
			local tailPart = oval(model, Vector3.new(0.5, 0.3, 0.6), rgb(40, 38, 36), c)
			tail(body, c * CFrame.new(0, 0.25, 0.95), tailPart, CFrame.new(0, 0, -0.2))
			local neckAt = c * CFrame.new(0, 0.75, -0.9)
			local h = head(model, body, neckAt, Vector3.new(0.6, 0.62, 0.72), rgb(30, 90, 56))
			h.Material = Enum.Material.Glass
			stick(h, oval(model, Vector3.new(0.62, 0.14, 0.5), rgb(236, 236, 230), neckAt * CFrame.new(0, -0.33, 0.1)))
			stick(
				h,
				oval(
					model,
					Vector3.new(0.3, 0.12, 0.55),
					rgb(222, 180, 58),
					neckAt * CFrame.new(0, -0.08, -0.5),
					SMOOTH
				)
			)
			eyes(model, h, neckAt * CFrame.new(0, 0.1, -0.24), 0.26, 0.1)
			legs(model, body, 0.3, 0, 0, -0.35, 0.55, 0.12, rgb(236, 128, 48), rgb(236, 128, 48), true)
		end,
	},
	-- A wild rabbit.
	Bunnies = {
		speed = 5,
		height = 0.9,
		hop = true,
		build = function(model, root)
			local c = root.CFrame
			local brown = rgb(140, 112, 84)
			local body = oval(model, Vector3.new(1.1, 1.05, 1.55), brown, c)
			stick(root, body)
			stick(body, oval(model, Vector3.new(0.8, 0.7, 1), rgb(200, 184, 164), c * CFrame.new(0, -0.25, -0.2)))
			local tailPart = oval(model, Vector3.one * 0.42, rgb(242, 240, 234), c, Enum.Material.Salt)
			tail(body, c * CFrame.new(0, 0.1, 0.78), tailPart, CFrame.new(0, 0, -0.1))
			local neckAt = c * CFrame.new(0, 0.55, -0.75)
			local h = head(model, body, neckAt, Vector3.new(0.78, 0.72, 0.85), brown)
			stick(h, oval(model, Vector3.new(0.42, 0.3, 0.3), rgb(214, 198, 180), neckAt * CFrame.new(0, -0.15, -0.36)))
			stick(h, oval(model, Vector3.one * 0.1, rgb(190, 120, 120), neckAt * CFrame.new(0, -0.05, -0.46), SMOOTH))
			eyes(model, h, neckAt * CFrame.new(0, 0.1, -0.28), 0.3, 0.14)
			for _, side in { -1, 1 } do
				local ear = oval(
					model,
					Vector3.new(0.24, 1, 0.12),
					brown,
					neckAt * CFrame.new(side * 0.18, 0.7, 0.1) * CFrame.Angles(0.2, 0, side * 0.15)
				)
				stick(h, ear)
				stick(
					h,
					oval(model, Vector3.new(0.14, 0.8, 0.05), rgb(214, 160, 160), ear.CFrame * CFrame.new(0, 0, -0.05))
				)
				stick(body, oval(model, Vector3.new(0.4, 0.55, 0.85), brown, c * CFrame.new(side * 0.42, -0.3, 0.4)))
			end
			legs(model, body, 0.25, -0.55, 0.45, -0.3, 0.45, 0.2, brown, rgb(210, 196, 180))
		end,
	},
	-- A sheep with thick wool.
	CloudSheep = {
		speed = 2.2,
		height = 1.8,
		build = function(model, root)
			local c = root.CFrame
			local wool = Enum.Material.Salt
			local woolColor = rgb(232, 226, 212)
			local body = oval(model, Vector3.new(1.8, 1.45, 2.4), woolColor, c, wool)
			stick(root, body)
			for _, offset in
				{
					Vector3.new(0.45, 0.55, 0.6),
					Vector3.new(-0.45, 0.55, -0.4),
					Vector3.new(0, 0.62, 0),
					Vector3.new(0, 0.1, 1),
				}
			do
				stick(body, oval(model, Vector3.new(1.1, 0.8, 1.2), woolColor, c + offset, wool))
			end
			local tailPart = oval(model, Vector3.new(0.35, 0.5, 0.35), woolColor, c, wool)
			tail(body, c * CFrame.new(0, 0.2, 1.2), tailPart, CFrame.new(0, 0.2, 0))
			local face = rgb(50, 42, 38)
			local neckAt = c * CFrame.new(0, 0.4, -1.35)
			local h = head(model, body, neckAt, Vector3.new(0.68, 0.78, 0.95), face)
			stick(h, oval(model, Vector3.new(0.8, 0.42, 0.6), woolColor, neckAt * CFrame.new(0, 0.38, 0.15), wool))
			eyes(model, h, neckAt * CFrame.new(0, 0.12, -0.3), 0.27, 0.12, rgb(60, 45, 20))
			for _, side in { -1, 1 } do
				stick(
					h,
					oval(
						model,
						Vector3.new(0.5, 0.16, 0.26),
						face,
						neckAt * CFrame.new(side * 0.44, 0.14, 0.1) * CFrame.Angles(0, 0, side * -0.3)
					)
				)
			end
			legs(model, body, 0.5, -0.8, 0.8, -0.55, 1.15, 0.26, face, rgb(40, 34, 30))
		end,
	},
	-- An orange tabby cat.
	Cat = {
		speed = 3.5,
		height = 1.2,
		build = function(model, root)
			local c = root.CFrame
			local orange = rgb(214, 130, 58)
			local stripe = rgb(160, 84, 34)
			local body = oval(model, Vector3.new(0.85, 0.85, 1.8), orange, c)
			stick(root, body)
			for i = -1, 1 do
				stick(body, oval(model, Vector3.new(0.88, 0.2, 0.25), stripe, c * CFrame.new(0, 0.3, i * 0.45)))
			end
			stick(body, oval(model, Vector3.new(0.6, 0.5, 1.2), rgb(236, 214, 186), c * CFrame.new(0, -0.22, -0.1)))
			local tailPart = oval(model, Vector3.new(0.18, 0.18, 1.5), orange, c)
			tail(
				body,
				c * CFrame.new(0, 0.25, 0.85) * CFrame.Angles(math.rad(35), 0, 0),
				tailPart,
				CFrame.new(0, 0, -0.7)
			)
			local neckAt = c * CFrame.new(0, 0.5, -0.95)
			local h = head(model, body, neckAt, Vector3.new(0.8, 0.72, 0.72), orange)
			stick(
				h,
				oval(model, Vector3.new(0.42, 0.28, 0.25), rgb(240, 222, 200), neckAt * CFrame.new(0, -0.15, -0.3))
			)
			stick(h, oval(model, Vector3.one * 0.09, rgb(220, 120, 130), neckAt * CFrame.new(0, -0.05, -0.38), SMOOTH))
			eyes(model, h, neckAt * CFrame.new(0, 0.08, -0.28), 0.2, 0.15, rgb(120, 180, 60))
			for _, side in { -1, 1 } do
				stick(
					h,
					wedge(
						model,
						Vector3.new(0.08, 0.35, 0.3),
						orange,
						neckAt * CFrame.new(side * 0.24, 0.42, 0) * CFrame.Angles(0, 0, side * -0.25)
					)
				)
			end
			legs(model, body, 0.24, -0.6, 0.6, -0.3, 0.85, 0.2, orange, rgb(240, 222, 200))
		end,
	},
	-- A corgi with short legs and big ears.
	Corgi = {
		speed = 4,
		height = 0.95,
		build = function(model, root)
			local c = root.CFrame
			local ginger = rgb(206, 132, 62)
			local white = rgb(244, 240, 232)
			local body = oval(model, Vector3.new(1.05, 0.9, 2), ginger, c)
			stick(root, body)
			stick(body, oval(model, Vector3.new(0.8, 0.5, 1.4), white, c * CFrame.new(0, -0.25, -0.2)))
			local tailPart = oval(model, Vector3.new(0.25, 0.25, 0.35), ginger, c)
			tail(body, c * CFrame.new(0, 0.3, 1), tailPart, CFrame.new(0, 0, -0.1))
			local neckAt = c * CFrame.new(0, 0.55, -1.05)
			local h = head(model, body, neckAt, Vector3.new(0.82, 0.75, 0.8), ginger)
			stick(h, oval(model, Vector3.new(0.4, 0.35, 0.5), white, neckAt * CFrame.new(0, -0.15, -0.38)))
			stick(
				h,
				oval(
					model,
					Vector3.new(0.16, 0.12, 0.12),
					rgb(25, 20, 18),
					neckAt * CFrame.new(0, -0.05, -0.62),
					SMOOTH
				)
			)
			eyes(model, h, neckAt * CFrame.new(0, 0.1, -0.3), 0.2, 0.12)
			for _, side in { -1, 1 } do
				stick(
					h,
					wedge(
						model,
						Vector3.new(0.08, 0.5, 0.38),
						ginger,
						neckAt * CFrame.new(side * 0.28, 0.5, 0.05) * CFrame.Angles(0, 0, side * -0.2)
					)
				)
			end
			legs(model, body, 0.3, -0.65, 0.65, -0.3, 0.5, 0.24, ginger, white)
		end,
	},
	-- A red fox with a bushy white-tipped tail.
	Fox = {
		speed = 4.5,
		height = 1.3,
		build = function(model, root)
			local c = root.CFrame
			local orange = rgb(210, 104, 40)
			local white = rgb(240, 234, 224)
			local black = rgb(35, 28, 26)
			local body = oval(model, Vector3.new(0.85, 0.85, 1.9), orange, c)
			stick(root, body)
			stick(body, oval(model, Vector3.new(0.55, 0.6, 0.8), white, c * CFrame.new(0, -0.1, -0.7)))
			local tailPart = oval(model, Vector3.new(0.5, 0.5, 1.5), orange, c)
			tail(
				body,
				c * CFrame.new(0, 0.1, 0.9) * CFrame.Angles(math.rad(-15), 0, 0),
				tailPart,
				CFrame.new(0, 0, -0.7)
			)
			stick(tailPart, oval(model, Vector3.new(0.4, 0.4, 0.45), white, tailPart.CFrame * CFrame.new(0, 0, 0.62)))
			local neckAt = c * CFrame.new(0, 0.5, -1.05)
			local h = head(model, body, neckAt, Vector3.new(0.75, 0.65, 0.75), orange)
			stick(h, oval(model, Vector3.new(0.34, 0.28, 0.62), white, neckAt * CFrame.new(0, -0.14, -0.42)))
			stick(h, oval(model, Vector3.one * 0.12, black, neckAt * CFrame.new(0, -0.06, -0.72), SMOOTH))
			eyes(model, h, neckAt * CFrame.new(0, 0.1, -0.26), 0.2, 0.12, rgb(200, 150, 40))
			for _, side in { -1, 1 } do
				local ear = wedge(
					model,
					Vector3.new(0.08, 0.45, 0.32),
					orange,
					neckAt * CFrame.new(side * 0.22, 0.45, 0.05) * CFrame.Angles(0, 0, side * -0.2)
				)
				stick(h, ear)
				stick(h, wedge(model, Vector3.new(0.09, 0.15, 0.2), black, ear.CFrame * CFrame.new(0, 0.16, 0.02)))
			end
			legs(model, body, 0.24, -0.62, 0.62, -0.3, 0.9, 0.18, black, black)
		end,
	},
	-- A spotted deer with antlers.
	Deer = {
		speed = 3,
		height = 2.3,
		build = function(model, root)
			local c = root.CFrame
			local brown = rgb(150, 104, 66)
			local body = oval(model, Vector3.new(1.15, 1.2, 2.4), brown, c)
			stick(root, body)
			stick(body, oval(model, Vector3.new(0.8, 0.5, 1.8), rgb(222, 206, 184), c * CFrame.new(0, -0.35, 0)))
			for i = 1, 6 do
				stick(
					body,
					oval(
						model,
						Vector3.one * 0.14,
						rgb(245, 240, 230),
						c * CFrame.new((i % 2 - 0.5) * 0.4, 0.55, -0.8 + i * 0.3)
					)
				)
			end
			local tailPart = oval(model, Vector3.new(0.25, 0.4, 0.2), rgb(240, 236, 228), c)
			tail(body, c * CFrame.new(0, 0.35, 1.2), tailPart, CFrame.new(0, 0.15, 0))
			local neck = oval(
				model,
				Vector3.new(0.5, 1.2, 0.55),
				brown,
				c * CFrame.new(0, 0.9, -1.1) * CFrame.Angles(math.rad(-25), 0, 0)
			)
			stick(body, neck)
			local neckAt = c * CFrame.new(0, 1.55, -1.45)
			local h = head(model, body, neckAt, Vector3.new(0.6, 0.6, 0.95), brown)
			stick(h, oval(model, Vector3.one * 0.14, rgb(25, 20, 18), neckAt * CFrame.new(0, -0.08, -0.5), SMOOTH))
			eyes(model, h, neckAt * CFrame.new(0, 0.1, -0.2), 0.22, 0.14)
			local antler = rgb(200, 180, 150)
			for _, side in { -1, 1 } do
				stick(
					h,
					oval(
						model,
						Vector3.new(0.14, 0.45, 0.28),
						brown,
						neckAt * CFrame.new(side * 0.35, 0.25, 0.1) * CFrame.Angles(0, 0, side * -0.6)
					)
				)
				local beam = piece(model, {
					Size = Vector3.new(0.1, 0.9, 0.1),
					Color = antler,
					Material = Enum.Material.Wood,
					CFrame = neckAt * CFrame.new(side * 0.18, 0.7, 0.05) * CFrame.Angles(0, 0, side * -0.35),
				})
				stick(h, beam)
				for i = 1, 2 do
					stick(
						h,
						piece(model, {
							Size = Vector3.new(0.08, 0.4, 0.08),
							Color = antler,
							Material = Enum.Material.Wood,
							CFrame = beam.CFrame
								* CFrame.new(side * 0.05, -0.2 + i * 0.3, -0.1)
								* CFrame.Angles(-0.7, 0, side * 0.3),
						})
					)
				end
			end
			legs(model, body, 0.35, -0.85, 0.85, -0.45, 1.75, 0.2, brown, rgb(40, 32, 28))
		end,
	},
	-- A baby storm dragon that flies.
	StormDragon = {
		speed = 7,
		height = 10,
		fly = true,
		build = function(model, root)
			local c = root.CFrame
			local scales = Enum.Material.Slate
			local purple = rgb(92, 64, 150)
			local body = oval(model, Vector3.new(1.5, 1.4, 2.6), purple, c, scales)
			stick(root, body)
			stick(body, oval(model, Vector3.new(1.1, 0.9, 2), rgb(170, 140, 110), c * CFrame.new(0, -0.35, 0), scales))
			local neckAt = c * CFrame.new(0, 1.1, -1.7)
			local h = head(model, body, neckAt, Vector3.new(0.95, 0.85, 1.35), purple)
			h.Material = scales
			stick(h, oval(model, Vector3.new(0.6, 0.4, 0.7), purple, neckAt * CFrame.new(0, -0.15, -0.65), scales))
			eyes(model, h, neckAt * CFrame.new(0, 0.15, -0.4), 0.32, 0.16, rgb(255, 200, 60))
			for _, side in { -1, 1 } do
				stick(
					h,
					wedge(
						model,
						Vector3.new(0.12, 0.6, 0.3),
						rgb(222, 206, 170),
						neckAt * CFrame.new(side * 0.25, 0.6, 0.3) * CFrame.Angles(-0.4, 0, side * 0.2),
						Enum.Material.Marble
					)
				)
				local wing = piece(model, {
					Size = Vector3.new(3, 0.08, 1.8),
					Color = rgb(150, 110, 190),
					Material = FUR,
					Transparency = 0.08,
				})
				wing.Name = "WingPart"
				joint("Wing", body, wing, c * CFrame.new(side * 0.7, 0.5, -0.2), CFrame.new(-side * 1.5, 0, 0))
			end
			local tailPart = oval(model, Vector3.new(0.45, 0.45, 2.2), purple, c, scales)
			tail(body, c * CFrame.new(0, 0, 1.2), tailPart, CFrame.new(0, 0, -1))
			legs(model, body, 0.5, -0.6, 0.6, -0.6, 0.8, 0.3, purple, purple)
		end,
	},
} :: { [string]: Kind }

function PetModels.build(kindName: string, at: CFrame): (Model?, Kind?)
	local kind = PetModels.Kinds[kindName]
	if not kind then
		return nil, nil
	end
	local model = Instance.new("Model")
	model.Name = "IslandPet"
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.one * 0.5
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.CFrame = at
	root.Parent = model
	model.PrimaryPart = root
	kind.build(model, root)
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") and item ~= root then
			item.CastShadow = true
		end
	end
	model:SetAttribute("Flies", kind.fly == true)
	return model, kind
end

return PetModels
