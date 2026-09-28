-- 🧙 Classes (ClassData): pick Knight, Archer, Builder or Healer in the lobby
-- (🧙 Class). While you play, your class shows as "MatchClass" (and its 🎓
-- level as "MatchClassLevel"); CombatService counts its damage perks, this
-- gives its starting items every time you spawn, and Healers heal themselves
-- and teammates nearby. Playing a class earns it XP (data.classXp); your
-- levels are shared as the "ClassLevels" attribute (JSON) for the picker.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local ClassData = require(Shared.ClassData)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent.Parent.Modules
local Juice = require(Modules.Juice)
local Notify = require(Modules.Notify)
local Usage = require(Modules.Usage)

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

local function levelsOf(data: any): { [string]: { level: number, xp: number } }
	data.classXp = data.classXp or {}
	return data.classXp
end

local function levelOf(player: Player, key: string): number
	local data = DataService.get(player)
	local entry = data and levelsOf(data)[key]
	return if entry then entry.level else 1
end

local function publish(player: Player)
	local data = DataService.get(player)
	player:SetAttribute("Class", chosen(player))
	if data then
		player:SetAttribute("ClassLevels", HttpService:JSONEncode(levelsOf(data)))
	end
end

local function addXp(player: Player, amount: number)
	local key = player:GetAttribute("MatchClass")
	local data = DataService.get(player)
	local class = ClassData.get(key :: string?)
	if not data or not class then
		return
	end
	local levels = levelsOf(data)
	local entry = levels[class.key]
	if not entry then
		entry = { level = 1, xp = 0 }
		levels[class.key] = entry
	end
	if entry.level >= ClassData.MaxLevel then
		return
	end
	entry.xp += amount
	local levelled = false
	while entry.level < ClassData.MaxLevel and entry.xp >= ClassData.xpFor(entry.level) do
		entry.xp -= ClassData.xpFor(entry.level)
		entry.level += 1
		levelled = true
	end
	if entry.level >= ClassData.MaxLevel then
		entry.xp = 0
	end
	if levelled then
		Notify.player(
			player,
			"🎓 Your "
				.. class.emoji
				.. " "
				.. class.name
				.. " is now level "
				.. entry.level
				.. "! "
				.. ClassData.summary(class.key, entry.level),
			"rare"
		)
		Juice.sound(player, "win")
		if entry.level >= ClassData.MaxLevel then
			data.stats.classesMaxed = (data.stats.classesMaxed or 0) + 1
		end
	end
	publish(player)
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
	Usage.track("class:" .. class.key, player)
	Notify.player(player, "🧙 You're a " .. class.emoji .. " " .. class.name .. " next match!", "success")
end

local function setClass(player: Player)
	local key = chosen(player)
	player:SetAttribute("MatchClass", key)
	player:SetAttribute("MatchClassLevel", levelOf(player, key))
end

local function onSpawn(player: Player)
	if not player:GetAttribute("MatchClass") then
		setClass(player)
	end
	task.wait(0.4) -- after your gear resets
	local class = ClassData.of(player)
	if not class or not MatchService.isPlaying(player) then
		return
	end
	local perks = ClassData.playing(player)
	if class.key == "Knight" then
		CombatService.give(player, "StoneSword")
	elseif class.key == "Archer" then
		CombatService.give(player, "Bow")
		CombatService.give(player, "Arrows", perks.arrows)
	elseif class.key == "Builder" then
		BlockService.add(player, "CloudWool", perks.wool)
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
			local perks = ClassData.playing(healer)
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
					and (friendRoot.Position - root.Position).Magnitude <= perks.range
				then
					humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + perks.heal)
					Juice.float(
						healer,
						"+" .. perks.heal .. " 💚",
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
				setClass(player)
			end
		end
	end)
	MatchService.MatchEnded:Connect(function()
		for _, player in Players:GetPlayers() do
			player:SetAttribute("MatchClass", nil)
			player:SetAttribute("MatchClassLevel", nil)
		end
	end)
	MatchService.PlayerSpawned:Connect(onSpawn)
	-- 🎓 Class XP (for the class you're playing).
	local xp = ClassData.Xp
	MatchService.Played:Connect(function(player)
		addXp(player, xp.play)
	end)
	MatchService.Won:Connect(function(player)
		addXp(player, xp.win)
	end)
	MatchService.Killed:Connect(function(killer)
		addXp(killer, xp.kill)
	end)
	MatchService.BotKilled:Connect(function(killer)
		addXp(killer, xp.kill)
	end)
	MatchService.BedBroken:Connect(function(breaker)
		if typeof(breaker) == "Instance" and breaker:IsA("Player") then
			addXp(breaker, xp.bed)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(ClassData.HealEvery)
			pcall(healers)
		end
	end)
end

return ClassService
