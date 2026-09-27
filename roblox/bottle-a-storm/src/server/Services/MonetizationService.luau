-- Game passes and developer products. Receipts are recorded in the profile
-- and saved before we tell Roblox the purchase is granted, so a purchase is
-- never lost or granted twice.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Products = require(Shared.Products)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent.Parent.Modules
local Notify = require(Modules.Notify)

local CosmeticService = require(script.Parent.CosmeticService)
local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local PlotService = require(script.Parent.PlotService)
local SeasonService = require(script.Parent.SeasonService)
local WeatherService = require(script.Parent.WeatherService)

local MonetizationService = {}

local function grantPass(player: Player, key: string)
	player:SetAttribute(Products.passAttribute(key), true)
	if key == "AutoCollect" then
		IncomeService.collect(player)
	end
	IncomeService.sync(player)
end

-- Returns true when the product was delivered.
local productHandlers: { [string]: (Player, any) -> boolean } = {
	SparksSmall = function(player, data)
		local amount =
			math.max(Config.Products.SparksSmallMin, IncomeService.rateOf(player) * Config.Products.SparksSmallSeconds)
		data.sparks += math.floor(amount)
		Notify.player(player, "💰 +⚡" .. Format.number(amount) .. " Sparks! Thank you!", "success")
		return true
	end,
	SparksLarge = function(player, data)
		local amount =
			math.max(Config.Products.SparksLargeMin, IncomeService.rateOf(player) * Config.Products.SparksLargeSeconds)
		data.sparks += math.floor(amount)
		Notify.player(player, "💰 +⚡" .. Format.number(amount) .. " Sparks! Thank you!", "success")
		return true
	end,
	EmergencyLock = function(player)
		return PlotService.lock(player, Config.Lock.EmergencyDuration, true)
	end,
	RaidShield = function(player, data)
		data.raidShields += 1
		Notify.player(player, "🛡️ Raid Shield ready! You have " .. data.raidShields .. ".", "success")
		return true
	end,
	SeasonPremium = function(player)
		return SeasonService.grantPremium(player)
	end,
	SeasonSkip = function(player)
		SeasonService.addXp(player, Config.Season.SkipTierXp)
		Notify.player(player, "⏭️ Skipped a season tier!", "success")
		return true
	end,
	SummonWeather = function(player)
		WeatherService.summon("RainbowHour", player.DisplayName)
		return true
	end,
}

-- Robux cosmetics ("Cosmetic_<id>") all share one handler.
local function handlerFor(key: string): ((Player, any) -> boolean)?
	if string.sub(key, 1, 9) == "Cosmetic_" then
		return function(player)
			return CosmeticService.grantProduct(player, key)
		end
	end
	return productHandlers[key]
end

local function processReceipt(receipt): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local item = Products.fromId(receipt.ProductId)
	local data = player and DataService.get(player)
	if not player or not item or not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receipt.PurchaseId)
	if DataService.hasReceipt(data, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local handler = handlerFor(item.key)
	if not handler then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ok, delivered = pcall(handler, player, data)
	if not ok or not delivered then
		warn("[Monetization] Could not deliver " .. item.key .. ": " .. tostring(delivered))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	DataService.addReceipt(data, purchaseId)
	IncomeService.sync(player)
	if not DataService.saveNow(player) then
		-- The grant stays in memory with its receipt, so a retry won't double it.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function checkPasses(player: Player)
	for _, pass in Products.Passes do
		if pass.id ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
			end)
			if ok and owns then
				grantPass(player, pass.key)
			end
		end
	end
end

-- Studio only: lets you test Robux items before they have real IDs.
local function onDevPurchase(player: Player, key: any)
	if not RunService:IsStudio() or type(key) ~= "string" then
		return
	end
	local item = Products.get(key)
	local data = DataService.get(player)
	if not item or not data then
		return
	end
	if Products.isPass(key) then
		grantPass(player, key)
		Notify.player(player, "🧪 Studio test: you now own " .. item.name .. ".", "success")
	else
		local handler = handlerFor(key)
		if handler then
			handler(player, data)
		end
		IncomeService.sync(player)
	end
end

function MonetizationService.start()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local pass = Products.fromId(passId)
		if purchased and pass and Products.isPass(pass.key) then
			grantPass(player, pass.key)
			Notify.player(player, "🎉 You got " .. pass.name .. "! Thank you!", "rare")
		end
	end)
	DataService.ProfileLoaded:Connect(checkPasses)
	Remotes.event("DevPurchase").OnServerEvent:Connect(onDevPurchase)
end

return MonetizationService
