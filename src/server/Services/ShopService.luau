-- Game passes and developer products.
-- In Studio, items whose Id is still 0 can be granted for free from the shop
-- so every perk can be tested before anything is created on the Creator Hub.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)

local ShopService = {}
local S

local owned = {} -- [Player] = { [passKey] = true }

function ShopService:Init(services)
	S = services
	MarketplaceService.ProcessReceipt = function(receipt)
		return self:_processReceipt(receipt)
	end
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local pass = Util.find(Config.GamePasses, "Id", passId)
		if pass and owned[player] then
			owned[player][pass.Key] = true
			S.PlayerService:OnPassesChanged(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		owned[player] = nil
	end)
end

function ShopService:LoadPasses(player: Player)
	local set = {}
	for _, pass in Config.GamePasses do
		if pass.Id ~= 0 then
			local ok, has = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.Id)
			if ok and has then
				set[pass.Key] = true
			end
		end
	end
	owned[player] = set
	return set
end

function ShopService:Owns(player: Player, key: string): boolean
	local set = owned[player]
	return set ~= nil and set[key] == true
end

function ShopService:OwnedList(player: Player)
	local list = {}
	for key in owned[player] or {} do
		table.insert(list, key)
	end
	return list
end

-- Studio-only free grant for items that have no real Id yet.
function ShopService:StudioGrant(player: Player, kind: string, key: string)
	if not RunService:IsStudio() then
		return false
	end
	if kind == "Pass" then
		local pass = Util.find(Config.GamePasses, "Key", key)
		if pass and owned[player] then
			owned[player][key] = true
			S.PlayerService:OnPassesChanged(player)
			return true
		end
	elseif kind == "Product" then
		if Util.find(Config.DevProducts, "Key", key) then
			return S.PlayerService:GrantProduct(player, key)
		end
	end
	return false
end

function ShopService:_processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local product = Util.find(Config.DevProducts, "Id", receipt.ProductId)
	if not player or not product then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local profile = S.PlayerService:GetProfile(player)
	if not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if table.find(profile.PurchaseIds, receipt.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local ok, granted = pcall(function()
		return S.PlayerService:GrantProduct(player, product.Key)
	end)
	if not ok or not granted then
		warn("[ShopService] Failed to grant", product.Key, ok and "" or granted)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	table.insert(profile.PurchaseIds, receipt.PurchaseId)
	while #profile.PurchaseIds > 50 do
		table.remove(profile.PurchaseIds, 1)
	end
	S.DataService:Save(player, profile)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

return ShopService
