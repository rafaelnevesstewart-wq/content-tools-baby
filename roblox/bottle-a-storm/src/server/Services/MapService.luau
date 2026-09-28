-- Map rotation (see MapData): when a match starts, the sky islands get a new
-- look (ground, cliffs, props and a color wash) that's different from the
-- last match. When everyone goes back to the lobby, the Meadow comes back.

local Lighting = game:GetService("Lighting")
local ServerStorage = game:GetService("ServerStorage")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local MapData = require(Shared.MapData)

local Modules = script.Parent.Parent.Modules
local Notify = require(Modules.Notify)
local WorldBuilder = require(Modules.WorldBuilder)

local MapService = {}

local rng = Random.new()
local lastKey = "Meadow"
local props: Folder? = nil
local hiddenDecor: { [Instance]: Instance } = {} -- decor folder -> its island

local function piece(parent: Instance, props_: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props_ do
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

local function paint(island: Instance, map: MapData.Map?)
	for _, child in island:GetChildren() do
		if child:IsA("BasePart") then
			if child:GetAttribute("MapColor") == nil then
				child:SetAttribute("MapColor", child.Color)
				child:SetAttribute("MapMaterial", child.Material.Name)
			end
			local color, material
			if map and child.Name == "Ground" then
				color, material = map.ground, map.groundMaterial
			elseif map and child.Name == "Rim" then
				color, material = map.rim, map.rimMaterial
			elseif map and string.sub(child.Name, 1, 9) == "Underside" then
				color, material = map.rock, map.rockMaterial
			end
			child.Color = color or child:GetAttribute("MapColor")
			child.Material = material or (Enum.Material :: any)[child:GetAttribute("MapMaterial")]
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
	local map = options[rng:NextInteger(1, #options)]
	lastKey = map.key
	workspace:SetAttribute("MapTheme", map.key)
	local world = workspace:FindFirstChild("World")
	local middle = world and world:FindFirstChild("WildSkies")
	if middle then
		paint(middle, map)
	end
	for _, info in islands do
		paint(info.model, map)
	end
	tint(map.tint)
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
	local world = workspace:FindFirstChild("World")
	if world then
		for _, island in world:GetDescendants() do
			if island:IsA("Model") and island:FindFirstChild("Ground") then
				paint(island, nil)
			end
		end
	end
	tint(nil)
	workspace:SetAttribute("MapTheme", "Meadow")
end

function MapService.init()
	workspace:SetAttribute("MapTheme", "Meadow")
end

return MapService
