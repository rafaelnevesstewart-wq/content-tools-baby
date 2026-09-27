-- Weather mutations (like Grow a Garden): while a weather event is on, storms
-- on pedestals can pick up extra mutations such as 💧 Wet or ⚡ Shocked.
-- They stack (up to Config.WeatherMutations.Max) and multiply the storm's
-- income, sell price and trade value. See StormData.WeatherMutations.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local StormData = require(Shared.StormData)

local Modules = script.Parent.Parent.Modules
local Juice = require(Modules.Juice)
local Notify = require(Modules.Notify)

local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local PlotService = require(script.Parent.PlotService)
local WeatherService = require(script.Parent.WeatherService)

local WeatherMutationService = {}

local rng = Random.new()

local function roll(player: Player, options: { StormData.WeatherMutation })
	local data = DataService.get(player)
	if not data then
		return
	end
	local changed = false
	for _, record in data.storms do
		if
			PlotService.isSlotStolen(player, record.slot)
			or rng:NextNumber() >= Config.WeatherMutations.ChancePerMinute
		then
			continue
		end
		local have = record.wm or {}
		if #have >= Config.WeatherMutations.Max then
			continue
		end
		local fresh = {}
		for _, mutation in options do
			if not table.find(have, mutation.id) then
				table.insert(fresh, mutation)
			end
		end
		if #fresh == 0 then
			continue
		end
		local mutation = fresh[rng:NextInteger(1, #fresh)]
		table.insert(have, mutation.id)
		record.wm = have
		changed = true
		PlotService.refreshSlot(player, record.slot)
		local position = PlotService.slotPosition(player, record.slot)
		if position then
			Juice.float(player, mutation.emoji .. " " .. mutation.name .. "!", position + Vector3.new(0, 7, 0))
		end
		Notify.player(
			player,
			mutation.emoji
				.. " Your "
				.. StormData.displayName(record)
				.. " got "
				.. mutation.name
				.. "! (x"
				.. mutation.multiplier
				.. " Sparks, now "
				.. StormData.weatherEmojis(record)
				.. ")",
			"rare"
		)
	end
	if changed then
		IncomeService.sync(player)
	end
end

function WeatherMutationService.start()
	task.spawn(function()
		while true do
			task.wait(60)
			local event = WeatherService.current()
			if event then
				local options = {}
				for _, mutation in StormData.WeatherMutations do
					if table.find(mutation.events, event.key) then
						table.insert(options, mutation)
					end
				end
				if #options > 0 then
					for _, player in Players:GetPlayers() do
						roll(player, options)
					end
				end
			end
		end
	end)
end

return WeatherMutationService
