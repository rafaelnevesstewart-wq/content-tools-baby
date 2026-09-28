-- 🛍️ The shop street's sellers: pressing a stall's prompt opens that shop's
-- window (WorldBuilder puts an "OpenWindow" attribute on each prompt; other
-- prompts like the 📖 Fish Book stand use it too).

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")

local EmoteWheel = require(script.Parent.EmoteWheel)
local FishBook = require(script.Parent.FishBook)
local Kits = require(script.Parent.Kits)
local Market = require(script.Parent.Market)
local Paint = require(script.Parent.Paint)
local Rewards = require(script.Parent.Rewards)
local Shop = require(script.Parent.Shop)
local Style = require(script.Parent.Style)

local player = Players.LocalPlayer

local ShopStreet = {}

local OPEN: { [string]: () -> () } = {
	Market = Market.toggle,
	Kits = Kits.toggle,
	Style = Style.toggle,
	Pets = function()
		Style.open("pet")
	end,
	Emotes = EmoteWheel.toggle,
	Paint = Paint.toggle,
	Rewards = function()
		Rewards.open("Spin")
	end,
	Robux = Shop.toggle,
	FishBook = FishBook.toggle, -- 🎣 the stand by the fishing pond
}

function ShopStreet.start()
	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who ~= player then
			return
		end
		local key = prompt:GetAttribute("OpenWindow")
		local open = type(key) == "string" and OPEN[key]
		if open then
			open()
		end
	end)
end

return ShopStreet
