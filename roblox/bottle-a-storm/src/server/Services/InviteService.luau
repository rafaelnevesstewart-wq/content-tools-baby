-- 📱 Friend invites: invite friends from 👥 Party (Roblox's invite window).
-- When someone new joins through your invite (or by joining you), you both
-- get a prize: they get a starter boost, you get Sparks. If you're in
-- another server when they join, your prize waits for you (a DataStore
-- queue) and arrives next time you join. Every player counts only once,
-- and only when they're new.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)

local Modules = script.Parent.Parent.Modules
local Notify = require(Modules.Notify)

local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local RewardService = require(script.Parent.RewardService)

local InviteService = {}

local queue: DataStore? = nil

-- Who brought this player here (0 if nobody).
local function referrerOf(player: Player): number
	local ok, joinData = pcall(function()
		return player:GetJoinData()
	end)
	local referred = if ok and type(joinData) == "table" then joinData.ReferredByPlayerId else nil
	if type(referred) == "number" and referred > 0 then
		return referred
	end
	local follow = player.FollowUserId
	return if follow and follow > 0 then follow else 0
end

local function rewardInviter(inviter: Player, count: number, newName: string?)
	local data = DataService.get(inviter)
	if not data then
		return
	end
	local already = data.stats.invites or 0
	local paid = math.clamp(Config.Invite.MaxRewards - already, 0, count)
	data.stats.invites = already + count
	if paid > 0 then
		IncomeService.addSparks(inviter, Config.Invite.InviterSparks * paid)
	end
	Notify.player(
		inviter,
		"📱 "
			.. (if newName
				then newName .. " joined from your invite!"
				else count .. " friend(s) joined from your invites!")
			.. (if paid > 0 then " +⚡" .. Format.number(Config.Invite.InviterSparks * paid) else ""),
		"rare"
	)
end

-- Prizes waiting from while this player was somewhere else.
local function claimQueued(player: Player)
	if not queue or DataService.isMemoryMode() then
		return
	end
	local count = 0
	pcall(function()
		(queue :: DataStore):UpdateAsync(tostring(player.UserId), function(value)
			count = if type(value) == "number" then value else 0
			return nil
		end)
	end)
	if count > 0 then
		rewardInviter(player, count, nil)
	end
end

local function onLoaded(player: Player, data: any)
	claimQueued(player)
	if data.invitedBy ~= nil then
		return -- already checked once
	end
	local inviter = referrerOf(player)
	local isNew = (data.stats.matches or 0) == 0
	data.invitedBy = if isNew then inviter else 0
	if not isNew or inviter == 0 or inviter == player.UserId then
		return
	end
	-- The new player's welcome prize.
	IncomeService.addSparks(player, Config.Invite.NewSparks)
	RewardService.grant(player, { kind = "kit", rarity = Config.Invite.NewKitRarity })
	Notify.player(player, "📱 Welcome! You joined through a friend, so you both get a prize!", "rare")
	-- The inviter's prize: now if they're here, otherwise it waits for them.
	local here = Players:GetPlayerByUserId(inviter)
	if here then
		rewardInviter(here, 1, player.DisplayName)
	elseif queue and not DataService.isMemoryMode() then
		pcall(function()
			(queue :: DataStore):UpdateAsync(tostring(inviter), function(value)
				return (if type(value) == "number" then value else 0) + 1
			end)
		end)
	end
end

function InviteService.init()
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore("InviteRewards_v1")
	end)
	queue = if ok then store else nil
end

function InviteService.start()
	DataService.ProfileLoaded:Connect(function(player, data)
		task.spawn(onLoaded, player, data)
	end)
end

return InviteService
