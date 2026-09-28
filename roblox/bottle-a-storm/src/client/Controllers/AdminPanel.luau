-- The 👑 Admin panel (only shown to admins; the server checks every command),
-- in four tabs:
--   ⚔️ Match    start or end a match, a tournament, Admin Abuse, any match
--              weather, or give everyone Sparks
--   🧪 Test     start features right away: the boss, disasters, the lobby
--              events, night, a shooting star, a special rule, and start your
--              own guide, treasure hunt and puzzles over
--   🗂️ Players  look anyone up, give someone Sparks, restore a backup
--   📈 Stats    what people have been doing today and this week

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local EventData = require(Shared.EventData)
local Remotes = require(Shared.Remotes)
local WeatherEvents = require(Shared.WeatherEvents)

local Toasts = require(script.Parent.Toasts)
local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local AdminPanel = {}

local window: Frame
local pages: { [string]: ScrollingFrame } = {}
local tabs: { [string]: TextButton } = {}
local output: TextLabel

local function run(command: string, arg: any?): (boolean, string)
	local ok, success, message = pcall(function()
		return Remotes.func("AdminCommand"):InvokeServer(command, arg)
	end)
	if not ok then
		return false, "The server didn't answer."
	end
	return success == true, tostring(message)
end

-- Runs a command and shows the answer as a toast.
local function quick(command: string, arg: any?)
	local ok, message = run(command, arg)
	Toasts.show(message, if ok then "success" else "warn")
end

-- Runs a command and shows the (longer) answer in the text box.
local function show(command: string, arg: any?)
	output.Text = "..."
	local _, message = run(command, arg)
	output.Text = message
end

local function showTab(name: string)
	for key, page in pages do
		page.Visible = key == name
	end
	for key, tab in tabs do
		tab.BackgroundColor3 = if key == name then UI.Colors.Good else UI.Colors.PanelLight
	end
end

function AdminPanel.toggle()
	window.Visible = not window.Visible
end

function AdminPanel.isAdmin(): boolean
	return player:GetAttribute("IsAdmin") == true
end

local function newPage(name: string): ScrollingFrame
	local page = UI.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 84),
		Size = UDim2.new(1, 0, 1, -84),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Visible = false,
		Parent = window,
	}, {
		UI.new("UIGridLayout", {
			CellSize = UDim2.new(0.5, -6, 0, 40),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	pages[name] = page
	return page
end

local function button(page: Instance, order: number, text: string, color: Color3?, onClick: () -> ()): TextButton
	local b = UI.button({
		LayoutOrder = order,
		Text = text,
		TextSize = 14,
		TextWrapped = true,
		BackgroundColor3 = color or UI.Colors.PanelLight,
		Parent = page,
	})
	b.Activated:Connect(onClick)
	return b
end

function AdminPanel.start()
	local screen = UI.screen("AdminPanel", 9)
	window = UI.new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.92, 0, 0.85, 0),
		BackgroundColor3 = UI.Colors.Panel,
		Visible = false,
		Parent = screen,
	}, {
		UI.corner(18),
		UI.stroke(UI.Colors.Spark, 3),
		UI.padding(12),
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(540, 600) }),
	})
	UI.label({
		Size = UDim2.new(1, -60, 0, 32),
		Text = "👑 Admin Panel",
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
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
	local tabRow = UI.new("Frame", {
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 1,
		Parent = window,
	}, {
		UI.new("UIGridLayout", {
			CellSize = UDim2.new(0.25, -6, 1, 0),
			CellPadding = UDim2.fromOffset(8, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for order, name in { "⚔️ Match", "🧪 Test", "🗂️ Players", "📈 Stats" } do
		local tab = UI.button({ LayoutOrder = order, Text = name, TextSize = 14, Parent = tabRow })
		tab.Activated:Connect(function()
			showTab(name)
		end)
		tabs[name] = tab
	end

	-- ⚔️ Match
	local match = newPage("⚔️ Match")
	button(match, 1, "⚔️ Start match now", UI.Colors.Good, function()
		quick("startmatch")
	end)
	button(match, 2, "🏁 End match", UI.Colors.Bad, function()
		quick("endmatch")
	end)
	button(match, 3, "🏆 Start 1v1 tournament", UI.Colors.Spark, function()
		quick("tournament")
	end)
	button(match, 4, "👑 ADMIN ABUSE", UI.Colors.Spark, function()
		quick("abuse")
	end)
	for order, event in WeatherEvents.List do
		button(match, 100 + order, event.emoji .. " " .. event.name, nil, function()
			quick("weather", event.key)
		end)
	end
	for order, amount in { 1000, 100000 } do
		button(match, 200 + order, "💸 Everyone +⚡" .. amount // 1000 .. "K", UI.Colors.Robux, function()
			quick("sparks", amount)
		end)
	end

	-- 🧪 Test
	local test = newPage("🧪 Test")
	local tests = {
		{ "🐉 Boss now (in a match)", "boss" },
		{ "☄️ Meteor shower", "disaster", "Meteors" },
		{ "🌋 Earthquake", "disaster", "Quake" },
		{ "🌊 Flood", "disaster", "Flood" },
		{ "🎨 Build contest now", "contest" },
		{ "🎭 Costume party now", "costume" },
		{ "⏩ Skip contest/party phase", "skip" },
		{ "🏟️ Arena Cup now", "arenacup" },
		{ "🌙 Night (3 min)", "night" },
		{ "🌠 Shooting star now", "star" },
		{ "🔁 Restart my guide, hunt, puzzles", "restart" },
		{ "🎪 Normal special rule", "rule", "" },
	}
	for order, entry in tests do
		button(test, order, entry[1], nil, function()
			quick(entry[2], entry[3])
		end)
	end
	for order, event in EventData.List do
		button(test, 100 + order, "🎪 Rule: " .. event.emoji .. " " .. event.name, nil, function()
			quick("rule", event.key)
		end)
	end

	-- 🗂️ Players and 📈 Stats share a text box for the answers.
	output = UI.label({
		Name = "Output",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0.55, 0),
		BackgroundColor3 = UI.Colors.Track,
		BackgroundTransparency = 0,
		Text = "",
		TextSize = 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Visible = false,
		Parent = window,
	})
	UI.corner(8).Parent = output
	UI.padding(8).Parent = output

	local people = newPage("🗂️ Players")
	people.Size = UDim2.new(1, 0, 0.45, -92)
	local nameBox = UI.new("TextBox", {
		LayoutOrder = 1,
		BackgroundColor3 = UI.Colors.Track,
		TextColor3 = UI.Colors.Text,
		Font = UI.Font,
		TextSize = 14,
		PlaceholderText = "name or user id",
		Text = "",
		ClearTextOnFocus = false,
		Parent = people,
	}, { UI.corner(8) })
	local amountBox = UI.new("TextBox", {
		LayoutOrder = 2,
		BackgroundColor3 = UI.Colors.Track,
		TextColor3 = UI.Colors.Text,
		Font = UI.Font,
		TextSize = 14,
		PlaceholderText = "Sparks amount",
		Text = "",
		ClearTextOnFocus = false,
		Parent = people,
	}, { UI.corner(8) })
	button(people, 3, "🔎 Look up", UI.Colors.Stroke, function()
		show("lookup", nameBox.Text)
	end)
	button(people, 4, "💸 Give Sparks", UI.Colors.Robux, function()
		show("give", { name = nameBox.Text, amount = tonumber(amountBox.Text) })
	end)
	local armed = 0
	button(people, 5, "🛡️ Restore newest backup (tap twice)", UI.Colors.Warn, function()
		if os.clock() - armed < 3 then
			armed = 0
			show("restore", nameBox.Text)
		else
			armed = os.clock()
			output.Text = "Tap again to restore " .. nameBox.Text .. "'s newest backup. They'll be asked to rejoin."
		end
	end)

	local stats = newPage("📈 Stats")
	stats.Size = UDim2.new(1, 0, 0.45, -92)
	button(stats, 1, "📈 Today", UI.Colors.Stroke, function()
		show("stats", 1)
	end)
	button(stats, 2, "📈 Last 7 days", UI.Colors.Stroke, function()
		show("stats", 7)
	end)

	local function refreshOutput()
		output.Visible = pages["🗂️ Players"].Visible or pages["📈 Stats"].Visible
	end
	for _, page in pages do
		page:GetPropertyChangedSignal("Visible"):Connect(refreshOutput)
	end
	showTab("⚔️ Match")
end

return AdminPanel
