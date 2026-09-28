--!strict
-- The server creates every remote on first require; clients wait for them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	"Notify", -- server -> client: (text, kind)
	"DevPurchase", -- client -> server, Studio only: (itemKey)
	"Juice", -- server -> client: (kind, ...) floating numbers, sounds, shake, pop-ups
	"CrateOpened", -- server -> client: (result) a Kit Crate opened, for the opening animation
	"Swing", -- client -> server: (aimPoint) sword swing
	"ShootBow", -- client -> server: (aimPoint)
	"UseItem", -- client -> server: (itemKey, aimPoint) Storm Apple / Wind Pearl
	"PlaceBlock", -- client -> server: (blockKey, point)
}

local FUNCTIONS = {
	"GetSeason", -- client -> server: () -> your season progress
	"SeasonClaim", -- client -> server: (tier, "free" | "premium") -> (ok, message)
	"GetRewards", -- client -> server: () -> daily, quests and Kit Collection info
	"ClaimDaily", -- client -> server: () -> (ok, message)
	"ClaimQuest", -- client -> server: (index) -> (ok, message)
	"GetTitles", -- client -> server: () -> titles and progress
	"SetTitle", -- client -> server: (titleId or nil) -> (ok, message)
	"Cosmetic", -- client -> server: (action, idOrValue) -> (ok, message)
	"RedeemCode", -- client -> server: (text) -> (ok, message)
	"Spin", -- client -> server: () -> (ok, prizeIndex or message)
	"AdminCommand", -- client -> server: (command, arg) -> (ok, message), admins only
	"GetHoliday", -- client -> server: () -> event info and your currency
	"BuyHoliday", -- client -> server: (index) -> (ok, message)
	"CheckGroup", -- client -> server: () -> (ok, message)
	"GetMarket", -- client -> server: () -> market stock
	"BuyMarket", -- client -> server: (slot) -> (ok, message)
	"OpenCrate", -- client -> server: (crateKey) -> (ok, message) opens a Kit Crate
	"BuyMatchItem", -- client -> server: (itemKey) -> (ok, message)
	"BuyUpgrade", -- client -> server: (upgradeKey) -> (ok, message)
	"GetKits", -- client -> server: () -> your storms and the chosen kit
	"ChooseKit", -- client -> server: (uid) -> (ok, message)
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
