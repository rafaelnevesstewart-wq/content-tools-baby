-- Things to do in the castle lobby between matches:
--   * 1v1 duels: challenge anyone from the 👥 Party window. You both get an
--     iron sword in the duel arena; the first knockout wins (Sparks for your
--     first few wins each day). Step out of the ring and you give up.
--   * Training dummies: whack them with your practice sword to see how much
--     damage you do.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local MatchData = require(Shared.MatchData)
local Remotes = require(Shared.Remotes)
local RewardsData = require(Shared.RewardsData)

local Modules = script.Parent.Parent.Modules
local Juice = require(Modules.Juice)
local Notify = require(Modules.Notify)
local WorldBuilder = require(Modules.WorldBuilder)

local CombatService = require(script.Parent.CombatService)
local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local MatchService = require(script.Parent.MatchService)

local LobbyService = {}

type Duel = { a: Player, b: Player, started: boolean, endsAt: number }

local duelOf: { [Player]: Duel } = {}
local invites: { [Player]: { [Player]: number } } = {} -- challenged -> challenger -> when
local lastChallenge: { [Player]: number } = {}
local dummies: { { model: Model, base: CFrame, head: BasePart } } = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

local function alive(player: Player): boolean
	local humanoid = humanoidOf(player)
	return humanoid ~= nil and humanoid.Health > 0
end

-- In the lobby, alive and not already dueling.
local function free(player: Player): boolean
	return player.Parent ~= nil and not player:GetAttribute("InMatch") and duelOf[player] == nil and alive(player)
end

local function place(player: Player, cframe: CFrame)
	local character = player.Character
	local root = rootOf(player)
	if character and root then
		root.AssemblyLinearVelocity = Vector3.zero
		character:PivotTo(cframe)
	end
end

local function heal(player: Player)
	local humanoid = humanoidOf(player)
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = humanoid.MaxHealth
	end
end

local function hold(player: Player, still: boolean)
	local root = rootOf(player)
	if root then
		root.Anchored = still
	end
end

local function opponentIn(duel: Duel, player: Player): Player
	return if duel.a == player then duel.b else duel.a
end

-- Where each duelist starts: opposite sides of the ring, facing each other.
local function arenaSpot(side: number): CFrame
	local spots = WorldBuilder.LobbySpots
	local center = spots.arena + Vector3.new(0, 4, 0)
	return CFrame.lookAt(center + Vector3.new(side * (spots.arenaRadius - 3), 0, 0), center)
end

local function reward(winner: Player)
	local data = DataService.get(winner)
	if not data then
		return
	end
	data.stats.duelsWon = (data.stats.duelsWon or 0) + 1
	local today = RewardsData.today(os.time())
	if data.duels.day ~= today then
		data.duels.day = today
		data.duels.paid = 0
	end
	if data.duels.paid < Config.Duel.RewardsPerDay then
		data.duels.paid += 1
		IncomeService.addSparks(winner, Config.Duel.WinSparks)
		local root = rootOf(winner)
		if root then
			Juice.float(winner, "+⚡" .. Config.Duel.WinSparks, root.Position + Vector3.new(0, 4, 0))
		end
	end
end

local function finish(duel: Duel, winner: Player?, why: string)
	if duelOf[duel.a] ~= duel then
		return
	end
	duelOf[duel.a] = nil
	duelOf[duel.b] = nil
	for _, player in { duel.a, duel.b } do
		if player.Parent then
			player:SetAttribute("Dueling", nil)
			hold(player, false)
		end
	end
	if winner then
		local loser = opponentIn(duel, winner)
		Notify.player(winner, "⚔️ You won the duel against " .. loser.DisplayName .. "! " .. why, "success")
		Juice.sound(winner, "chime")
		if loser.Parent then
			Notify.player(loser, "⚔️ " .. winner.DisplayName .. " won the duel. " .. why, "info")
		end
		reward(winner)
	else
		for _, player in { duel.a, duel.b } do
			if player.Parent then
				Notify.player(player, "⚔️ Duel over: " .. why, "info")
			end
		end
	end
	-- Back to the courtyard with a practice sword. (A knocked out duelist
	-- respawns there anyway.)
	task.delay(2, function()
		for index, player in { duel.a, duel.b } do
			if player.Parent and not player:GetAttribute("InMatch") and duelOf[player] == nil and alive(player) then
				heal(player)
				place(player, WorldBuilder.LobbySpots.spawn + Vector3.new(index * 6 - 9, 4, 0))
				CombatService.lobbyGear(player, 1)
			end
		end
	end)
end

local function begin(a: Player, b: Player)
	local duel: Duel = { a = a, b = b, started = false, endsAt = 0 }
	duelOf[a] = duel
	duelOf[b] = duel
	for index, player in { a, b } do
		player:SetAttribute("Dueling", opponentIn(duel, player).DisplayName)
		heal(player)
		CombatService.lobbyGear(player, Config.Duel.SwordTier)
		place(player, arenaSpot(if index == 1 then -1 else 1))
		hold(player, true)
	end
	task.spawn(function()
		for count = Config.Duel.CountdownSeconds, 1, -1 do
			for _, player in { a, b } do
				Notify.player(
					player,
					"⚔️ " .. opponentIn(duel, player).DisplayName .. " vs you in " .. count .. "...",
					"info"
				)
			end
			task.wait(1)
			if duelOf[a] ~= duel then
				return
			end
		end
		duel.started = true
		duel.endsAt = os.clock() + Config.Duel.Seconds
		for _, player in { a, b } do
			hold(player, false)
			Notify.player(player, "⚔️ FIGHT!", "success")
			Juice.sound(player, "zap")
		end
	end)
end

local function onAction(player: Player, action: any, userId: any)
	if type(action) ~= "string" or type(userId) ~= "number" then
		return
	end
	local other = Players:GetPlayerByUserId(userId)
	if not other or other == player then
		return
	end
	if action == "challenge" then
		if os.clock() - (lastChallenge[player] or 0) < 3 then
			return
		end
		lastChallenge[player] = os.clock()
		if not free(player) then
			Notify.player(player, "⚔️ You can only duel in the lobby, one duel at a time.", "error")
			return
		end
		if not free(other) then
			Notify.player(player, "⚔️ " .. other.DisplayName .. " is busy right now.", "error")
			return
		end
		invites[other] = invites[other] or {}
		invites[other][player] = os.clock()
		Remotes.event("DuelInvite"):FireClient(other, player.UserId, player.DisplayName)
		Notify.player(player, "⚔️ Challenge sent to " .. other.DisplayName .. "!", "info")
	elseif action == "accept" then
		local mine = invites[player]
		local sent = mine and mine[other]
		if mine then
			mine[other] = nil
		end
		if not sent or os.clock() - sent > Config.Duel.InviteSeconds then
			Notify.player(player, "⚔️ That challenge ran out.", "error")
		elseif not free(player) or not free(other) then
			Notify.player(player, "⚔️ You can't duel right now (one of you is busy or in a match).", "error")
		else
			begin(other, player)
		end
	elseif action == "decline" then
		local mine = invites[player]
		if mine and mine[other] then
			mine[other] = nil
			Notify.player(other, "⚔️ " .. player.DisplayName .. " said no thanks.", "info")
		end
	end
end

---------------------------------------------------------------------------
-- Training dummies
---------------------------------------------------------------------------

local function buildDummy(parent: Instance, at: Vector3): { model: Model, base: CFrame, head: BasePart }
	local model = Instance.new("Model")
	model.Name = "TrainingDummy"
	local base = CFrame.lookAt(at, Vector3.new(Config.Lobby.Center.X, at.Y, at.Z)) -- facing the courtyard
	local function piece(
		name: string,
		size: Vector3,
		cframe: CFrame,
		color: Color3,
		material: Enum.Material,
		shape: Enum.PartType?
	): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = cframe
		p.Color = color
		p.Material = material
		if shape then
			p.Shape = shape
		end
		p.Parent = model
		return p
	end
	local wood = Color3.fromRGB(110, 80, 54)
	local straw = Color3.fromRGB(214, 184, 110)
	local sack = Color3.fromRGB(196, 170, 128)
	piece("Stand", Vector3.new(3.2, 0.5, 3.2), base * CFrame.new(0, 0.25, 0), wood, Enum.Material.Wood)
	piece("Post", Vector3.new(0.6, 6.2, 0.6), base * CFrame.new(0, 3.1, 0), wood, Enum.Material.Wood)
	piece("Arms", Vector3.new(5, 0.5, 0.5), base * CFrame.new(0, 4.6, 0), wood, Enum.Material.Wood)
	local body = piece(
		"Body",
		Vector3.new(3.2, 2.2, 2.2),
		base * CFrame.new(0, 3.9, 0) * CFrame.Angles(0, 0, math.rad(90)),
		sack,
		Enum.Material.Fabric,
		Enum.PartType.Cylinder
	)
	for _, y in { 2.6, 5.1 } do
		piece(
			"Rope",
			Vector3.new(0.3, 2.3, 2.3),
			base * CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(150, 120, 80),
			Enum.Material.Fabric,
			Enum.PartType.Cylinder
		)
	end
	-- A target painted on the chest.
	for index, ring in
		{ { 1.9, Color3.fromRGB(200, 40, 40) }, { 1.3, Color3.new(1, 1, 1) }, { 0.7, Color3.fromRGB(200, 40, 40) } }
	do
		piece(
			"Target",
			Vector3.new(0.05, ring[1], ring[1]),
			base * CFrame.new(0, 3.9, -1.1 - index * 0.02) * CFrame.Angles(0, math.rad(90), 0),
			ring[2] :: Color3,
			Enum.Material.SmoothPlastic,
			Enum.PartType.Cylinder
		)
	end
	local head = piece(
		"Head",
		Vector3.new(1.9, 1.9, 1.9),
		base * CFrame.new(0, 6.3, 0),
		straw,
		Enum.Material.Fabric,
		Enum.PartType.Ball
	)
	for _, x in { -0.4, 0.4 } do
		piece(
			"Eye",
			Vector3.new(0.25, 0.25, 0.1),
			base * CFrame.new(x, 6.5, -0.93),
			Color3.fromRGB(40, 30, 20),
			Enum.Material.SmoothPlastic
		)
	end
	model.PrimaryPart = body
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 30)
	gui.StudsOffset = Vector3.new(0, 2, 0)
	gui.MaxDistance = 40
	gui.Parent = head
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.3
	text.Text = "🎯 Hit me!"
	text.Parent = gui
	model.Parent = parent
	return { model = model, base = model:GetPivot(), head = head }
end

-- The dummy rocks back and forth after a hit, away from whoever hit it.
local function wobble(dummy: { model: Model, base: CFrame, head: BasePart }, from: Vector3)
	if dummy.model:GetAttribute("Wobbling") then
		return
	end
	dummy.model:SetAttribute("Wobbling", true)
	local base = dummy.base
	local away = (base.Position - from) * Vector3.new(1, 0, 1)
	local axis = Vector3.yAxis:Cross(if away.Magnitude > 0.1 then away.Unit else base.LookVector)
	-- Tip around the dummy's feet, not its middle.
	local feet = base.Position - Vector3.new(0, 3.9, 0)
	local offset = CFrame.new(feet):ToObjectSpace(base)
	task.spawn(function()
		for step = 1, 14 do
			local angle = math.rad(20) * math.exp(-step * 0.25) * math.cos(step * 1.2)
			dummy.model:PivotTo(CFrame.new(feet) * CFrame.fromAxisAngle(axis, angle) * offset)
			task.wait(1 / 30)
		end
		dummy.model:PivotTo(base)
		dummy.model:SetAttribute("Wobbling", nil)
	end)
end

local function onSwung(player: Player, _aim: Vector3, weaponName: string)
	if player:GetAttribute("InMatch") then
		return
	end
	local root = rootOf(player)
	if not root then
		return
	end
	for _, dummy in dummies do
		local offset = dummy.base.Position - root.Position
		local flat = offset * Vector3.new(1, 0, 1)
		if flat.Magnitude <= Config.Match.SwordRange + 1 and root.CFrame.LookVector:Dot(flat.Unit) > 0.2 then
			local tier = player:GetAttribute("SwordTier")
			local sword = MatchData.Swords[if type(tier) == "number" then tier else 1] or MatchData.Swords[1]
			local amount = if weaponName == "Knockback Stick" then Config.Match.StickDamage else sword.damage
			Remotes.event("DamageShown"):FireClient(player, dummy.head.Position, amount)
			Juice.sound(player, "pop")
			wobble(dummy, root.Position)
			return
		end
	end
end

---------------------------------------------------------------------------

function LobbyService.start()
	CombatService.duelOpponent = function(player: Player): Player?
		local duel = duelOf[player]
		if duel and duel.started then
			return opponentIn(duel, player)
		end
		return nil
	end
	Remotes.event("DuelAction").OnServerEvent:Connect(onAction)
	CombatService.Swung:Connect(onSwung)

	local folder = Instance.new("Folder")
	folder.Name = "TrainingDummies"
	folder.Parent = workspace
	for _, at in WorldBuilder.LobbySpots.dummies do
		table.insert(dummies, buildDummy(folder, at))
	end

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
			if humanoid then
				humanoid.Died:Connect(function()
					local duel = duelOf[player]
					if duel then
						finish(duel, opponentIn(duel, player), "Knockout!")
					end
				end)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local duel = duelOf[player]
		if duel then
			finish(duel, opponentIn(duel, player), player.DisplayName .. " left.")
		end
		invites[player] = nil
		lastChallenge[player] = nil
		for _, list in invites do
			list[player] = nil
		end
	end)
	-- A match starting pulls everyone out of their duels.
	MatchService.MatchStarted:Connect(function()
		local seen: { [Duel]: boolean } = {}
		for _, duel in duelOf do
			if not seen[duel] then
				seen[duel] = true
				finish(duel, nil, "a match is starting!")
			end
		end
	end)

	-- Time limit, and stepping out of the ring (or falling) gives up.
	task.spawn(function()
		while true do
			task.wait(0.5)
			local seen: { [Duel]: boolean } = {}
			for _, duel in duelOf do
				if not seen[duel] and duel.started then
					seen[duel] = true
					if os.clock() > duel.endsAt then
						finish(duel, nil, "time's up, it's a draw!")
					else
						for _, player in { duel.a, duel.b } do
							local root = rootOf(player)
							local spots = WorldBuilder.LobbySpots
							local flat = if root then (root.Position - spots.arena) * Vector3.new(1, 0, 1) else nil
							if
								root
								and flat
								and (flat.Magnitude > spots.arenaRadius + 6 or root.Position.Y < spots.arena.Y - 10)
							then
								finish(duel, opponentIn(duel, player), player.DisplayName .. " left the ring.")
								break
							end
						end
					end
				end
			end
		end
	end)
end

return LobbyService
