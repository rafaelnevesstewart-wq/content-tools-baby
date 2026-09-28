-- 🎓 The first-match tutorial: in a player's very first match, their screen
-- walks them through the basics (TutorialController). Finishing the match or
-- pressing Skip marks it done (data.tutorial), so it never shows again.

local Players = game:GetService("Players")

local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Remotes)

local DataService = require(script.Parent.DataService)
local MatchService = require(script.Parent.MatchService)

local TutorialService = {}

local function done(player: Player)
	local data = DataService.get(player)
	if data then
		data.tutorial = "done"
	end
	player:SetAttribute("Tutorial", nil)
end

function TutorialService.start()
	Remotes.event("TutorialDone").OnServerEvent:Connect(done)
	MatchService.MatchStarted:Connect(function()
		task.wait(1)
		for _, player in Players:GetPlayers() do
			local data = DataService.get(player)
			if
				data
				and data.tutorial ~= "done"
				and (data.stats.matches or 0) == 0
				and player:GetAttribute("InMatch")
			then
				player:SetAttribute("Tutorial", true)
			end
		end
	end)
	MatchService.Played:Connect(done)
	MatchService.MatchEnded:Connect(function()
		for _, player in Players:GetPlayers() do
			player:SetAttribute("Tutorial", nil)
		end
	end)
end

return TutorialService
