-- Pop-up messages on the right side of the screen.

local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local UI = require(script.Parent.UI)

local Toasts = {}

local MAX_TOASTS = 5
local SECONDS = 4.5

local KIND_COLORS = {
	info = UI.Colors.Stroke,
	success = UI.Colors.Good,
	warn = UI.Colors.Warn,
	rare = UI.Colors.Rare,
}

local container: Frame
local order = 0

function Toasts.show(text: string, kind: string?)
	local color = KIND_COLORS[kind or "info"] or UI.Colors.Stroke
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
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = if kind == "rare" then UI.Colors.Spark else UI.Colors.Text,
		Parent = toast,
	})

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
		UI.new("UISizeConstraint", { MinSize = Vector2.new(220, 0), MaxSize = Vector2.new(360, math.huge) }),
	})

	Remotes.event("Notify").OnClientEvent:Connect(function(text, kind)
		Toasts.show(tostring(text), kind)
	end)
end

return Toasts
