-- 🐾 Pets that help in matches (PetHelpers): while you're playing, the pet
-- you brought heals you, brings you blocks or resources, guards your bed or
-- breathes fire, depending on what it is. Stronger with pet levels. Your
-- screen shows what it does ("PetHelp").

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local CosmeticsData = require(Shared.CosmeticsData)
local PetHelpers = require(Shared.PetHelpers)
local PetLevels = require(Shared.PetLevels)

local Modules = script.Parent.Parent.Modules
local Effects = require(Modules.Effects)
local Juice = require(Modules.Juice)
local Notify = require(Modules.Notify)

local BlockService = require(script.Parent.BlockService)
local CombatService = require(script.Parent.CombatService)
local DataService = require(script.Parent.DataService)
local MatchService = require(script.Parent.MatchService)

local PetHelperService = {}

local timers: { [Player]: number } = {}
local lastScout: { [Player]: number } = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

-- The pet you have out and its level.
local function petOf(player: Player): (CosmeticsData.Item?, number)
	local data = DataService.get(player)
	local item = data and CosmeticsData.get(data.cosmetics.pet)
	if not data or not item or not item.pet then
		return nil, 1
	end
	return item, PetLevels.levelOf(data, item.id)
end

local function heal(player: Player, amount: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = rootOf(player)
	if humanoid and root and humanoid.Health > 0 and humanoid.Health < humanoid.MaxHealth then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + amount)
		Juice.float(
			player,
			"+" .. math.floor(amount + 0.5) .. " ❤️",
			root.Position + Vector3.new(0, 3, 0),
			Color3.fromRGB(120, 240, 140)
		)
	end
end

local function scout(player: Player, range: number)
	local team = MatchService.teamOf(player)
	if not team or not team.bedAlive or os.clock() - (lastScout[player] or 0) < PetHelpers.ScoutCooldown then
		return
	end
	local bed = (team.frame * CFrame.new(0, 0, 22)).Position
	local seen = false
	for _, other in Players:GetPlayers() do
		local root = rootOf(other)
		if root and MatchService.isPlaying(other) and MatchService.isEnemy(player, other) then
			if (root.Position - bed).Magnitude < range then
				seen = true
				break
			end
		end
	end
	if not seen then
		for _, botRoot in CombatService.bots.enemiesOf(player) do
			if (botRoot.Position - bed).Magnitude < range then
				seen = true
				break
			end
		end
	end
	if seen then
		lastScout[player] = os.clock()
		Notify.player(player, "🦊 Your fox spotted an enemy near your bed!", "warn")
		Juice.sound(player, "zap")
	end
end

-- A quick line of fire from you to the target.
local function flame(from: Vector3, to: Vector3)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(255, 140, 40)
	part.Size = Vector3.new(0.5, 0.5, (to - from).Magnitude)
	part.CFrame = CFrame.lookAt((from + to) / 2, to)
	part.Parent = workspace
	game:GetService("Debris"):AddItem(part, 0.2)
	Effects.confetti(to, 6)
end

local function breath(player: Player, damage: number)
	local root = rootOf(player)
	if not root then
		return
	end
	local best: Player? = nil
	local bestRoot: BasePart? = nil
	local bestDistance = PetHelpers.BreathRange
	for _, other in Players:GetPlayers() do
		local otherRoot = rootOf(other)
		if otherRoot and MatchService.isPlaying(other) and MatchService.isEnemy(player, other) then
			local distance = (otherRoot.Position - root.Position).Magnitude
			if distance < bestDistance then
				best, bestRoot, bestDistance = other, otherRoot, distance
			end
		end
	end
	local from = root.Position + Vector3.new(0, 2, 0)
	if best and bestRoot then
		flame(from, bestRoot.Position)
		CombatService.hurt(best, player, damage, (bestRoot.Position - root.Position).Unit * 10, "Pet Dragon")
		return
	end
	-- No player close: a bot or monster, if there is one.
	for _, botRoot in CombatService.bots.enemiesOf(player) do
		if (botRoot.Position - root.Position).Magnitude < PetHelpers.BreathRange then
			local bot = CombatService.bots.botOf(botRoot)
			if bot then
				flame(from, botRoot.Position)
				CombatService.bots.hurt(bot, player, damage, (botRoot.Position - root.Position).Unit * 10)
				return
			end
		end
	end
end

local function work(player: Player)
	local item, level = petOf(player)
	local helper = item and item.pet and PetHelpers.ByKind[item.pet]
	if not helper or not MatchService.isPlaying(player) then
		timers[player] = nil
		if player:GetAttribute("PetHelp") then
			player:SetAttribute("PetHelp", nil)
		end
		return
	end
	local text = (item :: CosmeticsData.Item).emoji .. " Your pet " .. helper.text
	if player:GetAttribute("PetHelp") ~= text then
		player:SetAttribute("PetHelp", text)
	end
	timers[player] = (timers[player] or 0) + 1
	if timers[player] < helper.every then
		return
	end
	timers[player] = 0
	local power = PetHelpers.power(helper, level)
	local root = rootOf(player)
	if helper.job == "heal" then
		heal(player, power)
	elseif helper.job == "blocks" then
		local count = math.floor(power + 0.5)
		BlockService.add(player, "CloudWool", count)
		if root then
			Juice.float(player, "+" .. count .. " ☁️", root.Position + Vector3.new(0, 3, 0))
		end
	elseif helper.job == "resource" and helper.resource then
		local count = math.floor(power + 0.5)
		MatchService.addResource(player, helper.resource, count)
		if root then
			Juice.float(player, "+" .. count .. " " .. helper.resource, root.Position + Vector3.new(0, 3, 0))
		end
	elseif helper.job == "scout" then
		scout(player, power)
	elseif helper.job == "breath" then
		breath(player, power)
	end
end

function PetHelperService.start()
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local ok, problem = pcall(work, player)
				if not ok then
					warn("[Bottle a Storm] Pet helper failed: " .. tostring(problem))
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		timers[player] = nil
		lastScout[player] = nil
	end)
end

return PetHelperService
