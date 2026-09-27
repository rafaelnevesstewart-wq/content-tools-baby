-- Things bought with Sparks: jars, pedestals, boots, Lightning Rod traps,
-- thief styles and island themes.
-- Also handles selling storms from your own pedestals.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local StormData = require(Shared.StormData)
local ThiefStyles = require(Shared.ThiefStyles)

local Modules = script.Parent.Parent.Modules
local Notify = require(Modules.Notify)

local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local MovementService = require(script.Parent.MovementService)
local MoodService = require(script.Parent.MoodService)
local PlotService = require(script.Parent.PlotService)
local ThemeService = require(script.Parent.ThemeService)

local ShopService = {}

local lastRequest: { [Player]: number } = {}

local function spend(data: any, cost: number): (boolean, string?)
	if data.sparks < cost then
		return false, "You need ⚡" .. Format.number(cost - data.sparks) .. " more Sparks."
	end
	data.sparks -= cost
	return true, nil
end

local handlers: { [string]: (Player, any) -> (boolean, string) } = {
	Jar = function(_player, data)
		local cost = Economy.jarCost(data.jarTier)
		if not cost then
			return false, "You already have the best jar!"
		end
		local needed = Config.Jars[data.jarTier + 1].climate or 0
		if (data.climate or 0) < needed then
			return false,
				"🔒 The " .. Config.Jars[data.jarTier + 1].name .. " unlocks at Climate Shift " .. needed .. "."
		end
		local ok, err = spend(data, cost)
		if not ok then
			return false, err :: string
		end
		data.jarTier += 1
		local jar = Config.Jars[data.jarTier]
		local rarity = StormData.Rarities[jar.maxRarity]
		return true, "🫙 New " .. jar.name .. "! You can now bottle " .. rarity.name .. " storms."
	end,

	Pedestal = function(player, data)
		local max = player:GetAttribute("MaxPedestals") or Config.Pedestals.Max
		if data.pedestals >= max then
			return false, "Your island is at max pedestals."
		end
		local ok, err = spend(data, Economy.pedestalCost(data.pedestals))
		if not ok then
			return false, err :: string
		end
		data.pedestals += 1
		PlotService.refreshAll(player)
		return true, "🏛️ New pedestal built! (" .. data.pedestals .. "/" .. max .. ")"
	end,

	Boots = function(player, data)
		local cost = Economy.bootsCost(data.bootsLevel)
		if not cost then
			return false, "Your Boots of Wind are maxed out!"
		end
		local ok, err = spend(data, cost)
		if not ok then
			return false, err :: string
		end
		data.bootsLevel += 1
		MovementService.refresh(player)
		return true, "👟 Boots of Wind level " .. data.bootsLevel .. "!"
	end,

	Snacks = function(player, data)
		if #data.storms == 0 then
			return false, "You don't have any storms to feed yet!"
		end
		local baseIncome = 0
		for _, record in data.storms do
			baseIncome += StormData.incomeOf(record)
		end
		local ok, err = spend(data, Economy.snackCost(baseIncome))
		if not ok then
			return false, err :: string
		end
		MoodService.feedAll(player)
		return true, "🍪 Snack time! All your storms are 😄 Happy (+25% Sparks)."
	end,

	Trap = function(_player, data)
		local cost = Economy.trapCost(data.trapLevel)
		if not cost then
			return false, "Your Lightning Rod is maxed out!"
		end
		local ok, err = spend(data, cost)
		if not ok then
			return false, err :: string
		end
		data.trapLevel += 1
		return true,
			"⚡ Lightning Rod level "
				.. data.trapLevel
				.. "! Thieves get stunned for "
				.. data.trapLevel * Config.Traps.StunPerLevel
				.. "s."
	end,
}

-- "Style:QuickHands": unlock it (Sparks) or equip/unequip it if you own it.
local function onStyle(player: Player, data: any, key: string): (boolean, string)
	local style = ThiefStyles.get(key)
	if not style then
		return false, "Unknown style."
	end
	if player:GetAttribute("Carrying") then
		return false, "You can't change style while carrying a stolen storm!"
	end
	if data.thiefStyle == key then
		data.thiefStyle = nil
		return true, "You unequipped " .. style.name .. "."
	end
	if not data.thiefStyles[key] then
		local ok, err = spend(data, style.cost)
		if not ok then
			return false, err :: string
		end
		data.thiefStyles[key] = true
	end
	data.thiefStyle = key
	return true, style.emoji .. " " .. style.name .. " equipped! " .. style.description
end

local function onBuy(player: Player, itemKey: any): (boolean, string)
	if os.clock() - (lastRequest[player] or 0) < 0.25 then
		return false, "Slow down!"
	end
	lastRequest[player] = os.clock()
	local data = DataService.get(player)
	if type(itemKey) == "string" and data and string.sub(itemKey, 1, 6) == "Style:" then
		local ok, message = onStyle(player, data, string.sub(itemKey, 7))
		IncomeService.sync(player)
		MovementService.refresh(player)
		return ok, message
	end
	if type(itemKey) == "string" and data and string.sub(itemKey, 1, 6) == "Theme:" then
		local ok, message = ThemeService.buyOrEquip(player, string.sub(itemKey, 7))
		IncomeService.sync(player)
		return ok, message
	end
	local handler = type(itemKey) == "string" and handlers[itemKey]
	if not handler or not data then
		return false, "Can't buy that right now."
	end
	local ok, message = handler(player, data)
	IncomeService.sync(player)
	return ok, message
end

local function onSell(player: Player, slot: number)
	local data = DataService.get(player)
	if not data or PlotService.isSlotStolen(player, slot) then
		return
	end
	for index, record in data.storms do
		if record.slot == slot then
			local price = math.floor(StormData.incomeOf(record) * Config.Income.SellSeconds)
			table.remove(data.storms, index)
			data.sparks += price
			PlotService.refreshSlot(player, slot)
			IncomeService.sync(player)
			Notify.player(
				player,
				"Sold " .. StormData.displayName(record) .. " for ⚡" .. Format.number(price) .. ".",
				"info"
			)
			return
		end
	end
end

function ShopService.start()
	Remotes.func("BuyItem").OnServerInvoke = onBuy
	PlotService.SellRequested:Connect(onSell)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return ShopService
