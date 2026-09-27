-- ARK-style controls on computers: the mouse turns the camera and your
-- character (over-the-shoulder view with a crosshair), left click attacks
-- with your weapon (hold to keep attacking), right click aims.
-- Left Alt frees the cursor to click buttons; it also frees itself while the
-- shop, inventory, travel menu or death screen is open.
-- Touch devices keep the normal Roblox controls.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

if not UserInputService.MouseEnabled then
	return -- phones and tablets use the default controls
end

local SHOULDER = Vector3.new(1.8, 0.5, 0)
local BASE_FOV = 70
local AIM_FOV = 50
local PANELS = { Shop = true, Inventory = true, TravelMenu = true }

local freeCursor = false
local holdingAttack = false
local aiming = false

-- Crosshair ------------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "Crosshair"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 3
local dot = Instance.new("Frame")
dot.AnchorPoint = Vector2.new(0.5, 0.5)
dot.Position = UDim2.fromScale(0.5, 0.5)
dot.Size = UDim2.fromOffset(4, 4)
dot.BackgroundColor3 = Color3.fromRGB(235, 230, 220)
dot.BorderSizePixel = 0
dot.Parent = gui
local dotCorner = Instance.new("UICorner")
dotCorner.CornerRadius = UDim.new(1, 0)
dotCorner.Parent = dot
local ring = Instance.new("Frame")
ring.AnchorPoint = Vector2.new(0.5, 0.5)
ring.Position = UDim2.fromScale(0.5, 0.5)
ring.Size = UDim2.fromOffset(22, 22)
ring.BackgroundTransparency = 1
ring.Parent = gui
local ringStroke = Instance.new("UIStroke")
ringStroke.Color = Color3.fromRGB(235, 230, 220)
ringStroke.Transparency = 0.5
ringStroke.Thickness = 1.5
ringStroke.Parent = ring
local ringCorner = Instance.new("UICorner")
ringCorner.CornerRadius = UDim.new(1, 0)
ringCorner.Parent = ring
local hint = Instance.new("TextLabel")
hint.AnchorPoint = Vector2.new(0.5, 1)
hint.Position = UDim2.new(0.5, 0, 1, -8)
hint.Size = UDim2.fromOffset(520, 18)
hint.BackgroundTransparency = 1
hint.Font = Enum.Font.GothamMedium
hint.TextSize = 13
hint.TextColor3 = Color3.fromRGB(200, 195, 185)
hint.TextStrokeTransparency = 0.6
hint.Text = "Mouse: look   Left click: attack   Right click: aim   Alt: cursor   I: items   P: shop   T: travel"
hint.Parent = gui
gui.Parent = player:WaitForChild("PlayerGui")

-- State helpers ----------------------------------------------------------------------

local function panelOpen(): boolean
	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui then
		return false
	end
	local death = playerGui:FindFirstChild("DeathScreen")
	if death and death:IsA("ScreenGui") and death.Enabled then
		return true
	end
	for _, screen in playerGui:GetChildren() do
		if screen:IsA("ScreenGui") and screen.Enabled then
			for _, child in screen:GetChildren() do
				if PANELS[child.Name] and child:IsA("GuiObject") and child.Visible then
					return true
				end
			end
		end
	end
	return false
end

local function mouseLookActive(): boolean
	return not freeCursor and not panelOpen()
end

local function characterParts()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	return character, humanoid, hrp
end

-- Where the crosshair points in the world.
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function aimPoint(): Vector3
	local character = player.Character
	rayParams.FilterDescendantsInstances = { character, camera }
	local origin = camera.CFrame.Position
	local direction = camera.CFrame.LookVector * 600
	local hit = workspace:Raycast(origin, direction, rayParams)
	return hit and hit.Position or origin + direction
end

-- Camera and facing ---------------------------------------------------------------------

RunService:BindToRenderStep("MouseLook", Enum.RenderPriority.Camera.Value + 2, function()
	local _, humanoid, hrp = characterParts()
	local active = mouseLookActive()
	gui.Enabled = active
	UserInputService.MouseBehavior = active and Enum.MouseBehavior.LockCenter or Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = not active
	if not humanoid or not hrp then
		return
	end
	local state = humanoid:GetState()
	local free = state == Enum.HumanoidStateType.Seated or state == Enum.HumanoidStateType.Climbing or state == Enum.HumanoidStateType.Dead
	if active and not free then
		humanoid.AutoRotate = false
		humanoid.CameraOffset = humanoid.CameraOffset:Lerp(SHOULDER, 0.25)
		local look = camera.CFrame.LookVector
		local yaw = math.atan2(-look.X, -look.Z)
		hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, yaw, 0)
	else
		humanoid.AutoRotate = true
		humanoid.CameraOffset = humanoid.CameraOffset:Lerp(Vector3.zero, 0.25)
	end
	local fov = (aiming and active) and AIM_FOV or BASE_FOV
	camera.FieldOfView += (fov - camera.FieldOfView) * 0.2
end)

-- Attacking --------------------------------------------------------------------------------

local lastUsed = nil -- name of the last weapon you held

local function equippedWeapon(): Tool?
	local character, humanoid = characterParts()
	if not character or not humanoid then
		return nil
	end
	local tool = character:FindFirstChildOfClass("Tool")
	if tool and tool:GetAttribute("WeaponKey") then
		lastUsed = tool.Name
		return tool
	end
	-- Nothing in hand: draw the last weapon you used, or the first one you have.
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return nil
	end
	local pick = lastUsed and backpack:FindFirstChild(lastUsed)
	if not pick then
		for _, candidate in backpack:GetChildren() do
			if candidate:IsA("Tool") and candidate:GetAttribute("WeaponKey") then
				pick = candidate
				break
			end
		end
	end
	if pick then
		humanoid:EquipTool(pick)
	end
	return nil -- it takes a moment to be in hand; the next click attacks
end

local function weaponDef(key: string)
	for _, def in Config.Weapons do
		if def.Key == key then
			return def
		end
	end
	return nil
end

local swingSound = Instance.new("Sound")
swingSound.SoundId = "rbxasset://sounds/swordslash.wav"
swingSound.Volume = 0.45
swingSound.Parent = gui

local function kick()
	-- A small recoil on the crosshair so each attack is felt.
	ring.Size = UDim2.fromOffset(30, 30)
	TweenService:Create(ring, TweenInfo.new(0.15), { Size = UDim2.fromOffset(22, 22) }):Play()
end

local function attackLoop()
	while holdingAttack do
		local tool = equippedWeapon()
		local def = tool and weaponDef(tool:GetAttribute("WeaponKey"))
		if def then
			local _, _, hrp = characterParts()
			local origin = hrp and hrp.Position or camera.CFrame.Position
			local direction = (aimPoint() - origin)
			direction = direction.Magnitude > 0.1 and direction.Unit or camera.CFrame.LookVector
			Remotes.Action:FireServer("Attack", { Key = def.Key, Dir = direction })
			swingSound.PlaybackSpeed = def.Kind == "Ranged" and 1.4 or math.random(90, 115) / 100
			swingSound:Play()
			kick()
			task.wait(def.Cooldown + 0.02)
		else
			task.wait(0.2)
		end
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if input.KeyCode == Enum.KeyCode.LeftAlt then
		freeCursor = not freeCursor
		return
	end
	if processed or not mouseLookActive() then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if not holdingAttack then
			holdingAttack = true
			task.spawn(attackLoop)
		end
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		aiming = true
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		holdingAttack = false
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		aiming = false
	end
end)

player.CharacterAdded:Connect(function()
	holdingAttack = false
	aiming = false
end)
