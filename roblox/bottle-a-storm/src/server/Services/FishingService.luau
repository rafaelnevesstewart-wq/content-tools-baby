-- 🎣 The fishing pond on Games Island: take a rod from the dock, click the
-- water to cast, wait for a bite and click again quickly to reel it in.
-- Every catch pays Sparks (up to FishData.MaxSparksPerDay a day) and goes in
-- your 📖 Fish Book (data.fish). Rare catches are announced to everyone.
-- The rod is for the pond: it goes away if you walk off or join a match.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local FishData = require(Shared.FishData)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local RewardsData = require(Shared.RewardsData)

local Modules = script.Parent.Parent.Modules
local Effects = require(Modules.Effects)
local ItemModels = require(Modules.ItemModels)
local Juice = require(Modules.Juice)
local Notify = require(Modules.Notify)

local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)

local FishingService = {}

type Cast = { bobber: BasePart, beam: Beam, token: number, bitten: boolean }

local CENTER = FishData.Center
local WATER_Y = CENTER.Y - 1
local casts: { [Player]: Cast } = {}
local nextToken = 0
local rng = Random.new()

local function fishOf(data: any): any
	data.fish = data.fish or { caught = {}, best = {}, day = -1, paid = 0 }
	return data.fish
end

local function rodOf(player: Player): Tool?
	local character = player.Character
	local tool = character and character:FindFirstChild("Fishing Rod")
	return if tool and tool:IsA("Tool") then tool else nil
end

local function stop(player: Player)
	local cast = casts[player]
	casts[player] = nil
	player:SetAttribute("FishState", nil)
	if cast then
		cast.beam:Destroy()
		cast.bobber:Destroy()
	end
end

local function giveRod(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if player:GetAttribute("InMatch") or not backpack then
		return
	end
	if backpack:FindFirstChild("Fishing Rod") or rodOf(player) then
		Notify.player(player, "🎣 You already have a rod! Equip it and click the water.", "info")
		return
	end
	ItemModels.fishingRod().Parent = backpack
	Notify.player(player, "🎣 Got a rod! Equip it, click the water, then click again when a fish bites.", "success")
end

local function removeRod(player: Player)
	stop(player)
	for _, container in { player.Character, player:FindFirstChildOfClass("Backpack") } do
		local tool = container and container:FindFirstChild("Fishing Rod")
		if tool then
			tool:Destroy()
		end
	end
end

-- Shows the catch over your head for everyone.
local function showCatch(player: Player, fish: FishData.Fish, weight: number)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 70)
	gui.StudsOffset = Vector3.new(0, 3.5, 0)
	gui.MaxDistance = 80
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextStrokeTransparency = 0.3
	label.TextColor3 = FishData.Rarities[fish.rarity] or Color3.new(1, 1, 1)
	label.Text = fish.emoji .. " " .. fish.name .. "\n" .. string.format("%.1f kg", weight)
	label.Parent = gui
	gui.Parent = head
	Debris:AddItem(gui, 3)
end

local function land(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local fish = FishData.pick(rng:NextNumber())
	local low, high = fish.weight[1], fish.weight[2]
	local size = rng:NextNumber() ^ 1.6 -- big ones are rarer
	local weight = low + (high - low) * size
	local book = fishOf(data)
	book.caught[fish.id] = (book.caught[fish.id] or 0) + 1
	local best = book.best[fish.id]
	local record = best == nil or weight > best
	if record then
		book.best[fish.id] = math.floor(weight * 10 + 0.5) / 10
	end
	data.stats.fishCaught = (data.stats.fishCaught or 0) + 1
	-- Sparks, up to the daily limit.
	local today = RewardsData.today(os.time())
	if book.day ~= today then
		book.day = today
		book.paid = 0
	end
	local sparks = math.floor(fish.sparks * (0.8 + 0.4 * size))
	sparks = math.clamp(FishData.MaxSparksPerDay - book.paid, 0, sparks)
	book.paid += sparks
	if sparks > 0 then
		data.sparks += sparks
		IncomeService.sync(player)
	end
	showCatch(player, fish, weight)
	Juice.sound(player, if fish.rarity == "Junk" then "oops" else "coins")
	local message = "🎣 You caught a "
		.. fish.emoji
		.. " "
		.. fish.name
		.. " ("
		.. fish.rarity
		.. ", "
		.. string.format("%.1f kg", weight)
		.. ")"
		.. (if sparks > 0 then "! +⚡" .. Format.number(sparks) else "!")
		.. (if record and best ~= nil then " 🏅 New record!" else "")
		.. (if book.caught[fish.id] == 1 then " 📖 New in your Fish Book!" else "")
	Notify.player(player, message, if fish.rarity == "Legendary" or fish.rarity == "Mythic" then "rare" else "success")
	if fish.rarity == "Legendary" or fish.rarity == "Mythic" then
		Notify.all("🎣 " .. player.DisplayName .. " caught a " .. fish.emoji .. " " .. fish.name .. "!", "rare")
		Juice.sound(player, "win")
	end
end

local function cast(player: Player, point: Vector3)
	local rod = rodOf(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rod or not root or casts[player] or player:GetAttribute("InMatch") then
		return
	end
	if (Vector3.new(root.Position.X, CENTER.Y, root.Position.Z) - CENTER).Magnitude > FishData.CastRange then
		Notify.player(player, "🎣 Walk up to the pond to fish.", "info")
		return
	end
	-- Keep the bobber on the water.
	local offset = Vector3.new(point.X - CENTER.X, 0, point.Z - CENTER.Z)
	if offset.Magnitude > FishData.Radius - 1.5 then
		offset = offset.Unit * (FishData.Radius - 1.5)
	end
	local spot = Vector3.new(CENTER.X + offset.X, WATER_Y + 0.1, CENTER.Z + offset.Z)
	local bobber = Instance.new("Part")
	bobber.Name = "Bobber"
	bobber.Shape = Enum.PartType.Ball
	bobber.Size = Vector3.one * 0.5
	bobber.Anchored = true
	bobber.CanCollide = false
	bobber.CanQuery = false
	bobber.Color = Color3.fromRGB(230, 60, 60)
	bobber.Material = Enum.Material.SmoothPlastic
	bobber.CFrame = CFrame.new(spot)
	bobber.Parent = workspace
	local lineEnd = Instance.new("Attachment")
	lineEnd.Parent = bobber
	local pole = rod:FindFirstChild("Pole")
	local tip = pole and pole:FindFirstChild("Tip")
	local beam = Instance.new("Beam")
	beam.Attachment0 = if tip and tip:IsA("Attachment") then tip else nil
	beam.Attachment1 = lineEnd
	beam.Width0 = 0.04
	beam.Width1 = 0.04
	beam.CurveSize0 = -1
	beam.Color = ColorSequence.new(Color3.fromRGB(240, 240, 240))
	beam.FaceCamera = true
	beam.Parent = bobber
	nextToken += 1
	local token = nextToken
	casts[player] = { bobber = bobber, beam = beam, token = token, bitten = false }
	player:SetAttribute("FishState", "waiting")
	Juice.sound(player, "throw")
	task.delay(rng:NextNumber(FishData.BiteAfter[1], FishData.BiteAfter[2]), function()
		local current = casts[player]
		if not current or current.token ~= token then
			return
		end
		current.bitten = true
		player:SetAttribute("FishState", "bite")
		Juice.sound(player, "pop")
		Effects.confetti(spot, 6)
		TweenService:Create(bobber, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 3, true), {
			CFrame = CFrame.new(spot - Vector3.new(0, 0.45, 0)),
		}):Play()
		task.wait(FishData.ReactSeconds)
		local still = casts[player]
		if still and still.token == token then
			stop(player)
			Notify.player(player, "🐟 Too slow, it got away! Cast again.", "info")
		end
	end)
end

local function reel(player: Player)
	local current = casts[player]
	if not current then
		return
	end
	local bitten = current.bitten
	stop(player)
	if bitten then
		land(player)
	else
		Notify.player(player, "🎣 Too soon! Wait for the bobber to dip, then click.", "info")
	end
end

-- The pond: sand around clear water, a wooden dock, a rod rack and the Fish
-- Book stand.
local function build()
	local terrain = workspace.Terrain
	terrain:FillCylinder(CFrame.new(CENTER - Vector3.new(0, 1, 0)), 2, FishData.Radius + 2.5, Enum.Material.Sand)
	terrain:FillCylinder(CFrame.new(CENTER - Vector3.new(0, 3, 0)), 6, FishData.Radius, Enum.Material.Air)
	terrain:FillCylinder(CFrame.new(CENTER - Vector3.new(0, 3.6, 0)), 5.2, FishData.Radius, Enum.Material.Water)
	local folder = Instance.new("Folder")
	folder.Name = "FishingPond"
	folder.Parent = workspace
	local function part(props: { [string]: any }): Part
		local p = Instance.new("Part")
		p.Anchored = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		for key, value in props do
			(p :: any)[key] = value
		end
		p.Parent = folder
		return p
	end
	local wood = Color3.fromRGB(140, 100, 64)
	-- The dock reaches over the water from the island's middle side (-X).
	part({
		Name = "Dock",
		Size = Vector3.new(9, 0.4, 4),
		CFrame = CFrame.new(CENTER + Vector3.new(-7.5, 0.1, 0)),
		Color = wood,
		Material = Enum.Material.WoodPlanks,
	})
	for _, x in { -4, 0 } do
		for _, z in { -1.7, 1.7 } do
			part({
				Size = Vector3.new(0.5, 3, 0.5),
				CFrame = CFrame.new(CENTER + Vector3.new(x, -1.2, z)),
				Color = wood:Lerp(Color3.new(0, 0, 0), 0.2),
				Material = Enum.Material.Wood,
			})
		end
	end
	local function stand(position: Vector3, text: string, action: string, onTrigger: ((Player) -> ())?, window: string?)
		local board = part({
			Size = Vector3.new(4, 2.4, 0.3),
			CFrame = CFrame.lookAt(position + Vector3.new(0, 2.4, 0), position + Vector3.new(-5, 2.4, 0)),
			Color = wood,
			Material = Enum.Material.WoodPlanks,
		})
		part({
			Size = Vector3.new(0.3, 2.4, 0.3),
			CFrame = CFrame.new(position + Vector3.new(0, 0.6, 0)),
			Color = wood,
			Material = Enum.Material.Wood,
		})
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.CanvasSize = Vector2.new(240, 140)
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(255, 240, 210)
		label.Text = text
		label.Parent = gui
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = action
		prompt.ObjectText = "🎣 Fishing Pond"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		if window then
			prompt:SetAttribute("OpenWindow", window)
		end
		prompt.Parent = board
		if onTrigger then
			prompt.Triggered:Connect(onTrigger)
		end
	end
	stand(CENTER + Vector3.new(-14, 0, -3), "🎣 Fishing Pond\nTake a rod!", "Take a rod", giveRod)
	stand(CENTER + Vector3.new(-14, 0, 3), "📖 Fish Book\nYour catches", "Fish Book", nil, "FishBook")
end

function FishingService.start()
	build()
	Remotes.event("Fish").OnServerEvent:Connect(function(player, action, point)
		if action == "cast" and typeof(point) == "Vector3" then
			cast(player, point)
		elseif action == "reel" then
			reel(player)
		end
	end)
	Remotes.func("GetFish").OnServerInvoke = function(player)
		local data = DataService.get(player)
		if not data then
			return nil
		end
		local book = fishOf(data)
		return { caught = book.caught, best = book.best }
	end
	-- The rod is for the pond.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local backpack = player:FindFirstChildOfClass("Backpack")
				local has = rodOf(player) ~= nil or (backpack ~= nil and backpack:FindFirstChild("Fishing Rod") ~= nil)
				if has then
					local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
					local far = not root or (root.Position - CENTER).Magnitude > 90
					if far or player:GetAttribute("InMatch") then
						removeRod(player)
					elseif casts[player] and not rodOf(player) then
						stop(player) -- put the rod away mid-cast
					end
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(stop)
end

return FishingService
