-- 🏟️ The 2v2 Arena Cup on your screen (ArenaCupService): a chip at the top
-- right to join or leave while sign-ups are open, and, once it's running, to
-- open the bracket.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local ArenaCupClient = {}

local window: Frame
local list: ScrollingFrame

local function cup(): any
	local raw = workspace:GetAttribute("ArenaCup")
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, if type(raw) == "string" then raw else "")
	return if ok and type(decoded) == "table" then decoded else nil
end

local function fill(state: any)
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local order = 0
	local function line(text: string, color: Color3?, size: number?)
		order += 1
		UI.label({
			LayoutOrder = order,
			Size = UDim2.new(1, -8, 0, 26),
			Text = text,
			TextSize = size or 15,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = color or UI.Colors.Text,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = list,
		})
	end
	if not state or #state.rounds == 0 then
		line("Sign-ups: " .. (if state and #state.players > 0 then table.concat(state.players, ", ") else "nobody yet"))
		return
	end
	for index, round in state.rounds do
		line(if index == #state.rounds and #round == 1 then "🏆 Final" else "Round " .. index, UI.Colors.Spark, 17)
		for _, fight in round do
			local text = fight.a .. "  vs  " .. fight.b
			if fight.winner then
				text ..= "   →  " .. fight.winner .. " ✅"
			elseif fight.live then
				text ..= "   🔴 LIVE"
			end
			line(text)
		end
	end
end

function ArenaCupClient.start()
	local screen = UI.screen("ArenaCup", 8)
	local chip = UI.button({
		LayoutOrder = 1,
		Size = UDim2.fromOffset(0, 28),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Color3.fromRGB(190, 110, 40),
		TextSize = 14,
		Visible = false,
		Parent = UI.sideStack(),
	})
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = chip })

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
		UI.padding(12),
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(520, 480) }),
	})
	UI.label({
		Size = UDim2.new(1, -60, 0, 34),
		Text = "🏟️ 2v2 Arena Cup",
		TextSize = 22,
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
	}, { UI.list(2) })

	local joined = false
	chip.Activated:Connect(function()
		local state = cup()
		if state and state.state == "signup" then
			Remotes.event("ArenaCupAction"):FireServer(if joined then "leave" else "join")
		else
			window.Visible = not window.Visible
			fill(state)
		end
	end)
	workspace:GetAttributeChangedSignal("ArenaCup"):Connect(function()
		if window.Visible then
			fill(cup())
		end
	end)
	local last = 0
	RunService.Heartbeat:Connect(function()
		if os.clock() - last < 0.5 then
			return
		end
		last = os.clock()
		local state = cup()
		if not state or state.state == "idle" then
			chip.Visible = false
			window.Visible = false
			return
		end
		chip.Visible = true
		if state.state == "signup" then
			joined = table.find(state.players, player.DisplayName) ~= nil
			local left = math.max(0, (tonumber(state.signupEndsAt) or 0) - workspace:GetServerTimeNow())
			chip.Text = (
				if joined then "🏟️ You're in! (tap to leave) " else "🏟️ 2v2 Arena Cup: tap to join! "
			)
				.. Format.time(left)
				.. " · "
				.. #state.players
				.. " in"
		else
			chip.Text = "🏟️ Arena Cup is on! (tap for the bracket)"
		end
	end)
end

return ArenaCupClient
