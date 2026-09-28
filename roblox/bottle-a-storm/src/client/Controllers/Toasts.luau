-- Pop-up messages on the right side of the screen, kept calm:
--   * the same message twice in a row just bumps a "×2" on the first one
--   * only a few show at once
--   * 🔕 Fewer pop-ups (⚙️ Settings): messages meant for everyone (events,
--     other people's news) skip the pop-up unless they're a warning; your
--     own messages still pop up
--   * every message also goes in the 📜 Messages log (📋 Menu → Messages)

local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local Settings = require(script.Parent.Settings)
local Sfx = require(script.Parent.Sfx)
local UI = require(script.Parent.UI)

local KIND_SOUNDS = { success = "pop", rare = "chime", warn = "oops" }

local Toasts = {}

local MAX_TOASTS = 4
local SECONDS = 4.5
local LOG_SIZE = 60

local KIND_COLORS = {
	info = UI.Colors.Stroke,
	success = UI.Colors.Good,
	warn = UI.Colors.Warn,
	rare = UI.Colors.Rare,
}

type Entry = { text: string, kind: string, at: number }

local container: Frame
local order = 0
local log: { Entry } = {}
local logWindow: Frame
local logList: ScrollingFrame
local lastToast: { text: string, frame: Frame, label: TextLabel, count: number, at: number }? = nil

local function remember(text: string, kind: string)
	table.insert(log, 1, { text = text, kind = kind, at = os.clock() })
	while #log > LOG_SIZE do
		table.remove(log)
	end
end

function Toasts.show(text: string, kind: string?)
	local k = kind or "info"
	-- The same message again: bump a counter instead of stacking.
	local previous = lastToast
	if previous and previous.text == text and previous.frame.Parent and os.clock() - previous.at < SECONDS then
		previous.count += 1
		previous.at = os.clock()
		previous.label.Text = text .. "  ×" .. previous.count
		return
	end
	local sound = KIND_SOUNDS[k]
	if sound then
		Sfx.play(sound)
	end
	local color = KIND_COLORS[k] or UI.Colors.Stroke
	order += 1
	local toast = UI.new("Frame", {
		Name = "Toast",
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.1,
		Parent = container,
	}, { UI.corner(10), UI.stroke(color, 2.5), UI.padding(10) })
	local label = UI.label({
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = text,
		TextWrapped = true,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = if k == "rare" then UI.Colors.Spark else UI.Colors.Text,
		Parent = toast,
	})
	lastToast = { text = text, frame = toast, label = label, count = 1, at = os.clock() }

	local toasts = {}
	for _, child in container:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	table.sort(toasts, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = 1, #toasts - MAX_TOASTS do
		toasts[i]:Destroy()
	end

	task.delay(SECONDS, function()
		if toast.Parent then
			local info = TweenInfo.new(0.4)
			local fade = TweenService:Create(toast, info, { BackgroundTransparency = 1 })
			TweenService:Create(label, info, { TextTransparency = 1 }):Play()
			TweenService:Create(toast:FindFirstChildOfClass("UIStroke") :: UIStroke, info, { Transparency = 1 }):Play()
			fade:Play()
			fade.Completed:Wait()
			toast:Destroy()
		end
	end)
end

local function ago(seconds: number): string
	if seconds < 60 then
		return "just now"
	elseif seconds < 3600 then
		return math.floor(seconds / 60) .. "m ago"
	end
	return math.floor(seconds / 3600) .. "h ago"
end

local function fillLog()
	for _, child in logList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	if #log == 0 then
		UI.label({ Size = UDim2.new(1, -8, 0, 30), Text = "No messages yet.", TextSize = 15, Parent = logList })
	end
	for index, entry in log do
		local row = UI.new("Frame", {
			LayoutOrder = index,
			Size = UDim2.new(1, -8, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = UI.Colors.PanelLight,
			Parent = logList,
		}, { UI.corner(8), UI.padding(6), UI.stroke(KIND_COLORS[entry.kind] or UI.Colors.Stroke, 1.5) })
		UI.label({
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = entry.text .. "  ·  " .. ago(os.clock() - entry.at),
			TextSize = 14,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
	end
end

-- The 📜 Messages window: the last messages, newest first.
function Toasts.openLog()
	logWindow.Visible = not logWindow.Visible
	if logWindow.Visible then
		fillLog()
	end
end

function Toasts.start()
	local screen = UI.screen("Toasts", 20)
	container = UI.new("Frame", {
		Name = "Container",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.new(0.3, 0, 0.8, 0),
		BackgroundTransparency = 1,
		Parent = screen,
	}, {
		UI.list(8, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Right),
		UI.new("UISizeConstraint", { MinSize = Vector2.new(220, 0), MaxSize = Vector2.new(340, math.huge) }),
	})

	local logScreen = UI.screen("MessageLog", 8)
	logWindow = UI.new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.9, 0, 0.8, 0),
		BackgroundColor3 = UI.Colors.Panel,
		Visible = false,
		Parent = logScreen,
	}, {
		UI.corner(18),
		UI.stroke(UI.Colors.Stroke, 3),
		UI.padding(12),
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(520, 560) }),
	})
	UI.label({
		Size = UDim2.new(1, -60, 0, 32),
		Text = "📜 Messages",
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Spark,
		Parent = logWindow,
	})
	UI.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(44, 36),
		Text = "✕",
		TextSize = 20,
		BackgroundColor3 = UI.Colors.Bad,
		Parent = logWindow,
	}).Activated
		:Connect(function()
			logWindow.Visible = false
		end)
	logList = UI.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(1, 0, 1, -42),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = logWindow,
	}, { UI.list(4) })

	Remotes.event("Notify").OnClientEvent:Connect(function(text, kind, broadcast)
		local message = tostring(text)
		local k = if type(kind) == "string" then kind else "info"
		remember(message, k)
		if logWindow.Visible then
			fillLog()
		end
		-- 🔕 Fewer pop-ups: news for everyone goes to the log only (unless it's a warning).
		if broadcast == true and k ~= "warn" and Settings.get("quietMessages") then
			return
		end
		Toasts.show(message, k)
	end)
end

return Toasts
