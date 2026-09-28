-- 🗺️ Your next treasure hunt clue (TreasureService sets "TreasureClue"), in
-- the chips on the right while you're in the lobby.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local TreasureData = require(Shared.TreasureData)

local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local TreasureChip = {}

function TreasureChip.start()
	local chip = UI.label({
		LayoutOrder = 3,
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Color3.fromRGB(120, 84, 40),
		BackgroundTransparency = 0.15,
		TextSize = 14,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Visible = false,
		Parent = UI.sideStack(),
	})
	UI.corner(8).Parent = chip
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = chip })
	UI.new("UISizeConstraint", { MaxSize = Vector2.new(440, 26), Parent = chip })
	local function refresh()
		local clue = player:GetAttribute("TreasureClue")
		local step = player:GetAttribute("TreasureStep")
		chip.Visible = type(clue) == "string" and not player:GetAttribute("InMatch")
		if type(clue) == "string" then
			chip.Text = "🗺️ Treasure " .. tostring(step) .. "/" .. TreasureData.PerDay .. ": " .. clue
		end
	end
	for _, name in { "TreasureClue", "TreasureStep", "InMatch" } do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	refresh()
end

return TreasureChip
