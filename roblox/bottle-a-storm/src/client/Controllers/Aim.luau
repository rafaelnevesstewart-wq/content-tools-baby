-- Where the player is aiming (mouse or last touch), with a little aim assist
-- toward targets near the aim line. Used by the sword, the bow, Wind Pearls
-- and block placing.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local Aim = {}

local lastTouch: Vector3? = nil
local lastWasTouch = false
local centerUntil = 0

-- The phone ⚔️ Use button aims at the middle of the screen (its crosshair)
-- instead of where the button was tapped.
function Aim.aimAtCenter()
	centerUntil = os.clock() + 0.3
end

local function aimRay(): Ray
	local camera = workspace.CurrentCamera
	if os.clock() < centerUntil then
		local size = camera.ViewportSize
		return camera:ViewportPointToRay(size.X / 2, size.Y * 0.45)
	end
	if lastWasTouch and lastTouch then
		return camera:ScreenPointToRay(lastTouch.X, lastTouch.Y)
	end
	local mouse = UserInputService:GetMouseLocation()
	return camera:ViewportPointToRay(mouse.X, mouse.Y)
end

-- The target closest to the aim line (within `assist` studs plus its size),
-- or else whatever the aim ray hits.
function Aim.point(targets: { BasePart }, assist: number): Vector3
	local ray = aimRay()
	local direction = ray.Direction.Unit
	local best: Vector3? = nil
	local bestDistance = math.huge
	for _, part in targets do
		local offset = part.Position - ray.Origin
		local along = offset:Dot(direction)
		if along > 0 and along < 250 then
			local sideways = (offset - direction * along).Magnitude
			local allowed = assist + part.Size.X * 2
			if sideways < allowed and sideways < bestDistance then
				best = part.Position
				bestDistance = sideways
			end
		end
	end
	if best then
		return best
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance }
	local hit = workspace:Raycast(ray.Origin, direction * 300, params)
	return if hit then hit.Position else ray.Origin + direction * 60
end

-- The root parts of every model in a workspace folder (wild storms, grumps).
function Aim.rootsIn(folderName: string): { BasePart }
	local list = {}
	local folder = workspace:FindFirstChild(folderName)
	if folder then
		for _, model in folder:GetChildren() do
			local root = model:IsA("Model") and model.PrimaryPart
			if root then
				table.insert(list, root)
			end
		end
	end
	return list
end

-- Calls `onUse` whenever a tool called `toolName` is used.
function Aim.hookTool(toolName: string, onUse: () -> ())
	local hooked: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
	local function hook(tool: Instance)
		if tool:IsA("Tool") and tool.Name == toolName and not hooked[tool] then
			hooked[tool] = true
			tool.Activated:Connect(onUse)
		end
	end
	local function watch(container: Instance)
		for _, child in container:GetChildren() do
			hook(child)
		end
		container.ChildAdded:Connect(hook)
	end
	player.CharacterAdded:Connect(watch)
	if player.Character then
		watch(player.Character)
	end
	player.ChildAdded:Connect(function(child)
		if child:IsA("Backpack") then
			watch(child)
		end
	end)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		watch(backpack)
	end
end

function Aim.start()
	UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			lastTouch = input.Position
			lastWasTouch = true
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			lastWasTouch = false
		end
	end)
end

return Aim
