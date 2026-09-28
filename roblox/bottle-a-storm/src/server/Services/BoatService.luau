-- 🚤 The Sky Boat Race (BoatData): press "Race!" at the dock by the castle
-- gate and a flying boat carries you; your screen flies it where you look
-- (BoatController). Fly through every ring in order. Finishing pays a prize
-- (shared with the Games Island daily prizes), a bonus for your best time,
-- and the dock's board shows the best times in the server.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local BoatData = require(Shared.BoatData)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent.Parent.Modules
local Effects = require(Modules.Effects)
local Juice = require(Modules.Juice)
local MountModels = require(Modules.MountModels)
local Notify = require(Modules.Notify)

local DataService = require(script.Parent.DataService)
local MiniGameService = require(script.Parent.MiniGameService)

local BoatService = {}

type Race = { boat: Model, started: number, ring: number, hipHeight: number }

local races: { [Player]: Race } = {}
local boardRows: { TextLabel } = {}

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

local function stop(player: Player)
	local race = races[player]
	if not race then
		return
	end
	races[player] = nil
	race.boat:Destroy()
	local humanoid = humanoidOf(player)
	if humanoid then
		humanoid.HipHeight = race.hipHeight
	end
	player:SetAttribute("Boating", nil)
	player:SetAttribute("BoatRing", nil)
	player:SetAttribute("BoatStarted", nil)
	player:SetAttribute("Mounted", nil)
	player:SetAttribute("MountFlies", nil)
end

local function refreshBoard()
	local list = {}
	for _, player in Players:GetPlayers() do
		local data = DataService.get(player)
		local best = data and data.minigames.boatBest
		if type(best) == "number" then
			table.insert(list, { name = player.DisplayName, value = best })
		end
	end
	table.sort(list, function(a, b)
		return a.value < b.value
	end)
	for index, row in boardRows do
		local entry = list[index]
		row.Text = if entry
			then "#" .. index .. "  " .. entry.name .. "  " .. string.format("%.1fs", entry.value)
			else ""
	end
end

local function finish(player: Player, race: Race)
	local time = workspace:GetServerTimeNow() - race.started
	stop(player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local best = data.minigames.boatBest == nil or time < data.minigames.boatBest
	if best then
		data.minigames.boatBest = math.floor(time * 10) / 10
	end
	data.stats.boatRaces = (data.stats.boatRaces or 0) + 1
	local sparks = math.max(BoatData.MinSparks, math.floor(BoatData.StartSparks - time * 5))
	local root = rootOf(player)
	if root then
		Effects.confetti(root.Position, 40)
	end
	Juice.sound(player, "win")
	MiniGameService.prize(
		player,
		sparks,
		best,
		"🚤 Finished the Sky Boat Race in " .. string.format("%.1f", time) .. "s!"
	)
	refreshBoard()
end

local function start(player: Player)
	local character = player.Character
	local humanoid = humanoidOf(player)
	local root = rootOf(player)
	if not character or not humanoid or not root or humanoid.Health <= 0 or races[player] then
		return
	end
	if player:GetAttribute("InMatch") or player:GetAttribute("Dueling") then
		return
	end
	if player:GetAttribute("Mounted") then
		Notify.player(player, "🚤 Hop off your mount first (press H).", "info")
		return
	end
	local model, kind = MountModels.build("SkyBoat")
	if not model or not kind then
		return
	end
	character:PivotTo(BoatData.Start)
	local hipHeight = humanoid.HipHeight
	humanoid.HipHeight = hipHeight + kind.raise
	local weld = Instance.new("Weld")
	weld.Name = "MountWeld"
	weld.Part0 = root
	weld.Part1 = model.PrimaryPart
	weld.C0 = CFrame.new(0, -(root.Size.Y / 2 + humanoid.HipHeight) + kind.bodyHeight, 0.3)
	weld.Parent = model.PrimaryPart
	model.Name = player.Name .. "_SkyBoat"
	CollectionService:AddTag(model, "Mount")
	model.Parent = character
	races[player] = { boat = model, started = workspace:GetServerTimeNow(), ring = 1, hipHeight = hipHeight }
	player:SetAttribute("Boating", true)
	player:SetAttribute("Mounted", "SkyBoat") -- sit in it (MountController)
	player:SetAttribute("MountFlies", false)
	player:SetAttribute("BoatRing", 1)
	player:SetAttribute("BoatStarted", workspace:GetServerTimeNow())
	Notify.player(
		player,
		"🚤 GO! Fly where you look (hold forward). Through all " .. #BoatData.Rings .. " rings!",
		"success"
	)
	Juice.sound(player, "chime")
end

local function tick()
	for player, race in races do
		local root = rootOf(player)
		local humanoid = humanoidOf(player)
		if not root or not humanoid or humanoid.Health <= 0 or player:GetAttribute("InMatch") then
			stop(player)
			continue
		end
		if workspace:GetServerTimeNow() - race.started > BoatData.TimeLimit then
			stop(player)
			Notify.player(player, "🚤 Out of time! Try again at the dock.", "info")
			continue
		end
		local target = BoatData.Rings[race.ring]
		if (root.Position - target).Magnitude <= BoatData.RingRadius + 2 then
			race.ring += 1
			Juice.sound(player, "pop")
			if race.ring > #BoatData.Rings then
				finish(player, race)
			else
				player:SetAttribute("BoatRing", race.ring)
			end
		end
	end
end

-- The rings: glowing hoops, numbered, each facing the next.
local function buildCourse()
	local folder = Instance.new("Folder")
	folder.Name = "BoatCourse"
	for index, center in BoatData.Rings do
		local nextPoint = BoatData.Rings[index + 1] or BoatData.Dock
		local frame = CFrame.lookAt(center, nextPoint)
		local ring = Instance.new("Model")
		ring.Name = "Ring" .. index
		local pieces = 18
		for i = 0, pieces - 1 do
			local angle = i / pieces * math.pi * 2
			local p = Instance.new("Part")
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Material = Enum.Material.Neon
			p.Color = if index == #BoatData.Rings then Color3.fromRGB(255, 210, 80) else Color3.fromRGB(90, 200, 255)
			p.Size = Vector3.new(0.8, BoatData.RingRadius * 2 * math.pi / pieces + 0.3, 0.8)
			p.CFrame = frame * CFrame.Angles(0, 0, angle) * CFrame.new(BoatData.RingRadius, 0, 0)
			p.Parent = ring
		end
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(60, 40)
		gui.StudsOffsetWorldSpace = Vector3.new(0, BoatData.RingRadius + 3, 0)
		gui.MaxDistance = 250
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextStrokeTransparency = 0.3
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Text = if index == #BoatData.Rings then "🏁" else tostring(index)
		label.Parent = gui
		local anchor = Instance.new("Part")
		anchor.Name = "Center"
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.Transparency = 1
		anchor.Size = Vector3.one
		anchor.CFrame = frame
		anchor.Parent = ring
		gui.Parent = anchor
		ring.Parent = folder
	end
	folder.Parent = workspace
end

-- The dock: a wooden pier with a boat to look at, the Race prompt and the
-- best-times board.
local function buildDock()
	local folder = Instance.new("Folder")
	folder.Name = "BoatDock"
	local at = CFrame.lookAt(BoatData.Dock, BoatData.Dock + Vector3.new(0, 0, 1))
	local wood = Color3.fromRGB(140, 100, 64)
	local deck = Instance.new("Part")
	deck.Anchored = true
	deck.Size = Vector3.new(10, 0.6, 12)
	deck.CFrame = at * CFrame.new(0, 0.3, 0)
	deck.Color = wood
	deck.Material = Enum.Material.WoodPlanks
	deck.Parent = folder
	local display = MountModels.build("SkyBoat")
	if display and display.PrimaryPart then
		for _, p in display:GetDescendants() do
			if p:IsA("BasePart") then
				p.Anchored = true
			end
		end
		display:PivotTo(at * CFrame.new(0, 2.5, 1))
		display.Parent = folder
	end
	local board = Instance.new("Part")
	board.Anchored = true
	board.Size = Vector3.new(8, 7, 0.4)
	board.CFrame = at * CFrame.new(0, 5, -6.5) * CFrame.Angles(0, math.pi, 0)
	board.Color = Color3.fromRGB(36, 40, 52)
	board.Material = Enum.Material.Slate
	board.Parent = folder
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(320, 280)
	gui.Parent = board
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = gui
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 60)
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 205, 90)
	title.Text = "🚤 Sky Boat Race\nBest times"
	title.Parent = gui
	for i = 1, 5 do
		local row = Instance.new("TextLabel")
		row.LayoutOrder = i
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, 40)
		row.Font = Enum.Font.GothamBold
		row.TextScaled = true
		row.TextColor3 = Color3.fromRGB(230, 235, 245)
		row.Text = ""
		row.Parent = gui
		table.insert(boardRows, row)
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Race!"
	prompt.ObjectText = "🚤 Sky Boat Race"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = deck
	prompt.Triggered:Connect(start)
	folder.Parent = workspace
end

function BoatService.start()
	buildCourse()
	buildDock()
	Remotes.event("BoatAction").OnServerEvent:Connect(function(player, action)
		if action == "stop" and races[player] then
			stop(player)
			Notify.player(player, "🚤 Race stopped.", "info")
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.1)
			tick()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(30)
			refreshBoard()
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		races[player] = nil
		task.defer(refreshBoard)
	end)
end

return BoatService
