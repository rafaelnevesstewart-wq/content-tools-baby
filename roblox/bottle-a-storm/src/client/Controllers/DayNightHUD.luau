-- ☀️ / 🌙 A small chip in a match: day or night, and the time of day
-- (WeatherService runs the cycle and shares "IsNight").

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local DayNightHUD = {}

function DayNightHUD.start()
	local chip = UI.label({
		LayoutOrder = 4,
		Size = UDim2.fromOffset(0, 28),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.25,
		TextSize = 15,
		Visible = false,
		Parent = UI.sideStack(),
	})
	UI.corner(8).Parent = chip
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = chip })
	local last = 0
	RunService.Heartbeat:Connect(function()
		if os.clock() - last < 0.5 then
			return
		end
		last = os.clock()
		chip.Visible = player:GetAttribute("InMatch") == true
		if not chip.Visible then
			return
		end
		local clock = Lighting.ClockTime
		local hours = math.floor(clock)
		local minutes = math.floor((clock - hours) * 60)
		local night = workspace:GetAttribute("IsNight") == true
		chip.Text = (if night then "🌙 Night  " else "☀️ Day  ") .. string.format("%d:%02d", hours, minutes)
	end)
end

return DayNightHUD
