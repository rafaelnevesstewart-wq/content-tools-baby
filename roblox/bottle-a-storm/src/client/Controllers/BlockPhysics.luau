-- Special blocks on your screen (your own client moves your character):
--   🟢 Bounce Slime: land on it and you're thrown high into the air
--   🪜 Ladder: walk into it (or hold jump next to it) to climb up

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local BlockPhysics = {}

local BOUNCE_SPEED = 95
local CLIMB_SPEED = 14

local lastBounce = 0

local function blockAt(origin: Vector3, direction: Vector3, attribute: string): BasePart?
	local folder = workspace:FindFirstChild("Blocks")
	if not folder then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { folder }
	local hit = workspace:Raycast(origin, direction, params)
	local part = hit and hit.Instance
	-- A ladder's rungs belong to their block.
	while part and part.Parent ~= folder do
		part = part.Parent :: any
	end
	if part and part:IsA("BasePart") and part:GetAttribute(attribute) then
		return part
	end
	return nil
end

function BlockPhysics.start()
	RunService.Heartbeat:Connect(function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid or humanoid.Health <= 0 then
			return
		end
		local velocity = root.AssemblyLinearVelocity

		-- Slime under your feet: boing!
		if os.clock() - lastBounce > 0.35 then
			local below = blockAt(root.Position, Vector3.new(0, -(humanoid.HipHeight + 2.2), 0), "Bounce")
			if below then
				lastBounce = os.clock()
				root.AssemblyLinearVelocity = Vector3.new(velocity.X, BOUNCE_SPEED, velocity.Z)
				return
			end
		end

		-- A ladder in front of you: climb while you walk into it or hold jump.
		local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
		if look.Magnitude < 0.01 then
			return
		end
		look = look.Unit
		local ladder = blockAt(root.Position, look * 2.6, "Climb")
			or blockAt(root.Position - Vector3.new(0, 2, 0), look * 2.6, "Climb")
		if ladder then
			local pushing = humanoid.MoveDirection:Dot(look) > 0.3 or humanoid.Jump
			if pushing then
				root.AssemblyLinearVelocity = Vector3.new(velocity.X, CLIMB_SPEED, velocity.Z)
			elseif velocity.Y < -2 then
				-- Hold on instead of sliding off.
				root.AssemblyLinearVelocity = Vector3.new(velocity.X, -2, velocity.Z)
			end
		end
	end)
end

return BlockPhysics
