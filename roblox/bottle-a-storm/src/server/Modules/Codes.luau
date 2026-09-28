-- Redeem codes. Post these on your social media; players type them in
-- 🎁 Rewards → Codes. They live on the server only, so nobody can read them
-- out of the game. Each player can use each code once.
--   code:    what players type (not case-sensitive)
--   reward:  same format as the battle pass rewards (see SeasonData.Reward)
--   expires: optional os.time() after which the code stops working

local SeasonData = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").SeasonData)

export type Code = { code: string, reward: SeasonData.Reward, expires: number? }

return {
	{ code = "RELEASE", reward = { kind = "sparks", amount = 1000 } },
	{ code = "BEDWARS", reward = { kind = "kit", rarity = 3 } },
	{ code = "THANKYOU", reward = { kind = "sparks", amount = 500 } },
	{ code = "LIGHTNING", reward = { kind = "kit", rarity = 3, mutated = true } },
	{ code = "LIKES1K", reward = { kind = "sparks", amount = 3000 } },
} :: { Code }
