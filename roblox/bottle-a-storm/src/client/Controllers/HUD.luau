-- Always-on screen info: Sparks, income, weather countdown, lock status,
-- the "carrying a stolen storm" banner and the side buttons.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Format)
local Products = require(Shared.Products)
local Remotes = require(Shared.Remotes)
local RaidData = require(Shared.RaidData)
local WeatherEvents = require(Shared.WeatherEvents)

local Shop = require(script.Parent.Shop)
local Toasts = require(script.Parent.Toasts)
local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local HUD = {}

local sparksLabel: TextLabel
local incomeLabel: TextLabel
local unclaimedLabel: TextLabel
local weatherLabel: TextLabel
local lockLabel: TextLabel
local carryBanner: TextLabel
local raidPill: Frame
local raidLabel: TextLabel
local bossBar: Frame
local bossTitle: TextLabel
local bossTime: TextLabel
local bossFill: Frame
local bossHpText: TextLabel
local bossDamage: TextLabel

local function pill(parent: Instance, order: number, height: number): Frame
	return UI.new("Frame", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(0, height),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.15,
		Parent = parent,
	}, {
		UI.corner(height // 2),
		UI.stroke(UI.Colors.Stroke, 2),
		UI.new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }),
		UI.list(10, Enum.FillDirection.Horizontal),
	})
end

local function pillText(parent: Instance, order: number, size: number, color: Color3): TextLabel
	return UI.label({
		LayoutOrder = order,
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = size,
		TextColor3 = color,
		Parent = parent,
	})
end

local function weatherText(now: number): string
	local current = WeatherEvents.get(workspace:GetAttribute("WeatherEvent"))
	if current then
		local left = (workspace:GetAttribute("WeatherEndsAt") or now) - now
		return current.emoji .. " " .. current.name .. " · " .. Format.time(left) .. " left"
	end
	local nextEvent = WeatherEvents.get(workspace:GetAttribute("NextWeather"))
	if nextEvent then
		local wait = (workspace:GetAttribute("NextWeatherAt") or now) - now
		return "📺 Next: " .. nextEvent.emoji .. " " .. nextEvent.name .. " in " .. Format.time(wait)
	end
	return "☀️ Clear skies"
end

local function lockText(now: number): (string, Color3)
	local plot = UI.myPlot()
	if not plot then
		return "Finding your island...", UI.Colors.Muted
	end
	local lockedUntil = plot:GetAttribute("LockedUntil") or 0
	local readyAt = plot:GetAttribute("LockReadyAt") or 0
	if lockedUntil > now then
		return "🔒 Island locked · " .. Format.time(lockedUntil - now), UI.Colors.Good
	elseif readyAt > now then
		return "🔓 Lock recharging · " .. Format.time(readyAt - now), UI.Colors.Warn
	end
	return "🔓 Island open. Press your Lock button!", UI.Colors.Warn
end

-- The Mega-Storm HP bar, shown under the Sparks counter during a raid.
local function buildBossBar(parent: Instance)
	bossBar = UI.new("Frame", {
		Name = "BossBar",
		LayoutOrder = 2,
		Size = UDim2.fromOffset(380, 76),
		BackgroundColor3 = Color3.fromRGB(45, 20, 35),
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = parent,
	}, { UI.corner(12), UI.stroke(UI.Colors.Bad, 2.5), UI.padding(8) })
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
		BackgroundColor3 = Color3.fromRGB(20, 10, 20),
		Parent = bossBar,
	}, { UI.corner(8) })
	bossFill = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UI.Colors.Bad,
		Parent = track,
	}, { UI.corner(8) })
	bossHpText = UI.label({
		Size = UDim2.fromScale(1, 1),
		TextSize = 15,
		TextStrokeTransparency = 0.3,
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
	raidPill.Visible = state ~= "active"
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
			.. "  ·  Click to fire your Storm Launcher!"
	elseif state == "warning" then
		raidLabel.Text = "⚠️ MEGA-STORM in " .. Format.time(startsAt - now) .. "! Go to the Wild Skies!"
		raidLabel.TextColor3 = UI.Colors.Bad
	else
		raidLabel.Text = "🌪️ Mega-Storm in " .. Format.time(startsAt - now)
		raidLabel.TextColor3 = UI.Colors.Muted
	end
end

local function refreshStats()
	sparksLabel.Text = "⚡ " .. Format.number(player:GetAttribute("Sparks") or 0)
	incomeLabel.Text = "+" .. Format.number(player:GetAttribute("IncomePerSec") or 0) .. "/s"
	local unclaimed = player:GetAttribute("Unclaimed") or 0
	local auto = player:GetAttribute(Products.passAttribute("AutoCollect")) == true
	unclaimedLabel.Visible = unclaimed >= 1 and not auto
	unclaimedLabel.Text = "💰 ⚡" .. Format.number(unclaimed) .. " waiting on your Collect pad"
	local carrying = player:GetAttribute("Carrying")
	carryBanner.Visible = carrying ~= nil
	carryBanner.Text = "🏃 Carrying " .. tostring(carrying) .. "! Get back to your island!"
end

local function sideButton(parent: Instance, order: number, text: string, color: Color3): TextButton
	return UI.button({
		LayoutOrder = order,
		Size = UDim2.fromOffset(150, 48),
		Text = text,
		TextSize = 19,
		BackgroundColor3 = color,
		Parent = parent,
	})
end

function HUD.start()
	local screen = UI.screen("HUD", 1)

	local top = UI.new("Frame", {
		Name = "Top",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		Parent = screen,
	}, { UI.list(6) })

	local sparksPill = pill(top, 1, 48)
	sparksLabel = pillText(sparksPill, 1, 30, UI.Colors.Spark)
	incomeLabel = pillText(sparksPill, 2, 20, UI.Colors.Good)

	unclaimedLabel = UI.label({
		LayoutOrder = 3,
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = 17,
		TextStrokeTransparency = 0.4,
		Parent = top,
	})

	weatherLabel = pillText(pill(top, 4, 32), 1, 18, UI.Colors.Text)
	raidPill = pill(top, 5, 30)
	raidLabel = pillText(raidPill, 1, 16, UI.Colors.Muted)
	lockLabel = pillText(pill(top, 6, 30), 1, 16, UI.Colors.Warn)
	buildBossBar(top)

	local side = UI.new("Frame", {
		Name = "Side",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(150, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = screen,
	}, { UI.list(8) })

	sideButton(side, 1, "🛒 Shop", UI.Colors.PanelLight).Activated:Connect(function()
		Shop.toggle(nil)
	end)
	sideButton(side, 2, "💎 Robux", UI.Colors.Robux).Activated:Connect(function()
		Shop.toggle("Robux")
	end)
	local lockItem = Products.get("EmergencyLock")
	if lockItem then
		sideButton(side, 3, "🔒 Lock R$" .. lockItem.price, Color3.fromRGB(70, 130, 220)).Activated:Connect(function()
			if lockItem.id ~= 0 then
				MarketplaceService:PromptProductPurchase(player, lockItem.id)
			elseif RunService:IsStudio() then
				Remotes.event("DevPurchase"):FireServer(lockItem.key)
			else
				Toasts.show("Emergency Lock is coming soon!", "info")
			end
		end)
	end

	carryBanner = UI.label({
		Name = "CarryBanner",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -110),
		Size = UDim2.fromOffset(0, 44),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Color3.fromRGB(150, 40, 60),
		BackgroundTransparency = 0.1,
		TextSize = 22,
		Visible = false,
		Parent = screen,
	})
	UI.corner(12).Parent = carryBanner
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16), Parent = carryBanner })

	player.AttributeChanged:Connect(refreshStats)
	refreshStats()

	task.spawn(function()
		while true do
			local now = workspace:GetServerTimeNow()
			weatherLabel.Text = weatherText(now)
			local text, color = lockText(now)
			lockLabel.Text = text
			lockLabel.TextColor3 = color
			refreshRaid(now)
			task.wait(0.25)
		end
	end)
end

return HUD
