-- Redeem codes. Post these on your social media; players type them in
-- 🎁 Rewards → Codes. They live on the server only, so nobody can read them
-- out of the game. Each player can use each code once.
--   code:    what players type (not case-sensitive)
--   reward:  same format as the season pass rewards (see SeasonData.Reward)
--   expires: optional os.time() after which the code stops working

local SeasonData = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").SeasonData)

export type Code = { code: string, reward: SeasonData.Reward, expires: number? }

return {
	{ code = "RELEASE", reward = { kind = "sparks", minutes = 10, min = 2500 } },
	{ code = "STORMY", reward = { kind = "snacks" } },
	{ code = "THANKYOU", reward = { kind = "shield", amount = 1 } },
	{ code = "LIGHTNING", reward = { kind = "storm", rarity = 3 } },
	{ code = "LIKES1K", reward = { kind = "sparks", minutes = 30, min = 10000 } },
} :: { Code }
