-- Combat and movement controls: weapon attacks, the spell bar, the travel menu
-- and driving your titan. The server decides what actually hits.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera
local state = nil

local FONT = Enum.Font.GothamMedium
local PANEL = Color3.fromRGB(28, 32, 44)

local gui = Instance.new("ScreenGui")
gui.Name = "Combat"
gui.ResetOnSpawn = false

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

-- Where the player is aiming: the mouse on desktop, the camera on touch.
local function aimDirection(): Vector3
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return camera.CFrame.LookVector
	end
	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		return camera.CFrame.LookVector
	end
	local offset = mouse.Hit.Position - hrp.Position
	if offset.Magnitude < 1 then
		return hrp.CFrame.LookVector
	end
	return offset.Unit
end

-- Weapons ----------------------------------------------------------------------

local function hookTool(tool: Instance)
	if not tool:IsA("Tool") or not tool:GetAttribute("WeaponKey") or tool:GetAttribute("Hooked") then
		return
	end
	tool:SetAttribute("Hooked", true)
	tool.Activated:Connect(function()
		Remotes.Action:FireServer("Attack", { Key = tool:GetAttribute("WeaponKey"), Dir = aimDirection() })
	end)
end

local function onCharacter(character: Model)
	for _, child in character:GetChildren() do
		hookTool(child)
	end
	character.ChildAdded:Connect(hookTool)
end
player.CharacterAdded:Connect(onCharacter)
if player.Character then
	onCharacter(player.Character)
end

-- Spell bar ----------------------------------------------------------------------

local spellBar = Instance.new("Frame")
spellBar.Size = UDim2.fromOffset(#Config.Spells * 70, 66)
spellBar.Position = UDim2.new(0.5, -#Config.Spells * 35, 1, -80)
spellBar.BackgroundTransparency = 1
spellBar.Parent = gui
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.Padding = UDim.new(0, 6)
layout.Parent = spellBar

local spellSlots = {}
local readyAt = {}

local function cast(spell)
	local level = state and state.Spells[spell.Key] or 0
	if level <= 0 then
		Remotes.Action:FireServer("Cast", { Key = spell.Key }) -- server explains how to unlock it
		return
	end
	if os.clock() < (readyAt[spell.Key] or 0) then
		return
	end
	if (player:GetAttribute("Power") or 0) < spell.PowerCost then
		Remotes.Action:FireServer("Cast", { Key = spell.Key }) -- server says how much power is needed
		return
	end
	readyAt[spell.Key] = os.clock() + spell.Cooldown
	Remotes.Action:FireServer("Cast", { Key = spell.Key, Dir = aimDirection() })
end

for _, spell in Config.Spells do
	local slot = Instance.new("TextButton")
	slot.Size = UDim2.fromOffset(64, 64)
	slot.BackgroundColor3 = PANEL
	slot.AutoButtonColor = true
	slot.Text = ""
	corner(slot, 12)
	local stroke = Instance.new("UIStroke")
	stroke.Color = spell.Color
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = slot
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, -6, 0.5, 0)
	name.Position = UDim2.new(0, 3, 0.22, 0)
	name.Font = FONT
	name.TextScaled = true
	name.TextColor3 = spell.Color
	name.Text = spell.Name
	name.Parent = slot
	local key = Instance.new("TextLabel")
	key.BackgroundTransparency = 1
	key.Size = UDim2.new(1, 0, 0.25, 0)
	key.Font = FONT
	key.TextScaled = true
	key.TextColor3 = Color3.new(1, 1, 1)
	key.Text = spell.Hotkey
	key.Parent = slot
	local level = Instance.new("TextLabel")
	level.BackgroundTransparency = 1
	level.Size = UDim2.new(1, 0, 0.22, 0)
	level.Position = UDim2.new(0, 0, 0.76, 0)
	level.Font = FONT
	level.TextScaled = true
	level.TextColor3 = Color3.fromRGB(200, 200, 200)
	level.Text = "Locked"
	level.Parent = slot
	local cooldown = Instance.new("Frame")
	cooldown.BackgroundColor3 = Color3.new(0, 0, 0)
	cooldown.BackgroundTransparency = 0.35
	cooldown.BorderSizePixel = 0
	cooldown.AnchorPoint = Vector2.new(0, 1)
	cooldown.Position = UDim2.fromScale(0, 1)
	cooldown.Size = UDim2.fromScale(1, 0)
	cooldown.Parent = slot
	corner(cooldown, 12)
	slot.Activated:Connect(function()
		cast(spell)
	end)
	slot.Parent = spellBar
	spellSlots[spell.Key] = { Level = level, Cooldown = cooldown, Slot = slot, Spell = spell }
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end
	for _, spell in Config.Spells do
		if input.KeyCode == Enum.KeyCode[spell.Hotkey] then
			cast(spell)
		end
	end
end)

-- Travel menu ---------------------------------------------------------------------

local PLACES = {
	{ Key = "Base", Name = "Base (Titan's Rest)" },
	{ Key = "Titan", Name = "My Titan" },
	{ Key = "Fern Valley", Name = "Fern Valley Outpost" },
	{ Key = "Salt Flats", Name = "Salt Flats Outpost" },
	{ Key = "Aurora Tundra", Name = "Aurora Tundra Outpost" },
	{ Key = "Ember Wastes", Name = "Ember Wastes Outpost" },
}

local travelFrame = Instance.new("Frame")
travelFrame.Size = UDim2.fromOffset(260, #PLACES * 46 + 50)
travelFrame.Position = UDim2.new(0.5, -130, 0.5, -(#PLACES * 46 + 50) / 2)
travelFrame.BackgroundColor3 = PANEL
travelFrame.Visible = false
travelFrame.Parent = gui
corner(travelFrame, 14)
local travelTitle = Instance.new("TextLabel")
travelTitle.BackgroundTransparency = 1
travelTitle.Size = UDim2.new(1, 0, 0, 40)
travelTitle.Font = FONT
travelTitle.TextScaled = true
travelTitle.TextColor3 = Color3.fromRGB(214, 180, 116)
travelTitle.Text = "Travel"
travelTitle.Parent = travelFrame
for i, place in PLACES do
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, -20, 0, 40)
	b.Position = UDim2.fromOffset(10, 44 + (i - 1) * 46)
	b.BackgroundColor3 = Color3.fromRGB(50, 58, 76)
	b.Font = FONT
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = place.Name
	corner(b, 10)
	local size = Instance.new("UITextSizeConstraint")
	size.MaxTextSize = 20
	size.Parent = b
	b.Activated:Connect(function()
		travelFrame.Visible = false
		Remotes.Action:FireServer("Travel", place.Key)
	end)
	b.Parent = travelFrame
end

local travelButton = Instance.new("TextButton")
travelButton.Size = UDim2.fromOffset(120, 40)
travelButton.Position = UDim2.new(0, 12, 0, 236)
travelButton.BackgroundColor3 = Color3.fromRGB(58, 78, 104)
travelButton.Font = FONT
travelButton.TextScaled = true
travelButton.TextColor3 = Color3.new(1, 1, 1)
travelButton.Text = "Travel"
corner(travelButton, 12)
travelButton.Activated:Connect(function()
	travelFrame.Visible = not travelFrame.Visible
end)
travelButton.Parent = gui

-- Driving -------------------------------------------------------------------------

local driveHint = Instance.new("TextLabel")
driveHint.Size = UDim2.fromOffset(420, 34)
driveHint.Position = UDim2.new(0.5, -210, 0, 56)
driveHint.BackgroundColor3 = PANEL
driveHint.BackgroundTransparency = 0.2
driveHint.Font = FONT
driveHint.TextScaled = true
driveHint.TextColor3 = Color3.fromRGB(255, 220, 150)
driveHint.Text = "Driving your titan: W/S walk • A/D turn • Jump to get off"
driveHint.Visible = false
driveHint.Parent = gui
corner(driveHint, 12)

local lastSent = { Throttle = 0, Steer = 0 }
local sendClock = 0

RunService.Heartbeat:Connect(function(dt)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	local driving = seat ~= nil and seat.Name == "Saddle" and seat:IsA("VehicleSeat")
	driveHint.Visible = driving
	if not driving then
		return
	end
	sendClock += dt
	local throttle, steer = seat.ThrottleFloat, seat.SteerFloat
	if sendClock >= 0.1 and (throttle ~= lastSent.Throttle or steer ~= lastSent.Steer or sendClock >= 1) then
		sendClock = 0
		lastSent = { Throttle = throttle, Steer = steer }
		Remotes.Action:FireServer("Drive", lastSent)
	end
end)

-- Cooldowns and levels --------------------------------------------------------------

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	for key, slot in spellSlots do
		local left = (readyAt[key] or 0) - now
		slot.Cooldown.Size = UDim2.fromScale(1, left > 0 and math.clamp(left / slot.Spell.Cooldown, 0, 1) or 0)
	end
end)

Remotes.State.OnClientEvent:Connect(function(newState)
	state = newState
	for key, slot in spellSlots do
		local level = state.Spells[key] or 0
		slot.Level.Text = level > 0 and ("Lv " .. level) or "Locked"
		slot.Slot.BackgroundTransparency = level > 0 and 0 or 0.4
	end
end)

gui.Parent = player:WaitForChild("PlayerGui")
