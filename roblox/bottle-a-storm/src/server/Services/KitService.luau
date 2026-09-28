-- Bed Wars kits: every storm you own is a kit. Pick one in the 🌪️ Kits
-- window; in a match it floats beside you and gives you its power on Shift
-- (Updraft, Blink Dash, Surf Boost, Cloud Jump or Cloud Flight; the client
-- runs them in KitController). Rarer kits recharge faster. Get more kits
-- from Kit Crates, the Kit Shop, the spin wheel and the battle pass.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local StormData = require(Shared.StormData)

local Modules = script.Parent.Parent.Modules
local StormModel = require(Modules.StormModel)

local DataService = require(script.Parent.DataService)
local MatchService = require(script.Parent.MatchService)

local KitService = {}

local folder: Folder
local buddies: { [Player]: Model } = {}

local function findRecord(data: any, uid: any): StormData.StormRecord?
	if type(uid) ~= "string" then
		return nil
	end
	for _, record in data.storms do
		if record.uid == uid then
			return record
		end
	end
	return nil
end

-- The kit a player brings: the one they picked, or their rarest storm.
local function kitOf(player: Player): StormData.StormRecord?
	local data = DataService.get(player)
	if not data then
		return nil
	end
	local chosen = findRecord(data, data.kit)
	if chosen then
		return chosen
	end
	local best: StormData.StormRecord? = nil
	local bestRarity = 0
	for _, record in data.storms do
		local def = StormData.get(record.id)
		if def and def.rarity > bestRarity then
			best, bestRarity = record, def.rarity
		end
	end
	return best
end

local function clear(player: Player)
	local model = buddies[player]
	buddies[player] = nil
	if model then
		model:Destroy()
	end
	if player.Parent then
		player:SetAttribute("KitName", nil)
		player:SetAttribute("RideAbility", nil)
		player:SetAttribute("KitCooldown", nil)
	end
end

-- Gives the kit's power and shows the storm beside the player.
local function equip(player: Player)
	clear(player)
	local record = kitOf(player)
	local def = record and StormData.get(record.id)
	if not record or not def or not MatchService.isPlaying(player) then
		return
	end
	player:SetAttribute("KitName", StormData.displayName(record))
	player:SetAttribute("RideAbility", StormData.abilityOf(def))
	player:SetAttribute("KitCooldown", StormData.rarityOf(def).cooldown)
	local model = StormModel.build(def, { mutation = record.mut, scale = Config.Kit.BuddyScale, anchored = true })
	model.Name = "Kit_" .. player.UserId
	model:SetAttribute("OwnerUserId", player.UserId)
	local tag = StormModel.nameTag(def, record.mut, player.DisplayName .. "'s kit")
	tag.MaxDistance = 50
	tag.StudsOffsetWorldSpace *= 0.6
	tag.Parent = model.PrimaryPart
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanQuery = false -- arrows and blocks go through it
			descendant.CanTouch = false
		end
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	model:PivotTo((if root then root.CFrame else CFrame.new()) * CFrame.new(3, 2, 2))
	model.Parent = folder
	buddies[player] = model
end

local function getKits(player: Player)
	local data = DataService.get(player)
	if not data then
		return nil
	end
	local chosen = kitOf(player)
	local list = {}
	for _, record in data.storms do
		local def = StormData.get(record.id)
		if def then
			local ability = StormData.abilityOf(def)
			local info = StormData.AbilityInfo[ability]
			local rarity = StormData.rarityOf(def)
			table.insert(list, {
				uid = record.uid,
				name = StormData.displayName(record),
				rarity = rarity.name,
				rarityIndex = def.rarity,
				color = rarity.color,
				power = info.emoji .. " " .. info.name,
				powerText = info.description,
				cooldown = math.floor((Config.Kit.Cooldowns[ability] or 1) * rarity.cooldown * 10 + 0.5) / 10,
				chosen = chosen ~= nil and chosen.uid == record.uid,
			})
		end
	end
	table.sort(list, function(a, b)
		if a.rarityIndex ~= b.rarityIndex then
			return a.rarityIndex > b.rarityIndex
		end
		return a.name < b.name
	end)
	return list
end

local function chooseKit(player: Player, uid: any): (boolean, string)
	local data = DataService.get(player)
	local record = data and findRecord(data, uid)
	if not record then
		return false, "You don't have that kit."
	end
	data.kit = record.uid
	player:SetAttribute("KitChoice", StormData.displayName(record))
	if MatchService.isPlaying(player) then
		return true, "🌪️ " .. StormData.displayName(record) .. " will be your kit when you respawn."
	end
	return true, "🌪️ " .. StormData.displayName(record) .. " is your kit for the next match!"
end

function KitService.init()
	folder = workspace:FindFirstChild("Kits") :: Folder? or Instance.new("Folder")
	folder.Name = "Kits"
	folder.Parent = workspace
end

function KitService.start()
	Remotes.func("GetKits").OnServerInvoke = getKits
	Remotes.func("ChooseKit").OnServerInvoke = chooseKit
	MatchService.PlayerSpawned:Connect(function(player)
		task.wait(0.2)
		equip(player)
	end)
	MatchService.MatchEnded:Connect(function()
		for _, player in Players:GetPlayers() do
			clear(player)
		end
	end)
	DataService.ProfileLoaded:Connect(function(player)
		local record = kitOf(player)
		player:SetAttribute("KitChoice", if record then StormData.displayName(record) else nil)
	end)
	Players.PlayerRemoving:Connect(clear)

	-- Knocked out players lose their kit until the next match.
	task.spawn(function()
		while true do
			task.wait(1)
			for player in buddies do
				if not MatchService.isPlaying(player) then
					clear(player)
				end
			end
		end
	end)
end

return KitService
