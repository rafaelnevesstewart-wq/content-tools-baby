--!strict
-- 🏗️ Base Island (BaseService): where the plots are and what you can build
-- with. Every plot is a 10 x 10 x 10 grid of 3-stud cells; cells are saved as
-- "i,j,k,key" (i, j across the plot, k up).

local Config = require(script.Parent.Config)

export type BaseBlock = {
	key: string,
	name: string,
	emoji: string,
	material: Enum.Material,
	color: Color3,
	transparency: number?,
}

local rgb = Color3.fromRGB
local M = Enum.Material

local BaseData = {}

BaseData.Center = Config.Lobby.Center + Vector3.new(-Config.Lobby.SideDistance, 0, 0)
BaseData.Plots = 8
BaseData.Cells = 10 -- across and up
BaseData.CellSize = 3
BaseData.MaxBlocks = 400

BaseData.Blocks = {
	{ key = "Planks", name = "Planks", emoji = "🪵", material = M.WoodPlanks, color = rgb(160, 120, 80) },
	{ key = "Stone", name = "Stone", emoji = "🧱", material = M.Brick, color = rgb(150, 150, 155) },
	{ key = "Cobble", name = "Cobblestone", emoji = "🪨", material = M.Cobblestone, color = rgb(130, 128, 124) },
	{
		key = "Glass",
		name = "Glass",
		emoji = "🪟",
		material = M.Glass,
		color = rgb(190, 230, 255),
		transparency = 0.55,
	},
	{ key = "Grass", name = "Grass", emoji = "🌿", material = M.Grass, color = rgb(88, 140, 62) },
	{ key = "Gold", name = "Gold", emoji = "🟨", material = M.Foil, color = rgb(236, 190, 60) },
	{ key = "Red", name = "Red Wool", emoji = "🟥", material = M.Fabric, color = rgb(210, 60, 60) },
	{ key = "Blue", name = "Blue Wool", emoji = "🟦", material = M.Fabric, color = rgb(60, 110, 220) },
	{ key = "White", name = "White Wool", emoji = "⬜", material = M.Fabric, color = rgb(240, 240, 240) },
	{ key = "Black", name = "Black Wool", emoji = "⬛", material = M.Fabric, color = rgb(40, 40, 44) },
	{ key = "Neon", name = "Glow Block", emoji = "💡", material = M.Neon, color = rgb(150, 230, 255) },
} :: { BaseBlock }

function BaseData.block(key: string?): BaseBlock?
	for _, block in BaseData.Blocks do
		if block.key == key then
			return block
		end
	end
	return nil
end

-- The middle of a plot's floor (its top surface).
function BaseData.plotCenter(index: number): Vector3
	local column = (index - 1) % 4
	local row = (index - 1) // 4
	return BaseData.Center + Vector3.new((column - 1.5) * 36, 0.2, (row - 0.5) * 40)
end

-- The world position of a cell's middle.
function BaseData.cellPosition(index: number, i: number, j: number, k: number): Vector3
	local size = BaseData.CellSize
	local half = BaseData.Cells / 2
	return BaseData.plotCenter(index) + Vector3.new((i - half + 0.5) * size, (k + 0.5) * size, (j - half + 0.5) * size)
end

-- The cell a world point falls in (may be outside the plot).
function BaseData.cellAt(index: number, point: Vector3): (number, number, number)
	local size = BaseData.CellSize
	local half = BaseData.Cells / 2
	local offset = point - BaseData.plotCenter(index)
	return math.floor(offset.X / size + half), math.floor(offset.Z / size + half), math.floor(offset.Y / size)
end

function BaseData.inside(i: number, j: number, k: number): boolean
	local n = BaseData.Cells
	return i >= 0 and i < n and j >= 0 and j < n and k >= 0 and k < n
end

return BaseData
