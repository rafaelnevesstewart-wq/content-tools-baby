--!strict
-- Upgrade prices. Shared so the shop UI shows exactly what the server charges.

local Config = require(script.Parent.Config)

local Economy = {}

function Economy.maxPedestals(hasDoubleSlots: boolean): number
	return if hasDoubleSlots then Config.Pedestals.MaxWithPass else Config.Pedestals.Max
end

-- Price of the next pedestal when you already own `owned`.
function Economy.pedestalCost(owned: number): number
	local extra = owned - Config.Pedestals.Start
	return math.floor(Config.Pedestals.BaseCost * Config.Pedestals.CostGrowth ^ extra)
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

function Economy.trapCost(level: number): number?
	return Config.Traps.Costs[level + 1]
end

return Economy
