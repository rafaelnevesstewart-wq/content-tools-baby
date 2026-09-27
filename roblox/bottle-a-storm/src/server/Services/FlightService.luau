-- Cloud Flight (Robux game pass): press G (or the ☁️ button) to fly on a
-- fluffy cloud for Config.Flight.Duration seconds, then it needs a rest.
-- The player's own client moves them (FlightController), like riding powers;
-- the server decides when flying is allowed and shows the cloud to everyone.
-- Grabbing a stolen storm lands you at once, so thieves still have to run.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Products = require(Shared.Products)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent.Parent.Modules
local Notify = require(Modules.Notify)

local MovementService = require(script.Parent.MovementService)
local RideService = require(script.Parent.RideService)
local StealService = require(script.Parent.StealService)

local FlightService = {}

local flying: { [Player]: { endsAt: number, cloud: Model } } = {}
local readyAt: { [Player]: number } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

-- A small puffy cloud welded under the player's feet.
local function makeCloud(root: BasePart): Model
	local cloud = Instance.new("Model")
	cloud.Name = "FlightCloud"
	local puffs = {
		{ Vector3.new(0, 0, 0), 3.4 },
		{ Vector3.new(1.8, 0.2, 0.4), 2.6 },
		{ Vector3.new(-1.8, 0.1, -0.3), 2.7 },
		{ Vector3.new(0.4, 0.3, 1.6), 2.3 },
		{ Vector3.new(-0.3, 0.2, -1.7), 2.4 },
	}
	for _, puff in puffs do
		local part = Instance.new("Part")
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.one * puff[2]
		part.Color = Color3.fromRGB(252, 252, 255)
		part.Material = Enum.Material.SmoothPlastic
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		part.CastShadow = false
		part.CFrame = root.CFrame * CFrame.new(0, -3.4, 0) + puff[1]
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
		part.Parent = cloud
	end
	cloud.Parent = root.Parent
	return cloud
end

local function land(player: Player, message: string?)
	local flight = flying[player]
	if not flight then
		return
	end
	flying[player] = nil
	flight.cloud:Destroy()
	readyAt[player] = os.clock() + Config.Flight.Cooldown
	if player.Parent then
		player:SetAttribute("Flying", nil)
		player:SetAttribute("FlyEndsAt", nil)
		player:SetAttribute("FlyReadyAt", now() + Config.Flight.Cooldown)
		if message then
			Notify.player(player, message, "info")
		end
	end
end

local function takeOff(player: Player)
	if flying[player] then
		return
	end
	if player:GetAttribute(Products.passAttribute("Flight")) ~= true then
		return -- the client offers the pass instead
	end
	local root = rootOf(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	if StealService.isCarrying(player) then
		Notify.player(player, "🫙 The storm is too heavy to fly with! Run!", "warn")
		return
	end
	if MovementService.isStunned(player) then
		return
	end
	local wait = (readyAt[player] or 0) - os.clock()
	if wait > 0 then
		Notify.player(player, "☁️ Your cloud is resting. Fly again in " .. math.ceil(wait) .. "s.", "info")
		return
	end
	RideService.dismount(player)
	flying[player] = { endsAt = os.clock() + Config.Flight.Duration, cloud = makeCloud(root) }
	player:SetAttribute("FlyEndsAt", now() + Config.Flight.Duration)
	player:SetAttribute("Flying", true)
end

function FlightService.isFlying(player: Player): boolean
	return flying[player] ~= nil
end

function FlightService.start()
	Remotes.event("Fly").OnServerEvent:Connect(function(player, wants)
		if wants == true then
			takeOff(player)
		elseif wants == false then
			land(player, nil)
		end
	end)

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			land(player, nil)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		land(player, nil)
		readyAt[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(0.2)
			for player, flight in flying do
				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if StealService.isCarrying(player) then
					land(player, "🫙 The storm is too heavy to fly with! Run home!")
				elseif MovementService.isStunned(player) then
					land(player, "⚡ You got zapped off your cloud!")
				elseif not humanoid or humanoid.Health <= 0 then
					land(player, nil)
				elseif os.clock() >= flight.endsAt then
					land(player, "☁️ Your cloud needs a rest. Fly again in " .. Config.Flight.Cooldown .. "s.")
				end
			end
		end
	end)
end

return FlightService
