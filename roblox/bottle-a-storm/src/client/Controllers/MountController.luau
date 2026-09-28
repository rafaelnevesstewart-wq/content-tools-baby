-- 🐎 Mounts on your screen: press H (or 🐎) to ride (MountService). While
-- you ride you sit; flying clouds go up while you hold jump and drift down
-- slowly otherwise. Every horse on screen gallops (legs swing) when it moves,
-- and dragons flap their wings.

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local MountController = {}

local SIT = "rbxassetid://2506281703" -- Roblox's own sitting pose

type Leg = { weld: Weld, base: CFrame, phase: number }
type Wing = { weld: Weld, base: CFrame, side: number }
type Horse = { model: Model, legs: { Leg }, wings: { Wing }, last: Vector3, speed: number, gait: number }

local horses: { [Model]: Horse } = {}
local sitTrack: AnimationTrack? = nil

local function toggle()
	Remotes.event("Mount"):FireServer()
end

local function addHorse(model: Instance)
	if not model:IsA("Model") then
		return
	end
	task.wait(0.2)
	local legs = {}
	local wings = {}
	for _, item in model:GetDescendants() do
		if item:IsA("Weld") and item.Name == "Leg" then
			local phase = item:GetAttribute("Phase")
			table.insert(legs, { weld = item, base = item.C0, phase = if type(phase) == "number" then phase else 0 })
		elseif item:IsA("Weld") and item.Name == "Wing" then
			local side = item:GetAttribute("Side")
			table.insert(wings, { weld = item, base = item.C0, side = if type(side) == "number" then side else 1 })
		end
	end
	local root = model.PrimaryPart
	if (#legs > 0 or #wings > 0) and root then
		horses[model] = { model = model, legs = legs, wings = wings, last = root.Position, speed = 0, gait = 0 }
	end
end

local function setSitting(on: boolean)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if on and animator and not sitTrack then
		local animation = Instance.new("Animation")
		animation.AnimationId = SIT
		local ok, track = pcall(function()
			return animator:LoadAnimation(animation)
		end)
		if ok and track then
			track.Priority = Enum.AnimationPriority.Action
			track.Looped = true
			track:Play()
			sitTrack = track
		end
	elseif not on and sitTrack then
		sitTrack:Stop()
		sitTrack = nil
	end
end

function MountController.start()
	local screen = UI.screen("Mount", 2)
	UI.button({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, if UserInputService.TouchEnabled then -330 else -132),
		Size = UDim2.fromOffset(52, 52),
		Text = "🐎",
		TextSize = 26,
		Parent = screen,
	}).Activated
		:Connect(toggle)
	ContextActionService:BindAction("BottleAStormMount", function(_, state)
		if state == Enum.UserInputState.Begin then
			toggle()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.H)

	player:GetAttributeChangedSignal("Mounted"):Connect(function()
		setSitting(player:GetAttribute("Mounted") ~= nil)
	end)
	player.CharacterAdded:Connect(function()
		sitTrack = nil
	end)

	for _, model in CollectionService:GetTagged("Mount") do
		task.spawn(addHorse, model)
	end
	CollectionService:GetInstanceAddedSignal("Mount"):Connect(function(model)
		task.spawn(addHorse, model)
	end)
	CollectionService:GetInstanceRemovedSignal("Mount"):Connect(function(model)
		horses[model :: Model] = nil
	end)

	RunService.Heartbeat:Connect(function(dt)
		-- Flying clouds.
		if player:GetAttribute("Mounted") and player:GetAttribute("MountFlies") then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if root and humanoid then
				local v = root.AssemblyLinearVelocity
				local rising = humanoid.Jump or UserInputService:IsKeyDown(Enum.KeyCode.Space)
				local tooHigh = root.Position.Y > Config.Lobby.Center.Y + Config.Mounts.MaxHeight
				if rising and not tooHigh then
					root.AssemblyLinearVelocity = Vector3.new(v.X, Config.Mounts.FlyUpSpeed, v.Z)
				elseif v.Y < -Config.Mounts.FallSpeed then
					root.AssemblyLinearVelocity = Vector3.new(v.X, -Config.Mounts.FallSpeed, v.Z)
				end
			end
		end
		-- Galloping legs.
		if dt <= 0 then
			return
		end
		for model, horse in horses do
			local root = model.PrimaryPart
			if not model.Parent or not root then
				horses[model] = nil
				continue
			end
			local moved = Vector3.new(root.Position.X - horse.last.X, 0, root.Position.Z - horse.last.Z).Magnitude
			horse.last = root.Position
			horse.speed += (moved / dt - horse.speed) * math.min(1, dt * 8)
			local running = math.clamp(horse.speed / 6, 0, 1)
			horse.gait += dt * (6 + horse.speed * 0.4)
			for _, leg in horse.legs do
				leg.weld.C0 = leg.base * CFrame.Angles(math.sin(horse.gait + leg.phase) * 0.7 * running, 0, 0)
			end
			-- Wings beat slowly at rest and hard while moving.
			local beat = math.sin(os.clock() * (2.5 + running * 5)) * (0.25 + running * 0.45)
			for _, wing in horse.wings do
				wing.weld.C0 = wing.base * CFrame.Angles(0, 0, wing.side * (beat + 0.15))
			end
		end
	end)
end

return MountController
