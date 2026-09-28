-- 🏗️ Base Island (west of the castle, over a bridge): 8 building plots.
-- Claim a free plot at its sign and you get the 🔨 Builder: place and remove
-- blocks (BaseData.Blocks, free and unlimited up to BaseData.MaxBlocks) on
-- your plot's 10 x 10 x 10 grid. Your base is saved with your profile and
-- comes back whenever you claim a plot again. Anyone can visit.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local BaseData = require(Shared.BaseData)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent.Parent.Modules
local Effects = require(Modules.Effects)
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
}

local plotOf: { [Player]: Plot } = {}
local lastEdit: { [Player]: number } = {}
local root: Folder

local function cellKey(i: number, j: number, k: number): string
	return i .. "," .. j .. "," .. k
end

local function makeBlock(plot: Plot, i: number, j: number, k: number, key: string): BasePart?
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

local function saveList(plot: Plot): { string }
	local list = {}
	for key, part in plot.cells do
		local block = part:GetAttribute("Block")
		if type(block) == "string" then
			table.insert(list, key .. "," .. block)
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
		local i, j, k, key = string.match(entry, "^(%-?%d+),(%-?%d+),(%-?%d+),(%w+)$")
		local ci, cj, ck = tonumber(i), tonumber(j), tonumber(k)
		if ci and cj and ck and key and BaseData.inside(ci, cj, ck) then
			local part = makeBlock(plot, ci, cj, ck, key)
			if part then
				part:SetAttribute("Block", key)
			end
		end
	end
	giveBuilder(player)
	Notify.player(
		player,
		"🏗️ This plot is yours! Hold the 🔨 Builder and click to build. It saves by itself.",
		"success"
	)
end

local function onEdit(player: Player, action: any, i: any, j: any, k: any, key: any)
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
		if plot.cells[id] or type(key) ~= "string" or not BaseData.block(key) then
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
		local part = makeBlock(plot, i, j, k, key)
		if part then
			part:SetAttribute("Block", key)
			Juice.sound(player, "pop")
		end
	elseif action == "remove" then
		local part = plot.cells[id]
		if part then
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
		local plot: Plot = { index = index, owner = nil, folder = folder, signText = text, cells = {} }
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
		while true do
			task.wait(1)
			for player, _ in plotOf do
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
