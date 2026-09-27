-- Storm buddy: pick one storm (Options menu -> Buddy) to float next to you
-- everywhere, so everyone can see your favorite catch. It also stays on its
-- pedestal and keeps earning. The server makes the model; every player's
-- screen moves it next to its owner (BuddyController), which looks smooth.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local StormData = require(Shared.StormData)

local Modules = script.Parent.Parent.Modules
local Notify = require(Modules.Notify)
local StormModel = require(Modules.StormModel)

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)

local BuddyService = {}

local buddies: { [Player]: { uid: string, model: Model } } = {}
local folder: Folder

local function findRecord(data: any, uid: string?): StormData.StormRecord?
	if not uid then
		return nil
	end
	for _, record in data.storms do
		if record.uid == uid then
			return record
		end
	end
	return nil
end

local function buddyLine(player: Player, record: StormData.StormRecord): string
	return "💕 " .. player.DisplayName .. "'s buddy · Lv " .. StormData.levelOf(record)
end

local function removeBuddy(player: Player)
	local buddy = buddies[player]
	if buddy then
		buddies[player] = nil
		buddy.model:Destroy()
	end
	if player.Parent then
		player:SetAttribute("BuddyUid", nil)
	end
end

local function showBuddy(player: Player)
	removeBuddy(player)
	local data = DataService.get(player)
	local record = data and findRecord(data, data.buddyUid)
	local def = record and StormData.get(record.id)
	if not record or not def then
		return
	end
	local model = StormModel.build(def, { mutation = record.mut, scale = Config.Buddy.Scale, anchored = true })
	model.Name = "Buddy_" .. player.UserId
	model:SetAttribute("OwnerUserId", player.UserId)
	local tag = StormModel.nameTag(def, record.mut, buddyLine(player, record))
	tag.MaxDistance = 60
	tag.StudsOffsetWorldSpace *= 0.6
	tag.Parent = model.PrimaryPart
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local plot = PlotService.getPlot(player)
	local start = if root then root.CFrame elseif plot then plot.cframe else CFrame.new()
	model:PivotTo(start * CFrame.new(3, 2, 2))
	model.Parent = folder
	buddies[player] = { uid = record.uid, model = model }
	player:SetAttribute("BuddyUid", record.uid)
end

local function choose(player: Player, slot: number)
	local data = DataService.get(player)
	local record = data and PlotService.stormInSlot(data, slot)
	if not data or not record then
		return
	end
	if data.buddyUid == record.uid then
		data.buddyUid = nil
		removeBuddy(player)
		Notify.player(player, "👋 " .. StormData.displayName(record) .. " went back to its pedestal.", "info")
		return
	end
	data.buddyUid = record.uid
	showBuddy(player)
	Notify.player(
		player,
		"💕 " .. StormData.displayName(record) .. " is your buddy now! It follows you everywhere.",
		"success"
	)
end

function BuddyService.init()
	folder = Instance.new("Folder")
	folder.Name = "Buddies"
	folder.Parent = workspace
end

function BuddyService.start()
	PlotService.BuddyRequested:Connect(choose)
	PlotService.PlotAssigned:Connect(showBuddy)
	Players.PlayerRemoving:Connect(removeBuddy)

	-- A buddy that was sold, traded, mixed or stolen goes away. Its level
	-- label also stays up to date.
	task.spawn(function()
		while true do
			task.wait(1)
			for player, buddy in buddies do
				local data = DataService.get(player)
				local record = data and findRecord(data, buddy.uid)
				if not record then
					if data then
						data.buddyUid = nil
					end
					removeBuddy(player)
				else
					local tag = buddy.model.PrimaryPart and buddy.model.PrimaryPart:FindFirstChild("NameTag")
					local line = tag and tag:FindFirstChild("Line4", true)
					if line and line:IsA("TextLabel") then
						line.Text = buddyLine(player, record)
					end
				end
			end
		end
	end)
end

return BuddyService
