-- The boss's (🐉 Storm Dragon or 🐍 Sea Serpent) health bar at the top of the
-- screen while it's attacking (BossService shares "BossHealth", "BossMax"
-- and "BossName").

local TweenService = game:GetService("TweenService")

local UI = require(script.Parent.UI)

local BossHUD = {}

function BossHUD.start()
	local screen = UI.screen("BossBar", 3)
	local frame = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 170),
		Size = UDim2.new(0.5, 0, 0, 30),
		BackgroundColor3 = UI.Colors.Track,
		Visible = false,
		Parent = screen,
	}, {
		UI.corner(10),
		UI.stroke(Color3.fromRGB(190, 140, 255), 2),
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(520, 30) }),
	})
	local fill = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(150, 70, 230),
		Parent = frame,
	}, { UI.corner(10) })
	local text = UI.label({
		Size = UDim2.fromScale(1, 1),
		Text = "",
		TextSize = 16,
		TextStrokeTransparency = 0.3,
		Parent = frame,
	})
	local function refresh()
		local health = workspace:GetAttribute("BossHealth")
		local max = workspace:GetAttribute("BossMax")
		if type(health) ~= "number" or type(max) ~= "number" or max <= 0 then
			frame.Visible = false
			return
		end
		frame.Visible = true
		local name = workspace:GetAttribute("BossName")
		text.Text = (if type(name) == "string" then name else "🐉 Storm Dragon") .. "  " .. health .. " / " .. max
		TweenService:Create(fill, TweenInfo.new(0.2), { Size = UDim2.fromScale(math.clamp(health / max, 0, 1), 1) })
			:Play()
	end
	workspace:GetAttributeChangedSignal("BossHealth"):Connect(refresh)
	workspace:GetAttributeChangedSignal("BossMax"):Connect(refresh)
	refresh()
end

return BossHUD
