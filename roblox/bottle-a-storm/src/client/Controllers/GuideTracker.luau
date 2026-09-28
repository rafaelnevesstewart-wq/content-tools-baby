-- 🧭 Guide Gale's current step on your screen (in the chips on the right),
-- from the "GuideStep" attribute GuideService sets. Brand-new players are
-- told to go talk to her first.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GuideData = require(Shared.GuideData)

local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local GuideTracker = {}

function GuideTracker.start()
	local chip = UI.label({
		LayoutOrder = 2,
		Size = UDim2.fromOffset(0, 28),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Color3.fromRGB(40, 110, 160),
		BackgroundTransparency = 0.15,
		TextSize = 14,
		Visible = false,
		Parent = UI.sideStack(),
	})
	UI.corner(8).Parent = chip
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = chip })
	UI.new("UISizeConstraint", { MaxSize = Vector2.new(420, 28), Parent = chip })
	chip.TextTruncate = Enum.TextTruncate.AtEnd

	local function refresh()
		local step = player:GetAttribute("GuideStep")
		local total = #GuideData.Steps
		if type(step) ~= "number" or not GuideData.Steps[step] then
			chip.Visible = false
		elseif step == 1 then
			-- Only nudge brand-new players to start.
			chip.Visible = player:GetAttribute("GuideNew") == true
			chip.Text = "🧭 New? Talk to Guide Gale by the gate!"
		else
			chip.Visible = true
			chip.Text = "🧭 " .. step .. "/" .. total .. ": " .. GuideData.Steps[step].text
		end
	end
	player:GetAttributeChangedSignal("GuideStep"):Connect(refresh)
	player:GetAttributeChangedSignal("GuideNew"):Connect(refresh)
	refresh()
end

return GuideTracker
