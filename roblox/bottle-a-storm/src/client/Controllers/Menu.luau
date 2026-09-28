-- The 📋 Menu: one screen with a tile for every window in the game, so the
-- icon bar can stay small (🎁 Rewards, 🎟️ Pass, 📋 Menu, ⚙️ Settings).
-- Tap a tile to open that window. Press M to open or close it.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")

local AchievementBook = require(script.Parent.AchievementBook)
local AdminPanel = require(script.Parent.AdminPanel)
local Challenges = require(script.Parent.Challenges)
local Clan = require(script.Parent.Clan)
local ClassPicker = require(script.Parent.ClassPicker)
local EmoteWheel = require(script.Parent.EmoteWheel)
local FishBook = require(script.Parent.FishBook)
local Kits = require(script.Parent.Kits)
local Market = require(script.Parent.Market)
local Party = require(script.Parent.Party)
local PhotoMode = require(script.Parent.PhotoMode)
local PlayerShop = require(script.Parent.PlayerShop)
local Rewards = require(script.Parent.Rewards)
local Season = require(script.Parent.Season)
local Settings = require(script.Parent.Settings)
local Shop = require(script.Parent.Shop)
local Stats = require(script.Parent.Stats)
local Style = require(script.Parent.Style)
local Toasts = require(script.Parent.Toasts)
local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local Menu = {}

type Tile = { emoji: string, name: string, hint: string, color: Color3, open: () -> (), admin: boolean? }

local TILES: { Tile } = {
	{
		emoji = "🎨",
		name = "Style",
		hint = "Hats, trails, pets, mounts…",
		color = Color3.fromRGB(255, 170, 220),
		open = Style.toggle,
	},
	{
		emoji = "🌪️",
		name = "Kits",
		hint = "Pick the kit you bring",
		color = Color3.fromRGB(150, 200, 255),
		open = Kits.toggle,
	},
	{
		emoji = "🧙",
		name = "Class",
		hint = "Knight, Archer, Builder, Healer",
		color = Color3.fromRGB(110, 190, 140),
		open = ClassPicker.toggle,
	},
	{
		emoji = "🌟",
		name = "Challenges",
		hint = "Daily and weekly goals",
		color = Color3.fromRGB(255, 225, 120),
		open = Challenges.toggle,
	},
	{
		emoji = "🏅",
		name = "Achievements",
		hint = "Every goal and title",
		color = Color3.fromRGB(255, 200, 110),
		open = AchievementBook.toggle,
	},
	{
		emoji = "🎁",
		name = "Rewards",
		hint = "Daily calendar, quests, codes",
		color = Color3.fromRGB(150, 225, 170),
		open = Rewards.toggle,
	},
	{
		emoji = "🎟️",
		name = "Battle Pass",
		hint = "Season rewards",
		color = Color3.fromRGB(255, 205, 90),
		open = Season.toggle,
	},
	{
		emoji = "👥",
		name = "Party & Friends",
		hint = "Team up, duel, trade, gift",
		color = Color3.fromRGB(140, 220, 200),
		open = Party.toggle,
	},
	{
		emoji = "🛡️",
		name = "Clan",
		hint = "Your clan and its pass",
		color = Color3.fromRGB(190, 160, 255),
		open = Clan.toggle,
	},
	{
		emoji = "📊",
		name = "Stats",
		hint = "How you've been doing",
		color = Color3.fromRGB(150, 190, 255),
		open = Stats.toggle,
	},
	{
		emoji = "🏪",
		name = "Kit Market",
		hint = "Buy kits and crates",
		color = Color3.fromRGB(96, 170, 210),
		open = Market.toggle,
	},
	{
		emoji = "🛒",
		name = "Player Market",
		hint = "Buy and sell cosmetics",
		color = Color3.fromRGB(240, 180, 80),
		open = PlayerShop.toggle,
	},
	{
		emoji = "📖",
		name = "Fish Book",
		hint = "Your catches",
		color = Color3.fromRGB(90, 200, 230),
		open = FishBook.toggle,
	},
	{
		emoji = "😀",
		name = "Emotes",
		hint = "Dance and wave (G)",
		color = Color3.fromRGB(250, 180, 60),
		open = EmoteWheel.toggle,
	},
	{
		emoji = "📸",
		name = "Photo Mode",
		hint = "Poses and frames (P)",
		color = Color3.fromRGB(200, 170, 255),
		open = PhotoMode.open,
	},
	{
		emoji = "📜",
		name = "Messages",
		hint = "Everything that popped up",
		color = Color3.fromRGB(170, 180, 200),
		open = Toasts.openLog,
	},
	{
		emoji = "💎",
		name = "Robux Shop",
		hint = "VIP, boosts and more",
		color = Color3.fromRGB(36, 156, 92),
		open = Shop.toggle,
	},
	{
		emoji = "⚙️",
		name = "Settings",
		hint = "Camera, sound, faster mode",
		color = Color3.fromRGB(190, 196, 210),
		open = Settings.toggle,
	},
	{
		emoji = "👑",
		name = "Admin",
		hint = "Owner tools and tests",
		color = Color3.fromRGB(255, 196, 64),
		open = AdminPanel.toggle,
		admin = true,
	},
}

local window: Frame
local adminTiles: { GuiObject } = {}

function Menu.toggle()
	window.Visible = not window.Visible
	for _, tile in adminTiles do
		tile.Visible = AdminPanel.isAdmin()
	end
end

function Menu.start()
	local screen = UI.screen("Menu", 7)
	window = UI.new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.94, 0, 0.86, 0),
		BackgroundColor3 = UI.Colors.Panel,
		Visible = false,
		Parent = screen,
	}, {
		UI.corner(18),
		UI.stroke(UI.Colors.Stroke, 3),
		UI.padding(12),
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(640, 600) }),
	})
	UI.label({
		Size = UDim2.new(1, -60, 0, 34),
		Text = "📋 Menu",
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Spark,
		Parent = window,
	})
	UI.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(44, 36),
		Text = "✕",
		TextSize = 20,
		BackgroundColor3 = UI.Colors.Bad,
		Parent = window,
	}).Activated
		:Connect(function()
			window.Visible = false
		end)
	local grid = UI.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 1, -44),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = window,
	}, {
		UI.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(142, 96),
			CellPadding = UDim2.fromOffset(8, 8),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for order, tile in TILES do
		local button = UI.button({
			LayoutOrder = order,
			Text = "",
			BackgroundColor3 = tile.color:Lerp(UI.Colors.Panel, 0.55),
			Parent = grid,
		})
		UI.label({
			Size = UDim2.new(1, 0, 0, 40),
			Position = UDim2.fromOffset(0, 4),
			Text = tile.emoji,
			TextSize = 30,
			Parent = button,
		})
		UI.label({
			Position = UDim2.fromOffset(4, 44),
			Size = UDim2.new(1, -8, 0, 20),
			Text = tile.name,
			TextSize = 15,
			Parent = button,
		})
		UI.label({
			Position = UDim2.fromOffset(4, 64),
			Size = UDim2.new(1, -8, 0, 28),
			Text = tile.hint,
			TextSize = 11,
			TextWrapped = true,
			TextColor3 = UI.Colors.Muted,
			Parent = button,
		})
		button.Activated:Connect(function()
			window.Visible = false
			tile.open()
		end)
		if tile.admin then
			button.Visible = false
			table.insert(adminTiles, button)
		end
	end
	ContextActionService:BindAction("BottleAStormMenu", function(_, state)
		if state == Enum.UserInputState.Begin then
			Menu.toggle()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.M)
	player:GetAttributeChangedSignal("IsAdmin"):Connect(function()
		for _, tile in adminTiles do
			tile.Visible = AdminPanel.isAdmin()
		end
	end)
end

return Menu
