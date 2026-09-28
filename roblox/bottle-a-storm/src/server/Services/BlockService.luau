-- Bed Wars blocks: buy them in the Item Shop, place them on a grid to wall in
-- your cloud bed (or anywhere), and break other teams' blocks by hitting them
-- with your sword. Stronger blocks take more hits. All blocks disappear when
-- the match ends.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local MatchData = require(Shared.MatchData)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Signal)

local Modules = script.Parent.Parent.Modules
local Effects = require(Modules.Effects)

local MatchService = require(script.Parent.MatchService)

local BlockService = {}

-- (player) each time a player places a block (daily quests).
BlockService.Placed = Signal.new()

local SIZE = Config.Match.BlockSize
local folder: Folder
local placed: { [string]: BasePart } = {} -- grid key -> block
local counts: { [Player]: { [string]: number } } = {}

local function key(cell: Vector3): string
	return cell.X .. "," .. cell.Y .. "," .. cell.Z
end

-- The grid cell a point falls in (cells are SIZE studs, centered on multiples of SIZE).
local function snap(point: Vector3): Vector3
	return Vector3.new(
		math.round(point.X / SIZE) * SIZE,
		math.round((point.Y - SIZE / 2) / SIZE) * SIZE + SIZE / 2,
		math.round(point.Z / SIZE) * SIZE
	)
end

local function toolName(blockKey: string): string
	return MatchData.Blocks[blockKey].name
end

local function publish(player: Player)
	for blockKey in MatchData.Blocks do
		local count = counts[player] and counts[player][blockKey] or 0
		player:SetAttribute("Blocks_" .. blockKey, if count > 0 then count else nil)
		local name = toolName(blockKey)
		local backpack = player:FindFirstChildOfClass("Backpack")
		local character = player.Character
		local tool = (backpack and backpack:FindFirstChild(name)) or (character and character:FindFirstChild(name))
		if count > 0 and not tool and backpack then
			local block = MatchData.Blocks[blockKey]
			local team = MatchService.teamOf(player)
			local newTool = Instance.new("Tool")
			newTool.Name = name
			newTool.ToolTip = "Click to place a block"
			newTool.CanBeDropped = false
			newTool:SetAttribute("BlockKey", blockKey)
			local handle = Instance.new("Part")
			handle.Name = "Handle"
			handle.Size = Vector3.one * 1
			handle.CanCollide = false
			handle.Massless = true
			handle.Material = block.material
			handle.Color = block.color
				or (if team then team.info.color:Lerp(Color3.new(1, 1, 1), 0.4) else Color3.new(1, 1, 1))
			handle.Parent = newTool
			newTool.Parent = backpack
		elseif count <= 0 and tool then
			tool:Destroy()
		end
	end
end

function BlockService.add(player: Player, blockKey: string, amount: number)
	counts[player] = counts[player] or {}
	counts[player][blockKey] = (counts[player][blockKey] or 0) + amount
	publish(player)
end

local function blocked(cell: Vector3): boolean
	if placed[key(cell)] then
		return true
	end
	if cell.Y > Config.Match.MaxBlockHeight or cell.Y < -30 then
		return true
	end
	local box = Vector3.one * (SIZE - 0.2)
	for _, part in workspace:GetPartBoundsInBox(CFrame.new(cell), box) do
		-- No blocks inside players, beds, generators or shops.
		if CollectionService:HasTag(part, "NoBuild") then
			return true
		end
		local model = part:FindFirstAncestorOfClass("Model")
		if model and Players:GetPlayerFromCharacter(model) then
			return true
		end
	end
	return false
end

local function onPlace(player: Player, blockKey: any, point: any)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not MatchService.isPlaying(player) or type(blockKey) ~= "string" or typeof(point) ~= "Vector3" or not root then
		return
	end
	local block = MatchData.Blocks[blockKey]
	local have = counts[player] and counts[player][blockKey] or 0
	if not block or have <= 0 then
		return
	end
	local cell = snap(point)
	if (cell - root.Position).Magnitude > Config.Match.BlockReach or blocked(cell) then
		return
	end
	local team = MatchService.teamOf(player)
	local part = Instance.new("Part")
	part.Name = "Block"
	part.Anchored = true
	part.Size = Vector3.one * SIZE
	part.CFrame = CFrame.new(cell)
	part.Material = block.material
	part.Color = block.color or (if team then team.info.color:Lerp(Color3.new(1, 1, 1), 0.4) else Color3.new(1, 1, 1))
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part:SetAttribute("BlockKey", blockKey)
	part:SetAttribute("Hits", block.hits)
	part.Parent = folder
	placed[key(cell)] = part
	counts[player][blockKey] = have - 1
	publish(player)
	BlockService.Placed:Fire(player)
end

-- A sword swing at `aim`: damages the placed block nearest to it, if any.
function BlockService.hit(player: Player, aim: Vector3)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (aim - root.Position).Magnitude > Config.Match.SwordRange + SIZE then
		return
	end
	local best: BasePart? = nil
	local bestDistance = SIZE
	for _, part in folder:GetChildren() do
		if part:IsA("BasePart") then
			local distance = (part.Position - aim).Magnitude
			if distance < bestDistance then
				best, bestDistance = part, distance
			end
		end
	end
	if not best then
		return
	end
	local block = best :: BasePart
	local hits = (block:GetAttribute("Hits") or 1) - 1
	if hits <= 0 then
		placed[key(block.Position)] = nil
		Effects.confetti(block.Position, 12)
		block:Destroy()
	else
		block:SetAttribute("Hits", hits)
		block.Transparency = math.min(0.5, block.Transparency + 0.08)
	end
end

function BlockService.init()
	folder = Instance.new("Folder")
	folder.Name = "Blocks"
	folder.Parent = workspace
end

function BlockService.start()
	Remotes.event("PlaceBlock").OnServerEvent:Connect(onPlace)
	MatchService.PlayerSpawned:Connect(function(player)
		counts[player] = {} -- blocks are lost when you die
		publish(player)
	end)
	MatchService.MatchEnded:Connect(function()
		folder:ClearAllChildren()
		placed = {}
		for player in counts do
			counts[player] = {}
			if player.Parent then
				publish(player)
			end
		end
		counts = {}
	end)
	Players.PlayerRemoving:Connect(function(player)
		counts[player] = nil
	end)
end

return BlockService
