-- 🎯 Games Island (east of the castle, over a bridge) has two mini-games:
--   * Target Range: press Start at the firing line, get a bow and hit as
--     many moving targets as you can in 40 seconds (bullseyes score more).
--   * Parkour Race: step on the start pad, jump across the floating
--     platforms (touch both glowing checkpoints) and reach the finish pad as
--     fast as you can. Fall and you go back to your last checkpoint.
-- Both pay Sparks (a few times a day), with a bonus for a new personal best.
-- The board by the bridge shows the best scores and times in the server.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local RewardsData = require(Shared.RewardsData)

local Modules = script.Parent.Parent.Modules
local Effects = require(Modules.Effects)
local ItemModels = require(Modules.ItemModels)
local Juice = require(Modules.Juice)
local Notify = require(Modules.Notify)

local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)

local MiniGameService = {}

local GAMES = Config.Lobby.Center + Vector3.new(Config.Lobby.SideDistance, 0, 0)
local settings = Config.MiniGames

type Target = { model: Model, board: BasePart, owner: Player, tween: Tween? }
type RangeRound = { endsAt: number, score: number, targets: { Target }, lastShot: number }
type Race = { startedAt: number, checkpoint: number, respawn: CFrame }

local rounds: { [Player]: RangeRound } = {}
local races: { [Player]: Race } = {}
local targetFolder: Folder
local checkpoints: { BasePart } = {}
local startPad: BasePart
local rng = Random.new()
local boardRows: { TextLabel } = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

local function playerFrom(hit: BasePart): Player?
	local model = hit:FindFirstAncestorOfClass("Model")
	return if model then Players:GetPlayerFromCharacter(model) else nil
end

local function piece(parent: Instance, props: { [string]: any }): Part
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

local function label(parent: Instance, text: string, offset: number)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(240, 44)
	gui.StudsOffset = Vector3.new(0, offset, 0)
	gui.MaxDistance = 120
	gui.Parent = parent
	local textLabel = Instance.new("TextLabel")
	textLabel.BackgroundTransparency = 1
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.Font = Enum.Font.GothamBlack
	textLabel.TextScaled = true
	textLabel.TextColor3 = Color3.new(1, 1, 1)
	textLabel.TextStrokeTransparency = 0.2
	textLabel.Text = text
	textLabel.Parent = gui
end

-- A prize (a few times a day), plus a bonus for a personal best.
local function prize(player: Player, sparks: number, best: boolean, what: string)
	local data = DataService.get(player)
	if not data then
		return
	end
	local mini = data.minigames
	local today = RewardsData.today(os.time())
	if mini.day ~= today then
		mini.day = today
		mini.prizes = 0
	end
	local paid = 0
	if mini.prizes < settings.PrizesPerDay then
		mini.prizes += 1
		paid = sparks
	end
	if best then
		paid += settings.BestBonus
	end
	if paid > 0 then
		IncomeService.addSparks(player, paid)
	end
	Notify.player(
		player,
		what
			.. (if best then " 🌟 New personal best!" else "")
			.. (if paid > 0 then " +⚡" .. paid else " (no more prizes today, but it still counts!)"),
		"success"
	)
end

---------------------------------------------------------------------------
-- 🎯 Target Range
---------------------------------------------------------------------------

local RANGE_LINE = GAMES + Vector3.new(0, 0, -8)

local function spawnTarget(player: Player, round: RangeRound)
	local model = Instance.new("Model")
	model.Name = "Target_" .. player.UserId
	local spot = GAMES + Vector3.new(rng:NextNumber(-18, 18), rng:NextNumber(3, 11), -rng:NextNumber(30, 48))
	local frame = CFrame.lookAt(spot, Vector3.new(RANGE_LINE.X, spot.Y, RANGE_LINE.Z))
	local board = piece(model, {
		Name = "Board",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 3.4, 3.4),
		CFrame = frame * CFrame.Angles(0, math.rad(90), 0),
		Color = Color3.fromRGB(245, 240, 230),
		Material = Enum.Material.SmoothPlastic,
	})
	for index, ring in
		{ { 2.4, Color3.fromRGB(210, 40, 40) }, { 1.5, Color3.new(1, 1, 1) }, { 0.8, Color3.fromRGB(210, 40, 40) } }
	do
		local disc = piece(model, {
			Name = "Ring",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.42 + index * 0.02, ring[1] :: number, ring[1] :: number),
			CFrame = frame * CFrame.Angles(0, math.rad(90), 0),
			Color = ring[2] :: Color3,
			Material = Enum.Material.SmoothPlastic,
		})
		disc.CanQuery = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = board
		weld.Part1 = disc
		weld.Parent = disc
		disc.Anchored = false
	end
	model.PrimaryPart = board
	model.Parent = targetFolder
	local target: Target = { model = model, board = board, owner = player, tween = nil }
	-- It slides from side to side.
	local tween = TweenService:Create(
		board,
		TweenInfo.new(rng:NextNumber(1.2, 2.4), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ CFrame = board.CFrame + frame.RightVector * rng:NextNumber(-8, 8) }
	)
	tween:Play()
	target.tween = tween
	table.insert(round.targets, target)
end

local function endRound(player: Player)
	local round = rounds[player]
	if not round then
		return
	end
	rounds[player] = nil
	for _, target in round.targets do
		target.model:Destroy()
	end
	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	for _, container in { character, backpack } do
		local bow = container and container:FindFirstChild("Range Bow")
		if bow then
			bow:Destroy()
		end
	end
	player:SetAttribute("RangeScore", nil)
	player:SetAttribute("RangeEndsAt", nil)
	if not player.Parent then
		return
	end
	local data = DataService.get(player)
	local best = data ~= nil and round.score > (data.minigames.rangeBest or 0)
	if data and best then
		data.minigames.rangeBest = round.score
	end
	prize(
		player,
		math.floor(round.score * settings.SparksPerPoint),
		best and round.score > 0,
		"🎯 Time's up! You scored " .. round.score .. "."
	)
end

local function startRound(player: Player)
	if rounds[player] or player:GetAttribute("InMatch") then
		return
	end
	local round: RangeRound = {
		endsAt = workspace:GetServerTimeNow() + settings.RangeSeconds,
		score = 0,
		targets = {},
		lastShot = 0,
	}
	rounds[player] = round
	player:SetAttribute("RangeScore", 0)
	player:SetAttribute("RangeEndsAt", round.endsAt)
	local bow = ItemModels.bow()
	bow.Name = "Range Bow"
	bow.ToolTip = "Click to shoot the targets!"
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if backpack then
		bow.Parent = backpack
		if humanoid then
			humanoid:EquipTool(bow)
		end
	end
	for _ = 1, settings.TargetsAtOnce do
		spawnTarget(player, round)
	end
	Notify.player(player, "🎯 Go! Hit as many targets as you can!", "info")
	task.delay(settings.RangeSeconds, function()
		if rounds[player] == round then
			endRound(player)
		end
	end)
end

local function onShot(player: Player, aim: any)
	local round = rounds[player]
	local character = player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if not round or typeof(aim) ~= "Vector3" or not head then
		return
	end
	if os.clock() - round.lastShot < 0.35 then
		return
	end
	round.lastShot = os.clock()
	local origin = head.Position
	local direction = aim - origin
	if direction.Magnitude < 1 then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character :: Instance }
	local hit = workspace:Raycast(origin, direction.Unit * 160, params)
	local stop = if hit then hit.Position else origin + direction.Unit * 160
	-- The arrow's streak.
	local streak = piece(workspace, {
		Name = "RangeArrow",
		Size = Vector3.new(0.12, 0.12, (stop - origin).Magnitude),
		CFrame = CFrame.lookAt((origin + stop) / 2, stop),
		Color = Color3.fromRGB(255, 240, 180),
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
		Transparency = 0.3,
	})
	TweenService:Create(streak, TweenInfo.new(0.25), { Transparency = 1 }):Play()
	Debris:AddItem(streak, 0.3)
	Juice.sound(player, "arrow")
	if not hit then
		return
	end
	for index, target in round.targets do
		if hit.Instance == target.board then
			local fromCenter = (hit.Position - target.board.Position).Magnitude
			local points = if fromCenter < 0.5 then 25 elseif fromCenter < 0.9 then 15 else 10
			round.score += points
			player:SetAttribute("RangeScore", round.score)
			Juice.float(player, "+" .. points .. (if points == 25 then " 🎯 BULLSEYE!" else ""), hit.Position)
			Juice.sound(player, if points == 25 then "chime" else "hit")
			Effects.confetti(hit.Position, 12)
			if target.tween then
				target.tween:Cancel()
			end
			target.model:Destroy()
			table.remove(round.targets, index)
			spawnTarget(player, round)
			return
		end
	end
end

local function buildRange(parent: Instance)
	local line = piece(parent, {
		Name = "FiringLine",
		Size = Vector3.new(20, 0.3, 4),
		CFrame = CFrame.new(RANGE_LINE + Vector3.new(0, 0.15, 0)),
		Color = Color3.fromRGB(200, 60, 50),
		Material = Enum.Material.SmoothPlastic,
	})
	local stand = piece(parent, {
		Name = "RangeStand",
		Size = Vector3.new(3, 3.4, 1.6),
		CFrame = CFrame.new(RANGE_LINE + Vector3.new(-12, 1.7, 0)),
		Color = Color3.fromRGB(116, 82, 54),
		Material = Enum.Material.WoodPlanks,
	})
	label(stand, "🎯 Target Range", 4)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Start (" .. settings.RangeSeconds .. "s)"
	prompt.ObjectText = "🎯 Target Range"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = stand
	prompt.Triggered:Connect(startRound)
	-- Hay bales at the back to catch the arrows.
	for x = -24, 24, 6 do
		piece(parent, {
			Name = "HayBale",
			Size = Vector3.new(6, 4, 3),
			CFrame = CFrame.new(GAMES + Vector3.new(x, 2, -54)),
			Color = Color3.fromRGB(214, 184, 110),
			Material = Enum.Material.Fabric,
		})
	end
	line.CanCollide = false
end

---------------------------------------------------------------------------
-- ⏱️ Parkour Race
---------------------------------------------------------------------------

local function formatTime(seconds: number): string
	return string.format("%.1fs", seconds)
end

local function buildRace(parent: Instance)
	local count = 20
	local positions = {}
	for i = 1, count do
		local height = if i <= count / 2 then 3 + i * 1.6 else 3 + (count - i) * 1.6
		table.insert(positions, GAMES + Vector3.new(-28 + (i - 1) * 3, height, 30 + 10 * math.sin(i * 0.9)))
	end
	for i, position in positions do
		local checkpoint = i == 7 or i == 14
		local size = if checkpoint then 6 elseif i % 4 == 0 then 3.4 else 5
		local platform = piece(parent, {
			Name = if checkpoint then "RaceCheckpoint" else "RacePlatform",
			Size = Vector3.new(size, 1, size),
			CFrame = CFrame.new(position),
			Color = if checkpoint then Color3.fromRGB(120, 230, 255) else Color3.fromHSV(i / count, 0.45, 0.95),
			Material = if checkpoint then Enum.Material.Neon else Enum.Material.SmoothPlastic,
			Transparency = if checkpoint then 0.15 else 0,
		})
		if checkpoint then
			table.insert(checkpoints, platform)
		end
	end
	startPad = piece(parent, {
		Name = "RaceStart",
		Size = Vector3.new(6, 0.4, 6),
		CFrame = CFrame.new(GAMES + Vector3.new(-34, 0.2, 30)),
		Color = Color3.fromRGB(90, 220, 110),
		Material = Enum.Material.Neon,
	})
	label(startPad, "⏱️ Parkour Race: START", 3)
	local finish = piece(parent, {
		Name = "RaceFinish",
		Size = Vector3.new(6, 0.4, 6),
		CFrame = CFrame.new(GAMES + Vector3.new(34, 0.2, 30)),
		Color = Color3.fromRGB(255, 200, 60),
		Material = Enum.Material.Neon,
	})
	label(finish, "🏁 FINISH", 3)

	startPad.Touched:Connect(function(hit)
		local player = playerFrom(hit)
		local root = player and rootOf(player)
		if not player or not root or player:GetAttribute("InMatch") then
			return
		end
		local race = races[player]
		if race and race.checkpoint == 0 and os.clock() - race.startedAt < 1 then
			return -- still standing on it
		end
		races[player] = {
			startedAt = os.clock(),
			checkpoint = 0,
			respawn = startPad.CFrame + Vector3.new(0, 4, 0),
		}
		player:SetAttribute("RaceStartedAt", workspace:GetServerTimeNow())
		player:SetAttribute("RaceCheckpoint", 0)
	end)
	for index, checkpoint in checkpoints do
		checkpoint.Touched:Connect(function(hit)
			local player = playerFrom(hit)
			local race = player and races[player]
			if player and race and race.checkpoint == index - 1 then
				race.checkpoint = index
				race.respawn = checkpoint.CFrame + Vector3.new(0, 4, 0)
				player:SetAttribute("RaceCheckpoint", index)
				Juice.sound(player, "chime")
			end
		end)
	end
	finish.Touched:Connect(function(hit)
		local player = playerFrom(hit)
		local race = player and races[player]
		if not player or not race then
			return
		end
		if race.checkpoint < #checkpoints then
			Notify.player(player, "⏱️ Touch both glowing checkpoints first!", "error")
			return
		end
		races[player] = nil
		player:SetAttribute("RaceStartedAt", nil)
		player:SetAttribute("RaceCheckpoint", nil)
		local time = os.clock() - race.startedAt
		local data = DataService.get(player)
		local best = data ~= nil and (data.minigames.raceBest == nil or time < data.minigames.raceBest)
		if data and best then
			data.minigames.raceBest = math.floor(time * 10) / 10
		end
		Effects.confetti(finish.Position + Vector3.new(0, 2, 0), 40)
		prize(
			player,
			math.max(settings.RaceMinSparks, math.floor(settings.RaceSparks - time * 10)),
			best,
			"⏱️ Finished in " .. formatTime(time) .. "!"
		)
	end)
end

---------------------------------------------------------------------------
-- The best scores board
---------------------------------------------------------------------------

local function buildBoard(parent: Instance)
	local board = piece(parent, {
		Name = "GamesBoard",
		Size = Vector3.new(12, 10, 0.6),
		CFrame = CFrame.lookAt(GAMES + Vector3.new(-40, 7, -14), GAMES + Vector3.new(0, 7, -14)),
		Color = Color3.fromRGB(34, 38, 52),
		Material = Enum.Material.Slate,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(480, 400)
	gui.LightInfluence = 0.1
	gui.Parent = board
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = gui
	for i = 1, 14 do
		local row = Instance.new("TextLabel")
		row.LayoutOrder = i
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, 28)
		row.Font = Enum.Font.GothamBold
		row.TextScaled = true
		row.TextColor3 = if i == 1 or i == 8 then Color3.fromRGB(255, 210, 90) else Color3.fromRGB(235, 238, 245)
		row.Text = ""
		row.Parent = gui
		table.insert(boardRows, row)
	end
end

local function refreshBoard()
	local range, race = {}, {}
	for _, player in Players:GetPlayers() do
		local data = DataService.get(player)
		if data then
			if (data.minigames.rangeBest or 0) > 0 then
				table.insert(range, { name = player.DisplayName, value = data.minigames.rangeBest })
			end
			if data.minigames.raceBest then
				table.insert(race, { name = player.DisplayName, value = data.minigames.raceBest })
			end
		end
	end
	table.sort(range, function(a, b)
		return a.value > b.value
	end)
	table.sort(race, function(a, b)
		return a.value < b.value
	end)
	local lines = { "🎯 Best Target Range scores" }
	for i = 1, 5 do
		local entry = range[i]
		table.insert(lines, if entry then i .. ". " .. entry.name .. ": " .. entry.value else "")
	end
	table.insert(lines, "")
	table.insert(lines, "⏱️ Fastest Parkour Races")
	for i = 1, 5 do
		local entry = race[i]
		table.insert(lines, if entry then i .. ". " .. entry.name .. ": " .. formatTime(entry.value) else "")
	end
	for index, row in boardRows do
		row.Text = lines[index] or ""
	end
end

function MiniGameService.start()
	local folder = Instance.new("Folder")
	folder.Name = "GamesIsland"
	folder.Parent = workspace
	targetFolder = Instance.new("Folder")
	targetFolder.Name = "RangeTargets"
	targetFolder.Parent = workspace
	buildRange(folder)
	buildRace(folder)
	buildBoard(folder)
	Remotes.event("RangeShot").OnServerEvent:Connect(onShot)

	Players.PlayerRemoving:Connect(function(player)
		if rounds[player] then
			endRound(player)
		end
		races[player] = nil
	end)
	-- Falling off the course puts you back on your last checkpoint; going
	-- into a match ends your games.
	task.spawn(function()
		local lastBoard = 0
		while true do
			task.wait(0.25)
			for player, race in races do
				local root = rootOf(player)
				if not root or player:GetAttribute("InMatch") then
					races[player] = nil
					player:SetAttribute("RaceStartedAt", nil)
					player:SetAttribute("RaceCheckpoint", nil)
				elseif root.Position.Y < GAMES.Y - 10 then
					root.AssemblyLinearVelocity = Vector3.zero
					local character = root.Parent :: Model
					character:PivotTo(race.respawn)
				end
			end
			for player in rounds do
				if player:GetAttribute("InMatch") then
					endRound(player)
				end
			end
			if os.clock() - lastBoard > 10 then
				lastBoard = os.clock()
				pcall(refreshBoard)
			end
		end
	end)
end

return MiniGameService
