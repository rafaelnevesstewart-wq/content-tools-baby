-- Saves your ⚙️ Settings choices with your profile and shares them with your
-- screen as the "Settings" attribute (a JSON table of the ones you changed).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local SettingsData = require(Shared.SettingsData)

local DataService = require(script.Parent.DataService)

local SettingsService = {}

local function publish(player: Player)
	local data = DataService.get(player)
	if data then
		player:SetAttribute("Settings", HttpService:JSONEncode(data.settings))
	end
end

function SettingsService.start()
	Remotes.event("SaveSetting").OnServerEvent:Connect(function(player, key, value)
		local data = DataService.get(player)
		local setting = type(key) == "string" and SettingsData.find(key)
		if data and setting and SettingsData.valid(setting, value) then
			data.settings[key] = if value == setting.default then nil else value
			publish(player)
		end
	end)
	DataService.ProfileLoaded:Connect(publish)
	for _, player in Players:GetPlayers() do
		publish(player)
	end
end

return SettingsService
