-- Falling off the sky islands: anyone who drops below Config.World.VoidKillY
-- is knocked out (in a match, MatchService counts it as a death; the last
-- player who hit you gets the knockout).

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local MovementService = {}

function MovementService.start()
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if root and humanoid and humanoid.Health > 0 and root.Position.Y < Config.World.VoidKillY then
					humanoid.Health = 0
				end
			end
		end
	end)
end

return MovementService
