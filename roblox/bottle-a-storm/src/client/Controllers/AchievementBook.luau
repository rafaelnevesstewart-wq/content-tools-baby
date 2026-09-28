-- The 🏅 Achievement Book: every achievement and every title in one place,
-- with a progress bar for each and how many you've got. "Almost there"
-- shows the ones you're closest to first. Titles you've earned can be worn
-- right here. (Opened from 📋 Menu.)

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Format)
local ProgressionData = require(Shared.ProgressionData)
local Remotes = require(Shared.Remotes)
local TitleData = require(Shared.TitleData)

local UI = require(script.Parent.UI)

local AchievementBook = {}

type Row = {
	kind: string, -- "goal" | "title"
	id: string,
	emoji: string,
	name: string,
	goal: string,
	target: number,
	progress: number,
	done: boolean,
}

local window: Frame
local list: ScrollingFrame
local summary: TextLabel
local filterButtons: { [string]: TextButton } = {}
local filter = "Almost"
local equipped: string? = nil

local function load(): { Row }
	local rows: { Row } = {}
	local okGoals, goals = pcall(function()
		return Remotes.func("GetAchievements"):InvokeServer()
	end)
	local byId = {}
	if okGoals and type(goals) == "table" then
		for _, entry in goals do
			byId[entry.id] = entry
		end
	end
	for _, achievement in ProgressionData.Achievements do
		local entry = byId[achievement.id]
		table.insert(rows, {
			kind = "goal",
			id = achievement.id,
			emoji = achievement.emoji,
			name = achievement.name,
			goal = achievement.goal,
			target = achievement.target,
			progress = if entry then entry.progress else 0,
			done = entry ~= nil and entry.done == true,
		})
	end
	local okTitles, titles = pcall(function()
		return Remotes.func("GetTitles"):InvokeServer()
	end)
	local titleById = {}
	if okTitles and type(titles) == "table" then
		equipped = titles.equipped
		for _, entry in titles.list do
			titleById[entry.id] = entry
		end
	end
	for _, title in TitleData.List do
		local entry = titleById[title.id]
		table.insert(rows, {
			kind = "title",
			id = title.id,
			emoji = title.emoji,
			name = title.name,
			goal = title.goal,
			target = title.target,
			progress = if entry then entry.progress else 0,
			done = entry ~= nil and entry.unlocked == true,
		})
	end
	return rows
end

local fill: () -> ()

local function row(order: number, entry: Row)
	local frame = UI.new("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, 58),
		BackgroundColor3 = if entry.done then Color3.fromRGB(34, 70, 50) else UI.Colors.PanelLight,
		Parent = list,
	}, { UI.corner(10), UI.padding(6) })
	UI.label({
		Size = UDim2.fromOffset(40, 44),
		Text = entry.emoji,
		TextSize = 28,
		Parent = frame,
	})
	UI.label({
		Position = UDim2.fromOffset(46, 0),
		Size = UDim2.new(1, -150, 0, 22),
		Text = (if entry.kind == "title" then "🏷️ " else "") .. entry.name .. (if entry.done then "  ✅" else ""),
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = frame,
	})
	UI.label({
		Position = UDim2.fromOffset(46, 20),
		Size = UDim2.new(1, -150, 0, 16),
		Text = entry.goal,
		TextSize = 12,
		TextColor3 = UI.Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = frame,
	})
	local track = UI.new("Frame", {
		Position = UDim2.fromOffset(46, 40),
		Size = UDim2.new(1, -150, 0, 8),
		BackgroundColor3 = UI.Colors.Track,
		Parent = frame,
	}, { UI.corner(4) })
	UI.new("Frame", {
		Size = UDim2.fromScale(math.clamp(entry.progress / math.max(1, entry.target), 0, 1), 1),
		BackgroundColor3 = if entry.done then UI.Colors.Good else UI.Colors.Spark,
		Parent = track,
	}, { UI.corner(4) })
	UI.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(96, 22),
		Text = Format.number(math.floor(entry.progress)) .. " / " .. Format.number(entry.target),
		TextSize = 13,
		TextColor3 = UI.Colors.Muted,
		Parent = frame,
	})
	if entry.kind == "title" and entry.done then
		local wearing = equipped == entry.id
		local button = UI.button({
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.fromScale(1, 1),
			Size = UDim2.fromOffset(96, 26),
			Text = if wearing then "Wearing" else "Wear",
			TextSize = 13,
			BackgroundColor3 = if wearing then UI.Colors.Good else UI.Colors.Stroke,
			Parent = frame,
		})
		button.Activated:Connect(function()
			pcall(function()
				Remotes.func("SetTitle"):InvokeServer(if wearing then nil else entry.id)
			end)
			fill()
		end)
	end
end

fill = function()
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for key, button in filterButtons do
		button.BackgroundColor3 = if key == filter then UI.Colors.Good else UI.Colors.PanelLight
	end
	local rows = load()
	local goalsDone, goalsAll, titlesDone, titlesAll = 0, 0, 0, 0
	for _, entry in rows do
		if entry.kind == "goal" then
			goalsAll += 1
			goalsDone += if entry.done then 1 else 0
		else
			titlesAll += 1
			titlesDone += if entry.done then 1 else 0
		end
	end
	summary.Text = "🏅 "
		.. goalsDone
		.. "/"
		.. goalsAll
		.. " achievements   🏷️ "
		.. titlesDone
		.. "/"
		.. titlesAll
		.. " titles"
	local shown = {}
	for _, entry in rows do
		local wanted = filter == "All" or (filter == "Done") == entry.done
		if wanted then
			table.insert(shown, entry)
		end
	end
	if filter == "Almost" then
		table.sort(shown, function(a, b)
			return a.progress / math.max(1, a.target) > b.progress / math.max(1, b.target)
		end)
	end
	for index, entry in shown do
		row(index, entry)
	end
end

function AchievementBook.toggle()
	window.Visible = not window.Visible
	if window.Visible then
		fill()
	end
end

function AchievementBook.start()
	local screen = UI.screen("AchievementBook", 8)
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
		UI.stroke(UI.Colors.Stroke, 3),
		UI.padding(12),
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(560, 620) }),
	})
	UI.label({
		Size = UDim2.new(1, -60, 0, 32),
		Text = "🏅 Achievement Book",
		TextSize = 22,
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
	summary = UI.label({
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, 0, 0, 22),
		Text = "",
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = window,
	})
	local filters = UI.new("Frame", {
		Position = UDim2.fromOffset(0, 62),
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundTransparency = 1,
		Parent = window,
	}, {
		UI.new("UIGridLayout", {
			CellSize = UDim2.new(1 / 3, -6, 1, 0),
			CellPadding = UDim2.fromOffset(8, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for order, entry in { { "Almost", "⏳ Almost there" }, { "Done", "✅ Done" }, { "All", "📚 All" } } do
		local button = UI.button({ LayoutOrder = order, Text = entry[2], TextSize = 14, Parent = filters })
		button.Activated:Connect(function()
			filter = entry[1]
			fill()
		end)
		filterButtons[entry[1]] = button
	end
	list = UI.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 100),
		Size = UDim2.new(1, 0, 1, -100),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = window,
	}, { UI.list(4) })
end

return AchievementBook
