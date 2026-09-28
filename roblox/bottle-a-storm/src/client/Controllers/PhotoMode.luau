-- 📸 Photo mode (in the lobby): press 📸 (or P). Everything else on screen
-- hides, your character holds still, and the camera circles around you:
-- drag to turn it, scroll (or ➕ ➖) to zoom. Pick a pose, a frame and a
-- color filter, then 📷 Snap to save the picture (or use your device's own
-- screenshot). ✕ or P again to leave.

local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local PhotoMode = {}

type Pose = { name: string, id: string, hold: number? }

-- Roblox's own R15 emotes; `hold` freezes the pose after that many seconds.
local POSES: { Pose } = {
	{ name = "🧍 Stand", id = "" },
	{ name = "👋 Wave", id = "rbxassetid://507770239", hold = 0.55 },
	{ name = "👉 Point", id = "rbxassetid://507770453", hold = 0.6 },
	{ name = "🙌 Cheer", id = "rbxassetid://507770677", hold = 0.5 },
	{ name = "😂 Laugh", id = "rbxassetid://507770818", hold = 0.4 },
	{ name = "💃 Dance", id = "rbxassetid://507771019" },
	{ name = "🪑 Sit", id = "rbxassetid://2506281703" },
}

local FRAMES = { "None", "✨ Sparkle", "🌪️ Storm", "🎞️ Film", "🏆 Champion" }

local FILTERS: { { name: string, props: { [string]: any } } } = {
	{ name = "None", props = { Brightness = 0, Contrast = 0, Saturation = 0, TintColor = Color3.new(1, 1, 1) } },
	{
		name = "☀️ Warm",
		props = { Brightness = 0.03, Contrast = 0.05, Saturation = 0.1, TintColor = Color3.fromRGB(255, 232, 205) },
	},
	{
		name = "❄️ Cool",
		props = { Brightness = 0, Contrast = 0.05, Saturation = -0.05, TintColor = Color3.fromRGB(210, 228, 255) },
	},
	{
		name = "🖤 B&W",
		props = { Brightness = 0, Contrast = 0.15, Saturation = -1, TintColor = Color3.new(1, 1, 1) },
	},
	{
		name = "🌈 Vivid",
		props = { Brightness = 0.02, Contrast = 0.2, Saturation = 0.45, TintColor = Color3.new(1, 1, 1) },
	},
	{
		name = "💭 Dreamy",
		props = { Brightness = 0.08, Contrast = -0.1, Saturation = 0.1, TintColor = Color3.fromRGB(255, 225, 245) },
	},
}

local active = false
local yaw, pitch, distance = 0, 0.15, 10
local dragging = false
local hidden: { ScreenGui } = {}
local track: AnimationTrack? = nil
local screen: ScreenGui
local window: Frame
local panel: Frame
local overlay: Frame
local toggleButton: TextButton
local filterEffect: ColorCorrectionEffect? = nil
local poseIndex, frameIndex, filterIndex = 1, 1, 1

local function stopPose()
	if track then
		track:Stop(0.2)
		track = nil
	end
end

local function playPose(pose: Pose)
	stopPose()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator or pose.id == "" then
		return
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = pose.id
	local ok, loaded = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if not ok or not loaded then
		return
	end
	local newTrack = loaded :: AnimationTrack
	newTrack.Priority = Enum.AnimationPriority.Action4
	newTrack.Looped = pose.hold == nil
	newTrack:Play(0.2)
	track = newTrack
	if pose.hold then
		task.delay(pose.hold, function()
			if track == newTrack then
				newTrack:AdjustSpeed(0)
			end
		end)
	end
end

-- Decorations drawn over the whole screen.
local function drawFrame()
	for _, child in overlay:GetChildren() do
		child:Destroy()
	end
	local kind = FRAMES[frameIndex]
	local function border(color: Color3, thickness: number)
		UI.new("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Parent = overlay,
		}, { UI.stroke(color, thickness) })
	end
	local function corners(text: string)
		for _, spot in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
			UI.label({
				AnchorPoint = spot,
				Position = UDim2.new(spot.X, if spot.X == 0 then 18 else -18, spot.Y, if spot.Y == 0 then 18 else -18),
				Size = UDim2.fromOffset(48, 48),
				Text = text,
				TextSize = 40,
				Parent = overlay,
			})
		end
	end
	local function caption(text: string, color: Color3)
		UI.label({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -24),
			Size = UDim2.fromOffset(0, 40),
			AutomaticSize = Enum.AutomaticSize.X,
			Text = text,
			TextSize = 28,
			TextColor3 = color,
			TextStrokeTransparency = 0.2,
			Parent = overlay,
		})
	end
	if kind == "✨ Sparkle" then
		border(Color3.new(1, 1, 1), 10)
		corners("✨")
	elseif kind == "🌪️ Storm" then
		border(Color3.fromRGB(40, 60, 120), 16)
		corners("⚡")
		caption("🌪️ Bottle a Storm", Color3.fromRGB(180, 220, 255))
	elseif kind == "🎞️ Film" then
		for _, top in { true, false } do
			UI.new("Frame", {
				AnchorPoint = Vector2.new(0, if top then 0 else 1),
				Position = UDim2.fromScale(0, if top then 0 else 1),
				Size = UDim2.fromScale(1, 0.12),
				BackgroundColor3 = Color3.new(0, 0, 0),
				BorderSizePixel = 0,
				Parent = overlay,
			})
		end
	elseif kind == "🏆 Champion" then
		border(Color3.fromRGB(240, 196, 70), 14)
		corners("🏆")
		caption("🏆 " .. player.DisplayName .. " · Bottle a Storm: Bed Wars", Color3.fromRGB(255, 225, 120))
	end
end

local function applyFilter()
	if not filterEffect then
		local effect = Instance.new("ColorCorrectionEffect")
		effect.Name = "PhotoFilter"
		effect.Parent = Lighting
		filterEffect = effect
	end
	local effect = filterEffect :: ColorCorrectionEffect
	effect.Enabled = active and filterIndex > 1
	for key, value in FILTERS[filterIndex].props do
		(effect :: any)[key] = value
	end
end

local function freeze(_name: string, _state: Enum.UserInputState): Enum.ContextActionResult
	return Enum.ContextActionResult.Sink
end

local function setActive(on: boolean)
	if on == active then
		return
	end
	if on and player:GetAttribute("InMatch") then
		return
	end
	active = on
	local camera = workspace.CurrentCamera
	local gui = player:FindFirstChildOfClass("PlayerGui")
	if on then
		-- Start in front of you, looking at your face.
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local look = root.CFrame.LookVector
			yaw = math.atan2(look.X, look.Z)
		end
		pitch, distance = 0.15, 10
		hidden = {}
		if gui then
			for _, other in gui:GetChildren() do
				if other:IsA("ScreenGui") and other ~= screen and other.Enabled then
					other.Enabled = false
					table.insert(hidden, other)
				end
			end
		end
		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
		end)
		camera.CameraType = Enum.CameraType.Scriptable
		ContextActionService:BindActionAtPriority(
			"BottleAStormPhotoFreeze",
			freeze,
			false,
			3000,
			Enum.PlayerActions.CharacterForward,
			Enum.PlayerActions.CharacterBackward,
			Enum.PlayerActions.CharacterLeft,
			Enum.PlayerActions.CharacterRight,
			Enum.PlayerActions.CharacterJump
		)
	else
		for _, other in hidden do
			other.Enabled = true
		end
		hidden = {}
		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
		end)
		camera.CameraType = Enum.CameraType.Custom
		ContextActionService:UnbindAction("BottleAStormPhotoFreeze")
		stopPose()
		poseIndex = 1
		dragging = false
	end
	window.Visible = on
	toggleButton.Visible = not on and not player:GetAttribute("InMatch")
	applyFilter()
end

local function snap()
	panel.Visible = false
	task.wait(0.15)
	local ok = pcall(function()
		local CaptureService = game:GetService("CaptureService") :: any
		CaptureService:CaptureScreenshot(function(contentId)
			pcall(function()
				CaptureService:PromptSaveCapturesToGallery({ contentId }, function() end)
			end)
		end)
	end)
	task.wait(if ok then 1 else 0.1)
	panel.Visible = true
	if not ok then
		UI.label({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 20),
			Size = UDim2.fromOffset(0, 30),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = UI.Colors.Panel,
			Text = "Use your device's screenshot to save it (hide this bar with 🙈 first)",
			TextSize = 15,
			Parent = panel,
		})
	end
end

local function cycleButton(order: number, label: () -> string, onClick: () -> ()): TextButton
	local button = UI.button({
		LayoutOrder = order,
		Size = UDim2.fromOffset(118, 40),
		Text = label(),
		TextSize = 15,
		TextWrapped = true,
		Parent = panel,
	})
	button.Activated:Connect(function()
		onClick()
		button.Text = label()
	end)
	return button
end

function PhotoMode.start()
	screen = UI.screen("PhotoMode", 20)
	screen.IgnoreGuiInset = true
	toggleButton = UI.button({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 72, 1, if UserInputService.TouchEnabled then -270 else -72),
		Size = UDim2.fromOffset(52, 52),
		Text = "📸",
		TextSize = 26,
		Parent = screen,
	})
	toggleButton.Activated:Connect(function()
		setActive(true)
	end)
	-- Only in the lobby.
	local function refreshButton()
		toggleButton.Visible = not active and not player:GetAttribute("InMatch")
	end
	player:GetAttributeChangedSignal("InMatch"):Connect(refreshButton)
	refreshButton()
	-- A "Window" so the mouse is free while you're in photo mode.
	window = UI.new("Frame", {
		Name = "Window",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Active = false,
		Visible = false,
		Parent = screen,
	})
	overlay = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = window,
	})
	panel = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.new(1, -24, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.2,
		Parent = window,
	}, {
		UI.corner(12),
		UI.padding(8),
		UI.new("UIListLayout", {
			Padding = UDim.new(0, 6),
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Wraps = true,
		}),
	})
	cycleButton(1, function()
		return "Pose: " .. POSES[poseIndex].name
	end, function()
		poseIndex = poseIndex % #POSES + 1
		playPose(POSES[poseIndex])
	end)
	cycleButton(2, function()
		return "Frame: " .. FRAMES[frameIndex]
	end, function()
		frameIndex = frameIndex % #FRAMES + 1
		drawFrame()
	end)
	cycleButton(3, function()
		return "Filter: " .. FILTERS[filterIndex].name
	end, function()
		filterIndex = filterIndex % #FILTERS + 1
		applyFilter()
	end)
	cycleButton(4, function()
		return "➕ Closer"
	end, function()
		distance = math.max(4, distance - 2)
	end)
	cycleButton(5, function()
		return "➖ Farther"
	end, function()
		distance = math.min(30, distance + 2)
	end)
	cycleButton(6, function()
		return "🙈 Hide bar (3s)"
	end, function()
		panel.Visible = false
		task.delay(3, function()
			panel.Visible = true
		end)
	end)
	local snapButton = cycleButton(7, function()
		return "📷 Snap"
	end, function()
		task.spawn(snap)
	end)
	snapButton.BackgroundColor3 = UI.Colors.Good
	local exitButton = cycleButton(8, function()
		return "✕ Done"
	end, function()
		setActive(false)
	end)
	exitButton.BackgroundColor3 = UI.Colors.Bad

	-- Drag to turn the camera, scroll to zoom.
	UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode == Enum.KeyCode.P and not processed then
			setActive(not active)
			return
		end
		if not active or processed then
			return
		end
		local kind = input.UserInputType
		if
			kind == Enum.UserInputType.MouseButton1
			or kind == Enum.UserInputType.MouseButton2
			or kind == Enum.UserInputType.Touch
		then
			dragging = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		local kind = input.UserInputType
		if
			kind == Enum.UserInputType.MouseButton1
			or kind == Enum.UserInputType.MouseButton2
			or kind == Enum.UserInputType.Touch
		then
			dragging = false
		end
	end)
	UserInputService.InputChanged:Connect(function(input, processed)
		if not active then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseWheel and not processed then
			distance = math.clamp(distance - input.Position.Z * 1.5, 4, 30)
		elseif
			dragging
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			yaw -= input.Delta.X * 0.008
			pitch = math.clamp(pitch + input.Delta.Y * 0.006, -0.9, 1.2)
		end
	end)
	RunService:BindToRenderStep("BottleAStormPhoto", Enum.RenderPriority.Camera.Value + 5, function()
		if not active then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root or player:GetAttribute("InMatch") then
			setActive(false)
			return
		end
		local focus = root.Position + Vector3.new(0, 1.5, 0)
		local offset = Vector3.new(math.sin(yaw) * math.cos(pitch), math.sin(pitch), math.cos(yaw) * math.cos(pitch))
			* distance
		local camera = workspace.CurrentCamera
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = CFrame.lookAt(focus + offset, focus)
	end)
	drawFrame()
end

return PhotoMode
