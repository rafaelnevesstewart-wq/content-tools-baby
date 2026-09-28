-- 🏠 Furniture for Base Island plots (BaseData.Furniture): build(key, cell)
-- makes the pieces inside one 3-stud cell. `cell` is the cell's middle,
-- turned the way the furniture faces (its front is -Z). Every piece is
-- anchored; BaseService parents them to the cell's invisible root part.

local FurnitureModels = {}

local rgb = Color3.fromRGB
local M = Enum.Material

local function piece(
	parent: Instance,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	props: { [string]: any }?
): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	local extra: { [string]: any } = props or {}
	for key, value in extra do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

local WOOD = rgb(150, 105, 65)
local DARK = rgb(96, 66, 42)

local STONE = rgb(150, 150, 155)

-- 🚪 A door swings open and shut when anyone uses its handle.
local function door(parent: Instance, c: CFrame)
	local floor = c * CFrame.new(0, -1.5, 0)
	local frame = rgb(110, 76, 44)
	for _, x in { -1.35, 1.35 } do
		piece(parent, Vector3.new(0.3, 6, 0.6), floor * CFrame.new(x, 3, 0), frame, M.Wood)
	end
	piece(parent, Vector3.new(3, 0.3, 0.6), floor * CFrame.new(0, 5.85, 0), frame, M.Wood)
	local hinge = floor * CFrame.new(-1.2, 0, 0)
	local closed = hinge * CFrame.new(1.2, 2.85, 0)
	local open = hinge * CFrame.Angles(0, math.rad(-90), 0) * CFrame.new(1.2, 2.85, 0)
	local panel = piece(parent, Vector3.new(2.4, 5.6, 0.25), closed, rgb(150, 100, 60), M.WoodPlanks)
	panel.Name = "DoorPanel"
	local knob = piece(parent, Vector3.new(0.25, 0.25, 0.5), closed * CFrame.new(0.9, 0, 0), rgb(230, 190, 80), M.Foil)
	knob.CanCollide = false
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open"
	prompt.ObjectText = "🚪 Door"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt.Parent = panel
	local isOpen = false
	prompt.Triggered:Connect(function()
		isOpen = not isOpen
		local at = if isOpen then open else closed
		panel.CFrame = at
		knob.CFrame = at * CFrame.new(0.9, 0, 0)
		prompt.ActionText = if isOpen then "Close" else "Open"
	end)
end

local BUILDERS: { [string]: (Instance, CFrame) -> () } = {
	Stairs = function(parent, c)
		local floor = c * CFrame.new(0, -1.5, 0)
		-- Three steps going up toward the back.
		for step = 1, 3 do
			piece(parent, Vector3.new(3, step, 1), floor * CFrame.new(0, step / 2, -1.5 + (step - 0.5)), STONE, M.Brick)
		end
	end,
	Slab = function(parent, c)
		piece(parent, Vector3.new(3, 1.5, 3), c * CFrame.new(0, -0.75, 0), STONE, M.Brick)
	end,
	Window = function(parent, c)
		-- A stone wall block with a glass pane in the middle.
		piece(parent, Vector3.new(3, 0.5, 3), c * CFrame.new(0, 1.25, 0), STONE, M.Brick)
		piece(parent, Vector3.new(3, 0.5, 3), c * CFrame.new(0, -1.25, 0), STONE, M.Brick)
		for _, x in { -1.25, 1.25 } do
			piece(parent, Vector3.new(0.5, 2, 3), c * CFrame.new(x, 0, 0), STONE, M.Brick)
		end
		piece(parent, Vector3.new(2, 2, 0.2), c, rgb(190, 230, 255), M.Glass, { Transparency = 0.5 })
	end,
	Door = door,
	Chair = function(parent, c)
		local floor = c * CFrame.new(0, -1.5, 0)
		piece(parent, Vector3.new(1.8, 0.25, 1.8), floor * CFrame.new(0, 1.3, 0), WOOD, M.Wood)
		piece(parent, Vector3.new(1.8, 1.8, 0.25), floor * CFrame.new(0, 2.3, 0.8), WOOD, M.Wood)
		for _, x in { -0.75, 0.75 } do
			for _, z in { -0.75, 0.75 } do
				piece(parent, Vector3.new(0.2, 1.2, 0.2), floor * CFrame.new(x, 0.6, z), DARK, M.Wood)
			end
		end
	end,
	Table = function(parent, c)
		local floor = c * CFrame.new(0, -1.5, 0)
		piece(parent, Vector3.new(2.9, 0.25, 2.9), floor * CFrame.new(0, 1.9, 0), WOOD, M.WoodPlanks)
		for _, x in { -1.2, 1.2 } do
			for _, z in { -1.2, 1.2 } do
				piece(parent, Vector3.new(0.25, 1.8, 0.25), floor * CFrame.new(x, 0.9, z), DARK, M.Wood)
			end
		end
		-- A plate.
		piece(parent, Vector3.new(0.8, 0.08, 0.8), floor * CFrame.new(0, 2.06, 0), rgb(240, 240, 240), M.SmoothPlastic)
	end,
	Bed = function(parent, c)
		local floor = c * CFrame.new(0, -1.5, 0)
		piece(parent, Vector3.new(2.6, 0.6, 2.9), floor * CFrame.new(0, 0.5, 0), DARK, M.Wood)
		piece(parent, Vector3.new(2.5, 0.35, 2.8), floor * CFrame.new(0, 0.95, 0), rgb(245, 245, 245), M.Fabric)
		piece(parent, Vector3.new(2.52, 0.4, 1.8), floor * CFrame.new(0, 1.0, -0.5), rgb(200, 70, 80), M.Fabric)
		piece(parent, Vector3.new(1.6, 0.35, 0.7), floor * CFrame.new(0, 1.3, 1.0), rgb(250, 250, 250), M.Fabric)
		piece(parent, Vector3.new(2.6, 1.6, 0.25), floor * CFrame.new(0, 1.1, 1.4), DARK, M.Wood)
	end,
	Sofa = function(parent, c)
		local floor = c * CFrame.new(0, -1.5, 0)
		local fabric = rgb(80, 110, 190)
		piece(parent, Vector3.new(2.9, 0.8, 2), floor * CFrame.new(0, 0.6, -0.2), fabric, M.Fabric)
		piece(parent, Vector3.new(2.9, 1.4, 0.6), floor * CFrame.new(0, 1.3, 1), fabric, M.Fabric)
		for _, x in { -1.3, 1.3 } do
			piece(
				parent,
				Vector3.new(0.35, 1.2, 2.4),
				floor * CFrame.new(x, 1.0, 0),
				fabric:Lerp(rgb(0, 0, 0), 0.15),
				M.Fabric
			)
		end
	end,
	Lamp = function(parent, c)
		local floor = c * CFrame.new(0, -1.5, 0)
		piece(parent, Vector3.new(1, 0.2, 1), floor * CFrame.new(0, 0.1, 0), DARK, M.Metal)
		piece(parent, Vector3.new(0.15, 2, 0.15), floor * CFrame.new(0, 1.1, 0), DARK, M.Metal)
		local shade =
			piece(parent, Vector3.new(1.2, 0.8, 1.2), floor * CFrame.new(0, 2.3, 0), rgb(255, 225, 150), M.Neon)
		local light = Instance.new("PointLight")
		light.Color = rgb(255, 220, 160)
		light.Range = 14
		light.Parent = shade
	end,
	Plant = function(parent, c)
		local floor = c * CFrame.new(0, -1.5, 0)
		piece(parent, Vector3.new(1.2, 1, 1.2), floor * CFrame.new(0, 0.5, 0), rgb(190, 100, 60), M.Slate)
		for i = 0, 4 do
			local angle = i / 5 * math.pi * 2
			piece(
				parent,
				Vector3.new(0.5, 1.6, 0.15),
				floor
					* CFrame.new(math.cos(angle) * 0.3, 1.7, math.sin(angle) * 0.3)
					* CFrame.Angles(0, -angle, math.rad(20)),
				rgb(70, 150, 70),
				M.Grass
			)
		end
	end,
	Bookshelf = function(parent, c)
		local floor = c * CFrame.new(0, -1.5, 0)
		piece(parent, Vector3.new(2.9, 2.9, 0.2), floor * CFrame.new(0, 1.45, 1.35), DARK, M.Wood)
		for _, y in { 0.1, 1, 1.9, 2.8 } do
			piece(parent, Vector3.new(2.9, 0.15, 1.2), floor * CFrame.new(0, y, 0.85), WOOD, M.Wood)
		end
		local colors = { rgb(200, 60, 60), rgb(60, 110, 200), rgb(70, 160, 80), rgb(230, 190, 70), rgb(150, 80, 180) }
		for shelf, y in { 0.55, 1.45, 2.35 } do
			for i = 0, 6 do
				piece(
					parent,
					Vector3.new(0.3, 0.7, 0.9),
					floor * CFrame.new(-1.15 + i * 0.37, y, 0.85),
					colors[(i + shelf) % #colors + 1],
					M.SmoothPlastic
				)
			end
		end
	end,
	TV = function(parent, c)
		local floor = c * CFrame.new(0, -1.5, 0)
		piece(parent, Vector3.new(2.8, 0.8, 1.2), floor * CFrame.new(0, 0.4, 0.6), DARK, M.Wood)
		piece(parent, Vector3.new(2.6, 1.6, 0.2), floor * CFrame.new(0, 1.7, 0.7), rgb(30, 30, 36), M.SmoothPlastic)
		local screen =
			piece(parent, Vector3.new(2.4, 1.4, 0.05), floor * CFrame.new(0, 1.7, 0.58), rgb(90, 170, 255), M.Neon)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.Parent = screen
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.TextScaled = true
		label.Text = "⛈️"
		label.Parent = gui
	end,
	Rug = function(parent, c)
		local floor = c * CFrame.new(0, -1.5, 0)
		piece(parent, Vector3.new(2.9, 0.1, 2.9), floor * CFrame.new(0, 0.05, 0), rgb(180, 60, 60), M.Fabric)
		piece(parent, Vector3.new(2.2, 0.12, 2.2), floor * CFrame.new(0, 0.06, 0), rgb(230, 190, 90), M.Fabric)
		piece(parent, Vector3.new(1.4, 0.14, 1.4), floor * CFrame.new(0, 0.07, 0), rgb(180, 60, 60), M.Fabric)
	end,
	Painting = function(parent, c)
		local back = c * CFrame.new(0, 0.2, 1.3)
		piece(parent, Vector3.new(2.4, 1.9, 0.2), back, rgb(230, 190, 90), M.Foil)
		local canvas = piece(
			parent,
			Vector3.new(2, 1.5, 0.05),
			back * CFrame.new(0, 0, -0.12),
			rgb(250, 245, 230),
			M.SmoothPlastic
		)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.Parent = canvas
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.TextScaled = true
		label.Text = "🌪️🏝️"
		label.Parent = gui
	end,
	Fireplace = function(parent, c)
		local floor = c * CFrame.new(0, -1.5, 0)
		local brick = rgb(160, 90, 60)
		piece(parent, Vector3.new(2.9, 2.9, 0.6), floor * CFrame.new(0, 1.45, 1.15), brick, M.Brick)
		for _, x in { -1.2, 1.2 } do
			piece(parent, Vector3.new(0.5, 2, 1.2), floor * CFrame.new(x, 1, 0.4), brick, M.Brick)
		end
		piece(
			parent,
			Vector3.new(2.9, 0.5, 1.3),
			floor * CFrame.new(0, 2.2, 0.45),
			brick:Lerp(rgb(0, 0, 0), 0.2),
			M.Brick
		)
		local logs = piece(parent, Vector3.new(1.4, 0.4, 0.6), floor * CFrame.new(0, 0.2, 0.5), DARK, M.Wood)
		local fire = Instance.new("Fire")
		fire.Size = 3
		fire.Heat = 4
		fire.Parent = logs
		local light = Instance.new("PointLight")
		light.Color = rgb(255, 150, 70)
		light.Range = 12
		light.Parent = logs
	end,
	Aquarium = function(parent, c)
		local floor = c * CFrame.new(0, -1.5, 0)
		piece(parent, Vector3.new(2.8, 1, 1.6), floor * CFrame.new(0, 0.5, 0), DARK, M.Wood)
		piece(parent, Vector3.new(2.7, 1.6, 1.5), floor * CFrame.new(0, 1.8, 0), rgb(90, 180, 230), M.Glass, {
			Transparency = 0.5,
		})
		for i, color in { rgb(255, 140, 40), rgb(250, 220, 60), rgb(230, 80, 150) } do
			local fish = piece(
				parent,
				Vector3.new(0.4, 0.3, 0.2),
				floor * CFrame.new(-0.9 + i * 0.5, 1.6 + (i % 2) * 0.4, 0),
				color,
				M.Neon
			)
			fish.CanCollide = false
		end
	end,
}

-- Builds furniture `key` in the cell at `cell` (see above).
function FurnitureModels.build(parent: Instance, key: string, cell: CFrame): boolean
	local build = BUILDERS[key]
	if not build then
		return false
	end
	build(parent, cell)
	return true
end

return FurnitureModels
