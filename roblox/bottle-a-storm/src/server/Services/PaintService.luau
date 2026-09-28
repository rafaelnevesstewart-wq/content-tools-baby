-- 🖌️ The Paint Shop: pick a color for your sword blades and your armor
-- (PaintData). Free to change any time. Shared with your screen as the
-- "Paint" attribute (JSON: { blade = index, armor = index }).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local PaintData = require(Shared.PaintData)
local Remotes = require(Shared.Remotes)

local CombatService = require(script.Parent.CombatService)
local DataService = require(script.Parent.DataService)

local PaintService = {}

local lastChange: { [Player]: number } = {}

local function publish(player: Player)
	local data = DataService.get(player)
	if data then
		player:SetAttribute("Paint", HttpService:JSONEncode(data.paint))
	end
end

function PaintService.start()
	Remotes.event("SetPaint").OnServerEvent:Connect(function(player, slot, index)
		local data = DataService.get(player)
		if not data or os.clock() - (lastChange[player] or 0) < 0.3 then
			return
		end
		if slot ~= "blade" and slot ~= "armor" then
			return
		end
		lastChange[player] = os.clock()
		data.paint[slot] = if PaintData.color(index) then index else nil
		publish(player)
		CombatService.refreshLook(player)
	end)
	DataService.ProfileLoaded:Connect(publish)
	for _, player in Players:GetPlayers() do
		publish(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastChange[player] = nil
	end)
end

return PaintService
