-- Titles: earned by playing (see TitleData) and shown above your head for
-- everyone to see. Pick which one in 🎁 Rewards -> Titles.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local TitleData = require(Shared.TitleData)

local Modules = script.Parent.Parent.Modules
local Notify = require(Modules.Notify)

local DataService = require(script.Parent.DataService)
local RaidService = require(script.Parent.RaidService)

local TitleService = {}

local function unlocked(data: any, title: TitleData.Title): boolean
	return title.progress(data) >= title.target
end

-- Puts (or updates, or removes) the title tag above the player's head.
local function showTag(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local data = DataService.get(player)
	local title = data and TitleData.get(data.title)
	local tag = head:FindFirstChild("TitleTag") :: BillboardGui?
	if not title then
		if tag then
			tag:Destroy()
		end
		return
	end
	if not tag then
		local gui = Instance.new("BillboardGui")
		gui.Name = "TitleTag"
		gui.Size = UDim2.fromOffset(220, 30)
		gui.StudsOffset = Vector3.new(0, 3.1, 0)
		gui.MaxDistance = 90
		gui.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextStrokeTransparency = 0
		label.TextStrokeColor3 = Color3.fromRGB(60, 40, 90)
		label.Parent = gui
		gui.Parent = head
		tag = gui
	end
	local label = (tag :: BillboardGui):FindFirstChild("Text") :: TextLabel
	label.Text = title.emoji .. " " .. title.name
	label.TextColor3 = title.color
end

-- Announces titles the player has just earned. The first one is shown
-- automatically.
local function checkUnlocks(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	for _, title in TitleData.List do
		if not data.titles[title.id] and unlocked(data, title) then
			data.titles[title.id] = true
			if not data.title then
				data.title = title.id
				showTag(player)
				Notify.player(
					player,
					"🏷️ New title: " .. title.emoji .. " " .. title.name .. "! It's shown above your name.",
					"rare"
				)
			else
				Notify.player(
					player,
					"🏷️ New title unlocked: "
						.. title.emoji
						.. " "
						.. title.name
						.. "! Show it off in 🎁 Rewards → Titles.",
					"rare"
				)
			end
		end
	end
end

local function getTitles(player: Player)
	local data = DataService.get(player)
	if not data then
		return nil
	end
	local list = {}
	for _, title in TitleData.List do
		table.insert(list, {
			id = title.id,
			unlocked = unlocked(data, title),
			progress = math.min(title.progress(data), title.target),
		})
	end
	return { equipped = data.title, list = list }
end

local function setTitle(player: Player, id: any): (boolean, string)
	local data = DataService.get(player)
	if not data then
		return false, "Your data isn't loaded yet."
	end
	if id == nil then
		data.title = nil
		showTag(player)
		return true, "Title hidden."
	end
	local title = type(id) == "string" and TitleData.get(id)
	if not title or not unlocked(data, title) then
		return false, "You haven't earned that title yet."
	end
	data.title = title.id
	showTag(player)
	return true, "🏷️ Now showing: " .. title.emoji .. " " .. title.name
end

function TitleService.start()
	Remotes.func("GetTitles").OnServerInvoke = getTitles
	Remotes.func("SetTitle").OnServerInvoke = setTitle

	RaidService.Fought:Connect(function(player)
		local data = DataService.get(player)
		if data then
			data.stats.raids += 1
		end
	end)

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Head", 10)
			showTag(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	DataService.ProfileLoaded:Connect(function(player)
		showTag(player)
		checkUnlocks(player)
	end)

	task.spawn(function()
		while true do
			task.wait(3)
			for _, player in Players:GetPlayers() do
				checkUnlocks(player)
			end
		end
	end)
end

return TitleService
