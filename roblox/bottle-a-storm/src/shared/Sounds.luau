--!strict
-- Every sound effect in one place. These point at sounds built into the
-- Roblox app ("rbxasset://sounds/..."). If one stays silent in Studio (the
-- Output window says it failed to load), swap it for any sound from the
-- Creator Store: Toolbox > Audio, right-click > Copy Asset ID, then paste it
-- here as "rbxassetid://123456789".

export type SoundInfo = {
	id: string,
	volume: number,
	pitch: number,
}

local Sounds = {
	click = { id = "rbxasset://sounds/clickfast.wav", volume = 0.4, pitch = 1.1 },
	throw = { id = "rbxasset://sounds/swoosh.wav", volume = 0.5, pitch = 1.2 },
	pop = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.5, pitch = 1.3 },
	chime = { id = "rbxasset://sounds/victory.wav", volume = 0.45, pitch = 1 },
	coins = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.45, pitch = 1.8 },
	zap = { id = "rbxasset://sounds/hit.wav", volume = 0.5, pitch = 0.9 },
	oops = { id = "rbxasset://sounds/button.wav", volume = 0.4, pitch = 0.7 },
} :: { [string]: SoundInfo }

return Sounds
