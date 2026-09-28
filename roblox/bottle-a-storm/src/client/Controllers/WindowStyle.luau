-- 🎨 One look for every window: any Frame named "Window" on your screen gets
-- the same dark panel, rounded corners, blue border, gold title and red ✕
-- button, and pops in with a little bounce when it opens. Windows made
-- before or after this runs are both styled, so new windows match for free.
-- See-through windows (the emote wheel, photo mode) are left as they are.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local WindowStyle = {}

local CORNER = 18
local BORDER = 3
local POP = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local styled: { [Frame]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function isClose(item: Instance): boolean
	return item:IsA("TextButton") and (item.Text == "✕" or item.Text == "X" or item.Text == "✖")
end

local function styleClose(button: TextButton)
	button.BackgroundColor3 = UI.Colors.Bad
	button.TextColor3 = UI.Colors.Text
	button.Font = UI.Font
	local corner = button:FindFirstChildOfClass("UICorner") or UI.new("UICorner", { Parent = button })
	corner.CornerRadius = UDim.new(0, 10)
end

local function popIn(window: Frame)
	local scale = window:FindFirstChild("PopIn") :: UIScale?
	if not scale then
		return
	end
	scale.Scale = 0.9
	TweenService:Create(scale, POP, { Scale = 1 }):Play()
end

local function style(window: Frame)
	if styled[window] or window.BackgroundTransparency >= 0.9 then
		return
	end
	styled[window] = true
	window.BackgroundColor3 = UI.Colors.Panel
	local corner = window:FindFirstChildOfClass("UICorner") or UI.new("UICorner", { Parent = window })
	corner.CornerRadius = UDim.new(0, CORNER)
	local stroke = window:FindFirstChildOfClass("UIStroke") or UI.new("UIStroke", { Parent = window })
	stroke.Color = UI.Colors.Stroke
	stroke.Thickness = BORDER
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	-- The title: the first big text at the top of the window.
	for _, child in window:GetChildren() do
		if child:IsA("TextLabel") and child.TextSize >= 22 and child.Position.Y.Offset <= 8 then
			child.Font = Enum.Font.GothamBlack
			child.TextColor3 = UI.Colors.Spark
			break
		end
	end
	for _, item in window:GetDescendants() do
		if isClose(item) then
			styleClose(item :: TextButton)
		end
	end
	window.DescendantAdded:Connect(function(item)
		if isClose(item) then
			styleClose(item :: TextButton)
		end
	end)
	if not window:FindFirstChildOfClass("UIScale") then
		UI.new("UIScale", { Name = "PopIn", Parent = window })
		window:GetPropertyChangedSignal("Visible"):Connect(function()
			if window.Visible then
				popIn(window)
			end
		end)
		if window.Visible then
			popIn(window)
		end
	end
end

local function consider(item: Instance)
	if item.Name == "Window" and item:IsA("Frame") then
		-- Let the window finish building (its corner, border and title) first.
		task.defer(style, item)
	end
end

function WindowStyle.start()
	local gui = player:WaitForChild("PlayerGui")
	gui.DescendantAdded:Connect(consider)
	for _, item in gui:GetDescendants() do
		consider(item)
	end
end

return WindowStyle
