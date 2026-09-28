-- The 🗳️ Vote window in the lobby: vote for the next match's map and how
-- tough the bots are (VoteService). The team size vote is the row of
-- buttons at the top of the screen (MatchHUD).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local MapData = require(Shared.MapData)
local Remotes = require(Shared.Remotes)

local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local Vote = {}

local window: Frame
local mapButtons: { [string]: TextButton } = {}
local botButtons: { [string]: TextButton } = {}

local function counts(attribute: string): { [string]: number }
	local raw = workspace:GetAttribute(attribute)
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, if type(raw) == "string" then raw else "{}")
	return if ok and type(decoded) == "table" then decoded else {}
end

local function refresh()
	local maps = counts("MapVotes")
	local mine = player:GetAttribute("MapVote")
	for _, map in MapData.List do
		local button = mapButtons[map.key]
		if button then
			button.Text = map.emoji .. " " .. map.name .. "  (" .. (maps[map.key] or 0) .. ")"
			button.BackgroundColor3 = if mine == map.key then UI.Colors.Good else UI.Colors.PanelLight
		end
	end
	local bots = counts("BotVotes")
	local myBots = player:GetAttribute("BotVote")
	for key, button in botButtons do
		local level = Config.Bots.Difficulties[key]
		button.Text = level.emoji .. " " .. key .. "  (" .. (bots[key] or 0) .. ")"
		button.BackgroundColor3 = if myBots == key then UI.Colors.Good else UI.Colors.PanelLight
	end
end

function Vote.toggle()
	window.Visible = not window.Visible
	if window.Visible then
		refresh()
	end
end

function Vote.start()
	local screen = UI.screen("Vote", 7)
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
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(520, 560) }),
	})
	UI.label({
		Size = UDim2.new(1, -60, 0, 34),
		Text = "🗳️ Vote for the next match",
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
	local list = UI.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 1, -44),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = window,
	}, { UI.list(8) })

	local function heading(order: number, text: string)
		UI.label({
			LayoutOrder = order,
			Size = UDim2.new(1, -8, 0, 24),
			Text = text,
			TextSize = 17,
			TextColor3 = UI.Colors.Muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = list,
		})
	end
	local function grid(order: number, columns: number): Frame
		return UI.new("Frame", {
			LayoutOrder = order,
			Size = UDim2.new(1, -8, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = list,
		}, {
			UI.new("UIGridLayout", {
				CellSize = UDim2.new(1 / columns, -6, 0, 44),
				CellPadding = UDim2.fromOffset(6, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
	end

	heading(1, "🗺️ Map (most votes wins; no votes: a surprise!)")
	local maps = grid(2, 2)
	for order, map in MapData.List do
		local button = UI.button({
			LayoutOrder = order,
			TextSize = 15,
			TextScaled = true,
			TextWrapped = true,
			Parent = maps,
		})
		button.Activated:Connect(function()
			Remotes.event("Vote"):FireServer("map", map.key)
		end)
		mapButtons[map.key] = button
	end
	if Config.Bots.Enabled then
		heading(3, "🤖 Bots (they fill empty teams)")
		local bots = grid(4, 3)
		for order, key in Config.Bots.DifficultyOrder do
			local button = UI.button({
				LayoutOrder = order,
				TextSize = 16,
				Parent = bots,
			})
			button.Activated:Connect(function()
				Remotes.event("Vote"):FireServer("bots", key)
			end)
			botButtons[key] = button
		end
	end

	for _, attribute in { "MapVotes", "BotVotes" } do
		workspace:GetAttributeChangedSignal(attribute):Connect(refresh)
	end
	player:GetAttributeChangedSignal("MapVote"):Connect(refresh)
	player:GetAttributeChangedSignal("BotVote"):Connect(refresh)
	-- Voting closes when the match starts.
	workspace:GetAttributeChangedSignal("MatchPhase"):Connect(function()
		local phase = workspace:GetAttribute("MatchPhase")
		if phase ~= "waiting" and phase ~= "starting" then
			window.Visible = false
		end
	end)
	refresh()
end

return Vote
