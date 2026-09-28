--!strict
-- 🧭 Guide Gale's quest for new players (GuideService): a chain of steps that
-- walks you through the game, done in order. Each step pays Sparks; finishing
-- them all gives an Epic kit, a big Sparks bonus and the 🎓 Storm Scholar
-- title. Your step is saved as data.guide and shown as "GuideStep".

export type Step = { key: string, text: string, sparks: number }

local GuideData = {}

GuideData.Steps = {
	{ key = "talk", text = "Talk to Guide Gale by the castle gate", sparks = 100 },
	{ key = "chest", text = "Open the 🎁 Daily Mystery Chest in the castle", sparks = 150 },
	{ key = "collect", text = "Join a match and pick up resources at your generator", sparks = 150 },
	{ key = "buy", text = "Buy something from the item shop on your island", sparks = 150 },
	{ key = "knockout", text = "Knock out an enemy (bots count!)", sparks = 200 },
	{ key = "bed", text = "Break an enemy bed", sparks = 250 },
	{ key = "play", text = "Play a match to the end", sparks = 200 },
	{ key = "base", text = "Claim a plot on 🏗️ Base Island (over the west bridge)", sparks = 150 },
} :: { Step }

GuideData.FinalSparks = 1000
GuideData.FinalKitRarity = 4 -- Epic

-- Gale's tips once you're done.
GuideData.Tips = {
	"Protect your bed! Cover it in blocks: wool first, then wood, then obsidian.",
	"Upgrade your generator at the team shop for more resources.",
	"The Storm Dragon visits the middle island: beat it for loot (and maybe tame it!).",
	"Hold jump while falling with a 🪂 Glider to sail across the gaps.",
	"Check the news board for this week's 🎪 event.",
	"Party up with friends in 👥 Party so you're always on the same team.",
}

return GuideData
