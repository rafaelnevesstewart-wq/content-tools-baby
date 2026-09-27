--!strict
-- The server creates every remote on first require; clients wait for them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	"Notify", -- server -> client: (text, kind)
	"ThrowJar", -- client -> server: (targetPosition)
	"ToggleRide", -- client -> server: ()
	"TradeAction", -- client -> server: (action, ...)
	"TradeRequest", -- server -> client: (fromUserId, fromName)
	"TradeUpdate", -- server -> client: (state or nil when the trade closes)
	"DevPurchase", -- client -> server, Studio only: (itemKey)
}

local FUNCTIONS = {
	"BuyItem", -- client -> server: (itemKey) -> (ok, message)
	"GetMixer", -- client -> server: () -> mixer info
	"MixStorms", -- client -> server: (uidA, uidB) -> (ok, message)
	"ClimateShift", -- client -> server: () -> (ok, message)
	"GetSeason", -- client -> server: () -> your season progress
	"SeasonClaim", -- client -> server: (tier, "free" | "premium") -> (ok, message)
}

local folder: Instance
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in EVENTS do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
	for _, name in FUNCTIONS do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = folder
		end
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

local Remotes = {}

function Remotes.event(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

function Remotes.func(name: string): RemoteFunction
	return folder:WaitForChild(name) :: RemoteFunction
end

return Remotes
