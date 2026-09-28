-- Bed Wars weapons and gadgets: click with the Sword (or the Knockback
-- Stick) to swing, the Bow to
-- shoot, the Storm Apple to eat, the Wind Pearl or a Fireball to throw, a
-- potion to drink, and a Pickaxe or Axe to mine blocks. (Storm TNT is placed
-- by BlockController.) This only aims and asks; the server checks it all.

local Players = game:GetService("Players")

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
