--!strict
-- Thief styles: pick one way to steal. Unlock with Sparks in the Shop's
-- Styles tab, then equip one at a time.

export type Style = {
	key: string,
	name: string,
	emoji: string,
	cost: number,
	description: string,
}

local ThiefStyles = {}

ThiefStyles.List = {
	{
		key = "QuickHands",
		name = "Quick Hands",
		emoji = "⚡",
		cost = 1000,
		description = "Grab jars in 0.5s instead of 1.5s.",
	},
	{
		key = "CloudWalker",
		name = "Cloud Walker",
		emoji = "☁️",
		cost = 5000,
		description = "Turn almost invisible for 5s after you grab a jar. Your name tag hides too.",
	},
	{
		key = "UmbrellaTank",
		name = "Umbrella Tank",
		emoji = "☂️",
		cost = 15000,
		description = "Traps can't stun you and your umbrella blocks the first zap. You carry a bit slower.",
	},
} :: { Style }

-- Numbers for each style.
ThiefStyles.QuickHoldSeconds = 0.5
ThiefStyles.InvisibleSeconds = 5
ThiefStyles.InvisibleTransparency = 0.9
ThiefStyles.TankCarrySpeedMultiplier = 0.6 -- everyone else carries at Config.Steal.CarrySpeedMultiplier

local byKey: { [string]: Style } = {}
for _, style in ThiefStyles.List do
	byKey[style.key] = style
end

function ThiefStyles.get(key: string?): Style?
	if key == nil then
		return nil
	end
	return byKey[key]
end

return ThiefStyles
