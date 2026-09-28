-- 🎪 The Weekly Event (EventData): a special rule in every match this week.
-- Shared as the "WeeklyEvent" attribute. Low Gravity is applied by each
-- player's screen (EventClient), One Hit in CombatService, Speed Rush in
-- GadgetService, Double Sparks in IncomeService, and Giant Mode here.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local EventData = require(Shared.EventData)

local Modules = script.Parent.Parent.Modules
local Notify = require(Modules.Notify)

local MatchService = require(script.Parent.MatchService)

local EventService = {}

local function publish()
	local event = EventData.current(os.time())
	if workspace:GetAttribute("WeeklyEvent") ~= event.key then
		workspace:SetAttribute("WeeklyEvent", event.key)
	end
end

function EventService.start()
	publish()
	task.spawn(function()
		while true do
			task.wait(60)
			publish()
		end
	end)
	MatchService.MatchStarted:Connect(function()
		local event = EventData.current(os.time())
		Notify.all("🎪 Weekly Event: " .. event.emoji .. " " .. event.name .. "! " .. event.description, "rare")
	end)
	-- Giant Mode: everyone in the match is bigger.
	MatchService.PlayerSpawned:Connect(function(player)
		if not EventData.is("Giants") then
			return
		end
		task.delay(0.4, function()
			local character = player.Character
			if character and MatchService.isPlaying(player) then
				pcall(function()
					character:ScaleTo(EventData.GiantScale)
				end)
			end
		end)
	end)
end

return EventService
