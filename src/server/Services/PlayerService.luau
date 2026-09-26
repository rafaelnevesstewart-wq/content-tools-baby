-- Per-player progress: coins, food, growth, eggs, riders, molting, perks,
-- and the State snapshot the HUD draws from.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local PlayerService = {}
local S

local sessions = {} -- [Player] = session
local friendCache = {} -- ["a:b"] = boolean

local function today(): number
	return os.time() // 86400
end

function PlayerService:Init(services)
	S = services
	Remotes.Action.OnServerEvent:Connect(function(player, action, arg)
		self:_onAction(player, action, arg)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:_onRemoving(player)
	end)
	game:BindToClose(function()
		for player, session in sessions do
			S.DataService:Save(player, session.Profile)
		end
	end)
end

function PlayerService:Start()
	Players.PlayerAdded:Connect(function(player)
		self:_onAdded(player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(self._onAdded, self, player)
	end

	local elapsed, bondClock, saveClock = 0, 0, 0
	while true do
		local dt = task.wait(1)
		elapsed += dt
		bondClock += dt
		saveClock += dt
		if bondClock >= 5 then
			bondClock = 0
			self:_updateHerdBonds()
		end
		for player, session in sessions do
			self:_tick(player, session, dt)
		end
		self:_rescueFallen()
		if saveClock >= Config.AutosaveInterval then
			saveClock = 0
			for player, session in sessions do
				task.spawn(S.DataService.Save, S.DataService, player, session.Profile)
			end
		end
	end
end

-- Session lifecycle ---------------------------------------------------------

function PlayerService:_onAdded(player: Player)
	if sessions[player] then
		return
	end
	local profile = S.DataService:Load(player)
	if not player.Parent then
		S.DataService:Release(player)
		return
	end
	S.ShopService:LoadPasses(player)

	local session = {
		Profile = profile,
		LockedUntil = os.clock() + Config.Steal.ShellLockBase + Config.Steal.ShellLockPerMolt * profile.Molts,
		HerdBond = false,
		RoarNight = -1,
		NightDamage = 0,
		BossDamage = 0,
		LastAction = 0,
		LastTravel = 0,
	}
	sessions[player] = session
	player:SetAttribute("Level", profile.Level)

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Parent = leaderstats
	local stage = Instance.new("StringValue")
	stage.Name = "Stage"
	stage.Parent = leaderstats
	local kills = Instance.new("IntValue")
	kills.Name = "Kills"
	kills.Parent = leaderstats
	leaderstats.Parent = player

	-- Growth while away.
	if profile.LastOnline > 0 then
		local away = math.min(os.time() - profile.LastOnline, Config.Growth.OfflineCapSeconds)
		if away > 60 then
			local gained = away * Config.Growth.OfflinePerSecond * self:GrowthMult(player)
			self:AddGrowth(player, gained, true)
			self:Notify(player, string.format("Your titan grew %s while you were away!", Util.formatNumber(gained)))
		end
	end
	self:_checkFreeEgg(player)

	S.TitanService:SpawnTitan(player)
	player.CharacterAdded:Connect(function(character)
		self:_onCharacter(player, character)
	end)
	if player.Character then
		self:_onCharacter(player, player.Character)
	end
	self:MarkDirty(player)
end

function PlayerService:_onCharacter(player: Player, character: Model)
	-- Players are the only thing titans collide with (see TitanService).
	local function setGroup(descendant: Instance)
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = "Players"
		end
	end
	for _, descendant in character:GetDescendants() do
		setGroup(descendant)
	end
	character.DescendantAdded:Connect(setGroup)
	character:WaitForChild("HumanoidRootPart", 10)
	task.wait(0.1)
	S.TitanService:PlaceOnDeck(player)
	S.CombatService:OnCharacter(player, character)
end

-- Safety net: anyone who ends up under the ground goes back to their titan's
-- deck (or the town if they have no titan yet) instead of falling forever.
function PlayerService:_rescueFallen()
	for player in sessions do
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if hrp and humanoid and humanoid.Health > 0 and hrp.Position.Y < -25 then
			if S.TitanService:GetTitan(player) then
				S.TitanService:PlaceOnDeck(player)
			else
				character:PivotTo(CFrame.new(S.WorldService:TravelPoint("Base") + Vector3.new(0, 4, 0)))
			end
		end
	end
end

function PlayerService:_onRemoving(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	S.StealService:OnPlayerRemoving(player)
	S.TitanService:RemoveTitan(player)
	S.DataService:Save(player, session.Profile)
	S.DataService:Release(player)
	sessions[player] = nil
end

-- Accessors -----------------------------------------------------------------

function PlayerService:GetSession(player: Player)
	return sessions[player]
end

function PlayerService:GetProfile(player: Player)
	local session = sessions[player]
	return session and session.Profile
end

function PlayerService:AllSessions()
	return sessions
end

function PlayerService:StageDef(player: Player)
	local profile = self:GetProfile(player)
	return Config.Stages[profile and profile.Stage or 1]
end

function PlayerService:RiderSlots(player: Player): number
	local profile = self:GetProfile(player)
	local slots = Config.Stages[profile.Stage].RiderSlots + math.min(profile.Molts, Config.Molt.BonusRiderSlotsCap)
	if S.ShopService:Owns(player, "PlusRiderSlots") then
		slots += 2
	end
	return slots
end

function PlayerService:EggSlots(player: Player): number
	return Config.Stages[self:GetProfile(player).Stage].EggSlots
end

function PlayerService:FoodCapacity(player: Player): number
	local cap = Config.Growth.BaseFoodCapacity
	if S.ShopService:Owns(player, "BigBackpack") then
		cap *= 2
	end
	return cap
end

function PlayerService:GrowthMult(player: Player): number
	local mult = 1
	if S.ShopService:Owns(player, "DoubleGrowth") then
		mult *= 2
	end
	local profile = self:GetProfile(player)
	if profile and profile.GrowthSnackUntil > os.time() then
		mult *= 2
	end
	return mult
end

function PlayerService:IsLocked(player: Player): boolean
	local session = sessions[player]
	return session ~= nil and os.clock() < session.LockedUntil
end

function PlayerService:HasResonance(player: Player): boolean
	local profile = self:GetProfile(player)
	if profile.TitanMutation == "Normal" then
		return false
	end
	local count = 0
	for _, rider in profile.Riders do
		if rider.Mutation == profile.TitanMutation and not rider.InTransit then
			count += 1
		end
	end
	return count >= Config.Perks.ResonanceCount
end

function PlayerService:RiderIncome(rider): number
	return Util.riderDef(rider.Name).Income * Util.mutation(rider.Mutation).Mult
end

function PlayerService:Income(player: Player): number
	local session = sessions[player]
	if not session then
		return 0
	end
	local profile = session.Profile
	local base = 0
	for _, rider in profile.Riders do
		if not rider.InTransit then
			base += self:RiderIncome(rider)
		end
	end
	local mult = Config.Stages[profile.Stage].IncomeMult * Util.mutation(profile.TitanMutation).Mult * (1 + profile.Molts * Config.Molt.EarningsBonus)
	if S.ShopService:Owns(player, "VIP") then
		mult *= Config.Perks.VipIncomeMult
	end
	if self:HasResonance(player) then
		mult *= Config.Perks.ResonanceMult
	end
	if session.HerdBond then
		mult *= Config.Perks.HerdBondMult
	end
	return base * mult
end

function PlayerService:FoodCrateCost(player: Player): number
	local stage = self:GetProfile(player).Stage
	return math.floor(Config.FoodCrate.BaseCost * Config.FoodCrate.CostGrowth ^ (stage - 1))
end

-- Mutations and rolls -------------------------------------------------------

function PlayerService:RollMutation(player: Player?): string
	local lucky = S.CycleService:IsStorm()
	if player then
		local profile = self:GetProfile(player)
		if profile and profile.NightsSurvivedStreak >= Config.Nightfall.WeatheredStreak then
			lucky = true
		end
	end
	local picked = Util.weightedPick(Config.Mutations, function(m)
		if lucky and m.Name ~= "Normal" then
			return m.Weight * Config.StormMutationLuck
		end
		return m.Weight
	end)
	return picked.Name
end

function PlayerService:RollRarity(player: Player?, minRarity: string?): string
	local lucky = player ~= nil and S.ShopService:Owns(player, "LuckyHatcher")
	local minIndex = 1
	if minRarity then
		minIndex = table.find(Config.Rarities, Util.rarity(minRarity)) or 1
	end
	local pool = {}
	for i, r in Config.Rarities do
		if i >= minIndex then
			table.insert(pool, r)
		end
	end
	local picked = Util.weightedPick(pool, function(r)
		if lucky and r.Name ~= "Common" then
			return r.Weight * Config.LuckyHatcherBoost
		end
		return r.Weight
	end)
	return picked.Name
end

function PlayerService:MakeRider(player: Player?, rarity: string, mutation: string?)
	local options = {}
	for _, def in Config.Riders do
		if def.Rarity == rarity then
			table.insert(options, def)
		end
	end
	if #options == 0 then
		options = { Config.Riders[1] }
	end
	return {
		Name = options[math.random(1, #options)].Name,
		Mutation = mutation or self:RollMutation(player),
	}
end

function PlayerService:_nextId(profile): number
	local id = profile.NextId
	profile.NextId += 1
	return id
end

-- Mutators ------------------------------------------------------------------

function PlayerService:MarkDirty(player: Player)
	local session = sessions[player]
	if session then
		session.Dirty = true
	end
end

function PlayerService:Notify(player: Player, text: string)
	Remotes.Notify:FireClient(player, text)
end

function PlayerService:NotifyAll(text: string)
	Remotes.Notify:FireAllClients(text)
end

function PlayerService:AddCoins(player: Player, amount: number)
	local profile = self:GetProfile(player)
	if not profile then
		return
	end
	profile.Coins = math.max(0, profile.Coins + amount)
	self:MarkDirty(player)
end

-- Fighting experience --------------------------------------------------------

function PlayerService:XPToNext(level: number): number?
	if level >= Config.Leveling.MaxLevel then
		return nil
	end
	return math.floor(Config.Leveling.XPBase * Config.Leveling.XPGrowth ^ (level - 1))
end

function PlayerService:AddXP(player: Player, amount: number)
	local profile = self:GetProfile(player)
	if not profile or amount <= 0 then
		return
	end
	profile.XP += math.floor(amount)
	local levelled = false
	local need = self:XPToNext(profile.Level)
	while need and profile.XP >= need do
		profile.XP -= need
		profile.Level += 1
		levelled = true
		need = self:XPToNext(profile.Level)
	end
	if not need then
		profile.XP = 0
	end
	if levelled then
		S.CombatService:ApplyStats(player)
		S.CombatService:RefillOnLevelUp(player)
		Remotes.Ui:FireClient(player, { LevelUp = profile.Level })
		self:Notify(player, string.format("⭐ LEVEL UP! You are now level %d. More health, power and damage.", profile.Level))
	end
	player:SetAttribute("Level", profile.Level)
	self:MarkDirty(player)
end

function PlayerService:AddGrowth(player: Player, amount: number, silent: boolean?)
	local profile = self:GetProfile(player)
	if not profile then
		return
	end
	profile.Growth += amount
	local grewTo = nil
	while true do
		local def = Config.Stages[profile.Stage]
		if not def.GrowthToNext or profile.Growth < def.GrowthToNext then
			break
		end
		profile.Growth -= def.GrowthToNext
		profile.Stage += 1
		grewTo = Config.Stages[profile.Stage]
	end
	local last = Config.Stages[profile.Stage]
	if not last.GrowthToNext then
		profile.Growth = 0
	end
	if grewTo then
		S.TitanService:Rebuild(player)
		if not silent then
			self:Notify(player, string.format("Your titan grew into a %s!", grewTo.Name))
		end
	end
	self:MarkDirty(player)
end

function PlayerService:AddFood(player: Player, amount: number): number
	local profile = self:GetProfile(player)
	if not profile then
		return 0
	end
	local room = self:FoodCapacity(player) - profile.Food
	local added = math.clamp(amount, 0, room)
	profile.Food += added
	self:MarkDirty(player)
	return added
end

function PlayerService:FreeEggSlots(player: Player): number
	return self:EggSlots(player) - #self:GetProfile(player).Eggs
end

function PlayerService:FreeRiderSlots(player: Player): number
	return self:RiderSlots(player) - #self:GetProfile(player).Riders
end

function PlayerService:AddEgg(player: Player, rarity: string, existing): boolean
	local profile = self:GetProfile(player)
	if not profile or self:FreeEggSlots(player) <= 0 then
		return false
	end
	local egg = existing or {
		Rarity = rarity,
		HatchAt = os.time() + Util.rarity(rarity).HatchTime,
	}
	egg.Id = self:_nextId(profile)
	egg.InTransit = nil
	table.insert(profile.Eggs, egg)
	S.TitanService:RefreshDeck(player)
	self:MarkDirty(player)
	return true
end

function PlayerService:AddRider(player: Player, rider): boolean
	local profile = self:GetProfile(player)
	if not profile or self:FreeRiderSlots(player) <= 0 then
		return false
	end
	rider.Id = self:_nextId(profile)
	rider.InTransit = nil
	table.insert(profile.Riders, rider)
	S.TitanService:RefreshDeck(player)
	self:MarkDirty(player)
	return true
end

function PlayerService:FindItem(player: Player, kind: string, id: number)
	local profile = self:GetProfile(player)
	if not profile then
		return nil, nil
	end
	local list = kind == "Egg" and profile.Eggs or profile.Riders
	for index, item in list do
		if item.Id == id then
			return item, index
		end
	end
	return nil, nil
end

function PlayerService:RemoveItem(player: Player, kind: string, id: number)
	local profile = self:GetProfile(player)
	local item, index = self:FindItem(player, kind, id)
	if not item then
		return nil
	end
	local list = kind == "Egg" and profile.Eggs or profile.Riders
	table.remove(list, index)
	S.TitanService:RefreshDeck(player)
	self:MarkDirty(player)
	return item
end

function PlayerService:ReleaseRider(player: Player, riderId: number)
	local rider, _ = self:FindItem(player, "Rider", riderId)
	if not rider or rider.InTransit then
		return
	end
	local reward = math.floor(self:RiderIncome(rider) * 120)
	self:RemoveItem(player, "Rider", riderId)
	self:AddCoins(player, reward)
	self:Notify(player, string.format("Released %s for %s coins.", rider.Name, Util.formatNumber(reward)))
end

function PlayerService:_hatchReady(player: Player, force: boolean?)
	local profile = self:GetProfile(player)
	local now = os.time()
	local hatchedAny = false
	for i = #profile.Eggs, 1, -1 do
		local egg = profile.Eggs[i]
		if not egg.InTransit and (force or now >= egg.HatchAt) then
			if self:FreeRiderSlots(player) <= 0 then
				if force then
					self:Notify(player, "No free Rider slot. Release a Rider or grow your titan.")
				end
				break
			end
			table.remove(profile.Eggs, i)
			local rider = self:MakeRider(player, egg.Rarity)
			self:AddRider(player, rider)
			hatchedAny = true
			local label = rider.Mutation ~= "Normal" and (rider.Mutation .. " ") or ""
			self:Notify(player, string.format("Your %s egg hatched: %s%s!", egg.Rarity, label, rider.Name))
			if rider.Mutation ~= "Normal" or table.find({ "Legendary", "Mythic" }, egg.Rarity) then
				self:NotifyAll(string.format("%s hatched a %s %s%s!", player.DisplayName, egg.Rarity, label, rider.Name))
			end
		end
	end
	if hatchedAny then
		S.TitanService:RefreshDeck(player)
	end
	return hatchedAny
end

function PlayerService:_checkFreeEgg(player: Player)
	local profile = self:GetProfile(player)
	if S.ShopService:Owns(player, "VIP") and profile.LastFreeEggDay ~= today() then
		if self:FreeEggSlots(player) > 0 then
			profile.LastFreeEggDay = today()
			self:AddEgg(player, self:RollRarity(player, "Uncommon"))
			self:Notify(player, "VIP daily egg added to your titan!")
		end
	end
end

function PlayerService:OnPassesChanged(player: Player)
	self:_checkFreeEgg(player)
	S.TitanService:RefreshDeck(player)
	self:MarkDirty(player)
	self:Notify(player, "Pass unlocked. Thank you!")
end

-- Weapons, spells and upgrades -------------------------------------------------

function PlayerService:GrantWeapon(player: Player, key: string): boolean
	local profile = self:GetProfile(player)
	local def = Util.find(Config.Weapons, "Key", key)
	if not profile or not def then
		return false
	end
	if not table.find(profile.Weapons, key) then
		table.insert(profile.Weapons, key)
		self:Notify(player, string.format("New weapon: %s! Check your backpack.", def.Name))
	end
	S.CombatService:GiveWeapons(player)
	self:MarkDirty(player)
	return true
end

function PlayerService:_buyWeapon(player: Player, key: string)
	local profile = self:GetProfile(player)
	local def = Util.find(Config.Weapons, "Key", key)
	if not def or def.Currency ~= "Coins" or table.find(profile.Weapons, key) then
		return
	end
	if def.MinLevel and profile.Level < def.MinLevel then
		self:Notify(player, string.format("The %s needs level %d. Fight monsters to earn XP!", def.Name, def.MinLevel))
		return
	end
	if profile.Coins < def.Price then
		self:Notify(player, string.format("You need %s coins for the %s.", Util.formatNumber(def.Price), def.Name))
		return
	end
	self:AddCoins(player, -def.Price)
	self:GrantWeapon(player, key)
end

function PlayerService:SpellCost(player: Player, key: string): number?
	local def = Util.find(Config.Spells, "Key", key)
	local level = self:GetProfile(player).Spells[key] or 0
	if not def or level >= Config.SpellMaxLevel then
		return nil
	end
	if level == 0 then
		return def.UnlockCost
	end
	return Config.SpellUpgradeCost * level * level
end

function PlayerService:_buySpell(player: Player, key: string)
	local profile = self:GetProfile(player)
	local cost = self:SpellCost(player, key)
	local def = Util.find(Config.Spells, "Key", key)
	if not cost or not def then
		return
	end
	if profile.Coins < cost then
		self:Notify(player, string.format("You need %s coins.", Util.formatNumber(cost)))
		return
	end
	self:AddCoins(player, -cost)
	profile.Spells[key] = (profile.Spells[key] or 0) + 1
	self:Notify(player, string.format("%s is now level %d! Press %s to cast.", def.Name, profile.Spells[key], def.Hotkey))
	self:MarkDirty(player)
end

function PlayerService:UpgradeCost(player: Player, key: string): number?
	local def = Util.find(Config.Upgrades, "Key", key)
	local level = self:GetProfile(player).Upgrades[key] or 0
	if not def or level >= def.MaxLevel then
		return nil
	end
	return math.floor(def.BaseCost * def.Growth ^ level)
end

function PlayerService:_buyUpgrade(player: Player, key: string)
	local profile = self:GetProfile(player)
	local cost = self:UpgradeCost(player, key)
	local def = Util.find(Config.Upgrades, "Key", key)
	if not cost or not def then
		return
	end
	if profile.Coins < cost then
		self:Notify(player, string.format("You need %s coins.", Util.formatNumber(cost)))
		return
	end
	self:AddCoins(player, -cost)
	profile.Upgrades[key] = (profile.Upgrades[key] or 0) + 1
	S.CombatService:ApplyStats(player)
	self:Notify(player, string.format("%s upgraded to level %d!", def.Name, profile.Upgrades[key]))
	self:MarkDirty(player)
end

function PlayerService:_travel(player: Player, place: string)
	local session = sessions[player]
	if os.clock() - session.LastTravel < 8 then
		self:Notify(player, string.format("Travel is recharging (%ds).", math.ceil(8 - (os.clock() - session.LastTravel))))
		return
	end
	if S.TitanService:IsDriving(player) then
		self:Notify(player, "Get off the saddle first.")
		return
	end
	local character = player.Character
	if not character then
		return
	end
	if place == "Titan" then
		S.StealService:DropCarried(player, "travelled away")
		S.TitanService:PlaceOnDeck(player)
	else
		local point = S.WorldService:TravelPoint(place)
		if not point then
			return
		end
		S.StealService:DropCarried(player, "travelled away")
		character:PivotTo(CFrame.new(point + Vector3.new(0, 4, 0)))
	end
	session.LastTravel = os.clock()
end

-- Skins ---------------------------------------------------------------------

function PlayerService:OwnsSkin(player: Player, key: string): boolean
	local profile = self:GetProfile(player)
	return profile ~= nil and (key == "Classic" or table.find(profile.OwnedSkins, key) ~= nil)
end

-- Unlocks a skin and puts it on straight away. Safe to call twice.
function PlayerService:GrantSkin(player: Player, key: string): boolean
	local profile = self:GetProfile(player)
	local skin = Util.find(Config.Skins, "Key", key)
	if not profile or not skin then
		return false
	end
	if not table.find(profile.OwnedSkins, key) then
		table.insert(profile.OwnedSkins, key)
		self:Notify(player, string.format("Unlocked the %s skin!", skin.Name))
	end
	self:EquipSkin(player, key)
	return true
end

function PlayerService:EquipSkin(player: Player, key: string)
	local profile = self:GetProfile(player)
	if not profile or not self:OwnsSkin(player, key) or profile.EquippedSkin == key then
		return
	end
	profile.EquippedSkin = key
	S.TitanService:Rebuild(player)
	self:MarkDirty(player)
end

function PlayerService:_buySkinWithCoins(player: Player, key: string)
	local profile = self:GetProfile(player)
	local skin = Util.find(Config.Skins, "Key", key)
	if not skin or skin.Currency ~= "Coins" then
		return
	end
	if self:OwnsSkin(player, key) then
		self:EquipSkin(player, key)
	elseif profile.Coins < skin.Price then
		self:Notify(player, string.format("You need %s coins for %s.", Util.formatNumber(skin.Price), skin.Name))
	else
		self:AddCoins(player, -skin.Price)
		self:GrantSkin(player, key)
	end
end

function PlayerService:GrantProduct(player: Player, key: string): boolean
	local profile = self:GetProfile(player)
	if not profile then
		return false
	end
	if key == "GrowthSnack" then
		profile.GrowthSnackUntil = math.max(profile.GrowthSnackUntil, os.time()) + Config.Products.GrowthSnackSeconds
		self:Notify(player, "Growth Snack active: 2x growth for 15 minutes!")
	elseif key == "InstantHatch" then
		self:_hatchReady(player, true)
	elseif key == "CoinPouch" or key == "CoinChest" then
		local seconds = key == "CoinPouch" and Config.Products.CoinPouchSeconds or Config.Products.CoinChestSeconds
		local minimum = key == "CoinPouch" and Config.Products.CoinPouchMin or Config.Products.CoinChestMin
		local amount = math.max(minimum, math.floor(self:Income(player) * seconds))
		self:AddCoins(player, amount)
		self:Notify(player, string.format("+%s coins!", Util.formatNumber(amount)))
	elseif key == "StormTotem" then
		S.CycleService:StartStorm(Config.Cycle.StormLength * 2, player)
	else
		return false
	end
	self:MarkDirty(player)
	return true
end

-- Actions from the HUD ------------------------------------------------------

function PlayerService:_onAction(player: Player, action, arg)
	local session = sessions[player]
	if not session or type(action) ~= "string" then
		return
	end
	-- Combat and driving input have their own cooldowns and arrive often.
	if action == "Attack" then
		S.CombatService:Attack(player, arg)
		return
	elseif action == "Cast" then
		S.CombatService:Cast(player, arg)
		return
	elseif action == "Drive" then
		if type(arg) == "table" then
			S.TitanService:SetDriveInput(player, arg.Throttle, arg.Steer)
		end
		return
	end
	if os.clock() - session.LastAction < 0.15 then
		return
	end
	session.LastAction = os.clock()
	local profile = session.Profile

	if action == "Feed" then
		if profile.Food <= 0 then
			self:Notify(player, "Forage food around the herd first.")
		elseif not S.TitanService:IsNearOwnTitan(player) then
			self:Notify(player, "Get closer to your titan to feed it.")
		else
			local food = profile.Food
			profile.Food = 0
			self:AddGrowth(player, food * Config.Growth.FoodValue * self:GrowthMult(player))
			self:Notify(player, string.format("Fed %d food to your titan.", food))
			S.QuestService:Progress(player, "Feed", food)
		end
	elseif action == "BuyFood" then
		local def = Config.Stages[profile.Stage]
		local cost = self:FoodCrateCost(player)
		if not def.GrowthToNext then
			self:Notify(player, "Your titan is fully grown. Molt to grow again!")
		elseif profile.Coins < cost then
			self:Notify(player, "Not enough coins.")
		else
			self:AddCoins(player, -cost)
			self:AddGrowth(player, def.GrowthToNext * Config.FoodCrate.GrowthFraction * self:GrowthMult(player))
		end
	elseif action == "Molt" then
		self:_molt(player)
	elseif action == "Whistle" then
		if S.ShopService:Owns(player, "TitanWhistle") then
			S.StealService:DropCarried(player, "whistled away")
			S.TitanService:PlaceOnDeck(player)
		else
			self:Notify(player, "Titan Whistle is a game pass.")
		end
	elseif action == "BuyWeapon" and type(arg) == "string" then
		self:_buyWeapon(player, arg)
	elseif action == "BuySpell" and type(arg) == "string" then
		self:_buySpell(player, arg)
	elseif action == "BuyUpgrade" and type(arg) == "string" then
		self:_buyUpgrade(player, arg)
	elseif action == "ClaimQuest" then
		S.QuestService:Claim(player, arg)
	elseif action == "Travel" and type(arg) == "string" then
		self:_travel(player, arg)
	elseif action == "BuySkin" and type(arg) == "string" then
		self:_buySkinWithCoins(player, arg)
	elseif action == "EquipSkin" and type(arg) == "string" then
		if self:OwnsSkin(player, arg) then
			self:EquipSkin(player, arg)
		end
	elseif action == "Roar" then
		S.CycleService:Roar(player)
	elseif action == "StudioGrant" and type(arg) == "table" then
		if not S.ShopService:StudioGrant(player, tostring(arg.Kind), tostring(arg.Key)) then
			self:Notify(player, "That item has no Id yet. Set it in Config.luau.")
		end
	end
	self:MarkDirty(player)
end

function PlayerService:_molt(player: Player)
	local profile = self:GetProfile(player)
	if Config.Stages[profile.Stage].GrowthToNext then
		self:Notify(player, "Your titan must be Ancient to molt.")
		return
	end
	profile.Molts += 1
	profile.Stage = 1
	profile.Growth = 0
	profile.TitanMutation = self:RollMutation(player)
	-- Eggs beyond the hatchling's slots are hatched early rather than lost.
	while #profile.Eggs > Config.Stages[1].EggSlots do
		local egg = table.remove(profile.Eggs)
		local rider = self:MakeRider(player, egg.Rarity)
		rider.Id = self:_nextId(profile)
		table.insert(profile.Riders, rider)
	end
	S.TitanService:Rebuild(player)
	self:MarkDirty(player)
	local mutation = profile.TitanMutation ~= "Normal" and (" It came out " .. profile.TitanMutation .. "!") or ""
	self:Notify(
		player,
		string.format(
			"Your titan molted! Molt %d: +%d%% coins forever.%s",
			profile.Molts,
			math.floor(profile.Molts * Config.Molt.EarningsBonus * 100),
			mutation
		)
	)
end

-- Ticks ---------------------------------------------------------------------

function PlayerService:_tick(player: Player, session, dt: number)
	local profile = session.Profile
	local income = self:Income(player)
	if income > 0 then
		profile.Coins += income * dt
	end
	if Config.Stages[profile.Stage].GrowthToNext then
		self:AddGrowth(player, Config.Growth.IdlePerSecond * dt * self:GrowthMult(player))
	end
	self:_hatchReady(player)
	if S.ShopService:Owns(player, "AutoFeeder") and profile.Food > 0 and Config.Stages[profile.Stage].GrowthToNext then
		local food = profile.Food
		profile.Food = 0
		self:AddGrowth(player, food * Config.Growth.FoodValue * self:GrowthMult(player))
	end
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		leaderstats.Coins.Value = math.floor(profile.Coins)
		leaderstats.Stage.Value = Config.Stages[profile.Stage].Name
		leaderstats.Kills.Value = profile.Kills
	end
	session.Dirty = true
	self:_flush(player, session)
end

function PlayerService:_isFriend(a: Player, b: Player): boolean
	local key = math.min(a.UserId, b.UserId) .. ":" .. math.max(a.UserId, b.UserId)
	if friendCache[key] == nil then
		friendCache[key] = false
		task.spawn(function()
			local ok, result = pcall(a.IsFriendsWith, a, b.UserId)
			friendCache[key] = ok and result or false
		end)
	end
	return friendCache[key]
end

function PlayerService:_updateHerdBonds()
	for player, session in sessions do
		local bonded = false
		for _, neighbor in S.TitanService:Neighbors(player) do
			if self:_isFriend(player, neighbor) then
				bonded = true
				break
			end
		end
		session.HerdBond = bonded
	end
end

function PlayerService:_costTable(player: Player, list, costFn)
	local costs = {}
	for _, def in list do
		costs[def.Key] = costFn(self, player, def.Key) or -1
	end
	return costs
end

function PlayerService:_flush(player: Player, session)
	if not session.Dirty then
		return
	end
	session.Dirty = false
	local profile = session.Profile
	local stage = Config.Stages[profile.Stage]
	local health, maxHealth = S.TitanService:GetHealth(player)
	Remotes.State:FireClient(player, {
		Coins = math.floor(profile.Coins),
		Food = profile.Food,
		FoodCap = self:FoodCapacity(player),
		Stage = profile.Stage,
		StageName = stage.Name,
		Growth = profile.Growth,
		GrowthToNext = stage.GrowthToNext,
		Molts = profile.Molts,
		Species = profile.Species,
		TitanMutation = profile.TitanMutation,
		Riders = #profile.Riders,
		RiderSlots = self:RiderSlots(player),
		Eggs = #profile.Eggs,
		EggSlots = self:EggSlots(player),
		Income = self:Income(player),
		Passes = S.ShopService:OwnedList(player),
		CanMolt = stage.GrowthToNext == nil,
		FoodCrateCost = self:FoodCrateCost(player),
		LockedFor = math.max(0, session.LockedUntil - os.clock()),
		Health = health,
		MaxHealth = maxHealth,
		CanRoar = profile.Stage >= Config.Nightfall.RoarStage,
		HerdBond = session.HerdBond,
		Resonance = self:HasResonance(player),
		GrowthSnackLeft = math.max(0, profile.GrowthSnackUntil - os.time()),
		Weathered = profile.NightsSurvivedStreak >= Config.Nightfall.WeatheredStreak,
		NightsStreak = profile.NightsSurvivedStreak,
		OwnedSkins = profile.OwnedSkins,
		EquippedSkin = profile.EquippedSkin,
		Weapons = profile.Weapons,
		Spells = profile.Spells,
		Upgrades = profile.Upgrades,
		Kills = profile.Kills,
		Level = profile.Level,
		XP = profile.XP,
		Quests = S.QuestService:Snapshot(player),
		XPToNext = self:XPToNext(profile.Level),
		Strength = S.CombatService:Strength(player),
		Driving = S.TitanService:IsDriving(player),
		SpellCosts = self:_costTable(player, Config.Spells, self.SpellCost),
		UpgradeCosts = self:_costTable(player, Config.Upgrades, self.UpgradeCost),
	})
end

return PlayerService
