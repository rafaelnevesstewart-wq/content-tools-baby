-- Falling off the sky islands: anyone who drops below Config.World.VoidKillY
-- in a match is knocked out (MatchService counts it as a death; the last
-- player who hit you gets the knockout). In the lobby you're just put back at
-- the spawn.

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
				if root and humanoid and humanoid.Health > 0 then
					local inMatch = player:GetAttribute("InMatch") == true
					local spawn = workspace:FindFirstChild("LobbySpawn", true) :: BasePart?
					if not inMatch and spawn and root.Position.Y < Config.Lobby.Center.Y - 40 then
						-- In the lobby a fall just puts you back at the spawn.
						root.AssemblyLinearVelocity = Vector3.zero
						character:PivotTo(CFrame.new(spawn.Position + Vector3.new(0, 4, 0)))
					elseif root.Position.Y < Config.World.VoidKillY then
						humanoid.Health = 0
					end
				end
			end
		end
	end)
end

return MovementService
