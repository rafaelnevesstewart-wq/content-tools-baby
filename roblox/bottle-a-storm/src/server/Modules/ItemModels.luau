-- Detailed models for everything you hold in a match, built from parts so
-- the game needs no uploaded meshes: swords (leather grip, pommel,
-- crossguard, blade with a fuller and a point), the recurve bow, arrows in
-- flight, pickaxes, axes, Storm TNT, fireballs, potion bottles, the Storm
-- Apple and the Wind Pearl.
--
-- Every tool's Handle is its grip, lying along its Z axis; the business end
-- points toward +Z. All other parts are welded to the Handle.

local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local MatchData = require(Shared.MatchData)
local SkinData = require(Shared.SkinData)

local ItemModels = {}

local rgb = Color3.fromRGB
local M = Enum.Material

-- The hand holds the Handle's middle, pointing its +Z end forward.
local GRIP = CFrame.new(0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 1, 0)

local LEATHER = rgb(74, 50, 34)
local DARK_WOOD = rgb(96, 68, 44)
local STEEL = rgb(190, 194, 202)

local function piece(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.CanCollide = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

local function newTool(name: string, tip: string, handle: { [string]: any }): (Tool, Part)
	local tool = Instance.new("Tool")
	tool.Name = name
	tool.ToolTip = tip
	tool.CanBeDropped = false
	tool.Grip = GRIP
	handle.Name = "Handle"
	handle.CFrame = CFrame.new()
	local part = piece(tool, handle)
	return tool, part
end

-- Welds every part of `root`'s tool to it, where they were built.
local function weldAll(tool: Instance, handle: BasePart)
	for _, p in tool:GetDescendants() do
		if p:IsA("BasePart") and p ~= handle then
			p.Anchored = false
			p.CanQuery = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = p
			weld.Parent = p
		end
	end
end

---------------------------------------------------------------------------
-- Swords
---------------------------------------------------------------------------

local BLADE_LOOK: { [string]: { color: Color3, material: Enum.Material, edge: Color3 } } = {
	WoodSword = { color = rgb(150, 112, 72), material = M.Wood, edge = rgb(176, 136, 92) },
	StoneSword = { color = rgb(128, 128, 132), material = M.Slate, edge = rgb(160, 160, 164) },
	IronSword = { color = rgb(196, 200, 208), material = M.Metal, edge = rgb(232, 236, 242) },
	DiamondSword = { color = rgb(110, 225, 240), material = M.Glass, edge = rgb(200, 250, 255) },
}

-- Dresses a sword's blade in its Sword Skin: colors, glowing edges, a light,
-- particles and a swing streak (a Trail from the blade's base to its point
-- that only shows while the sword moves).
local function styleBlade(tool: Tool, blade: BasePart, length: number, skinId: string?)
	local skin = SkinData.sword(skinId)
	for _, p in tool:GetDescendants() do
		if p:IsA("BasePart") and (p.Name == "Blade" or p.Name == "BladeTip" or p.Name == "Fuller") then
			if skin.blade then
				p.Color = if p.Name == "Fuller" then skin.blade:Lerp(Color3.new(0, 0, 0), 0.3) else skin.blade
			end
			if skin.material then
				p.Material = skin.material
			end
			p.Transparency = skin.transparency or 0
			p.Reflectance = skin.reflectance or 0
		elseif p:IsA("BasePart") and p.Name == "Edge" then
			if skin.edge then
				p.Color = skin.edge
			end
			if skin.edgeGlow then
				p.Material = M.Neon
			elseif skin.material then
				p.Material = skin.material
			end
		end
	end
	if skin.glow then
		local light = Instance.new("PointLight")
		light.Name = if skin.pulse then "PulseLight" else "BladeLight"
		light.Color = skin.glow
		light.Range = 9
		light.Brightness = 1.2
		light.Parent = blade
	end
	if skin.sparkles then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = skin.sparkles
		sparkles.Parent = blade
	end
	if skin.fire then
		local fire = Instance.new("Fire")
		fire.Size = 2
		fire.Heat = 4
		fire.Color = rgb(255, 150, 50)
		fire.SecondaryColor = rgb(255, 60, 20)
		fire.Parent = blade
	end
	if skin.particles then
		SkinData.emitter(skin.particles).Parent = blade
	end
	-- The swing streak.
	local base = Instance.new("Attachment")
	base.Name = "SwingBase"
	base.Position = Vector3.new(0, 0, -length / 2)
	base.Parent = blade
	local point = Instance.new("Attachment")
	point.Name = "SwingPoint"
	point.Position = Vector3.new(0, 0, length / 2 + 0.2)
	point.Parent = blade
	local streak = Instance.new("Trail")
	streak.Name = "SwingTrail"
	streak.Attachment0 = base
	streak.Attachment1 = point
	streak.Color = SkinData.sequence(skin.swing)
	streak.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, if skinId and skinId ~= SkinData.DefaultSword then 0.25 else 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	streak.Lifetime = 0.18
	streak.MinLength = 0.1
	streak.LightEmission = if skinId and skinId ~= SkinData.DefaultSword then 0.8 else 0.2
	streak.FaceCamera = false
	streak.Parent = blade
	-- Crackling bolts and throbbing lights are animated by the client's FlashyFx.
	if skin.bolts or skin.pulse then
		if skin.bolts then
			blade:SetAttribute("Bolts", skin.bolts)
		end
		CollectionService:AddTag(blade, "FlashyFx")
	end
end

function ItemModels.sword(tier: number, skin: string?): Tool
	local sword = MatchData.Swords[tier]
	local look = BLADE_LOOK[sword.key] or BLADE_LOOK.IronSword
	local tool, handle = newTool(
		"Sword",
		sword.name .. " (" .. sword.damage .. " damage)",
		{ Size = Vector3.new(0.26, 0.26, 1.1), Color = LEATHER, Material = M.Fabric }
	)
	-- Leather wraps, pommel and crossguard.
	for i = -1, 1 do
		piece(tool, {
			Size = Vector3.new(0.3, 0.3, 0.08),
			CFrame = CFrame.new(0, 0, i * 0.34),
			Color = LEATHER:Lerp(Color3.new(0, 0, 0), 0.3),
			Material = M.Fabric,
		})
	end
	local fitting = if sword.key == "WoodSword" then DARK_WOOD else rgb(150, 120, 60)
	local fittingMaterial = if sword.key == "WoodSword" then M.Wood else M.Metal
	piece(tool, {
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 0.42,
		CFrame = CFrame.new(0, 0, -0.66),
		Color = fitting,
		Material = fittingMaterial,
	})
	piece(tool, {
		Size = Vector3.new(0.3, 1.5, 0.24),
		CFrame = CFrame.new(0, 0, 0.66),
		Color = fitting,
		Material = fittingMaterial,
	})
	for _, side in { -1, 1 } do
		piece(tool, {
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.3,
			CFrame = CFrame.new(0, side * 0.78, 0.66),
			Color = fitting,
			Material = fittingMaterial,
		})
	end
	-- The blade: a flat body, a darker fuller groove down the middle and a
	-- diamond-cut point.
	local length = 3.2
	local blade = piece(tool, {
		Name = "Blade",
		Size = Vector3.new(0.08, 0.44, length),
		CFrame = CFrame.new(0, 0, 0.78 + length / 2),
		Color = look.color,
		Material = look.material,
	})
	piece(tool, {
		Name = "BladeTip",
		Size = Vector3.new(0.08, 0.31, 0.31),
		CFrame = CFrame.new(0, 0, 0.78 + length) * CFrame.Angles(math.rad(45), 0, 0),
		Color = look.color,
		Material = look.material,
	})
	for _, side in { -1, 1 } do
		piece(tool, {
			Name = "Edge",
			Size = Vector3.new(0.05, 0.06, length),
			CFrame = CFrame.new(0, side * 0.21, 0.78 + length / 2),
			Color = look.edge,
			Material = look.material,
		})
	end
	piece(tool, {
		Name = "Fuller",
		Size = Vector3.new(0.1, 0.1, length * 0.7),
		CFrame = CFrame.new(0, 0, 0.78 + length * 0.38),
		Color = look.color:Lerp(Color3.new(0, 0, 0), 0.25),
		Material = look.material,
	})
	styleBlade(tool, blade, length, skin)
	weldAll(tool, handle)
	return tool
end

---------------------------------------------------------------------------
-- Bow and arrows
---------------------------------------------------------------------------

function ItemModels.bow(): Tool
	local tool, handle = newTool(
		"Bow",
		"Click to shoot (needs arrows)",
		{ Size = Vector3.new(0.3, 0.9, 0.3), Color = LEATHER, Material = M.Fabric }
	)
	-- Two limbs curving back, then recurving forward at the tips.
	local tips = {}
	for _, side in { -1, 1 } do
		local segments = {
			{ from = Vector3.new(0, side * 0.45, 0), to = Vector3.new(0, side * 1.4, -0.35) },
			{ from = Vector3.new(0, side * 1.4, -0.35), to = Vector3.new(0, side * 2.2, -0.45) },
			{ from = Vector3.new(0, side * 2.2, -0.45), to = Vector3.new(0, side * 2.55, -0.25) },
		}
		for index, segment in segments do
			local a, b = segment.from, segment.to
			piece(tool, {
				Size = Vector3.new(0.22, 0.16, (b - a).Magnitude + 0.05),
				CFrame = CFrame.lookAt((a + b) / 2, b),
				Color = if index == 3 then rgb(60, 42, 30) else DARK_WOOD,
				Material = M.Wood,
			})
		end
		table.insert(tips, segments[3].to)
	end
	-- The string, pulled straight between the tips.
	local a, b = tips[1], tips[2]
	piece(tool, {
		Name = "String",
		Size = Vector3.new(0.04, 0.04, (b - a).Magnitude),
		CFrame = CFrame.lookAt((a + b) / 2, b),
		Color = rgb(230, 225, 210),
		Material = M.Fabric,
	})
	weldAll(tool, handle)
	return tool
end

-- An arrow in flight (anchored root; move it with root.CFrame). Its Arrow
-- Effect colors the fletching and adds a glowing flight streak, particles
-- and sometimes a light.
function ItemModels.arrow(effect: string?): Model
	local skin = SkinData.beam(effect)
	local model = Instance.new("Model")
	model.Name = "Arrow"
	local shaft = piece(model, {
		Name = "Shaft",
		Size = Vector3.new(0.1, 0.1, 2.6),
		Color = rgb(170, 130, 88),
		Material = M.Wood,
		Anchored = true,
		CanQuery = false,
	})
	model.PrimaryPart = shaft
	piece(model, {
		Size = Vector3.new(0.05, 0.22, 0.22),
		CFrame = CFrame.new(0, 0, -1.35) * CFrame.Angles(math.rad(45), 0, 0),
		Color = STEEL,
		Material = M.Metal,
	})
	for i = 0, 2 do
		piece(model, {
			Size = Vector3.new(0.02, 0.22, 0.55),
			CFrame = CFrame.new(0, 0, 1.05) * CFrame.Angles(0, 0, i * math.rad(120)) * CFrame.new(0, 0.12, 0),
			Color = skin.color,
			Material = M.Fabric,
		})
	end
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p ~= shaft then
			p.Anchored = false
			p.CanQuery = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = shaft
			weld.Part1 = p
			weld.Parent = p
		end
	end
	-- The flight streak, flat across the arrow so it reads from every side.
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, 0.18, 0.9)
	top.Parent = shaft
	local bottom = Instance.new("Attachment")
	bottom.Position = Vector3.new(0, -0.18, 0.9)
	bottom.Parent = shaft
	local streak = Instance.new("Trail")
	streak.Attachment0 = top
	streak.Attachment1 = bottom
	streak.Color = SkinData.sequence(skin.streak)
	streak.Transparency = NumberSequence.new(0.2, 1)
	streak.WidthScale = NumberSequence.new(1, 0.2)
	streak.Lifetime = 0.25
	streak.LightEmission = 0.8
	streak.FaceCamera = true
	streak.Parent = shaft
	if skin.particles then
		SkinData.emitter(skin.particles).Parent = shaft
	end
	if skin.light then
		local light = Instance.new("PointLight")
		light.Color = skin.glow
		light.Range = 10
		light.Brightness = 1.5
		light.Parent = shaft
	end
	return model
end

---------------------------------------------------------------------------
-- Pickaxes and axes
---------------------------------------------------------------------------

local function toolHandle(name: string, tip: string): (Tool, Part)
	local tool, handle = newTool(name, tip, { Size = Vector3.new(0.24, 0.24, 1), Color = LEATHER, Material = M.Fabric })
	piece(tool, {
		Name = "Shaft",
		Size = Vector3.new(0.22, 0.22, 2.6),
		CFrame = CFrame.new(0, 0, 0.8),
		Color = DARK_WOOD,
		Material = M.Wood,
	})
	return tool, handle
end

function ItemModels.pickaxe(tier: MatchData.ToolTier): Tool
	local tool, handle = toolHandle("Pickaxe", tier.name .. " (click a block)")
	local head = CFrame.new(0, 0, 2.05)
	local material = if tier.name:find("Wood") then M.Wood elseif tier.name:find("Stone") then M.Slate else M.Metal
	piece(tool, {
		Size = Vector3.new(0.32, 0.5, 0.4),
		CFrame = head,
		Color = tier.color:Lerp(Color3.new(0, 0, 0), 0.2),
		Material = material,
	})
	-- Two curved picks, thinner toward the points.
	for _, side in { -1, 1 } do
		piece(tool, {
			Size = Vector3.new(0.26, 0.9, 0.26),
			CFrame = head * CFrame.new(0, side * 0.6, -0.08) * CFrame.Angles(math.rad(side * 14), 0, 0),
			Color = tier.color,
			Material = material,
		})
		piece(tool, {
			Size = Vector3.new(0.16, 0.2, 0.2),
			CFrame = head * CFrame.new(0, side * 1.08, -0.24) * CFrame.Angles(math.rad(45), 0, 0),
			Color = tier.color,
			Material = material,
		})
	end
	weldAll(tool, handle)
	return tool
end

function ItemModels.axe(tier: MatchData.ToolTier): Tool
	local tool, handle = toolHandle("Axe", tier.name .. " (click a block)")
	local head = CFrame.new(0, 0, 1.85)
	local material = if tier.name:find("Wood") then M.Wood elseif tier.name:find("Stone") then M.Slate else M.Metal
	piece(tool, {
		Size = Vector3.new(0.3, 0.45, 0.5),
		CFrame = head * CFrame.new(0, -0.1, 0),
		Color = tier.color:Lerp(Color3.new(0, 0, 0), 0.2),
		Material = material,
	})
	-- A wide bit that flares out to a bright cutting edge.
	piece(tool, {
		Size = Vector3.new(0.14, 0.8, 0.7),
		CFrame = head * CFrame.new(0, 0.5, 0),
		Color = tier.color,
		Material = material,
	})
	piece(tool, {
		Size = Vector3.new(0.08, 0.14, 0.95),
		CFrame = head * CFrame.new(0, 0.93, 0),
		Color = tier.color:Lerp(Color3.new(1, 1, 1), 0.35),
		Material = material,
	})
	weldAll(tool, handle)
	return tool
end

---------------------------------------------------------------------------
-- Throwables and consumables
---------------------------------------------------------------------------

-- Three sticks of dynamite tied together, with a fuse.
function ItemModels.tnt(): Tool
	local tool, handle = newTool("Storm TNT", "Click to place (3 second fuse)", {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.3, 0.42, 0.42),
		CFrame = CFrame.Angles(0, math.rad(90), 0),
		Color = rgb(190, 36, 36),
		Material = M.SmoothPlastic,
	})
	handle.CFrame = CFrame.Angles(0, math.rad(90), 0)
	for _, x in { -0.42, 0.42 } do
		piece(tool, {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.3, 0.42, 0.42),
			CFrame = CFrame.new(x, 0, 0) * CFrame.Angles(0, math.rad(90), 0),
			Color = rgb(190, 36, 36),
			Material = M.SmoothPlastic,
		})
	end
	piece(tool, {
		Size = Vector3.new(1.35, 0.48, 0.2),
		Color = rgb(60, 50, 40),
		Material = M.Fabric,
	})
	piece(tool, {
		Size = Vector3.new(0.05, 0.05, 0.5),
		CFrame = CFrame.new(0, 0, -0.85),
		Color = rgb(30, 30, 30),
		Material = M.Fabric,
	})
	tool:SetAttribute("PlaceGadget", "TNT")
	weldAll(tool, handle)
	return tool
end

-- The placed Storm TNT block (anchored), with TNT labels on its sides.
function ItemModels.tntBlock(size: number): Part
	local block = Instance.new("Part")
	block.Name = "StormTNT"
	block.Anchored = true
	block.CanCollide = false
	block.Size = Vector3.one * size
	block.Color = rgb(200, 40, 40)
	block.Material = M.SmoothPlastic
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.Parent = block
		local band = Instance.new("Frame")
		band.AnchorPoint = Vector2.new(0, 0.5)
		band.Position = UDim2.fromScale(0, 0.5)
		band.Size = UDim2.fromScale(1, 0.34)
		band.BackgroundColor3 = rgb(235, 228, 210)
		band.BorderSizePixel = 0
		band.Parent = gui
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamBlack
		label.Text = "TNT"
		label.TextScaled = true
		label.TextColor3 = rgb(30, 30, 30)
		label.Parent = band
	end
	return block
end

function ItemModels.fireball(): Tool
	local tool, handle = newTool("Fireball", "Click to throw", {
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 0.9,
		Color = rgb(255, 150, 40),
		Material = M.Neon,
	})
	piece(tool, {
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.1,
		Color = rgb(255, 80, 20),
		Material = M.Neon,
		Transparency = 0.6,
	})
	local fire = Instance.new("Fire")
	fire.Size = 2
	fire.Heat = 4
	fire.Parent = handle
	weldAll(tool, handle)
	return tool
end

-- A round glass bottle with colored liquid, a neck and a cork.
function ItemModels.potion(name: string, color: Color3): Tool
	local tool, handle = newTool(name, "Click to drink", {
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 0.8,
		Color = rgb(220, 235, 245),
		Material = M.Glass,
		Transparency = 0.55,
	})
	piece(tool, {
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 0.66,
		CFrame = CFrame.new(0, -0.04, 0),
		Color = color,
		Material = M.Neon,
		Transparency = 0.15,
	})
	piece(tool, {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 0.24, 0.24),
		CFrame = CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = rgb(220, 235, 245),
		Material = M.Glass,
		Transparency = 0.5,
	})
	piece(tool, {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.18, 0.26, 0.26),
		CFrame = CFrame.new(0, 0.74, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = rgb(160, 120, 80),
		Material = M.Wood,
	})
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 5
	light.Brightness = 0.8
	light.Parent = handle
	weldAll(tool, handle)
	return tool
end

-- A shiny red apple with a stem and a leaf.
function ItemModels.apple(): Tool
	local tool, handle = newTool("Storm Apple", "Eat to heal 40", {
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.85, 0.8, 0.85),
		Color = rgb(196, 30, 36),
		Material = M.SmoothPlastic,
		Reflectance = 0.08,
	})
	piece(tool, {
		Size = Vector3.new(0.06, 0.26, 0.06),
		CFrame = CFrame.new(0, 0.48, 0) * CFrame.Angles(0, 0, math.rad(12)),
		Color = rgb(90, 64, 40),
		Material = M.Wood,
	})
	piece(tool, {
		Size = Vector3.new(0.02, 0.12, 0.26),
		CFrame = CFrame.new(0.06, 0.54, 0.1) * CFrame.Angles(math.rad(-30), 0, 0),
		Color = rgb(70, 140, 50),
		Material = M.LeafyGrass,
	})
	weldAll(tool, handle)
	return tool
end

-- A glass orb with a swirling storm inside.
function ItemModels.pearl(): Tool
	local tool, handle = newTool("Wind Pearl", "Throw to teleport where it lands", {
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 0.75,
		Color = rgb(200, 220, 255),
		Material = M.Glass,
		Transparency = 0.45,
	})
	piece(tool, {
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 0.45,
		Color = rgb(150, 90, 230),
		Material = M.Neon,
		Transparency = 0.2,
	})
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = rgb(200, 170, 255)
	sparkles.Parent = handle
	weldAll(tool, handle)
	return tool
end

return ItemModels
