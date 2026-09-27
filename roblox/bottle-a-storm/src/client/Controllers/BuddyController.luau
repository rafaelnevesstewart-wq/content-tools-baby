-- Moves every storm buddy (server BuddyService) next to its owner on this
-- screen, with a smooth follow and a little bob, so it never lags behind.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local BuddyController = {}

local OFFSET = CFrame.new(3.2, 2.4, 1.5) -- right, up and a bit behind you

function BuddyController.start()
	local folder = workspace:WaitForChild("Buddies")
	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		for _, model in folder:GetChildren() do
			local root = model:IsA("Model") and model.PrimaryPart
			local owner = Players:GetPlayerByUserId(model:GetAttribute("OwnerUserId") or 0)
			local character = owner and owner.Character
			local ownerRoot = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and ownerRoot then
				local bob = math.sin(t * 2 + (owner :: Player).UserId % 7) * 0.4
				local goal = ownerRoot.CFrame * OFFSET * CFrame.new(0, bob, 0)
				if (root.Position - goal.Position).Magnitude > 60 then
					root.CFrame = goal -- teleported: jump straight there
				else
					root.CFrame = root.CFrame:Lerp(goal, 1 - math.exp(-dt * 6))
				end
			end
		end
	end)
end

return BuddyController
