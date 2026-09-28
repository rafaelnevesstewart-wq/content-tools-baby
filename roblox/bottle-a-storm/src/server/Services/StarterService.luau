-- 🎁 The starter pack: brand-new players (no matches yet) get a welcome
-- window with a gift (Sparks, a Rare kit and a Duckling pet) and a short
-- "what to do first" list (StarterPack on the client). Players who already
-- played never see it. Saved as data.starter ("claimed" or "skipped").

local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Remotes)

local Modules = script.Parent.Parent.Modules
local Notify = require(Modules.Notify)
local Usage = require(Modules.Usage)

local CosmeticService = require(script.Parent.CosmeticService)
local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local RewardService = require(script.Parent.RewardService)

local StarterService = {}

local SPARKS = 1000
local PET = "PetDuck"

local function claim(player: Player)
	local data = DataService.get(player)
	if not data or data.starter == "claimed" or not player:GetAttribute("StarterPack") then
		return
	end
	data.starter = "claimed"
	player:SetAttribute("StarterPack", nil)
	data.sparks += SPARKS
	IncomeService.sync(player)
	RewardService.grant(player, { kind = "kit", rarity = 3 }, nil, true)
	if not data.cosmetics.owned[PET] then
		CosmeticService.grant(player, PET)
	end
	Usage.track("starterPack", player)
	Notify.player(
		player,
		"🎁 Welcome gift: ⚡" .. SPARKS .. ", a Rare kit and a 🦆 Duckling pet! Have fun!",
		"rare"
	)
end

function StarterService.start()
	Remotes.event("ClaimStarter").OnServerEvent:Connect(claim)
	DataService.ProfileLoaded:Connect(function(player, data)
		if data.starter == nil then
			if (data.stats.matches or 0) == 0 then
				player:SetAttribute("StarterPack", true)
			else
				data.starter = "skipped"
			end
		end
	end)
end

return StarterService
