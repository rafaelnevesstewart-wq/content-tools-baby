-- Bed Wars weapons and gadgets: click with the Sword (or the Knockback
-- Stick) to swing, the Bow to
-- shoot, the Storm Apple to eat, the Wind Pearl or a Fireball to throw, a
-- potion to drink, and a Pickaxe or Axe to mine blocks. (Storm TNT is placed
-- by BlockController.) This only aims and asks; the server checks it all.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local Aim = require(script.Parent.Aim)
local Sfx = require(script.Parent.Sfx)

local player = Players.LocalPlayer

local WeaponController = {}

-- The root parts of players on other teams.
local function enemyRoots(): { BasePart }
	local mine = player:GetAttribute("TeamKey")
	local list = {}
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if other ~= player and root and root:IsA("BasePart") and other:GetAttribute("TeamKey") ~= mine then
			table.insert(list, root)
		end
	end
	return list
end

-- The Grappling Hook: shoots a rope to a wall or ledge you aim at and pulls
-- you there (your own screen moves your character).
local GRAPPLE_RANGE = 90
local GRAPPLE_SPEED = 85
local lastGrapple = 0

local function grapple()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not root or not humanoid or os.clock() - lastGrapple < 1.5 then
		return
	end
	local aim = Aim.point({}, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local offset = aim - root.Position
	if offset.Magnitude < 4 then
		return
	end
	local hit = workspace:Raycast(root.Position, offset.Unit * math.min(offset.Magnitude + 2, GRAPPLE_RANGE), params)
	if not hit then
		Sfx.play("oops")
		return
	end
	lastGrapple = os.clock()
	Sfx.play("throw", 0.6)
	local target = hit.Position
	-- The rope: a beam from your hand to a hook stuck where you aimed.
	local hook = Instance.new("Part")
	hook.Name = "GrappleHook"
	hook.Anchored = true
	hook.CanCollide = false
	hook.CanQuery = false
	hook.Size = Vector3.one * 0.5
	hook.Color = Color3.fromRGB(190, 194, 202)
	hook.Material = Enum.Material.Metal
	hook.CFrame = CFrame.new(target)
	hook.Parent = workspace
	local hookPoint = Instance.new("Attachment")
	hookPoint.Parent = hook
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm") or root
	local handPoint = Instance.new("Attachment")
	handPoint.Parent = hand
	local rope = Instance.new("Beam")
	rope.Attachment0 = handPoint
	rope.Attachment1 = hookPoint
	rope.Width0 = 0.15
	rope.Width1 = 0.15
	rope.Color = ColorSequence.new(Color3.fromRGB(176, 150, 110))
	rope.FaceCamera = true
	rope.Segments = 1
	rope.Parent = hook
	-- The pull.
	local attachment = Instance.new("Attachment")
	attachment.Parent = root
	local pull = Instance.new("LinearVelocity")
	pull.Attachment0 = attachment
	pull.RelativeTo = Enum.ActuatorRelativeTo.World
	pull.MaxForce = 1e6
	pull.Parent = root
	local started = os.clock()
	local connection: RBXScriptConnection? = nil
	local function finish()
		if connection then
			connection:Disconnect()
		end
		pull:Destroy()
		attachment:Destroy()
		handPoint:Destroy()
		Debris:AddItem(hook, 0.1)
		-- A little hop at the end so you land on the ledge.
		if root.Parent then
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(v.X * 0.3, 30, v.Z * 0.3)
		end
	end
	connection = RunService.Heartbeat:Connect(function()
		local toTarget = target - root.Position
		if toTarget.Magnitude < 5 or os.clock() - started > 1.6 or humanoid.Health <= 0 or not root.Parent then
			finish()
			return
		end
		pull.VectorVelocity = toTarget.Unit * GRAPPLE_SPEED
	end)
end

-- The default Animate script plays a slash when a Tool gets this value.
local function slash(toolName: string)
	local character = player.Character
	local tool = character and character:FindFirstChild(toolName)
	if tool then
		local value = Instance.new("StringValue")
		value.Name = "toolanim"
		value.Value = "Slash"
		value.Parent = tool
		task.delay(0.3, function()
			value:Destroy()
		end)
	end
end

function WeaponController.start()
	local lastSwing = 0
	for _, toolName in { "Sword", "Knockback Stick" } do
		Aim.hookTool(toolName, function()
			if os.clock() - lastSwing < 0.3 then
				return
			end
			lastSwing = os.clock()
			slash(toolName)
			if toolName == "Sword" then
				Sfx.play("slash", 0.95 + math.random() * 0.15)
			else
				Sfx.play("throw", 0.9 + math.random() * 0.2)
			end
			Remotes.event("Swing"):FireServer(Aim.point(enemyRoots(), 2))
		end)
	end
	Aim.hookTool("Bow", function()
		Sfx.play("arrow", 0.9 + math.random() * 0.2)
		Remotes.event("ShootBow"):FireServer(Aim.point(enemyRoots(), 4))
	end)
	Aim.hookTool("Storm Apple", function()
		Sfx.play("pop", 0.8)
		Remotes.event("UseItem"):FireServer("StormApple")
	end)
	Aim.hookTool("Wind Pearl", function()
		Sfx.play("throw", 1)
		Remotes.event("UseItem"):FireServer("WindPearl", Aim.point({}, 0))
	end)
	Aim.hookTool("Rocket Launcher", function()
		Sfx.play("boom", 1.4)
		Remotes.event("UseGadget"):FireServer("Rocket", Aim.point(enemyRoots(), 3))
	end)
	Aim.hookTool("Grappling Hook", grapple)
	Aim.hookTool("Range Bow", function()
		Sfx.play("arrow", 1)
		Remotes.event("RangeShot"):FireServer(Aim.point(Aim.rootsIn("RangeTargets"), 2))
	end)
	Aim.hookTool("Fireball", function()
		Sfx.play("throw", 0.7)
		Remotes.event("UseGadget"):FireServer("Fireball", Aim.point(enemyRoots(), 4))
	end)
	for toolName, key in
		{ ["Speed Potion"] = "SpeedPotion", ["Jump Potion"] = "JumpPotion", ["Invisibility Potion"] = "InvisPotion" }
	do
		Aim.hookTool(toolName, function()
			Sfx.play("pop", 0.6)
			Remotes.event("UseGadget"):FireServer(key, Vector3.zero)
		end)
	end
	local lastMine = 0
	for _, toolName in { "Pickaxe", "Axe" } do
		Aim.hookTool(toolName, function()
			if os.clock() - lastMine < 0.3 then
				return
			end
			lastMine = os.clock()
			slash(toolName)
			Sfx.play("pop", 1.4)
			Remotes.event("UseGadget"):FireServer("Mine", Aim.point({}, 0))
		end)
	end

	-- While you're invisible, you still see a ghost of yourself.
	local function showGhost()
		local character = player.Character
		if not character or not player:GetAttribute("Invisible") then
			return
		end
		for _, part in character:GetDescendants() do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Transparency >= 1 then
				part.Transparency = 0.75
			end
		end
	end
	player:GetAttributeChangedSignal("Invisible"):Connect(function()
		task.wait(0.2) -- after the server's change arrives
		showGhost()
	end)
end

return WeaponController
