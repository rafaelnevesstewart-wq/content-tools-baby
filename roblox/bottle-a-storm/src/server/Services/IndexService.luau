-- The Kit Collection. The first time you get a kind of kit (from a Kit Crate,
-- the Kit Shop, the battle pass or a reward) it's added to your collection
-- and pays a little bonus. Completing every kit of a rarity (a "row") gives
-- +5% match Sparks forever. Battle pass and holiday kits are shown but don't
-- count toward rows, since they can't be earned after their event.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local StormData = require(Shared.StormData)

local Modules = script.Parent.Parent.Modules
local Notify = require(Modules.Notify)

local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)

local IndexService = {}

-- Kit ids that make up each rarity row (no exclusives).
local rows: { [number]: { string } } = {}
for _, def in StormData.Storms do
	if not StormData.isExclusive(def) then
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
	local bonus = Config.Index.DiscoverSparks[def.rarity] or 100
	data.sparks += bonus
	Notify.player(
		player,
		"📖 New in your Kit Collection: " .. def.name .. "! +⚡" .. Format.number(bonus),
		"success"
	)

	local before = data.indexRows or 0
	local done = completedRows(data)
	data.indexRows = #done
	if #done > before then
		local rarity = StormData.Rarities[def.rarity]
		Notify.player(
			player,
			"🏆 You completed the "
				.. rarity.name
				.. " row of your Kit Collection! +"
				.. math.floor(Config.Index.RowBonus * 100)
				.. "% match Sparks forever.",
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
