-- On-screen HUD: stats, day/night timer, action buttons, toasts and the shop.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local state = nil

local FONT = Enum.Font.GothamMedium
local PANEL = Color3.fromRGB(28, 32, 44)
local ACCENT = Color3.fromRGB(214, 180, 116)

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
local coinsLine = statLine(4, Color3.fromRGB(226, 200, 140))
local foodLine = statLine(5, Color3.fromRGB(214, 150, 150))
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
	Position = UDim2.new(0.5, -230, 1, -390),
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

local feedButton = button("Feed", 1, Color3.fromRGB(70, 86, 60), function()
	Remotes.Action:FireServer("Feed")
end)
local foodButton = button("Buy Food", 2, Color3.fromRGB(112, 84, 50), function()
	Remotes.Action:FireServer("BuyFood")
end)
local moltButton = button("Molt!", 3, Color3.fromRGB(86, 64, 100), function()
	Remotes.Action:FireServer("Molt")
end)
local roarButton = button("Titan Roar", 4, Color3.fromRGB(122, 46, 42), function()
	Remotes.Action:FireServer("Roar")
end)
local whistleButton = button("Whistle", 5, Color3.fromRGB(54, 74, 98), function()
	Remotes.Action:FireServer("Whistle")
end)
button("Shop", 6, Color3.fromRGB(140, 110, 56), function()
	shopFrame.Visible = not shopFrame.Visible
end)

-- Shop ------------------------------------------------------------------------

shopFrame = make("Frame", {
	Name = "Shop",
	Visible = false,
	-- Centred on screen whatever its size.
	AnchorPoint = Vector2.new(0.5, 0.5),
	Size = UDim2.new(0.62, 0, 0.72, 0),
	Position = UDim2.fromScale(0.5, 0.5),
	BackgroundColor3 = PANEL,
}, {
	corner(16),
	make("UISizeConstraint", { MaxSize = Vector2.new(720, 620), MinSize = Vector2.new(320, 320) }),
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

-- One scrolling list per tab, with a row of tab buttons above them.
local TAB_NAMES = { "Weapons", "Spells", "Upgrades", "Skins", "Passes", "Boosts" }
local tabLists, tabButtons = {}, {}
local tabBar = make("Frame", {
	Size = UDim2.new(1, -24, 0, 34),
	Position = UDim2.fromOffset(12, 54),
	BackgroundTransparency = 1,
}, {
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }),
})
tabBar.Parent = shopFrame

local function showTab(name: string)
	for tabName, tabList in tabLists do
		tabList.Visible = tabName == name
		tabButtons[tabName].BackgroundColor3 = tabName == name and ACCENT or Color3.fromRGB(60, 66, 84)
	end
end

for _, name in TAB_NAMES do
	local tabList = make("ScrollingFrame", {
		Name = name,
		Size = UDim2.new(1, -24, 1, -104),
		Position = UDim2.fromOffset(12, 96),
		BackgroundTransparency = 1,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 10,
		ScrollBarImageColor3 = ACCENT,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		Visible = false,
	})
	-- Size the scrollable area to the rows so the mouse wheel, touch drag and
	-- the scroll bar can reach every item.
	local layout = make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		tabList.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 12)
	end)
	layout.Parent = tabList
	tabList.Parent = shopFrame
	tabLists[name] = tabList
	local tabButton = make("TextButton", {
		Size = UDim2.new(1 / #TAB_NAMES, -6, 1, 0),
		BackgroundColor3 = Color3.fromRGB(60, 66, 84),
		Font = FONT,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Text = name,
	}, { corner(8), make("UITextSizeConstraint", { MaxTextSize = 16 }) })
	tabButton.Activated:Connect(function()
		showTab(name)
	end)
	tabButton.Parent = tabBar
	tabButtons[name] = tabButton
end
local list = tabLists.Weapons
showTab("Weapons")

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
		BackgroundColor3 = Color3.fromRGB(66, 104, 66),
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
		BackgroundColor3 = Color3.fromRGB(66, 104, 66),
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

-- A generic row: title, description and one action button.
local function actionRow(title: string, description: string)
	order += 1
	local row = make("Frame", { Size = UDim2.new(1, -8, 0, 64), BackgroundColor3 = Color3.fromRGB(44, 50, 66), LayoutOrder = order }, { corner(10) })
	local titleLabel = text({ Size = UDim2.new(1, -140, 0, 26), Position = UDim2.fromOffset(10, 6), Text = title, Parent = row })
	local descriptionLabel = text({
		Size = UDim2.new(1, -140, 0, 24),
		Position = UDim2.fromOffset(10, 34),
		Text = description,
		TextColor3 = Color3.fromRGB(190, 200, 215),
		Parent = row,
	})
	descriptionLabel:FindFirstChildOfClass("UITextSizeConstraint").MaxTextSize = 16
	local actionButton = make("TextButton", {
		Size = UDim2.fromOffset(120, 44),
		Position = UDim2.new(1, -130, 0.5, -22),
		BackgroundColor3 = Color3.fromRGB(66, 104, 66),
		Font = FONT,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "",
	}, { corner(10), make("UITextSizeConstraint", { MaxTextSize = 18 }) })
	actionButton.Parent = row
	row.Parent = list
	return titleLabel, actionButton
end

local weaponButtons, spellRows, upgradeRows = {}, {}, {}

list = tabLists.Weapons
for _, weapon in Config.Weapons do
	local blurb = string.format("%s  •  %d dmg  •  %s", weapon.Description, weapon.Damage, weapon.Kind)
	local _, weaponButton = actionRow(weapon.Name, blurb)
	weaponButton.Activated:Connect(function()
		if not state or weapon.Currency == "Free" or table.find(state.Weapons, weapon.Key) then
			return
		end
		if weapon.Currency == "Coins" then
			Remotes.Action:FireServer("BuyWeapon", weapon.Key)
		elseif weapon.Id ~= 0 then
			MarketplaceService:PromptProductPurchase(player, weapon.Id)
		elseif RunService:IsStudio() then
			toast("Studio test: unlocking " .. weapon.Name .. " for free")
			Remotes.Action:FireServer("StudioGrant", { Kind = "Weapon", Key = weapon.Key })
		else
			toast(weapon.Name .. " is coming soon!")
		end
	end)
	weaponButtons[weapon.Key] = { Button = weaponButton, Weapon = weapon }
end

list = tabLists.Spells
for _, spell in Config.Spells do
	local titleLabel, spellButton =
		actionRow(spell.Name, string.format("[%s] %s  •  %s  •  %d power", spell.Hotkey, spell.Description, spell.Type, spell.PowerCost))
	spellButton.Activated:Connect(function()
		Remotes.Action:FireServer("BuySpell", spell.Key)
	end)
	spellRows[spell.Key] = { Title = titleLabel, Button = spellButton, Spell = spell }
end

list = tabLists.Upgrades
for _, upgrade in Config.Upgrades do
	local titleLabel, upgradeButton = actionRow(upgrade.Name, upgrade.Description)
	upgradeButton.Activated:Connect(function()
		Remotes.Action:FireServer("BuyUpgrade", upgrade.Key)
	end)
	upgradeRows[upgrade.Key] = { Title = titleLabel, Button = upgradeButton, Upgrade = upgrade }
end

list = tabLists.Skins
header("Titan Skins")
for _, skin in Config.Skins do
	skinRow(skin)
end
list = tabLists.Passes
header("Game Passes (forever)")
for _, pass in Config.GamePasses do
	shopRow("Pass", pass)
end
list = tabLists.Boosts
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
	coinsLine.Text = string.format("Gold %s (+%s/s)", Util.formatNumber(state.Coins), Util.formatNumber(state.Income))
	foodLine.Text = string.format("Food %d / %d", state.Food, state.FoodCap)
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
		table.insert(perks, "Shell Lock " .. math.ceil(state.LockedFor) .. "s")
	end
	perksLine.Text = #perks > 0 and table.concat(perks, " • ") or "Night streak: " .. state.NightsStreak

	feedButton.Text = string.format("Feed (%d)", state.Food)
	foodButton.Visible = state.GrowthToNext ~= nil
	foodButton.Text = "Buy Food " .. Util.formatNumber(state.FoodCrateCost) .. "g"
	moltButton.Visible = state.CanMolt
	roarButton.Visible = state.CanRoar and ReplicatedStorage:GetAttribute("Phase") == "Night"
	whistleButton.Visible = table.find(state.Passes, "TitanWhistle") ~= nil

	for key, entry in weaponButtons do
		local weapon = entry.Weapon
		local owned = weapon.Currency == "Free" or table.find(state.Weapons, key) ~= nil
		if owned then
			entry.Button.Text = "Owned"
			entry.Button.BackgroundColor3 = Color3.fromRGB(90, 95, 110)
		elseif weapon.Currency == "Coins" and weapon.MinLevel and (state.Level or 1) < weapon.MinLevel then
			entry.Button.Text = "Level " .. weapon.MinLevel
			entry.Button.BackgroundColor3 = Color3.fromRGB(90, 95, 110)
		elseif weapon.Currency == "Coins" then
			entry.Button.Text = Util.formatNumber(weapon.Price) .. "g"
			entry.Button.BackgroundColor3 = Color3.fromRGB(146, 116, 62)
		else
			entry.Button.Text = "R$ " .. weapon.Price
			entry.Button.BackgroundColor3 = Color3.fromRGB(66, 104, 66)
		end
	end
	for key, entry in spellRows do
		local level = state.Spells[key] or 0
		local cost = state.SpellCosts[key] or -1
		entry.Title.Text = string.format("%s  (Lv %d/%d)", entry.Spell.Name, level, Config.SpellMaxLevel)
		if cost < 0 then
			entry.Button.Text = "Max level"
			entry.Button.BackgroundColor3 = Color3.fromRGB(90, 95, 110)
		else
			entry.Button.Text = (level == 0 and "Unlock " or "Upgrade ") .. Util.formatNumber(cost) .. "g"
			entry.Button.BackgroundColor3 = state.Coins >= cost and Color3.fromRGB(146, 116, 62) or Color3.fromRGB(96, 84, 62)
		end
	end
	for key, entry in upgradeRows do
		local level = state.Upgrades[key] or 0
		local cost = state.UpgradeCosts[key] or -1
		entry.Title.Text = string.format("%s  (Lv %d/%d)", entry.Upgrade.Name, level, entry.Upgrade.MaxLevel)
		if cost < 0 then
			entry.Button.Text = "Max level"
			entry.Button.BackgroundColor3 = Color3.fromRGB(90, 95, 110)
		else
			entry.Button.Text = Util.formatNumber(cost) .. "g"
			entry.Button.BackgroundColor3 = state.Coins >= cost and Color3.fromRGB(146, 116, 62) or Color3.fromRGB(96, 84, 62)
		end
	end

	for key, entry in skinButtons do
		local skinButton, skin = entry.Button, entry.Skin
		if state.EquippedSkin == key then
			skinButton.Text = "Equipped"
			skinButton.BackgroundColor3 = Color3.fromRGB(90, 95, 110)
		elseif skinOwned(key) then
			skinButton.Text = "Equip"
			skinButton.BackgroundColor3 = Color3.fromRGB(58, 84, 112)
		elseif skin.Currency == "Coins" then
			skinButton.Text = Util.formatNumber(skin.Price) .. "g"
			skinButton.BackgroundColor3 = Color3.fromRGB(146, 116, 62)
		else
			skinButton.Text = "R$ " .. skin.Price
			skinButton.BackgroundColor3 = Color3.fromRGB(66, 104, 66)
		end
	end
	for key, entry in passButtons do
		local owned = table.find(state.Passes, key) ~= nil
		entry.Button.Text = owned and "Owned" or ("R$ " .. entry.Item.Price)
		entry.Button.BackgroundColor3 = owned and Color3.fromRGB(90, 95, 110) or Color3.fromRGB(66, 104, 66)
	end
end

Remotes.State.OnClientEvent:Connect(function(newState)
	state = newState
	refresh()
end)

Remotes.Notify.OnClientEvent:Connect(toast)

UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.P then
		shopFrame.Visible = not shopFrame.Visible
	end
end)

-- Walking into a base building opens its shop tab.
Remotes.Ui.OnClientEvent:Connect(function(message)
	if type(message) == "table" and tabLists[message.Open] then
		shopFrame.Visible = true
		showTab(message.Open)
	end
end)

RunService.RenderStepped:Connect(function()
	local phase = ReplicatedStorage:GetAttribute("Phase") or "Day"
	local left = (ReplicatedStorage:GetAttribute("PhaseEndsAt") or 0) - workspace:GetServerTimeNow()
	local storm = (ReplicatedStorage:GetAttribute("StormUntil") or 0) > workspace:GetServerTimeNow()
	if phase == "Night" then
		local boss = ReplicatedStorage:GetAttribute("BossNight") and " • Storm King!" or ""
		phaseLabel.Text = string.format("Nightfall %d%s • %s", ReplicatedStorage:GetAttribute("NightNumber") or 0, boss, Util.formatTime(left))
		phaseLabel.TextColor3 = Color3.fromRGB(190, 190, 255)
	else
		local biome = ReplicatedStorage:GetAttribute("Biome") or "Fern Valley"
		phaseLabel.Text = string.format("%sMigration • %s • %s", storm and "Storm • " or "", biome, Util.formatTime(left))
		phaseLabel.TextColor3 = storm and Color3.fromRGB(220, 180, 255) or Color3.fromRGB(255, 235, 160)
	end
	roarButton.Visible = state ~= nil and state.CanRoar and phase == "Night"
end)

gui.Parent = player:WaitForChild("PlayerGui")
