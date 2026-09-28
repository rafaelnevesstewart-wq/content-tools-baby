-- 🌠 Shooting-star wishes: at night, shooting stars streak across the sky
-- over the lobby islands and land somewhere as a glowing Wish Star. Find it
-- and hold E to make a wish for a surprise prize (Sparks, a kit or a
-- cosmetic). Each star grants 3 wishes, one per player, and fades after a
-- while; you can make up to MAX_A_DAY wishes a day.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local CosmeticsData = require(Shared.CosmeticsData)
local RewardsData = require(Shared.RewardsData)

local Modules = script.Parent.Parent.Modules
local Effects = require(Modules.Effects)
local Juice = require(Modules.Juice)
local Notify = require(Modules.Notify)
local Usage = require(Modules.Usage)

local CosmeticService = require(script.Parent.CosmeticService)
local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local RewardService = require(script.Parent.RewardService)

local WishService = {}

local EVERY = { 20, 40 } -- seconds between stars at night
local WISHES_PER_STAR = 3
local STAR_SECONDS = 45
local MAX_A_DAY = 10

local L = Config.Lobby.Center
local PLACES = {
	{ name = "by the castle", center = L, radius = 82 },
	{
		name = "on 🎯 Games Island",
		center = L + Vector3.new(Config.Lobby.SideDistance, 0, 0),
		radius = Config.Lobby.GamesRadius - 6,
	},
	{
		name = "on 🏗️ Base Island",
		center = L - Vector3.new(Config.Lobby.SideDistance, 0, 0),
		radius = Config.Lobby.BaseRadius - 6,
	},
	{
		name = "on 🛍️ Shop Street",
		center = L - Vector3.new(0, 0, Config.Lobby.StreetDistance),
		radius = Config.Lobby.StreetRadius - 6,
	},
}

type Prize = { weight: number, give: (Player, any) -> string? }

local rng = Random.new()

local function sparks(amount: number): Prize
	return {
		weight = 0,
		give = function(player, data)
			data.sparks += amount
			IncomeService.sync(player)
			return "⚡" .. amount .. " Sparks"
		end,
	}
end

local PRIZES: { Prize } = {}
local function add(weight: number, prize: Prize)
	prize.weight = weight
	table.insert(PRIZES, prize)
end
add(40, sparks(200))
add(20, sparks(500))
add(6, sparks(1500))
add(14, {
	weight = 0,
	give = function(player)
		RewardService.grant(player, { kind = "kit", rarity = 3 }, nil, true)
		return "a Rare kit"
	end,
})
add(4, {
	weight = 0,
	give = function(player)
		RewardService.grant(player, { kind = "kit", rarity = 4 }, nil, true)
		return "an Epic kit"
	end,
})
add(8, {
	weight = 0,
	give = function(player, data)
		local options = {}
		for _, item in CosmeticsData.Items do
			if
				item.cost > 0
				and item.cost <= 5000
				and not item.robux
				and not item.season
				and not item.achievement
				and not data.cosmetics.owned[item.id]
			then
				table.insert(options, item)
			end
		end
		if #options == 0 then
			data.sparks += 1000
			IncomeService.sync(player)
			return "⚡1000 Sparks"
		end
		local item = options[rng:NextInteger(1, #options)]
		CosmeticService.grant(player, item.id)
		return item.emoji .. " " .. item.name
	end,
})

local function pickPrize(): Prize
	local total = 0
	for _, prize in PRIZES do
		total += prize.weight
	end
	local roll = rng:NextNumber() * total
	for _, prize in PRIZES do
		roll -= prize.weight
		if roll <= 0 then
			return prize
		end
	end
	return PRIZES[1]
end

local function wish(player: Player, star: BasePart, wished: { [Player]: boolean })
	local data = DataService.get(player)
	if not data or wished[player] or not star.Parent then
		return
	end
	data.wishes = data.wishes or { day = -1, count = 0 }
	local today = RewardsData.today(os.time())
	if data.wishes.day ~= today then
		data.wishes.day = today
		data.wishes.count = 0
	end
	if data.wishes.count >= MAX_A_DAY then
		Notify.player(player, "🌠 You've made all your wishes for today. More tomorrow night!", "info")
		return
	end
	wished[player] = true
	data.wishes.count += 1
	data.stats.wishes = (data.stats.wishes or 0) + 1
	Usage.track("wish", player)
	local ok, what = pcall(pickPrize().give, player, data)
	Effects.confetti(star.Position, 30)
	Juice.sound(player, "chime")
	Notify.player(
		player,
		"🌠 Your wish came true: " .. (if ok and what then what else "⚡200 Sparks") .. "!",
		"rare"
	)
	if not ok then
		IncomeService.addSparks(player, 200)
	end
	local count = 0
	for _ in wished do
		count += 1
	end
	if count >= WISHES_PER_STAR then
		star:Destroy()
	end
end

local function groundAt(point: Vector3): Vector3?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local characters = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(characters, player.Character)
		end
	end
	params.FilterDescendantsInstances = characters
	local hit = workspace:Raycast(point + Vector3.new(0, 60, 0), Vector3.new(0, -100, 0), params)
	return if hit and hit.Instance == workspace.Terrain then hit.Position else nil
end

local function shootingStar()
	local place = PLACES[rng:NextInteger(1, #PLACES)]
	local landing: Vector3? = nil
	for _ = 1, 10 do
		local angle, distance = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, place.radius)
		landing = groundAt(place.center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance))
		if landing then
			break
		end
	end
	if not landing then
		return
	end
	local target = landing :: Vector3
	-- The streak across the sky.
	local star = Instance.new("Part")
	star.Name = "ShootingStar"
	star.Anchored = true
	star.CanCollide = false
	star.CanQuery = false
	star.Shape = Enum.PartType.Ball
	star.Size = Vector3.one * 1.6
	star.Material = Enum.Material.Neon
	star.Color = Color3.fromRGB(255, 245, 200)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.6, 0)
	a0.Parent = star
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.6, 0)
	a1.Parent = star
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.8
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 240, 180), Color3.fromRGB(150, 200, 255))
	trail.Transparency = NumberSequence.new(0, 1)
	trail.LightEmission = 1
	trail.Parent = star
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 240, 190)
	light.Range = 30
	light.Brightness = 3
	light.Parent = star
	local from = target + Vector3.new(rng:NextNumber(-200, 200), 220, rng:NextNumber(-200, 200))
	star.CFrame = CFrame.new(from)
	star.Parent = workspace
	local fall = TweenService:Create(star, TweenInfo.new(2.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		CFrame = CFrame.new(target + Vector3.new(0, 1.6, 0)),
	})
	fall:Play()
	for _, player in Players:GetPlayers() do
		if not player:GetAttribute("InMatch") then
			Notify.player(
				player,
				"🌠 A shooting star is falling " .. place.name .. "! Find it and make a wish!",
				"rare"
			)
		end
	end
	fall.Completed:Wait()
	-- The Wish Star, bobbing and sparkling where it landed.
	star.Size = Vector3.one * 2.2
	trail.Enabled = false
	Effects.confetti(target, 20)
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = Color3.fromRGB(255, 240, 160)
	sparkles.Parent = star
	TweenService:Create(
		star,
		TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ CFrame = CFrame.new(target + Vector3.new(0, 2.6, 0)) }
	):Play()
	local wished: { [Player]: boolean } = {}
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Make a wish"
	prompt.ObjectText = "🌠 Wish Star"
	prompt.HoldDuration = 1
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = star
	prompt.Triggered:Connect(function(player)
		wish(player, star, wished)
	end)
	Debris:AddItem(star, STAR_SECONDS)
end

-- Sends a shooting star right now, night or not (admins, for testing).
function WishService.starNow()
	task.spawn(shootingStar)
end

function WishService.start()
	task.spawn(function()
		while true do
			task.wait(rng:NextNumber(EVERY[1], EVERY[2]))
			if workspace:GetAttribute("IsNight") then
				local ok, problem = pcall(shootingStar)
				if not ok then
					warn("[Bottle a Storm] Shooting star failed: " .. tostring(problem))
				end
			end
		end
	end)
end

return WishService
