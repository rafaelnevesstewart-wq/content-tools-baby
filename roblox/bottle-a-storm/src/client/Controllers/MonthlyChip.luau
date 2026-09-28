-- 🏅 Your Season Points this month (MonthlyService sets "MonthlyPoints"),
-- in the chips on the right while you're in the lobby. The board in the
-- castle shows the world's top 10.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Format)
local Lang = require(Shared.Lang)

local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local MonthlyChip = {}

function MonthlyChip.start()
	local chip = UI.label({
		LayoutOrder = 5,
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Color3.fromRGB(70, 50, 110),
		BackgroundTransparency = 0.15,
		TextSize = 14,
		Visible = false,
		Parent = UI.sideStack(),
	})
	UI.corner(8).Parent = chip
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = chip })
	local function refresh()
		local points = player:GetAttribute("MonthlyPoints")
		chip.Visible = type(points) == "number" and not player:GetAttribute("InMatch")
		if type(points) == "number" then
			chip.Text = Lang.f("chip.season", { points = Format.number(points) })
		end
	end
	player:GetAttributeChangedSignal("MonthlyPoints"):Connect(refresh)
	player:GetAttributeChangedSignal("InMatch"):Connect(refresh)
	refresh()
end

return MonthlyChip
