-- Water balloon fights. Everyone gets Water Balloons: click a player to throw
-- one. Nobody gets hurt. A splash knocks players back and soaks them (slower
-- for a moment), and a thief who gets splashed drops the stolen storm.
-- Players standing on their own island are safe.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local SkinData = require(Shared.SkinData)

local Modules = script.Parent.Parent.Modules
local Effects = require(Modules.Effects)
local Juice = require(Modules.Juice)

local DataService = require(script.Parent.DataService)
local MovementService = require(script.Parent.MovementService)
local PlotService = require(script.Parent.PlotService)
local StealService = require(script.Parent.StealService)

local BalloonService = {}

local TOOL_NAME = "Water Balloons"
local COLORS = {
	Color3.fromRGB(120, 200, 255),
	Color3.fromRGB(255, 150, 200),
	Color3.fromRGB(170, 240, 170),
	Color3.fromRGB(255, 220, 120),
}

local lastThrow: { [Player]: number } = {}
local template: Tool
local rng = Random.new()

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

local function splash(thrower: Player, at: Vector3, color: Color3)
	Effects.splash(at, color)
	local hitSomeone = false
	for _, target in Players:GetPlayers() do
		local root = rootOf(target)
		local humanoid = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
		if target == thrower or not root or not humanoid or humanoid.Health <= 0 then
			continue
		end
		if (root.Position - at).Magnitude > Config.Balloon.SplashRadius + 1.5 then
			continue
		end
		if PlotService.isOnPlot(target, root.Position) then
			Juice.float(
				thrower,
				"🛡️ Safe at home!",
				root.Position + Vector3.new(0, 3, 0),
				Color3.fromRGB(150, 130, 220)
			)
			continue
		end
		hitSomeone = true
		local away = root.Position - at
		local flat = Vector3.new(away.X, 0, away.Z)
		local direction = if flat.Magnitude > 0.1 then flat.Unit else (root.Position - at + Vector3.new(0.1, 0, 0)).Unit
		Juice.knock(target, direction * Config.Balloon.Knockback + Vector3.new(0, 25, 0))
		MovementService.soak(target, Config.Balloon.SoakSeconds)
		Juice.float(target, "💦 SPLASH!", root.Position + Vector3.new(0, 3, 0), color)
		Juice.sound(target, "pop")
		if StealService.isCarrying(target) then
			StealService.zapThief(target, thrower.DisplayName, at, thrower, true)
		end
	end
	if hitSomeone then
		Juice.float(thrower, "💦 SPLASH!", at + Vector3.new(0, 3, 0), color)
		Juice.sound(thrower, "coins")
		local data = DataService.get(thrower)
		if data then
			data.stats.splashes += 1
		end
	end
end

local function onThrow(player: Player, target: any)
	if typeof(target) ~= "Vector3" then
		return
	end
	local root = rootOf(player)
	local character = player.Character
	if not root or not character or not character:FindFirstChild(TOOL_NAME) then
		return
	end
	if os.clock() - (lastThrow[player] or 0) < Config.Balloon.Cooldown or MovementService.isStunned(player) then
		return
	end
	lastThrow[player] = os.clock()

	local origin = root.Position + Vector3.new(0, 1.5, 0)
	local aim = target - origin
	if aim.Magnitude > Config.Balloon.Range then
		target = origin + aim.Unit * Config.Balloon.Range
	end
	local data = DataService.get(player)
	local fx = data and data.cosmetics.fx
	local color = if fx and fx ~= SkinData.DefaultBeam
		then SkinData.beam(fx).glow
		else COLORS[rng:NextInteger(1, #COLORS)]
	local balloon = Instance.new("Part")
	balloon.Name = "WaterBalloon"
	balloon.Shape = Enum.PartType.Ball
	balloon.Size = Vector3.new(1.3, 1.3, 1.3)
	balloon.Color = color
	balloon.Material = Enum.Material.Glass
	balloon.Transparency = 0.15
	balloon.Anchored = true
	balloon.CanCollide = false
	balloon.CanTouch = false
	balloon.CanQuery = false
	local duration = math.clamp((target - origin).Magnitude / Config.Balloon.Speed, 0.15, 0.9)
	local landing: Vector3 = target
	Effects.lob(balloon, origin, landing, duration, function()
		splash(player, landing, color)
	end)
end

local function makeTool(): Tool
	local tool = Instance.new("Tool")
	tool.Name = TOOL_NAME
	tool.RequiresHandle = false
	tool.CanBeDropped = false
	tool.ToolTip = "Click a player to splash them (not on their own island)"
	return tool
end

local function give(player: Player)
	local backpack = player:WaitForChild("Backpack", 10)
	local character = player.Character
	if not backpack or backpack:FindFirstChild(TOOL_NAME) or (character and character:FindFirstChild(TOOL_NAME)) then
		return
	end
	template:Clone().Parent = backpack
end

function BalloonService.init()
	template = makeTool()
end

function BalloonService.start()
	Remotes.event("ThrowBalloon").OnServerEvent:Connect(onThrow)
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			task.wait(0.35) -- after the Cloud Blaster, so it's tool 4
			give(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastThrow[player] = nil
	end)
end

return BalloonService
