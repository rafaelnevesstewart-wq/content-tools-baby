-- 📅 What's next in the lobby (LobbyEventService shares "LobbyEvent"): a chip
-- at the top right, "Next: 🎭 Costume Party in 3:12", while nothing is on
-- (each event shows its own chip while it runs).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Format)

local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local LobbyEventChip = {}

function LobbyEventChip.start()
	local chip = UI.label({
		LayoutOrder = 7,
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.2,
		TextSize = 14,
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
		local raw = workspace:GetAttribute("LobbyEvent")
		local ok, state = pcall(HttpService.JSONDecode, HttpService, if type(raw) == "string" then raw else "")
		if not ok or type(state) ~= "table" or state.now or player:GetAttribute("InMatch") then
			chip.Visible = false
			return
		end
		local left = math.max(0, (tonumber(state.nextAt) or 0) - workspace:GetServerTimeNow())
		chip.Visible = true
		chip.Text = "📅 Next: " .. tostring(state.next) .. (if left > 0 then " in " .. Format.time(left) else " soon")
	end)
end

return LobbyEventChip
