-- Cloud Flight controls. G (or the ☁️ button on phones) takes off and lands.
-- While flying: move as normal, Space (⬆️) goes up and Ctrl or C (⬇️) goes
-- down. Players without the pass get offered it when they press G.
-- The server decides when you can fly (FlightService); this only moves you.

local ContextActionService = game:GetService("ContextActionService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Products = require(Shared.Products)
local Remotes = require(Shared.Remotes)

local Toasts = require(script.Parent.Toasts)
local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local FlightController = {}

local TOGGLE_ACTION = "BottleAStormFly"
local UP_ACTION = "BottleAStormFlyUp"
local DOWN_ACTION = "BottleAStormFlyDown"

local flyEvent: RemoteEvent
local label: TextLabel
local up = false
local down = false
local attachment: Attachment? = nil
local velocity: LinearVelocity? = nil

local function ownsPass(): boolean
	return player:GetAttribute(Products.passAttribute("Flight")) == true
end

local function offerPass()
	local pass = Products.get("Flight")
	if not pass then
		return
	end
	if pass.id ~= 0 then
		MarketplaceService:PromptGamePassPurchase(player, pass.id)
	elseif RunService:IsStudio() then
		Remotes.event("DevPurchase"):FireServer(pass.key)
	else
		Toasts.show("☁️ Cloud Flight is coming soon!", "info")
	end
end

local function stopPhysics()
	if velocity then
		velocity:Destroy()
		velocity = nil
	end
	if attachment then
		attachment:Destroy()
		attachment = nil
	end
	up, down = false, false
	ContextActionService:UnbindAction(UP_ACTION)
	ContextActionService:UnbindAction(DOWN_ACTION)
end

local function startPhysics()
	stopPhysics()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local a = Instance.new("Attachment")
	a.Name = "FlightAttachment"
	a.Parent = root
	local v = Instance.new("LinearVelocity")
	v.Name = "FlightVelocity"
	v.Attachment0 = a
	v.RelativeTo = Enum.ActuatorRelativeTo.World
	v.MaxForce = 1e6
	v.VectorVelocity = Vector3.zero
	v.Parent = root
	attachment, velocity = a, v

	-- Up and down, only while flying (so Space still jumps normally).
	ContextActionService:BindActionAtPriority(UP_ACTION, function(_, state)
		up = state == Enum.UserInputState.Begin or state == Enum.UserInputState.Change
		return Enum.ContextActionResult.Sink
	end, true, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
	ContextActionService:SetTitle(UP_ACTION, "⬆️")
	ContextActionService:BindActionAtPriority(DOWN_ACTION, function(_, state)
		down = state == Enum.UserInputState.Begin or state == Enum.UserInputState.Change
		return Enum.ContextActionResult.Sink
	end, true, Enum.ContextActionPriority.High.Value, Enum.KeyCode.LeftControl, Enum.KeyCode.C, Enum.KeyCode.ButtonB)
	ContextActionService:SetTitle(DOWN_ACTION, "⬇️")
end

local function refreshLabel()
	local now = workspace:GetServerTimeNow()
	local endsAt = player:GetAttribute("FlyEndsAt")
	local readyAt = player:GetAttribute("FlyReadyAt")
	if player:GetAttribute("Flying") and type(endsAt) == "number" then
		label.Visible = true
		label.Text = "☁️ Flying " .. Format.time(endsAt - now) .. "  ·  Space ⬆️  Ctrl ⬇️  ·  G to land"
		ContextActionService:SetTitle(TOGGLE_ACTION, "Land")
	elseif ownsPass() and type(readyAt) == "number" and readyAt > now then
		label.Visible = false
		ContextActionService:SetTitle(TOGGLE_ACTION, "☁️ " .. math.ceil(readyAt - now))
	else
		label.Visible = false
		ContextActionService:SetTitle(TOGGLE_ACTION, "☁️ Fly")
	end
end

function FlightController.start()
	flyEvent = Remotes.event("Fly")
	local screen = UI.screen("Flight", 2)
	label = UI.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -200),
		Size = UDim2.fromOffset(0, 32),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.15,
		TextSize = 18,
		Visible = false,
		Parent = screen,
	})
	UI.corner(10).Parent = label
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = label })

	ContextActionService:BindAction(TOGGLE_ACTION, function(_, state)
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		if player:GetAttribute("Flying") then
			flyEvent:FireServer(false)
		elseif ownsPass() then
			flyEvent:FireServer(true)
		else
			offerPass()
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.G, Enum.KeyCode.DPadUp)

	player:GetAttributeChangedSignal("Flying"):Connect(function()
		if player:GetAttribute("Flying") then
			startPhysics()
		else
			stopPhysics()
		end
	end)
	player.CharacterAdded:Connect(stopPhysics)

	RunService.RenderStepped:Connect(function()
		refreshLabel()
		local v = velocity
		if not v then
			return
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not humanoid or not root then
			return
		end
		local vertical = (if up then 1 else 0) - (if down then 1 else 0)
		if root.Position.Y > Config.Flight.MaxHeight and vertical > 0 then
			vertical = 0
		end
		v.VectorVelocity = humanoid.MoveDirection * Config.Flight.Speed
			+ Vector3.new(0, vertical * Config.Flight.VerticalSpeed, 0)
	end)
end

return FlightController
