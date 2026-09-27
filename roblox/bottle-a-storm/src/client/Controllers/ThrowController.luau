-- Throwing the Storm Jar. When you click or tap with the jar in hand, this
-- finds the wild storm closest to where you aimed (a little aim assist) and
-- tells the server to throw there. The server decides hit, dodge or catch.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local player = Players.LocalPlayer

local ThrowController = {}

local JAR_NAME = "Storm Jar"
local AIM_ASSIST = 4 -- studs around a storm that still count as aiming at it

local hooked: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local lastTouch: Vector3? = nil
local lastWasTouch = false

local function aimRay(): Ray
	local camera = workspace.CurrentCamera
	if lastWasTouch and lastTouch then
		return camera:ScreenPointToRay(lastTouch.X, lastTouch.Y)
	end
	local mouse = UserInputService:GetMouseLocation()
	return camera:ViewportPointToRay(mouse.X, mouse.Y)
end

local function aimPoint(): Vector3
	local ray = aimRay()
	local direction = ray.Direction.Unit

	-- Prefer the wild storm closest to the aim line.
	local best: Vector3? = nil
	local bestDistance = math.huge
	local folder = workspace:FindFirstChild("WildStorms")
	if folder then
		for _, model in folder:GetChildren() do
			local root = model:IsA("Model") and model.PrimaryPart
			if root then
				local offset = root.Position - ray.Origin
				local along = offset:Dot(direction)
				if along > 0 and along < 250 then
					local sideways = (offset - direction * along).Magnitude
					local allowed = AIM_ASSIST + root.Size.X * 2
					if sideways < allowed and sideways < bestDistance then
						best = root.Position
						bestDistance = sideways
					end
				end
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

local function hook(tool: Instance)
	if not tool:IsA("Tool") or tool.Name ~= JAR_NAME or hooked[tool] then
		return
	end
	hooked[tool] = true
	tool.Activated:Connect(function()
		Remotes.event("ThrowJar"):FireServer(aimPoint())
	end)
end

local function watch(container: Instance)
	for _, child in container:GetChildren() do
		hook(child)
	end
	container.ChildAdded:Connect(hook)
end

function ThrowController.start()
	UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			lastTouch = input.Position
			lastWasTouch = true
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			lastWasTouch = false
		end
	end)

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

return ThrowController
