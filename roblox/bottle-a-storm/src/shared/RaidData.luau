--!strict
-- Mega-Storm bosses. One is picked at random for each raid.

export type Boss = {
	id: string,
	name: string,
	emoji: string,
	colors: { Color3 },
	fx: string, -- particle style from StormModel
	taunt: string, -- shown when it arrives
	winLine: string, -- shown when it wins
}

local RaidData = {}

RaidData.Bosses = {
	{
		id = "GrandmaCyclone",
		name = "Grandma Cyclone",
		emoji = "🌪️",
		colors = { Color3.fromRGB(150, 160, 175), Color3.fromRGB(110, 120, 140) },
		fx = "hurricane",
		taunt = "Grandma Cyclone is here to tidy up your islands!",
		winLine = "Grandma Cyclone swept everyone's islands clean!",
	},
	{
		id = "ThunderTitan",
		name = "The Thunder Titan",
		emoji = "⛈️",
		colors = { Color3.fromRGB(70, 60, 110), Color3.fromRGB(100, 90, 150) },
		fx = "lightning",
		taunt = "The Thunder Titan rumbles over the Wild Skies!",
		winLine = "The Thunder Titan zapped the whole server!",
	},
	{
		id = "SirBlizzardington",
		name = "Sir Blizzardington",
		emoji = "❄️",
		colors = { Color3.fromRGB(215, 235, 255), Color3.fromRGB(150, 195, 240) },
		fx = "snow",
		taunt = "Sir Blizzardington demands your finest storms!",
		winLine = "Sir Blizzardington froze everyone's storms solid!",
	},
} :: { Boss }

local byId: { [string]: Boss } = {}
for _, boss in RaidData.Bosses do
	byId[boss.id] = boss
end

function RaidData.get(id: string?): Boss?
	if id == nil then
		return nil
	end
	return byId[id]
end

return RaidData
