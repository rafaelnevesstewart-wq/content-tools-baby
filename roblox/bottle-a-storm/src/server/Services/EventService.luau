-- 🎪 The Weekly Event (EventData): a special rule in every match this week.
-- Shared as the "WeeklyEvent" attribute. Low Gravity is applied by each
-- player's screen (EventClient), One Hit in CombatService, Speed Rush in
-- GadgetService, Double Sparks in IncomeService, and Giant Mode here.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local CustomData = require(Shared.CustomData)
local EventData = require(Shared.EventData)

local Modules = script.Parent.Parent.Modules
local Notify = require(Modules.Notify)

local MatchService = require(script.Parent.MatchService)

local EventService = {}

-- This week's event, unless a private server's owner picked another rule
-- (🎟️ CustomData) or none.
local function active(): EventData.WeeklyEvent?
	local custom = CustomData.get("event")
	if custom == "None" then
		return nil
	end
	for _, event in EventData.List do
		if event.key == custom then
			return event
		end
	end
	return EventData.current(os.time())
end

local function publish()
	local event = active()
	local key = if event then event.key else nil
	if workspace:GetAttribute("WeeklyEvent") ~= key then
		workspace:SetAttribute("WeeklyEvent", key)
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
	workspace:GetAttributeChangedSignal("CustomRules"):Connect(publish)
	MatchService.MatchStarted:Connect(function()
		local event = active()
		if event then
			Notify.all("🎪 Special rule: " .. event.emoji .. " " .. event.name .. "! " .. event.description, "rare")
		end
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
