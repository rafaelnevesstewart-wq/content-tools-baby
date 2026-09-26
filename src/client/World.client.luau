-- Client-side world touches: hides prompts that aren't meant for this player,
-- counts down egg timers, and animates Rainbow mutations and the Galaxy skin.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Util = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"))

local player = Players.LocalPlayer

-- Prompt filtering. The server still validates every trigger; this only
-- stops players seeing "Steal" on their own Riders or "Release" on others'.
local function shouldShow(prompt: ProximityPrompt): boolean
	local owner = prompt:GetAttribute("OwnerUserId")
	if prompt:GetAttribute("OwnerOnly") and owner ~= player.UserId then
		return false
	end
	if prompt:GetAttribute("OthersOnly") and owner == player.UserId then
		return false
	end
	local only = prompt:GetAttribute("OnlyUserId")
	if only and only ~= player.UserId then
		return false
	end
	return true
end

local function watchPrompt(prompt: Instance)
	if not prompt:IsA("ProximityPrompt") then
		return
	end
	local function apply()
		if not shouldShow(prompt) and prompt.Enabled then
			prompt.Enabled = false
		end
	end
	apply()
	prompt:GetPropertyChangedSignal("Enabled"):Connect(apply)
	prompt.AttributeChanged:Connect(apply)
end

for _, descendant in workspace:GetDescendants() do
	watchPrompt(descendant)
end
workspace.DescendantAdded:Connect(watchPrompt)

-- Egg timers and rainbow parts.
local hue = 0
local clock = 0
RunService.RenderStepped:Connect(function(dt)
	hue = (hue + dt * 0.25) % 1
	local color = Color3.fromHSV(hue, 0.8, 1)
	for _, part in CollectionService:GetTagged("RainbowPart") do
		if part:IsA("BasePart") then
			part.Color = color
		end
	end
	local galaxy = Color3.fromHSV(0.62 + math.sin(hue * math.pi * 2) * 0.12, 0.8, 0.55)
	for _, part in CollectionService:GetTagged("GalaxyPart") do
		if part:IsA("BasePart") then
			part.Color = galaxy
		end
	end

	clock += dt
	if clock < 0.25 then
		return
	end
	clock = 0
	local now = os.time()
	for _, label in CollectionService:GetTagged("EggTimer") do
		local hatchAt = label:GetAttribute("HatchAt")
		if hatchAt and label:IsA("TextLabel") then
			local left = hatchAt - now
			label.Text = left > 0 and ("Hatches in " .. Util.formatTime(left)) or "Ready! Needs a Rider slot"
		end
	end
end)
