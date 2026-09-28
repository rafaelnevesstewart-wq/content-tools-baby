-- 🌋 Random disasters in matches (Config.Disasters), a few minutes apart:
--   ☄️ Meteor Shower: meteors crash down (a red circle warns where), breaking
--      blocks and throwing people around.
--   🌋 Earthquake: the islands shake and placed blocks crack and crumble.
--   🌊 Flood: the sky fills with water up to your knees for 30 seconds, and
--      falling off the islands is safe while it lasts: swim back!
-- Not in the co-op modes, and a private server can turn them off
-- (🎟️ CustomData). The one on now is shared as the "Disaster" attribute.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local ClassData = require(Shared.ClassData)
local Config = require(Shared.Config)
local CustomData = require(Shared.CustomData)
local MatchData = require(Shared.MatchData)

local Modules = script.Parent.Parent.Modules
local Effects = require(Modules.Effects)
local Juice = require(Modules.Juice)
local Notify = require(Modules.Notify)
local Usage = require(Modules.Usage)

local BlockService = require(script.Parent.BlockService)
local MatchService = require(script.Parent.MatchService)

local DisasterService = {}

local round = 0
local flooded = false
local rng = Random.new()

local KINDS = {
	Meteors = { emoji = "☄️", name = "Meteor Shower", warning = "Meteors are coming! Watch for red circles!" },
	Quake = { emoji = "🌋", name = "Earthquake", warning = "The ground is starting to rumble..." },
	Flood = { emoji = "🌊", name = "Flood", warning = "Water is rising! The islands are about to flood!" },
}
local ORDER = { "Meteors", "Quake", "Flood" }

-- The whole sky world where the water goes (lined up with the terrain grid).
local function floodRegion(): Region3
	local reach = Config.World.PlotRingDistance + Config.World.PlotRadius + 16
	return Region3.new(Vector3.new(-reach, -8, -reach), Vector3.new(reach, 4, reach)):ExpandToGrid(4)
end

local function unflood()
	if flooded then
		flooded = false
		pcall(function()
			workspace.Terrain:ReplaceMaterial(floodRegion(), 4, Enum.Material.Water, Enum.Material.Air)
		end)
	end
end

local function playing(): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		if MatchService.isPlaying(player) then
			table.insert(list, player)
		end
	end
	return list
end

-- Somewhere on an island: near a random player half the time.
local function randomTarget(): Vector3
	local players = playing()
	if #players > 0 and rng:NextNumber() < 0.5 then
		local root = players[rng:NextInteger(1, #players)].Character
		local part = root and root:FindFirstChild("HumanoidRootPart") :: BasePart?
		if part then
			return part.Position + Vector3.new(rng:NextNumber(-10, 10), 0, rng:NextNumber(-10, 10))
		end
	end
	local frames = MatchService.teamFrames()
	if #frames > 0 and rng:NextNumber() < 0.6 then
		local frame = frames[rng:NextInteger(1, #frames)]
		local angle, distance = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, Config.World.PlotRadius - 8)
		return (frame * CFrame.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)).Position
	end
	local angle, distance = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, Config.World.CenterRadius - 20)
	return Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
end

local function groundAt(point: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local characters = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(characters, player.Character)
		end
	end
	params.FilterDescendantsInstances = characters
	local hit = workspace:Raycast(Vector3.new(point.X, 120, point.Z), Vector3.new(0, -200, 0), params)
	return if hit then hit.Position else Vector3.new(point.X, 0, point.Z)
end

local function meteor(myRound: number)
	local settings = Config.Disasters
	local target = groundAt(randomTarget())
	-- The warning circle.
	local circle = Instance.new("Part")
	circle.Anchored = true
	circle.CanCollide = false
	circle.CanQuery = false
	circle.CanTouch = false
	circle.Shape = Enum.PartType.Cylinder
	circle.Size = Vector3.new(0.2, settings.MeteorRadius * 2, settings.MeteorRadius * 2)
	circle.CFrame = CFrame.new(target + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	circle.Color = Color3.fromRGB(255, 60, 40)
	circle.Material = Enum.Material.Neon
	circle.Transparency = 0.5
	circle.Parent = workspace
	Debris:AddItem(circle, 2.4)
	-- The meteor falls.
	local rock = Instance.new("Part")
	rock.Anchored = true
	rock.CanCollide = false
	rock.CanQuery = false
	rock.Shape = Enum.PartType.Ball
	rock.Size = Vector3.one * 4
	rock.Color = Color3.fromRGB(90, 60, 50)
	rock.Material = Enum.Material.CrackedLava
	rock.CFrame = CFrame.new(target + Vector3.new(rng:NextNumber(-30, 30), 140, rng:NextNumber(-30, 30)))
	local fire = Instance.new("Fire")
	fire.Size = 8
	fire.Heat = 12
	fire.Parent = rock
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 140, 60)
	light.Range = 20
	light.Brightness = 3
	light.Parent = rock
	rock.Parent = workspace
	local fall = TweenService:Create(rock, TweenInfo.new(2.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		CFrame = CFrame.new(target),
	})
	fall:Play()
	fall.Completed:Wait()
	rock:Destroy()
	if round ~= myRound or MatchService.phase() ~= "playing" then
		return
	end
	Effects.confetti(target, 25)
	BlockService.explode(target, settings.MeteorRadius, 3, { Obsidian = true })
	for _, player in playing() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid then
			local offset = root.Position - target
			local distance = offset.Magnitude
			if distance <= settings.MeteorRadius then
				local strength = 1 - distance / settings.MeteorRadius * 0.5
				humanoid:TakeDamage(settings.MeteorDamage * strength * ClassData.taken(player))
				local direction = if distance > 0.1 then offset.Unit else Vector3.yAxis
				Juice.knock(player, direction * 50 * strength + Vector3.new(0, 40, 0))
			end
			if distance < 50 then
				Juice.shake(player, math.clamp(1 - distance / 50, 0.2, 1))
				Juice.sound(player, "boom")
			end
		end
	end
end

local function run(key: string, myRound: number)
	local settings = Config.Disasters
	local kind = KINDS[key]
	local function stillOn(): boolean
		return round == myRound and MatchService.phase() == "playing"
	end
	Notify.all(kind.emoji .. " " .. kind.name .. "! " .. kind.warning, "warn")
	Usage.track("disaster:" .. key)
	workspace:SetAttribute("Disaster", key)
	task.wait(settings.Warning)
	if not stillOn() then
		return
	end
	if key == "Meteors" then
		for _ = 1, settings.Meteors do
			if not stillOn() then
				break
			end
			task.spawn(meteor, myRound)
			task.wait(rng:NextNumber(0.4, 1.1))
		end
		task.wait(3)
	elseif key == "Quake" then
		for _ = 1, settings.QuakeSeconds do
			if not stillOn() then
				break
			end
			BlockService.quake(settings.QuakeChance, 2)
			for _, player in playing() do
				Juice.shake(player, 0.8)
				Juice.knock(player, Vector3.new(rng:NextNumber(-12, 12), 6, rng:NextNumber(-12, 12)))
			end
			task.wait(1)
		end
	elseif key == "Flood" then
		flooded = true
		pcall(function()
			workspace.Terrain:ReplaceMaterial(floodRegion(), 4, Enum.Material.Air, Enum.Material.Water)
		end)
		Notify.all("🌊 FLOOD! Swim for it. Falling off is safe until the water drains!", "rare")
		local ends = os.clock() + settings.FloodSeconds
		while os.clock() < ends and stillOn() do
			task.wait(1)
		end
		unflood()
		if stillOn() then
			Notify.all("🌊 The water drained away. Careful at the edges again!", "info")
		end
	end
	if round == myRound then
		workspace:SetAttribute("Disaster", nil)
	end
end

-- Starts a disaster right now ("Meteors", "Quake" or "Flood"; admins, for
-- testing). False outside a match or for an unknown one.
function DisasterService.runNow(key: string): boolean
	if not KINDS[key] or MatchService.phase() ~= "playing" then
		return false
	end
	task.spawn(run, key, round)
	return true
end

function DisasterService.start()
	MatchService.MatchStarted:Connect(function()
		round += 1
		local myRound = round
		local mode = MatchData.mode(workspace:GetAttribute("MatchMode"))
		if not Config.Disasters.Enabled or (mode and mode.coop) or CustomData.get("disasters") == "Off" then
			return
		end
		task.spawn(function()
			local settings = Config.Disasters
			local last = ""
			task.wait(rng:NextNumber(settings.FirstAfter[1], settings.FirstAfter[2]))
			while round == myRound and MatchService.phase() == "playing" do
				local options = {}
				for _, key in ORDER do
					if key ~= last then
						table.insert(options, key)
					end
				end
				last = options[rng:NextInteger(1, #options)]
				local ok, problem = pcall(run, last, myRound)
				if not ok then
					warn("[Bottle a Storm] Disaster failed: " .. tostring(problem))
				end
				task.wait(rng:NextNumber(settings.Every[1], settings.Every[2]))
			end
		end)
	end)
	MatchService.MatchEnded:Connect(function()
		round += 1
		workspace:SetAttribute("Disaster", nil)
		unflood()
	end)
end

return DisasterService
