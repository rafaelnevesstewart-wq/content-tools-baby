-- Riding controls. Q (or the Ride button on phones) hops on and off your
-- storm. Shift (or the power button) uses its power (in Bed Wars: your kit's
-- power). Movement powers run here
-- because the player's own client moves their character.
--   Updraft    (wind storms)             launch high into the air
--   Blink Dash (lightning storms)        teleport forward
--   Surf Boost (ice and sand storms)     a burst of speed
--   Cloud Jump (rain, fog, rainbow)      jump again in mid-air; you also glide

local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local StormData = require(Shared.StormData)

local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local RideController = {}

local TOGGLE_ACTION = "BottleAStormRide"
local POWER_ACTION = "BottleAStormRidePower"

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
			root.AssemblyLinearVelocity = Vector3.new(v.X, Config.Ride.UpdraftPower, v.Z)
		end)
		return true
	end,

	BlinkDash = function(character, root)
		local look = flatLook(root)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character }
		local hit = workspace:Raycast(root.Position, look * Config.Ride.DashDistance, params)
		local distance = if hit
			then math.max(0, (hit.Position - root.Position).Magnitude - 3)
			else Config.Ride.DashDistance
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
		push.VectorVelocity = flatLook(root) * Config.Ride.SurfSpeed
		push.Parent = root
		Debris:AddItem(push, Config.Ride.SurfSeconds)
		Debris:AddItem(attachment, Config.Ride.SurfSeconds)
		return true
	end,

	CloudJump = function(_character, root, humanoid)
		if humanoid.FloorMaterial ~= Enum.Material.Air or usedAirJump then
			return false
		end
		usedAirJump = true
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(v.X, Config.Ride.CloudJumpPower, v.Z)
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
		readyAt[ability] = os.clock() + (Config.Ride.Cooldowns[ability] or 1)
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
	local riding = player:GetAttribute("Riding")
	local kit = player:GetAttribute("KitName")
	local ability = player:GetAttribute("RideAbility")
	label.Visible = riding ~= nil or kit ~= nil
	if not riding and not kit then
		return
	end
	local info = ability and StormData.AbilityInfo[ability]
	local text = if riding then "🐎 Riding " .. tostring(riding) else "🌪️ Kit: " .. tostring(kit)
	if info then
		local wait = (readyAt[ability] or 0) - os.clock()
		local status = if wait > 0 then string.format("%.0fs", math.ceil(wait)) else "ready"
		text ..= "  ·  Shift: " .. info.emoji .. " " .. info.name .. " (" .. status .. ")"
	end
	label.Text = text
end

function RideController.start()
	local screen = UI.screen("Ride", 2)
	label = UI.label({
		Name = "RideLabel",
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

	-- In Bed Wars your storm is a kit instead (its power works without riding).
	if Config.GameMode ~= "BedWars" then
		ContextActionService:BindAction(TOGGLE_ACTION, function(_, state)
			if state == Enum.UserInputState.Begin then
				Remotes.event("ToggleRide"):FireServer()
			end
			return Enum.ContextActionResult.Sink
		end, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonY)
		ContextActionService:SetTitle(TOGGLE_ACTION, "Ride")
	end

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
			if v.Y < -Config.Ride.GlideFallSpeed then
				root.AssemblyLinearVelocity = Vector3.new(v.X, -Config.Ride.GlideFallSpeed, v.Z)
			end
		end
	end)
end

return RideController
