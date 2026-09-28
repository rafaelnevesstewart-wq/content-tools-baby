--!strict
-- 💬 Taunts and voice lines: press T (or 💬) to say one; your character also
-- says things by itself when you knock someone out, break a bed or win
-- (TauntService). They pop up in a speech bubble with a sound.

export type Taunt = { key: string, text: string, sound: string, pitch: number }

local TauntData = {}

TauntData.List = {
	{ key = "GG", text = "GG! 🤝", sound = "chime", pitch = 1.2 },
	{ key = "ComeGetMe", text = "Come get me! 😤", sound = "zap", pitch = 1.3 },
	{ key = "TooEasy", text = "Too easy 😎", sound = "pop", pitch = 0.9 },
	{ key = "NiceTry", text = "Nice try! 😜", sound = "oops", pitch = 1.4 },
	{ key = "BedSafe", text = "My bed is safe 🛏️🔒", sound = "click", pitch = 0.8 },
	{ key = "FollowMe", text = "Team, follow me! 🚩", sound = "chime", pitch = 0.9 },
	{ key = "Help", text = "HELP! 😱", sound = "oops", pitch = 0.8 },
	{ key = "LetsGo", text = "Let's gooo! 🔥", sound = "zap", pitch = 1.1 },
	{ key = "Oops", text = "Oops... 😅", sound = "oops", pitch = 1 },
	{ key = "Thanks", text = "Thanks! 💖", sound = "chime", pitch = 1.4 },
} :: { Taunt }

-- What your character says by itself.
TauntData.Auto = {
	kill = { "Boom! 💥", "See you later! 👋", "Too slow! 💨", "Gotcha! ⚡" },
	bed = { "Your bed is mine! 🛏️", "No more naps for you! 😴", "Bed broken! 🔨" },
	win = { "GG everyone! 🏆", "Victory! 🎉", "We did it! 🙌" },
}

function TauntData.get(key: string?): Taunt?
	for _, taunt in TauntData.List do
		if taunt.key == key then
			return taunt
		end
	end
	return nil
end

return TauntData
