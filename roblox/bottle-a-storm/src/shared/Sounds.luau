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
	-- Fighting
	slash = { id = "rbxasset://sounds/swordslash.wav", volume = 0.45, pitch = 1 },
	hit = { id = "rbxasset://sounds/swordlunge.wav", volume = 0.55, pitch = 1.15 },
	hurt = { id = "rbxasset://sounds/hit.wav", volume = 0.55, pitch = 0.8 },
	oof = { id = "rbxasset://sounds/uuhhh.mp3", volume = 0.6, pitch = 1 },
	kill = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.6, pitch = 2.2 },
	equip = { id = "rbxasset://sounds/unsheath.wav", volume = 0.35, pitch = 1 },
	arrow = { id = "rbxasset://sounds/paintball.wav", volume = 0.45, pitch = 0.8 },
	boom = { id = "rbxasset://sounds/collide.wav", volume = 0.7, pitch = 0.7 },
	-- Beds and winning
	bedBreak = { id = "rbxasset://sounds/collide.wav", volume = 0.6, pitch = 1.4 },
	win = { id = "rbxasset://sounds/victory.wav", volume = 0.6, pitch = 1 },
} :: { [string]: SoundInfo }

return Sounds
