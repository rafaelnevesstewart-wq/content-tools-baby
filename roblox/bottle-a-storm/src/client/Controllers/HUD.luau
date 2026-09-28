-- Always-on screen info, kept tidy:
--   top:  your Sparks (and your match Sparks bonus), then a row of small chips:
--         match weather and events (Admin Abuse, holidays)
--   left: an icon bar (Rewards, Battle Pass, Kits, Kit Market, Style, Party,
--         Robux, Stats, Settings, Admin)
-- The match itself (timer, teams, beds, resources) is in MatchHUD.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Format)
local ProgressionData = require(Shared.ProgressionData)
local WeatherEvents = require(Shared.WeatherEvents)

local AdminPanel = require(script.Parent.AdminPanel)
local Kits = require(script.Parent.Kits)
local Market = require(script.Parent.Market)
local Party = require(script.Parent.Party)
local Rewards = require(script.Parent.Rewards)
local Season = require(script.Parent.Season)
local Settings = require(script.Parent.Settings)
local Stats = require(script.Parent.Stats)
local Shop = require(script.Parent.Shop)
local Style = require(script.Parent.Style)
local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local HUD = {}

local sparksLabel: TextLabel
local bonusLabel: TextLabel
local levelChip: TextLabel
local weatherChip: TextLabel
local eventChip: TextLabel

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

-- The weather event on now, or the next one during a match.
local function weatherText(now: number): string?
	local current = WeatherEvents.get(workspace:GetAttribute("WeatherEvent"))
	if current then
		return current.emoji
			.. " "
			.. current.name
			.. " "
			.. Format.time((workspace:GetAttribute("WeatherEndsAt") or now) - now)
	end
	local nextEvent = WeatherEvents.get(workspace:GetAttribute("NextWeather"))
	local nextAt = workspace:GetAttribute("NextWeatherAt")
	if nextEvent and type(nextAt) == "number" and nextAt > now then
		return "📺 Next: " .. nextEvent.emoji .. " " .. nextEvent.name .. " in " .. Format.time(nextAt - now)
	end
	return nil
end

local function refreshStats()
	sparksLabel.Text = "⚡ " .. Format.number(player:GetAttribute("Sparks") or 0)
	local level = player:GetAttribute("Level")
	if type(level) == "number" then
		local prestige = player:GetAttribute("Prestige") or 0
		local rank = ProgressionData.rankOf(player:GetAttribute("RankPoints") or 0)
		local streak = player:GetAttribute("WinStreak") or 0
		levelChip.Visible = true
		levelChip.Text = "⭐"
			.. (if prestige > 0 then tostring(prestige) else "")
			.. " Lv "
			.. level
			.. " ("
			.. (player:GetAttribute("LevelXp") or 0)
			.. "/"
			.. (player:GetAttribute("LevelNeed") or 100)
			.. " XP)  ·  "
			.. rank.emoji
			.. " "
			.. rank.name
			.. " "
			.. (player:GetAttribute("RankPoints") or 0)
			.. (if streak >= 2 then "  ·  🔥" .. streak else "")
		levelChip.TextColor3 =
			UI.ink(ProgressionData.PrestigeColors[math.min(prestige, ProgressionData.MaxPrestige) + 1])
	end
	local bonus = player:GetAttribute("SparksBonus")
	local shown = type(bonus) == "number" and bonus > 1.001
	bonusLabel.Visible = shown
	if shown then
		bonusLabel.Text = string.format("x%.1f match Sparks", bonus)
	end
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
local function badge(button: GuiObject, attribute: string)
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
	local function refresh()
		local waiting = player:GetAttribute(attribute) or 0
		label.Visible = waiting > 0
		label.Text = tostring(waiting)
	end
	player:GetAttributeChangedSignal(attribute):Connect(refresh)
	refresh()
end

function HUD.start()
	local screen = UI.screen("HUD", 1)

	-- Top: Sparks bar, then the chips row.
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
		UI.new("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }),
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
	bonusLabel = UI.label({
		LayoutOrder = 2,
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = 16,
		TextColor3 = Color3.fromRGB(110, 220, 150),
		Visible = false,
		Parent = sparksBar,
	})

	local chips = UI.new("Frame", {
		LayoutOrder = 2,
		Size = UDim2.fromOffset(0, 28),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Parent = top,
	}, { UI.list(6, Enum.FillDirection.Horizontal) })
	levelChip = chip(chips, 0, 28, 15)
	levelChip.Visible = false
	weatherChip = chip(chips, 1, 28, 15)
	weatherChip.Visible = false
	eventChip = chip(chips, 2, 28, 15)
	eventChip.BackgroundColor3 = Color3.fromRGB(70, 56, 26)
	eventChip.Visible = false

	-- Left: the icon bar, two buttons wide. It shrinks on short (phone) screens.
	local bar = UI.new("Frame", {
		Name = "IconBar",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(136, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = screen,
	}, {
		UI.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(64, 64),
			CellPadding = UDim2.fromOffset(8, 8),
			FillDirectionMaxCells = 2,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local barScale = UI.new("UIScale", { Parent = bar })
	local function fitBar()
		local camera = workspace.CurrentCamera
		local height = if camera then camera.ViewportSize.Y else 800
		barScale.Scale = math.clamp((height - 140) / 440, 0.55, 1)
	end
	fitBar()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitBar)
	end

	local rewardsButton = iconButton(bar, 0, "🎁", "Rewards", Color3.fromRGB(150, 225, 170))
	rewardsButton.Activated:Connect(Rewards.toggle)
	badge(rewardsButton, "RewardsReady")
	local passButton = iconButton(bar, 1, "🎟️", "Pass", Color3.fromRGB(255, 205, 90))
	passButton.Activated:Connect(Season.toggle)
	badge(passButton, "SeasonClaimable")
	iconButton(bar, 2, "🌪️", "Kits", Color3.fromRGB(150, 200, 255)).Activated:Connect(Kits.toggle)
	iconButton(bar, 3, "🏪", "Market", Color3.fromRGB(96, 170, 210)).Activated:Connect(Market.toggle)
	iconButton(bar, 4, "🎨", "Style", Color3.fromRGB(255, 170, 220)).Activated:Connect(Style.toggle)
	iconButton(bar, 5, "👥", "Party", Color3.fromRGB(140, 220, 200)).Activated:Connect(Party.toggle)
	iconButton(bar, 6, "💎", "Robux", UI.Colors.Robux).Activated:Connect(Shop.toggle)
	iconButton(bar, 7, "📊", "Stats", Color3.fromRGB(150, 190, 255)).Activated:Connect(Stats.toggle)
	iconButton(bar, 8, "⚙️", "Settings", Color3.fromRGB(190, 196, 210)).Activated:Connect(Settings.toggle)
	local adminButton = iconButton(bar, 20, "👑", "Admin", UI.Colors.Spark)
	adminButton.Activated:Connect(AdminPanel.toggle)
	local function refreshAdmin()
		adminButton.Visible = AdminPanel.isAdmin()
	end
	player:GetAttributeChangedSignal("IsAdmin"):Connect(refreshAdmin)
	refreshAdmin()

	player.AttributeChanged:Connect(refreshStats)
	refreshStats()

	task.spawn(function()
		while true do
			local now = workspace:GetServerTimeNow()
			local weather = weatherText(now)
			weatherChip.Visible = weather ~= nil
			weatherChip.Text = weather or ""
			-- Admin Abuse / holiday event chip.
			local abuseUntil = workspace:GetAttribute("AbuseUntil")
			local holiday = workspace:GetAttribute("Holiday")
			if type(abuseUntil) == "number" and abuseUntil > now then
				eventChip.Visible = true
				eventChip.Text = "👑 ADMIN ABUSE: x2 Sparks " .. Format.time(abuseUntil - now)
			elseif type(holiday) == "string" then
				eventChip.Visible = true
				eventChip.Text = "🎉 Event: " .. Format.number(player:GetAttribute("HolidayPoints") or 0) .. " points"
			else
				eventChip.Visible = false
			end
			task.wait(0.25)
		end
	end)
end

return HUD
