-- 🏗️ Base Island (west of the castle, over a bridge): 8 building plots.
-- Claim a free plot at its sign and you get the 🔨 Builder: place and remove
-- blocks (BaseData.Blocks, free and unlimited up to BaseData.MaxBlocks) on
-- your plot's 10 x 10 x 10 grid. Your base is saved with your profile and
-- comes back whenever you claim a plot again. Anyone can visit.
--
-- 🏆 Behind every claimed plot is its owner's Trophy Room: a wall of shelves
-- with a golden cup and a plaque for every achievement they've earned
-- (ProgressionData.Achievements).

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local BaseData = require(Shared.BaseData)
local ProgressionData = require(Shared.ProgressionData)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent.Parent.Modules
local Effects = require(Modules.Effects)
local FurnitureModels = require(Modules.FurnitureModels)
local Juice = require(Modules.Juice)
local Notify = require(Modules.Notify)

local DataService = require(script.Parent.DataService)

local BaseService = {}

type Plot = {
	index: number,
	owner: Player?,
	folder: Folder,
	signText: TextLabel,
	cells: { [string]: BasePart }, -- "i,j,k" -> block
	trophies: Folder,
	wall: CFrame, -- the trophy wall's middle, at the ground, facing the plot
	trophyCount: number, -- achievements shown (-1 = empty wall)
}

local plotOf: { [Player]: Plot } = {}
local lastEdit: { [Player]: number } = {}
local root: Folder

local function cellKey(i: number, j: number, k: number): string
	return i .. "," .. j .. "," .. k
end

-- 🏠 Furniture: an invisible cell-sized root with the model's pieces inside
-- it (so removing the root removes it all). Every piece knows its cell.
local function makeFurniture(plot: Plot, i: number, j: number, k: number, key: string, turn: number): BasePart?
	if not BaseData.furniture(key) then
		return nil
	end
	local cell = CFrame.new(BaseData.cellPosition(plot.index, i, j, k)) * CFrame.Angles(0, turn * math.pi / 2, 0)
	local holder = Instance.new("Part")
	holder.Name = "BaseFurniture"
	holder.Anchored = true
	holder.CanCollide = false
	holder.Transparency = 1
	holder.Size = Vector3.one * (BaseData.CellSize - 0.1)
	holder.CFrame = cell
	FurnitureModels.build(holder, key, cell)
	for _, part in holder:GetDescendants() do
		if part:IsA("BasePart") then
			part:SetAttribute("Cell", cellKey(i, j, k))
		end
	end
	holder:SetAttribute("Cell", cellKey(i, j, k))
	holder:SetAttribute("Turn", turn)
	-- 🚪 A door is two cells tall: it keeps the cell above it for itself.
	local above = cellKey(i, j, k + 1)
	if key == "Door" and BaseData.inside(i, j, k + 1) and not plot.cells[above] then
		local top = Instance.new("Part")
		top.Name = "DoorTop"
		top.Anchored = true
		top.CanCollide = false
		top.Transparency = 1
		top.Size = Vector3.one * (BaseData.CellSize - 0.1)
		top.CFrame = cell * CFrame.new(0, BaseData.CellSize, 0)
		top:SetAttribute("Cell", above)
		top:SetAttribute("DoorOf", cellKey(i, j, k))
		top.Parent = holder
		plot.cells[above] = top
		holder:SetAttribute("Top", above)
	end
	holder.Parent = plot.folder
	plot.cells[cellKey(i, j, k)] = holder
	return holder
end

local function makeBlock(plot: Plot, i: number, j: number, k: number, key: string, turn: number?): BasePart?
	if BaseData.furniture(key) then
		return makeFurniture(plot, i, j, k, key, turn or 0)
	end
	local block = BaseData.block(key)
	if not block then
		return nil
	end
	local part = Instance.new("Part")
	part.Name = "BaseBlock"
	part.Anchored = true
	part.Size = Vector3.one * BaseData.CellSize
	part.CFrame = CFrame.new(BaseData.cellPosition(plot.index, i, j, k))
	part.Material = block.material
	part.Color = block.color
	part.Transparency = block.transparency or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part:SetAttribute("Cell", cellKey(i, j, k))
	if key == "Neon" then
		local light = Instance.new("PointLight")
		light.Color = block.color
		light.Range = 8
		light.Parent = part
	end
	part.Parent = plot.folder
	plot.cells[cellKey(i, j, k)] = part
	return part
end

local function clearPlot(plot: Plot)
	for _, part in plot.cells do
		part:Destroy()
	end
	plot.cells = {}
end

---------------------------------------------------------------------------
-- 🏆 Trophy rooms
---------------------------------------------------------------------------

local SHELVES = 3
local PER_SHELF = 11
local WALL_WIDTH = 28

local function trophyPart(parent: Instance, props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = parent
	return part
end

local function surfaceText(part: BasePart, text: string, canvas: Vector2, color: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = canvas
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = text
	label.Parent = gui
end

-- A golden cup on a dark stand.
local function cup(parent: Instance, at: CFrame)
	trophyPart(parent, {
		Size = Vector3.new(0.8, 0.3, 0.8),
		CFrame = at * CFrame.new(0, 0.15, 0),
		Color = Color3.fromRGB(50, 40, 36),
		Material = Enum.Material.Marble,
	})
	local gold = Color3.fromRGB(240, 196, 70)
	trophyPart(parent, {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.5, 0.2, 0.2),
		CFrame = at * CFrame.new(0, 0.55, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = gold,
		Material = Enum.Material.Foil,
	})
	trophyPart(parent, {
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 0.9,
		CFrame = at * CFrame.new(0, 1.1, 0),
		Color = gold,
		Material = Enum.Material.Foil,
	})
	for _, side in { -1, 1 } do
		trophyPart(parent, {
			Size = Vector3.new(0.15, 0.45, 0.15),
			CFrame = at * CFrame.new(side * 0.55, 1.15, 0),
			Color = gold,
			Material = Enum.Material.Foil,
		})
	end
end

-- Rebuilds the plot's trophy wall for `player` (or clears it for nil).
local function refreshTrophies(plot: Plot, player: Player?)
	local data = if player then DataService.get(player) else nil
	local earned = {}
	if data then
		for _, achievement in ProgressionData.Achievements do
			if data.achievements[achievement.id] then
				table.insert(earned, achievement)
			end
		end
	end
	local count = if player then #earned else -1
	if count == plot.trophyCount then
		return
	end
	plot.trophyCount = count
	plot.trophies:ClearAllChildren()
	if not player then
		return
	end
	local wall = plot.wall
	local height = SHELVES * 2.4 + 1
	local brown = Color3.fromRGB(96, 64, 40)
	trophyPart(plot.trophies, {
		Name = "TrophyWall",
		CanCollide = true,
		Size = Vector3.new(WALL_WIDTH, height, 0.6),
		CFrame = wall * CFrame.new(0, height / 2, 0),
		Color = brown,
		Material = Enum.Material.WoodPlanks,
	})
	local header = trophyPart(plot.trophies, {
		Size = Vector3.new(14, 1.8, 0.3),
		CFrame = wall * CFrame.new(0, height + 0.9, -0.1),
		Color = Color3.fromRGB(60, 40, 30),
		Material = Enum.Material.Wood,
	})
	surfaceText(
		header,
		"🏆 " .. player.DisplayName .. "'s Trophy Room  " .. #earned .. "/" .. #ProgressionData.Achievements,
		Vector2.new(560, 72),
		Color3.fromRGB(255, 220, 120)
	)
	for shelf = 1, SHELVES do
		local y = (shelf - 1) * 2.4 + 0.4
		trophyPart(plot.trophies, {
			Size = Vector3.new(WALL_WIDTH - 0.4, 0.3, 1.6),
			CFrame = wall * CFrame.new(0, y, -1.1),
			Color = brown:Lerp(Color3.new(1, 1, 1), 0.15),
			Material = Enum.Material.WoodPlanks,
		})
	end
	local spacing = (WALL_WIDTH - 1) / PER_SHELF
	for index, achievement in earned do
		if index > SHELVES * PER_SHELF then
			break
		end
		local shelf = (index - 1) // PER_SHELF
		local slot = (index - 1) % PER_SHELF
		local x = (slot - (PER_SHELF - 1) / 2) * spacing
		local y = shelf * 2.4 + 0.55
		cup(plot.trophies, wall * CFrame.new(x, y, -1.2))
		local plaque = trophyPart(plot.trophies, {
			Size = Vector3.new(spacing - 0.2, 0.55, 0.1),
			CFrame = wall * CFrame.new(x, y - 0.35, -1.95),
			Color = Color3.fromRGB(40, 30, 24),
			Material = Enum.Material.SmoothPlastic,
		})
		surfaceText(plaque, achievement.emoji .. " " .. achievement.name, Vector2.new(200, 44), Color3.new(1, 1, 1))
	end
end

local function saveList(plot: Plot): { string }
	local list = {}
	for key, part in plot.cells do
		local block = part:GetAttribute("Block")
		local turn = part:GetAttribute("Turn")
		if type(block) == "string" then
			local extra = if type(turn) == "number" and turn > 0 then "," .. turn else ""
			table.insert(list, key .. "," .. block .. extra)
		end
	end
	return list
end

local function giveBuilder(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack or backpack:FindFirstChild("Builder") then
		return
	end
	local character = player.Character
	if character and character:FindFirstChild("Builder") then
		return
	end
	local tool = Instance.new("Tool")
	tool.Name = "Builder"
	tool.ToolTip = "Build your base (pick blocks at the bottom of the screen)"
	tool.CanBeDropped = false
	tool.Grip = CFrame.new(0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 1, 0)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.3, 0.3, 1.6)
	handle.Color = Color3.fromRGB(110, 78, 50)
	handle.Material = Enum.Material.Wood
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	local head = Instance.new("Part")
	head.Name = "HammerHead"
	head.Size = Vector3.new(0.5, 0.5, 1.1)
	head.Color = Color3.fromRGB(150, 150, 158)
	head.Material = Enum.Material.Metal
	head.CanCollide = false
	head.Massless = true
	head.CFrame = handle.CFrame * CFrame.new(0, 0, 0.8) * CFrame.Angles(0, math.rad(90), 0)
	head.Parent = tool
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = head
	weld.Parent = head
	tool.Parent = backpack
end

local function removeBuilder(player: Player)
	for _, container in { player.Character, player:FindFirstChildOfClass("Backpack") } do
		local tool = container and container:FindFirstChild("Builder")
		if tool then
			tool:Destroy()
		end
	end
end

local function release(player: Player)
	local plot = plotOf[player]
	if not plot then
		return
	end
	plotOf[player] = nil
	plot.owner = nil
	clearPlot(plot)
	plot.signText.Text = "🏗️ Free plot\n(claim it here!)"
	refreshTrophies(plot, nil)
	player:SetAttribute("BasePlot", nil)
	removeBuilder(player)
end

local function claim(player: Player, plot: Plot)
	local data = DataService.get(player)
	if not data then
		return
	end
	if plot.owner then
		if plot.owner ~= player then
			Notify.player(player, "🏗️ That's " .. plot.owner.DisplayName .. "'s plot. Find a free one!", "error")
		end
		return
	end
	release(player)
	plot.owner = player
	plotOf[player] = plot
	plot.signText.Text = "🏗️ " .. player.DisplayName .. "'s base"
	player:SetAttribute("BasePlot", plot.index)
	-- Bring back the saved base.
	for _, entry in data.base.blocks do
		local i, j, k, key, turn = string.match(entry, "^(%-?%d+),(%-?%d+),(%-?%d+),(%w+),?(%d?)$")
		local ci, cj, ck = tonumber(i), tonumber(j), tonumber(k)
		if ci and cj and ck and key and BaseData.inside(ci, cj, ck) then
			local part = makeBlock(plot, ci, cj, ck, key, tonumber(turn) or 0)
			if part then
				part:SetAttribute("Block", key)
			end
		end
	end
	giveBuilder(player)
	refreshTrophies(plot, player)
	Notify.player(
		player,
		"🏗️ This plot is yours! Hold the 🔨 Builder and click to build. It saves by itself.",
		"success"
	)
end

local function onEdit(player: Player, action: any, i: any, j: any, k: any, key: any, turn: any)
	local plot = plotOf[player]
	local data = DataService.get(player)
	if not plot or not data or type(i) ~= "number" or type(j) ~= "number" or type(k) ~= "number" then
		return
	end
	if os.clock() - (lastEdit[player] or 0) < 0.08 then
		return
	end
	lastEdit[player] = os.clock()
	i, j, k = math.floor(i), math.floor(j), math.floor(k)
	if not BaseData.inside(i, j, k) then
		return
	end
	local id = cellKey(i, j, k)
	if action == "place" then
		if plot.cells[id] or type(key) ~= "string" or not (BaseData.block(key) or BaseData.furniture(key)) then
			return
		end
		if key == "Door" and (not BaseData.inside(i, j, k + 1) or plot.cells[cellKey(i, j, k + 1)]) then
			Notify.player(player, "🚪 A door needs two empty cells, one on top of the other.", "error")
			return
		end
		local count = 0
		for _ in plot.cells do
			count += 1
		end
		if count >= BaseData.MaxBlocks then
			Notify.player(player, "🏗️ Your base is full (" .. BaseData.MaxBlocks .. " blocks)!", "error")
			return
		end
		local quarter = if type(turn) == "number" then math.floor(turn) % 4 else 0
		local part = makeBlock(plot, i, j, k, key, quarter)
		if part then
			part:SetAttribute("Block", key)
			Juice.sound(player, "pop")
		end
	elseif action == "remove" then
		local part = plot.cells[id]
		-- The top half of a door removes the whole door.
		local doorOf = part and part:GetAttribute("DoorOf")
		if type(doorOf) == "string" and plot.cells[doorOf] then
			id = doorOf
			part = plot.cells[doorOf]
		end
		if part then
			local top = part:GetAttribute("Top")
			if type(top) == "string" then
				plot.cells[top] = nil
			end
			Effects.confetti(part.Position, 6)
			part:Destroy()
			plot.cells[id] = nil
			Juice.sound(player, "click")
		end
	elseif action == "clear" then
		clearPlot(plot)
	else
		return
	end
	data.base.blocks = saveList(plot)
end

local function buildPlots()
	root = Instance.new("Folder")
	root.Name = "Bases"
	root.Parent = workspace
	local size = BaseData.Cells * BaseData.CellSize
	for index = 1, BaseData.Plots do
		local center = BaseData.plotCenter(index)
		local folder = Instance.new("Folder")
		folder.Name = "Plot" .. index
		folder.Parent = root
		local floor = Instance.new("Part")
		floor.Name = "PlotFloor"
		floor.Anchored = true
		floor.Size = Vector3.new(size, 0.4, size)
		floor.CFrame = CFrame.new(center - Vector3.new(0, 0.2, 0))
		floor.Color = Color3.fromRGB(196, 190, 176)
		floor.Material = Enum.Material.Concrete
		floor.Parent = root
		-- A low border around the plot.
		for _, side in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
			local border = Instance.new("Part")
			border.Anchored = true
			border.CanCollide = false
			border.Size = if side.X ~= 0 then Vector3.new(0.4, 0.5, size + 0.4) else Vector3.new(size + 0.4, 0.5, 0.4)
			border.CFrame = CFrame.new(center + side * (size / 2) + Vector3.new(0, 0.05, 0))
			border.Color = Color3.fromRGB(120, 190, 255)
			border.Material = Enum.Material.Neon
			border.Transparency = 0.3
			border.Parent = root
		end
		-- The sign at the plot's front edge (toward the island's middle row).
		local front = if center.Z > BaseData.Center.Z then -1 else 1
		local signPos = center + Vector3.new(0, 0, front * (size / 2 + 2))
		local sign = Instance.new("Part")
		sign.Name = "PlotSign"
		sign.Anchored = true
		sign.Size = Vector3.new(6, 3, 0.4)
		sign.CFrame = CFrame.lookAt(signPos + Vector3.new(0, 2.5, 0), signPos + Vector3.new(0, 2.5, front))
		sign.Color = Color3.fromRGB(110, 78, 50)
		sign.Material = Enum.Material.WoodPlanks
		sign.Parent = root
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.CanvasSize = Vector2.new(300, 150)
		gui.Parent = sign
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, 1)
		text.Font = Enum.Font.GothamBold
		text.TextScaled = true
		text.TextColor3 = Color3.fromRGB(255, 240, 210)
		text.Text = "🏗️ Free plot\n(claim it here!)"
		text.Parent = gui
		local trophies = Instance.new("Folder")
		trophies.Name = "Trophies"
		trophies.Parent = folder
		local wallAt = center + Vector3.new(0, 0, -front * (size / 2 + 1.2))
		local plot: Plot = {
			index = index,
			owner = nil,
			folder = folder,
			signText = text,
			cells = {},
			trophies = trophies,
			wall = CFrame.lookAt(wallAt, wallAt + Vector3.new(0, 0, front)),
			trophyCount = -1,
		}
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Claim / Build"
		prompt.ObjectText = "🏗️ Plot " .. index
		prompt.HoldDuration = 0.4
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = sign
		prompt.Triggered:Connect(function(player)
			claim(player, plot)
		end)
	end
end

-- Everyone with a claimed plot: their plot number and how many blocks it has
-- (the 🎨 build contest uses this).
function BaseService.entries(): { { player: Player, plot: number, blocks: number } }
	local list = {}
	for player, plot in plotOf do
		local count = 0
		for _ in plot.cells do
			count += 1
		end
		table.insert(list, { player = player, plot = plot.index, blocks = count })
	end
	return list
end

-- Where a visitor stands to look at a plot: out front, facing it.
function BaseService.visitFrame(index: number): CFrame
	local center = BaseData.plotCenter(index)
	local front = if center.Z > BaseData.Center.Z then -1 else 1
	local size = BaseData.Cells * BaseData.CellSize
	local spot = center + Vector3.new(4, 3, front * (size / 2 + 5))
	return CFrame.lookAt(spot, Vector3.new(center.X, spot.Y, center.Z))
end

function BaseService.start()
	buildPlots()
	Remotes.event("BaseEdit").OnServerEvent:Connect(onEdit)
	Players.PlayerRemoving:Connect(function(player)
		release(player)
		lastEdit[player] = nil
	end)
	-- The Builder is for your plot: it goes away when you leave Base Island
	-- (or a match starts) and comes back when you return.
	task.spawn(function()
		local ticks = 0
		while true do
			task.wait(1)
			ticks += 1
			for player, plot in plotOf do
				-- New achievements go up on the wall.
				if ticks % 10 == 0 then
					refreshTrophies(plot, player)
				end
				local character = player.Character
				local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local near = rootPart ~= nil
					and not player:GetAttribute("InMatch")
					and (rootPart.Position - BaseData.Center).Magnitude < 110
				if near then
					giveBuilder(player)
				else
					removeBuilder(player)
				end
			end
		end
	end)
end

return BaseService
