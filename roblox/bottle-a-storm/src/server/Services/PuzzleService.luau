-- 🧩 The daily puzzle rooms on Base Island's south side (PuzzleData):
--   🌀 Hedge Maze: find the chest at the far corner (it has a glass roof, so
--      no flying over it).
--   🪟 Glass Bridge: cross six pairs of glass; one of each pair breaks. Step
--      on every row in order to claim the chest at the end.
--   🔐 Code Door: the code's symbols are on the board by the door; the
--      number for each symbol is on a painting somewhere around the rooms.
-- They all change every day. Each chest pays Sparks once a day, and doing
-- all three pays a bonus (and counts toward 🧩 Puzzle Master).

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local PuzzleData = require(Shared.PuzzleData)
local Remotes = require(Shared.Remotes)
local RewardsData = require(Shared.RewardsData)

local Modules = script.Parent.Parent.Modules
local Busy = require(Modules.Busy)
local Effects = require(Modules.Effects)
local Juice = require(Modules.Juice)
local Notify = require(Modules.Notify)
local Usage = require(Modules.Usage)

local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)

local PuzzleService = {}

local O = PuzzleData.Origin
local MAZE_CORNER = O + Vector3.new(-38, 0, 46)
local BRIDGE_Y = 6
local ROOM_MIN = O + Vector3.new(14, 0, 46)
local ROOM_MAX = O + Vector3.new(38, 0, 70)

local day = -1
local code = ""
local safeSide: { number } = {}
local root: Folder
local daily: Folder? = nil
local bridgeProgress: { [Player]: number } = {}
local lastTry: { [Player]: number } = {}

local function part(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

local function sign(parent: Instance, cframe: CFrame, size: Vector3, text: string)
	local board = part(parent, {
		Size = size,
		CFrame = cframe,
		Color = Color3.fromRGB(96, 66, 42),
		Material = Enum.Material.WoodPlanks,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(size.X * 50, size.Y * 50)
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 240, 210)
	label.Text = text
	label.Parent = gui
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

local function inBox(position: Vector3, low: Vector3, high: Vector3): boolean
	return position.X >= low.X and position.X <= high.X and position.Z >= low.Z and position.Z <= high.Z
end

---------------------------------------------------------------------------
-- Rewards
---------------------------------------------------------------------------

local function claim(player: Player, key: string)
	local data = DataService.get(player)
	if not data then
		return
	end
	data.puzzles = data.puzzles or { day = -1, done = {} }
	local puzzles = data.puzzles
	if puzzles.day ~= day then
		puzzles.day = day
		puzzles.done = {}
	end
	if puzzles.done[key] then
		Notify.player(
			player,
			"🧩 You already solved today's " .. PuzzleData.Names[key] .. ". New puzzles tomorrow!",
			"info"
		)
		return
	end
	puzzles.done[key] = true
	Usage.track("puzzle:" .. key, player)
	data.sparks += PuzzleData.Sparks
	local message = "🧩 You solved the " .. PuzzleData.Names[key] .. "! +⚡" .. PuzzleData.Sparks
	if puzzles.done.Maze and puzzles.done.Bridge and puzzles.done.Code then
		data.sparks += PuzzleData.AllBonus
		data.stats.puzzleDays = (data.stats.puzzleDays or 0) + 1
		message ..= " And that's all three today: +⚡" .. PuzzleData.AllBonus .. " bonus!"
		Juice.sound(player, "win")
	else
		Juice.sound(player, "coins")
	end
	IncomeService.sync(player)
	local where = rootOf(player)
	if where then
		Effects.confetti(where.Position + Vector3.new(0, 2, 0), 30)
	end
	Notify.player(player, message, "success")
end

local function chest(parent: Instance, position: Vector3, action: string, onClaim: (Player) -> ())
	local box = part(parent, {
		Name = "PuzzleChest",
		Size = Vector3.new(2.6, 1.8, 1.8),
		CFrame = CFrame.new(position + Vector3.new(0, 0.9, 0)),
		Color = Color3.fromRGB(150, 95, 50),
		Material = Enum.Material.WoodPlanks,
	})
	part(parent, {
		Size = Vector3.new(2.7, 0.3, 1.9),
		CFrame = box.CFrame * CFrame.new(0, 0.6, 0),
		Color = Color3.fromRGB(230, 184, 70),
		Material = Enum.Material.Foil,
		CanCollide = false,
	})
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = "🧩 Puzzle prize"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = box
	prompt.Triggered:Connect(onClaim)
end

---------------------------------------------------------------------------
-- The daily parts
---------------------------------------------------------------------------

local HEDGE = Color3.fromRGB(56, 118, 58)

local function buildMaze(parent: Instance)
	local size, cell = PuzzleData.MazeSize, PuzzleData.MazeCell
	local open = PuzzleData.maze(day)
	local height = 8
	local function id(x: number, y: number): number
		return (x - 1) * size + y
	end
	local function wall(center: Vector3, across: boolean)
		part(parent, {
			Name = "Hedge",
			Size = if across then Vector3.new(cell + 0.8, height, 0.8) else Vector3.new(0.8, height, cell + 0.8),
			CFrame = CFrame.new(center + Vector3.new(0, height / 2, 0)),
			Color = HEDGE,
			Material = Enum.Material.Grass,
		})
	end
	for x = 1, size do
		for y = 1, size do
			local low = MAZE_CORNER + Vector3.new((x - 1) * cell, 0, (y - 1) * cell)
			-- East side of the cell.
			if x < size and not (open[id(x, y)] and open[id(x, y)][id(x + 1, y)]) then
				wall(low + Vector3.new(cell, 0, cell / 2), false)
			end
			-- South side of the cell.
			if y < size and not (open[id(x, y)] and open[id(x, y)][id(x, y + 1)]) then
				wall(low + Vector3.new(cell / 2, 0, cell), true)
			end
		end
		-- Outer walls: north (with the way in at the first cell) and south.
		if x ~= 1 then
			wall(MAZE_CORNER + Vector3.new((x - 0.5) * cell, 0, 0), true)
		end
		wall(MAZE_CORNER + Vector3.new((x - 0.5) * cell, 0, size * cell), true)
	end
	for y = 1, size do
		wall(MAZE_CORNER + Vector3.new(0, 0, (y - 0.5) * cell), false)
		wall(MAZE_CORNER + Vector3.new(size * cell, 0, (y - 0.5) * cell), false)
	end
	-- A glass roof: no flying over the hedges.
	part(parent, {
		Size = Vector3.new(size * cell + 1, 0.4, size * cell + 1),
		CFrame = CFrame.new(MAZE_CORNER + Vector3.new(size * cell / 2, height + 0.2, size * cell / 2)),
		Color = Color3.fromRGB(200, 235, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.85,
	})
	local far = MAZE_CORNER + Vector3.new((size - 0.5) * cell, 0, (size - 0.5) * cell)
	chest(parent, far, "Open", function(player)
		local where = rootOf(player)
		local high = MAZE_CORNER + Vector3.new(size * cell, 0, size * cell)
		if where and inBox(where.Position, MAZE_CORNER, high) and not player:GetAttribute("Mounted") then
			claim(player, "Maze")
		end
	end)
end

local function buildBridge(parent: Instance)
	safeSide = PuzzleData.bridge(day)
	for row, safe in safeSide do
		for _, side in { -1, 1 } do
			local tile = part(parent, {
				Name = "BridgeGlass",
				Size = Vector3.new(3.6, 0.4, 3.4),
				CFrame = CFrame.new(O + Vector3.new(side * 2.5, BRIDGE_Y - 0.2, 47 + (row - 0.5) * 4)),
				Color = Color3.fromRGB(170, 220, 255),
				Material = Enum.Material.Glass,
				Transparency = 0.3,
			})
			local good = side == safe
			local broken = false
			tile.Touched:Connect(function(hit)
				local character = hit.Parent
				local player = character and Players:GetPlayerFromCharacter(character)
				if not player then
					return
				end
				if good then
					local progress = bridgeProgress[player] or 0
					if row == progress + 1 then
						bridgeProgress[player] = row
					end
				elseif not broken then
					broken = true
					Effects.confetti(tile.Position, 16)
					Juice.sound(player, "oops")
					tile.Transparency = 1
					tile.CanCollide = false
					task.delay(3, function()
						broken = false
						tile.Transparency = 0.3
						tile.CanCollide = true
					end)
				end
			end)
		end
	end
end

local function buildCode(parent: Instance)
	local list = PuzzleData.code(day)
	local symbols, digits = {}, {}
	for _, entry in list do
		table.insert(symbols, entry.symbol)
		table.insert(digits, tostring(entry.digit))
	end
	code = table.concat(digits)
	sign(
		parent,
		CFrame.lookAt(O + Vector3.new(19, 4, 45.4), O + Vector3.new(19, 4, 40)),
		Vector3.new(7, 3, 0.3),
		"🔐 The code is:\n" .. table.concat(symbols, " ") .. "\nFind each number on the paintings around here!"
	)
	-- The paintings, one per symbol, on the outside walls.
	local spots = {
		CFrame.lookAt(O + Vector3.new(-38.8, 4, 58), O + Vector3.new(-45, 4, 58)),
		CFrame.lookAt(O + Vector3.new(-26, 4, 70.8), O + Vector3.new(-26, 4, 80)),
		CFrame.lookAt(O + Vector3.new(26, 4, 70.8), O + Vector3.new(26, 4, 80)),
		CFrame.lookAt(O + Vector3.new(38.8, 4, 58), O + Vector3.new(45, 4, 58)),
	}
	for index, entry in list do
		local frame = part(parent, {
			Size = Vector3.new(3.4, 3.4, 0.3),
			CFrame = spots[index],
			Color = Color3.fromRGB(230, 190, 90),
			Material = Enum.Material.Foil,
		})
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.CanvasSize = Vector2.new(160, 160)
		gui.Parent = frame
		local label = Instance.new("TextLabel")
		label.BackgroundColor3 = Color3.fromRGB(250, 245, 230)
		label.Size = UDim2.new(1, -16, 1, -16)
		label.Position = UDim2.fromOffset(8, 8)
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(40, 30, 24)
		label.Text = entry.symbol .. "\n= " .. entry.digit
		label.Parent = gui
	end
end

local function buildDaily()
	if daily then
		daily:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Daily"
	buildMaze(folder)
	buildBridge(folder)
	buildCode(folder)
	folder.Parent = root
	daily = folder
	bridgeProgress = {}
end

---------------------------------------------------------------------------
-- The parts that stay the same
---------------------------------------------------------------------------

local function buildFixed()
	local wood = Color3.fromRGB(140, 100, 64)
	sign(
		root,
		CFrame.lookAt(O + Vector3.new(-9, 3, 40), O + Vector3.new(-9, 3, 30)),
		Vector3.new(8, 3.4, 0.3),
		"🧩 Puzzle Rooms\n🌀 Maze · 🪟 Glass Bridge · 🔐 Code Door\nNew puzzles every day!"
	)
	-- The glass bridge: a ramp up, a start and an end platform on posts.
	local ramp = Instance.new("WedgePart")
	ramp.Anchored = true
	ramp.Size = Vector3.new(4, BRIDGE_Y, 6)
	ramp.CFrame = CFrame.new(O + Vector3.new(0, BRIDGE_Y / 2, 39))
	ramp.Color = wood
	ramp.Material = Enum.Material.WoodPlanks
	ramp.Parent = root
	for _, z in { 44.5, 73 } do
		local platform = part(root, {
			Size = Vector3.new(12, 1, if z < 50 then 5 else 4),
			CFrame = CFrame.new(O + Vector3.new(0, BRIDGE_Y - 0.5, z)),
			Color = wood,
			Material = Enum.Material.WoodPlanks,
		})
		for _, x in { -5.5, 5.5 } do
			part(root, {
				Size = Vector3.new(0.8, BRIDGE_Y - 1, 0.8),
				CFrame = CFrame.new(O + Vector3.new(x, (BRIDGE_Y - 1) / 2, z)),
				Color = wood:Lerp(Color3.new(0, 0, 0), 0.2),
				Material = Enum.Material.Wood,
			})
		end
		if z > 50 then
			chest(root, platform.Position + Vector3.new(0, 0.5, 0.8), "Open", function(player)
				if (bridgeProgress[player] or 0) >= PuzzleData.BridgeRows then
					claim(player, "Bridge")
				else
					Notify.player(player, "🪟 You have to cross the glass to win this one!", "info")
				end
			end)
		end
	end
	-- The code room: stone walls, a glass roof and a locked door.
	local stone = Color3.fromRGB(150, 150, 158)
	local height = 8
	local low, high = ROOM_MIN, ROOM_MAX
	local width, depth = high.X - low.X, high.Z - low.Z
	local middle = (low + high) / 2
	local function wall(size: Vector3, position: Vector3)
		part(root, {
			Size = size,
			CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0)),
			Color = stone,
			Material = Enum.Material.Brick,
		})
	end
	wall(Vector3.new(0.8, height, depth), Vector3.new(low.X, low.Y, middle.Z))
	wall(Vector3.new(0.8, height, depth), Vector3.new(high.X, low.Y, middle.Z))
	wall(Vector3.new(width, height, 0.8), Vector3.new(middle.X, low.Y, high.Z))
	local doorWidth = 4
	local side = (width - doorWidth) / 2
	wall(Vector3.new(side, height, 0.8), Vector3.new(low.X + side / 2, low.Y, low.Z))
	wall(Vector3.new(side, height, 0.8), Vector3.new(high.X - side / 2, low.Y, low.Z))
	part(root, {
		Size = Vector3.new(width + 1, 0.4, depth + 1),
		CFrame = CFrame.new(middle + Vector3.new(0, height + 0.2, 0)),
		Color = Color3.fromRGB(200, 235, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.85,
	})
	local door = part(root, {
		Name = "CodeDoor",
		Size = Vector3.new(doorWidth, height, 0.8),
		CFrame = CFrame.new(Vector3.new(middle.X, low.Y + height / 2, low.Z)),
		Color = Color3.fromRGB(110, 70, 40),
		Material = Enum.Material.Wood,
	})
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Enter the code"
	prompt.ObjectText = "🔐 Code Door"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OpenWindow", "CodeDoor")
	prompt.Parent = door
	-- Inside: the prize and a way out.
	chest(root, Vector3.new(middle.X, low.Y, high.Z - 5), "Open", function(player)
		local where = rootOf(player)
		if where and inBox(where.Position, low, high) then
			claim(player, "Code")
		end
	end)
	local lever = part(root, {
		Size = Vector3.new(1.2, 2, 0.4),
		CFrame = CFrame.new(Vector3.new(middle.X - 4, low.Y + 1, low.Z + 1.2)),
		Color = Color3.fromRGB(200, 60, 60),
		Material = Enum.Material.SmoothPlastic,
	})
	local leave = Instance.new("ProximityPrompt")
	leave.ActionText = "Leave"
	leave.ObjectText = "🚪 Exit"
	leave.HoldDuration = 0
	leave.MaxActivationDistance = 7
	leave.RequiresLineOfSight = false
	leave.Parent = lever
	leave.Triggered:Connect(function(player)
		local character = player.Character
		if character then
			character:PivotTo(CFrame.new(Vector3.new(middle.X, low.Y + 3, low.Z - 5)))
		end
	end)
end

local function tryCode(player: Player, guess: any): (boolean, string)
	if os.clock() - (lastTry[player] or 0) < 1 then
		return false, "Slow down!"
	end
	lastTry[player] = os.clock()
	local where = rootOf(player)
	local door = Vector3.new((ROOM_MIN.X + ROOM_MAX.X) / 2, ROOM_MIN.Y, ROOM_MIN.Z)
	if not where or (where.Position - door).Magnitude > 14 then
		return false, "Stand by the Code Door."
	end
	local busy = Busy.reason(player)
	if busy then
		return false, "Not while you're " .. busy .. "."
	end
	if type(guess) ~= "string" or guess ~= code then
		Juice.sound(player, "oops")
		return false, "❌ Wrong code! Check the paintings around the rooms."
	end
	local character = player.Character
	if character then
		character:PivotTo(CFrame.new(door + Vector3.new(0, 3, 5)))
	end
	Juice.sound(player, "chime")
	return true, "🔓 The door opens!"
end

local function refreshDay()
	local today = RewardsData.today(os.time())
	if today ~= day then
		day = today
		buildDaily()
	end
end

function PuzzleService.start()
	root = Instance.new("Folder")
	root.Name = "PuzzleRooms"
	root.Parent = workspace
	buildFixed()
	refreshDay()
	Remotes.func("PuzzleCode").OnServerInvoke = tryCode
	-- Fall off the glass bridge and you start it over.
	task.spawn(function()
		while true do
			task.wait(0.5)
			for player, progress in bridgeProgress do
				local where = rootOf(player)
				if progress > 0 and (not where or where.Position.Y < O.Y + BRIDGE_Y - 3) then
					bridgeProgress[player] = 0
				end
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(60)
			refreshDay()
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		bridgeProgress[player] = nil
		lastTry[player] = nil
	end)
end

return PuzzleService
