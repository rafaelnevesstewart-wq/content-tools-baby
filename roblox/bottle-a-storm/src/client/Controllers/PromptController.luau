-- Shows each player only the prompts that make sense for them: "Sell" on your
-- own pedestals, "Steal" on other people's, and only your own Lock button.
-- These are local changes; the server still checks every trigger.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local PromptController = {}

local function plotModel(index: number): Instance?
	local world = workspace:FindFirstChild("World")
	local plots = world and world:FindFirstChild("Plots")
	return plots and plots:FindFirstChild("Plot" .. index)
end

local function setEnabled(parent: Instance, name: string, enabled: boolean)
	local prompt = parent:FindFirstChild(name)
	if prompt and prompt:IsA("ProximityPrompt") and prompt.Enabled ~= enabled then
		prompt.Enabled = enabled
	end
end

local function refresh()
	local now = workspace:GetServerTimeNow()
	local carrying = player:GetAttribute("Carrying") ~= nil

	for _, base in CollectionService:GetTagged("Pedestal") do
		local owner = base:GetAttribute("OwnerUserId") or 0
		local mine = owner == player.UserId
		local hasStorm = base:GetAttribute("HasStorm") == true
		local stolen = base:GetAttribute("BeingStolen") == true
		local plot = plotModel(base:GetAttribute("PlotIndex") or 0)
		local locked = plot ~= nil and (plot:GetAttribute("LockedUntil") or 0) > now

		setEnabled(base, "SellPrompt", mine and hasStorm and not stolen)
		setEnabled(base, "RidePrompt", mine and hasStorm and not stolen)
		setEnabled(
			base,
			"StealPrompt",
			not mine and owner ~= 0 and hasStorm and not stolen and not locked and not carrying
		)
	end

	local world = workspace:FindFirstChild("World")
	local plots = world and world:FindFirstChild("Plots")
	if plots then
		for _, plot in plots:GetChildren() do
			local props = plot:FindFirstChild("Props")
			local mine = plot:GetAttribute("OwnerUserId") == player.UserId
			local button = props and props:FindFirstChild("LockButton")
			if button then
				setEnabled(button, "LockPrompt", mine)
			end
			local mixer = props and props:FindFirstChild("StormMixer")
			local pot = mixer and mixer:FindFirstChild("Pot")
			if pot then
				setEnabled(pot, "MixerPrompt", mine)
			end
		end
	end
end

function PromptController.start()
	task.spawn(function()
		while true do
			refresh()
			task.wait(0.3)
		end
	end)
end

return PromptController
