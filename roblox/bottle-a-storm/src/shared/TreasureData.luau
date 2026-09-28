--!strict
-- 🗺️ The daily treasure hunt (TreasureService): every day 5 of these spots
-- are picked (the same for everyone) and each gets a buried treasure. Follow
-- the clues in order and dig each one up. Positions are on the lobby islands.

local Config = require(script.Parent.Config)
local FishData = require(script.Parent.FishData)

export type Spot = { key: string, clue: string, position: Vector3 }

local LOBBY = Config.Lobby.Center
local GAMES = LOBBY + Vector3.new(Config.Lobby.SideDistance, 0, 0)
local BASE = LOBBY + Vector3.new(-Config.Lobby.SideDistance, 0, 0)
local STREET = LOBBY + Vector3.new(0, 0, -Config.Lobby.StreetDistance)

local TreasureData = {}

TreasureData.PerDay = 5
TreasureData.StepSparks = { 150, 200, 250, 300, 350 }
TreasureData.FinalSparks = 1000
TreasureData.FinalKitRarity = 3 -- Rare

TreasureData.Spots = {
	{
		key = "TV",
		clue = "The weather is always on here. Look behind the big screen.",
		position = LOBBY + Vector3.new(0, 0, -32),
	},
	{ key = "Chest", clue = "Next to a box that opens once a day.", position = LOBBY + Vector3.new(-25, 0, -27) },
	{
		key = "Arena",
		clue = "Where 1v1 fights happen. Check the edge of the ring.",
		position = LOBBY + Vector3.new(41, 0, 10),
	},
	{ key = "Dummies", clue = "Behind the ones who never fight back.", position = LOBBY + Vector3.new(-39, 0, 4) },
	{ key = "News", clue = "Behind the board that tells you what's new.", position = LOBBY + Vector3.new(30, 0, 41) },
	{ key = "Guide", clue = "Right behind the friendly guide by the gate.", position = LOBBY + Vector3.new(14, 0, 34) },
	{
		key = "Signpost",
		clue = "Outside the castle gate, by the signs pointing the way.",
		position = LOBBY + Vector3.new(20, 0, 60),
	},
	{
		key = "Pond",
		clue = "On the sandy shore where the fish bite.",
		position = FishData.Center + Vector3.new(0, 0, 10.5),
	},
	{ key = "Range", clue = "Where the archers stand on Games Island.", position = GAMES + Vector3.new(15, 0, -5) },
	{ key = "Parkour", clue = "Where the parkour race begins.", position = GAMES + Vector3.new(-38, 0, 24) },
	{ key = "Bases", clue = "In the middle of the island where people build.", position = BASE },
	{
		key = "Street",
		clue = "On the cobbles of the street full of shops.",
		position = STREET + Vector3.new(0, 0, -20),
	},
	{
		key = "Bridge",
		clue = "Where the bridge to the shops lands.",
		position = STREET + Vector3.new(5, 0, Config.Lobby.StreetRadius - 10),
	},
	{
		key = "Season",
		clue = "In front of the board of this month's best.",
		position = LOBBY + Vector3.new(-32, 0, 26),
	},
} :: { Spot }

-- Today's spots, in order (the same for everyone).
function TreasureData.forDay(day: number): { Spot }
	local rng = Random.new(day * 7919 + 17)
	local pool = table.clone(TreasureData.Spots)
	local picked = {}
	for _ = 1, math.min(TreasureData.PerDay, #pool) do
		table.insert(picked, table.remove(pool, rng:NextInteger(1, #pool)) :: Spot)
	end
	return picked
end

return TreasureData
