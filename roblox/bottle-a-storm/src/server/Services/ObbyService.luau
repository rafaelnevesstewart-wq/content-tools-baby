-- Lobby parkour: a hidden path of cloud platforms that starts behind the
-- trees at the edge of the lobby island and climbs to a secret island.
-- Something to do between matches. Touch the glowing checkpoints on the way
-- up, then claim a free Epic kit at the shrine, once a day.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local RewardsData = require(Shared.RewardsData)

local Modules = script.Parent.Parent.Modules
local Notify = require(Modules.Notify)

local DataService = require(script.Parent.DataService)
local RewardService = require(script.Parent.RewardService)

local ObbyService = {}

local folder: Folder
local topPosition: Vector3
local reached: { [Player]: { [number]: boolean } } = {}

local function stepPosition(step: number): Vector3
	local angle = math.rad(Config.Obby.StartAngle + (step - 1) * Config.Obby.StepAngle)
	local height = Config.Obby.BaseHeight + (step - 1) * Config.Obby.Rise
	return Vector3.new(math.cos(angle) * Config.Obby.Radius, height, math.sin(angle) * Config.Obby.Radius)
end

local function cloudPlatform(position: Vector3, size: number, checkpoint: boolean): Part
	local platform = Instance.new("Part")
	platform.Name = if checkpoint then "Checkpoint" else "CloudStep"
	platform.Shape = Enum.PartType.Cylinder
	platform.Size = Vector3.new(1.4, size, size)
	platform.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	platform.Anchored = true
	platform.Color = if checkpoint then Color3.fromRGB(170, 230, 255) else Color3.fromRGB(245, 247, 252)
	platform.Material = if checkpoint then Enum.Material.Neon else Enum.Material.SmoothPlastic
	platform.Transparency = if checkpoint then 0.2 else 0
	platform.Parent = folder
	local wisps = Instance.new("ParticleEmitter")
	wisps.Texture = "rbxasset://textures/particles/smoke_main.dds"
	wisps.Color = ColorSequence.new(Color3.fromRGB(245, 247, 252))
	wisps.Size = NumberSequence.new(size * 0.35, size * 0.5)
	wisps.Transparency = NumberSequence.new(0.5, 1)
	wisps.Lifetime = NumberRange.new(1.5, 2.5)
	wisps.Rate = 2
	wisps.Speed = NumberRange.new(0.2, 0.5)
	wisps.SpreadAngle = Vector2.new(180, 180)
	wisps.Parent = platform
	return platform
end

local function claim(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local progress = reached[player] or {}
	for _, step in Config.Obby.Checkpoints do
		if not progress[step] then
			Notify.player(player, "🏔️ Climb the sky path and touch every glowing checkpoint first!", "warn")
			return
		end
	end
	local today = RewardsData.today(os.time())
	if data.obby.lastDay == today then
		Notify.player(player, "🏔️ You already claimed today's kit. Come back tomorrow!", "info")
		return
	end
	local problem = RewardService.giveKit(player, RewardService.randomKit(4), nil)
	if problem then
		Notify.player(player, problem, "warn")
		return
	end
	data.obby.lastDay = today
	data.stats.obbyClears += 1
	Notify.allExcept(
		player,
		"🏔️ " .. player.DisplayName .. " climbed to the Secret Sky Island and found an Epic kit!",
		"rare"
	)
end

function ObbyService.init()
	folder = Instance.new("Folder")
	folder.Name = "SecretSkyPath"
	folder.Parent = workspace
	for step = 1, Config.Obby.Steps do
		local checkpoint = table.find(Config.Obby.Checkpoints, step) ~= nil
		local size = if step == 1 then 4.5 else 6
		local platform = cloudPlatform(stepPosition(step), size, checkpoint)
		if checkpoint then
			platform.Touched:Connect(function(hit)
				local player = Players:GetPlayerFromCharacter(hit.Parent)
				if player then
					reached[player] = reached[player] or {}
					if not reached[player][step] then
						reached[player][step] = true
						Notify.player(player, "✨ Checkpoint! Keep climbing!", "success")
					end
				end
			end)
		end
	end

	-- The secret island and its shrine.
	topPosition = stepPosition(Config.Obby.Steps + 3) + Vector3.new(0, 2, 0)
	local island = Instance.new("Part")
	island.Name = "SecretIsland"
	island.Shape = Enum.PartType.Cylinder
	island.Size = Vector3.new(3, 30, 30)
	island.CFrame = CFrame.new(topPosition) * CFrame.Angles(0, 0, math.rad(90))
	island.Anchored = true
	island.Color = Color3.fromRGB(96, 132, 66)
	island.Material = Enum.Material.Grass
	island.Parent = folder
	local under = Instance.new("Part")
	under.Shape = Enum.PartType.Ball
	under.Size = Vector3.one * 24
	under.CFrame = CFrame.new(topPosition - Vector3.new(0, 9, 0))
	under.Anchored = true
	under.Color = Color3.fromRGB(102, 98, 94)
	under.Material = Enum.Material.Rock
	under.Parent = folder
	local shrine = Instance.new("Part")
	shrine.Name = "Shrine"
	shrine.Size = Vector3.new(4, 3, 4)
	shrine.CFrame = CFrame.new(topPosition + Vector3.new(0, 3, 0))
	shrine.Anchored = true
	shrine.Color = Color3.fromRGB(235, 230, 245)
	shrine.Material = Enum.Material.Marble
	shrine.Parent = folder
	local glow = Instance.new("Part")
	glow.Shape = Enum.PartType.Ball
	glow.Size = Vector3.one * 2.2
	glow.CFrame = CFrame.new(topPosition + Vector3.new(0, 5.8, 0))
	glow.Anchored = true
	glow.CanCollide = false
	glow.Color = Color3.fromRGB(255, 200, 60)
	glow.Material = Enum.Material.Neon
	glow.Parent = folder
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 210, 110)
	light.Range = 18
	light.Brightness = 2
	light.Parent = glow
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Claim a free Epic kit"
	prompt.ObjectText = "🏔️ Secret Sky Shrine"
	prompt.HoldDuration = 1
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = shrine
	prompt.Triggered:Connect(claim)
end

function ObbyService.start()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			reached[player] = {} -- start the climb again after respawning
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		reached[player] = nil
	end)
end

return ObbyService
