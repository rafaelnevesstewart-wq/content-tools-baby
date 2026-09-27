-- The Storm Index (collection book). The first time you get a kind of storm,
-- by catching, stealing, trading, mixing or as a reward, it's added to your
-- Index and pays you a little bonus. Completing every storm of a rarity (a
-- "row") gives +5% Sparks forever. Season-pass exclusives are shown but don't
-- count toward rows, since they can't be earned after their season.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local StormData = require(Shared.StormData)

local Modules = script.Parent.Parent.Modules
local Notify = require(Modules.Notify)

local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)

local IndexService = {}

-- Storm ids that make up each rarity row (no season exclusives).
local rows: { [number]: { string } } = {}
for _, def in StormData.Storms do
	if not def.season then
		rows[def.rarity] = rows[def.rarity] or {}
		table.insert(rows[def.rarity], def.id)
	end
end

function IndexService.rows(): { [number]: { string } }
	return rows
end

local function completedRows(data: any): { number }
	local done = {}
	for rarity, ids in rows do
		local complete = true
		for _, id in ids do
			if not data.discovered[id] then
				complete = false
				break
			end
		end
		if complete then
			table.insert(done, rarity)
		end
	end
	return done
end

-- Records a storm kind as found. Returns true if it's new for this player.
function IndexService.discover(player: Player, id: string): boolean
	local data = DataService.get(player)
	local def = StormData.get(id)
	if not data or not def or data.discovered[id] then
		return false
	end
	data.discovered[id] = true
	local bonus = math.max(Config.Index.DiscoverMin, math.floor(def.income * Config.Index.DiscoverSeconds))
	data.sparks += bonus
	Notify.player(player, "📖 New in your Storm Index: " .. def.name .. "! +⚡" .. Format.number(bonus), "success")

	local before = data.indexRows or 0
	local done = completedRows(data)
	data.indexRows = #done
	if #done > before then
		local rarity = StormData.Rarities[def.rarity]
		Notify.player(
			player,
			"🏆 You completed the "
				.. rarity.name
				.. " row of your Storm Index! +"
				.. math.floor(Config.Index.RowBonus * 100)
				.. "% Sparks forever.",
			"rare"
		)
	end
	IncomeService.sync(player)
	return true
end

-- Old profiles: work out rows from what they've already discovered.
function IndexService.start()
	DataService.ProfileLoaded:Connect(function(player, data)
		data.indexRows = #completedRows(data)
		IncomeService.sync(player)
	end)
end

return IndexService
