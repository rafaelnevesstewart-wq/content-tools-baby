--!strict
local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

-- 1234 -> "1.2K", 999 -> "999"
function Format.number(value: number): string
	value = math.floor(value)
	if math.abs(value) < 1000 then
		return tostring(value)
	end
	local index = 1
	local scaled = value
	while math.abs(scaled) >= 1000 and index < #SUFFIXES do
		scaled /= 1000
		index += 1
	end
	local text = if math.abs(scaled) < 100 then string.format("%.1f", scaled) else tostring(math.floor(scaled))
	text = string.gsub(text, "%.0$", "")
	return text .. SUFFIXES[index]
end

-- 75 -> "1:15"
function Format.time(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

return Format
