--!strict
-- The server creates every remote on first require; clients wait for them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	"Notify", -- server -> client: (text, kind)
	"DevPurchase", -- client -> server, Studio only: (itemKey)
	"Juice", -- server -> client: (kind, ...) floating numbers, sounds, shake, pop-ups
	"CrateOpened", -- server -> client: (result) a Kit Crate opened, for the opening animation
	"Swing", -- client -> server: (aimPoint) sword swing
	"ShootBow", -- client -> server: (aimPoint)
	"UseItem", -- client -> server: (itemKey, aimPoint) Storm Apple / Wind Pearl
	"PlaceBlock", -- client -> server: (blockKey, point)
	"VoteMode", -- client -> server: ("Solo" | "Duo" | "Squad")
	"PartyAction", -- client -> server: ("invite" | "accept" | "decline" | "leave" | "kick", userId)
	"PartyInvite", -- server -> client: (fromUserId, fromName)
	"DuelAction", -- client -> server: ("challenge" | "accept" | "decline", userId)
	"DuelInvite", -- server -> client: (fromUserId, fromName) someone challenged you
	"SaveSetting", -- client -> server: (key, value) a ⚙️ Settings choice
	"KitPower", -- client -> server: (ability, aimOrDirection) kit powers the server runs
	"TournamentAction", -- client -> server: ("join" | "leave")
	"Vote", -- client -> server: ("map" | "bots", key) lobby votes for the next match
	"SetPaint", -- client -> server: ("blade" | "armor", colorIndex or 0)
	"NewsSeen", -- client -> server: () the "What's new" pop-up was closed
	"Taunt", -- client -> server: (key) say a taunt (TauntData)
	"Mount", -- client -> server: () hop on or off your mount
	"RangeShot", -- client -> server: (aimPoint) a Target Range arrow
	"BaseEdit", -- client -> server: ("place" | "remove" | "clear", i, j, k, blockKey, turn)
	"ClanInvite", -- server -> client: (clanId, clanName, tag, fromName)
	"TradeAction", -- client -> server: (action, a, b) see TradeService
	"TradeInvite", -- server -> client: (fromUserId, fromName)
	"TradeUpdate", -- server -> client: (state) the trade window
	"Victory", -- server -> client: (teamKey) your team won: dance!
	"DamageShown", -- server -> client: (position, amount) you hit someone
	"KillFeed", -- server -> all clients: (entry) a knockout or a broken bed
	"UseGadget", -- client -> server: ("TNT" | "Fireball" | "Rocket" | potion key | "Mine", aimPoint)
	"Glide", -- client -> server: (on) you started or stopped gliding (the wings show)
	"ArenaCupAction", -- client -> server: ("join" | "leave") the 🏟️ 2v2 Arena Cup sign-ups
	"BoatAction", -- client -> server: ("stop") quit the 🚤 Sky Boat Race
	"PickClass", -- client -> server: (classKey) your 🧙 class for the next match
	"Fish", -- client -> server: ("cast", aimPoint) or ("reel") with the Fishing Rod
}

local FUNCTIONS = {
	"GetSeason", -- client -> server: () -> your season progress
	"SeasonClaim", -- client -> server: (tier, "free" | "premium") -> (ok, message)
	"GetRewards", -- client -> server: () -> daily, quests and Kit Collection info
	"ClaimDaily", -- client -> server: () -> (ok, message)
	"ClaimQuest", -- client -> server: (index) -> (ok, message)
	"GetTitles", -- client -> server: () -> titles and progress
	"SetTitle", -- client -> server: (titleId or nil) -> (ok, message)
	"Cosmetic", -- client -> server: (action, idOrValue) -> (ok, message)
	"RedeemCode", -- client -> server: (text) -> (ok, message)
	"Spin", -- client -> server: () -> (ok, prizeIndex or message)
	"AdminCommand", -- client -> server: (command, arg) -> (ok, message), admins only
	"GetHoliday", -- client -> server: () -> event info and your currency
	"BuyHoliday", -- client -> server: (index) -> (ok, message)
	"CheckGroup", -- client -> server: () -> (ok, message)
	"GetMarket", -- client -> server: () -> market stock
	"BuyMarket", -- client -> server: (slot) -> (ok, message)
	"OpenCrate", -- client -> server: (crateKey) -> (ok, message) opens a Kit Crate
	"BuyMatchItem", -- client -> server: (itemKey) -> (ok, message)
	"BuyUpgrade", -- client -> server: (upgradeKey) -> (ok, message)
	"GetKits", -- client -> server: () -> your storms and the chosen kit
	"ChooseKit", -- client -> server: (uid) -> (ok, message)
	"GetAchievements", -- client -> server: () -> achievements and your progress
	"GetStats", -- client -> server: () -> your 📊 Stats page
	"GetChallenges", -- client -> server: () -> your 🌟 daily and weekly challenges
	"ClanAction", -- client -> server: (action, a, b) -> (ok, message)
	"GetClan", -- client -> server: () -> your clan and the top clans
	"GetTradeInventory", -- client -> server: () -> your tradeable kits, cosmetics and Sparks
	"BuyEmote", -- client -> server: (key) -> (ok, message)
	"ClaimChallenge", -- client -> server: ("daily" | index | "bonus") -> (ok, message)
	"GetGifts", -- client -> server: (userId) -> what you could gift them and your Sparks
	"SendGift", -- client -> server: (userId, cosmeticId) -> (ok, message)
	"CustomRules", -- client -> server: ("get") -> the rules, or ("set", optionKey, choice) -> ok (private server owner)
	"PlayerShop", -- client -> server: ("info") -> the 🏪 Player Market, or ("sell" | "cancel" | "buy", a, b) -> (ok, message)
	"Costume", -- client -> server: ("info") -> costume party info, or ("look" | "vote", userId, stars) -> (ok, message)
	"PuzzleCode", -- client -> server: (fourDigits) -> (ok, message) the 🔐 Code Door
	"GetFish", -- client -> server: () -> your Fish Book (caught counts, best weights)
	"Contest", -- client -> server: ("info") -> contest info, or ("visit" | "vote", userId, stars) -> (ok, message)
}

local folder: Instance
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in EVENTS do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
	for _, name in FUNCTIONS do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = folder
		end
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

local Remotes = {}

function Remotes.event(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

function Remotes.func(name: string): RemoteFunction
	return folder:WaitForChild(name) :: RemoteFunction
end

return Remotes
