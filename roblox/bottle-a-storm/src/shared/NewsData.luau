--!strict
-- 📰 What's new in Bottle a Storm: shown on the news board in the castle
-- courtyard and in a pop-up the first time you join after an update. Add a
-- new entry at the TOP (with a bigger version number) for every update.

export type News = { version: number, title: string, lines: { string } }

local NewsData = {}

NewsData.List = {
	{
		version = 9,
		title = "🎪 Weekly events, gliders and a dragon to tame!",
		lines = {
			"🎪 A new rule every week: low gravity, giants, one hit, speed rush or double Sparks",
			"🪂 Gliders and ⛱️ parachutes in the match shop",
			"🐉 Do the most damage to the Storm Dragon and you might tame it as a mount",
			"🏆 A trophy room behind your base, 🎨 build contests with star voting",
			"🧭 Guide Gale by the gate, 🎁 gift cosmetics to friends from 👥 Party",
		},
	},
	{
		version = 8,
		title = "🐎 Mounts, mini-games and base building!",
		lines = {
			"🐎 Ride horses and flying clouds in the lobby (🎨 Style → Mounts)",
			"🏗️ Build your own base on Base Island, saved forever",
			"🎯 Target Range and ⏱️ Parkour Race on Games Island",
			"👑 King of the Hill mode, 🌙 day and night in matches",
			"💬 Taunts (T), 📅 a 28-day login calendar",
		},
	},
	{
		version = 7,
		title = "🧟 Zombie Survival and Shop Street",
		lines = {
			"🧟 Defend your bed from 10 zombie waves together",
			"🛍️ Shop Street behind the castle, 🚀 rockets and 🪝 grappling hooks",
			"😀 Emote wheel (G), 🐾 pet levels, 🖌️ Paint Shop, 🎖️ Clan Pass",
		},
	},
	{
		version = 6,
		title = "🐉 The Storm Dragon and clans",
		lines = {
			"🐉 A dragon boss attacks the middle island",
			"🛡️ Clans, 🤝 trading, 🌟 challenges, 🗳️ map votes",
		},
	},
} :: { News }

function NewsData.latest(): News
	return NewsData.List[1]
end

return NewsData
