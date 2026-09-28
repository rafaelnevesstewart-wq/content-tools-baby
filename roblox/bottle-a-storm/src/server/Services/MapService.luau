-- Map rotation (see MapData): when a match starts, the sky islands get the
-- map voted in the lobby (🗳️ Vote), or else a random one different from the
-- last match: the terrain's ground and cliffs, props and a color wash. When
-- everyone goes back to the lobby, the Meadow comes back.

local Lighting = game:GetService("Lighting")
local ServerStorage = game:GetService("ServerStorage")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local MapData = require(Shared.MapData)

local Modules = script.Parent.Parent.Modules
local Notify = require(Modules.Notify)
local WorldBuilder = require(Modules.WorldBuilder)

local VoteService = require(script.Parent.VoteService)

local MapService = {}

local rng = Random.new()
local lastKey = "Meadow"
local current: MapData.Map? = nil
local props: Folder? = nil
local hiddenDecor: { [Instance]: Instance } = {} -- decor folder -> its island

local function piece(parent: Instance, settings: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in settings do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

local function glow(p: BasePart, color: Color3, range: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = 1.4
	light.Parent = p
end

-- One prop standing at `at` (on the ground, random turn).
local PROPS: { [string]: (Instance, CFrame) -> () } = {
	volcano = function(parent, at)
		if rng:NextNumber() < 0.5 then
			-- A bubbling lava pool.
			local pool = piece(parent, {
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.3, rng:NextNumber(5, 9), rng:NextNumber(5, 9)),
				CFrame = at * CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)),
				Color = Color3.fromRGB(255, 110, 30),
				Material = Enum.Material.Neon,
				CanCollide = false,
			})
			glow(pool, Color3.fromRGB(255, 120, 40), 14)
		else
			-- A smoking obsidian spike.
			local height = rng:NextNumber(5, 10)
			local spike = piece(parent, {
				Size = Vector3.new(2, height, 2),
				CFrame = at * CFrame.new(0, height / 2, 0) * CFrame.Angles(math.rad(rng:NextNumber(-8, 8)), 0, 0),
				Color = Color3.fromRGB(30, 22, 34),
				Material = Enum.Material.Basalt,
			})
			local smoke = Instance.new("Smoke")
			smoke.Color = Color3.fromRGB(80, 70, 70)
			smoke.Size = 2
			smoke.RiseVelocity = 3
			smoke.Parent = spike
		end
	end,
	ice = function(parent, at)
		local height = rng:NextNumber(4, 9)
		for i = 0, 2 do
			piece(parent, {
				Size = Vector3.new(1.2, height * (1 - i * 0.25), 1.2),
				CFrame = at
					* CFrame.Angles(0, i * 2.1, 0)
					* CFrame.new(i * 0.9, height * (1 - i * 0.25) / 2, 0)
					* CFrame.Angles(0, 0, math.rad(i * 12)),
				Color = Color3.fromRGB(180, 225, 255),
				Material = Enum.Material.Ice,
				Transparency = 0.2,
			})
		end
	end,
	candy = function(parent, at)
		if rng:NextNumber() < 0.5 then
			-- A striped candy cane.
			for i = 0, 5 do
				piece(parent, {
					Shape = Enum.PartType.Cylinder,
					Size = Vector3.new(1.2, 1, 1),
					CFrame = at * CFrame.new(0, 0.6 + i * 1.2, 0) * CFrame.Angles(0, 0, math.rad(90)),
					Color = if i % 2 == 0 then Color3.fromRGB(230, 40, 60) else Color3.new(1, 1, 1),
					Material = Enum.Material.SmoothPlastic,
				})
			end
		else
			-- A lollipop.
			piece(parent, {
				Size = Vector3.new(0.4, 6, 0.4),
				CFrame = at * CFrame.new(0, 3, 0),
				Color = Color3.new(1, 1, 1),
				Material = Enum.Material.SmoothPlastic,
			})
			piece(parent, {
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.6, 4, 4),
				CFrame = at * CFrame.new(0, 7.5, 0),
				Color = Color3.fromHSV(rng:NextNumber(), 0.55, 1),
				Material = Enum.Material.SmoothPlastic,
			})
		end
	end,
	desert = function(parent, at)
		local roll = rng:NextNumber()
		if roll < 0.55 then
			-- A saguaro cactus with two arms.
			local green = Color3.fromRGB(78, 128, 62)
			local height = rng:NextNumber(5, 8)
			local function limb(size: Vector3, cframe: CFrame)
				local p = piece(parent, {
					Size = size,
					CFrame = cframe,
					Color = green,
					Material = Enum.Material.Grass,
				})
				local mesh = Instance.new("SpecialMesh")
				mesh.MeshType = Enum.MeshType.Cylinder
				mesh.Parent = p
			end
			limb(Vector3.new(height, 1.4, 1.4), at * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90)))
			for _, side in { -1, 1 } do
				local y = height * rng:NextNumber(0.4, 0.6)
				limb(Vector3.new(1.4, 0.9, 0.9), at * CFrame.new(side * 1, y, 0))
				limb(
					Vector3.new(2.2, 0.9, 0.9),
					at * CFrame.new(side * 1.6, y + 1.1, 0) * CFrame.Angles(0, 0, math.rad(90))
				)
			end
		elseif roll < 0.85 then
			-- A wind-worn sandstone pillar.
			local height = rng:NextNumber(4, 9)
			for i = 0, 2 do
				local width = rng:NextNumber(2.2, 3.4) * (1 - i * 0.15)
				piece(parent, {
					Size = Vector3.new(width, height / 3, width * 0.9),
					CFrame = at
						* CFrame.new(rng:NextNumber(-0.3, 0.3), height / 6 + i * height / 3, 0)
						* CFrame.Angles(0, rng:NextNumber(0, 1), 0),
					Color = Color3.fromRGB(206, 160, 108):Lerp(Color3.fromRGB(170, 120, 80), i / 3),
					Material = Enum.Material.Sandstone,
				})
			end
		else
			-- A dry tumbleweed bush.
			local bush = piece(parent, {
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * rng:NextNumber(2, 3),
				CFrame = at * CFrame.new(0, 1, 0),
				Color = Color3.fromRGB(150, 118, 70),
				Material = Enum.Material.Fabric,
				Transparency = 0.2,
				CanCollide = false,
			})
			bush.CastShadow = false
		end
	end,
	haunted = function(parent, at)
		local roll = rng:NextNumber()
		if roll < 0.4 then
			-- A tilted gravestone.
			local stone = Color3.fromRGB(110, 108, 116)
			local lean = at * CFrame.Angles(math.rad(rng:NextNumber(-10, 10)), 0, math.rad(rng:NextNumber(-8, 8)))
			piece(parent, {
				Size = Vector3.new(2.4, 3.2, 0.6),
				CFrame = lean * CFrame.new(0, 1.6, 0),
				Color = stone,
				Material = Enum.Material.Slate,
			})
			local top = piece(parent, {
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.6, 2.4, 2.4),
				CFrame = lean * CFrame.new(0, 3.2, 0) * CFrame.Angles(0, math.rad(90), 0),
				Color = stone,
				Material = Enum.Material.Slate,
			})
			top.CanCollide = false
			piece(parent, {
				Size = Vector3.new(2.6, 0.3, 3.6),
				CFrame = at * CFrame.new(0, 0.15, -2),
				Color = Color3.fromRGB(58, 50, 44),
				Material = Enum.Material.Mud,
				CanCollide = false,
			})
		elseif roll < 0.7 then
			-- A bare, twisted dead tree.
			local bark = Color3.fromRGB(44, 38, 36)
			local height = rng:NextNumber(6, 10)
			piece(parent, {
				Size = Vector3.new(1, height, 1),
				CFrame = at * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-6, 6))),
				Color = bark,
				Material = Enum.Material.Wood,
			})
			for i = 1, 4 do
				local length = rng:NextNumber(2.5, 4)
				piece(parent, {
					Size = Vector3.new(0.4, 0.4, length),
					CFrame = at
						* CFrame.new(0, height * rng:NextNumber(0.55, 0.95), 0)
						* CFrame.Angles(0, i * 1.6, 0)
						* CFrame.Angles(math.rad(-35), 0, 0)
						* CFrame.new(0, 0, -length / 2),
					Color = bark,
					Material = Enum.Material.Wood,
					CanCollide = false,
				})
			end
		elseif roll < 0.9 then
			-- A glowing jack-o'-lantern.
			local pumpkin = piece(parent, {
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(2.4, 2, 2.4),
				CFrame = at * CFrame.new(0, 1, 0),
				Color = Color3.fromRGB(230, 120, 30),
				Material = Enum.Material.SmoothPlastic,
			})
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Scale = Vector3.new(1, 0.85, 1)
			mesh.Parent = pumpkin
			piece(parent, {
				Size = Vector3.new(0.3, 0.6, 0.3),
				CFrame = at * CFrame.new(0, 2.1, 0),
				Color = Color3.fromRGB(70, 90, 40),
				Material = Enum.Material.Wood,
				CanCollide = false,
			})
			for _, x in { -0.45, 0.45 } do
				piece(parent, {
					Size = Vector3.new(0.4, 0.4, 0.1),
					CFrame = at * CFrame.new(x, 1.3, -1.12) * CFrame.Angles(0, 0, math.rad(45)),
					Color = Color3.fromRGB(255, 220, 90),
					Material = Enum.Material.Neon,
					CanCollide = false,
				})
			end
			glow(pumpkin, Color3.fromRGB(255, 150, 50), 12)
		else
			-- A ghostly wisp drifting over the ground.
			local wisp = piece(parent, {
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 0.8,
				CFrame = at * CFrame.new(0, rng:NextNumber(3, 6), 0),
				Color = Color3.fromRGB(200, 230, 255),
				Material = Enum.Material.Neon,
				Transparency = 0.3,
				CanCollide = false,
				CanQuery = false,
			})
			glow(wisp, Color3.fromRGB(170, 210, 255), 10)
			local trail = Instance.new("ParticleEmitter")
			trail.Texture = "rbxasset://textures/particles/smoke_main.dds"
			trail.Color = ColorSequence.new(Color3.fromRGB(210, 230, 255))
			trail.Size = NumberSequence.new(1.2, 3)
			trail.Transparency = NumberSequence.new(0.6, 1)
			trail.Lifetime = NumberRange.new(1.5, 2.5)
			trail.Rate = 6
			trail.Speed = NumberRange.new(0.3, 0.8)
			trail.LightEmission = 0.6
			trail.Parent = wisp
		end
	end,
	city = function(parent, at)
		local roll = rng:NextNumber()
		if roll < 0.45 then
			-- A little tower block with glowing windows and a rooftop rim.
			local width = rng:NextNumber(5, 7)
			local height = rng:NextNumber(8, 14)
			local wall = Color3.fromRGB(150, 156, 170):Lerp(Color3.fromRGB(190, 170, 150), rng:NextNumber())
			local building = piece(parent, {
				Size = Vector3.new(width, height, width),
				CFrame = at * CFrame.new(0, height / 2, 0),
				Color = wall,
				Material = Enum.Material.Concrete,
			})
			piece(parent, {
				Size = Vector3.new(width + 0.4, 0.5, width + 0.4),
				CFrame = building.CFrame * CFrame.new(0, height / 2 + 0.25, 0),
				Color = Color3.fromRGB(80, 84, 96),
				Material = Enum.Material.Metal,
			})
			for floor = 1, math.floor(height / 3) - 1 do
				for _, face in { 0, 1, 2, 3 } do
					for column = -1, 1, 2 do
						piece(parent, {
							Size = Vector3.new(1, 1.2, 0.1),
							CFrame = building.CFrame
								* CFrame.Angles(0, face * math.pi / 2, 0)
								* CFrame.new(column * width * 0.22, -height / 2 + floor * 3, -width / 2 - 0.05),
							Color = if rng:NextNumber() < 0.6
								then Color3.fromRGB(255, 226, 150)
								else Color3.fromRGB(70, 90, 120),
							Material = Enum.Material.Neon,
							CanCollide = false,
						})
					end
				end
			end
		elseif roll < 0.8 then
			-- A street lamp.
			local metal = Color3.fromRGB(50, 54, 60)
			piece(parent, {
				Size = Vector3.new(0.4, 8, 0.4),
				CFrame = at * CFrame.new(0, 4, 0),
				Color = metal,
				Material = Enum.Material.Metal,
			})
			piece(parent, {
				Size = Vector3.new(0.3, 0.3, 2),
				CFrame = at * CFrame.new(0, 7.9, -0.9),
				Color = metal,
				Material = Enum.Material.Metal,
			})
			local lamp = piece(parent, {
				Size = Vector3.new(0.9, 0.5, 0.9),
				CFrame = at * CFrame.new(0, 7.5, -1.8),
				Color = Color3.fromRGB(255, 236, 180),
				Material = Enum.Material.Neon,
				CanCollide = false,
			})
			glow(lamp, Color3.fromRGB(255, 220, 160), 16)
		else
			-- A rooftop billboard on legs.
			local legs = Color3.fromRGB(60, 64, 72)
			for _, x in { -2.5, 2.5 } do
				piece(parent, {
					Size = Vector3.new(0.4, 5, 0.4),
					CFrame = at * CFrame.new(x, 2.5, 0),
					Color = legs,
					Material = Enum.Material.Metal,
				})
			end
			local board = piece(parent, {
				Size = Vector3.new(7, 3.2, 0.3),
				CFrame = at * CFrame.new(0, 6.4, 0),
				Color = Color3.fromHSV(rng:NextNumber(), 0.55, 0.95),
				Material = Enum.Material.Neon,
			})
			glow(board, board.Color, 12)
		end
	end,
	space = function(parent, at)
		local height = rng:NextNumber(3, 7)
		local crystal = piece(parent, {
			Size = Vector3.new(1.4, height, 1.4),
			CFrame = at
				* CFrame.new(0, height / 2, 0)
				* CFrame.Angles(0, math.rad(45), math.rad(rng:NextNumber(-15, 15))),
			Color = Color3.fromHSV(rng:NextNumber(0.55, 0.85), 0.6, 1),
			Material = Enum.Material.Neon,
			Transparency = 0.15,
		})
		glow(crystal, crystal.Color, 10)
		-- A little asteroid floating above.
		piece(parent, {
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * rng:NextNumber(1.5, 3),
			CFrame = at * CFrame.new(rng:NextNumber(-3, 3), height + rng:NextNumber(6, 12), rng:NextNumber(-3, 3)),
			Color = Color3.fromRGB(90, 88, 100),
			Material = Enum.Material.Slate,
			CanCollide = false,
		})
	end,
}

-- The whole sky world, for swapping terrain materials (a little bigger than
-- the islands, lined up with the 4-stud terrain grid).
local function worldRegion(): Region3
	local reach = Config.World.PlotRingDistance + Config.World.PlotRadius + 16
	return Region3.new(Vector3.new(-reach, -48, -reach), Vector3.new(reach, 8, reach)):ExpandToGrid(4)
end

local originalColors: { [Enum.Material]: Color3 } = {}

-- Turns the islands' grass and dirt into the map's materials (or back).
local function paint(map: MapData.Map, forward: boolean)
	local terrain = workspace.Terrain
	local region = worldRegion()
	if map.grass then
		terrain:ReplaceMaterial(
			region,
			4,
			if forward then Enum.Material.Grass else map.grass,
			if forward then map.grass else Enum.Material.Grass
		)
	end
	if map.dirt then
		terrain:ReplaceMaterial(
			region,
			4,
			if forward then Enum.Material.Ground else map.dirt,
			if forward then map.dirt else Enum.Material.Ground
		)
	end
	local colors: { [Enum.Material]: Color3 } = map.colors or {}
	for material, color in colors do
		if forward then
			originalColors[material] = originalColors[material] or terrain:GetMaterialColor(material)
			terrain:SetMaterialColor(material, color)
		elseif originalColors[material] then
			terrain:SetMaterialColor(material, originalColors[material])
		end
	end
end

local function scatter(parent: Instance, frame: CFrame, radius: number, count: number, kind: string, middle: boolean)
	local build = PROPS[kind]
	local placed, tries = 0, 0
	while placed < count and tries < count * 20 do
		tries += 1
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(radius * 0.35, radius - 6)
		local spot = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		local blocked = if middle then WorldBuilder.isWildBlocked(spot) else WorldBuilder.isPlotBlocked(spot)
		if not blocked then
			placed += 1
			build(parent, frame * CFrame.new(spot) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
		end
	end
end

local function tint(color: Color3?)
	local effect = Lighting:FindFirstChild("MapTint") :: ColorCorrectionEffect?
	if not effect then
		local new = Instance.new("ColorCorrectionEffect")
		new.Name = "MapTint"
		new.Parent = Lighting
		effect = new
	end
	(effect :: ColorCorrectionEffect).TintColor = color or Color3.new(1, 1, 1)
end

-- Picks the next map (never the same twice in a row) and dresses the
-- islands. `islands` are the team islands from WorldBuilder.
function MapService.apply(islands: { WorldBuilder.PlotInfo })
	local options = {}
	for _, map in MapData.List do
		if map.key ~= lastKey then
			table.insert(options, map)
		end
	end
	-- The map with the most votes in the lobby, or a random new one.
	local voted = MapData.get(VoteService.winner("map"))
	-- Zombie Survival is spooky unless someone voted for a map.
	if not voted and workspace:GetAttribute("MatchMode") == "Zombies" then
		voted = MapData.get("Haunted")
	end
	local map = voted or options[rng:NextInteger(1, #options)]
	lastKey = map.key
	current = map
	workspace:SetAttribute("MapTheme", map.key)
	local world = workspace:FindFirstChild("World")
	local middle = world and world:FindFirstChild("WildSkies")
	paint(map, true)
	tint(map.tint)
	if map.clock then
		-- The day and night cycle (WeatherService) holds this time of day.
		workspace:SetAttribute("FixedClock", map.clock)
	end
	if map.props then
		local folder = Instance.new("Folder")
		folder.Name = "MapProps"
		-- The islands' usual trees and flowers step aside for the theme.
		for _, info in islands do
			local decor = info.model:FindFirstChild("Decor")
			if decor then
				hiddenDecor[decor] = info.model
				decor.Parent = ServerStorage
			end
			scatter(folder, info.cframe, Config.World.PlotRadius, 10, map.props, false)
		end
		if middle then
			local decor = middle:FindFirstChild("Decor")
			if decor then
				hiddenDecor[decor] = middle
				decor.Parent = ServerStorage
			end
			scatter(folder, CFrame.new(), Config.World.CenterRadius, 30, map.props, true)
		end
		folder.Parent = workspace
		props = folder
	end
	Notify.all("🗺️ This match's map: " .. map.emoji .. " " .. map.name .. "!", "info")
end

-- Back to the Meadow for the lobby.
function MapService.reset()
	if props then
		props:Destroy()
		props = nil
	end
	for decor, island in hiddenDecor do
		decor.Parent = island
	end
	hiddenDecor = {}
	if current then
		paint(current, false)
		current = nil
	end
	tint(nil)
	workspace:SetAttribute("FixedClock", nil)
	workspace:SetAttribute("MapTheme", "Meadow")
end

function MapService.init()
	workspace:SetAttribute("MapTheme", "Meadow")
end

return MapService
