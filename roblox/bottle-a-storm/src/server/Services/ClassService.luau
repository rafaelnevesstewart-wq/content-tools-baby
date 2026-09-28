-- 🧙 Classes (ClassData): pick Knight, Archer, Builder or Healer in the lobby
-- (🧙 Class). While you play, your class shows as "MatchClass"; CombatService
-- counts its damage bonuses, this gives its starting items every time you
-- spawn, and Healers heal themselves and teammates nearby.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local ClassData = require(Shared.ClassData)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent.Parent.Modules
local Juice = require(Modules.Juice)
local Notify = require(Modules.Notify)

local BlockService = require(script.Parent.BlockService)
local CombatService = require(script.Parent.CombatService)
local DataService = require(script.Parent.DataService)
local GadgetService = require(script.Parent.GadgetService)
local MatchService = require(script.Parent.MatchService)

local ClassService = {}

local function chosen(player: Player): string
	local data = DataService.get(player)
	local key = data and data.class
	return if ClassData.get(key) then key else ClassData.Default
end

local function publish(player: Player)
	player:SetAttribute("Class", chosen(player))
end

local function onPick(player: Player, key: any)
	local data = DataService.get(player)
	local class = if type(key) == "string" then ClassData.get(key) else nil
	if not data or not class then
		return
	end
	if player:GetAttribute("InMatch") then
		Notify.player(player, "🧙 You can change class in the lobby, before the next match.", "info")
		return
	end
	data.class = class.key
	publish(player)
	Notify.player(player, "🧙 You're a " .. class.emoji .. " " .. class.name .. " next match!", "success")
end

local function onSpawn(player: Player)
	if not player:GetAttribute("MatchClass") then
		player:SetAttribute("MatchClass", chosen(player))
	end
	task.wait(0.4) -- after your gear resets
	local class = ClassData.of(player)
	if not class or not MatchService.isPlaying(player) then
		return
	end
	if class.key == "Knight" then
		CombatService.give(player, "StoneSword")
	elseif class.key == "Archer" then
		CombatService.give(player, "Bow")
		CombatService.give(player, "Arrows", ClassData.ArcherArrows)
	elseif class.key == "Builder" then
		BlockService.add(player, "CloudWool", ClassData.BuilderWool)
		if (player:GetAttribute("PickaxeTier") or 0) < 2 then
			GadgetService.give(player, "Pickaxe")
		end
	end
end

local function healers()
	for _, healer in Players:GetPlayers() do
		local class = ClassData.of(healer)
		local character = healer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if class and class.key == "Healer" and root and MatchService.isPlaying(healer) then
			local team = MatchService.teamOf(healer)
			for _, friend in if team then team.members else { healer } do
				local friendCharacter = friend.Character
				local friendRoot = friendCharacter and friendCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
				local humanoid = friendCharacter and friendCharacter:FindFirstChildOfClass("Humanoid")
				if
					friendRoot
					and humanoid
					and humanoid.Health > 0
					and humanoid.Health < humanoid.MaxHealth
					and MatchService.isPlaying(friend)
					and (friendRoot.Position - root.Position).Magnitude <= ClassData.HealRange
				then
					humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + ClassData.HealAmount)
					Juice.float(
						healer,
						"+" .. ClassData.HealAmount .. " 💚",
						friendRoot.Position + Vector3.new(0, 3, 0),
						Color3.fromRGB(120, 240, 140)
					)
				end
			end
		end
	end
end

function ClassService.start()
	Remotes.event("PickClass").OnServerEvent:Connect(onPick)
	DataService.ProfileLoaded:Connect(function(player)
		publish(player)
	end)
	MatchService.MatchStarted:Connect(function()
		for _, player in Players:GetPlayers() do
			if player:GetAttribute("InMatch") then
				player:SetAttribute("MatchClass", chosen(player))
			end
		end
	end)
	MatchService.MatchEnded:Connect(function()
		for _, player in Players:GetPlayers() do
			player:SetAttribute("MatchClass", nil)
		end
	end)
	MatchService.PlayerSpawned:Connect(onSpawn)
	task.spawn(function()
		while true do
			task.wait(ClassData.HealEvery)
			pcall(healers)
		end
	end)
end

return ClassService
