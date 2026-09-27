-- Toast messages on the player's screen. Kinds: "info", "success", "warn", "rare".

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local notifyEvent = Remotes.event("Notify")

local Notify = {}

function Notify.player(player: Player, text: string, kind: string?)
	notifyEvent:FireClient(player, text, kind or "info")
end

function Notify.all(text: string, kind: string?)
	notifyEvent:FireAllClients(text, kind or "info")
end

function Notify.allExcept(except: Player, text: string, kind: string?)
	for _, player in Players:GetPlayers() do
		if player ~= except then
			notifyEvent:FireClient(player, text, kind or "info")
		end
	end
end

return Notify
