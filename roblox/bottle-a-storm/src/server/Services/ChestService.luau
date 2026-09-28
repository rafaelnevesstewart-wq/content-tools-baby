-- The 🎁 Mystery Chest in the castle courtyard: open it once a day for a
-- random prize (Sparks, a kit, a cosmetic you don't have, wheel spins, or
-- rarely a big Sparks jackpot).

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local CosmeticsData = require(Shared.CosmeticsData)
local RewardsData = require(Shared.RewardsData)

local Modules = script.Parent.Parent.Modules
local Effects = require(Modules.Effects)
local Juice = require(Modules.Juice)
local Notify = require(Modules.Notify)
local WorldBuilder = require(Modules.WorldBuilder)

local DataService = require(script.Parent.DataService)
local RewardService = require(script.Parent.RewardService)

local ChestService = {}

local rng = Random.new()
local lid: BasePart
local lidClosed: CFrame
local busy = false

type Prize = { weight: number, give: (Player, any) -> () }

-- A Sparks cosmetic you don't own yet (nil if you have them all).
local function unownedCosmetic(data: any): string?
	local options = {}
	for _, item in CosmeticsData.Items do
		if
			item.cost > 0
			and item.cost <= 6000
			and not item.robux
			and not item.season
			and not item.achievement
			and not data.cosmetics.owned[item.id]
		then
			table.insert(options, item.id)
		end
	end
	return if #options > 0 then options[rng:NextInteger(1, #options)] else nil
end

local PRIZES: { Prize } = {
	{
		weight = 45,
		give = function(player)
			RewardService.grant(player, { kind = "sparks", amount = rng:NextInteger(8, 50) * 50 })
		end,
	},
	{
		weight = 25,
		give = function(player)
			RewardService.grant(player, { kind = "kit", rarity = rng:NextInteger(2, 4) })
		end,
	},
	{
		weight = 15,
		give = function(player, data)
			local id = unownedCosmetic(data)
			if id then
				RewardService.grant(player, { kind = "cosmetic", id = id })
			else
				RewardService.grant(player, { kind = "sparks", amount = 3000 })
			end
		end,
	},
	{
		weight = 10,
		give = function(player, data)
			data.spin.extra += 2
			Notify.player(player, "🎡 2 free prize wheel spins! (🎁 Rewards → Wheel)", "success")
		end,
	},
	{
		weight = 5,
		give = function(player)
			Notify.all("🎁💰 " .. player.DisplayName .. " hit the Mystery Chest JACKPOT!", "rare")
			RewardService.grant(player, { kind = "sparks", amount = 10000 })
		end,
	},
}

local function pick(): Prize
	local total = 0
	for _, prize in PRIZES do
		total += prize.weight
	end
	local roll = rng:NextNumber(0, total)
	for _, prize in PRIZES do
		roll -= prize.weight
		if roll <= 0 then
			return prize
		end
	end
	return PRIZES[1]
end

local function publish(player: Player)
	local data = DataService.get(player)
	if data then
		player:SetAttribute("ChestReady", data.chest.lastDay ~= RewardsData.today(os.time()))
	end
end

-- The lid swings open, sparkles burst out, and it closes again.
local function animate(at: Vector3)
	if busy then
		return
	end
	busy = true
	local open = lidClosed * CFrame.new(0, 0, 1.55) * CFrame.Angles(math.rad(100), 0, 0) * CFrame.new(0, 0, -1.55)
	TweenService:Create(lid, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = open })
		:Play()
	Effects.confetti(at + Vector3.new(0, 2, 0), 40)
	task.delay(2, function()
		TweenService:Create(lid, TweenInfo.new(0.4), { CFrame = lidClosed }):Play()
		busy = false
	end)
end

local function onOpen(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local today = RewardsData.today(os.time())
	if data.chest.lastDay == today then
		Notify.player(player, "🎁 You already opened today's chest. Come back tomorrow!", "info")
		return
	end
	data.chest.lastDay = today
	data.chest.opened += 1
	publish(player)
	animate(lid.Position)
	Juice.sound(player, "chime")
	local ok, problem = pcall(pick().give, player, data)
	if not ok then
		warn("[Bottle a Storm] Mystery chest prize failed: " .. tostring(problem))
		RewardService.grant(player, { kind = "sparks", amount = 500 })
	end
end

local function build(): BasePart
	local frame = WorldBuilder.LobbySpots.chest
	local model = Instance.new("Model")
	model.Name = "MysteryChest"
	local wood = Color3.fromRGB(122, 74, 40)
	local gold = Color3.fromRGB(230, 184, 70)
	local function piece(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = cframe
		p.Color = color
		p.Material = material
		p.Parent = model
		return p
	end
	local body = piece("Body", Vector3.new(4.4, 2.4, 3), frame * CFrame.new(0, 1.2, 0), wood, Enum.Material.WoodPlanks)
	for _, x in { -1.6, 1.6 } do
		piece("Band", Vector3.new(0.35, 2.45, 3.05), frame * CFrame.new(x, 1.2, 0), gold, Enum.Material.Foil)
	end
	lid = piece("Lid", Vector3.new(4.5, 0.9, 3.1), frame * CFrame.new(0, 2.85, 0), wood, Enum.Material.WoodPlanks)
	lidClosed = lid.CFrame
	for _, x in { -1.6, 1.6 } do
		local band =
			piece("LidBand", Vector3.new(0.36, 0.95, 3.12), lidClosed * CFrame.new(x, 0, 0), gold, Enum.Material.Foil)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = lid
		weld.Part1 = band
		weld.Parent = band
		band.Anchored = false
	end
	local lock = piece("Lock", Vector3.new(0.7, 0.8, 0.25), frame * CFrame.new(0, 2.3, -1.6), gold, Enum.Material.Foil)
	local light = Instance.new("PointLight")
	light.Color = gold
	light.Range = 12
	light.Brightness = 1.5
	light.Parent = lock
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = Color3.fromRGB(255, 230, 140)
	sparkles.Parent = lock
	-- A stone plinth under it.
	piece(
		"Plinth",
		Vector3.new(6, 0.4, 4.6),
		frame * CFrame.new(0, 0.2, 0),
		Color3.fromRGB(200, 196, 188),
		Enum.Material.Marble
	)

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 56)
	gui.StudsOffset = Vector3.new(0, 4.5, 0)
	gui.MaxDistance = 80
	gui.Parent = body
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(255, 225, 120)
	text.TextStrokeTransparency = 0.3
	text.Text = "🎁 Mystery Chest\nA free prize every day!"
	text.Parent = gui

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open"
	prompt.ObjectText = "Mystery Chest"
	prompt.HoldDuration = 0.6
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = body
	prompt.Triggered:Connect(onOpen)

	model.Parent = workspace
	return body
end

function ChestService.start()
	build()
	DataService.ProfileLoaded:Connect(publish)
	for _, player in Players:GetPlayers() do
		publish(player)
	end
	-- A new day makes everyone's chest ready again.
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				publish(player)
			end
		end
	end)
end

return ChestService
