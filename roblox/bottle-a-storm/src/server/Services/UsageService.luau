-- 📈 Counts the big moments for the play stats (Usage): joins, new players,
-- matches by mode and map, bosses beaten, duels, the mystery chest and shop
-- buys. Smaller features count themselves where they happen.

local Players = game:GetService("Players")

local Modules = script.Parent.Parent.Modules
local Usage = require(Modules.Usage)

local BossService = require(script.Parent.BossService)
local ChestService = require(script.Parent.ChestService)
local DataService = require(script.Parent.DataService)
local ItemShopService = require(script.Parent.ItemShopService)
local LobbyService = require(script.Parent.LobbyService)
local MatchService = require(script.Parent.MatchService)

local UsageService = {}

function UsageService.start()
	Players.PlayerAdded:Connect(function(player)
		Usage.track("join", player)
	end)
	DataService.ProfileLoaded:Connect(function(player, data)
		if (data.stats.matches or 0) == 0 then
			Usage.track("newPlayer", player)
		end
	end)
	MatchService.MatchStarted:Connect(function()
		Usage.track("match:" .. tostring(workspace:GetAttribute("MatchMode")))
		Usage.track("map:" .. tostring(workspace:GetAttribute("MapTheme")))
	end)
	MatchService.Played:Connect(function(player)
		Usage.track("matchFinished", player)
	end)
	BossService.Defeated:Connect(function(_helpers, _damage, kind)
		Usage.track("bossBeaten:" .. tostring(kind))
	end)
	ChestService.Opened:Connect(function(player)
		Usage.track("mysteryChest", player)
	end)
	ItemShopService.Bought:Connect(function(player)
		Usage.track("matchShopBuy", player)
	end)
	LobbyService.DuelWon:Connect(function(player)
		Usage.track("duel", player)
	end)
end

return UsageService
