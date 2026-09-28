-- Background music on your screen: calm songs in the lobby, faster ones
-- while you're in a match, and a fanfare when your team wins. The songs are
-- listed in Config.Music; the volume is the ⚙️ Settings "Music" choice.
-- Songs fade into each other when you go from the lobby to a match.

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local Settings = require(script.Parent.Settings)

local player = Players.LocalPlayer

local MusicController = {}

local FADE = 1.5

local current: Sound? = nil
local playlist = ""
local rng = Random.new()

local function volume(): number
	return Config.Music.Volume * (Settings.get("music") or 0)
end

local function fadeOut(sound: Sound)
	local tween = TweenService:Create(sound, TweenInfo.new(FADE), { Volume = 0 })
	tween.Completed:Connect(function()
		sound:Destroy()
	end)
	tween:Play()
end

local function listFor(name: string): { number }
	return if name == "Match" then Config.Music.Match else Config.Music.Lobby
end

local playNext: (string) -> ()

-- Starts a random song from a playlist, fading out whatever was playing.
playNext = function(name: string)
	playlist = name
	local old = current
	current = nil
	if old then
		fadeOut(old)
	end
	local songs = listFor(name)
	if #songs == 0 or volume() <= 0 then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = "Music"
	sound.SoundId = "rbxassetid://" .. songs[rng:NextInteger(1, #songs)]
	sound.Volume = 0
	sound.Parent = SoundService
	sound:Play()
	TweenService:Create(sound, TweenInfo.new(FADE), { Volume = volume() }):Play()
	current = sound
	sound.Ended:Connect(function()
		if current == sound then
			playNext(name)
		end
	end)
end

local function wanted(): string
	return if player:GetAttribute("InMatch") then "Match" else "Lobby"
end

local function refresh()
	local name = wanted()
	if name ~= playlist or (current == nil and volume() > 0) then
		playNext(name)
	end
end

function MusicController.start()
	Settings.Changed:Connect(function(key)
		if key == "music" then
			if current then
				current.Volume = volume()
				if volume() <= 0 then
					fadeOut(current)
					current = nil
				end
			else
				refresh()
			end
		end
	end)
	player:GetAttributeChangedSignal("InMatch"):Connect(refresh)
	Remotes.event("Victory").OnClientEvent:Connect(function()
		local id = Config.Music.Victory
		if id and volume() > 0 then
			local fanfare = Instance.new("Sound")
			fanfare.SoundId = "rbxassetid://" .. id
			fanfare.Volume = math.min(1, volume() * 1.5)
			fanfare.Parent = SoundService
			fanfare:Play()
			fanfare.Ended:Connect(function()
				fanfare:Destroy()
			end)
		end
	end)
	task.delay(2, refresh)
end

return MusicController
