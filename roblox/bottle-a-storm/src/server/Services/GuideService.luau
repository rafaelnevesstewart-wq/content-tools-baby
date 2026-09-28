-- 🧭 Guide Gale: a friendly guide by the castle gate who walks new players
-- through the game (GuideData.Steps, in order). Talk to her to start; each
-- step pays Sparks and finishing them all gives an Epic kit, a Sparks bonus
-- and the 🎓 Storm Scholar title. Your screen shows the current step
-- (GuideTracker, from the "GuideStep" attribute).

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Format)
local GuideData = require(Shared.GuideData)
local RewardsData = require(Shared.RewardsData)

local Modules = script.Parent.Parent.Modules
local Effects = require(Modules.Effects)
local Juice = require(Modules.Juice)
local Notify = require(Modules.Notify)
local WorldBuilder = require(Modules.WorldBuilder)
local Usage = require(Modules.Usage)

local ChestService = require(script.Parent.ChestService)
local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local ItemShopService = require(script.Parent.ItemShopService)
local MatchService = require(script.Parent.MatchService)
local RewardService = require(script.Parent.RewardService)

local GuideService = {}

local NAME = "Guide Gale"
local tipIndex = 0

local function guideOf(data: any): { step: number, done: boolean }
	data.guide = data.guide or { step = 1, done = false }
	return data.guide
end

local function publish(player: Player, data: any)
	local guide = guideOf(data)
	player:SetAttribute("GuideStep", if guide.done then nil else guide.step)
	-- Brand-new players see "talk to Gale" even before they have.
	player:SetAttribute("GuideNew", if (data.stats.matches or 0) < 3 then true else nil)
end

-- Some steps might already be done when you reach them.
local function alreadyDone(player: Player, data: any, key: string): boolean
	if key == "chest" then
		return data.chest.lastDay == RewardsData.today(os.time())
	elseif key == "base" then
		return player:GetAttribute("BasePlot") ~= nil
	end
	return false
end

local advance: (Player, string) -> ()

local function finish(player: Player, data: any)
	local guide = guideOf(data)
	guide.done = true
	data.stats.guideDone = 1
	Usage.track("guideFinished", player)
	data.sparks += GuideData.FinalSparks
	IncomeService.sync(player)
	RewardService.grant(player, { kind = "kit", rarity = GuideData.FinalKitRarity })
	Notify.player(
		player,
		"🎓 "
			.. NAME
			.. ": You did it! You know everything now. Here's an Epic kit, ⚡"
			.. Format.number(GuideData.FinalSparks)
			.. " and the 🎓 Storm Scholar title!",
		"rare"
	)
	Juice.sound(player, "win")
	publish(player, data)
end

advance = function(player: Player, key: string)
	local data = DataService.get(player)
	if not data then
		return
	end
	local guide = guideOf(data)
	local step = GuideData.Steps[guide.step]
	if guide.done or not step or step.key ~= key then
		return
	end
	data.sparks += step.sparks
	IncomeService.sync(player)
	Juice.sound(player, "chime")
	guide.step += 1
	local nextStep = GuideData.Steps[guide.step]
	if not nextStep then
		finish(player, data)
		return
	end
	Notify.player(
		player,
		"🧭 Step done! +⚡"
			.. step.sparks
			.. ". Next: "
			.. nextStep.text
			.. " ("
			.. guide.step
			.. "/"
			.. #GuideData.Steps
			.. ")",
		"success"
	)
	publish(player, data)
	if alreadyDone(player, data, nextStep.key) then
		task.delay(1.5, advance, player, nextStep.key)
	end
end

local function talk(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local guide = guideOf(data)
	if guide.done then
		tipIndex = tipIndex % #GuideData.Tips + 1
		Notify.player(player, "🧭 " .. NAME .. ": " .. GuideData.Tips[tipIndex], "info")
		return
	end
	if guide.step == 1 then
		Notify.player(
			player,
			"🧭 "
				.. NAME
				.. ": Welcome to Bottle a Storm! Protect your bed, break theirs. Follow my steps (top right) for prizes!",
			"info"
		)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			Effects.confetti(root.Position, 12)
		end
		advance(player, "talk")
		return
	end
	local step = GuideData.Steps[guide.step]
	Notify.player(player, "🧭 " .. NAME .. ": Your next step: " .. step.text .. ". You can do it!", "info")
end

-- Guide Gale herself: a Roblox avatar with a compass sign.
local function build()
	local frame = WorldBuilder.LobbySpots.guide
	local model = Instance.new("Model")
	model.Name = "GuideGale"
	local base = Instance.new("Part")
	base.Name = "Stand"
	base.Anchored = true
	base.Shape = Enum.PartType.Cylinder
	base.Size = Vector3.new(0.6, 5, 5)
	base.CFrame = frame * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.rad(90))
	base.Color = Color3.fromRGB(80, 150, 220)
	base.Material = Enum.Material.Marble
	base.Parent = model
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 60)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 8, 0)
	gui.MaxDistance = 90
	gui.AlwaysOnTop = false
	gui.Parent = base
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextStrokeTransparency = 0.3
	label.TextColor3 = Color3.fromRGB(255, 230, 120)
	label.Text = "🧭 Guide Gale\nNew here? Talk to me!"
	label.Parent = gui
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Talk"
	prompt.ObjectText = "🧭 " .. NAME
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = base
	prompt.Triggered:Connect(talk)
	model.Parent = workspace
	task.spawn(function()
		local ok, guide = pcall(function()
			local description = Instance.new("HumanoidDescription")
			local skin = Color3.fromRGB(234, 184, 146)
			description.HeadColor = skin
			description.LeftArmColor = skin
			description.RightArmColor = skin
			description.TorsoColor = Color3.fromRGB(80, 150, 220)
			description.LeftLegColor = Color3.fromRGB(50, 60, 90)
			description.RightLegColor = Color3.fromRGB(50, 60, 90)
			return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
		end)
		if not ok or not guide then
			return
		end
		guide.Name = NAME
		for _, p in guide:GetDescendants() do
			if p:IsA("BasePart") then
				p.Anchored = p.Name == "HumanoidRootPart"
				p.CanCollide = false
			end
		end
		local humanoid = guide:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.DisplayName = NAME
			humanoid.NameDisplayDistance = 0
			humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		end
		guide:PivotTo(frame * CFrame.new(0, 3.6, 0))
		guide.Parent = model
		if humanoid then
			local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
			animator.Parent = humanoid
			local animation = Instance.new("Animation")
			animation.AnimationId = "rbxassetid://507766666"
			pcall(function()
				local track = animator:LoadAnimation(animation)
				track.Looped = true
				track:Play()
			end)
		end
	end)
end

-- Starts someone's guide steps over (admins, for testing).
function GuideService.restart(player: Player)
	local data = DataService.get(player)
	if data then
		data.guide = { step = 1, done = false }
		publish(player, data)
	end
end

function GuideService.start()
	build()
	DataService.ProfileLoaded:Connect(function(player, data)
		publish(player, data)
	end)
	ChestService.Opened:Connect(function(player)
		advance(player, "chest")
	end)
	MatchService.Collected:Connect(function(player)
		advance(player, "collect")
	end)
	ItemShopService.Bought:Connect(function(player)
		advance(player, "buy")
	end)
	MatchService.Killed:Connect(function(killer)
		if killer then
			advance(killer, "knockout")
		end
	end)
	MatchService.BotKilled:Connect(function(killer)
		advance(killer, "knockout")
	end)
	MatchService.BedBroken:Connect(function(breaker)
		if typeof(breaker) == "Instance" and breaker:IsA("Player") then
			advance(breaker, "bed")
		end
	end)
	MatchService.Played:Connect(function(player)
		advance(player, "play")
	end)
	local function watchBase(player: Player)
		player:GetAttributeChangedSignal("BasePlot"):Connect(function()
			if player:GetAttribute("BasePlot") then
				advance(player, "base")
			end
		end)
	end
	Players.PlayerAdded:Connect(watchBase)
	for _, player in Players:GetPlayers() do
		watchBase(player)
	end
end

return GuideService
