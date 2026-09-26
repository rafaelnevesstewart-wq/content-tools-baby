-- On-screen HUD: stats, day/night timer, action buttons, toasts and the shop.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local state = nil

local FONT = Enum.Font.FredokaOne
local PANEL = Color3.fromRGB(28, 32, 44)
local ACCENT = Color3.fromRGB(255, 196, 70)

local function make(className: string, props, children)
	local instance = Instance.new(className)
	for key, value in props or {} do
		instance[key] = value
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	return instance
end

local function corner(radius: number)
	return make("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function text(props)
	local defaults = {
		BackgroundTransparency = 1,
		Font = FONT,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	for key, value in props do
		defaults[key] = value
	end
	return make("TextLabel", defaults, { make("UITextSizeConstraint", { MaxTextSize = 22 }) })
end

local gui = make("ScreenGui", { Name = "Hud", ResetOnSpawn = false, IgnoreGuiInset = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })

-- Stats panel -----------------------------------------------------------------

local stats = make("Frame", {
	Name = "Stats",
	Size = UDim2.fromOffset(250, 214),
	Position = UDim2.fromOffset(12, 12),
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.15,
}, {
	corner(12),
	make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }),
	make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
})
stats.Parent = gui

local function statLine(order: number, color: Color3?)
	return text({ Size = UDim2.new(1, 0, 0, 20), LayoutOrder = order, TextColor3 = color or Color3.new(1, 1, 1), Parent = stats })
end

local function bar(order: number, color: Color3)
	local back = make("Frame", { Size = UDim2.new(1, 0, 0, 10), BackgroundColor3 = Color3.fromRGB(50, 55, 70), LayoutOrder = order }, { corner(5) })
	local fill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = color }, { corner(5) })
	fill.Parent = back
	back.Parent = stats
	return fill
end

local titanLine = statLine(1, ACCENT)
local stageLine = statLine(2)
local growthFill = bar(3, Color3.fromRGB(110, 220, 110))
local coinsLine = statLine(4, Color3.fromRGB(255, 225, 110))
local foodLine = statLine(5, Color3.fromRGB(255, 150, 170))
local slotsLine = statLine(6)
local healthFill = bar(7, Color3.fromRGB(230, 80, 80))
local perksLine = statLine(8, Color3.fromRGB(170, 210, 255))

-- Phase pill ------------------------------------------------------------------

local phaseLabel = text({
	Size = UDim2.fromOffset(360, 36),
	Position = UDim2.new(0.5, -180, 0, 10),
	BackgroundTransparency = 0.15,
	BackgroundColor3 = PANEL,
	TextXAlignment = Enum.TextXAlignment.Center,
	Parent = gui,
})
corner(18).Parent = phaseLabel

-- Toasts ----------------------------------------------------------------------

local toastHolder = make("Frame", {
	Size = UDim2.new(0, 460, 0, 200),
	Position = UDim2.new(0.5, -230, 1, -290),
	BackgroundTransparency = 1,
}, {
	make(
		"UIListLayout",
		{ Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Center }
	),
})
toastHolder.Parent = gui

local function toast(message: string)
	local label = text({
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 0.2,
		BackgroundColor3 = PANEL,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = message,
		Parent = toastHolder,
	})
	corner(10).Parent = label
	make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }).Parent = label
	task.delay(4, function()
		local tween = TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1, BackgroundTransparency = 1 })
		tween:Play()
		tween.Completed:Wait()
		label:Destroy()
	end)
	local children = toastHolder:GetChildren()
	if #children > 7 then
		for _, child in children do
			if child:IsA("TextLabel") then
				child:Destroy()
				break
			end
		end
	end
end

-- Buttons ---------------------------------------------------------------------

local buttonBar = make("Frame", {
	Size = UDim2.fromOffset(150, 330),
	Position = UDim2.new(1, -162, 1, -350),
	BackgroundTransparency = 1,
}, {
	make("UIListLayout", { Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Bottom, SortOrder = Enum.SortOrder.LayoutOrder }),
})
buttonBar.Parent = gui

local function button(name: string, order: number, color: Color3, onClick)
	local b = make("TextButton", {
		Name = name,
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundColor3 = color,
		Font = FONT,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Text = name,
		LayoutOrder = order,
		AutoButtonColor = true,
	}, {
		corner(12),
		make("UITextSizeConstraint", { MaxTextSize = 22 }),
		make("UIStroke", { Thickness = 2, Color = Color3.fromRGB(20, 20, 20), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	b.Activated:Connect(onClick)
	b.Parent = buttonBar
	return b
end

local shopFrame -- forward declaration

local feedButton = button("Feed", 1, Color3.fromRGB(80, 170, 90), function()
	Remotes.Action:FireServer("Feed")
end)
local foodButton = button("Buy Food", 2, Color3.fromRGB(200, 140, 60), function()
	Remotes.Action:FireServer("BuyFood")
end)
local moltButton = button("Molt!", 3, Color3.fromRGB(170, 90, 220), function()
	Remotes.Action:FireServer("Molt")
end)
local roarButton = button("Titan Roar", 4, Color3.fromRGB(220, 70, 70), function()
	Remotes.Action:FireServer("Roar")
end)
local whistleButton = button("Whistle", 5, Color3.fromRGB(70, 150, 220), function()
	Remotes.Action:FireServer("Whistle")
end)
button("Shop", 6, Color3.fromRGB(240, 180, 40), function()
	shopFrame.Visible = not shopFrame.Visible
end)

-- Shop ------------------------------------------------------------------------

shopFrame = make("Frame", {
	Name = "Shop",
	Visible = false,
	Size = UDim2.new(0.6, 0, 0.7, 0),
	Position = UDim2.new(0.2, 0, 0.15, 0),
	BackgroundColor3 = PANEL,
}, {
	corner(16),
	make("UISizeConstraint", { MaxSize = Vector2.new(620, 560), MinSize = Vector2.new(300, 300) }),
})
shopFrame.Parent = gui

text({
	Size = UDim2.new(1, -70, 0, 40),
	Position = UDim2.fromOffset(16, 8),
	Text = "Titan Shop",
	TextColor3 = ACCENT,
	Parent = shopFrame,
})
local close = make("TextButton", {
	Size = UDim2.fromOffset(40, 40),
	Position = UDim2.new(1, -48, 0, 8),
	Text = "X",
	Font = FONT,
	TextScaled = true,
	BackgroundColor3 = Color3.fromRGB(200, 70, 70),
	TextColor3 = Color3.new(1, 1, 1),
}, { corner(10) })
close.Activated:Connect(function()
	shopFrame.Visible = false
end)
close.Parent = shopFrame

local list = make("ScrollingFrame", {
	Size = UDim2.new(1, -24, 1, -64),
	Position = UDim2.fromOffset(12, 56),
	BackgroundTransparency = 1,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	ScrollBarThickness = 6,
}, {
	make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})
list.Parent = shopFrame

local passButtons = {}

local function buy(kind: string, item)
	if item.Id ~= 0 then
		if kind == "Pass" then
			MarketplaceService:PromptGamePassPurchase(player, item.Id)
		else
			MarketplaceService:PromptProductPurchase(player, item.Id)
		end
	elseif RunService:IsStudio() then
		toast("Studio test: granting " .. item.Name .. " for free")
		Remotes.Action:FireServer("StudioGrant", { Kind = kind, Key = item.Key })
	else
		toast(item.Name .. " is coming soon!")
	end
end

local order = 0
local function header(title: string)
	order += 1
	text({ Size = UDim2.new(1, 0, 0, 28), Text = title, TextColor3 = ACCENT, LayoutOrder = order, Parent = list })
end

local function shopRow(kind: string, item)
	order += 1
	local row = make("Frame", { Size = UDim2.new(1, -8, 0, 64), BackgroundColor3 = Color3.fromRGB(44, 50, 66), LayoutOrder = order }, { corner(10) })
	text({ Size = UDim2.new(1, -130, 0, 26), Position = UDim2.fromOffset(10, 6), Text = item.Name, Parent = row })
	local description = text({
		Size = UDim2.new(1, -130, 0, 24),
		Position = UDim2.fromOffset(10, 34),
		Text = item.Description,
		TextColor3 = Color3.fromRGB(190, 200, 215),
		Parent = row,
	})
	description:FindFirstChildOfClass("UITextSizeConstraint").MaxTextSize = 16
	local priceButton = make("TextButton", {
		Size = UDim2.fromOffset(110, 44),
		Position = UDim2.new(1, -120, 0.5, -22),
		BackgroundColor3 = Color3.fromRGB(80, 190, 90),
		Font = FONT,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "R$ " .. item.Price,
	}, { corner(10), make("UITextSizeConstraint", { MaxTextSize = 20 }) })
	priceButton.Activated:Connect(function()
		if kind == "Pass" and state and table.find(state.Passes, item.Key) then
			return
		end
		buy(kind, item)
	end)
	priceButton.Parent = row
	row.Parent = list
	if kind == "Pass" then
		passButtons[item.Key] = { Button = priceButton, Item = item }
	end
end

local skinButtons = {}

local function skinOwned(key: string): boolean
	return key == "Classic" or (state ~= nil and table.find(state.OwnedSkins or {}, key) ~= nil)
end

local function skinRow(skin)
	order += 1
	local row = make("Frame", { Size = UDim2.new(1, -8, 0, 64), BackgroundColor3 = Color3.fromRGB(44, 50, 66), LayoutOrder = order }, { corner(10) })
	local swatch = make("Frame", {
		Size = UDim2.fromOffset(44, 44),
		Position = UDim2.fromOffset(10, 10),
		BackgroundColor3 = skin.ShellColor or Color3.fromRGB(150, 104, 62),
	}, {
		make("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		make("UIStroke", { Thickness = 3, Color = skin.AccentColor or Color3.fromRGB(240, 200, 110) }),
	})
	swatch.Parent = row
	text({ Size = UDim2.new(1, -190, 0, 26), Position = UDim2.fromOffset(64, 6), Text = skin.Name, Parent = row })
	local description = text({
		Size = UDim2.new(1, -190, 0, 24),
		Position = UDim2.fromOffset(64, 34),
		Text = skin.Description,
		TextColor3 = Color3.fromRGB(190, 200, 215),
		Parent = row,
	})
	description:FindFirstChildOfClass("UITextSizeConstraint").MaxTextSize = 16
	local skinButton = make("TextButton", {
		Size = UDim2.fromOffset(110, 44),
		Position = UDim2.new(1, -120, 0.5, -22),
		BackgroundColor3 = Color3.fromRGB(80, 190, 90),
		Font = FONT,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "",
	}, { corner(10), make("UITextSizeConstraint", { MaxTextSize = 20 }) })
	skinButton.Activated:Connect(function()
		if not state then
			return
		end
		if skinOwned(skin.Key) then
			Remotes.Action:FireServer("EquipSkin", skin.Key)
		elseif skin.Currency == "Coins" then
			Remotes.Action:FireServer("BuySkin", skin.Key)
		elseif skin.Currency == "Robux" then
			if skin.Id ~= 0 then
				MarketplaceService:PromptProductPurchase(player, skin.Id)
			elseif RunService:IsStudio() then
				toast("Studio test: unlocking " .. skin.Name .. " for free")
				Remotes.Action:FireServer("StudioGrant", { Kind = "Skin", Key = skin.Key })
			else
				toast(skin.Name .. " is coming soon!")
			end
		end
	end)
	skinButton.Parent = row
	row.Parent = list
	skinButtons[skin.Key] = { Button = skinButton, Skin = skin }
end

header("Titan Skins")
for _, skin in Config.Skins do
	skinRow(skin)
end
header("Game Passes (forever)")
for _, pass in Config.GamePasses do
	shopRow("Pass", pass)
end
header("Boosts and Coins")
for _, product in Config.DevProducts do
	shopRow("Product", product)
end

-- Updating --------------------------------------------------------------------

local function refresh()
	if not state then
		return
	end
	local species = (Config.Species[state.Species] or Config.Species.Shellback).DisplayName
	local mutation = state.TitanMutation ~= "Normal" and (state.TitanMutation .. " ") or ""
	titanLine.Text = string.format("%s%s", mutation, species)
	if state.GrowthToNext then
		stageLine.Text = string.format("%s  (%s / %s)", state.StageName, Util.formatNumber(state.Growth), Util.formatNumber(state.GrowthToNext))
		growthFill.Size = UDim2.fromScale(math.clamp(state.Growth / state.GrowthToNext, 0, 1), 1)
	else
		stageLine.Text = state.StageName .. "  (fully grown!)"
		growthFill.Size = UDim2.fromScale(1, 1)
	end
	coinsLine.Text = string.format("🪙 %s  (+%s/s)", Util.formatNumber(state.Coins), Util.formatNumber(state.Income))
	foodLine.Text = string.format("🍓 Food %d / %d", state.Food, state.FoodCap)
	slotsLine.Text = string.format("Riders %d/%d   Eggs %d/%d", state.Riders, state.RiderSlots, state.Eggs, state.EggSlots)
	healthFill.Size = UDim2.fromScale(math.clamp(state.Health / math.max(state.MaxHealth, 1), 0, 1), 1)

	local perks = {}
	if state.Molts > 0 then
		table.insert(perks, "Molt " .. state.Molts)
	end
	if state.HerdBond then
		table.insert(perks, "Herd Bond")
	end
	if state.Resonance then
		table.insert(perks, "Resonance")
	end
	if state.Weathered then
		table.insert(perks, "Weathered")
	end
	if state.GrowthSnackLeft > 0 then
		table.insert(perks, "Snack " .. Util.formatTime(state.GrowthSnackLeft))
	end
	if state.LockedFor > 0 then
		table.insert(perks, "🔒 " .. math.ceil(state.LockedFor) .. "s")
	end
	perksLine.Text = #perks > 0 and table.concat(perks, " • ") or "Night streak: " .. state.NightsStreak

	feedButton.Text = string.format("Feed (%d)", state.Food)
	foodButton.Visible = state.GrowthToNext ~= nil
	foodButton.Text = "Buy Food 🪙" .. Util.formatNumber(state.FoodCrateCost)
	moltButton.Visible = state.CanMolt
	roarButton.Visible = state.CanRoar and ReplicatedStorage:GetAttribute("Phase") == "Night"
	whistleButton.Visible = table.find(state.Passes, "TitanWhistle") ~= nil

	for key, entry in skinButtons do
		local skinButton, skin = entry.Button, entry.Skin
		if state.EquippedSkin == key then
			skinButton.Text = "Equipped"
			skinButton.BackgroundColor3 = Color3.fromRGB(90, 95, 110)
		elseif skinOwned(key) then
			skinButton.Text = "Equip"
			skinButton.BackgroundColor3 = Color3.fromRGB(70, 140, 220)
		elseif skin.Currency == "Coins" then
			skinButton.Text = "🪙 " .. Util.formatNumber(skin.Price)
			skinButton.BackgroundColor3 = Color3.fromRGB(210, 160, 50)
		else
			skinButton.Text = "R$ " .. skin.Price
			skinButton.BackgroundColor3 = Color3.fromRGB(80, 190, 90)
		end
	end
	for key, entry in passButtons do
		local owned = table.find(state.Passes, key) ~= nil
		entry.Button.Text = owned and "Owned" or ("R$ " .. entry.Item.Price)
		entry.Button.BackgroundColor3 = owned and Color3.fromRGB(90, 95, 110) or Color3.fromRGB(80, 190, 90)
	end
end

Remotes.State.OnClientEvent:Connect(function(newState)
	state = newState
	refresh()
end)

Remotes.Notify.OnClientEvent:Connect(toast)

RunService.RenderStepped:Connect(function()
	local phase = ReplicatedStorage:GetAttribute("Phase") or "Day"
	local left = (ReplicatedStorage:GetAttribute("PhaseEndsAt") or 0) - workspace:GetServerTimeNow()
	local storm = (ReplicatedStorage:GetAttribute("StormUntil") or 0) > workspace:GetServerTimeNow()
	if phase == "Night" then
		local boss = ReplicatedStorage:GetAttribute("BossNight") and " • Storm King!" or ""
		phaseLabel.Text = string.format("🌙 Nightfall %d%s • %s", ReplicatedStorage:GetAttribute("NightNumber") or 0, boss, Util.formatTime(left))
		phaseLabel.TextColor3 = Color3.fromRGB(190, 190, 255)
	else
		local biome = ReplicatedStorage:GetAttribute("Biome") or "Fern Valley"
		phaseLabel.Text = string.format("%s Migration • %s • %s", storm and "⚡" or "☀", biome, Util.formatTime(left))
		phaseLabel.TextColor3 = storm and Color3.fromRGB(220, 180, 255) or Color3.fromRGB(255, 235, 160)
	end
	roarButton.Visible = state ~= nil and state.CanRoar and phase == "Night"
end)

gui.Parent = player:WaitForChild("PlayerGui")
