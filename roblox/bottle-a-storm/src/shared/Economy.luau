--!strict
-- Upgrade prices. Shared so the shop UI shows exactly what the server charges.

local Config = require(script.Parent.Config)

local Economy = {}

-- Pedestals that fit on one floor.
function Economy.perFloor(hasDoubleSlots: boolean): number
	return if hasDoubleSlots then Config.Floors.PerFloorWithPass else Config.Floors.PerFloor
end

function Economy.maxPedestals(hasDoubleSlots: boolean, floors: number?): number
	return Economy.perFloor(hasDoubleSlots) * math.max(1, floors or 1)
end

-- Price of the next floor, or nil at the top.
function Economy.floorCost(floors: number): number?
	return Config.Floors.Costs[floors + 1]
end

-- Price of the next pedestal when you already own `owned`.
function Economy.pedestalCost(owned: number): number
	local extra = owned - Config.Pedestals.Start
	-- Prices grow fast at first, then more gently for the upper floors.
	local fast = math.min(extra, 17)
	local slow = math.max(0, extra - 17)
	return math.floor(Config.Pedestals.BaseCost * Config.Pedestals.CostGrowth ^ fast * 1.3 ^ slow)
end

-- Price of the next jar, or nil when you already have the best one.
function Economy.jarCost(tier: number): number?
	local nextJar = Config.Jars[tier + 1]
	return if nextJar then nextJar.cost else nil
end

function Economy.bootsCost(level: number): number?
	if level >= Config.Boots.MaxLevel then
		return nil
	end
	return math.floor(Config.Boots.BaseCost * Config.Boots.CostGrowth ^ level)
end

-- Storm Snacks: makes every storm Happy. Priced from your storms' base income.
function Economy.snackCost(baseIncome: number): number
	return math.max(Config.Mood.SnackMinCost, math.floor(baseIncome * Config.Mood.SnackSeconds))
end

function Economy.trapCost(level: number): number?
	return Config.Traps.Costs[level + 1]
end

return Economy
