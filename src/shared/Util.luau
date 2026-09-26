local Config = require(script.Parent.Config)

local Util = {}

-- Picks an entry from list using weightFn(entry) -> number.
function Util.weightedPick(list, weightFn, rng: Random?)
	local total = 0
	for _, entry in list do
		total += weightFn(entry)
	end
	local roll = (rng and rng:NextNumber() or math.random()) * total
	for _, entry in list do
		roll -= weightFn(entry)
		if roll <= 0 then
			return entry
		end
	end
	return list[#list]
end

function Util.find(list, key, value)
	for _, entry in list do
		if entry[key] == value then
			return entry
		end
	end
	return nil
end

function Util.mutation(name: string)
	return Util.find(Config.Mutations, "Name", name) or Config.Mutations[1]
end

function Util.rarity(name: string)
	return Util.find(Config.Rarities, "Name", name) or Config.Rarities[1]
end

function Util.riderDef(name: string)
	return Util.find(Config.Riders, "Name", name) or Config.Riders[1]
end

function Util.formatNumber(n: number): string
	n = math.floor(n)
	local suffixes = { "", "K", "M", "B", "T" }
	local i = 1
	local value = n
	while math.abs(value) >= 1000 and i < #suffixes do
		value /= 1000
		i += 1
	end
	if i == 1 then
		return tostring(n)
	end
	return string.format("%.1f%s", value, suffixes[i])
end

function Util.formatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

return Util
