-- 🐾 What your pet does for you in a match (PetHelperService sets
-- "PetHelp"), in the chips on the right.

local Players = game:GetService("Players")

local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local PetHelpChip = {}

function PetHelpChip.start()
	local chip = UI.label({
		LayoutOrder = 6,
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Color3.fromRGB(50, 110, 70),
		BackgroundTransparency = 0.15,
		TextSize = 14,
		Visible = false,
		Parent = UI.sideStack(),
	})
	UI.corner(8).Parent = chip
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = chip })
	local function refresh()
		local text = player:GetAttribute("PetHelp")
		chip.Visible = type(text) == "string"
		chip.Text = if type(text) == "string" then text else ""
	end
	player:GetAttributeChangedSignal("PetHelp"):Connect(refresh)
	refresh()
end

return PetHelpChip
