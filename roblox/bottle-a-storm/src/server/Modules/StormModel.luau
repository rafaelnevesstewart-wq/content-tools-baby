-- Builds the storm creatures (living little weather clouds) out of plain
-- parts and particles, so the game runs with no uploaded art. Swap in real
-- meshes later by changing build() only.

local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local StormData = require(Shared.StormData)

local StormModel = {}

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

type FxStyle = {
	texture: string,
	color: ColorSequence,
	size: number,
	speed: number,
	rate: number,
	lifetime: number,
	spread: number,
	down: boolean,
	transparency: number,
	lightEmission: number,
	light: Color3?,
}

local rainbow = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 80)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(100, 230, 120)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(90, 160, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 100, 255)),
})

local FX: { [string]: FxStyle } = {
	fire = {
		texture = FIRE,
		color = ColorSequence.new(Color3.fromRGB(255, 170, 60), Color3.fromRGB(255, 60, 30)),
		size = 1.2,
		speed = 4,
		rate = 18,
		lifetime = 0.8,
		spread = 25,
		down = false,
		transparency = 0.2,
		lightEmission = 0.9,
		light = Color3.fromRGB(255, 140, 60),
	},
	stars = {
		texture = SPARKLE,
		color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 180, 255)),
		size = 0.45,
		speed = 1.5,
		rate = 14,
		lifetime = 2,
		spread = 180,
		down = false,
		transparency = 0,
		lightEmission = 1,
		light = Color3.fromRGB(170, 170, 255),
	},
	rain = {
		texture = SPARKLE,
		color = ColorSequence.new(Color3.fromRGB(120, 180, 255)),
		size = 0.2,
		speed = 10,
		rate = 25,
		lifetime = 0.6,
		spread = 8,
		down = true,
		transparency = 0.1,
		lightEmission = 0.3,
	},
	snow = {
		texture = SPARKLE,
		color = ColorSequence.new(Color3.fromRGB(255, 255, 255)),
		size = 0.35,
		speed = 2.5,
		rate = 14,
		lifetime = 1.6,
		spread = 35,
		down = true,
		transparency = 0,
		lightEmission = 0.5,
	},
	hail = {
		texture = SPARKLE,
		color = ColorSequence.new(Color3.fromRGB(220, 240, 255)),
		size = 0.4,
		speed = 12,
		rate = 8,
		lifetime = 0.5,
		spread = 10,
		down = true,
		transparency = 0,
		lightEmission = 0.2,
	},
	fog = {
		texture = SMOKE,
		color = ColorSequence.new(Color3.fromRGB(235, 235, 245)),
		size = 2.5,
		speed = 0.8,
		rate = 3,
		lifetime = 2.5,
		spread = 180,
		down = false,
		transparency = 0.7,
		lightEmission = 0,
	},
	wind = {
		texture = SMOKE,
		color = ColorSequence.new(Color3.fromRGB(220, 245, 235)),
		size = 1.4,
		speed = 5,
		rate = 6,
		lifetime = 1.2,
		spread = 180,
		down = false,
		transparency = 0.6,
		lightEmission = 0,
	},
	lightning = {
		texture = SPARKLE,
		color = ColorSequence.new(Color3.fromRGB(255, 240, 90)),
		size = 0.6,
		speed = 7,
		rate = 10,
		lifetime = 0.35,
		spread = 180,
		down = false,
		transparency = 0,
		lightEmission = 1,
		light = Color3.fromRGB(255, 235, 120),
	},
	dust = {
		texture = SMOKE,
		color = ColorSequence.new(Color3.fromRGB(215, 180, 125)),
		size = 1.6,
		speed = 3,
		rate = 8,
		lifetime = 1.4,
		spread = 70,
		down = false,
		transparency = 0.5,
		lightEmission = 0,
	},
	rainbow = {
		texture = SPARKLE,
		color = rainbow,
		size = 0.5,
		speed = 3,
		rate = 16,
		lifetime = 1.2,
		spread = 180,
		down = false,
		transparency = 0,
		lightEmission = 0.8,
		light = Color3.fromRGB(255, 180, 230),
	},
	hurricane = {
		texture = SMOKE,
		color = ColorSequence.new(Color3.fromRGB(150, 230, 230)),
		size = 2,
		speed = 8,
		rate = 14,
		lifetime = 1,
		spread = 180,
		down = false,
		transparency = 0.5,
		lightEmission = 0.1,
	},
}

local function ball(parent: Instance, size: number, color: Color3, cframe: CFrame, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(size, size, size)
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.CFrame = cframe
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function weld(root: BasePart, part: BasePart)
	local constraint = Instance.new("WeldConstraint")
	constraint.Part0 = root
	constraint.Part1 = part
	constraint.Parent = part
end

local function addParticles(root: BasePart, fxName: string, scale: number)
	local style = FX[fxName]
	if not style then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "FxAttachment"
	attachment.Position = Vector3.new(0, if style.down then -1.6 * scale else 0, 0)
	attachment.Parent = root

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = style.texture
	emitter.Color = style.color
	emitter.Size = NumberSequence.new(style.size * scale)
	emitter.Speed = NumberRange.new(style.speed * 0.8, style.speed * 1.2)
	emitter.Rate = style.rate
	emitter.Lifetime = NumberRange.new(style.lifetime * 0.8, style.lifetime * 1.2)
	emitter.SpreadAngle = Vector2.new(style.spread, style.spread)
	emitter.EmissionDirection = if style.down then Enum.NormalId.Bottom else Enum.NormalId.Top
	emitter.Transparency = NumberSequence.new(style.transparency, 1)
	emitter.LightEmission = style.lightEmission
	emitter.RotSpeed = NumberRange.new(-90, 90)
	emitter.Parent = attachment

	if style.light then
		local light = Instance.new("PointLight")
		light.Color = style.light
		light.Range = 10 * scale
		light.Brightness = 1.5
		light.Parent = root
	end
end

export type BuildOptions = {
	mutation: string?,
	scale: number?, -- multiplies the rarity's size
	anchored: boolean?, -- false when the model gets welded to a character
	angry: boolean?, -- frowning eyebrows, for Mega-Storm bosses
}

-- Returns a Model whose PrimaryPart "Root" is the pivot. The creature faces -Z.
function StormModel.build(def: StormData.StormDef, options: BuildOptions?): Model
	local opts: BuildOptions = options or {}
	local rarity = StormData.rarityOf(def)
	local scale = rarity.scale * (opts.scale or 1)
	local mutation = StormData.getMutation(opts.mutation)

	local model = Instance.new("Model")
	model.Name = def.id

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Shape = Enum.PartType.Ball
	root.Size = Vector3.new(1, 1, 1) * scale
	root.Transparency = 1
	root.Anchored = opts.anchored ~= false
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.Massless = true
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root

	-- Everything visible hangs off "Body", which is joined to Root by a Weld.
	-- Each player's client animates that Weld (bobbing, swaying): see
	-- StormAnimator. The server never touches it after this.
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(1, 1, 1) * scale
	body.Transparency = 1
	body.Anchored = false
	body.CanCollide = false
	body.CanTouch = false
	body.CanQuery = false
	body.Massless = true
	body.CFrame = CFrame.new()
	body.Parent = model
	local bodyWeld = Instance.new("Weld")
	bodyWeld.Name = "BodyWeld"
	bodyWeld.Part0 = root
	bodyWeld.Part1 = body
	bodyWeld.Parent = root

	local function colorAt(index: number): Color3
		local color = def.colors[(index - 1) % #def.colors + 1]
		if mutation then
			color = color:Lerp(mutation.color, 0.45)
		end
		return color
	end

	-- A realistic cloud body: many overlapping puffs, lighter on top and
	-- shadowed underneath, with soft wisps drifting off the edges.
	local puffs = {
		{ size = 4, offset = Vector3.new(0, 0, 0) },
		{ size = 3, offset = Vector3.new(-2, -0.4, 0.2) },
		{ size = 3, offset = Vector3.new(2, -0.4, 0.1) },
		{ size = 2.8, offset = Vector3.new(-0.9, 1.5, 0.3) },
		{ size = 2.6, offset = Vector3.new(1.1, 1.4, 0.4) },
		{ size = 2.4, offset = Vector3.new(0, -0.7, 1.5) },
		{ size = 2.2, offset = Vector3.new(0.1, 0.4, -1.5) },
		{ size = 2, offset = Vector3.new(-2.9, -0.7, -0.4) },
		{ size = 2, offset = Vector3.new(2.9, -0.6, -0.3) },
		{ size = 1.8, offset = Vector3.new(0.3, 2.4, -0.2) },
	}
	local glowing = rarity.index >= 4
	local shadow = Color3.fromRGB(70, 74, 88)
	for index, puff in puffs do
		-- Top puffs catch the light; low ones are in shadow.
		local lift = math.clamp((puff.offset.Y + 1) / 3.5, 0, 1)
		local color = colorAt(index):Lerp(shadow, 0.28 * (1 - lift)):Lerp(Color3.new(1, 1, 1), 0.12 * lift)
		local part = ball(model, puff.size * scale, color, CFrame.new(puff.offset * scale))
		part.Name = "Puff"
		if glowing then
			part.Transparency = 0.18 -- lets the glowing core shine through
		end
		weld(body, part)
	end

	-- Epic and rarer storms have a glowing heart of their rarity's color.
	if glowing then
		local core = ball(model, 2.4 * scale, rarity.color, CFrame.new(0, 0.2 * scale, 0), Enum.Material.Neon)
		core.Name = "Core"
		weld(body, core)
	end

	local wispAttachment = Instance.new("Attachment")
	wispAttachment.Name = "WispAttachment"
	wispAttachment.Parent = root
	local wisps = Instance.new("ParticleEmitter")
	wisps.Name = "Wisps"
	wisps.Texture = SMOKE
	wisps.Color = ColorSequence.new(colorAt(1):Lerp(Color3.new(1, 1, 1), 0.2))
	wisps.Size = NumberSequence.new(2.4 * scale, 3.6 * scale)
	wisps.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	wisps.Lifetime = NumberRange.new(2, 3)
	wisps.Rate = 3
	wisps.Speed = NumberRange.new(0.4, 1)
	wisps.SpreadAngle = Vector2.new(180, 180)
	wisps.RotSpeed = NumberRange.new(-10, 10)
	wisps.LockedToPart = true
	wisps.Parent = wispAttachment

	-- Mega-Storm bosses and grumpy clouds have glowing, narrowed eyes.
	if opts.angry then
		for _, side in { -1, 1 } do
			local eye = Instance.new("Part")
			eye.Name = "Eye"
			eye.Size = Vector3.new(0.9, 0.28, 0.3) * scale
			eye.Color = Color3.fromRGB(255, 90, 60)
			eye.Material = Enum.Material.Neon
			eye.CFrame = CFrame.new(Vector3.new(0.8 * side, 0.4, -1.95) * scale)
				* CFrame.Angles(0, 0, math.rad(-18 * side))
			eye.CanCollide = false
			eye.CanTouch = false
			eye.CanQuery = false
			eye.Massless = true
			eye.CastShadow = false
			eye.Anchored = false
			eye.Parent = model
			weld(body, eye)
		end
	end

	addParticles(root, def.fx, scale)

	-- Rarity glow: sparkles and light that get fancier the rarer it is.
	local sparkleRate = ({ 0, 0, 2, 4, 6, 9, 12 })[rarity.index] or 0
	if sparkleRate > 0 then
		local attachment = Instance.new("Attachment")
		attachment.Name = "GlowAttachment"
		attachment.Parent = root
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Name = "RarityGlow"
		sparkles.Texture = SPARKLE
		sparkles.Color = ColorSequence.new(rarity.color, Color3.new(1, 1, 1))
		sparkles.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.3, 0.45 * scale),
			NumberSequenceKeypoint.new(1, 0),
		})
		sparkles.Rate = sparkleRate
		sparkles.Lifetime = NumberRange.new(1, 1.8)
		sparkles.Speed = NumberRange.new(0.5, 1.5)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.LightEmission = 1
		sparkles.Parent = attachment
	end
	if rarity.index >= 4 and not mutation then
		local light = Instance.new("PointLight")
		light.Name = "RarityLight"
		light.Color = rarity.color
		light.Range = 8 * scale
		light.Brightness = 0.8
		light.Parent = root
	end

	model:SetAttribute("Scale", scale)
	CollectionService:AddTag(model, "StormCreature")

	if mutation then
		local glow = Instance.new("PointLight")
		glow.Color = mutation.color
		glow.Range = 12 * scale
		glow.Brightness = 2
		glow.Parent = root
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = mutation.color
		sparkles.Parent = root
	end

	return model
end

-- A glass jar with a lid, sized around a storm of the given rarity. The jar's
-- base sits at the pivot, so place it on top of a pedestal.
function StormModel.buildJar(scale: number, anchored: boolean): Model
	local jar = Instance.new("Model")
	jar.Name = "Jar"

	local height = 7.5 * scale
	local width = 7 * scale

	local glass = Instance.new("Part")
	glass.Name = "Glass"
	glass.Shape = Enum.PartType.Cylinder
	glass.Size = Vector3.new(height, width, width)
	glass.CFrame = CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90))
	glass.Material = Enum.Material.Glass
	glass.Color = Color3.fromRGB(200, 235, 255)
	glass.Transparency = 0.75
	glass.CanCollide = false
	glass.CanTouch = false
	glass.CanQuery = false
	glass.Massless = true
	glass.CastShadow = false
	glass.Anchored = anchored
	glass.Parent = jar
	jar.PrimaryPart = glass

	local lid = Instance.new("Part")
	lid.Name = "Lid"
	lid.Shape = Enum.PartType.Cylinder
	lid.Size = Vector3.new(0.8 * scale, width * 0.8, width * 0.8)
	lid.CFrame = CFrame.new(0, height + 0.4 * scale, 0) * CFrame.Angles(0, 0, math.rad(90))
	lid.Material = Enum.Material.Metal
	lid.Color = Color3.fromRGB(190, 140, 70)
	lid.CanCollide = false
	lid.CanTouch = false
	lid.CanQuery = false
	lid.Massless = true
	lid.Anchored = anchored
	lid.Parent = jar
	if not anchored then
		weld(glass, lid)
	end

	return jar
end

-- Floating label above a storm.
function StormModel.nameTag(def: StormData.StormDef, mutation: string?, subtitle: string?): BillboardGui
	local rarity = StormData.rarityOf(def)
	local mutationDef = StormData.getMutation(mutation)

	local gui = Instance.new("BillboardGui")
	gui.Name = "NameTag"
	gui.Size = UDim2.fromOffset(220, 70)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 4.5 * rarity.scale, 0)
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false

	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = gui

	local function line(order: number, text: string, color: Color3, size: number)
		local label = Instance.new("TextLabel")
		label.Name = "Line" .. order
		label.LayoutOrder = order
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, 0, 0, size + 4)
		label.Font = Enum.Font.GothamBold
		label.TextSize = size
		label.TextColor3 = color
		label.TextStrokeTransparency = 0.3
		label.Text = text
		label.Parent = gui
		return label
	end

	if mutationDef then
		line(1, mutationDef.emoji .. " " .. mutationDef.name, mutationDef.color, 16)
	end
	line(2, def.name, Color3.new(1, 1, 1), 20)
	line(3, rarity.name, rarity.color, 16)
	if subtitle then
		line(4, subtitle, Color3.fromRGB(255, 225, 90), 16)
	end
	return gui
end

return StormModel
