-- 🔨 Building your base (BaseService): hold the Builder on Base Island, pick
-- a block (or 🧽 Remove) in the bar at the bottom, and click where it goes.
-- A see-through ghost shows the spot first. 🪑 switches the bar to furniture;
-- 🔄 (or R) turns furniture a quarter turn.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local BaseData = require(Shared.BaseData)
local Remotes = require(Shared.Remotes)

local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local BaseBuilder = {}

local selected = BaseData.Blocks[1].key
local removing = false
local target: { number }? = nil -- the cell under the mouse: { i, j, k }
local ghost: Part
local palette: Frame
local buttons: { [string]: TextButton } = {}
local lastTouch: Vector2? = nil
local furnitureMode = false
local turn = 0
local turnButton: TextButton

local function holding(): Tool?
	local character = player.Character
	local tool = character and character:FindFirstChild("Builder")
	return if tool and tool:IsA("Tool") then tool else nil
end

local function refreshButtons()
	for key, button in buttons do
		local on = if key == "Remove" then removing else (not removing and key == selected)
		if key == "Tab" or key == "Turn" then
			on = false
		end
		button.BackgroundColor3 = if on then UI.Colors.Good else UI.Colors.PanelLight
	end
end

-- What's under the pointer: the cell to build in (or the block to remove).
local function aim(plot: number): { number }?
	local camera = workspace.CurrentCamera
	local screen = if UserInputService.TouchEnabled and lastTouch
		then lastTouch
		else UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(screen.X, screen.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { ghost }
	if player.Character then
		table.insert(ignore, player.Character)
	end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 150, params)
	if not hit then
		return nil
	end
	if removing then
		local cell = hit.Instance:GetAttribute("Cell")
		local folder = workspace:FindFirstChild("Bases")
		local mine = folder and folder:FindFirstChild("Plot" .. plot)
		if type(cell) == "string" and mine and hit.Instance:IsDescendantOf(mine) then
			local i, j, k = string.match(cell, "^(%-?%d+),(%-?%d+),(%-?%d+)$")
			return { tonumber(i) :: number, tonumber(j) :: number, tonumber(k) :: number }
		end
		return nil
	end
	local point = hit.Position + hit.Normal * (BaseData.CellSize / 2)
	local i, j, k = BaseData.cellAt(plot, point)
	if not BaseData.inside(i, j, k) then
		return nil
	end
	return { i, j, k }
end

function BaseBuilder.start()
	ghost = Instance.new("Part")
	ghost.Name = "BuildGhost"
	ghost.Anchored = true
	ghost.CanCollide = false
	ghost.CanQuery = false
	ghost.CanTouch = false
	ghost.Size = Vector3.one * (BaseData.CellSize + 0.05)
	ghost.Material = Enum.Material.Neon
	ghost.Transparency = 0.6

	local screen = UI.screen("BaseBuilder", 6)
	palette = UI.new("Frame", {
		Name = "Window", -- frees the mouse so you can aim and click
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(620, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = screen,
	}, {
		UI.corner(12),
		UI.stroke(UI.Colors.Stroke, 2),
		UI.padding(5),
		-- Wraps onto more rows on narrow (phone) screens.
		UI.new("UIListLayout", {
			Padding = UDim.new(0, 4),
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Wraps = true,
		}),
	})
	local function fitPalette()
		local camera = workspace.CurrentCamera
		local width = if camera then camera.ViewportSize.X - 24 else 620
		palette.Size = UDim2.fromOffset(math.clamp(width, 240, 620), 0)
	end
	fitPalette()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitPalette)
	end
	local function addButton(order: number, key: string, text: string, color: Color3?, onClick: () -> ()): TextButton
		local button = UI.button({
			LayoutOrder = order,
			Size = UDim2.fromOffset(46, 46),
			Text = text,
			TextSize = 22,
			Parent = palette,
		})
		if color then
			local swatch = UI.new("Frame", {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -3),
				Size = UDim2.new(1, -10, 0, 5),
				BackgroundColor3 = color,
				Parent = button,
			}, { UI.corner(3) })
			swatch.ZIndex = 2
		end
		button.Activated:Connect(onClick)
		buttons[key] = button
		return button
	end
	local blockButtons: { TextButton } = {}
	local furnitureButtons: { TextButton } = {}
	for order, block in BaseData.Blocks do
		table.insert(
			blockButtons,
			addButton(order, block.key, block.emoji, block.color, function()
				selected = block.key
				removing = false
				refreshButtons()
			end)
		)
	end
	for order, item in BaseData.Furniture do
		local button = addButton(20 + order, item.key, item.emoji, item.color, function()
			selected = item.key
			removing = false
			refreshButtons()
		end)
		button.Visible = false
		table.insert(furnitureButtons, button)
	end
	-- 🪑 / 🧱 switches between blocks and furniture.
	local tab: TextButton
	tab = addButton(0, "Tab", "🪑", nil, function()
		furnitureMode = not furnitureMode
		for _, button in blockButtons do
			button.Visible = not furnitureMode
		end
		for _, button in furnitureButtons do
			button.Visible = furnitureMode
		end
		tab.Text = if furnitureMode then "🧱" else "🪑"
		turnButton.Visible = furnitureMode
		selected = if furnitureMode then BaseData.Furniture[1].key else BaseData.Blocks[1].key
		removing = false
		refreshButtons()
	end)
	local function rotate()
		turn = (turn + 1) % 4
		turnButton.Text = "🔄" .. turn * 90 .. "°"
	end
	turnButton = addButton(49, "Turn", "🔄0°", nil, rotate)
	turnButton.TextSize = 13
	turnButton.Visible = false
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.R and furnitureMode and holding() then
			rotate()
		end
	end)
	addButton(50, "Remove", "🧽", nil, function()
		removing = not removing
		refreshButtons()
	end)
	local armed = 0
	addButton(51, "Clear", "🗑️", nil, function()
		-- Tap twice to clear the whole plot.
		if os.clock() - armed < 2 then
			Remotes.event("BaseEdit"):FireServer("clear", 0, 0, 0)
			armed = 0
		else
			armed = os.clock()
		end
	end)
	refreshButtons()

	UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			lastTouch = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)

	local hooked: { [Tool]: boolean } = setmetatable({}, { __mode = "k" }) :: any
	RunService.RenderStepped:Connect(function()
		local tool = holding()
		local plot = player:GetAttribute("BasePlot")
		palette.Visible = tool ~= nil
		if not tool or type(plot) ~= "number" then
			ghost.Parent = nil
			target = nil
			return
		end
		if not hooked[tool] then
			hooked[tool] = true
			tool.Activated:Connect(function()
				local cell = target
				if cell then
					if removing then
						Remotes.event("BaseEdit"):FireServer("remove", cell[1], cell[2], cell[3])
					else
						Remotes.event("BaseEdit"):FireServer("place", cell[1], cell[2], cell[3], selected, turn)
					end
				end
			end)
		end
		target = aim(plot)
		if target then
			ghost.CFrame = CFrame.new(BaseData.cellPosition(plot, target[1], target[2], target[3]))
				* CFrame.Angles(0, turn * math.pi / 2, 0)
			local block = BaseData.block(selected)
			local item = BaseData.furniture(selected)
			ghost.Color = if removing
				then Color3.fromRGB(255, 80, 80)
				elseif block then block.color
				elseif item then item.color
				else Color3.new(1, 1, 1)
			ghost.Parent = workspace
		else
			ghost.Parent = nil
		end
	end)
end

return BaseBuilder
