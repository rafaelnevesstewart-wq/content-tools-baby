-- Toast messages on the player's screen. Kinds: "info", "success", "warn", "rare".
-- Messages for everyone are marked as such, so players with 🔕 Fewer pop-ups
-- only see them in their 📜 Messages log (Toasts).

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local notifyEvent = Remotes.event("Notify")

local Notify = {}

function Notify.player(player: Player, text: string, kind: string?)
	notifyEvent:FireClient(player, text, kind or "info")
end

function Notify.all(text: string, kind: string?)
	notifyEvent:FireAllClients(text, kind or "info", true)
end

function Notify.allExcept(except: Player, text: string, kind: string?)
	for _, player in Players:GetPlayers() do
		if player ~= except then
			notifyEvent:FireClient(player, text, kind or "info", true)
		end
	end
end

return Notify
