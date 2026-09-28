-- 🪂 Gliders and parachutes in matches. Your own screen runs your character's
-- physics, so the flying happens here: with a Glider, hold jump while falling
-- to sail forward and sink slowly; while "Parachuting" (GadgetService opened
-- one after you fell off the map) you drift down gently. The server shows the
-- wings to everyone.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local GlideController = {}

local GLIDE_FALL = 10 -- the fastest you sink while gliding
local GLIDE_SPEED = 34 -- forward speed while gliding
local PARACHUTE_FALL = 12

function GlideController.start()
	local screen = UI.screen("Glide", 2)
	local chip = UI.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -150),
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Color3.fromRGB(40, 90, 140),
		BackgroundTransparency = 0.2,
		TextSize = 14,
		Visible = false,
		Parent = screen,
	})
	UI.corner(8).Parent = chip
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = chip })

	local gliding = false
	local function setGliding(on: boolean)
		if gliding ~= on then
			gliding = on
			Remotes.event("Glide"):FireServer(on)
		end
	end

	RunService.Heartbeat:Connect(function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local inMatch = player:GetAttribute("InMatch") == true
		local hasGlider = inMatch and player:GetAttribute("Glider") == true
		local parachutes = if inMatch then player:GetAttribute("Parachutes") else nil
		-- The reminder chip over the hotbar.
		local parts = {}
		if hasGlider then
			table.insert(parts, "🪂 Glider: hold jump while falling")
		end
		if type(parachutes) == "number" and parachutes > 0 then
			table.insert(parts, "⛱️ Parachutes: " .. parachutes)
		end
		chip.Visible = #parts > 0
		chip.Text = table.concat(parts, "   ")
		if not root or not humanoid or humanoid.Health <= 0 then
			setGliding(false)
			return
		end
		local v = root.AssemblyLinearVelocity
		if player:GetAttribute("Parachuting") then
			setGliding(false)
			if v.Y < -PARACHUTE_FALL then
				root.AssemblyLinearVelocity = Vector3.new(v.X, -PARACHUTE_FALL, v.Z)
			end
			return
		end
		local falling = humanoid.FloorMaterial == Enum.Material.Air and v.Y < -2
		local holding = humanoid.Jump or UserInputService:IsKeyDown(Enum.KeyCode.Space)
		local on = hasGlider and not player:GetAttribute("Mounted") and (holding and (falling or gliding))
		if on and humanoid.FloorMaterial ~= Enum.Material.Air then
			on = false
		end
		setGliding(on)
		if on then
			local move = humanoid.MoveDirection
			local ahead = if move.Magnitude > 0.1 then move.Unit else root.CFrame.LookVector
			local flat = Vector3.new(ahead.X, 0, ahead.Z)
			flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis
			root.AssemblyLinearVelocity = flat * GLIDE_SPEED + Vector3.new(0, math.max(v.Y, -GLIDE_FALL), 0)
		end
	end)
end

return GlideController
