-- 🎟️ Custom private matches: in a private server (or in Studio, for
-- testing), the server's owner opens 🎟️ Rules and picks the mode, map,
-- special rule, generator speed, bots and boss for every match there
-- (CustomData). Changes apply from the next match. Public servers always
-- play the normal game.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local CustomData = require(Shared.CustomData)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent.Parent.Modules
local Notify = require(Modules.Notify)

local CustomMatchService = {}

local rules: { [string]: string } = {}
local lastChange: { [Player]: number } = {}

local function isPrivate(): boolean
	return game.PrivateServerId ~= "" or RunService:IsStudio()
end

local function canEdit(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	return game.PrivateServerId ~= "" and game.PrivateServerOwnerId ~= 0 and player.UserId == game.PrivateServerOwnerId
end

local function publish()
	workspace:SetAttribute("CustomRules", HttpService:JSONEncode(rules))
end

local function onAction(player: Player, action: any, key: any, value: any): (any, string?)
	if action == "get" then
		return { rules = CustomData.rules(), canEdit = canEdit(player), private = isPrivate() }
	end
	if action ~= "set" then
		return false, "Can't do that."
	end
	if not canEdit(player) then
		return false, "Only the private server's owner can change the rules."
	end
	if os.clock() - (lastChange[player] or 0) < 0.2 then
		return false, "Slow down!"
	end
	lastChange[player] = os.clock()
	local option = if type(key) == "string" then CustomData.option(key) else nil
	if not option or type(value) ~= "string" or not option.labels[value] then
		return false, "That's not a choice."
	end
	rules[option.key] = value
	publish()
	Notify.all("🎟️ " .. option.name .. ": " .. option.labels[value] .. " (from the next match)", "info")
	return true, nil
end

function CustomMatchService.start()
	Remotes.func("CustomRules").OnServerInvoke = onAction
	workspace:SetAttribute("PrivateServer", isPrivate())
	local function mark(player: Player)
		player:SetAttribute("CanCustomize", if canEdit(player) then true else nil)
	end
	Players.PlayerAdded:Connect(mark)
	for _, player in Players:GetPlayers() do
		mark(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastChange[player] = nil
	end)
end

return CustomMatchService
