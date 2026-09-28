-- 💬 The taunt picker: press T (or the 💬 button) and pick a line to say
-- (TauntService shows it over your head). Other players' bubbles can be
-- hidden in ⚙️ Settings.

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local TauntData = require(Shared.TauntData)

local Settings = require(script.Parent.Settings)
local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local TauntPicker = {}

local window: Frame

function TauntPicker.toggle()
	window.Visible = not window.Visible
end

local function applyVisibility(bubble: Instance)
	if bubble:IsA("BillboardGui") and bubble:GetAttribute("OwnerId") ~= player.UserId then
		bubble.Enabled = Settings.get("taunts") == true
	end
end

function TauntPicker.start()
	local screen = UI.screen("Taunts", 9)
	window = UI.new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 72, 1, if UserInputService.TouchEnabled then -210 else -12),
		Size = UDim2.fromOffset(230, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = UI.Colors.Panel,
		Visible = false,
		Parent = screen,
	}, { UI.corner(14), UI.stroke(UI.Colors.Stroke, 2), UI.padding(8), UI.list(4) })
	UI.label({
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 24),
		Text = "💬 Say something (T)",
		TextSize = 16,
		TextColor3 = UI.Colors.Spark,
		Parent = window,
	})
	for order, taunt in TauntData.List do
		UI.button({
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 32),
			Text = taunt.text,
			TextSize = 15,
			Parent = window,
		}).Activated
			:Connect(function()
				Remotes.event("Taunt"):FireServer(taunt.key)
				window.Visible = false
			end)
	end
	UI.button({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, if UserInputService.TouchEnabled then -270 else -72),
		Size = UDim2.fromOffset(52, 52),
		Text = "💬",
		TextSize = 26,
		Parent = screen,
	}).Activated
		:Connect(TauntPicker.toggle)
	ContextActionService:BindAction("BottleAStormTaunts", function(_, state)
		if state == Enum.UserInputState.Begin then
			TauntPicker.toggle()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.T)

	for _, bubble in CollectionService:GetTagged("TauntBubble") do
		applyVisibility(bubble)
	end
	CollectionService:GetInstanceAddedSignal("TauntBubble"):Connect(applyVisibility)
end

return TauntPicker
