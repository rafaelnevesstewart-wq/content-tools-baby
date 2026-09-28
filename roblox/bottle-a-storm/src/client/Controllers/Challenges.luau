-- The 🌟 Challenges window: today's Daily Challenge, this week's 5 Weekly
-- Challenges with progress bars and Claim buttons, and the weekly bonus for
-- finishing them all (ChallengeService).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local UI = require(script.Parent.UI)

local Challenges = {}

local window: Frame
local list: ScrollingFrame
local reload: () -> ()

-- 93784 -> "1d 2h", 7260 -> "2h 1m"
local function timeLeft(seconds: number): string
	local days = seconds // 86400
	local hours = (seconds % 86400) // 3600
	local minutes = (seconds % 3600) // 60
	if days > 0 then
		return days .. "d " .. hours .. "h"
	end
	return hours .. "h " .. minutes .. "m"
end

local function clear()
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function heading(order: number, text: string, color: Color3?)
	UI.label({
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, 26),
		Text = text,
		TextSize = 17,
		TextColor3 = color or UI.Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = list,
	})
end

local function claim(which: any)
	local ok, result = pcall(function()
		return Remotes.func("ClaimChallenge"):InvokeServer(which)
	end)
	if ok then
		reload()
	end
	return result
end

-- One challenge card: text, a progress bar and a Claim button.
local function card(order: number, entry: any, which: any)
	local frame = UI.new("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, 64),
		BackgroundColor3 = UI.Colors.PanelLight,
		Parent = list,
	}, { UI.corner(10), UI.padding(8) })
	UI.label({
		Size = UDim2.new(1, -110, 0, 24),
		Text = entry.text,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = frame,
	})
	local bar = UI.new("Frame", {
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, -110, 0, 16),
		BackgroundColor3 = UI.Colors.Track,
		Parent = frame,
	}, { UI.corner(8) })
	UI.new("Frame", {
		Size = UDim2.fromScale(math.clamp(entry.progress / math.max(1, entry.target), 0, 1), 1),
		BackgroundColor3 = if entry.progress >= entry.target then UI.Colors.Good else UI.Colors.Stroke,
		Parent = bar,
	}, { UI.corner(8) })
	UI.label({
		Size = UDim2.fromScale(1, 1),
		Text = Format.number(entry.progress) .. " / " .. Format.number(entry.target),
		TextSize = 12,
		Parent = bar,
	})
	local done = entry.progress >= entry.target
	local button = UI.button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(98, 38),
		Text = if entry.claimed then "✅ Done" elseif done then "Claim!" else "…",
		TextSize = 16,
		BackgroundColor3 = if entry.claimed
			then UI.Colors.Disabled
			elseif done then UI.Colors.Good
			else UI.Colors.Disabled,
		Parent = frame,
	})
	if done and not entry.claimed then
		button.Activated:Connect(function()
			claim(which)
		end)
	end
end

local function show(state: any)
	clear()
	if type(state) ~= "table" then
		heading(1, "Still loading. Try again in a moment!")
		return
	end
	heading(1, "☀️ Daily Challenge  ·  new in " .. timeLeft(state.dayEndsIn), UI.Colors.Spark)
	heading(2, "Reward: " .. state.rewards.daily)
	card(3, state.daily, "daily")
	heading(4, "📅 Weekly Challenges  ·  new in " .. timeLeft(state.weekEndsIn), UI.Colors.Spark)
	heading(5, "Each: " .. state.rewards.weekly)
	for index, entry in state.weekly do
		card(5 + index, entry, index)
	end
	heading(20, "🏆 Finish them all: " .. state.rewards.bonus)
	local bonus = UI.button({
		LayoutOrder = 21,
		Size = UDim2.new(1, -8, 0, 44),
		Text = if state.bonusClaimed
			then "✅ Weekly bonus claimed!"
			elseif state.bonusReady then "🎁 Claim the weekly bonus!"
			else "🔒 Claim all 5 weekly challenges first",
		TextSize = 17,
		BackgroundColor3 = if state.bonusReady then UI.Colors.Spark else UI.Colors.Disabled,
		Parent = list,
	})
	if state.bonusReady then
		bonus.Activated:Connect(function()
			claim("bonus")
		end)
	end
end

reload = function()
	task.spawn(function()
		local ok, state = pcall(function()
			return Remotes.func("GetChallenges"):InvokeServer()
		end)
		if window.Visible then
			show(if ok then state else nil)
		end
	end)
end

function Challenges.toggle()
	window.Visible = not window.Visible
	if window.Visible then
		clear()
		heading(1, "Loading...")
		reload()
	end
end

function Challenges.start()
	local screen = UI.screen("Challenges", 7)
	window = UI.new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.9, 0, 0.85, 0),
		BackgroundColor3 = UI.Colors.Panel,
		Visible = false,
		Parent = screen,
	}, {
		UI.corner(18),
		UI.stroke(UI.Colors.Stroke, 3),
		UI.padding(14),
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(540, 640) }),
	})
	UI.label({
		Size = UDim2.new(1, -60, 0, 34),
		Text = "🌟 Challenges",
		TextSize = 28,
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

return Challenges
