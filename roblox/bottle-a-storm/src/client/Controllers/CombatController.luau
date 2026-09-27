-- The Cloud Blaster (pops grumpy clouds) and Water Balloons (splash other
-- players). This only aims; the server decides what gets hit.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local Aim = require(script.Parent.Aim)
local Sfx = require(script.Parent.Sfx)

local player = Players.LocalPlayer

local CombatController = {}

local function otherPlayers(): { BasePart }
	local list = {}
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if other ~= player and root and root:IsA("BasePart") then
			table.insert(list, root)
		end
	end
	return list
end

function CombatController.start()
	Aim.hookTool("Cloud Blaster", function()
		Sfx.play("zap", 1.4 + math.random() * 0.2)
		Remotes.event("BlastCloud"):FireServer(Aim.point(Aim.rootsIn("Grumps"), 5))
	end)
	Aim.hookTool("Water Balloons", function()
		Sfx.play("throw", 1.1 + math.random() * 0.2)
		Remotes.event("ThrowBalloon"):FireServer(Aim.point(otherPlayers(), 3))
	end)
end

return CombatController
