-- Bed Wars weapons: click with the Sword to swing, the Bow to shoot, the
-- Storm Apple to eat and the Wind Pearl to throw. This only aims and asks;
-- CombatService on the server checks every hit.

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
	Aim.hookTool("Sword", function()
		if os.clock() - lastSwing < 0.3 then
			return
		end
		lastSwing = os.clock()
		slash("Sword")
		Sfx.play("throw", 1.3 + math.random() * 0.2)
		Remotes.event("Swing"):FireServer(Aim.point(enemyRoots(), 2))
	end)
	Aim.hookTool("Bow", function()
		Sfx.play("throw", 0.8)
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
end

return WeaponController
