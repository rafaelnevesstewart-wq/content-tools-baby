-- 😀 Buying emotes for the emote wheel (EmoteData). What you own is shared
-- with your screen as the "Emotes" attribute (a JSON list of keys).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local EmoteData = require(Shared.EmoteData)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)

local EmoteService = {}

local function publish(player: Player)
	local data = DataService.get(player)
	if data then
		local owned = {}
		for key in data.emotes do
			table.insert(owned, key)
		end
		player:SetAttribute("Emotes", HttpService:JSONEncode(owned))
	end
end

local function buy(player: Player, key: any): (boolean, string)
	local data = DataService.get(player)
	local emote = type(key) == "string" and EmoteData.get(key)
	if not data or not emote then
		return false, "Unknown emote."
	end
	if emote.cost <= 0 or data.emotes[emote.key] then
		return false, "You already have it!"
	end
	if data.sparks < emote.cost then
		return false, "You need ⚡" .. Format.number(emote.cost - data.sparks) .. " more Sparks."
	end
	data.sparks -= emote.cost
	data.emotes[emote.key] = true
	IncomeService.sync(player)
	publish(player)
	return true, emote.emoji .. " " .. emote.name .. " unlocked! Press G to use it."
end

function EmoteService.start()
	Remotes.func("BuyEmote").OnServerInvoke = buy
	DataService.ProfileLoaded:Connect(publish)
	for _, player in Players:GetPlayers() do
		publish(player)
	end
end

return EmoteService
