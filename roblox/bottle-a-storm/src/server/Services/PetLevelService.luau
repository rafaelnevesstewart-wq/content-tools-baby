-- 🐾 Pet levels (see PetLevels): the pet you have out gets XP when you play,
-- win, knock someone out, break a bed or win a duel. On a level up it's
-- rebuilt bigger (and sparkly or golden at high levels) and your match
-- Sparks bonus goes up.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local CosmeticsData = require(Shared.CosmeticsData)
local PetLevels = require(Shared.PetLevels)

local Modules = script.Parent.Parent.Modules
local Notify = require(Modules.Notify)

local CosmeticService = require(script.Parent.CosmeticService)
local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local LobbyService = require(script.Parent.LobbyService)
local MatchService = require(script.Parent.MatchService)

local PetLevelService = {}

local function addXp(player: Player, amount: number)
	local data = DataService.get(player)
	local item = data and CosmeticsData.get(data.cosmetics.pet)
	if not data or not item or not item.pet then
		return
	end
	data.petLevels = data.petLevels or {}
	local entry = data.petLevels[item.id]
	if not entry then
		entry = { level = 1, xp = 0 }
		data.petLevels[item.id] = entry
	end
	if entry.level >= PetLevels.MaxLevel then
		return
	end
	entry.xp += amount
	local levelled = false
	while entry.level < PetLevels.MaxLevel and entry.xp >= PetLevels.xpFor(entry.level) do
		entry.xp -= PetLevels.xpFor(entry.level)
		entry.level += 1
		levelled = true
	end
	if entry.level >= PetLevels.MaxLevel then
		entry.xp = 0
	end
	player:SetAttribute("PetLevel", entry.level)
	player:SetAttribute("PetXp", entry.xp)
	if levelled then
		Notify.player(
			player,
			"🐾 Your " .. item.emoji .. " " .. item.name .. " is now level " .. entry.level .. "! (+1% match Sparks)",
			"rare"
		)
		IncomeService.sync(player)
		-- Rebuild it bigger, once you're not mid-fight with it.
		task.delay(1, CosmeticService.rebuildPet, player)
	end
end

function PetLevelService.start()
	local xp = PetLevels.Xp
	MatchService.Played:Connect(function(player)
		addXp(player, xp.play)
	end)
	MatchService.Won:Connect(function(player)
		addXp(player, xp.win)
	end)
	MatchService.Killed:Connect(function(killer)
		addXp(killer, xp.kill)
	end)
	MatchService.BedBroken:Connect(function(breaker)
		addXp(breaker, xp.bed)
	end)
	LobbyService.DuelWon:Connect(function(winner)
		addXp(winner, xp.duel)
	end)
end

return PetLevelService
