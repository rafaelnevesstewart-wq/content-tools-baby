--!strict
-- 🧩 The daily puzzle rooms on Base Island's south side (PuzzleService): a
-- hedge maze, a glass bridge (one glass in each pair breaks!) and a code
-- door whose numbers are hidden on paintings around the rooms. All three
-- change every day (the same for everyone). Each pays Sparks once a day.

local BaseData = require(script.Parent.BaseData)

local PuzzleData = {}

PuzzleData.Origin = BaseData.Center -- positions below are from here
PuzzleData.Sparks = 300 -- per puzzle, once a day
PuzzleData.AllBonus = 700 -- for doing all three in a day
PuzzleData.MazeSize = 6 -- cells across
PuzzleData.MazeCell = 4 -- studs
PuzzleData.BridgeRows = 6
PuzzleData.Symbols = { "🐟", "🌟", "🔥", "🌙", "🍀", "⚡", "🍄", "💎" }

PuzzleData.Names = { Maze = "🌀 Hedge Maze", Bridge = "🪟 Glass Bridge", Code = "🔐 Code Door" }

local function rngFor(day: number, salt: number): Random
	return Random.new(day * 1009 + salt)
end

-- The maze's open passages: open[a][b] = true between neighbouring cells,
-- cells numbered (x - 1) * size + y. A random depth-first maze.
function PuzzleData.maze(day: number): { [number]: { [number]: boolean } }
	local size = PuzzleData.MazeSize
	local rng = rngFor(day, 1)
	local open: { [number]: { [number]: boolean } } = {}
	local visited: { [number]: boolean } = {}
	local function id(x: number, y: number): number
		return (x - 1) * size + y
	end
	local function link(a: number, b: number)
		open[a] = open[a] or {}
		open[b] = open[b] or {}
		open[a][b] = true
		open[b][a] = true
	end
	local stack = { { 1, 1 } }
	visited[id(1, 1)] = true
	while #stack > 0 do
		local top = stack[#stack]
		local x, y = top[1], top[2]
		local options = {}
		for _, step in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local nx, ny = x + step[1], y + step[2]
			if nx >= 1 and nx <= size and ny >= 1 and ny <= size and not visited[id(nx, ny)] then
				table.insert(options, { nx, ny })
			end
		end
		if #options == 0 then
			table.remove(stack)
		else
			local pick = options[rng:NextInteger(1, #options)]
			visited[id(pick[1], pick[2])] = true
			link(id(x, y), id(pick[1], pick[2]))
			table.insert(stack, pick)
		end
	end
	return open
end

-- For each bridge row, which glass is safe: -1 (left) or 1 (right).
function PuzzleData.bridge(day: number): { number }
	local rng = rngFor(day, 2)
	local rows = {}
	for _ = 1, PuzzleData.BridgeRows do
		table.insert(rows, if rng:NextNumber() < 0.5 then -1 else 1)
	end
	return rows
end

-- Today's code: 4 symbols (in order) and the digit each stands for.
function PuzzleData.code(day: number): { { symbol: string, digit: number } }
	local rng = rngFor(day, 3)
	local pool = table.clone(PuzzleData.Symbols)
	local list = {}
	for _ = 1, 4 do
		local symbol = table.remove(pool, rng:NextInteger(1, #pool)) :: string
		table.insert(list, { symbol = symbol, digit = rng:NextInteger(0, 9) })
	end
	return list
end

return PuzzleData
