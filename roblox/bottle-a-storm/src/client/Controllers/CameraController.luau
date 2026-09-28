-- The camera turns with the mouse, like most fighting games: the mouse is
-- locked to the middle of the screen (with a crosshair), the camera sits a
-- little over your right shoulder, and your character faces where you look.
-- Opening any window (Item Shop, Style, Rewards...) frees the mouse so you
-- can click. Hold Left Alt (or press Ctrl) to free it any time. Phones and
-- controllers keep Roblox's normal camera.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local CameraController = {}

local SHOULDER = Vector3.new(1.75, 0.3, 0)
local freed = false -- Ctrl toggles this

-- Is any game window open (every window is a Frame called "Window")?
local function windowOpen(): boolean
	local gui = player:FindFirstChildOfClass("PlayerGui")
	if not gui then
		return false
	end
	for _, screen in gui:GetChildren() do
		if screen:IsA("ScreenGui") and screen.Enabled then
			local window = screen:FindFirstChild("Window")
			if window and window:IsA("GuiObject") and window.Visible then
				return true
			end
		end
	end
	return false
end

local function usingMouse(): boolean
	return UserInputService.KeyboardEnabled
		and UserInputService.MouseEnabled
		and not UserInputService.TouchEnabled
		and not UserInputService.GamepadEnabled
end

function CameraController.start()
	if not UserInputService.MouseEnabled then
		return
	end
	local screen = UI.screen("Crosshair", 0)
	local crosshair = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(6, 6),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = screen,
	}, { UI.corner(3), UI.stroke(Color3.new(0, 0, 0), 1) })
	screen.IgnoreGuiInset = true
	local hint = UI.label({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -12),
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = "🖱️ Ctrl: free the mouse (or hold Alt)",
		TextSize = 14,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.4,
		Visible = false,
		Parent = screen,
	})

	UserInputService.InputBegan:Connect(function(input, processed)
		if
			not processed and (input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.RightControl)
		then
			freed = not freed
		end
	end)

	local wasLocked = false
	RunService:BindToRenderStep("BedWarsCamera", Enum.RenderPriority.Camera.Value + 1, function()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local camera = workspace.CurrentCamera
		local lock = usingMouse()
			and not freed
			and not UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt)
			and not windowOpen()
			and humanoid ~= nil
			and humanoid.Health > 0
			and root ~= nil
		if lock then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
			UserInputService.MouseIconEnabled = false
			crosshair.Visible = true
			hint.Text = "🖱️ Ctrl: free the mouse (or hold Alt)"
			hint.Visible = true
			local h = humanoid :: Humanoid
			local r = root :: BasePart
			h.AutoRotate = false
			h.CameraOffset = h.CameraOffset:Lerp(SHOULDER, 0.2)
			-- Face where the camera looks (flat, so you don't tip over).
			local look = camera.CFrame.LookVector * Vector3.new(1, 0, 1)
			if look.Magnitude > 0.01 then
				r.CFrame = CFrame.lookAt(r.Position, r.Position + look.Unit)
			end
			wasLocked = true
		elseif wasLocked then
			wasLocked = false
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
			crosshair.Visible = false
			hint.Text = "🖱️ Ctrl: lock the camera to the mouse again"
			hint.Visible = freed
			if humanoid then
				humanoid.AutoRotate = true
				humanoid.CameraOffset = Vector3.zero
			end
		end
	end)
end

return CameraController
