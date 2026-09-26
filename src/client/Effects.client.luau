-- The feel of the world: damage numbers, hit and swing sounds, weapon swings,
-- a red flash and camera shake when you are hurt, the ground shaking under
-- nearby titans, and rain during storms.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local rng = Random.new()

local SOUNDS = {
	Swing = "rbxasset://sounds/swordslash.wav",
	Hit = "rbxasset://sounds/swordlunge.wav",
	Equip = "rbxasset://sounds/unsheath.wav",
	Thud = "rbxasset://sounds/collide.wav",
	Hurt = "rbxasset://sounds/splat.wav",
}

local function playSound(id: string, volume: number, speed: number?, parent: Instance?)
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.PlaybackSpeed = speed or 1
	sound.Parent = parent or workspace
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	task.delay(5, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

-- Camera shake: offsets the camera a little each frame while it decays.
local shake = 0
RunService:BindToRenderStep("CombatShake", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if shake > 0.01 then
		camera.CFrame *= CFrame.new(rng:NextNumber(-1, 1) * shake, rng:NextNumber(-1, 1) * shake, 0)
		shake = math.max(0, shake - dt * 2.5)
	end
end)

-- Damage numbers -----------------------------------------------------------------

local function damageNumber(position: Vector3, amount: number, crit: boolean)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.Position = position + Vector3.new(rng:NextNumber(-1.5, 1.5), 3, rng:NextNumber(-1.5, 1.5))
	anchor.Parent = workspace
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(crit and 140 or 90, crit and 60 or 40)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.Bangers
	label.TextScaled = true
	label.TextColor3 = crit and Color3.fromRGB(255, 200, 40) or Color3.new(1, 1, 1)
	label.TextStrokeColor3 = crit and Color3.fromRGB(120, 20, 0) or Color3.fromRGB(40, 0, 0)
	label.TextStrokeTransparency = 0
	label.Text = crit and (amount .. "!") or tostring(amount)
	label.Parent = gui
	TweenService:Create(anchor, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { Position = anchor.Position + Vector3.new(0, 4, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(1, function()
		anchor:Destroy()
	end)
end

-- Hurt flash ------------------------------------------------------------------------

local hurtGui = Instance.new("ScreenGui")
hurtGui.Name = "HurtFlash"
hurtGui.IgnoreGuiInset = true
hurtGui.ResetOnSpawn = false
hurtGui.DisplayOrder = 5
local hurtFrame = Instance.new("Frame")
hurtFrame.Size = UDim2.fromScale(1, 1)
hurtFrame.BackgroundColor3 = Color3.fromRGB(160, 0, 0)
hurtFrame.BackgroundTransparency = 1
hurtFrame.Parent = hurtGui
local vignette = Instance.new("UIGradient")
vignette.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.3, 0.85),
	NumberSequenceKeypoint.new(0.7, 0.85),
	NumberSequenceKeypoint.new(1, 0),
})
vignette.Parent = hurtFrame
hurtGui.Parent = player:WaitForChild("PlayerGui")

local function hurt(amount: number)
	hurtFrame.BackgroundTransparency = 0.2
	TweenService:Create(hurtFrame, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
	shake = math.max(shake, math.clamp(amount / 25, 0.15, 0.8))
	playSound(SOUNDS.Hurt, 0.5, rng:NextNumber(0.9, 1.1))
end

-- Weapon swings -------------------------------------------------------------------------

local function hookTool(tool: Instance)
	if not tool:IsA("Tool") or not tool:GetAttribute("WeaponKey") or tool:GetAttribute("FxHooked") then
		return
	end
	tool:SetAttribute("FxHooked", true)
	local swinging = false
	tool.Equipped:Connect(function()
		playSound(SOUNDS.Equip, 0.4)
	end)
	tool.Activated:Connect(function()
		playSound(SOUNDS.Swing, 0.5, rng:NextNumber(0.9, 1.15))
		if swinging then
			return
		end
		swinging = true
		-- A quick overhead chop by tilting the grip, then back.
		local rest = tool.Grip
		local value = Instance.new("CFrameValue")
		value.Value = rest
		value.Changed:Connect(function(grip)
			tool.Grip = grip
		end)
		local down = TweenService:Create(value, TweenInfo.new(0.1, Enum.EasingStyle.Quad), { Value = rest * CFrame.Angles(math.rad(-95), 0, 0) })
		down:Play()
		down.Completed:Wait()
		local back = TweenService:Create(value, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { Value = rest })
		back:Play()
		back.Completed:Wait()
		value:Destroy()
		swinging = false
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

-- Titan footsteps: the ground shakes and thuds when a big titan walks nearby.

local stepClock = 0
RunService.Heartbeat:Connect(function(dt)
	stepClock += dt
	if stepClock < 0.9 then
		return
	end
	stepClock = 0
	local herd = workspace:FindFirstChild("Herd")
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not herd or not hrp or ReplicatedStorage:GetAttribute("Phase") == "Night" then
		return
	end
	local strongest = 0
	for _, titan in herd:GetChildren() do
		local root = titan:IsA("Model") and titan.PrimaryPart
		if root then
			local distance = (root.Position - hrp.Position).Magnitude
			local size = root.Position.Y / 12 -- titans stand about 12 studs per unit of scale
			strongest = math.max(strongest, size * math.clamp(1 - distance / 140, 0, 1))
		end
	end
	if strongest > 0.05 then
		shake = math.max(shake, strongest * 0.18)
		playSound(SOUNDS.Thud, math.clamp(strongest * 0.6, 0.1, 0.8), 0.35)
	end
end)

-- Storm rain around the camera ------------------------------------------------------------

local rainPart = Instance.new("Part")
rainPart.Name = "Rain"
rainPart.Anchored = true
rainPart.CanCollide = false
rainPart.CanQuery = false
rainPart.CanTouch = false
rainPart.Transparency = 1
rainPart.Size = Vector3.new(160, 1, 160)
rainPart.Parent = camera
local rain = Instance.new("ParticleEmitter")
rain.Texture = "rbxasset://textures/particles/sparkles_main.dds"
rain.Color = ColorSequence.new(Color3.fromRGB(175, 190, 215))
rain.LightEmission = 0.2
rain.Transparency = NumberSequence.new(0.35)
rain.Size = NumberSequence.new(0.18)
rain.Squash = NumberSequence.new(-3) -- stretch into streaks
rain.Speed = NumberRange.new(90, 110)
rain.Lifetime = NumberRange.new(0.9, 1.1)
rain.EmissionDirection = Enum.NormalId.Bottom
rain.Rate = 0
rain.Parent = rainPart

RunService.RenderStepped:Connect(function()
	rainPart.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 60, 0))
	local storm = (ReplicatedStorage:GetAttribute("StormUntil") or 0) > workspace:GetServerTimeNow()
	rain.Rate = storm and 900 or 0
end)

-- Server messages -------------------------------------------------------------------------

Remotes.Ui.OnClientEvent:Connect(function(message)
	if type(message) ~= "table" then
		return
	end
	if message.Hit then
		damageNumber(message.Hit.Position, message.Hit.Amount, message.Hit.Crit)
		playSound(SOUNDS.Hit, message.Hit.Crit and 0.9 or 0.6, message.Hit.Crit and 0.8 or rng:NextNumber(1, 1.2))
		if message.Hit.Crit then
			shake = math.max(shake, 0.25)
		end
	elseif message.Hurt then
		hurt(message.Hurt)
	end
end)
