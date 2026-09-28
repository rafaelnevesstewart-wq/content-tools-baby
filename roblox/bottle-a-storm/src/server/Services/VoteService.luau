-- Lobby votes for the next match (the 🗳️ Vote window): the map and how
-- tough the bots are. (The Solos / Duos / Squads vote lives in
-- MatchService.) Each player's vote is an attribute ("MapVote", "BotVote");
-- the counts are shared as workspace attributes ("MapVotes", "BotVotes").
-- MapService and BotService read the winner when a match starts.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local MapData = require(Shared.MapData)
local Remotes = require(Shared.Remotes)

local VoteService = {}

type Category = { attribute: string, published: string, valid: (string) -> boolean }

local CATEGORIES: { [string]: Category } = {
	map = {
		attribute = "MapVote",
		published = "MapVotes",
		valid = function(key)
			return MapData.get(key) ~= nil
		end,
	},
	bots = {
		attribute = "BotVote",
		published = "BotVotes",
		valid = function(key)
			return Config.Bots.Difficulties[key] ~= nil
		end,
	},
}

local function counts(category: Category): { [string]: number }
	local tally: { [string]: number } = {}
	for _, player in Players:GetPlayers() do
		local vote = player:GetAttribute(category.attribute)
		if type(vote) == "string" and category.valid(vote) then
			tally[vote] = (tally[vote] or 0) + 1
		end
	end
	return tally
end

local function publish()
	for _, category in CATEGORIES do
		workspace:SetAttribute(category.published, HttpService:JSONEncode(counts(category)))
	end
end

-- The option with the most votes (ties: a random one of them), or nil when
-- nobody voted. Clears the votes, ready for the next match.
function VoteService.winner(name: string): string?
	local category = CATEGORIES[name]
	if not category then
		return nil
	end
	local tally = counts(category)
	local best: { string } = {}
	local bestCount = 0
	for key, count in tally do
		if count > bestCount then
			best, bestCount = { key }, count
		elseif count == bestCount then
			table.insert(best, key)
		end
	end
	for _, player in Players:GetPlayers() do
		player:SetAttribute(category.attribute, nil)
	end
	publish()
	return if #best > 0 then best[math.random(1, #best)] else nil
end

function VoteService.start()
	Remotes.event("Vote").OnServerEvent:Connect(function(player, name, key)
		local category = type(name) == "string" and CATEGORIES[name]
		if category and type(key) == "string" and category.valid(key) then
			player:SetAttribute(category.attribute, key)
			publish()
		end
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(publish)
	end)
	publish()
end

return VoteService
