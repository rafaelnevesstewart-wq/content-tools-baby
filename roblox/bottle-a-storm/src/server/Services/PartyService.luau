-- Parties: invite friends in the server (👥 Party) so you always end up on
-- the same team. Up to Config.Party.MaxSize players; the one who invited
-- first leads. MatchService asks for the parties when it makes teams.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent.Parent.Modules
local Notify = require(Modules.Notify)

local PartyService = {}

type Party = { leader: Player, members: { Player } }

local partyOf: { [Player]: Party } = {}
local invites: { [Player]: { [Player]: number } } = {} -- invited -> inviter -> when
local lastInvite: { [Player]: number } = {}

local function publish(party: Party?)
	if not party then
		return
	end
	local names = {}
	for _, member in party.members do
		table.insert(names, { userId = member.UserId, name = member.DisplayName, leader = member == party.leader })
	end
	local encoded = HttpService:JSONEncode(names)
	for _, member in party.members do
		if member.Parent then
			member:SetAttribute("Party", encoded)
		end
	end
end

local function leave(player: Player)
	local party = partyOf[player]
	if not party then
		return
	end
	partyOf[player] = nil
	if player.Parent then
		player:SetAttribute("Party", nil)
	end
	local index = table.find(party.members, player)
	if index then
		table.remove(party.members, index)
	end
	if #party.members <= 1 then
		-- A party of one is no party.
		for _, member in party.members do
			partyOf[member] = nil
			if member.Parent then
				member:SetAttribute("Party", nil)
				Notify.player(member, "👥 Your party ended.", "info")
			end
		end
		return
	end
	if party.leader == player then
		party.leader = party.members[1]
	end
	for _, member in party.members do
		Notify.player(member, "👥 " .. player.DisplayName .. " left the party.", "info")
	end
	publish(party)
end

local function invite(player: Player, target: Player)
	if target == player or not target.Parent then
		return
	end
	if os.clock() - (lastInvite[player] or 0) < 2 then
		Notify.player(player, "Slow down!", "warn")
		return
	end
	lastInvite[player] = os.clock()
	local party = partyOf[player]
	if party and #party.members >= Config.Party.MaxSize then
		Notify.player(player, "👥 Your party is full (" .. Config.Party.MaxSize .. " players).", "warn")
		return
	end
	if partyOf[target] and partyOf[target] == party then
		return
	end
	invites[target] = invites[target] or {}
	invites[target][player] = os.clock()
	Remotes.event("PartyInvite"):FireClient(target, player.UserId, player.DisplayName)
	Notify.player(player, "👥 Invited " .. target.DisplayName .. "!", "success")
end

local function accept(player: Player, inviter: Player)
	local sent = invites[player] and invites[player][inviter]
	if not sent or os.clock() - sent > Config.Party.InviteSeconds or not inviter.Parent then
		Notify.player(player, "That invite expired.", "warn")
		return
	end
	invites[player][inviter] = nil
	local party = partyOf[inviter]
	if not party then
		party = { leader = inviter, members = { inviter } }
		partyOf[inviter] = party
	end
	if #party.members >= Config.Party.MaxSize then
		Notify.player(player, "👥 That party is full.", "warn")
		return
	end
	leave(player)
	table.insert(party.members, player)
	partyOf[player] = party
	for _, member in party.members do
		Notify.player(member, "👥 " .. player.DisplayName .. " joined the party!", "success")
	end
	publish(party)
end

local function onAction(player: Player, action: any, userId: any)
	local other = if type(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
	if action == "invite" and other then
		invite(player, other)
	elseif action == "accept" and other then
		accept(player, other)
	elseif action == "decline" and other then
		if invites[player] then
			invites[player][other] = nil
		end
		Notify.player(other, "👥 " .. player.DisplayName .. " said no thanks.", "info")
	elseif action == "leave" then
		leave(player)
	elseif action == "kick" and other then
		local party = partyOf[player]
		if party and party.leader == player and partyOf[other] == party then
			leave(other)
			Notify.player(other, "👥 You were removed from the party.", "warn")
		end
	end
end

-- The players in `list` grouped by party (players with no party alone).
function PartyService.groups(list: { Player }): { { Player } }
	local seen: { [Player]: boolean } = {}
	local inList: { [Player]: boolean } = {}
	for _, player in list do
		inList[player] = true
	end
	local groups = {}
	for _, player in list do
		if not seen[player] then
			local party = partyOf[player]
			local group = {}
			if party then
				for _, member in party.members do
					if inList[member] and not seen[member] then
						seen[member] = true
						table.insert(group, member)
					end
				end
			else
				seen[player] = true
				table.insert(group, player)
			end
			table.insert(groups, group)
		end
	end
	return groups
end

function PartyService.start()
	Remotes.event("PartyAction").OnServerEvent:Connect(onAction)
	Players.PlayerRemoving:Connect(function(player)
		leave(player)
		invites[player] = nil
		lastInvite[player] = nil
		for _, list in invites do
			list[player] = nil
		end
	end)
end

return PartyService
