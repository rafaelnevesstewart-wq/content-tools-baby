-- The Storm Mixer: put two of your storms in, pay a Sparks fee, get one back.
--   * A secret recipe makes a hybrid (some are Mythic, the only way to get them).
--   * Any other pair makes a random storm of the higher rarity, with a small
--     chance of going one rarity up.
-- The result keeps the better mutation of the two, and lands on the first
-- storm's pedestal.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local StormData = require(Shared.StormData)
local Signal = require(Shared.Signal)

local Modules = script.Parent.Parent.Modules
local Notify = require(Modules.Notify)
local Recipes = require(Modules.Recipes)

local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local IndexService = require(script.Parent.IndexService)
local PlotService = require(script.Parent.PlotService)
local SeasonService = require(script.Parent.SeasonService)

local MixService = {}

-- (player) after every mix.
MixService.Mixed = Signal.new()

local busy: { [Player]: boolean } = {}
local rng = Random.new()

local function findRecord(data: any, uid: any): (StormData.StormRecord?, number?)
	for index, record in data.storms do
		if record.uid == uid then
			return record, index
		end
	end
	return nil, nil
end

function MixService.fee(a: StormData.StormRecord, b: StormData.StormRecord): number
	local fee = (StormData.incomeOf(a) + StormData.incomeOf(b)) * Config.Mixing.FeeSeconds
	return math.max(Config.Mixing.MinFee, math.floor(fee))
end

local function betterMutation(a: string?, b: string?): string?
	local ma = StormData.getMutation(a)
	local mb = StormData.getMutation(b)
	if ma and mb then
		return if ma.multiplier >= mb.multiplier then ma.id else mb.id
	end
	return if ma then ma.id elseif mb then mb.id else nil
end

local function randomResult(a: StormData.StormDef, b: StormData.StormDef): StormData.StormDef
	local rarity = math.min(math.max(a.rarity, b.rarity), 5)
	if rarity < 5 and rng:NextNumber() < Config.Mixing.UpgradeChance then
		rarity += 1
	end
	local options = StormData.wildOfRarity(rarity)
	return options[rng:NextInteger(1, #options)]
end

-- What the mixer window needs: your storms and the recipes you've found.
local function getMixer(player: Player)
	local data = DataService.get(player)
	if not data then
		return nil
	end
	local storms = {}
	for _, record in data.storms do
		table.insert(storms, {
			uid = record.uid,
			id = record.id,
			mut = record.mut,
			slot = record.slot,
			stolen = PlotService.isSlotStolen(player, record.slot),
		})
	end
	local found = {}
	for result in data.recipes do
		local recipe = Recipes.forResult(result)
		if recipe then
			table.insert(found, { a = recipe.a, b = recipe.b, result = recipe.result })
		end
	end
	return { storms = storms, found = found, total = #Recipes.List }
end

-- Swirls the cauldron in the result's color while it mixes.
local function playMixAnimation(player: Player, color: Color3)
	local mixer = PlotService.getMixer(player)
	local swirl = mixer and mixer:FindFirstChild("Swirl") :: Part?
	if not swirl then
		return
	end
	local original = swirl.Color
	local bubbles = swirl:FindFirstChild("Bubbles") :: ParticleEmitter?
	if bubbles then
		bubbles.Rate = 60
	end
	local grow =
		TweenService:Create(swirl, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			Size = Vector3.new(8, 8, 8),
			Color = color,
		})
	grow:Play()
	task.delay(Config.Mixing.MixSeconds, function()
		grow:Cancel()
		swirl.Size = Vector3.new(6, 6, 6)
		swirl.Color = original
		if bubbles then
			bubbles.Rate = 6
			bubbles:Emit(40)
		end
	end)
end

local function mix(player: Player, uidA: any, uidB: any): (boolean, string)
	local data = DataService.get(player)
	if not data or busy[player] then
		return false, "The mixer is busy!"
	end
	if uidA == uidB then
		return false, "Pick two different storms."
	end
	local recordA = findRecord(data, uidA)
	local recordB = findRecord(data, uidB)
	if not recordA or not recordB then
		return false, "You don't own those storms anymore."
	end
	if PlotService.isSlotStolen(player, recordA.slot) or PlotService.isSlotStolen(player, recordB.slot) then
		return false, "One of those storms is being stolen!"
	end
	local defA = StormData.get(recordA.id)
	local defB = StormData.get(recordB.id)
	if not defA or not defB then
		return false, "Something went wrong with those storms."
	end
	local mixer = PlotService.getMixer(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if
		not mixer
		or not mixer.PrimaryPart
		or not root
		or (root.Position - mixer.PrimaryPart.Position).Magnitude > Config.Mixing.Range
	then
		return false, "Stand next to your Storm Mixer to mix."
	end
	local fee = MixService.fee(recordA, recordB)
	if data.sparks < fee then
		return false,
			"Mixing costs ⚡" .. Format.number(fee) .. ". You need ⚡" .. Format.number(fee - data.sparks) .. " more."
	end

	local recipe = Recipes.find(defA.id, defB.id)
	local resultDef = if recipe then StormData.get(recipe.result) else nil
	if not resultDef then
		resultDef = randomResult(defA, defB)
	end
	local result = resultDef :: StormData.StormDef

	-- Change the profile all at once so leaving mid-animation can't lose storms.
	local slotA, slotB = recordA.slot, recordB.slot
	local _, indexA = findRecord(data, uidA)
	table.remove(data.storms, indexA :: number)
	local _, indexB = findRecord(data, uidB)
	table.remove(data.storms, indexB :: number)
	data.sparks -= fee
	local record: StormData.StormRecord = {
		uid = HttpService:GenerateGUID(false),
		id = result.id,
		mut = betterMutation(recordA.mut, recordB.mut),
		slot = slotA,
		at = os.time(),
		mood = Config.Mood.Start,
	}
	table.insert(data.storms, record)
	data.stats.mixed += 1
	SeasonService.addXp(player, Config.Season.MixXp)
	MixService.Mixed:Fire(player)
	IndexService.discover(player, result.id)
	local newRecipe = recipe ~= nil and not data.recipes[result.id]
	if recipe then
		data.recipes[result.id] = true
	end

	busy[player] = true
	-- Slot A keeps showing the old storm until the reveal.
	PlotService.refreshSlot(player, slotB)
	IncomeService.sync(player)
	playMixAnimation(player, StormData.rarityOf(result).color)

	local name = StormData.displayName(record)
	task.delay(Config.Mixing.MixSeconds, function()
		busy[player] = nil
		if not player.Parent then
			return
		end
		PlotService.refreshSlot(player, slotA)
		local rarity = StormData.rarityOf(result)
		if newRecipe then
			Notify.player(
				player,
				"🧪 NEW RECIPE! " .. defA.name .. " + " .. defB.name .. " = " .. name .. "!",
				"rare"
			)
			Notify.allExcept(
				player,
				"🧪 " .. player.DisplayName .. " discovered " .. result.name .. " (" .. rarity.name .. ")!",
				"rare"
			)
		elseif recipe then
			Notify.player(player, "🧪 You mixed " .. name .. "!", "success")
		else
			Notify.player(player, "🧪 Unknown mix... you got " .. name .. " (" .. rarity.name .. ").", "info")
		end
	end)
	return true, "🧪 Mixing..."
end

function MixService.start()
	Remotes.func("GetMixer").OnServerInvoke = getMixer
	Remotes.func("MixStorms").OnServerInvoke = mix
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)
end

return MixService
