-- The 🏪 Player Market window (PlayerShopService): 🛒 Buy shows everything
-- on sale in the server (and a Cancel on your own); 💰 Sell lists your
-- cosmetics you could sell, with a price box. Opened at the market kiosk at
-- the start of Shop Street.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local UI = require(script.Parent.UI)

local PlayerShop = {}

local window: Frame
local list: ScrollingFrame
local status: TextLabel
local tabs: { [string]: TextButton } = {}
local mode = "Buy"

local function call(action: string, a: any?, b: any?): (any, any)
	local ok, result, message = pcall(function()
		return Remotes.func("PlayerShop"):InvokeServer(action, a, b)
	end)
	if not ok then
		return nil, nil
	end
	return result, message
end

local fill: () -> ()

local function row(order: number, text: string): Frame
	local frame = UI.new("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, 44),
		BackgroundColor3 = UI.Colors.PanelLight,
		Parent = list,
	}, { UI.corner(10), UI.padding(6) })
	UI.label({
		Size = UDim2.new(1, -150, 1, 0),
		Text = text,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = frame,
	})
	return frame
end

local function act(action: string, a: any?, b: any?)
	local _, message = call(action, a, b)
	fill()
	if type(message) == "string" then
		status.Text = message
	end
end

fill = function()
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for key, button in tabs do
		button.BackgroundColor3 = if key == mode then UI.Colors.Good else UI.Colors.PanelLight
	end
	local info = call("info")
	if type(info) ~= "table" then
		return
	end
	status.Text = "You have ⚡"
		.. Format.number(info.sparks)
		.. ". Sellers pay a "
		.. math.floor(info.fee * 100)
		.. "% market fee."
	if mode == "Buy" then
		if #info.listings == 0 then
			row(1, "Nothing on sale right now. Be the first: 💰 Sell!")
		end
		for index, listing in info.listings do
			local frame = row(
				index,
				listing.emoji
					.. " "
					.. listing.name
					.. "  ·  "
					.. listing.seller
					.. (if listing.owned then "  (you have it)" else "")
			)
			local button = UI.button({
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.fromOffset(140, 32),
				Text = if listing.mine
					then "Cancel ⚡" .. Format.number(listing.price)
					else "Buy ⚡" .. Format.number(listing.price),
				TextSize = 14,
				BackgroundColor3 = if listing.mine
					then UI.Colors.Bad
					elseif info.sparks >= listing.price then UI.Colors.Good
					else UI.Colors.Disabled,
				Parent = frame,
			})
			button.Activated:Connect(function()
				act(if listing.mine then "cancel" else "buy", listing.id)
			end)
		end
	else
		if #info.mine == 0 then
			row(1, "You don't have any cosmetics you can sell (Robux and free ones can't be sold).")
		end
		for index, item in info.mine do
			local frame =
				row(index, item.emoji .. " " .. item.name .. "  (shop price ⚡" .. Format.number(item.value) .. ")")
			local box = UI.new("TextBox", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -66, 0.5, 0),
				Size = UDim2.fromOffset(76, 32),
				BackgroundColor3 = UI.Colors.Track,
				TextColor3 = UI.Colors.Text,
				Font = UI.Font,
				TextSize = 14,
				PlaceholderText = "price",
				Text = tostring(math.floor(item.value * 0.8)),
				ClearTextOnFocus = false,
				Parent = frame,
			}, { UI.corner(8) })
			local button = UI.button({
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.fromOffset(60, 32),
				Text = "Sell",
				TextSize = 14,
				BackgroundColor3 = UI.Colors.Warn,
				Parent = frame,
			})
			button.Activated:Connect(function()
				act("sell", item.id, tonumber(box.Text))
			end)
		end
	end
end

function PlayerShop.toggle()
	window.Visible = not window.Visible
	if window.Visible then
		fill()
	end
end

function PlayerShop.start()
	local screen = UI.screen("PlayerShop", 8)
	window = UI.new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.9, 0, 0.82, 0),
		BackgroundColor3 = UI.Colors.Panel,
		Visible = false,
		Parent = screen,
	}, {
		UI.corner(18),
		UI.stroke(UI.Colors.Stroke, 3),
		UI.padding(12),
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(560, 580) }),
	})
	UI.label({
		Size = UDim2.new(1, -60, 0, 34),
		Text = "🏪 Player Market",
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Spark,
		Parent = window,
	})
	UI.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(44, 40),
		Text = "✕",
		TextSize = 22,
		BackgroundColor3 = UI.Colors.Bad,
		Parent = window,
	}).Activated
		:Connect(function()
			window.Visible = false
		end)
	for index, key in { "Buy", "Sell" } do
		local button = UI.button({
			Position = UDim2.fromOffset((index - 1) * 128, 42),
			Size = UDim2.fromOffset(120, 34),
			Text = if key == "Buy" then "🛒 Buy" else "💰 Sell",
			TextSize = 16,
			Parent = window,
		})
		button.Activated:Connect(function()
			mode = key
			fill()
		end)
		tabs[key] = button
	end
	status = UI.label({
		Position = UDim2.fromOffset(0, 82),
		Size = UDim2.new(1, 0, 0, 22),
		Text = "",
		TextSize = 14,
		TextColor3 = UI.Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = window,
	})
	list = UI.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 108),
		Size = UDim2.new(1, 0, 1, -108),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = window,
	}, { UI.list(4) })
end

return PlayerShop
