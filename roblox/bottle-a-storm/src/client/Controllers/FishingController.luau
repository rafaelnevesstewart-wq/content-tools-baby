-- 🎣 Fishing on your screen: with the Fishing Rod out, click the water to
-- cast; when the bobber dips ("❗ BITE!") click again fast to reel it in
-- (FishingService decides what you catch).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local Aim = require(script.Parent.Aim)
local Sfx = require(script.Parent.Sfx)
local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local FishingController = {}

function FishingController.start()
	local screen = UI.screen("Fishing", 3)
	local label = UI.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -170),
		Size = UDim2.fromOffset(0, 40),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.15,
		TextSize = 20,
		Visible = false,
		Parent = screen,
	})
	UI.corner(10).Parent = label
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), Parent = label })

	local lastClick = 0
	Aim.hookTool("Fishing Rod", function()
		if os.clock() - lastClick < 0.3 then
			return
		end
		lastClick = os.clock()
		if player:GetAttribute("FishState") then
			Remotes.event("Fish"):FireServer("reel")
		else
			Sfx.play("throw", 0.8)
			Remotes.event("Fish"):FireServer("cast", Aim.point({}, 0))
		end
	end)

	player:GetAttributeChangedSignal("FishState"):Connect(function()
		if player:GetAttribute("FishState") == "bite" then
			Sfx.play("zap", 1.3)
		end
	end)
	RunService.Heartbeat:Connect(function()
		local character = player.Character
		local holding = character ~= nil and character:FindFirstChild("Fishing Rod") ~= nil
		local state = player:GetAttribute("FishState")
		label.Visible = holding
		if state == "bite" then
			label.Text = "❗ A BITE! CLICK NOW!"
			label.BackgroundColor3 = UI.Colors.Bad
		elseif state == "waiting" then
			label.Text = "🎣 Waiting for a bite... (wait for the bobber to dip)"
			label.BackgroundColor3 = UI.Colors.Panel
		else
			label.Text = "🎣 Click the water to cast"
			label.BackgroundColor3 = UI.Colors.Panel
		end
	end)
end

return FishingController
