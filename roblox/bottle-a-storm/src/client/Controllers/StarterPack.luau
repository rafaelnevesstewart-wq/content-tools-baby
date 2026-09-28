-- 🎁 The welcome window for brand-new players (StarterService sets
-- "StarterPack"): a gift to claim and the first things to try.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local StarterPack = {}

local STEPS = {
	"⚔️ Play a match: vote for a mode at the top, it starts by itself",
	"🛏️ Protect your bed with blocks, break the other teams' beds",
	"🧭 Talk to Guide Gale by the gate for a step-by-step quest",
	"🧙 Pick a class (the Class button next to the mode vote)",
	"📋 Everything else is in the Menu (or press M)",
}

function StarterPack.start()
	local screen = UI.screen("StarterPack", 12)
	local window = UI.new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.9, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = UI.Colors.Panel,
		Visible = false,
		Parent = screen,
	}, {
		UI.corner(18),
		UI.stroke(UI.Colors.Spark, 3),
		UI.padding(16),
		UI.list(8),
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(480, 600) }),
	})
	UI.label({
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 36),
		Text = "👋 Welcome to Bottle a Storm!",
		TextSize = 24,
		TextColor3 = UI.Colors.Spark,
		TextScaled = true,
		Parent = window,
	})
	UI.label({
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = "🎁 Your welcome gift: ⚡1,000 Sparks, a Rare kit and a 🦆 Duckling pet that heals you in matches!",
		TextSize = 16,
		TextWrapped = true,
		Parent = window,
	})
	UI.label({
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 22),
		Text = "What to do first:",
		TextSize = 16,
		TextColor3 = UI.Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = window,
	})
	for index, step in STEPS do
		UI.label({
			LayoutOrder = 3 + index,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = step,
			TextSize = 15,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = window,
		})
	end
	UI.button({
		LayoutOrder = 20,
		Size = UDim2.new(1, 0, 0, 46),
		Text = "🎁 Claim my gift & play!",
		TextSize = 19,
		BackgroundColor3 = UI.Colors.Good,
		Parent = window,
	}).Activated
		:Connect(function()
			Remotes.event("ClaimStarter"):FireServer()
			window.Visible = false
		end)
	local function refresh()
		if player:GetAttribute("StarterPack") and not player:GetAttribute("InMatch") then
			task.delay(2, function()
				if player:GetAttribute("StarterPack") then
					window.Visible = true
				end
			end)
		end
	end
	player:GetAttributeChangedSignal("StarterPack"):Connect(refresh)
	refresh()
end

return StarterPack
