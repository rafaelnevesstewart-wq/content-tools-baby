-- Gives each Climate Shift island its own feel on your screen: a colour tint
-- while you stand on it, and low gravity on the Space island. These changes
-- are only on your own client.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local ClimateData = require(Shared.ClimateData)

local player = Players.LocalPlayer

local BiomeController = {}

local NORMAL_GRAVITY = workspace.Gravity

local function currentBiome(position: Vector3): ClimateData.Climate?
	local world = workspace:FindFirstChild("World")
	local biomes = world and world:FindFirstChild("Biomes")
	if not biomes then
		return nil
	end
	for _, island in biomes:GetChildren() do
		local center = island:GetAttribute("Center")
		local radius = island:GetAttribute("Radius")
		if typeof(center) == "Vector3" and type(radius) == "number" then
			local offset = position - center
			local flat = Vector3.new(offset.X, 0, offset.Z).Magnitude
			if flat <= radius + 10 and offset.Y > -40 and offset.Y < 80 then
				return ClimateData.get(island:GetAttribute("Climate"))
			end
		end
	end
	return nil
end

function BiomeController.start()
	local tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "BiomeTint"
	tint.Parent = Lighting

	local active: string? = nil
	task.spawn(function()
		while true do
			task.wait(0.4)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local biome = if root then currentBiome(root.Position) else nil
			local key = if biome then biome.key else nil
			if key ~= active then
				active = key
				local info = TweenInfo.new(1.5)
				TweenService:Create(tint, info, {
					TintColor = if biome and biome.tint then biome.tint else Color3.new(1, 1, 1),
					Saturation = if biome then 0.15 else 0,
					Contrast = if biome and biome.gravity then 0.15 else 0,
				}):Play()
				workspace.Gravity = if biome and biome.gravity then biome.gravity else NORMAL_GRAVITY
			end
		end
	end)
end

return BiomeController
