-- The house over each island's pedestals: pillars, a floor slab and railings
-- for every floor you've built (Config.Floors), glowing lift pads between
-- floors, and a roof on top. On one floor it's an open pavilion. Its look is
-- the "house" cosmetic (HouseData); the Fairy Lights decoration strings lights
-- along the roof.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local HouseData = require(Shared.HouseData)

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)

local HouseService = {}

local houses: { [Player]: Model } = {}

-- The house footprint in island space (-Z faces the Wild Skies).
local HALF_WIDTH = 31
local FRONT = -5
local BACK = 45
local LIFT = Vector3.new(26, 0, -1)
local FAIRY = {
	Color3.fromRGB(255, 220, 140),
	Color3.fromRGB(255, 160, 200),
	Color3.fromRGB(160, 220, 255),
	Color3.fromRGB(190, 255, 170),
}

local function block(parent: Instance, frame: CFrame, size: Vector3, surface: HouseData.Surface, name: string?): Part
	local p = Instance.new("Part")
	p.Name = name or "HousePart"
	p.Anchored = true
	p.Size = size
	p.CFrame = frame
	p.Color = surface.color
	p.Material = surface.material
	p.Transparency = surface.transparency or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function roof(parent: Instance, frame: CFrame, top: number, style: HouseData.Style)
	local depth = BACK - FRONT
	local middle = (BACK + FRONT) / 2
	block(
		parent,
		frame * CFrame.new(0, top + 0.5, middle),
		Vector3.new(HALF_WIDTH * 2 + 4, 1, depth + 4),
		style.roof,
		"Roof"
	)
	if style.roofType == "pitched" then
		local rise = 8
		local half = depth / 2 + 2
		local angle = math.atan2(rise, half)
		local length = math.sqrt(half * half + rise * rise)
		for _, side in { -1, 1 } do
			block(
				parent,
				frame * CFrame.new(0, top + 1 + rise / 2, middle + side * half / 2) * CFrame.Angles(-side * angle, 0, 0),
				Vector3.new(HALF_WIDTH * 2 + 5, 0.8, length),
				style.roof
			)
		end
	elseif style.roofType == "castle" then
		for x = -HALF_WIDTH, HALF_WIDTH, 4 do
			for _, z in { FRONT - 1, BACK + 1 } do
				block(parent, frame * CFrame.new(x, top + 2, z), Vector3.new(2, 2.5, 2), style.roof)
			end
		end
		for z = FRONT + 3, BACK - 1, 4 do
			for _, x in { -HALF_WIDTH - 1, HALF_WIDTH + 1 } do
				block(parent, frame * CFrame.new(x, top + 2, z), Vector3.new(2, 2.5, 2), style.roof)
			end
		end
	elseif style.roofType == "dome" then
		for tier, radius in { 26, 21, 15, 8 } do
			local p = block(
				parent,
				frame * CFrame.new(0, top + 1 + tier * 2.2, middle) * CFrame.Angles(0, 0, math.rad(90)),
				Vector3.new(2.2, radius * 2, radius * 2),
				style.roof
			)
			p.Shape = Enum.PartType.Cylinder
		end
	end
end

local function fairyLights(parent: Instance, frame: CFrame, top: number)
	local corners = {
		Vector3.new(-HALF_WIDTH - 2, top + 1.3, FRONT - 2),
		Vector3.new(HALF_WIDTH + 2, top + 1.3, FRONT - 2),
		Vector3.new(HALF_WIDTH + 2, top + 1.3, BACK + 2),
		Vector3.new(-HALF_WIDTH - 2, top + 1.3, BACK + 2),
	}
	local count = 0
	for i = 1, 4 do
		local a, b = corners[i], corners[i % 4 + 1]
		local steps = math.floor((b - a).Magnitude / 3)
		for step = 0, steps - 1 do
			count += 1
			local bulb = Instance.new("Part")
			bulb.Name = "FairyLight"
			bulb.Shape = Enum.PartType.Ball
			bulb.Size = Vector3.one * 0.6
			bulb.Anchored = true
			bulb.CanCollide = false
			bulb.CastShadow = false
			bulb.Material = Enum.Material.Neon
			bulb.Color = FAIRY[count % #FAIRY + 1]
			-- A gentle droop between posts.
			local alpha = step / steps
			bulb.CFrame = frame * CFrame.new(a:Lerp(b, alpha) - Vector3.new(0, math.sin(alpha * math.pi) * 0.8, 0))
			bulb.Parent = parent
			if count % 8 == 0 then
				local light = Instance.new("PointLight")
				light.Color = bulb.Color
				light.Range = 10
				light.Brightness = 1
				light.Parent = bulb
			end
		end
	end
end

local function liftPad(parent: Instance, frame: CFrame, floor: number, floors: number, style: HouseData.Style)
	local y = (floor - 1) * Config.Floors.Height
	local pad = Instance.new("Part")
	pad.Name = "LiftPad" .. floor
	pad.Shape = Enum.PartType.Cylinder
	pad.Size = Vector3.new(0.4, 6, 6)
	pad.CFrame = frame * CFrame.new(LIFT + Vector3.new(0, y + 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	pad.Anchored = true
	pad.CanCollide = false
	pad.Material = Enum.Material.Neon
	pad.Color = if style.trim then style.trim.color else Color3.fromRGB(120, 210, 255)
	pad.Transparency = 0.25
	pad.Parent = parent
	local function prompt(action: string, key: Enum.KeyCode, target: number)
		local p = Instance.new("ProximityPrompt")
		p.ActionText = action
		p.ObjectText = "🛗 Lift"
		p.KeyboardKeyCode = key
		p.HoldDuration = 0
		p.MaxActivationDistance = 8
		p.RequiresLineOfSight = false
		p.Parent = pad
		p.Triggered:Connect(function(player)
			local character = player.Character
			if character then
				local ty = (target - 1) * Config.Floors.Height
				character:PivotTo(frame * CFrame.new(LIFT + Vector3.new(0, ty + 3.5, -4)))
			end
		end)
	end
	if floor < floors then
		prompt("Up to floor " .. floor + 1, Enum.KeyCode.E, floor + 1)
	end
	if floor > 1 then
		prompt(if floor == 2 then "Down to the ground" else "Down to floor " .. floor - 1, Enum.KeyCode.R, floor - 1)
	end
end

function HouseService.refresh(player: Player)
	local data = DataService.get(player)
	local plot = PlotService.getPlot(player)
	if not data or not plot then
		return
	end
	local old = houses[player] or plot.model:FindFirstChild("House")
	if old then
		old:Destroy()
	end
	local style = HouseData.Styles[data.cosmetics.house or HouseData.Default] or HouseData.Styles[HouseData.Default]
	local floors = math.clamp(data.floors or 1, 1, Config.Floors.Max)
	local height = Config.Floors.Height
	local top = floors * height
	local frame = plot.cframe
	local house = Instance.new("Model")
	house.Name = "House"

	-- Pillars at the corners and the middle of each side.
	for _, x in { -HALF_WIDTH, HALF_WIDTH } do
		for _, z in { FRONT, (FRONT + BACK) / 2, BACK } do
			block(house, frame * CFrame.new(x, top / 2, z), Vector3.new(2, top, 2), style.pillar, "Pillar")
		end
	end

	-- Upper floors: a slab, railings, an optional glowing trim and ceiling lamps.
	local middle = (FRONT + BACK) / 2
	local depth = BACK - FRONT
	for floor = 2, floors do
		local y = (floor - 1) * height
		block(
			house,
			frame * CFrame.new(0, y - 0.5, middle),
			Vector3.new(HALF_WIDTH * 2, 1, depth),
			style.slab,
			"Floor" .. floor
		)
		for _, z in { FRONT, BACK } do
			block(house, frame * CFrame.new(0, y + 0.8, z), Vector3.new(HALF_WIDTH * 2, 1.6, 0.4), style.rail, "Rail")
		end
		for _, x in { -HALF_WIDTH, HALF_WIDTH } do
			block(house, frame * CFrame.new(x, y + 0.8, middle), Vector3.new(0.4, 1.6, depth), style.rail, "Rail")
		end
		if style.trim then
			for _, z in { FRONT - 0.3, BACK + 0.3 } do
				block(
					house,
					frame * CFrame.new(0, y - 0.8, z),
					Vector3.new(HALF_WIDTH * 2, 0.25, 0.25),
					style.trim,
					"Trim"
				)
			end
		end
	end
	for floor = 1, floors do
		local ceiling = floor * height - 0.15
		for _, spot in
			{ Vector3.new(-15, 0, 10), Vector3.new(15, 0, 10), Vector3.new(-15, 0, 32), Vector3.new(15, 0, 32) }
		do
			local lamp = block(
				house,
				frame * CFrame.new(spot.X, ceiling, spot.Z),
				Vector3.new(2, 0.3, 2),
				{ color = style.light or Color3.fromRGB(255, 230, 190), material = Enum.Material.Neon },
				"Lamp"
			)
			lamp.CanCollide = false
			local light = Instance.new("PointLight")
			light.Color = style.light or Color3.fromRGB(255, 230, 190)
			light.Range = 18
			light.Brightness = 0.9
			light.Parent = lamp
		end
	end

	roof(house, frame, top, style)
	if data.cosmetics.decor.FairyLights then
		fairyLights(house, frame, top)
	end
	if floors > 1 then
		for floor = 1, floors do
			liftPad(house, frame, floor, floors, style)
		end
	end
	house.Parent = plot.model
	houses[player] = house
end

function HouseService.start()
	PlotService.PlotAssigned:Connect(HouseService.refresh)
	Players.PlayerRemoving:Connect(function(player)
		local house = houses[player]
		houses[player] = nil
		if house then
			house:Destroy()
		end
	end)
end

return HouseService
