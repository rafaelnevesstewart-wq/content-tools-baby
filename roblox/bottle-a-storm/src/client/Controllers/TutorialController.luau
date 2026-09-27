-- First-time help: until you've caught your first storm, a glowing arrow
-- points from you to the nearest wild storm (or to the Wild Skies if you're
-- far away), with a tip at the bottom of the screen.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local TutorialController = {}

local WILD_CENTER = Vector3.new(0, 6, 0)

local function nearestStorm(from: Vector3): BasePart?
	local folder = workspace:FindFirstChild("WildStorms")
	if not folder then
		return nil
	end
	local best: BasePart? = nil
	local bestDistance = 160
	for _, model in folder:GetChildren() do
		local root = model:IsA("Model") and model.PrimaryPart
		if root then
			local distance = (root.Position - from).Magnitude
			if distance < bestDistance then
				best = root
				bestDistance = distance
			end
		end
	end
	return best
end

local function done(): boolean
	local captured = player:GetAttribute("Captured")
	return type(captured) == "number" and captured > 0
end

function TutorialController.start()
	local target = Instance.new("Part")
	target.Name = "TutorialTarget"
	target.Anchored = true
	target.CanCollide = false
	target.CanTouch = false
	target.CanQuery = false
	target.Transparency = 1
	target.Size = Vector3.new(1, 1, 1)
	target.Parent = workspace
	local targetAttachment = Instance.new("Attachment")
	targetAttachment.Parent = target

	local startAttachment = Instance.new("Attachment")
	local beam = Instance.new("Beam")
	beam.Attachment1 = targetAttachment
	beam.FaceCamera = true
	beam.Width0 = 1.4
	beam.Width1 = 0.6
	beam.LightEmission = 1
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 225, 90), Color3.fromRGB(255, 140, 200))
	beam.Transparency = NumberSequence.new(0.1, 0.5)
	beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	beam.TextureMode = Enum.TextureMode.Wrap
	beam.TextureLength = 3
	beam.TextureSpeed = 2
	beam.Segments = 12
	beam.Enabled = false
	beam.Parent = target

	local screen = UI.screen("Tutorial", 2)
	local tip = UI.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -170),
		Size = UDim2.fromOffset(0, 40),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.05,
		TextSize = 19,
		Visible = false,
		Parent = screen,
	})
	UI.corner(20).Parent = tip
	UI.stroke(UI.Colors.Spark, 3).Parent = tip
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16), Parent = tip })

	local connection: RBXScriptConnection? = nil
	connection = RunService.Heartbeat:Connect(function()
		if done() then
			beam.Enabled = false
			tip.Visible = false
			target:Destroy()
			screen:Destroy()
			if connection then
				connection:Disconnect()
			end
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root or player:GetAttribute("Captured") == nil then
			beam.Enabled = false
			tip.Visible = false
			return
		end
		if startAttachment.Parent ~= root then
			startAttachment.Parent = root
			beam.Attachment0 = startAttachment
		end
		local storm = nearestStorm(root.Position)
		if storm then
			target.Position = storm.Position
			tip.Text = "🫙 Hold your Storm Jar (press 1) and click a storm to throw it!"
		else
			target.Position = WILD_CENTER
			tip.Text = "✨ Follow the sparkly arrow to the Wild Skies to catch storms!"
		end
		beam.Enabled = true
		tip.Visible = true
	end)
end

return TutorialController
