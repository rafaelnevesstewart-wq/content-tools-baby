-- Kit powers (Bed Wars). In a match your kit storm floats beside you and
-- Shift (or the power button on phones) uses its power. The powers run here
-- because the player's own client moves their character. Rarer kits recharge
-- faster (the KitCooldown attribute, set by KitService).
--   Updraft      (wind, hurricane, fire)   launch high into the air
--   Blink Dash   (lightning, stars)        teleport forward
--   Surf Boost   (ice, hail, sand)         a burst of speed
--   Cloud Jump   (rain, fog, rainbow)      jump again in mid-air; you also glide
--   Cloud Flight (a few rare kits)         fly where you look for a few seconds

local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local StormData = require(Shared.StormData)

local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local KitController = {}

local POWER_ACTION = "BottleAStormKitPower"

local readyAt: { [string]: number } = {}
local usedAirJump = false
local label: TextLabel

local function parts(): (Model?, BasePart?, Humanoid?)
	local character = player.Character
	if not character then
		return nil, nil, nil
	end
	return character,
		character:FindFirstChild("HumanoidRootPart") :: BasePart?,
		character:FindFirstChildOfClass("Humanoid")
end

local function flatLook(root: BasePart): Vector3
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	return if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)
end

local powers: { [string]: (Model, BasePart, Humanoid) -> boolean } = {
	Updraft = function(_character, root, humanoid)
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		task.defer(function()
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(v.X, Config.Kit.UpdraftPower, v.Z)
		end)
		return true
	end,

	BlinkDash = function(character, root)
		local look = flatLook(root)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character }
		local hit = workspace:Raycast(root.Position, look * Config.Kit.DashDistance, params)
		local distance = if hit
			then math.max(0, (hit.Position - root.Position).Magnitude - 3)
			else Config.Kit.DashDistance
		character:PivotTo(character:GetPivot() + look * distance)
		return true
	end,

	Surf = function(_character, root)
		local attachment = Instance.new("Attachment")
		attachment.Name = "SurfAttachment"
		attachment.Parent = root
		local push = Instance.new("LinearVelocity")
		push.Attachment0 = attachment
		push.RelativeTo = Enum.ActuatorRelativeTo.World
		push.ForceLimitMode = Enum.ForceLimitMode.PerAxis
		push.MaxAxesForce = Vector3.new(1e5, 0, 1e5) -- gravity still works
		push.VectorVelocity = flatLook(root) * Config.Kit.SurfSpeed
		push.Parent = root
		Debris:AddItem(push, Config.Kit.SurfSeconds)
		Debris:AddItem(attachment, Config.Kit.SurfSeconds)
		return true
	end,

	Flight = function(_character, root)
		local camera = workspace.CurrentCamera
		local attachment = Instance.new("Attachment")
		attachment.Name = "FlightAttachment"
		attachment.Parent = root
		local lift = Instance.new("LinearVelocity")
		lift.Attachment0 = attachment
		lift.RelativeTo = Enum.ActuatorRelativeTo.World
		lift.MaxForce = 1e6
		lift.Parent = root
		local cloud = Instance.new("Part")
		cloud.Name = "FlightCloud"
		cloud.Shape = Enum.PartType.Ball
		cloud.Size = Vector3.new(4, 2, 4)
		cloud.Color = Color3.fromRGB(250, 251, 255)
		cloud.Material = Enum.Material.SmoothPlastic
		cloud.CanCollide = false
		cloud.CanQuery = false
		cloud.CanTouch = false
		cloud.Massless = true
		cloud.CFrame = root.CFrame * CFrame.new(0, -3.2, 0)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = cloud
		weld.Parent = cloud
		cloud.Parent = root.Parent
		local endsAt = os.clock() + Config.Kit.FlightSeconds
		task.spawn(function()
			while os.clock() < endsAt and lift.Parent do
				local look = if camera then camera.CFrame.LookVector else root.CFrame.LookVector
				lift.VectorVelocity = look * Config.Kit.FlightSpeed
				RunService.Heartbeat:Wait()
			end
			lift:Destroy()
			attachment:Destroy()
			cloud:Destroy()
		end)
		return true
	end,

	CloudJump = function(_character, root, humanoid)
		if humanoid.FloorMaterial ~= Enum.Material.Air or usedAirJump then
			return false
		end
		usedAirJump = true
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(v.X, Config.Kit.CloudJumpPower, v.Z)
		return true
	end,
}

local function usePower(_, state: Enum.UserInputState)
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	local ability = player:GetAttribute("RideAbility")
	local power = ability and powers[ability]
	local character, root, humanoid = parts()
	if not power or not character or not root or not humanoid or humanoid.Health <= 0 or humanoid.WalkSpeed == 0 then
		return Enum.ContextActionResult.Sink
	end
	if os.clock() < (readyAt[ability] or 0) then
		return Enum.ContextActionResult.Sink
	end
	if power(character, root, humanoid) then
		local scale = player:GetAttribute("KitCooldown")
		readyAt[ability] = os.clock()
			+ (Config.Kit.Cooldowns[ability] or 1) * (if type(scale) == "number" then scale else 1)
	end
	return Enum.ContextActionResult.Sink
end

local function refreshBindings()
	local ability = player:GetAttribute("RideAbility")
	ContextActionService:UnbindAction(POWER_ACTION)
	if ability then
		ContextActionService:BindAction(POWER_ACTION, usePower, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonX)
		local info = StormData.AbilityInfo[ability]
		ContextActionService:SetTitle(POWER_ACTION, if info then info.emoji else "✨")
	end
end

local function refreshLabel()
	local kit = player:GetAttribute("KitName")
	local ability = player:GetAttribute("RideAbility")
	label.Visible = kit ~= nil
	if not kit then
		return
	end
	local info = ability and StormData.AbilityInfo[ability]
	local text = "🌪️ Kit: " .. tostring(kit)
	if info then
		local wait = (readyAt[ability] or 0) - os.clock()
		local status = if wait > 0 then string.format("%.0fs", math.ceil(wait)) else "ready"
		text ..= "  ·  Shift: " .. info.emoji .. " " .. info.name .. " (" .. status .. ")"
	end
	label.Text = text
end

function KitController.start()
	local screen = UI.screen("Kit", 2)
	label = UI.label({
		Name = "KitLabel",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -160),
		Size = UDim2.fromOffset(0, 32),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.2,
		TextSize = 18,
		Visible = false,
		Parent = screen,
	})
	UI.corner(10).Parent = label
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = label })

	player:GetAttributeChangedSignal("RideAbility"):Connect(refreshBindings)
	refreshBindings()

	RunService.RenderStepped:Connect(function()
		refreshLabel()
		local _, root, humanoid = parts()
		if not root or not humanoid then
			return
		end
		if humanoid.FloorMaterial ~= Enum.Material.Air then
			usedAirJump = false
		end
		-- Cloud riders glide instead of falling fast.
		if player:GetAttribute("RideAbility") == "CloudJump" then
			local v = root.AssemblyLinearVelocity
			if v.Y < -Config.Kit.GlideFallSpeed then
				root.AssemblyLinearVelocity = Vector3.new(v.X, -Config.Kit.GlideFallSpeed, v.Z)
			end
		end
	end)
end

return KitController
