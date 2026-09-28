--!strict
-- 📰 What's new in Bottle a Storm: shown on the news board in the castle
-- courtyard and in a pop-up the first time you join after an update. Add a
-- new entry at the TOP (with a bigger version number) for every update.

export type News = { version: number, title: string, lines: { string } }

local NewsData = {}

NewsData.List = {
	{
		version = 13,
		title = "📋 A tidier, faster Bottle a Storm!",
		lines = {
			"📋 Everything is in the new Menu (press M), 🏅 an Achievement Book",
			"🔕 Fewer pop-ups option and a 📜 message log",
			"📅 Lobby events take turns: see what's next at the top right",
			"⚡ Faster mode in ⚙️ Settings for slow devices",
			"🎁 A welcome gift for new players",
		},
	},
	{
		version = 12,
		title = "🐍 A Sea Serpent, player shops and a 2v2 cup!",
		lines = {
			"🐍 The Sea Serpent boss swims in on the 🌊 Bubble Reef map",
			"🏪 Sell your spare cosmetics at the Player Market (Shop Street)",
			"🎓 Classes level up as you play them, with stronger perks",
			"🌠 Shooting stars at night: find where they land and make a wish",
			"🧱 Stairs, half blocks, windows and doors, 🏟️ the 2v2 Arena Cup",
		},
	},
	{
		version = 11,
		title = "🧙 Classes, disasters and a boat race!",
		lines = {
			"🧙 Pick Knight, Archer, Builder or Healer before each match",
			"🌋 Meteor showers, earthquakes and floods in matches, 🎯 bounties",
			"🏠 Furniture for your base, 🧩 daily puzzle rooms on Base Island",
			"🚤 Sky Boat Race from the dock by the gate, 🎭 costume parties",
			"🌟 The Hall of Legends: statues of the best players ever",
		},
	},
	{
		version = 10,
		title = "🏰 Castle Defense, fishing and a monthly season!",
		lines = {
			"🏰 Castle Defense: hold your castle against 8 waves of storm monsters",
			"🎣 A fishing pond on Games Island with 14 fish to catch",
			"🏅 A monthly leaderboard: the top 100 win prizes",
			"🐾 Pets now help in matches, 🌊 new Bubble Reef map",
			"🗺️ Daily treasure hunt, 📸 photo mode (P), 🎟️ private match rules",
		},
	},
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
