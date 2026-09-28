-- Long-term progress (see ProgressionData):
--   * Level and prestige: XP from every match. Each level pays Sparks, every
--     10th a kit; at level 100 you prestige (back to level 1 with a new star
--     color and a big Sparks prize).
--   * Ranked: rank points from matches with 2+ teams (Bronze to Champion).
--   * Win streaks: extra Sparks for winning in a row.
--   * Victory dances: winners dance (their 💃 cosmetic) with confetti.
--   * Achievements: finished automatically, with a reward.
-- The level, rank and streak show on a tag above your head.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Format)
local ProgressionData = require(Shared.ProgressionData)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent.Parent.Modules
local Effects = require(Modules.Effects)
local Juice = require(Modules.Juice)
local Notify = require(Modules.Notify)

local CosmeticService = require(script.Parent.CosmeticService)
local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local MatchService = require(script.Parent.MatchService)
local RewardService = require(script.Parent.RewardService)

local ProgressionService = {}

local wonThisMatch: { [Player]: boolean } = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

local function ensure(data: any)
	data.level = data.level or 1
	data.levelXp = data.levelXp or 0
	data.prestige = data.prestige or 0
	data.winStreak = data.winStreak or 0
	data.bestStreak = data.bestStreak or 0
	data.bestRank = data.bestRank or 0
	data.achievements = data.achievements or {}
	data.stats.rankPoints = data.stats.rankPoints or 0
end

---------------------------------------------------------------------------
-- The tag above your head
---------------------------------------------------------------------------

local function showTag(player: Player)
	local data = DataService.get(player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not data or not head then
		return
	end
	ensure(data)
	local tag = head:FindFirstChild("InfoTag") :: BillboardGui?
	if not tag then
		local gui = Instance.new("BillboardGui")
		gui.Name = "InfoTag"
		gui.Size = UDim2.fromOffset(240, 26)
		gui.StudsOffset = Vector3.new(0, 4.1, 0)
		gui.MaxDistance = 80
		gui.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.RichText = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0.2
		label.Parent = gui
		gui.Parent = head
		tag = gui
	end
	local star = ProgressionData.PrestigeColors[math.min(data.prestige, ProgressionData.MaxPrestige) + 1]
	local rank = ProgressionData.rankOf(data.stats.rankPoints)
	local text = string.format(
		'<font color="#%s">%s%s Lv %d</font>  %s %s',
		star:ToHex(),
		"⭐",
		if data.prestige > 0 then tostring(data.prestige) else "",
		data.level,
		rank.emoji,
		rank.name
	)
	if data.winStreak >= 2 then
		text ..= "  🔥" .. data.winStreak
	end
	local clanTag = player:GetAttribute("ClanTag")
	local clanColor = player:GetAttribute("ClanColor")
	if type(clanTag) == "string" then
		local color = if typeof(clanColor) == "Color3" then clanColor else Color3.new(1, 1, 1)
		text = string.format('<font color="#%s">[%s]</font>  ', color:ToHex(), clanTag) .. text
	end
	((tag :: BillboardGui):FindFirstChild("Text") :: TextLabel).Text = text
end

local function publish(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	ensure(data)
	player:SetAttribute("Level", data.level)
	player:SetAttribute("Prestige", data.prestige)
	player:SetAttribute("LevelXp", data.levelXp)
	player:SetAttribute("LevelNeed", ProgressionData.xpFor(data.level))
	player:SetAttribute("RankPoints", data.stats.rankPoints)
	player:SetAttribute("WinStreak", data.winStreak)
	local leaderstats = player:FindFirstChild("leaderstats")
	local levelValue = leaderstats and leaderstats:FindFirstChild("Level") :: IntValue?
	if levelValue then
		levelValue.Value = data.prestige * ProgressionData.MaxLevel + data.level
	end
	showTag(player)
end

---------------------------------------------------------------------------
-- XP, levels and prestige
---------------------------------------------------------------------------

local function addXp(player: Player, amount: number)
	local data = DataService.get(player)
	if not data then
		return
	end
	ensure(data)
	data.levelXp += amount
	while data.levelXp >= ProgressionData.xpFor(data.level) do
		if data.level >= ProgressionData.MaxLevel then
			if data.prestige >= ProgressionData.MaxPrestige then
				data.levelXp = ProgressionData.xpFor(data.level) - 1
				break
			end
			data.prestige += 1
			data.level = 1
			data.levelXp = 0
			IncomeService.addSparks(player, ProgressionData.PrestigeSparks)
			Notify.all("💫 " .. player.DisplayName .. " reached PRESTIGE " .. data.prestige .. "!", "rare")
			break
		end
		data.levelXp -= ProgressionData.xpFor(data.level)
		data.level += 1
		local sparks = ProgressionData.levelSparks(data.level)
		IncomeService.addSparks(player, sparks)
		Juice.sound(player, "chime")
		local root = rootOf(player)
		if root then
			Juice.float(
				player,
				"LEVEL " .. data.level .. "!",
				root.Position + Vector3.new(0, 6, 0),
				Color3.fromRGB(255, 225, 90)
			)
		end
		if data.level % 10 == 0 then
			RewardService.giveKit(player, RewardService.randomKit(math.min(5, 3 + data.level // 40)), nil)
		end
		Notify.player(player, "⭐ Level " .. data.level .. "! +⚡" .. Format.number(sparks), "success")
	end
	publish(player)
end

---------------------------------------------------------------------------
-- Ranked
---------------------------------------------------------------------------

local function ranked(): boolean
	return MatchService.teamCount() >= 2
end

local function addRankPoints(player: Player, amount: number)
	local data = DataService.get(player)
	if not data or not ranked() then
		return
	end
	ensure(data)
	local before = ProgressionData.rankOf(data.stats.rankPoints)
	data.stats.rankPoints = math.max(0, data.stats.rankPoints + amount)
	data.bestRank = math.max(data.bestRank, data.stats.rankPoints)
	local after = ProgressionData.rankOf(data.stats.rankPoints)
	if after.points > before.points then
		Notify.player(player, after.emoji .. " RANK UP! You're now " .. after.name .. "!", "rare")
		Notify.allExcept(
			player,
			after.emoji .. " " .. player.DisplayName .. " ranked up to " .. after.name .. "!",
			"info"
		)
	elseif after.points < before.points then
		Notify.player(player, "📉 You dropped to " .. after.emoji .. " " .. after.name .. ".", "warn")
	end
	publish(player)
end

---------------------------------------------------------------------------
-- Achievements
---------------------------------------------------------------------------

local function checkAchievements(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	ensure(data)
	for _, achievement in ProgressionData.Achievements do
		if not data.achievements[achievement.id] and achievement.progress(data) >= achievement.target then
			data.achievements[achievement.id] = true
			RewardService.grant(player, achievement.reward, nil)
			Notify.player(
				player,
				"🏅 Achievement: " .. achievement.emoji .. " " .. achievement.name .. "! Reward claimed.",
				"rare"
			)
		end
	end
	local done = 0
	for _ in data.achievements do
		done += 1
	end
	player:SetAttribute("AchievementsDone", done)
end

local function getAchievements(player: Player)
	local data = DataService.get(player)
	if not data then
		return nil
	end
	ensure(data)
	local list = {}
	for _, achievement in ProgressionData.Achievements do
		table.insert(list, {
			id = achievement.id,
			done = data.achievements[achievement.id] == true,
			progress = math.min(achievement.progress(data), achievement.target),
		})
	end
	return list
end

---------------------------------------------------------------------------

function ProgressionService.start()
	Remotes.func("GetAchievements").OnServerInvoke = getAchievements
	local xp = ProgressionData.Xp
	local points = ProgressionData.RankPoints

	MatchService.Killed:Connect(function(killer, _victim, final)
		addXp(killer, if final then xp.FinalKill else xp.Kill)
		if final then
			addRankPoints(killer, points.FinalKill)
		end
	end)
	MatchService.BedBroken:Connect(function(breaker)
		addXp(breaker, xp.Bed)
		addRankPoints(breaker, points.Bed)
	end)
	MatchService.Won:Connect(function(player)
		local data = DataService.get(player)
		if not data then
			return
		end
		ensure(data)
		wonThisMatch[player] = true
		data.winStreak += 1
		data.bestStreak = math.max(data.bestStreak, data.winStreak)
		addXp(player, xp.Win)
		addRankPoints(player, points.Win)
		if data.winStreak >= 2 then
			local bonus = math.min(ProgressionData.StreakSparksMax, ProgressionData.StreakSparks * data.winStreak)
			IncomeService.addSparks(player, bonus)
			Notify.player(
				player,
				"🔥 " .. data.winStreak .. " wins in a row! Streak bonus +⚡" .. Format.number(bonus),
				"rare"
			)
		end
		-- Victory dance with confetti.
		Remotes.event("Victory"):FireClient(player, CosmeticService.danceOf(player))
		local root = rootOf(player)
		if root then
			Effects.confetti(root.Position + Vector3.new(0, 4, 0), 60)
		end
		publish(player)
	end)
	MatchService.Played:Connect(function(player)
		addXp(player, xp.Played)
		local data = DataService.get(player)
		if data and not wonThisMatch[player] then
			ensure(data)
			if data.winStreak >= 2 then
				Notify.player(player, "💔 Your " .. data.winStreak .. "-win streak ended.", "warn")
			end
			data.winStreak = 0
			addRankPoints(player, points.Loss)
		end
		checkAchievements(player)
	end)
	MatchService.MatchEnded:Connect(function()
		wonThisMatch = {}
	end)

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Head", 10)
			showTag(player)
		end)
		player:GetAttributeChangedSignal("ClanTag"):Connect(function()
			showTag(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	DataService.ProfileLoaded:Connect(function(player)
		publish(player)
		checkAchievements(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		wonThisMatch[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(5)
			for _, player in Players:GetPlayers() do
				checkAchievements(player)
			end
		end
	end)
end

return ProgressionService
