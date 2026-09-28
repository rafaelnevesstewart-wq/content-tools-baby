-- 🐎 Mounts to ride in the lobby (a cosmetic, CosmeticsData category
-- "mount"): horses with legs that gallop, flying clouds and the tamed Storm
-- Dragon (wings are Welds named "Wing" with a "Side" that the client flaps). build() returns a
-- Model whose invisible PrimaryPart "Root" sits at the middle of the body;
-- every other part is welded to it. Legs are Welds named "Leg" (with a
-- "Phase") that the client swings (MountController). Attributes:
--   BodyHeight  how high the body's middle is above the ground
--   Raise       how much higher the rider sits than when walking
--   Flies       true for clouds

local MountModels = {}

local rgb = Color3.fromRGB

export type Kind = {
	bodyHeight: number,
	raise: number,
	flies: boolean?,
	build: (Model, BasePart) -> (),
}

local function piece(model: Model, props: { [string]: any }): BasePart
	local p = Instance.new(props.ClassName or "Part") :: BasePart
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		if key ~= "ClassName" and key ~= "Round" then
			(p :: any)[key] = value
		end
	end
	if props.Round then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	p.Parent = model
	return p
end

local function stick(to: BasePart, part: BasePart)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = to
	weld.Part1 = part
	weld.Parent = part
end

-- A horse: body, neck, head with ears and a mane, a tail, a saddle and four
-- legs with hooves. `horn` makes it a unicorn.
local function horse(coat: Color3, mane: Color3, horn: Color3?, glow: Color3?): (Model, BasePart) -> ()
	return function(model, root)
		local c = root.CFrame
		local body = piece(
			model,
			{ Size = Vector3.new(2.4, 2.4, 5), Color = coat, Material = Enum.Material.Fabric, CFrame = c, Round = true }
		)
		stick(root, body)
		local neck = piece(model, {
			Size = Vector3.new(1.3, 2.8, 1.4),
			Color = coat,
			Material = Enum.Material.Fabric,
			CFrame = c * CFrame.new(0, 1.3, -2.3) * CFrame.Angles(math.rad(-35), 0, 0),
			Round = true,
		})
		stick(body, neck)
		local head = piece(model, {
			Size = Vector3.new(1.1, 1.1, 2.2),
			Color = coat,
			Material = Enum.Material.Fabric,
			CFrame = c * CFrame.new(0, 2.5, -3.1) * CFrame.Angles(math.rad(25), 0, 0),
			Round = true,
		})
		stick(body, head)
		for _, side in { -1, 1 } do
			stick(
				head,
				piece(model, {
					ClassName = "WedgePart",
					Size = Vector3.new(0.2, 0.6, 0.35),
					Color = coat,
					Material = Enum.Material.Fabric,
					CFrame = c * CFrame.new(side * 0.35, 3.2, -2.7),
				})
			)
			stick(
				head,
				piece(model, {
					Size = Vector3.new(0.18, 0.18, 0.18),
					Color = rgb(20, 20, 24),
					Material = Enum.Material.SmoothPlastic,
					CFrame = c * CFrame.new(side * 0.5, 2.75, -3.4),
					Round = true,
				})
			)
		end
		-- The mane down the neck and the tail.
		for i = 0, 3 do
			stick(
				neck,
				piece(model, {
					Size = Vector3.new(0.35, 0.8, 0.7),
					Color = mane,
					Material = Enum.Material.Fabric,
					CFrame = c * CFrame.new(0, 1.3 + i * 0.45, -1.6 - i * 0.4) * CFrame.Angles(math.rad(-35), 0, 0),
				})
			)
		end
		stick(
			body,
			piece(model, {
				Size = Vector3.new(0.5, 2.2, 0.6),
				Color = mane,
				Material = Enum.Material.Fabric,
				CFrame = c * CFrame.new(0, -0.1, 2.7) * CFrame.Angles(math.rad(25), 0, 0),
				Round = true,
			})
		)
		-- The saddle.
		stick(
			body,
			piece(model, {
				Size = Vector3.new(2.5, 0.3, 1.8),
				Color = rgb(110, 60, 30),
				Material = Enum.Material.Leather,
				CFrame = c * CFrame.new(0, 1.15, 0.1),
			})
		)
		if horn then
			stick(
				head,
				piece(model, {
					Size = Vector3.new(0.25, 1.4, 0.25),
					Color = horn,
					Material = Enum.Material.Neon,
					CFrame = c * CFrame.new(0, 3.3, -3.4) * CFrame.Angles(math.rad(-30), 0, 0),
				})
			)
		end
		if glow then
			local sparkles = Instance.new("Sparkles")
			sparkles.SparkleColor = glow
			sparkles.Parent = body
		end
		-- Legs on joints (the client swings them).
		for index, spot in { { -0.7, -1.7 }, { 0.7, -1.7 }, { -0.7, 1.7 }, { 0.7, 1.7 } } do
			local leg = piece(
				model,
				{ Size = Vector3.new(0.5, 2.6, 0.5), Color = coat, Material = Enum.Material.Fabric, CFrame = c }
			)
			local hip = c * CFrame.new(spot[1], -0.6, spot[2])
			leg.CFrame = hip * CFrame.new(0, -1.3, 0)
			local weld = Instance.new("Weld")
			weld.Name = "Leg"
			weld.Part0 = body
			weld.Part1 = leg
			weld.C0 = body.CFrame:ToObjectSpace(hip)
			weld.C1 = CFrame.new(0, 1.3, 0)
			weld:SetAttribute("Phase", if index == 1 or index == 4 then 0 else math.pi)
			weld.Parent = leg
			stick(
				leg,
				piece(model, {
					Size = Vector3.new(0.55, 0.3, 0.6),
					Color = rgb(40, 32, 28),
					Material = Enum.Material.SmoothPlastic,
					CFrame = leg.CFrame * CFrame.new(0, -1.3, -0.05),
				})
			)
		end
	end
end

-- A fluffy cloud to sit on (a storm cloud is dark and crackles).
local function cloud(color: Color3, storm: boolean): (Model, BasePart) -> ()
	return function(model, root)
		local c = root.CFrame
		local core = piece(model, {
			Size = Vector3.new(4.5, 1.6, 4.5),
			Color = color,
			Material = Enum.Material.SmoothPlastic,
			CFrame = c,
			Round = true,
		})
		stick(root, core)
		for i = 0, 6 do
			local angle = i / 7 * math.pi * 2
			local size = 1.6 + (i % 3) * 0.35
			stick(
				core,
				piece(model, {
					Size = Vector3.one * size,
					Color = color:Lerp(Color3.new(1, 1, 1), if storm then 0 else 0.1),
					Material = Enum.Material.SmoothPlastic,
					CFrame = c * CFrame.new(math.cos(angle) * 1.9, 0.2 + (i % 2) * 0.3, math.sin(angle) * 1.9),
					Round = true,
				})
			)
		end
		local puffs = Instance.new("ParticleEmitter")
		puffs.Texture = "rbxasset://textures/particles/smoke_main.dds"
		puffs.Color = ColorSequence.new(color)
		puffs.Size = NumberSequence.new(1, 2.5)
		puffs.Transparency = NumberSequence.new(0.5, 1)
		puffs.Lifetime = NumberRange.new(0.8, 1.2)
		puffs.Rate = 12
		puffs.Speed = NumberRange.new(0.5, 1.5)
		puffs.Parent = core
		if storm then
			core:SetAttribute("Bolts", rgb(190, 225, 255))
			game:GetService("CollectionService"):AddTag(core, "FlashyFx")
			local light = Instance.new("PointLight")
			light.Color = rgb(170, 200, 255)
			light.Range = 10
			light.Parent = core
		end
	end
end

-- 🐉 The tamed Storm Dragon: a scaly body, a long neck and horned head, a
-- spiked tail, four clawed legs and two big wings that flap.
local function dragon(scales: Color3, belly: Color3, glow: Color3): (Model, BasePart) -> ()
	return function(model, root)
		local c = root.CFrame
		local body = piece(model, {
			Size = Vector3.new(2.8, 2.6, 5.6),
			Color = scales,
			Material = Enum.Material.Slate,
			CFrame = c,
			Round = true,
		})
		stick(root, body)
		stick(
			body,
			piece(model, {
				Size = Vector3.new(2.2, 1.4, 4.4),
				Color = belly,
				Material = Enum.Material.Sand,
				CFrame = c * CFrame.new(0, -0.7, 0),
				Round = true,
			})
		)
		local neck = piece(model, {
			Size = Vector3.new(1.3, 3.4, 1.4),
			Color = scales,
			Material = Enum.Material.Slate,
			CFrame = c * CFrame.new(0, 1.5, -2.8) * CFrame.Angles(math.rad(-40), 0, 0),
			Round = true,
		})
		stick(body, neck)
		local head = piece(model, {
			Size = Vector3.new(1.5, 1.2, 2.6),
			Color = scales,
			Material = Enum.Material.Slate,
			CFrame = c * CFrame.new(0, 3, -4),
			Round = true,
		})
		stick(body, head)
		for _, side in { -1, 1 } do
			-- Glowing eyes and swept-back horns.
			stick(
				head,
				piece(model, {
					Size = Vector3.one * 0.25,
					Color = glow,
					Material = Enum.Material.Neon,
					CFrame = c * CFrame.new(side * 0.55, 3.25, -4.6),
					Round = true,
				})
			)
			stick(
				head,
				piece(model, {
					ClassName = "WedgePart",
					Size = Vector3.new(0.25, 0.5, 1.4),
					Color = belly,
					Material = Enum.Material.Marble,
					CFrame = c * CFrame.new(side * 0.45, 3.75, -3.4) * CFrame.Angles(math.rad(20), math.pi, 0),
				})
			)
		end
		-- Spikes down the back and the tail.
		for i = 0, 4 do
			stick(
				body,
				piece(model, {
					ClassName = "WedgePart",
					Size = Vector3.new(0.2, 0.6, 0.6),
					Color = glow,
					Material = Enum.Material.Neon,
					CFrame = c * CFrame.new(0, 1.35 + (if i == 0 then 0.2 else 0), -1.6 + i * 0.9),
				})
			)
		end
		for i = 1, 4 do
			stick(
				body,
				piece(model, {
					Size = Vector3.new(1.2 - i * 0.22, 1.1 - i * 0.2, 1.6),
					Color = scales,
					Material = Enum.Material.Slate,
					CFrame = c * CFrame.new(0, -0.2 - i * 0.15, 2.4 + i * 1.3),
					Round = true,
				})
			)
		end
		-- The saddle.
		stick(
			body,
			piece(model, {
				Size = Vector3.new(2.6, 0.3, 1.8),
				Color = rgb(90, 40, 30),
				Material = Enum.Material.Leather,
				CFrame = c * CFrame.new(0, 1.3, 0.3),
			})
		)
		local light = Instance.new("PointLight")
		light.Color = glow
		light.Range = 12
		light.Parent = head
		-- Wings on joints (the client flaps them).
		for _, side in { -1, 1 } do
			local shoulder = c * CFrame.new(side * 1.1, 1, -0.6)
			local wing = piece(model, {
				Size = Vector3.new(6, 0.2, 3.6),
				Color = scales:Lerp(glow, 0.25),
				Material = Enum.Material.Fabric,
				CFrame = shoulder * CFrame.new(side * 3, 0, 0.6),
			})
			stick(
				wing,
				piece(model, {
					Size = Vector3.new(6.2, 0.3, 0.3),
					Color = scales,
					Material = Enum.Material.Slate,
					CFrame = shoulder * CFrame.new(side * 3, 0.1, -1.1),
				})
			)
			local weld = Instance.new("Weld")
			weld.Name = "Wing"
			weld.Part0 = body
			weld.Part1 = wing
			weld.C0 = body.CFrame:ToObjectSpace(shoulder)
			weld.C1 = CFrame.new(-side * 3, 0, -0.6)
			weld:SetAttribute("Side", side)
			weld.Parent = wing
		end
		-- Four short legs with claws.
		for index, spot in { { -0.9, -1.6 }, { 0.9, -1.6 }, { -0.9, 1.6 }, { 0.9, 1.6 } } do
			local leg = piece(model, {
				Size = Vector3.new(0.7, 2, 0.7),
				Color = scales,
				Material = Enum.Material.Slate,
				CFrame = c,
			})
			local hip = c * CFrame.new(spot[1], -0.9, spot[2])
			leg.CFrame = hip * CFrame.new(0, -1, 0)
			local weld = Instance.new("Weld")
			weld.Name = "Leg"
			weld.Part0 = body
			weld.Part1 = leg
			weld.C0 = body.CFrame:ToObjectSpace(hip)
			weld.C1 = CFrame.new(0, 1, 0)
			weld:SetAttribute("Phase", if index == 1 or index == 4 then 0 else math.pi)
			weld.Parent = leg
			stick(
				leg,
				piece(model, {
					Size = Vector3.new(0.8, 0.3, 0.9),
					Color = belly,
					Material = Enum.Material.Marble,
					CFrame = leg.CFrame * CFrame.new(0, -1, -0.15),
				})
			)
		end
	end
end

MountModels.Kinds = {
	Pony = { bodyHeight = 3.2, raise = 2.4, build = horse(rgb(140, 92, 56), rgb(60, 40, 28)) },
	NightMare = {
		bodyHeight = 3.2,
		raise = 2.4,
		build = horse(rgb(34, 30, 36), rgb(120, 40, 200), nil, rgb(170, 90, 255)),
	},
	Unicorn = {
		bodyHeight = 3.2,
		raise = 2.4,
		build = horse(rgb(245, 244, 250), rgb(255, 150, 220), rgb(255, 220, 120), rgb(255, 200, 250)),
	},
	Cloud = { bodyHeight = 1.4, raise = 1.6, flies = true, build = cloud(rgb(248, 250, 255), false) },
	StormCloud = { bodyHeight = 1.4, raise = 1.6, flies = true, build = cloud(rgb(70, 76, 96), true) },
	Dragon = {
		bodyHeight = 3.2,
		raise = 2.8,
		flies = true,
		build = dragon(rgb(46, 58, 92), rgb(200, 190, 150), rgb(120, 220, 255)),
	},
} :: { [string]: Kind }

function MountModels.build(kindName: string): (Model?, Kind?)
	local kind = MountModels.Kinds[kindName]
	if not kind then
		return nil, nil
	end
	local model = Instance.new("Model")
	model.Name = "Mount"
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.one * 0.5
	root.Transparency = 1
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Massless = true
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root
	kind.build(model, root)
	model:SetAttribute("BodyHeight", kind.bodyHeight)
	model:SetAttribute("Raise", kind.raise)
	model:SetAttribute("Flies", kind.flies == true)
	return model, kind
end

return MountModels
