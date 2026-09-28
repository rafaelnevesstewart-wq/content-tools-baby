-- 🐎 Riding your mount (CosmeticsData category "mount", MountModels) around
-- the lobby: press H (or 🐎) to hop on or off. The mount is welded under
-- you, you sit higher and move faster; clouds fly (MountController does the
-- flying and the galloping on your screen). You get off automatically when
-- a match or a duel starts.
--
-- 🐉 Taming the Storm Dragon: whoever does the most damage to the boss
-- (BossService) has a Config.Mounts.DragonChance chance to tame it as a
-- mount, and it's certain after Config.Mounts.DragonPity tries.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local CosmeticsData = require(Shared.CosmeticsData)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent.Parent.Modules
local MountModels = require(Modules.MountModels)
local Notify = require(Modules.Notify)

local BossService = require(script.Parent.BossService)
local CosmeticService = require(script.Parent.CosmeticService)
local DataService = require(script.Parent.DataService)

local MountService = {}

type Ride = { model: Model, hipHeight: number, walkSpeed: number, jumpPower: number }

local rides: { [Player]: Ride } = {}

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

local function dismount(player: Player)
	local ride = rides[player]
	if not ride then
		return
	end
	rides[player] = nil
	ride.model:Destroy()
	local humanoid = humanoidOf(player)
	if humanoid then
		humanoid.HipHeight = ride.hipHeight
		humanoid.WalkSpeed = ride.walkSpeed
		humanoid.JumpPower = ride.jumpPower
	end
	player:SetAttribute("Mounted", nil)
end

local function mount(player: Player)
	local data = DataService.get(player)
	local character = player.Character
	local humanoid = humanoidOf(player)
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not data or not character or not humanoid or not root or humanoid.Health <= 0 then
		return
	end
	if player:GetAttribute("InMatch") or player:GetAttribute("Dueling") then
		Notify.player(player, "🐎 Mounts are for the lobby!", "error")
		return
	end
	local item = CosmeticsData.get(data.cosmetics.mount)
	if not item or not item.mount or not data.cosmetics.owned[item.id] then
		Notify.player(player, "🐎 Get a mount in 🎨 Style → Mounts (or the Shop Street), then press H!", "info")
		return
	end
	local model, kind = MountModels.build(item.mount)
	if not model or not kind then
		return
	end
	local hipHeight = humanoid.HipHeight
	local newHip = hipHeight + kind.raise
	humanoid.HipHeight = newHip
	local weld = Instance.new("Weld")
	weld.Name = "MountWeld"
	weld.Part0 = root
	weld.Part1 = model.PrimaryPart
	-- The body's middle sits BodyHeight above the ground, under the rider.
	weld.C0 = CFrame.new(0, -(root.Size.Y / 2 + newHip) + kind.bodyHeight, 0.3)
	weld.Parent = model.PrimaryPart
	model.Name = player.Name .. "_Mount"
	model:SetAttribute("OwnerId", player.UserId)
	CollectionService:AddTag(model, "Mount")
	model.Parent = character
	rides[player] = {
		model = model,
		hipHeight = hipHeight,
		walkSpeed = humanoid.WalkSpeed,
		jumpPower = humanoid.JumpPower,
	}
	humanoid.WalkSpeed = Config.Mounts.Speed
	humanoid.UseJumpPower = true
	humanoid.JumpPower = Config.Mounts.JumpPower
	player:SetAttribute("Mounted", item.mount)
	player:SetAttribute("MountFlies", kind.flies == true)
end

local function tryTame(_helpers: { Player }, damage: { [Player]: number }?)
	local best, most = nil, 0
	local hits: { [Player]: number } = damage or {}
	for player, amount in hits do
		if player.Parent and amount > most then
			best, most = player, amount
		end
	end
	local data = best and DataService.get(best)
	if not best or not data or data.cosmetics.owned.MountDragon then
		return
	end
	local tries = (data.stats.dragonTries or 0) + 1
	data.stats.dragonTries = tries
	if tries < Config.Mounts.DragonPity and math.random() > Config.Mounts.DragonChance then
		Notify.player(
			best,
			"🐉 You did the most damage, but the dragon got away... Keep trying to tame it! ("
				.. tries
				.. "/"
				.. Config.Mounts.DragonPity
				.. ")",
			"info"
		)
		return
	end
	if CosmeticService.grant(best, "MountDragon") == nil then
		Notify.all("🐉 " .. best.DisplayName .. " TAMED THE STORM DRAGON! It's their mount now!", "rare")
		Notify.player(best, "🐉 The Storm Dragon is yours! Ride it in the lobby (press H). It flies!", "success")
	end
end

function MountService.start()
	BossService.Defeated:Connect(tryTame)
	Remotes.event("Mount").OnServerEvent:Connect(function(player)
		if rides[player] then
			dismount(player)
		else
			mount(player)
		end
	end)
	local function onPlayer(player: Player)
		player.CharacterRemoving:Connect(function()
			rides[player] = nil
			player:SetAttribute("Mounted", nil)
		end)
		for _, attribute in { "InMatch", "Dueling" } do
			player:GetAttributeChangedSignal(attribute):Connect(function()
				if player:GetAttribute(attribute) then
					dismount(player)
				end
			end)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		rides[player] = nil
	end)
end

return MountService
