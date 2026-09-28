-- 📰 "What's new": the newest update (NewsData) pops up once, the first
-- time you join after it.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local NewsData = require(Shared.NewsData)
local Remotes = require(Shared.Remotes)

local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local NewsPopup = {}

local shown = false

local function show()
	local seen = player:GetAttribute("NewsSeen")
	local news = NewsData.latest()
	if shown or type(seen) ~= "number" or seen >= news.version then
		return
	end
	shown = true
	local screen = UI.screen("NewsPopup", 12)
	local window = UI.new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.92, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = UI.Colors.Panel,
		Parent = screen,
	}, {
		UI.corner(18),
		UI.stroke(UI.Colors.Spark, 3),
		UI.padding(16),
		UI.list(8),
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(460, math.huge) }),
	})
	UI.label({
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 30),
		Text = "📰 What's new",
		TextSize = 26,
		TextColor3 = UI.Colors.Spark,
		Parent = window,
	})
	UI.label({
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 26),
		Text = news.title,
		TextSize = 19,
		TextWrapped = true,
		Parent = window,
	})
	for index, line in news.lines do
		UI.label({
			LayoutOrder = 2 + index,
			Size = UDim2.new(1, 0, 0, 22),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = line,
			TextSize = 15,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = window,
		})
	end
	UI.button({
		LayoutOrder = 99,
		Size = UDim2.new(1, 0, 0, 44),
		Text = "Let's play! 🎉",
		TextSize = 19,
		BackgroundColor3 = UI.Colors.Good,
		Parent = window,
	}).Activated
		:Connect(function()
			Remotes.event("NewsSeen"):FireServer()
			screen:Destroy()
		end)
end

function NewsPopup.start()
	player:GetAttributeChangedSignal("NewsSeen"):Connect(function()
		task.delay(3, show)
	end)
	task.delay(3, show)
end

return NewsPopup
