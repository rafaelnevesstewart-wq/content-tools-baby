-- Plays the server's "juice" on this screen: floating numbers with sparkle
-- bursts, sound effects and camera shake (see server Modules/Juice).

local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Format)
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
	label.TextStrokeColor3 = Color3.new(1, 1, 1)
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
local function awayText(seconds: number): string
	local hours = seconds // 3600
	local minutes = (seconds % 3600) // 60
	if hours > 0 then
		return hours .. "h " .. minutes .. "m"
	end
	return math.max(1, minutes) .. "m"
end

-- The "welcome back" pop-up: what your storms earned while you were away.
local function welcome(amount: number, awaySeconds: number)
	local screen = UI.screen("WelcomeBack", 9)
	local panel = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(340, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = UI.Colors.Panel,
		Parent = screen,
	}, { UI.corner(20), UI.stroke(UI.Colors.Spark, 4), UI.padding(16), UI.list(10) })
	local scale = UI.new("UIScale", { Scale = 0.3, Parent = panel })
	UI.label({
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 34),
		Text = "👋 Welcome back!",
		TextSize = 28,
		Parent = panel,
	})
	UI.label({
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 44),
		Text = "While you were away for " .. awayText(awaySeconds) .. ", your storms made:",
		TextSize = 17,
		TextWrapped = true,
		TextColor3 = UI.Colors.Muted,
		Parent = panel,
	})
	UI.label({
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 44),
		Text = "⚡" .. Format.number(amount),
		TextSize = 40,
		TextColor3 = UI.Colors.Spark,
		Parent = panel,
	})
	local ok = UI.button({
		LayoutOrder = 4,
		Size = UDim2.fromOffset(180, 46),
		Text = "Yay!",
		TextSize = 22,
		BackgroundColor3 = UI.Colors.Good,
		Parent = panel,
	})
	ok.Activated:Connect(function()
		screen:Destroy()
	end)
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	Sfx.play("coins")
end

local rareCatchPlaying = false

-- The big moment for an Epic-or-better catch: white flash, the camera swoops
-- in on the storm, and a banner pops up with its name.
local function rareCatch(name: string, rarityName: string, color: Color3, position: Vector3)
	local screen = UI.screen("RareCatch", 10)
	local flash = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.1,
		Parent = screen,
	})
	TweenService:Create(flash, TweenInfo.new(0.7), { BackgroundTransparency = 1 }):Play()

	local banner = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.28),
		Size = UDim2.fromOffset(460, 110),
		BackgroundColor3 = UI.Colors.Panel,
		Parent = screen,
	}, { UI.corner(24), UI.stroke(color, 5), UI.padding(8) })
	local scale = UI.new("UIScale", { Scale = 0.2, Parent = banner })
	UI.label({
		Size = UDim2.new(1, 0, 0.5, 0),
		Text = "✨ " .. string.upper(rarityName) .. " CATCH! ✨",
		TextScaled = true,
		TextColor3 = UI.ink(color),
		Parent = banner,
	})
	UI.label({
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0.5, 0),
		Text = name,
		TextScaled = true,
		TextColor3 = UI.Colors.Text,
		Parent = banner,
	})
	TweenService:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	Sfx.play("chime")
	task.delay(2.6, function()
		TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 })
			:Play()
		task.wait(0.35)
		screen:Destroy()
	end)

	-- Camera swoop (skipped if one is already playing).
	local camera = workspace.CurrentCamera
	if not camera or rareCatchPlaying then
		return
	end
	rareCatchPlaying = true
	local from = camera.CFrame
	local away = from.Position - position
	local direction = if away.Magnitude > 0.1 then away.Unit else Vector3.new(0, 0.3, 1).Unit
	local closeUp = CFrame.lookAt(position + direction * 14 + Vector3.new(0, 3, 0), position)
	camera.CameraType = Enum.CameraType.Scriptable
	TweenService
		:Create(camera, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = closeUp })
		:Play()
	task.delay(1.8, function()
		local back = TweenService:Create(camera, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { CFrame = from })
		back:Play()
		back.Completed:Wait()
		camera.CameraType = Enum.CameraType.Custom
		rareCatchPlaying = false
	end)
end

local function shake(strength: number)
	shakeStrength = math.max(shakeStrength, strength)
	shakeUntil = os.clock() + 0.35
end

function JuiceController.start()
	Remotes.event("Juice").OnClientEvent:Connect(function(kind, a, b, c, d)
		if kind == "float" and type(a) == "string" and typeof(b) == "Vector3" then
			float(a, b, if typeof(c) == "Color3" then c else nil)
		elseif kind == "sound" and type(a) == "string" then
			Sfx.play(a)
		elseif
			kind == "rareCatch"
			and type(a) == "string"
			and type(b) == "string"
			and typeof(c) == "Color3"
			and typeof(d) == "Vector3"
		then
			rareCatch(a, b, c, d)
		elseif kind == "welcome" and type(a) == "number" and type(b) == "number" then
			welcome(a, b)
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
