-- Walk speed (boots, carrying a stolen storm), stuns, and respawning anyone
-- who falls off the sky islands.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local ThiefStyles = require(Shared.ThiefStyles)

local Juice = require(script.Parent.Parent.Modules.Juice)

local DataService = require(script.Parent.DataService)

local MovementService = {}

local stunnedUntil: { [Player]: number } = {}
local soakedUntil: { [Player]: number } = {}
local defaultJump: { [Humanoid]: { power: number, height: number } } = {}

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

function MovementService.isStunned(player: Player): boolean
	return (stunnedUntil[player] or 0) > os.clock()
end

-- Recomputes speed and jump from boots, carrying and stun state.
function MovementService.refresh(player: Player)
	local humanoid = humanoidOf(player)
	if not humanoid then
		return
	end
	local jump = defaultJump[humanoid]
	if not jump then
		jump = { power = humanoid.JumpPower, height = humanoid.JumpHeight }
		defaultJump[humanoid] = jump
		humanoid.Destroying:Connect(function()
			defaultJump[humanoid] = nil
		end)
	end

	if MovementService.isStunned(player) then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
		return
	end

	local data = DataService.get(player)
	local boots = if data then data.bootsLevel else 0
	local speed = Config.Movement.BaseWalkSpeed
		+ boots * Config.Boots.SpeedPerLevel
		+ (player:GetAttribute("RideSpeed") or 0)
	if player:GetAttribute("Carrying") then
		speed *= if player:GetAttribute("ThiefStyle") == "UmbrellaTank"
			then ThiefStyles.TankCarrySpeedMultiplier
			else Config.Steal.CarrySpeedMultiplier
	end
	if (soakedUntil[player] or 0) > os.clock() then
		speed *= Config.Balloon.SoakSpeedMultiplier
	end
	humanoid.WalkSpeed = speed
	humanoid.JumpPower = jump.power
	humanoid.JumpHeight = jump.height
end

-- Freezes the player in place with a crackle of lightning.
function MovementService.stun(player: Player, seconds: number)
	local untilTime = os.clock() + seconds
	stunnedUntil[player] = math.max(stunnedUntil[player] or 0, untilTime)
	MovementService.refresh(player)
	Juice.shake(player, 1)
	Juice.sound(player, "zap")

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = Color3.fromRGB(255, 240, 90)
		sparkles.Parent = root
		task.delay(seconds, function()
			sparkles:Destroy()
		end)
	end

	task.delay(seconds + 0.05, function()
		if player.Parent and not MovementService.isStunned(player) then
			MovementService.refresh(player)
		end
	end)
end

-- Soaked by a water balloon or raindrop: slower for a moment, with drips.
function MovementService.soak(player: Player, seconds: number)
	soakedUntil[player] = math.max(soakedUntil[player] or 0, os.clock() + seconds)
	MovementService.refresh(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and not root:FindFirstChild("SoakDrips") then
		local drips = Instance.new("ParticleEmitter")
		drips.Name = "SoakDrips"
		drips.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		drips.Color = ColorSequence.new(Color3.fromRGB(120, 200, 255))
		drips.Size = NumberSequence.new(0.35, 0.1)
		drips.Speed = NumberRange.new(1, 3)
		drips.Acceleration = Vector3.new(0, -30, 0)
		drips.Lifetime = NumberRange.new(0.4, 0.7)
		drips.Rate = 25
		drips.Parent = root
		task.delay(seconds, function()
			drips:Destroy()
		end)
	end
	task.delay(seconds + 0.05, function()
		if player.Parent then
			MovementService.refresh(player)
		end
	end)
end

function MovementService.start()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid", 10)
			stunnedUntil[player] = nil
			MovementService.refresh(player)
		end)
		if player.Character then
			MovementService.refresh(player)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		stunnedUntil[player] = nil
		soakedUntil[player] = nil
	end)
	DataService.ProfileLoaded:Connect(function(player)
		MovementService.refresh(player)
	end)

	-- Falling off the islands respawns you at home.
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local humanoid = humanoidOf(player)
				if root and humanoid and humanoid.Health > 0 and root.Position.Y < Config.World.VoidKillY then
					humanoid.Health = 0
				end
			end
		end
	end)
end

return MovementService
