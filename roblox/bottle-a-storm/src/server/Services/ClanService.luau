-- 🛡️ Clans: make a clan with a name and a 2-4 letter tag (costs Sparks),
-- invite people in your server, and every match a member wins counts for
-- the whole clan. Your clan tag shows above your head, and the 🛡️ Clan
-- window has the Top Clans leaderboard.
--
-- Clans are saved in DataStores so they work across servers:
--   Clans_v1       "clan_<id>" -> the clan (name, tag, owner, members, wins)
--   ClanTags_v1    "<TAG>" -> clan id (so every tag is taken only once)
--   ClanWins_v1    (ordered) clan id -> wins, for the leaderboard
-- In Studio without API access they live in this server only.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent.Parent.Modules
local Notify = require(Modules.Notify)

local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local MatchService = require(script.Parent.MatchService)

local ClanService = {}

export type Clan = {
	id: string,
	name: string,
	tag: string,
	color: number, -- index into Config.Clans.Colors
	owner: number, -- user id
	members: { [string]: string }, -- tostring(userId) -> display name
	wins: number,
}

local clanStore: DataStore? = nil
local tagStore: DataStore? = nil
local winStore: OrderedDataStore? = nil
local memory: { [string]: Clan } = {} -- memory mode, and a cache otherwise
local memoryTags: { [string]: string } = {}
local invites: { [Player]: { [string]: number } } = {} -- invited -> clan id -> when
local lastAction: { [Player]: number } = {}
local topCache: { any } = {}
local topCachedAt = 0

local function online(): boolean
	return clanStore ~= nil and not DataService.isMemoryMode()
end

local function count(members: { [string]: string }): number
	local total = 0
	for _ in members do
		total += 1
	end
	return total
end

-- Reads a clan (fresh from the DataStore when online).
local function load(id: string): Clan?
	if not online() then
		return memory[id]
	end
	local ok, clan = pcall(function()
		return (clanStore :: DataStore):GetAsync("clan_" .. id)
	end)
	if ok and type(clan) == "table" then
		memory[id] = clan
		return clan
	end
	return if ok then nil else memory[id]
end

-- Changes a clan safely (other servers may change it at the same time).
-- `change` gets the clan and returns it (or nil to delete it).
local function update(id: string, change: (Clan) -> Clan?): Clan?
	if not online() then
		local clan = memory[id]
		if not clan then
			return nil
		end
		local result = change(clan)
		memory[id] = result :: any
		return result
	end
	local result: Clan? = nil
	local ok = pcall(function()
		(clanStore :: DataStore):UpdateAsync("clan_" .. id, function(clan)
			if type(clan) ~= "table" then
				return nil
			end
			result = change(clan :: Clan)
			return result
		end)
	end)
	if ok then
		memory[id] = result :: any
		return result
	end
	return nil
end

-- A tag can belong to one clan only. Returns whether this clan got it.
local function claimTag(tag: string, id: string?): boolean
	if not online() then
		if id and memoryTags[tag] then
			return false
		end
		memoryTags[tag] = id :: any
		return true
	end
	local got = false
	pcall(function()
		(tagStore :: DataStore):UpdateAsync(tag, function(owner)
			if id == nil then
				return nil -- releasing it
			end
			if owner ~= nil and owner ~= id then
				return owner
			end
			got = true
			return id
		end)
	end)
	return got
end

local function setWins(clan: Clan)
	if online() and winStore then
		pcall(function()
			(winStore :: OrderedDataStore):SetAsync(clan.id, clan.wins)
		end)
	end
end

-- Shows the tag above a player's head (ProgressionService draws it).
local function showTag(player: Player, clan: Clan?)
	if clan then
		local color = Config.Clans.Colors[clan.color] or Config.Clans.Colors[1]
		player:SetAttribute("ClanTag", clan.tag)
		player:SetAttribute("ClanColor", color)
		player:SetAttribute("ClanId", clan.id)
	else
		player:SetAttribute("ClanTag", nil)
		player:SetAttribute("ClanColor", nil)
		player:SetAttribute("ClanId", nil)
	end
end

-- Everyone in this server who's in a clan sees its changes.
local function refreshMembers(id: string, clan: Clan?)
	for _, player in Players:GetPlayers() do
		local data = DataService.get(player)
		if data and data.clan == id then
			if clan and clan.members[tostring(player.UserId)] then
				showTag(player, clan)
			else
				data.clan = nil
				showTag(player, nil)
			end
		end
	end
end

-- Makes user-typed text safe to show to everyone (nil if it had to be hidden).
local function filtered(player: Player, text: string): string?
	local ok, result = pcall(function()
		local filter = TextService:FilterStringAsync(text, player.UserId, Enum.TextFilterContext.PublicChat)
		return filter:GetNonChatStringForBroadcastAsync()
	end)
	if not ok then
		return text -- (Studio can't always filter)
	end
	if result ~= text then
		return nil
	end
	return result
end

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------

local function create(player: Player, data: any, name: any, tag: any): (boolean, string)
	if data.clan then
		return false, "Leave your clan first."
	end
	if type(name) ~= "string" or type(tag) ~= "string" then
		return false, "Pick a name and a tag."
	end
	name = string.gsub(name, "^%s+", "")
	name = string.gsub(name, "%s+$", "")
	tag = string.upper(tag)
	if #name < 3 or #name > Config.Clans.NameMax then
		return false, "The name needs 3 to " .. Config.Clans.NameMax .. " letters."
	end
	if not string.match(tag, "^%w+$") or #tag < Config.Clans.TagMin or #tag > Config.Clans.TagMax then
		return false, "The tag needs " .. Config.Clans.TagMin .. " to " .. Config.Clans.TagMax .. " letters or numbers."
	end
	if data.sparks < Config.Clans.CreateCost then
		return false, "A clan costs ⚡" .. Config.Clans.CreateCost .. "."
	end
	local safeName = filtered(player, name)
	local safeTag = filtered(player, tag)
	if not safeName or not safeTag then
		return false, "That name or tag isn't allowed. Try another!"
	end
	local id = HttpService:GenerateGUID(false)
	if not claimTag(tag, id) then
		return false, "The tag [" .. tag .. "] is taken. Try another!"
	end
	local clan: Clan = {
		id = id,
		name = safeName,
		tag = safeTag,
		color = math.random(1, #Config.Clans.Colors),
		owner = player.UserId,
		members = { [tostring(player.UserId)] = player.DisplayName },
		wins = 0,
	}
	if online() then
		local ok = pcall(function()
			(clanStore :: DataStore):SetAsync("clan_" .. id, clan)
		end)
		if not ok then
			claimTag(tag, nil)
			return false, "Couldn't save your clan. Try again in a moment."
		end
	end
	memory[id] = clan
	data.sparks -= Config.Clans.CreateCost
	IncomeService.sync(player)
	data.clan = id
	showTag(player, clan)
	setWins(clan)
	return true, "🛡️ Clan [" .. clan.tag .. "] " .. clan.name .. " created!"
end

local function leave(player: Player, data: any): (boolean, string)
	local id = data.clan
	if not id then
		return false, "You're not in a clan."
	end
	local released: string? = nil
	local clan = update(id, function(saved)
		saved.members[tostring(player.UserId)] = nil
		if count(saved.members) == 0 then
			released = saved.tag
			return nil -- the last one out closes the clan
		end
		if saved.owner == player.UserId then
			for userId in saved.members do
				saved.owner = tonumber(userId) or saved.owner
				break
			end
		end
		return saved
	end)
	if released then
		claimTag(released, nil)
		if online() and winStore then
			pcall(function()
				(winStore :: OrderedDataStore):RemoveAsync(id)
			end)
		end
	end
	data.clan = nil
	showTag(player, nil)
	refreshMembers(id, clan)
	return true, "You left the clan."
end

local function invite(player: Player, data: any, userId: any): (boolean, string)
	local target = type(userId) == "number" and Players:GetPlayerByUserId(userId)
	if not data.clan then
		return false, "Make or join a clan first."
	end
	if not target or target == player then
		return false, "They're not in this server."
	end
	local targetData = DataService.get(target)
	if targetData and targetData.clan == data.clan then
		return false, "They're already in your clan!"
	end
	local clan = memory[data.clan] or load(data.clan)
	if not clan then
		return false, "Couldn't find your clan."
	end
	invites[target] = invites[target] or {}
	invites[target][clan.id] = os.clock()
	Remotes.event("ClanInvite"):FireClient(target, clan.id, clan.name, clan.tag, player.DisplayName)
	return true, "Invite sent to " .. target.DisplayName .. "!"
end

local function accept(player: Player, data: any, id: any): (boolean, string)
	local mine = invites[player]
	local sent = type(id) == "string" and mine and mine[id]
	if not sent or os.clock() - sent > Config.Clans.InviteSeconds then
		return false, "That invite ran out."
	end
	mine[id] = nil
	if data.clan then
		return false, "Leave your clan first."
	end
	local full = false
	local clan = update(id, function(saved)
		if count(saved.members) >= Config.Clans.MaxMembers then
			full = true
			return saved
		end
		saved.members[tostring(player.UserId)] = player.DisplayName
		return saved
	end)
	if not clan then
		return false, "That clan is gone."
	end
	if full then
		return false, "That clan is full."
	end
	data.clan = id
	showTag(player, clan)
	refreshMembers(id, clan)
	Notify.player(player, "🛡️ Welcome to [" .. clan.tag .. "] " .. clan.name .. "!", "success")
	return true, "Joined!"
end

local function kick(player: Player, data: any, userId: any): (boolean, string)
	if not data.clan or type(userId) ~= "number" or userId == player.UserId then
		return false, "Can't do that."
	end
	local allowed = true
	local clan = update(data.clan, function(saved)
		if saved.owner ~= player.UserId then
			allowed = false
			return saved
		end
		saved.members[tostring(userId)] = nil
		return saved
	end)
	if not allowed then
		return false, "Only the clan leader can remove people."
	end
	refreshMembers(data.clan, clan)
	return true, "Removed."
end

local function onAction(player: Player, action: any, a: any, b: any): (boolean, string)
	local data = DataService.get(player)
	if not data or os.clock() - (lastAction[player] or 0) < 1 then
		return false, "Slow down!"
	end
	lastAction[player] = os.clock()
	if action == "create" then
		return create(player, data, a, b)
	elseif action == "leave" then
		return leave(player, data)
	elseif action == "invite" then
		return invite(player, data, a)
	elseif action == "accept" then
		return accept(player, data, a)
	elseif action == "kick" then
		return kick(player, data, a)
	end
	return false, "Can't do that."
end

-- The top clans by wins (refreshed at most once a minute).
local function topClans(): { any }
	if os.clock() - topCachedAt < 60 and #topCache > 0 then
		return topCache
	end
	topCachedAt = os.clock()
	local list = {}
	if online() and winStore then
		local ok, pages = pcall(function()
			return (winStore :: OrderedDataStore):GetSortedAsync(false, 10)
		end)
		if ok and pages then
			for _, entry in pages:GetCurrentPage() do
				local clan = memory[entry.key] or load(entry.key)
				if clan then
					table.insert(
						list,
						{ name = clan.name, tag = clan.tag, wins = entry.value, members = count(clan.members) }
					)
				end
			end
		end
	else
		for _, clan in memory do
			table.insert(list, { name = clan.name, tag = clan.tag, wins = clan.wins, members = count(clan.members) })
		end
		table.sort(list, function(x, y)
			return x.wins > y.wins
		end)
		while #list > 10 do
			table.remove(list)
		end
	end
	topCache = list
	return list
end

local function getClan(player: Player): any
	local data = DataService.get(player)
	if not data then
		return nil
	end
	local mine = nil
	if data.clan then
		local clan = memory[data.clan] or load(data.clan)
		if clan then
			local members = {}
			for userId, name in clan.members do
				local id = tonumber(userId) or 0
				table.insert(members, {
					userId = id,
					name = name,
					leader = id == clan.owner,
					online = Players:GetPlayerByUserId(id) ~= nil,
				})
			end
			table.sort(members, function(x, y)
				if x.online ~= y.online then
					return x.online
				end
				return x.name < y.name
			end)
			mine = {
				id = clan.id,
				name = clan.name,
				tag = clan.tag,
				wins = clan.wins,
				color = Config.Clans.Colors[clan.color] or Config.Clans.Colors[1],
				leader = clan.owner == player.UserId,
				members = members,
				max = Config.Clans.MaxMembers,
			}
		end
	end
	return { clan = mine, top = topClans(), cost = Config.Clans.CreateCost }
end

function ClanService.init()
	local ok = pcall(function()
		clanStore = DataStoreService:GetDataStore("Clans_v1")
		tagStore = DataStoreService:GetDataStore("ClanTags_v1")
		winStore = DataStoreService:GetOrderedDataStore("ClanWins_v1")
	end)
	if not ok then
		clanStore, tagStore, winStore = nil, nil, nil
	end
end

function ClanService.start()
	Remotes.func("ClanAction").OnServerInvoke = onAction
	Remotes.func("GetClan").OnServerInvoke = getClan

	-- Joining: check you're still in your clan (you may have been removed).
	DataService.ProfileLoaded:Connect(function(player, data)
		if not data.clan then
			return
		end
		local clan = load(data.clan)
		if clan and clan.members[tostring(player.UserId)] then
			showTag(player, clan)
		elseif clan or online() then
			data.clan = nil
			showTag(player, nil)
		end
	end)
	-- Every win counts for the whole clan.
	MatchService.Won:Connect(function(player)
		local data = DataService.get(player)
		if data and data.clan then
			local clan = update(data.clan, function(saved)
				saved.wins = (saved.wins or 0) + 1
				return saved
			end)
			if clan then
				setWins(clan)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		invites[player] = nil
		lastAction[player] = nil
	end)
end

return ClanService
