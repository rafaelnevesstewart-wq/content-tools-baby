-- 👑 King of the Hill (a match mode): a glowing hill in the middle of the
-- middle island. Every second that only one team has players (or bots) on
-- it, that team scores a point; if two teams are on it, it's contested and
-- nobody scores. First team to Config.Hill.Target wins (beds still count:
-- you can also win the normal way).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local Modules = script.Parent.Parent.Modules
local Juice = require(Modules.Juice)
local Notify = require(Modules.Notify)

local BotService = require(script.Parent.BotService)
local MatchService = require(script.Parent.MatchService)

local HillService = {}

local CENTER = Vector3.new(0, 0, 0)
local round = 0
local model: Model? = nil

local function build(): (BasePart, BasePart)
	local hill = Instance.new("Model")
	hill.Name = "Hill"
	local function piece(props: { [string]: any }): Part
		local p = Instance.new("Part")
		p.Anchored = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		for key, value in props do
			(p :: any)[key] = value
		end
		p.Parent = hill
		return p
	end
	local radius = Config.Hill.Radius
	piece({
		Name = "HillStone",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, radius * 2 + 2, radius * 2 + 2),
		CFrame = CFrame.new(CENTER + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(150, 146, 138),
		Material = Enum.Material.Cobblestone,
	})
	local ring = piece({
		Name = "HillRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, radius * 2, radius * 2),
		CFrame = CFrame.new(CENTER + Vector3.new(0, 1.05, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 255, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.55,
		CanCollide = false,
	})
	piece({
		Name = "FlagPole",
		Size = Vector3.new(0.6, 18, 0.6),
		CFrame = CFrame.new(CENTER + Vector3.new(0, 10, 0)),
		Color = Color3.fromRGB(80, 80, 90),
		Material = Enum.Material.Metal,
	})
	local flag = piece({
		Name = "Flag",
		Size = Vector3.new(0.2, 4, 6),
		CFrame = CFrame.new(CENTER + Vector3.new(0, 16.5, 3.2)),
		Color = Color3.fromRGB(255, 255, 255),
		Material = Enum.Material.Fabric,
		CanCollide = false,
	})
	local light = Instance.new("PointLight")
	light.Range = 30
	light.Brightness = 2
	light.Parent = ring
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 40)
	gui.StudsOffset = Vector3.new(0, 12, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 600
	gui.Parent = flag
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 220, 110)
	label.TextStrokeTransparency = 0.2
	label.Text = "👑 THE HILL"
	label.Parent = gui
	hill.Parent = workspace
	model = hill
	return ring, flag
end

local function onHill(position: Vector3): boolean
	local offset = position - CENTER
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= Config.Hill.Radius and offset.Y > -3 and offset.Y < 14
end

local function run(myRound: number)
	local ring, flag = build()
	local scores: { [any]: number } = {}
	local lastHolder: any = nil
	Notify.all(
		"👑 King of the Hill! Hold the hill in the middle island alone to score. First to "
			.. Config.Hill.Target
			.. " wins!",
		"rare"
	)
	while round == myRound and MatchService.phase() == "playing" do
		task.wait(1)
		local present: { [any]: boolean } = {}
		local count = 0
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local team = MatchService.teamOf(player)
			if root and team and MatchService.isPlaying(player) and onHill(root.Position) then
				if not present[team] then
					count += 1
				end
				present[team] = true
			end
		end
		for _, bot in BotService.positions() do
			if onHill(bot.position) then
				if not present[bot.team] then
					count += 1
				end
				present[bot.team] = true
			end
		end
		local holder = nil
		if count == 1 then
			holder = next(present)
		end
		local color = if holder
			then holder.info.color
			elseif count > 1 then Color3.fromRGB(255, 80, 80)
			else Color3.new(1, 1, 1)
		TweenService:Create(ring, TweenInfo.new(0.4), { Color = color }):Play()
		flag.Color = color
		local light = ring:FindFirstChildOfClass("PointLight")
		if light then
			light.Color = color
		end
		if holder then
			scores[holder] = (scores[holder] or 0) + 1
			if holder ~= lastHolder then
				Notify.all("👑 " .. holder.info.emoji .. " " .. holder.info.name .. " took the hill!", "info")
			end
			if scores[holder] >= Config.Hill.Target then
				Notify.all("👑 " .. holder.info.emoji .. " " .. holder.info.name .. " is King of the Hill!", "rare")
				for _, member in holder.members do
					if member.Parent then
						Juice.sound(member, "win")
					end
				end
				MatchService.declareWinner(holder)
				break
			end
		end
		lastHolder = holder
		local published = {}
		for team, points in scores do
			published[team.info.key] = points
		end
		workspace:SetAttribute("HillScores", HttpService:JSONEncode(published))
		workspace:SetAttribute("HillHolder", if holder then holder.info.key elseif count > 1 then "contested" else "")
	end
end

local function clear()
	round += 1
	if model then
		model:Destroy()
		model = nil
	end
	workspace:SetAttribute("HillScores", nil)
	workspace:SetAttribute("HillHolder", nil)
end

function HillService.start()
	MatchService.MatchStarted:Connect(function()
		clear()
		if workspace:GetAttribute("MatchMode") ~= "Hill" then
			return
		end
		local myRound = round
		workspace:SetAttribute("HillTarget", Config.Hill.Target)
		task.spawn(function()
			local ok, problem = pcall(run, myRound)
			if not ok then
				warn("[Bottle a Storm] King of the Hill failed: " .. tostring(problem))
			end
		end)
	end)
	MatchService.MatchEnded:Connect(clear)
end

return HillService
