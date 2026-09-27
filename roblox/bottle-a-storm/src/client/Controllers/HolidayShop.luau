-- The holiday event tab in the 🏪 Market (only while an event is on): your
-- event currency, time left, and the event shop.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local StormData = require(Shared.StormData)

local Market = require(script.Parent.Market)
local Toasts = require(script.Parent.Toasts)
local UI = require(script.Parent.UI)

local HolidayShop = {}

local function build(page: ScrollingFrame)
	local info = Remotes.func("GetHoliday"):InvokeServer()
	if type(info) ~= "table" then
		return
	end
	local left = (info.endsAt or 0) - workspace:GetServerTimeNow()
	local header = UI.new("Frame", {
		LayoutOrder = 0,
		BackgroundColor3 = UI.Colors.PanelLight,
		Parent = page,
	}, { UI.corner(12), UI.padding(8) })
	UI.label({
		Size = UDim2.fromScale(1, 1),
		Text = info.emoji .. " " .. info.name .. "\nYou have " .. info.currencyEmoji .. " " .. Format.number(
			info.points
		) .. "\nEnds in " .. math.max(0, math.floor(left / 86400)) .. " days\n" .. (if Config.GameMode
				== "BedWars"
			then "Win fights to earn more!"
			else "Catch storms to earn more!"),
		TextScaled = true,
		Parent = header,
	})
	for index, item in info.shop do
		local def = item.stormId and StormData.get(item.stormId)
		local frame = UI.new("Frame", {
			LayoutOrder = index,
			BackgroundColor3 = UI.Colors.PanelLight,
			Parent = page,
		}, { UI.corner(12), UI.padding(8) })
		if def then
			UI.stroke(StormData.rarityOf(def).color, 2).Parent = frame
		end
		local title = UI.label({
			Size = UDim2.new(1, 0, 0, 60),
			Text = if def then def.name .. "\n" .. StormData.rarityOf(def).name else tostring(item.label),
			TextScaled = true,
			TextWrapped = true,
			TextColor3 = if def then UI.ink(StormData.rarityOf(def).color) else UI.Colors.Text,
			Parent = frame,
		})
		UI.new("UITextSizeConstraint", { MaxTextSize = 18, Parent = title })
		if def then
			UI.label({
				Position = UDim2.fromOffset(0, 64),
				Size = UDim2.new(1, 0, 0, 20),
				Text = "+" .. Format.number(def.income) .. " ⚡/s",
				TextSize = 14,
				TextColor3 = UI.Colors.Muted,
				Parent = frame,
			})
		end
		local affordable = info.points >= item.cost
		UI.button({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.new(1, 0, 0, 38),
			Text = info.currencyEmoji .. " " .. Format.number(item.cost),
			TextSize = 16,
			BackgroundColor3 = if affordable then UI.Colors.Spark else UI.Colors.Disabled,
			Parent = frame,
		}).Activated
			:Connect(function()
				local ok, message = Remotes.func("BuyHoliday"):InvokeServer(index)
				Toasts.show(message, if ok then "success" else "warn")
				for _, child in page:GetChildren() do
					if child:IsA("Frame") then
						child:Destroy()
					end
				end
				build(page)
			end)
	end
end

local function refresh()
	local key = workspace:GetAttribute("Holiday")
	if type(key) == "string" then
		Market.addTab("Holiday", "🎉 Event", build)
	else
		Market.removeTab("Holiday")
	end
end

function HolidayShop.start()
	workspace:GetAttributeChangedSignal("Holiday"):Connect(refresh)
	refresh()
end

return HolidayShop
