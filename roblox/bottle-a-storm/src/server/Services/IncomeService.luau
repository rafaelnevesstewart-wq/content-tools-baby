-- Your Sparks wallet. Sparks come from Bed Wars matches (knockouts, beds,
-- wins, playing), rewards and purchases. This keeps the numbers the client
-- UI reads (player attributes) and the leaderboard columns (Sparks, Wins,
-- Kills) up to date, and works out the Sparks bonus for match rewards.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Products = require(Shared.Products)

local DataService = require(script.Parent.DataService)
local WeatherService = require(script.Parent.WeatherService)

local IncomeService = {}

-- How much bigger this player's match Sparks are right now: VIP, Style
-- Bonus, Kit Collection rows, group members, Admin Abuse and Rainbow Hour.
function IncomeService.multiplier(player: Player): number
	local data = DataService.get(player)
	if not data then
		return 1
	end
	local vip = if player:GetAttribute(Products.passAttribute("VIP")) == true then Config.Income.VIPMultiplier else 1
	local style = 1 + (data.styleBonus or 0)
	local collection = 1 + Config.Index.RowBonus * (data.indexRows or 0)
	local group = if player:GetAttribute("InGroup") == true then 1 + Config.Group.Bonus else 1
	local abuseUntil = workspace:GetAttribute("AbuseUntil")
	local abuse = if type(abuseUntil) == "number" and abuseUntil > workspace:GetServerTimeNow()
		then Config.Admin.AbuseIncomeMultiplier
		else 1
	return vip * style * collection * group * abuse * WeatherService.sparksMultiplier()
end

-- Pushes the profile's numbers to attributes and leaderstats.
function IncomeService.sync(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	player:SetAttribute("Sparks", math.floor(data.sparks))
	player:SetAttribute("SparksBonus", IncomeService.multiplier(player))
	player:SetAttribute("KitCount", #data.storms)
	player:SetAttribute("IndexRows", data.indexRows or 0)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local function set(name: string, value: number)
			local holder = leaderstats:FindFirstChild(name) :: IntValue?
			if holder then
				holder.Value = math.floor(math.min(value, 2 ^ 53))
			end
		end
		set("Sparks", data.sparks)
		set("Wins", data.stats.wins or 0)
		set("Kills", data.stats.kills or 0)
	end
end

function IncomeService.addSparks(player: Player, amount: number)
	local data = DataService.get(player)
	if data then
		data.sparks += amount
		data.stats.sparksEarned += amount
		IncomeService.sync(player)
	end
end

local function createLeaderstats(player: Player)
	if player:FindFirstChild("leaderstats") then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	for _, name in { "Wins", "Kills", "Sparks" } do
		local value = Instance.new("IntValue")
		value.Name = name
		value.Parent = folder
	end
	folder.Parent = player
end

function IncomeService.start()
	DataService.ProfileLoaded:Connect(function(player)
		createLeaderstats(player)
		IncomeService.sync(player)
	end)
	-- The bonus shown in the HUD changes with Admin Abuse and Rainbow Hour.
	task.spawn(function()
		while true do
			task.wait(5)
			for _, player in Players:GetPlayers() do
				IncomeService.sync(player)
			end
		end
	end)
end

return IncomeService
