-- Walk speed (boots, carrying a stolen storm), stuns, and respawning anyone
-- who falls off the sky islands.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local DataService = require(script.Parent.DataService)

local MovementService = {}

local stunnedUntil: { [Player]: number } = {}
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
	local speed = Config.Movement.BaseWalkSpeed + boots * Config.Boots.SpeedPerLevel
	if player:GetAttribute("Carrying") then
		speed *= Config.Steal.CarrySpeedMultiplier
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
