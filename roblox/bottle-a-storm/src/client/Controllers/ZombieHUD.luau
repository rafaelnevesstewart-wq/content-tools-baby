-- 🧟 Zombie Survival and 🏰 Castle Defense on your screen: the wave, monsters
-- left, and the countdown to the next wave (ZombieService shares them as
-- attributes).

local RunService = game:GetService("RunService")

local UI = require(script.Parent.UI)

local ZombieHUD = {}

function ZombieHUD.start()
	local screen = UI.screen("ZombieBar", 3)
	local label = UI.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 170),
		Size = UDim2.fromOffset(0, 34),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Color3.fromRGB(40, 60, 34),
		BackgroundTransparency = 0.1,
		TextSize = 18,
		Visible = false,
		Parent = screen,
	})
	UI.corner(10).Parent = label
	UI.stroke(Color3.fromRGB(130, 200, 100), 2).Parent = label
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), Parent = label })
	local last = 0
	RunService.Heartbeat:Connect(function()
		if os.clock() - last < 0.25 then
			return
		end
		last = os.clock()
		local wave = workspace:GetAttribute("ZombieWave")
		local total = workspace:GetAttribute("ZombieWaves")
		if type(wave) ~= "number" or type(total) ~= "number" then
			label.Visible = false
			return
		end
		label.Visible = true
		local breakUntil = workspace:GetAttribute("ZombieBreakUntil")
		local left = workspace:GetAttribute("ZombiesLeft") or 0
		local wait = if type(breakUntil) == "number" then breakUntil - workspace:GetServerTimeNow() else 0
		local castle = workspace:GetAttribute("HordeKind") == "Castle"
		local icon = if castle then "⛈️" else "🧟"
		if wait > 0 then
			label.Text = icon
				.. " Wave "
				.. wave + 1
				.. "/"
				.. total
				.. " in "
				.. math.ceil(wait)
				.. (if castle then "s: fix the walls!" else "s: build walls!")
		else
			label.Text = icon
				.. " Wave "
				.. wave
				.. "/"
				.. total
				.. "  ·  "
				.. left
				.. (if castle then " storm monsters left" else " zombies left")
		end
	end)
end

return ZombieHUD
