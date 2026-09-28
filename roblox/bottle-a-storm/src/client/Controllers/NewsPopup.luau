-- 📰 "What's new" / 👋 "Welcome back": when you join after an update (or
-- after a day or more away) this window lists every update you missed and
-- what's waiting for you today. NewsService decides what goes in it (the
-- "WelcomeBack" attribute).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Lang = require(Shared.Lang)
local NewsData = require(Shared.NewsData)
local Remotes = require(Shared.Remotes)

local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local NewsPopup = {}

local shown = false

type Info = {
	days: number,
	updates: { number },
	daily: boolean?,
	treasure: boolean?,
	puzzles: boolean?,
	rule: string?,
}

local function read(): Info?
	local raw = player:GetAttribute("WelcomeBack")
	if type(raw) ~= "string" then
		return nil
	end
	local ok, info = pcall(HttpService.JSONDecode, HttpService, raw)
	if not ok or type(info) ~= "table" then
		return nil
	end
	return info
end

local function newsFor(version: number): NewsData.News?
	for _, news in NewsData.List do
		if news.version == version then
			return news
		end
	end
	return nil
end

local function show()
	local info = read()
	if shown or not info then
		return
	end
	shown = true
	local back = info.days >= 1
	local screen = UI.screen("NewsPopup", 12)
	local window = UI.new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.92, 0, 0.8, 0),
		BackgroundColor3 = UI.Colors.Panel,
		Parent = screen,
	}, {
		UI.corner(18),
		UI.stroke(UI.Colors.Stroke, 3),
		UI.padding(16),
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(480, 520) }),
	})
	UI.label({
		Size = UDim2.new(1, 0, 0, 32),
		Text = if back then Lang.t("back.title") else Lang.t("news.title"),
		TextSize = 26,
		TextColor3 = UI.Colors.Spark,
		Parent = window,
	})
	local body = UI.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 1, -96),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = window,
	}, {
		UI.list(6),
	})
	local order = 0
	local function line(text: string, size: number, color: Color3?)
		order += 1
		UI.label({
			LayoutOrder = order,
			Size = UDim2.new(1, -10, 0, size + 6),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = text,
			TextSize = size,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = color or UI.Colors.Text,
			Parent = body,
		})
	end
	if back then
		line(Lang.f("back.away", { days = info.days }), 17, UI.Colors.Muted)
	end
	if #info.updates > 0 and back then
		line(Lang.t("back.new"), 18, UI.Colors.Spark)
	end
	for index, version in info.updates do
		local news = newsFor(version)
		if news then
			line(news.title, if index == 1 then 19 else 16)
			-- The newest update in full, older ones as a short list.
			for lineIndex, text in news.lines do
				if index == 1 or lineIndex <= 2 then
					line("   " .. text, 14, UI.Colors.Muted)
				end
			end
		end
	end
	if back then
		local waiting = {}
		if info.daily then
			table.insert(waiting, Lang.t("back.daily"))
		end
		if info.treasure then
			table.insert(waiting, Lang.t("back.treasure"))
		end
		if info.puzzles then
			table.insert(waiting, Lang.t("back.puzzles"))
		end
		if info.rule then
			table.insert(waiting, Lang.f("back.rule", { rule = info.rule }))
		end
		if #waiting > 0 then
			line(Lang.t("back.waiting"), 18, UI.Colors.Good)
			for _, text in waiting do
				line("   " .. text, 15)
			end
		end
	end
	UI.button({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 46),
		Text = Lang.t("back.close") .. " 🎉",
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
	player:GetAttributeChangedSignal("WelcomeBack"):Connect(function()
		task.delay(3, show)
	end)
	task.delay(3, show)
end

return NewsPopup
