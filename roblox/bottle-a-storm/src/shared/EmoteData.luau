--!strict
-- 😀 Emotes for the emote wheel (press G, or the 😀 button). The first ones
-- are free; the rest are bought once with Sparks (EmoteService). "emote"
-- ones play Roblox's built-in emotes; the others are moves your own screen
-- makes (EmoteWheel).

export type Emote = {
	key: string,
	name: string,
	emoji: string,
	cost: number, -- Sparks; 0 = free
	emote: string?, -- a built-in Roblox emote
	move: string?, -- "spin" | "flip" | "hop" | "sit"
}

local EmoteData = {}

EmoteData.List = {
	{ key = "Wave", name = "Wave", emoji = "👋", cost = 0, emote = "wave" },
	{ key = "Point", name = "Point", emoji = "👉", cost = 0, emote = "point" },
	{ key = "Cheer", name = "Cheer", emoji = "🎉", cost = 0, emote = "cheer" },
	{ key = "Laugh", name = "Laugh", emoji = "😂", cost = 0, emote = "laugh" },
	{ key = "Sit", name = "Sit", emoji = "🪑", cost = 0, move = "sit" },
	{ key = "Hop", name = "Happy Hops", emoji = "🐰", cost = 600, move = "hop" },
	{ key = "Spin", name = "Spin", emoji = "🌀", cost = 1000, move = "spin" },
	{ key = "Dance", name = "Dance", emoji = "💃", cost = 1500, emote = "dance" },
	{ key = "Flip", name = "Backflip", emoji = "🤸", cost = 2500, move = "flip" },
	{ key = "Dance2", name = "Groove", emoji = "🕺", cost = 3000, emote = "dance2" },
	{ key = "Dance3", name = "Party Dance", emoji = "🪩", cost = 5000, emote = "dance3" },
} :: { Emote }

function EmoteData.get(key: string?): Emote?
	for _, emote in EmoteData.List do
		if emote.key == key then
			return emote
		end
	end
	return nil
end

return EmoteData
