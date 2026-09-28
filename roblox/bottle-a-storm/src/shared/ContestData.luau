--!strict
-- 🎨 Build contests on Base Island (ContestService): a theme, a building
-- phase, then everyone votes 1-5 stars on each base. The contest's state is
-- shared as the workspace attribute "Contest" (JSON: phase, theme, endsAt).

local ContestData = {}

ContestData.BuildSeconds = 10 * 60
ContestData.VoteSeconds = 3 * 60
ContestData.MinBlocks = 10 -- a base needs this many blocks to enter

ContestData.Themes = {
	"🏰 A castle",
	"🏠 A cozy house",
	"🚀 A rocket ship",
	"🌳 A treehouse",
	"🐉 A dragon",
	"🗼 The tallest tower",
	"⛵ A pirate ship",
	"🎂 A giant cake",
	"🌋 A volcano",
	"🎡 A theme park ride",
	"🛏️ The best bed fort",
	"🤖 A robot",
}

-- Sparks for 1st, 2nd and 3rd; everyone who enters and everyone who votes.
ContestData.Prizes = { 2000, 1000, 500 }
ContestData.EntrySparks = 200
ContestData.VoterSparks = 50

return ContestData
