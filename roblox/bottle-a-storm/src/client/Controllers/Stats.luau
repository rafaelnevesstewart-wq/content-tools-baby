-- The 📊 Stats window: your wins, knockouts, beds, streaks, rank, level and
-- your favorite weapon, with a bar for every weapon you've used.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local Stats = {}

-- Emoji for each weapon (also used by the kill feed).
Stats.WeaponEmoji = {
	Sword = "⚔️",
	Bow = "🏹",
	["Knockback Stick"] = "🪄",
	TNT = "🧨",
	Fireball = "🔥",
	["Lucky Block"] = "🍀",
	Rocket = "🚀",
} :: { [string]: string }

local window: Frame
local list: ScrollingFrame

local function clear()
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function heading(order: number, text: string)
	UI.label({
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, 24),
		Text = text,
		TextSize = 16,
		TextColor3 = UI.Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = list,
	})
end

-- A grid of stat cards: { emoji, name, value }.
local function cards(order: number, entries: { { string } })
	local grid = UI.new("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = list,
	}, {
		UI.new("UIGridLayout", {
			CellSize = UDim2.new(1 / 3, -6, 0, 70),
			CellPadding = UDim2.fromOffset(6, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for index, entry in entries do
		local card = UI.new("Frame", {
			LayoutOrder = index,
			BackgroundColor3 = UI.Colors.PanelLight,
			Parent = grid,
		}, { UI.corner(10), UI.padding(6) })
		UI.label({
			Size = UDim2.new(1, 0, 0, 30),
			Text = entry[3],
			TextSize = 24,
			TextColor3 = UI.Colors.Spark,
			Parent = card,
		})
		UI.label({
			Position = UDim2.fromOffset(0, 32),
			Size = UDim2.new(1, 0, 0, 22),
			Text = entry[1] .. " " .. entry[2],
			TextSize = 14,
			TextColor3 = UI.Colors.Text,
			Parent = card,
		})
	end
end

local function show(stats: any)
	clear()
	if type(stats) ~= "table" then
		heading(1, "Your stats are still loading. Try again in a moment!")
		return
	end
	local n = Format.number
	local winRate = if stats.matches > 0 then math.floor(stats.wins / stats.matches * 100 + 0.5) else 0
	local ratio = if stats.deaths > 0 then string.format("%.2f", stats.kills / stats.deaths) else tostring(stats.kills)
	heading(1, "🛏️ Bed Wars")
	cards(2, {
		{ "🏆", "Wins", n(stats.wins) },
		{ "🎮", "Matches", n(stats.matches) },
		{ "📈", "Win rate", winRate .. "%" },
		{ "⚔️", "Knockouts", n(stats.kills) },
		{ "💀", "Final kills", n(stats.finalKills) },
		{ "⚖️", "K/D", ratio },
		{ "🛏️", "Beds broken", n(stats.bedsBroken) },
		{ "🔥", "Win streak", n(stats.winStreak) },
		{ "🌟", "Best streak", n(stats.bestStreak) },
	})
	heading(3, "⭐ Progress")
	cards(4, {
		{ "⭐", "Level", (if stats.prestige > 0 then "P" .. stats.prestige .. " " else "") .. stats.level },
		{ "👑", "Rank", stats.rank },
		{ "🎯", "Rank points", n(stats.rankPoints) },
		{ "🤺", "Duels won", n(stats.duelsWon) },
		{ "🧟", "Zombies", n(stats.zombiesKilled or 0) },
		{ "🏔️", "Parkour clears", n(stats.obbyClears) },
		{ "⚡", "Sparks earned", n(stats.sparksEarned) },
	})
	heading(5, "🗡️ Favorite weapon")
	if stats.favorite then
		UI.label({
			LayoutOrder = 6,
			Size = UDim2.new(1, -8, 0, 40),
			Text = (Stats.WeaponEmoji[stats.favorite] or "⚔️") .. " " .. stats.favorite .. " (" .. n(
				stats.favoriteKills
			) .. " knockouts)",
			TextSize = 22,
			TextColor3 = UI.Colors.Spark,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = list,
		})
		-- A bar for every weapon, longest for the favorite.
		local order = 7
		local sorted = {}
		for weapon, count in stats.weaponKills do
			table.insert(sorted, { weapon = weapon, count = count })
		end
		table.sort(sorted, function(a, b)
			return a.count > b.count
		end)
		for _, entry in sorted do
			order += 1
			local row = UI.new("Frame", {
				LayoutOrder = order,
				Size = UDim2.new(1, -8, 0, 26),
				BackgroundColor3 = UI.Colors.Track,
				Parent = list,
			}, { UI.corner(8) })
			UI.new("Frame", {
				Size = UDim2.fromScale(math.max(0.04, entry.count / stats.favoriteKills), 1),
				BackgroundColor3 = UI.Colors.Stroke,
				Parent = row,
			}, { UI.corner(8) })
			UI.label({
				Position = UDim2.fromOffset(8, 0),
				Size = UDim2.new(1, -16, 1, 0),
				Text = (Stats.WeaponEmoji[entry.weapon] or "⚔️") .. " " .. entry.weapon .. ": " .. n(entry.count),
				TextSize = 15,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = row,
			})
		end
	else
		heading(6, "Knock someone out in a match to find your favorite!")
	end
end

function Stats.toggle()
	window.Visible = not window.Visible
	if window.Visible then
		clear()
		heading(1, "Loading...")
		task.spawn(function()
			local ok, stats = pcall(function()
				return Remotes.func("GetStats"):InvokeServer()
			end)
			if window.Visible then
				show(if ok then stats else nil)
			end
		end)
	end
end

function Stats.start()
	local screen = UI.screen("Stats", 7)
	window = UI.new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.9, 0, 0.8, 0),
		BackgroundColor3 = UI.Colors.Panel,
		Visible = false,
		Parent = screen,
	}, {
		UI.corner(18),
		UI.stroke(UI.Colors.Stroke, 3),
		UI.padding(14),
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(560, 600) }),
	})
	UI.label({
		Size = UDim2.new(1, -60, 0, 34),
		Text = "📊 " .. player.DisplayName .. "'s Stats",
		TextSize = 26,
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
	list = UI.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 1, -44),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = window,
	}, { UI.list(6) })
end

return Stats
