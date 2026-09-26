-- Creates the remotes on the server and waits for them on the client.
--   Action (client -> server): action name plus an optional argument
--   Notify (server -> client): a short toast message
--   State  (server -> client): the player's profile snapshot for the HUD
--   Ui     (server -> client): open a HUD panel, e.g. a shop tab at the town base

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = { "Action", "Notify", "State", "Ui" }

local Remotes = {}

if RunService:IsServer() then
	local folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in NAMES do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		Remotes[name] = remote
	end
	folder.Parent = ReplicatedStorage
else
	local folder = ReplicatedStorage:WaitForChild("Remotes")
	for _, name in NAMES do
		Remotes[name] = folder:WaitForChild(name)
	end
end

return Remotes
