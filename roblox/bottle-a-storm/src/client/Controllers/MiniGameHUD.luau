-- 🎯 / ⏱️ Games Island on your screen: your Target Range score and time
-- left, or your Parkour Race timer and checkpoints (MiniGameService).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local MiniGameHUD = {}

function MiniGameHUD.start()
	local screen = UI.screen("MiniGame", 3)
	local label = UI.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 120),
		Size = UDim2.fromOffset(0, 40),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.1,
		TextSize = 22,
		Visible = false,
		Parent = screen,
	})
	UI.corner(10).Parent = label
	UI.stroke(UI.Colors.Spark, 2).Parent = label
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16), Parent = label })
	RunService.Heartbeat:Connect(function()
		local now = workspace:GetServerTimeNow()
		local rangeEnds = player:GetAttribute("RangeEndsAt")
		local raceStarted = player:GetAttribute("RaceStartedAt")
		if type(rangeEnds) == "number" then
			label.Visible = true
			label.Text = "🎯 Score: "
				.. tostring(player:GetAttribute("RangeScore") or 0)
				.. "   ⏱️ "
				.. math.max(0, math.ceil(rangeEnds - now))
				.. "s"
		elseif type(raceStarted) == "number" then
			label.Visible = true
			label.Text = string.format(
				"⏱️ %.1fs   🚩 %d/2",
				now - raceStarted,
				tonumber(player:GetAttribute("RaceCheckpoint")) or 0
			)
		else
			label.Visible = false
		end
	end)
end

return MiniGameHUD
