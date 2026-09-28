-- Plays the server's "juice" on this screen: floating numbers with sparkle
-- bursts, sound effects and camera shake (see server Modules/Juice).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local Sfx = require(script.Parent.Sfx)
local UI = require(script.Parent.UI)

local JuiceController = {}

local rng = Random.new()
local shakeUntil = 0
local shakeStrength = 0

-- "+⚡300" rising from a spot, with a sparkle burst.
local function float(text: string, position: Vector3, color: Color3?)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = workspace

	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Color = ColorSequence.new(color or Color3.fromRGB(255, 220, 90), Color3.new(1, 1, 1))
	sparkles.Size = NumberSequence.new(0.7, 0)
	sparkles.Speed = NumberRange.new(6, 12)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Lifetime = NumberRange.new(0.5, 0.9)
	sparkles.LightEmission = 1
	sparkles.Rate = 0
	sparkles.Parent = anchor
	sparkles:Emit(18)

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 60)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 150
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = UI.Font
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color or Color3.fromRGB(255, 210, 60)
	label.TextStrokeColor3 = Color3.fromRGB(15, 18, 26)
	label.TextStrokeTransparency = 0
	label.Parent = gui

	local info = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, { StudsOffsetWorldSpace = Vector3.new(0, 5, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.7), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	Debris:AddItem(anchor, 1.4)
end

-- "2h 15m" / "45m"
local function knock(velocity: Vector3)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	root.AssemblyLinearVelocity += velocity
end

local function shake(strength: number)
	shakeStrength = math.max(shakeStrength, strength)
	shakeUntil = os.clock() + 0.35
end

-- Your team won: your character plays its victory dance (a built-in Roblox
-- emote picked in 🎨 Style → Victory Dances) a few times.
local function victory(emote: string)
	task.spawn(function()
		for _ = 1, 3 do
			local character = Players.LocalPlayer.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if not humanoid or humanoid.Health <= 0 then
				return
			end
			pcall(function()
				humanoid:PlayEmote(emote)
			end)
			task.wait(3)
		end
	end)
	Sfx.play("chime")
end

function JuiceController.start()
	Remotes.event("Victory").OnClientEvent:Connect(function(emote)
		if type(emote) == "string" then
			victory(emote)
		end
	end)
	Remotes.event("Juice").OnClientEvent:Connect(function(kind, a, b, c)
		if kind == "float" and type(a) == "string" and typeof(b) == "Vector3" then
			float(a, b, if typeof(c) == "Color3" then c else nil)
		elseif kind == "sound" and type(a) == "string" then
			Sfx.play(a)
		elseif kind == "knock" and typeof(a) == "Vector3" then
			knock(a)
		elseif kind == "shake" then
			shake(if type(a) == "number" then a else 1)
		end
	end)

	-- Runs right after the camera moves, so the shake sits on top of it.
	RunService:BindToRenderStep("JuiceShake", Enum.RenderPriority.Camera.Value + 1, function()
		local left = shakeUntil - os.clock()
		if left <= 0 then
			shakeStrength = 0
			return
		end
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local power = shakeStrength * (left / 0.35)
		camera.CFrame *= CFrame.new(rng:NextNumber(-0.35, 0.35) * power, rng:NextNumber(-0.35, 0.35) * power, 0) * CFrame.Angles(
			0,
			0,
			rng:NextNumber(-0.012, 0.012) * power
		)
	end)
end

return JuiceController
