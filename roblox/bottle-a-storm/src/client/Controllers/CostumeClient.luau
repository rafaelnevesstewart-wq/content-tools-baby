-- 🎭 Costume parties on your screen (CostumeService): a button at the top
-- right with the theme and the time left, and a window to go look at every
-- dressed-up player and give them 1-5 stars while voting is on.

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local UI = require(script.Parent.UI)

local CostumeClient = {}

local STAR_ON = Color3.fromRGB(250, 196, 40)

local window: Frame
local title: TextLabel
local status: TextLabel
local list: ScrollingFrame

local function party(): any
	local raw = workspace:GetAttribute("Costume")
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, if type(raw) == "string" then raw else "")
	return if ok and type(decoded) == "table" then decoded else nil
end

local function call(action: string, userId: number?, stars: number?): (boolean, any)
	local ok, result, message = pcall(function()
		return Remotes.func("Costume"):InvokeServer(action, userId, stars)
	end)
	if not ok then
		return false, nil
	end
	return result, message
end

local fill: () -> ()

local function row(order: number, entry: any, voting: boolean)
	local frame = UI.new("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, 76),
		BackgroundColor3 = UI.Colors.PanelLight,
		Parent = list,
	}, { UI.corner(10), UI.padding(6) })
	UI.label({
		Size = UDim2.new(1, -96, 0, 26),
		Text = "🎭 " .. entry.name .. (if entry.you then " (you)" else ""),
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = frame,
	})
	UI.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(88, 28),
		Text = "👀 Look",
		TextSize = 14,
		BackgroundColor3 = UI.Colors.Stroke,
		Parent = frame,
	}).Activated
		:Connect(function()
			local _, message = call("look", entry.userId)
			if type(message) == "string" then
				status.Text = message
			end
		end)
	if entry.you or not voting then
		UI.label({
			Position = UDim2.fromOffset(0, 34),
			Size = UDim2.new(1, 0, 0, 28),
			Text = if entry.you then "You're in the costume party!" else "Voting starts when dressing up ends.",
			TextSize = 14,
			TextColor3 = UI.Colors.Muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = frame,
		})
		return
	end
	for stars = 1, 5 do
		local chosen = type(entry.stars) == "number" and stars <= entry.stars
		UI.button({
			Position = UDim2.fromOffset((stars - 1) * 46, 34),
			Size = UDim2.fromOffset(42, 30),
			Text = "⭐",
			TextSize = 16,
			BackgroundColor3 = if chosen then STAR_ON else UI.Colors.Track,
			Parent = frame,
		}).Activated
			:Connect(function()
				local _, message = call("vote", entry.userId, stars)
				fill()
				if type(message) == "string" then
					status.Text = message
				end
			end)
	end
end

fill = function()
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local info = call("info")
	if type(info) ~= "table" then
		return
	end
	title.Text = "🎭 Costume Party: " .. (if info.theme ~= "" then info.theme else "starting soon")
	if info.phase == "dress" then
		status.Text = "Dress up (🎨 Style) for the theme, then stand on the stage at the end of 🛍️ Shop Street!"
	elseif info.phase == "vote" then
		status.Text = "Look at each costume and give it stars. Voting pays ⚡ too!"
	else
		status.Text = "The next costume party starts soon."
	end
	if #info.entries == 0 then
		UI.label({
			Size = UDim2.new(1, -8, 0, 30),
			Text = if info.phase == "vote"
				then "Nobody else is on stage."
				else "Everyone on the stage shows up when voting starts.",
			TextSize = 15,
			TextColor3 = UI.Colors.Muted,
			Parent = list,
		})
	end
	for index, entry in info.entries do
		row(index, entry, info.phase == "vote")
	end
end

function CostumeClient.start()
	local screen = UI.screen("Costume", 3)
	local chip = UI.button({
		LayoutOrder = 1,
		Size = UDim2.fromOffset(0, 28),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Color3.fromRGB(170, 60, 140),
		TextSize = 14,
		Visible = false,
		Parent = UI.sideStack(),
	})
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = chip })

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
		UI.padding(12),
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(480, 560) }),
	})
	title = UI.label({
		Size = UDim2.new(1, -60, 0, 34),
		Text = "🎭 Costume Party",
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Spark,
		TextTruncate = Enum.TextTruncate.AtEnd,
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
	status = UI.label({
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 0, 36),
		Text = "",
		TextSize = 14,
		TextWrapped = true,
		TextColor3 = UI.Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = window,
	})
	list = UI.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 82),
		Size = UDim2.new(1, 0, 1, -82),
		BackgroundColor3 = UI.Colors.PanelLight,
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = window,
	}, { UI.corner(10), UI.padding(6), UI.list(4) })

	chip.Activated:Connect(function()
		window.Visible = not window.Visible
		if window.Visible then
			fill()
		end
	end)
	local lastPhase = nil
	local last = 0
	RunService.Heartbeat:Connect(function()
		if os.clock() - last < 0.5 then
			return
		end
		last = os.clock()
		local state = party()
		if not state or (state.phase ~= "dress" and state.phase ~= "vote") then
			chip.Visible = false
			window.Visible = false
			lastPhase = nil
			return
		end
		local left = math.max(0, (tonumber(state.endsAt) or 0) - workspace:GetServerTimeNow())
		chip.Visible = true
		chip.Text = (if state.phase == "vote" then "🎭 Vote on costumes! " else "🎭 Party: " .. state.theme .. " ")
			.. Format.time(left)
		if state.phase ~= lastPhase then
			lastPhase = state.phase
			if window.Visible then
				fill()
			end
		end
	end)
end

return CostumeClient
