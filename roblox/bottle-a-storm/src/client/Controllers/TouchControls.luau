-- Bigger fight buttons for phones and tablets, next to the jump button:
--   ⚔️ Use: swing, shoot, throw, eat or place with whatever you're holding,
--          aimed at the crosshair in the middle of the screen
--   🎒 Next: switch to your next item (no fiddling with the tiny backpack)
-- Turn them off in ⚙️ Settings ("Big fight buttons").

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Aim = require(script.Parent.Aim)
local Settings = require(script.Parent.Settings)
local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local TouchControls = {}

local function roundButton(parent: Instance, text: string, size: number, position: UDim2, color: Color3): TextButton
	local button = UI.button({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = UDim2.fromOffset(size, size),
		Text = text,
		TextSize = size * 0.42,
		BackgroundColor3 = color,
		BackgroundTransparency = 0.15,
		Parent = parent,
	})
	local corner = button:FindFirstChildOfClass("UICorner")
	if corner then
		corner.CornerRadius = UDim.new(0.5, 0) -- round
	end
	return button
end

local function holding(): Tool?
	local character = player.Character
	return if character then character:FindFirstChildOfClass("Tool") else nil
end

-- Every tool you have, in a steady order, and the one after the held one.
local function nextTool(): Tool?
	local tools: { Tool } = {}
	local backpack = player:FindFirstChildOfClass("Backpack")
	for _, container in { backpack, player.Character } do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") then
					table.insert(tools, child)
				end
			end
		end
	end
	if #tools == 0 then
		return nil
	end
	table.sort(tools, function(a, b)
		return a.Name < b.Name
	end)
	local current = holding()
	local index = if current then table.find(tools, current) else nil
	return tools[if index then index % #tools + 1 else 1]
end

function TouchControls.start()
	if not UserInputService.TouchEnabled then
		return
	end
	local screen = UI.screen("TouchControls", 2)
	local holder = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = screen,
	})
	local useButton = roundButton(holder, "⚔️", 84, UDim2.new(1, -210, 1, -80), Color3.fromRGB(206, 64, 78))
	local nextButton = roundButton(holder, "🎒", 60, UDim2.new(1, -90, 1, -190), Color3.fromRGB(70, 90, 140))
	local crosshair = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(8, 8),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.2,
		Visible = false,
		Parent = holder,
	}, { UI.corner(4), UI.stroke(Color3.new(0, 0, 0), 1) })
	screen.IgnoreGuiInset = true

	useButton.Activated:Connect(function()
		local tool = holding()
		if not tool then
			local first = nextTool()
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if first and humanoid then
				humanoid:EquipTool(first)
			end
			return
		end
		Aim.aimAtCenter()
		tool:Activate()
	end)
	nextButton.Activated:Connect(function()
		local tool = nextTool()
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if tool and humanoid then
			humanoid:EquipTool(tool)
		end
	end)

	local function refresh()
		local on = Settings.get("phoneButtons") == true
		holder.Visible = on
		crosshair.Visible = on and holding() ~= nil
	end
	refresh()
	Settings.Changed:Connect(refresh)
	local function watchCharacter(character: Model)
		character.ChildAdded:Connect(refresh)
		character.ChildRemoved:Connect(refresh)
		refresh()
	end
	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		watchCharacter(player.Character)
	end
end

return TouchControls
