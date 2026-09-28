-- 🏆 Tournament on your screen: during sign-ups a card with a countdown and
-- a Join button; during the tournament the fight that's on now and a
-- Bracket button that shows every round (TournamentService).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local TournamentHUD = {}

local card: Frame
local info: TextLabel
local joinButton: TextButton
local bracketButton: TextButton
local window: Frame
local list: ScrollingFrame
local data: any = { state = "idle" }

local function roundName(index: number, total: number): string
	if index == total then
		return "🏆 Final"
	elseif index == total - 1 then
		return "Semifinals"
	elseif index == total - 2 then
		return "Quarterfinals"
	end
	return "Round " .. index
end

local function joined(): boolean
	return table.find(data.entrants or {}, player.DisplayName) ~= nil
end

local function buildBracket()
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local order = 0
	local rounds = data.rounds or {}
	if #rounds == 0 then
		UI.label({
			Size = UDim2.new(1, -8, 0, 30),
			Text = "The bracket appears when sign-ups close.",
			TextSize = 16,
			TextColor3 = UI.Colors.Muted,
			Parent = list,
		})
	end
	for index, round in rounds do
		order += 1
		UI.label({
			LayoutOrder = order,
			Size = UDim2.new(1, -8, 0, 26),
			Text = roundName(index, #rounds),
			TextSize = 18,
			TextColor3 = UI.Colors.Spark,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = list,
		})
		for _, fight in round do
			order += 1
			local row = UI.new("Frame", {
				LayoutOrder = order,
				Size = UDim2.new(1, -8, 0, 36),
				BackgroundColor3 = if fight.live then Color3.fromRGB(120, 60, 30) else UI.Colors.PanelLight,
				Parent = list,
			}, { UI.corner(8), UI.padding(6) })
			local function side(name: string, x: number, align: Enum.TextXAlignment)
				local won = fight.winner == name
				UI.label({
					Position = UDim2.fromScale(x, 0),
					Size = UDim2.new(0.45, 0, 1, 0),
					Text = (if won then "✅ " else "") .. name,
					TextSize = 16,
					TextColor3 = if won then UI.Colors.Good elseif fight.winner then UI.Colors.Muted else UI.Colors.Text,
					TextXAlignment = align,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Parent = row,
				})
			end
			side(fight.a, 0, Enum.TextXAlignment.Left)
			UI.label({
				Position = UDim2.fromScale(0.45, 0),
				Size = UDim2.new(0.1, 0, 1, 0),
				Text = if fight.live then "⚔️" else "vs",
				TextSize = 15,
				TextColor3 = UI.Colors.Muted,
				Parent = row,
			})
			side(fight.b, 0.55, Enum.TextXAlignment.Right)
		end
	end
end

local function refresh()
	local raw = workspace:GetAttribute("Tournament")
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, if type(raw) == "string" then raw else "{}")
	data = if ok and type(decoded) == "table" then decoded else { state = "idle" }
	card.Visible = data.state == "signup" or data.state == "running"
	joinButton.Visible = data.state == "signup"
	bracketButton.Visible = data.state == "running"
	joinButton.Text = if joined() then "Leave" else "🏆 Join!"
	joinButton.BackgroundColor3 = if joined() then UI.Colors.Bad else UI.Colors.Good
	if data.state == "idle" then
		window.Visible = false
	elseif window.Visible then
		buildBracket()
	end
end

local function updateText()
	if data.state == "signup" then
		local left = math.max(0, math.ceil((data.signupEndsAt or 0) - workspace:GetServerTimeNow()))
		info.Text = "🏆 Tournament sign-ups: "
			.. left
			.. "s  ·  "
			.. #(data.entrants or {})
			.. "/"
			.. (data.max or 8)
			.. " joined"
	elseif data.state == "running" then
		local live = nil
		for _, round in data.rounds or {} do
			for _, fight in round do
				if fight.live then
					live = fight
				end
			end
		end
		info.Text = if live
			then "🏆 Now fighting: " .. live.a .. " vs " .. live.b
			else "🏆 Tournament: next fight soon..."
	end
end

function TournamentHUD.start()
	local screen = UI.screen("Tournament", 5)
	card = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 120),
		Size = UDim2.fromOffset(0, 44),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = screen,
	}, {
		UI.corner(12),
		UI.stroke(UI.Colors.Spark, 2),
		UI.padding(6),
		UI.list(8, Enum.FillDirection.Horizontal),
	})
	info = UI.label({
		LayoutOrder = 1,
		Size = UDim2.fromOffset(0, 32),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = 17,
		Parent = card,
	})
	joinButton = UI.button({
		LayoutOrder = 2,
		Size = UDim2.fromOffset(96, 32),
		TextSize = 16,
		Parent = card,
	})
	joinButton.Activated:Connect(function()
		Remotes.event("TournamentAction"):FireServer(if joined() then "leave" else "join")
	end)
	bracketButton = UI.button({
		LayoutOrder = 3,
		Size = UDim2.fromOffset(110, 32),
		Text = "📋 Bracket",
		TextSize = 16,
		Parent = card,
	})
	bracketButton.Activated:Connect(function()
		window.Visible = not window.Visible
		if window.Visible then
			buildBracket()
		end
	end)

	window = UI.new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.9, 0, 0.75, 0),
		BackgroundColor3 = UI.Colors.Panel,
		Visible = false,
		Parent = screen,
	}, {
		UI.corner(18),
		UI.stroke(UI.Colors.Stroke, 3),
		UI.padding(14),
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(460, 520) }),
	})
	UI.label({
		Size = UDim2.new(1, -60, 0, 34),
		Text = "🏆 Tournament Bracket",
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

	workspace:GetAttributeChangedSignal("Tournament"):Connect(refresh)
	refresh()
	local last = 0
	RunService.Heartbeat:Connect(function()
		if os.clock() - last > 0.25 then
			last = os.clock()
			if card.Visible then
				updateText()
			end
		end
	end)
end

return TournamentHUD
