-- Plays the sound effects listed in src/shared/Sounds.luau.

local SoundService = game:GetService("SoundService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Sounds = require(Shared.Sounds)

local Sfx = {}

local cache: { [string]: Sound } = {}

-- 0 to 1, from the ⚙️ Settings "Sound effects" choice (set by Settings).
Sfx.volume = 1

-- Plays a sound by name ("click", "pop", ...). `pitch` nudges it up or down.
function Sfx.play(name: string, pitch: number?)
	local info = Sounds[name]
	if not info then
		return
	end
	local sound = cache[name]
	if not sound then
		local created = Instance.new("Sound")
		created.Name = "Sfx_" .. name
		created.SoundId = info.id
		created.Volume = info.volume
		created:SetAttribute("BaseVolume", info.volume)
		created.Parent = SoundService
		cache[name] = created
		sound = created
	end
	local s = sound :: Sound
	if Sfx.volume <= 0 then
		return
	end
	s.Volume = info.volume * Sfx.volume
	s.PlaybackSpeed = info.pitch * (pitch or 1)
	-- PlayLocalSound lets the same effect overlap itself (fast clicks, coins).
	SoundService:PlayLocalSound(s)
end

function Sfx.start() end

return Sfx
