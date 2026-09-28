-- The 🏪 Kit Market window: the restocking Kit Shop and the Kit Crates, plus
-- the crate-opening animation (shake, flash, reveal).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Format)
local MarketData = require(Shared.MarketData)
local Products = require(Shared.Products)
local Remotes = require(Shared.Remotes)
local StormData = require(Shared.StormData)

local Sfx = require(script.Parent.Sfx)
local Toasts = require(script.Parent.Toasts)
local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local Market = {}

local window: Frame
local pages: { [string]: ScrollingFrame } = {}
local tabs: { [string]: TextButton } = {}
local timerLabel: TextLabel
local currentTab = "Market"
local busy = false
local extraTabs: { [string]: (ScrollingFrame) -> () } = {}

local function invoke(remote: string, arg: any)
	if busy then
		return
	end
	busy = true
	local ok, message = Remotes.func(remote):InvokeServer(arg)
	busy = false
	if not ok or remote ~= "OpenCrate" then
		Toasts.show(message, if ok then "success" else "warn")
	end
end

local function clear(page: Instance)
	for _, child in page:GetChildren() do
		if not child:IsA("UIGridLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local function card(page: Instance, order: number, height: number?): Frame
	return UI.new("Frame", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(180, height or 170),
		BackgroundColor3 = UI.Colors.PanelLight,
		Parent = page,
	}, { UI.corner(12), UI.padding(8) })
end

local function buildMarket()
	local page = pages.Market
	clear(page)
	local data = Remotes.func("GetMarket"):InvokeServer()
	if type(data) ~= "table" then
		return
	end
	for index, item in data.items do
		local def = StormData.get(item.id)
		if not def then
			continue
		end
		local rarity = StormData.rarityOf(def)
		local frame = card(page, index)
		UI.stroke(rarity.color, 2).Parent = frame
		UI.label({
			Size = UDim2.new(1, 0, 0, 22),
			Text = rarity.name,
			TextSize = 14,
			TextColor3 = UI.ink(rarity.color),
			Parent = frame,
		})
		local name = UI.label({
			Position = UDim2.fromOffset(0, 24),
			Size = UDim2.new(1, 0, 0, 40),
			Text = StormData.displayName({ id = item.id, mut = item.mut }),
			TextScaled = true,
			TextWrapped = true,
			Parent = frame,
		})
		UI.new("UITextSizeConstraint", { MaxTextSize = 18, Parent = name })
		UI.label({
			Position = UDim2.fromOffset(0, 66),
			Size = UDim2.new(1, 0, 0, 20),
			Text = "Shift: " .. tostring(item.power),
			TextSize = 14,
			TextColor3 = UI.Colors.Muted,
			Parent = frame,
		})
		UI.label({
			Position = UDim2.fromOffset(0, 88),
			Size = UDim2.new(1, 0, 0, 20),
			Text = if item.stock > 0 then "📦 " .. item.stock .. " left" else "❌ Sold out",
			TextSize = 14,
			TextColor3 = if item.stock > 0 then UI.Colors.Text else UI.Colors.Bad,
			Parent = frame,
		})
		local canBuy = item.stock > 0
		local button = UI.button({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.new(1, 0, 0, 38),
			Text = if canBuy then "⚡ " .. Format.number(item.price) else "Sold out",
			TextSize = 16,
			BackgroundColor3 = if canBuy then UI.Colors.Spark else UI.Colors.Disabled,
			AutoButtonColor = canBuy,
			Parent = frame,
		})
		if canBuy then
			button.Activated:Connect(function()
				invoke("BuyMarket", index)
			end)
		end
	end
end

local function buyGoldenCrate()
	local product = Products.get("GoldenKitCrate")
	if not product then
		return
	end
	if product.id ~= 0 then
		MarketplaceService:PromptProductPurchase(player, product.id)
	elseif RunService:IsStudio() then
		Remotes.event("DevPurchase"):FireServer(product.key)
	else
		Toasts.show("The Golden Crate is coming soon!", "info")
	end
end

local function buildCrates()
	local page = pages.Crates
	clear(page)
	for index, crate in MarketData.Crates do
		local frame = card(page, index, 230)
		UI.stroke(crate.color, 2).Parent = frame
		UI.label({ Size = UDim2.new(1, 0, 0, 44), Text = crate.emoji, TextSize = 38, Parent = frame })
		UI.label({
			Position = UDim2.fromOffset(0, 44),
			Size = UDim2.new(1, 0, 0, 22),
			Text = crate.name,
			TextSize = 18,
			TextColor3 = UI.ink(crate.color),
			Parent = frame,
		})
		local lines = {}
		for rarity, chance in crate.odds do
			if chance > 0 then
				table.insert(lines, StormData.Rarities[rarity].name .. " " .. chance .. "%")
			end
		end
		table.insert(
			lines,
			if crate.mutationChance >= 1
				then "Always shiny!"
				else "Shiny " .. math.floor(crate.mutationChance * 100) .. "%"
		)
		UI.label({
			Position = UDim2.fromOffset(0, 70),
			Size = UDim2.new(1, 0, 0, 100),
			Text = table.concat(lines, "\n"),
			TextSize = 13,
			TextColor3 = UI.Colors.Muted,
			TextYAlignment = Enum.TextYAlignment.Top,
			Parent = frame,
		})
		local robux = crate.cost <= 0
		local product = Products.get("GoldenKitCrate")
		local button = UI.button({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.new(1, 0, 0, 38),
			Text = if robux
				then "R$ " .. (if product then product.price else "?")
				else "⚡ " .. Format.number(crate.cost),
			TextSize = 16,
			BackgroundColor3 = if robux then UI.Colors.Robux else UI.Colors.Spark,
			Parent = frame,
		})
		button.Activated:Connect(function()
			if robux then
				buyGoldenCrate()
			else
				invoke("OpenCrate", crate.key)
			end
		end)
	end
end

-- The opening: the crate shakes harder and harder, flashes, then shows the kit.
local function playOpening(result: any)
	window.Visible = false
	local screen = UI.screen("CrateOpening", 11)
	local dim = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		Parent = screen,
	})
	local crate = UI.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(200, 200),
		Text = tostring(result.crateEmoji or "🎁"),
		TextSize = 150,
		Parent = dim,
	})
	for i = 1, 10 do
		local angle = (if i % 2 == 0 then 1 else -1) * (4 + i * 1.8)
		local tween = TweenService:Create(crate, TweenInfo.new(0.09 + (10 - i) * 0.012), { Rotation = angle })
		tween:Play()
		tween.Completed:Wait()
		if i % 3 == 0 then
			Sfx.play("pop", 0.8 + i * 0.05)
		end
	end
	crate.Visible = false
	local flash = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = screen,
	})
	TweenService:Create(flash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
	Sfx.play("chime")

	local color = if typeof(result.color) == "Color3" then result.color else UI.Colors.Stroke
	local reveal = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.new(0.9, 0, 0, 220),
		BackgroundColor3 = UI.Colors.Panel,
		Parent = dim,
	}, {
		UI.corner(18),
		UI.stroke(color, 4),
		UI.padding(12),
		UI.list(6),
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(380, 220) }),
	})
	local scale = UI.new("UIScale", { Scale = 0.2, Parent = reveal })
	UI.label({
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 40),
		Text = "✨ " .. string.upper(tostring(result.rarity)) .. "! ✨",
		TextSize = 32,
		TextColor3 = UI.ink(color),
		Parent = reveal,
	})
	UI.label({
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 34),
		Text = tostring(result.name),
		TextSize = 26,
		Parent = reveal,
	})
	if result.mutation then
		UI.label({
			LayoutOrder = 3,
			Size = UDim2.new(1, 0, 0, 24),
			Text = "Shiny: " .. tostring(result.mutation),
			TextSize = 18,
			TextColor3 = UI.Colors.Spark,
			Parent = reveal,
		})
	end
	UI.label({
		LayoutOrder = 4,
		Size = UDim2.new(1, 0, 0, 20),
		Text = "Shift power: " .. tostring(result.power) .. "  ·  Pick it in 🌪️ Kits!",
		TextSize = 15,
		TextColor3 = UI.Colors.Muted,
		Parent = reveal,
	})
	UI.button({
		LayoutOrder = 5,
		Size = UDim2.fromOffset(160, 42),
		Text = "Nice!",
		TextSize = 20,
		BackgroundColor3 = UI.Colors.Good,
		Parent = reveal,
	}).Activated
		:Connect(function()
			screen:Destroy()
			window.Visible = true
		end)
	TweenService:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
end

local function showTab(name: string)
	currentTab = name
	for key, page in pages do
		page.Visible = key == name
		tabs[key].BackgroundColor3 = if key == name then UI.Colors.Rare else UI.Colors.PanelLight
	end
	if name == "Market" then
		buildMarket()
	elseif name == "Crates" then
		buildCrates()
	elseif extraTabs[name] then
		clear(pages[name])
		extraTabs[name](pages[name])
	end
end

function Market.toggle()
	window.Visible = not window.Visible
	if window.Visible then
		showTab(currentTab)
	end
end

-- Lets other features (the holiday event shop) add a tab.
function Market.addTab(key: string, title: string, build: (ScrollingFrame) -> ())
	extraTabs[key] = build
	local tabRow = window:FindFirstChild("Tabs")
	if not tabRow or tabs[key] then
		return
	end
	local button = UI.button({
		LayoutOrder = 10,
		Size = UDim2.fromOffset(170, 38),
		Text = title,
		TextSize = 16,
		Parent = tabRow,
	})
	button.Activated:Connect(function()
		showTab(key)
	end)
	tabs[key] = button
	pages[key] = UI.new("ScrollingFrame", {
		Name = key,
		Position = UDim2.fromOffset(0, 118),
		Size = UDim2.new(1, 0, 1, -118),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Visible = false,
		Parent = window,
	}, {
		UI.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(180, 200),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		UI.padding(4),
	})
end

-- Takes a tab away again (when the holiday ends).
function Market.removeTab(key: string)
	extraTabs[key] = nil
	if tabs[key] then
		tabs[key]:Destroy()
		tabs[key] = nil
	end
	if pages[key] then
		pages[key]:Destroy()
		pages[key] = nil
	end
	if currentTab == key then
		currentTab = "Market"
	end
end

function Market.start()
	local screen = UI.screen("Market", 6)
	window = UI.new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.94, 0.84),
		BackgroundColor3 = UI.Colors.Panel,
		Visible = false,
		Parent = screen,
	}, {
		UI.corner(18),
		UI.stroke(UI.Colors.Stroke, 3),
		UI.padding(14),
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(820, 520) }),
	})
	UI.label({
		Size = UDim2.new(1, -60, 0, 32),
		Text = "🏪 Kit Market",
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = window,
	})
	UI.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(44, 34),
		Text = "✕",
		TextSize = 22,
		BackgroundColor3 = UI.Colors.Bad,
		Parent = window,
	}).Activated
		:Connect(function()
			window.Visible = false
		end)
	local tabRow = UI.new("Frame", {
		Name = "Tabs",
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundTransparency = 1,
		Parent = window,
	}, { UI.list(8, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left) })
	timerLabel = UI.label({
		Position = UDim2.fromOffset(0, 84),
		Size = UDim2.new(1, 0, 0, 26),
		TextSize = 16,
		TextColor3 = UI.Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = window,
	})
	for order, entry in { { "Market", "🏪 Kit Shop" }, { "Crates", "🎁 Kit Crates" } } do
		local key = entry[1]
		local button = UI.button({
			LayoutOrder = order,
			Size = UDim2.fromOffset(170, 38),
			Text = entry[2],
			TextSize = 16,
			Parent = tabRow,
		})
		button.Activated:Connect(function()
			showTab(key)
		end)
		tabs[key] = button
		pages[key] = UI.new("ScrollingFrame", {
			Name = key,
			Position = UDim2.fromOffset(0, 118),
			Size = UDim2.new(1, 0, 1, -118),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			Visible = false,
			Parent = window,
		}, {
			UI.new("UIGridLayout", {
				CellSize = UDim2.fromOffset(180, if key == "Crates" then 230 else 170),
				CellPadding = UDim2.fromOffset(8, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			UI.padding(4),
		})
	end

	workspace:GetAttributeChangedSignal("MarketVersion"):Connect(function()
		if window.Visible and currentTab == "Market" then
			buildMarket()
		end
	end)
	Remotes.event("CrateOpened").OnClientEvent:Connect(function(result)
		if type(result) == "table" then
			task.spawn(playOpening, result)
		end
	end)
	task.spawn(function()
		while true do
			local restockAt = workspace:GetAttribute("MarketRestockAt")
			if type(restockAt) == "number" then
				local left = restockAt - workspace:GetServerTimeNow()
				timerLabel.Text = if currentTab == "Market"
					then "🔄 Restocks in " .. Format.time(left) .. "  ·  Stock is shared with everyone in the server!"
					elseif currentTab == "Crates" then "🎁 Open a random kit! Odds are shown on each crate."
					else ""
			end
			task.wait(0.5)
		end
	end)
end

return Market
