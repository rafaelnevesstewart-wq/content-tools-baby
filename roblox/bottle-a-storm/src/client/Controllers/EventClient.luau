-- 🎪 The Weekly Event on your screen: Low Gravity (your own screen runs your
-- character's physics, so the gravity is set here while you're in a match)
-- and a small banner in the lobby saying what this week's event is.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local EventData = require(Shared.EventData)

local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local EventClient = {}

local NORMAL_GRAVITY = 196.2

function EventClient.start()
	local chip = UI.label({
		LayoutOrder = 3,
		Size = UDim2.fromOffset(0, 28),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Color3.fromRGB(90, 50, 120),
		BackgroundTransparency = 0.15,
		TextSize = 15,
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
		local key = workspace:GetAttribute("WeeklyEvent")
		local event = nil
		for _, entry in EventData.List do
			if entry.key == key then
				event = entry
			end
		end
		chip.Visible = event ~= nil
		if event then
			chip.Text = "🎪 This week: " .. event.emoji .. " " .. event.name
		end
		local inMatch = player:GetAttribute("InMatch") == true
		local gravity = if inMatch and key == "LowGravity" then EventData.LowGravity else NORMAL_GRAVITY
		if workspace.Gravity ~= gravity then
			workspace.Gravity = gravity
		end
	end)
end

return EventClient
