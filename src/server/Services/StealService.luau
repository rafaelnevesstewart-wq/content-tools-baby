-- Stealing eggs and Riders from other titans during the Migration, plus the
-- "stealing without tears" rules: Shell Lock, egg-only protection for small
-- titans, Snatch Back, and calling homesick Riders home.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)

local StealService = {}
local S

local carrying = {} -- [thief] = { Owner, Kind, Id, Visual, StartedAt, Label }

local function itemLabel(kind: string, item): string
	if kind == "Egg" then
		return item.Rarity .. " Egg"
	end
	local prefix = item.Mutation ~= "Normal" and (item.Mutation .. " ") or ""
	return prefix .. item.Name
end

local function makeVisual(thief: Player, owner: Player, kind: string, item)
	local hrp = thief.Character and thief.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return nil
	end
	local part = Instance.new("Part")
	part.Name = "StolenItem"
	part.Shape = Enum.PartType.Ball
	part.Size = kind == "Egg" and Vector3.new(2, 2, 2) or Vector3.one * 2.4
	part.Color = kind == "Egg" and Util.rarity(item.Rarity).Color or Util.riderDef(item.Name).Color
	part.Material = Enum.Material.Neon
	part.CanCollide = false
	part.Massless = true
	part.CFrame = hrp.CFrame * CFrame.new(0, 4.5, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hrp
	weld.Part1 = part
	weld.Parent = part
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Snatch Back"
	prompt.ObjectText = itemLabel(kind, item)
	prompt.HoldDuration = 0.3
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 14
	prompt:SetAttribute("OnlyUserId", owner.UserId)
	prompt.Parent = part
	prompt.Triggered:Connect(function(who)
		if who == owner then
			StealService:ReturnItem(thief, who.DisplayName .. " snatched it back")
		end
	end)
	part.Parent = thief.Character
	return part
end

function StealService:IsCarrying(player: Player): boolean
	return carrying[player] ~= nil
end

function StealService:TrySteal(thief: Player, owner: Player, kind: string, id: number)
	local PS = S.PlayerService
	if thief == owner or not PS:GetSession(thief) or not PS:GetSession(owner) then
		return
	end
	if not S.CycleService:IsDay() then
		PS:Notify(thief, "Stealing is off during Nightfall. The herd must work together!")
		return
	end
	if PS:IsLocked(owner) then
		PS:Notify(thief, owner.DisplayName .. "'s titan is under Shell Lock.")
		return
	end
	if carrying[thief] then
		PS:Notify(thief, "You're already carrying something. Get it home!")
		return
	end
	local item = PS:FindItem(owner, kind, id)
	if not item or item.InTransit then
		return
	end
	if kind == "Rider" then
		if PS:GetProfile(owner).Stage < Config.Steal.MinStageForRiderSteal then
			PS:Notify(thief, "Young titans can only lose eggs, not Riders.")
			return
		end
		if PS:FreeRiderSlots(thief) <= 0 then
			PS:Notify(thief, "You have no free Rider slot for that.")
			return
		end
	elseif PS:FreeEggSlots(thief) <= 0 then
		PS:Notify(thief, "You have no free egg slot for that.")
		return
	end

	local visual = makeVisual(thief, owner, kind, item)
	if not visual then
		return
	end
	item.InTransit = true
	-- Stealing ends your own Shell Lock, so nobody can raid from safety.
	PS:GetSession(thief).LockedUntil = 0
	carrying[thief] = { Owner = owner, Kind = kind, Id = id, Visual = visual, StartedAt = os.clock(), Label = itemLabel(kind, item) }
	S.TitanService:RefreshDeck(owner)
	PS:MarkDirty(owner)
	PS:Notify(thief, string.format("You grabbed %s! Get back to your own titan (or Leap) within %ds.", itemLabel(kind, item), Config.Steal.CarryTimeout))
	PS:Notify(owner, string.format("🚨 %s is stealing your %s! Catch them and Snatch it back!", thief.DisplayName, itemLabel(kind, item)))
end

function StealService:ReturnItem(thief: Player, reason: string?)
	local carry = carrying[thief]
	if not carry then
		return
	end
	carrying[thief] = nil
	if carry.Visual then
		carry.Visual:Destroy()
	end
	local owner = carry.Owner
	local item = S.PlayerService:FindItem(owner, carry.Kind, carry.Id)
	if item then
		item.InTransit = nil
		S.TitanService:RefreshDeck(owner)
		S.PlayerService:MarkDirty(owner)
		S.PlayerService:Notify(owner, string.format("Your %s is back home%s.", carry.Label, reason and (" (" .. reason .. ")") or ""))
	end
	if thief.Parent then
		S.PlayerService:Notify(thief, string.format("You dropped %s%s.", carry.Label, reason and (": " .. reason) or ""))
	end
end

StealService.DropCarried = StealService.ReturnItem

function StealService:_deliver(thief: Player)
	local carry = carrying[thief]
	local PS = S.PlayerService
	local owner = carry.Owner
	local hasRoom = carry.Kind == "Egg" and PS:FreeEggSlots(thief) > 0 or carry.Kind == "Rider" and PS:FreeRiderSlots(thief) > 0
	if not hasRoom then
		self:ReturnItem(thief, "no free slot")
		return
	end
	carrying[thief] = nil
	carry.Visual:Destroy()
	local item = PS:RemoveItem(owner, carry.Kind, carry.Id)
	if not item then
		return
	end
	item.InTransit = nil
	if carry.Kind == "Egg" then
		PS:AddEgg(thief, item.Rarity, item)
	else
		local ownerProfile = PS:GetProfile(owner)
		local bonus = ownerProfile and ownerProfile.RescuedCount >= 5 and 1 or 0 -- Homecoming perk
		item.HomeUserId = owner.UserId
		item.HomesickUntilNight = S.CycleService:NightNumber() + Config.Steal.HomesickNights + bonus
		PS:AddRider(thief, item)
	end
	PS:Notify(thief, string.format("Stolen! %s is now on your titan.", carry.Label))
	if carry.Kind == "Rider" then
		PS:Notify(
			owner,
			string.format("%s took your %s. It's homesick: board their titan before Nightfall to Call it Home for free!", thief.DisplayName, carry.Label)
		)
	else
		PS:Notify(owner, string.format("%s took your %s.", thief.DisplayName, carry.Label))
	end
end

function StealService:CallHome(who: Player, holder: Player, riderId: number)
	local PS = S.PlayerService
	local rider = PS:FindItem(holder, "Rider", riderId)
	if not rider or rider.InTransit or rider.HomeUserId ~= who.UserId then
		return
	end
	if S.CycleService:NightNumber() >= (rider.HomesickUntilNight or 0) then
		PS:Notify(who, "Too late, it has settled in with its new herd.")
		return
	end
	if PS:FreeRiderSlots(who) <= 0 then
		PS:Notify(who, "You need a free Rider slot to call it home.")
		return
	end
	PS:RemoveItem(holder, "Rider", riderId)
	rider.HomeUserId = nil
	rider.HomesickUntilNight = nil
	PS:AddRider(who, rider)
	local profile = PS:GetProfile(who)
	profile.RescuedCount += 1
	PS:Notify(who, string.format("%s came home! (%d rescued)", rider.Name, profile.RescuedCount))
	PS:Notify(holder, string.format("%s's %s went home.", who.DisplayName, rider.Name))
end

function StealService:Leap(player: Player)
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	local _, current = S.TitanService:TitanUnder(hrp.Position)
	local own = S.TitanService:GetTitan(player)
	local best, bestDistance = nil, Config.Steal.LeapRange
	for _, record in S.TitanService:AllTitans() do
		if record ~= current and record.Root then
			local d = (record.Root.Position - hrp.Position).Magnitude
			if carrying[player] and record == own and d <= Config.Steal.LeapRange then
				best = record
				break
			end
			if d < bestDistance then
				best, bestDistance = record, d
			end
		end
	end
	if not best then
		S.PlayerService:Notify(player, "No titan close enough to leap to.")
		return
	end
	S.TitanService:PlaceOnDeck(player, best)
end

function StealService:OnNightfall()
	for thief in table.clone(carrying) do
		self:ReturnItem(thief, "Nightfall")
	end
end

function StealService:OnPlayerRemoving(player: Player)
	if carrying[player] then
		self:ReturnItem(player, "thief left")
	end
	for thief, carry in table.clone(carrying) do
		if carry.Owner == player then
			carrying[thief] = nil
			carry.Visual:Destroy()
			S.PlayerService:Notify(thief, "The owner left, so the item vanished home.")
		end
	end
end

function StealService:Init(services)
	S = services
end

function StealService:Start()
	local clock = 0
	RunService.Heartbeat:Connect(function(dt)
		clock += dt
		if clock < 0.2 then
			return
		end
		clock = 0
		for thief, carry in table.clone(carrying) do
			local character = thief.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if not thief.Parent or not humanoid or humanoid.Health <= 0 or not hrp then
				self:ReturnItem(thief, "thief was knocked out")
			elseif os.clock() - carry.StartedAt > Config.Steal.CarryTimeout then
				self:ReturnItem(thief, "took too long")
			elseif S.TitanService:IsOnDeck(S.TitanService:GetTitan(thief), hrp.Position) then
				self:_deliver(thief)
			end
		end
	end)
end

return StealService
