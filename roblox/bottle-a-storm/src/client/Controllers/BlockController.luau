-- Bed Wars blocks: while you hold a block (Cloud Wool, Wood Planks...) or
-- Storm TNT, a see-through preview shows where it will go; click to place it.
-- Blocks snap to a grid next to whatever you point at. The server checks it.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local Aim = require(script.Parent.Aim)
local Sfx = require(script.Parent.Sfx)

local player = Players.LocalPlayer

local BlockController = {}

local SIZE = Config.Match.BlockSize
local ghost: Part
local held: Tool? = nil

-- Same grid as the server (BlockService).
local function snap(point: Vector3): Vector3
	return Vector3.new(
		math.round(point.X / SIZE) * SIZE,
		math.round((point.Y - SIZE / 2) / SIZE) * SIZE + SIZE / 2,
		math.round(point.Z / SIZE) * SIZE
	)
end

-- Where the held block would go: against the surface you're pointing at.
local function target(): Vector3?
	local camera = workspace.CurrentCamera
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not camera or not character or not root then
		return nil
	end
	local point = Aim.point({}, 0)
	local origin = camera.CFrame.Position
	local direction = point - origin
	if direction.Magnitude < 0.1 then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, ghost }
	local hit = workspace:Raycast(origin, direction.Unit * (direction.Magnitude + 2), params)
	if not hit then
		return nil
	end
	local cell = snap(hit.Position + hit.Normal * (SIZE / 2))
	if (cell - root.Position).Magnitude > Config.Match.BlockReach then
		return nil
	end
	return cell
end

local function watch(tool: Instance)
	if not tool:IsA("Tool") or not (tool:GetAttribute("BlockKey") or tool:GetAttribute("PlaceGadget")) then
		return
	end
	held = tool
	local connection = tool.Activated:Connect(function()
		local cell = target()
		if not cell then
			return
		end
		Sfx.play("pop", 0.7)
		local gadget = tool:GetAttribute("PlaceGadget")
		if gadget then
			Remotes.event("UseGadget"):FireServer(gadget, cell) -- Storm TNT
		else
			Remotes.event("PlaceBlock"):FireServer(tool:GetAttribute("BlockKey"), cell)
		end
	end)
	tool.AncestryChanged:Connect(function()
		if tool.Parent ~= player.Character then
			connection:Disconnect()
			if held == tool then
				held = nil
			end
		end
	end)
end

function BlockController.start()
	ghost = Instance.new("Part")
	ghost.Name = "BlockPreview"
	ghost.Anchored = true
	ghost.CanCollide = false
	ghost.CanQuery = false
	ghost.CanTouch = false
	ghost.CastShadow = false
	ghost.Size = Vector3.one * SIZE
	ghost.Material = Enum.Material.ForceField
	ghost.Color = Color3.fromRGB(150, 220, 255)
	ghost.Transparency = 1
	ghost.Parent = workspace

	local function onCharacter(character: Model)
		character.ChildAdded:Connect(watch)
		for _, child in character:GetChildren() do
			watch(child)
		end
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end

	RunService.RenderStepped:Connect(function()
		local cell = if held then target() else nil
		if cell then
			ghost.CFrame = CFrame.new(cell)
			ghost.Transparency = 0.4
		else
			ghost.Transparency = 1
		end
	end)
end

return BlockController
