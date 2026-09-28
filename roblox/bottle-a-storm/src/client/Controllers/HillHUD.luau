-- 👑 King of the Hill on your screen: who's holding the hill and every
-- team's points toward the target (HillService).

local HttpService = game:GetService("HttpService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local MatchData = require(Shared.MatchData)

local UI = require(script.Parent.UI)

local HillHUD = {}

function HillHUD.start()
	local screen = UI.screen("HillBar", 3)
	local bar = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 170),
		Size = UDim2.fromOffset(0, 34),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = screen,
	}, { UI.corner(10), UI.stroke(UI.Colors.Spark, 2), UI.padding(4), UI.list(6, Enum.FillDirection.Horizontal) })
	local function refresh()
		local raw = workspace:GetAttribute("HillScores")
		if type(raw) ~= "string" then
			bar.Visible = false
			return
		end
		local ok, scores = pcall(HttpService.JSONDecode, HttpService, raw)
		if not ok or type(scores) ~= "table" then
			return
		end
		bar.Visible = true
		for _, child in bar:GetChildren() do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end
		local holder = workspace:GetAttribute("HillHolder")
		local target = workspace:GetAttribute("HillTarget") or 150
		UI.label({
			LayoutOrder = 0,
			Size = UDim2.fromOffset(0, 26),
			AutomaticSize = Enum.AutomaticSize.X,
			Text = if holder == "contested"
				then "👑 Contested!"
				elseif holder == "" then "👑 Nobody on the hill"
				else "👑",
			TextSize = 16,
			Parent = bar,
		})
		for order, team in MatchData.Teams do
			local points = scores[team.key]
			if points then
				UI.label({
					LayoutOrder = order,
					Size = UDim2.fromOffset(0, 26),
					AutomaticSize = Enum.AutomaticSize.X,
					Text = (if holder == team.key then "▶ " else "") .. team.emoji .. " " .. points .. "/" .. target,
					TextSize = 16,
					TextColor3 = team.color,
					Parent = bar,
				})
			end
		end
	end
	workspace:GetAttributeChangedSignal("HillScores"):Connect(refresh)
	workspace:GetAttributeChangedSignal("HillHolder"):Connect(refresh)
	refresh()
end

return HillHUD
