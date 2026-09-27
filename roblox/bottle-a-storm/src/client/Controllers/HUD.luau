-- Always-on screen info, kept tidy:
--   top:  one Sparks bar, then a row of small chips (weather, Mega-Storm, lock)
--         and the boss HP bar during a raid
--   left: an icon bar (Shop, Robux, Trade, Climate, Season, Emergency Lock)
--   bottom: the "carrying a stolen storm" banner

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Format)
local Products = require(Shared.Products)
local Remotes = require(Shared.Remotes)
local RaidData = require(Shared.RaidData)
local WeatherEvents = require(Shared.WeatherEvents)

local Climate = require(script.Parent.Climate)
local Battle = require(script.Parent.Battle)
local Rewards = require(script.Parent.Rewards)
local Season = require(script.Parent.Season)
local Shop = require(script.Parent.Shop)
local Toasts = require(script.Parent.Toasts)
local Trade = require(script.Parent.Trade)
local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local HUD = {}

local sparksLabel: TextLabel
local incomeLabel: TextLabel
local unclaimedChip: TextLabel
local weatherChip: TextLabel
local raidChip: TextLabel
local lockChip: TextLabel
local boostChip: TextLabel
local carryBanner: TextLabel
local bossBar: Frame
local bossTitle: TextLabel
local bossTime: TextLabel
local bossFill: Frame
local bossHpText: TextLabel
local bossDamage: TextLabel

-- A small rounded label with an outline, sized to its text.
local function chip(parent: Instance, order: number, height: number, textSize: number): TextLabel
	local label = UI.label({
		LayoutOrder = order,
		Size = UDim2.fromOffset(0, height),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.05,
		TextSize = textSize,
		Parent = parent,
	})
	UI.corner(height // 2).Parent = label
	UI.stroke(UI.Colors.Stroke, 2).Parent = label
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = label })
	return label
end

local function weatherText(now: number): string
	local current = WeatherEvents.get(workspace:GetAttribute("WeatherEvent"))
	if current then
		return current.emoji .. " " .. Format.time((workspace:GetAttribute("WeatherEndsAt") or now) - now)
	end
	local nextEvent = WeatherEvents.get(workspace:GetAttribute("NextWeather"))
	if nextEvent then
		return "📺 "
			.. nextEvent.emoji
			.. " in "
			.. Format.time((workspace:GetAttribute("NextWeatherAt") or now) - now)
	end
	return "☀️"
end

local function lockText(now: number): (string, Color3)
	local plot = UI.myPlot()
	if not plot then
		return "🏝️ ...", UI.Colors.Muted
	end
	local lockedUntil = plot:GetAttribute("LockedUntil") or 0
	local readyAt = plot:GetAttribute("LockReadyAt") or 0
	if lockedUntil > now then
		return "🔒 " .. Format.time(lockedUntil - now), Color3.fromRGB(50, 160, 95)
	elseif readyAt > now then
		return "🔓 " .. Format.time(readyAt - now), UI.Colors.Warn
	end
	return "🔓 Open", UI.Colors.Bad
end

-- The Mega-Storm HP bar, shown under the chips during a raid.
local function buildBossBar(parent: Instance)
	bossBar = UI.new("Frame", {
		Name = "BossBar",
		LayoutOrder = 3,
		Size = UDim2.fromOffset(360, 72),
		BackgroundColor3 = Color3.fromRGB(255, 232, 238),
		Visible = false,
		Parent = parent,
	}, { UI.corner(16), UI.stroke(UI.Colors.Bad, 3), UI.padding(8) })
	bossTitle = UI.label({
		Size = UDim2.new(1, -70, 0, 22),
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = bossBar,
	})
	bossTime = UI.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(70, 22),
		TextSize = 20,
		TextColor3 = UI.Colors.Spark,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = bossBar,
	})
	local track = UI.new("Frame", {
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundColor3 = UI.Colors.Track,
		Parent = bossBar,
	}, { UI.corner(10) })
	bossFill = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UI.Colors.Bad,
		Parent = track,
	}, { UI.corner(10) })
	bossHpText = UI.label({
		Size = UDim2.fromScale(1, 1),
		TextSize = 15,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeColor3 = UI.Colors.Outline,
		TextStrokeTransparency = 0.2,
		ZIndex = 2,
		Parent = track,
	})
	bossDamage = UI.label({
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(1, 0, 0, 16),
		TextSize = 14,
		TextColor3 = UI.Colors.Muted,
		Parent = bossBar,
	})
end

local function refreshRaid(now: number)
	local state = workspace:GetAttribute("RaidState")
	local startsAt = workspace:GetAttribute("RaidStartsAt") or now
	bossBar.Visible = state == "active"
	raidChip.Visible = state ~= "active"
	if state == "active" then
		local boss = RaidData.get(workspace:GetAttribute("RaidBoss"))
		local hp = workspace:GetAttribute("RaidHp") or 0
		local maxHp = math.max(1, workspace:GetAttribute("RaidMaxHp") or 1)
		bossTitle.Text = if boss then boss.emoji .. " " .. boss.name else "Mega-Storm"
		bossTime.Text = Format.time((workspace:GetAttribute("RaidEndsAt") or now) - now)
		bossFill.Size = UDim2.fromScale(math.clamp(hp / maxHp, 0, 1), 1)
		bossHpText.Text = Format.number(hp) .. " / " .. Format.number(maxHp)
		bossDamage.Text = "Your damage: "
			.. Format.number(player:GetAttribute("RaidDamage") or 0)
			.. "  ·  Click to fire!"
	elseif state == "warning" then
		raidChip.Text = "⚠️ Mega-Storm " .. Format.time(startsAt - now) .. "!"
		raidChip.TextColor3 = UI.Colors.Bad
	else
		raidChip.Text = "🌪️ " .. Format.time(startsAt - now)
		raidChip.TextColor3 = UI.Colors.Text
	end
end

local function refreshStats()
	sparksLabel.Text = "⚡ " .. Format.number(player:GetAttribute("Sparks") or 0)
	incomeLabel.Text = "+" .. Format.number(player:GetAttribute("IncomePerSec") or 0) .. "/s"
	local unclaimed = player:GetAttribute("Unclaimed") or 0
	local auto = player:GetAttribute(Products.passAttribute("AutoCollect")) == true
	unclaimedChip.Visible = unclaimed >= 1 and not auto
	unclaimedChip.Text = "💰 " .. Format.number(unclaimed)
	local carrying = player:GetAttribute("Carrying")
	carryBanner.Visible = carrying ~= nil
	carryBanner.Text = "🏃 Carrying " .. tostring(carrying) .. "! Run home!"
end

-- A square icon button with a tiny label under the emoji.
local function iconButton(parent: Instance, order: number, emoji: string, caption: string, color: Color3): TextButton
	local button = UI.button({
		LayoutOrder = order,
		Size = UDim2.fromOffset(64, 64),
		Text = "",
		BackgroundColor3 = color,
		Parent = parent,
	})
	UI.label({
		Size = UDim2.new(1, 0, 0.66, 0),
		Text = emoji,
		TextSize = 30,
		Parent = button,
	})
	UI.label({
		Position = UDim2.fromScale(0, 0.62),
		Size = UDim2.new(1, 0, 0.34, 0),
		Text = caption,
		TextSize = 13,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeColor3 = UI.Colors.Outline,
		TextStrokeTransparency = 0.1,
		Parent = button,
	})
	return button
end

-- A little red number in the corner of a button.
local function badge(button: GuiObject): TextLabel
	local label = UI.label({
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = UI.Colors.Bad,
		BackgroundTransparency = 0,
		TextSize = 14,
		TextColor3 = Color3.new(1, 1, 1),
		ZIndex = 3,
		Visible = false,
		Parent = button,
	})
	UI.corner(12).Parent = label
	UI.stroke(Color3.new(1, 1, 1), 2).Parent = label
	return label
end

local function buyEmergencyLock()
	local lockItem = Products.get("EmergencyLock")
	if not lockItem then
		return
	end
	if lockItem.id ~= 0 then
		MarketplaceService:PromptProductPurchase(player, lockItem.id)
	elseif RunService:IsStudio() then
		Remotes.event("DevPurchase"):FireServer(lockItem.key)
	else
		Toasts.show("Emergency Lock is coming soon!", "info")
	end
end

function HUD.start()
	local screen = UI.screen("HUD", 1)

	-- Top: Sparks bar, then the chips row, then the boss bar.
	local top = UI.new("Frame", {
		Name = "Top",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		Parent = screen,
	}, { UI.list(6) })

	local sparksBar = UI.new("Frame", {
		LayoutOrder = 1,
		Size = UDim2.fromOffset(0, 46),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = UI.Colors.Panel,
		Parent = top,
	}, {
		UI.corner(23),
		UI.stroke(UI.Colors.Spark, 3),
		UI.new("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 10) }),
		UI.list(10, Enum.FillDirection.Horizontal),
	})
	sparksLabel = UI.label({
		LayoutOrder = 1,
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = 28,
		TextColor3 = UI.Colors.Spark,
		Parent = sparksBar,
	})
	incomeLabel = UI.label({
		LayoutOrder = 2,
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = 18,
		TextColor3 = Color3.fromRGB(50, 160, 95),
		Parent = sparksBar,
	})
	unclaimedChip = chip(sparksBar, 3, 30, 16)
	unclaimedChip.BackgroundColor3 = Color3.fromRGB(255, 236, 200)
	unclaimedChip.AnchorPoint = Vector2.new(0, 0.5)

	local chips = UI.new("Frame", {
		LayoutOrder = 2,
		Size = UDim2.fromOffset(0, 28),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Parent = top,
	}, { UI.list(6, Enum.FillDirection.Horizontal) })
	weatherChip = chip(chips, 1, 28, 15)
	raidChip = chip(chips, 2, 28, 15)
	lockChip = chip(chips, 3, 28, 15)
	boostChip = chip(chips, 4, 28, 15)
	boostChip.BackgroundColor3 = Color3.fromRGB(255, 236, 200)
	boostChip.Visible = false
	buildBossBar(top)

	-- Left: the icon bar. It shrinks on short (phone) screens.
	local bar = UI.new("Frame", {
		Name = "IconBar",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(64, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = screen,
	}, { UI.list(8) })
	local barScale = UI.new("UIScale", { Parent = bar })
	local function fitBar()
		local camera = workspace.CurrentCamera
		local height = if camera then camera.ViewportSize.Y else 800
		barScale.Scale = math.clamp((height - 140) / 600, 0.5, 1)
	end
	fitBar()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitBar)
	end

	local rewardsButton = iconButton(bar, 0, "🎁", "Rewards", Color3.fromRGB(150, 225, 170))
	rewardsButton.Activated:Connect(function()
		Rewards.toggle()
	end)
	local rewardsBadge = badge(rewardsButton)
	local function refreshRewardsBadge()
		local waiting = player:GetAttribute("RewardsReady") or 0
		rewardsBadge.Visible = waiting > 0
		rewardsBadge.Text = tostring(waiting)
	end
	player:GetAttributeChangedSignal("RewardsReady"):Connect(refreshRewardsBadge)
	refreshRewardsBadge()
	iconButton(bar, 1, "🛒", "Shop", UI.Colors.PanelLight).Activated:Connect(function()
		Shop.toggle(nil)
	end)
	iconButton(bar, 2, "💎", "Robux", UI.Colors.Robux).Activated:Connect(function()
		Shop.toggle("Robux")
	end)
	local seasonButton = iconButton(bar, 3, "🎟️", "Season", Color3.fromRGB(255, 205, 90))
	seasonButton.Activated:Connect(function()
		Season.toggle()
	end)
	local seasonBadge = badge(seasonButton)
	local function refreshSeasonBadge()
		local waiting = player:GetAttribute("SeasonClaimable") or 0
		seasonBadge.Visible = waiting > 0
		seasonBadge.Text = tostring(waiting)
	end
	player:GetAttributeChangedSignal("SeasonClaimable"):Connect(refreshSeasonBadge)
	refreshSeasonBadge()
	iconButton(bar, 4, "🤝", "Trade", Color3.fromRGB(255, 180, 140)).Activated:Connect(function()
		Trade.openMenu()
	end)
	iconButton(bar, 5, "⚔️", "Battle", Color3.fromRGB(255, 150, 150)).Activated:Connect(function()
		Battle.openMenu()
	end)
	iconButton(bar, 6, "🌍", "Climate", Color3.fromRGB(140, 195, 255)).Activated:Connect(function()
		Climate.toggle()
	end)
	local lockItem = Products.get("EmergencyLock")
	if lockItem then
		iconButton(bar, 7, "🔒", "R$" .. lockItem.price, Color3.fromRGB(255, 160, 190)).Activated:Connect(
			buyEmergencyLock
		)
	end

	-- Bottom: carrying banner.
	carryBanner = UI.label({
		Name = "CarryBanner",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -110),
		Size = UDim2.fromOffset(0, 44),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = UI.Colors.Bad,
		BackgroundTransparency = 0,
		TextSize = 22,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeColor3 = UI.Colors.Outline,
		TextStrokeTransparency = 0.2,
		Visible = false,
		Parent = screen,
	})
	UI.corner(22).Parent = carryBanner
	UI.stroke(Color3.new(1, 1, 1), 3).Parent = carryBanner
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18), Parent = carryBanner })

	player.AttributeChanged:Connect(refreshStats)
	refreshStats()

	task.spawn(function()
		while true do
			local now = workspace:GetServerTimeNow()
			weatherChip.Text = weatherText(now)
			local text, color = lockText(now)
			lockChip.Text = text
			lockChip.TextColor3 = color
			local boostEndsAt = player:GetAttribute("BoostEndsAt")
			boostChip.Visible = type(boostEndsAt) == "number" and boostEndsAt > now
			if boostChip.Visible then
				boostChip.Text = "🚀 x2 Beginner Boost " .. Format.time(boostEndsAt - now)
			end
			refreshRaid(now)
			task.wait(0.25)
		end
	end)
end

return HUD
