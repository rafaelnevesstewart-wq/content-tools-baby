-- 📰 The news board in the castle courtyard: what's on right now (events,
-- the match, the Storm Dragon, tournaments, Admin Abuse...) and the latest
-- updates (NewsData). Your screen also shows the newest update once, the
-- first time you join after it (NewsPopup, saved as data.newsSeen).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local EventData = require(Shared.EventData)
local Format = require(Shared.Format)
local HolidayData = require(Shared.HolidayData)
local MapData = require(Shared.MapData)
local MatchData = require(Shared.MatchData)
local NewsData = require(Shared.NewsData)
local Remotes = require(Shared.Remotes)
local WeatherEvents = require(Shared.WeatherEvents)

local Modules = script.Parent.Parent.Modules
local WorldBuilder = require(Modules.WorldBuilder)

local DataService = require(script.Parent.DataService)

local NewsService = {}

local rows: { TextLabel } = {}

-- One line for everything happening right now.
local function happening(): { string }
	local now = workspace:GetServerTimeNow()
	local lines = {}
	local phase = workspace:GetAttribute("MatchPhase")
	if phase == "playing" then
		local mode = MatchData.mode(workspace:GetAttribute("MatchMode"))
		local map = MapData.get(workspace:GetAttribute("MapTheme"))
		table.insert(
			lines,
			"⚔️ Match on: "
				.. (if mode then mode.emoji .. " " .. mode.name else "Bed Wars")
				.. (if map then " on " .. map.emoji .. " " .. map.name else "")
		)
	elseif phase == "starting" then
		table.insert(lines, "⚔️ A match is about to start!")
	else
		table.insert(lines, "⚔️ Waiting for the next match")
	end
	if type(workspace:GetAttribute("BossHealth")) == "number" then
		table.insert(lines, "🐉 The Storm Dragon is attacking the middle island!")
	end
	local wave = workspace:GetAttribute("ZombieWave")
	if type(wave) == "number" and wave > 0 then
		table.insert(lines, "🧟 Zombie wave " .. wave .. "!")
	end
	local event = WeatherEvents.get(workspace:GetAttribute("WeatherEvent"))
	if event then
		table.insert(lines, event.emoji .. " " .. event.name .. " is on!")
	end
	local contestRaw = workspace:GetAttribute("Contest")
	local contestOk, contest =
		pcall(HttpService.JSONDecode, HttpService, if type(contestRaw) == "string" then contestRaw else "{}")
	if contestOk and type(contest) == "table" and contest.phase == "build" then
		table.insert(lines, "🎨 Build contest on Base Island: " .. tostring(contest.theme) .. "!")
	elseif contestOk and type(contest) == "table" and contest.phase == "vote" then
		table.insert(lines, "🎨 Vote in the build contest now!")
	end
	local weekly = EventData.current(os.time())
	table.insert(lines, "🎪 This week: " .. weekly.emoji .. " " .. weekly.name .. " in every match")
	local abuse = workspace:GetAttribute("AbuseUntil")
	if type(abuse) == "number" and abuse > now then
		table.insert(lines, "👑 ADMIN ABUSE: double Sparks for " .. Format.time(abuse - now) .. "!")
	end
	local holiday = HolidayData.active(os.time())
	if holiday then
		table.insert(lines, holiday.emoji .. " " .. holiday.name .. " event: special shop and decorations!")
	end
	local raw = workspace:GetAttribute("Tournament")
	local ok, tournament = pcall(HttpService.JSONDecode, HttpService, if type(raw) == "string" then raw else "{}")
	if ok and type(tournament) == "table" and tournament.state and tournament.state ~= "idle" then
		table.insert(lines, "🏆 A tournament is on in the lobby!")
	else
		local weekday = tonumber(os.date("!%w", os.time()))
		if weekday == 0 or weekday == 6 then
			table.insert(lines, "🏆 It's the weekend: tournaments every 30 minutes!")
		end
	end
	return lines
end

local function refresh()
	local lines = { "— 🔴 Right now —" }
	for _, line in happening() do
		table.insert(lines, line)
	end
	for index, news in NewsData.List do
		if index > 2 then
			break
		end
		table.insert(lines, "— " .. news.title .. " —")
		for _, line in news.lines do
			table.insert(lines, line)
		end
	end
	for index, row in rows do
		row.Text = lines[index] or ""
	end
end

local function build()
	local frame = WorldBuilder.LobbySpots.news
	local board = Instance.new("Part")
	board.Name = "NewsBoard"
	board.Anchored = true
	board.Size = Vector3.new(14, 11, 0.6)
	board.CFrame = frame * CFrame.new(0, 7.5, 0)
	board.Color = Color3.fromRGB(34, 38, 52)
	board.Material = Enum.Material.Slate
	board.Parent = workspace
	for _, x in { -6, 6 } do
		local post = Instance.new("Part")
		post.Anchored = true
		post.Size = Vector3.new(0.7, 2.5, 0.7)
		post.CFrame = board.CFrame * CFrame.new(x, -6.5, 0)
		post.Color = Color3.fromRGB(96, 70, 48)
		post.Material = Enum.Material.Wood
		post.Parent = board
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(560, 440)
	gui.LightInfluence = 0.1
	gui.Parent = board
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = gui
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 50)
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 210, 90)
	title.Text = "📰 Sky News"
	title.Parent = gui
	for i = 1, 16 do
		local row = Instance.new("TextLabel")
		row.LayoutOrder = i
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, -16, 0, 24)
		row.Font = Enum.Font.GothamBold
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = Color3.fromRGB(235, 238, 245)
		row.Text = ""
		row.Parent = gui
		table.insert(rows, row)
	end
end

function NewsService.start()
	build()
	Remotes.event("NewsSeen").OnServerEvent:Connect(function(player)
		local data = DataService.get(player)
		if data then
			data.newsSeen = NewsData.latest().version
			player:SetAttribute("NewsSeen", data.newsSeen)
		end
	end)
	DataService.ProfileLoaded:Connect(function(player, data)
		player:SetAttribute("NewsSeen", data.newsSeen or 0)
	end)
	for _, player in Players:GetPlayers() do
		local data = DataService.get(player)
		if data then
			player:SetAttribute("NewsSeen", data.newsSeen or 0)
		end
	end
	task.spawn(function()
		while true do
			pcall(refresh)
			task.wait(15)
		end
	end)
end

return NewsService
