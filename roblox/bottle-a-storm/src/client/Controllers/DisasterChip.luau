local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Lang = require(Shared.Lang)
-- 🌋 The disaster happening in your match right now (DisasterService sets
-- "Disaster"), in red at the top of the chips on the right.

local UI = require(script.Parent.UI)

local DisasterChip = {}

local NAMES = { Meteors = "chip.meteors", Quake = "chip.quake", Flood = "chip.flood" }

function DisasterChip.start()
	local chip = UI.label({
		LayoutOrder = -1,
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Color3.fromRGB(180, 50, 40),
		BackgroundTransparency = 0.05,
		TextSize = 16,
		Visible = false,
		Parent = UI.sideStack(),
	})
	UI.corner(8).Parent = chip
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = chip })
	local function refresh()
		local key = workspace:GetAttribute("Disaster")
		local text = if type(key) == "string" and NAMES[key] then Lang.t(NAMES[key]) else nil
		chip.Visible = text ~= nil
		chip.Text = text or ""
	end
	workspace:GetAttributeChangedSignal("Disaster"):Connect(refresh)
	refresh()
end

return DisasterChip
