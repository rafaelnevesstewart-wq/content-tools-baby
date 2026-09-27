-- The bottling tug-of-war. Hold (click, tap, Space or A) to push your jar to
-- the right, let go and it slides back. Keep the jar under the storm to fill
-- the meter. Fill it to bottle the storm; empty it and the storm escapes.

local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local UI = require(script.Parent.UI)

local CaptureMinigame = {}

local ACTION = "BottleAStormHold"
local ZONE_WIDTH = 0.1
local START_PROGRESS = 0.3
local FILL_RATE = 0.32
local PUSH = 2.6
local GRAVITY = 2.0
local MAX_SPEED = 1.3

type Info = {
	uid: string,
	name: string,
	rarity: string,
	color: Color3,
	pull: number,
	power: number,
}

local screen: ScreenGui
local overlay: TextButton
local panel: Frame
local titleLabel: TextLabel
local track: Frame
local zone: TextLabel
local catcher: Frame
local meterFill: Frame

local activeUid: string? = nil
local holding = false
local connection: RBXScriptConnection? = nil

local function stop()
	activeUid = nil
	holding = false
	if connection then
		connection:Disconnect()
		connection = nil
	end
	ContextActionService:UnbindAction(ACTION)
	screen.Enabled = false
end

local function finish(uid: string, success: boolean)
	if activeUid ~= uid then
		return
	end
	stop()
	Remotes.event("CaptureResult"):FireServer(uid, success)
end

local function run(info: Info)
	if activeUid then
		stop()
	end
	activeUid = info.uid
	holding = false
	titleLabel.Text = "Bottling " .. info.name .. "! (" .. info.rarity .. ")"
	titleLabel.TextColor3 = info.color

	local catcherWidth = 0.18 + 0.14 * info.power
	local zoneSpeed = 0.22 + 0.6 * info.pull
	local drainRate = 0.18 + 0.14 * info.pull
	catcher.Size = UDim2.fromScale(catcherWidth, 1)

	local rng = Random.new()
	local catcherPos = 0.5 - catcherWidth / 2
	local catcherVel = 0
	local zonePos = 0.5
	local zoneTarget = 0.5
	local retargetIn = 0
	local progress = START_PROGRESS

	ContextActionService:BindActionAtPriority(ACTION, function(_, state)
		holding = state == Enum.UserInputState.Begin
		return Enum.ContextActionResult.Sink
	end, false, 3000, Enum.KeyCode.Space, Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonR2)

	screen.Enabled = true
	local uid = info.uid
	connection = RunService.RenderStepped:Connect(function(dt)
		dt = math.min(dt, 0.1)

		-- The storm darts between random spots; stronger storms move faster.
		retargetIn -= dt
		if retargetIn <= 0 then
			retargetIn = rng:NextNumber(0.35, 1.1) * (1.2 - info.pull * 0.5)
			zoneTarget = rng:NextNumber(ZONE_WIDTH / 2, 1 - ZONE_WIDTH / 2)
		end
		local diff = zoneTarget - zonePos
		zonePos += math.clamp(diff, -zoneSpeed * dt, zoneSpeed * dt)

		-- Your jar: pushed right while holding, slides left when you let go.
		catcherVel += (if holding then PUSH else -GRAVITY) * dt
		catcherVel = math.clamp(catcherVel, -MAX_SPEED, MAX_SPEED)
		catcherPos += catcherVel * dt
		if catcherPos < 0 then
			catcherPos = 0
			catcherVel = math.max(0, catcherVel) * -0.3
		elseif catcherPos > 1 - catcherWidth then
			catcherPos = 1 - catcherWidth
			catcherVel = math.min(0, catcherVel) * -0.3
		end

		local inside = zonePos >= catcherPos and zonePos <= catcherPos + catcherWidth
		progress += (if inside then FILL_RATE else -drainRate) * dt

		catcher.Position = UDim2.fromScale(catcherPos, 0)
		catcher.BackgroundColor3 = if inside then UI.Colors.Good else Color3.fromRGB(150, 200, 255)
		zone.Position = UDim2.fromScale(zonePos, 0.5)
		meterFill.Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1)
		meterFill.BackgroundColor3 = if progress > 0.66
			then UI.Colors.Good
			elseif progress > 0.33 then UI.Colors.Spark
			else UI.Colors.Bad

		if progress >= 1 then
			finish(uid, true)
		elseif progress <= 0 then
			finish(uid, false)
		end
	end)
end

function CaptureMinigame.start()
	screen = UI.screen("Capture", 10)
	screen.Enabled = false

	-- Invisible full-screen button so a click or tap anywhere counts as holding.
	overlay = UI.new("TextButton", {
		Name = "HoldArea",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Parent = screen,
	})
	overlay.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			holding = true
		end
	end)
	overlay.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			holding = false
		end
	end)

	panel = UI.new("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -40),
		Size = UDim2.new(0.9, 0, 0, 190),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.05,
		Active = false,
		Parent = screen,
	}, {
		UI.corner(16),
		UI.stroke(UI.Colors.Stroke, 3),
		UI.padding(14),
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(520, 190) }),
	})

	titleLabel = UI.label({
		Size = UDim2.new(1, 0, 0, 30),
		TextSize = 24,
		Parent = panel,
	})

	track = UI.new("Frame", {
		Name = "Track",
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundColor3 = Color3.fromRGB(15, 20, 45),
		ClipsDescendants = true,
		Parent = panel,
	}, { UI.corner(10) })

	catcher = UI.new("Frame", {
		Name = "Jar",
		Size = UDim2.fromScale(0.2, 1),
		BackgroundColor3 = Color3.fromRGB(150, 200, 255),
		BackgroundTransparency = 0.35,
		Parent = track,
	}, { UI.corner(10), UI.stroke(Color3.new(1, 1, 1), 2) })
	UI.label({ Size = UDim2.fromScale(1, 1), Text = "🫙", TextSize = 28, Parent = catcher })

	zone = UI.label({
		Name = "Storm",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(ZONE_WIDTH, 0, 1, 0),
		Text = "⛈️",
		TextSize = 34,
		ZIndex = 2,
		Parent = track,
	})

	local meter = UI.new("Frame", {
		Name = "Meter",
		Position = UDim2.fromOffset(0, 102),
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundColor3 = Color3.fromRGB(15, 20, 45),
		Parent = panel,
	}, { UI.corner(9) })
	meterFill = UI.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(START_PROGRESS, 1),
		BackgroundColor3 = UI.Colors.Spark,
		Parent = meter,
	}, { UI.corner(9) })

	UI.label({
		Position = UDim2.fromOffset(0, 128),
		Size = UDim2.new(1, 0, 0, 24),
		Text = "HOLD click / tap / Space to push the jar right. Keep the storm inside it!",
		TextSize = 16,
		TextWrapped = true,
		TextColor3 = UI.Colors.Muted,
		Parent = panel,
	})

	Remotes.event("CaptureStart").OnClientEvent:Connect(run)
	Remotes.event("CaptureEnd").OnClientEvent:Connect(function(uid)
		if activeUid == uid then
			stop()
		end
	end)
end

return CaptureMinigame
