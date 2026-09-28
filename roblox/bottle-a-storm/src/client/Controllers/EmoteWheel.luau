-- 😀 The emote wheel: press G (or the 😀 button) and pick an emote from the
-- ring. Locked ones show their price; click to buy (EmoteService). Built-in
-- Roblox emotes play on your character; spin, backflip, hops and sit are
-- moves made here (your own screen moves your character).

local ContextActionService = game:GetService("ContextActionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local EmoteData = require(Shared.EmoteData)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local Toasts = require(script.Parent.Toasts)
local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local EmoteWheel = {}

local window: Frame
local slots: { [string]: TextButton } = {}
local busy = false

local function owned(): { [string]: boolean }
	local raw = player:GetAttribute("Emotes")
	local ok, list = pcall(HttpService.JSONDecode, HttpService, if type(raw) == "string" then raw else "[]")
	local set = {}
	if ok and type(list) == "table" then
		for _, key in list do
			set[key] = true
		end
	end
	return set
end

local function has(emote: EmoteData.Emote, set: { [string]: boolean }): boolean
	return emote.cost <= 0 or set[emote.key] == true
end

-- Turns the character around an axis over `seconds` (a spin or a flip).
local function rotate(root: BasePart, axis: Vector3, seconds: number)
	player:SetAttribute("EmoteMove", true)
	local start = os.clock()
	local base = root.CFrame
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local alpha = math.min(1, (os.clock() - start) / seconds)
		if root.Parent then
			local position = root.Position
			root.CFrame = CFrame.new(position) * base.Rotation * CFrame.fromAxisAngle(axis, alpha * math.pi * 2)
		end
		if alpha >= 1 then
			connection:Disconnect()
			player:SetAttribute("EmoteMove", nil)
		end
	end)
end

local function play(emote: EmoteData.Emote)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root or humanoid.Health <= 0 or busy then
		return
	end
	if emote.emote then
		pcall(function()
			humanoid:PlayEmote(emote.emote :: string)
		end)
		return
	end
	busy = true
	if emote.move == "spin" then
		rotate(root, Vector3.yAxis, 0.7)
		task.wait(0.75)
	elseif emote.move == "flip" then
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(v.X, 55, v.Z)
		task.wait(0.05)
		rotate(root, Vector3.xAxis, 0.65)
		task.wait(0.8)
	elseif emote.move == "hop" then
		for _ = 1, 3 do
			humanoid.Jump = true
			task.wait(0.45)
		end
	elseif emote.move == "sit" then
		humanoid.Sit = true
	end
	busy = false
end

local function refresh()
	local set = owned()
	for key, button in slots do
		local emote = EmoteData.get(key) :: EmoteData.Emote
		if has(emote, set) then
			button.Text = emote.emoji .. "\n" .. emote.name
			button.BackgroundColor3 = UI.Colors.PanelLight
		else
			button.Text = "🔒 " .. emote.emoji .. "\n⚡" .. Format.number(emote.cost)
			button.BackgroundColor3 = UI.Colors.Disabled
		end
	end
end

function EmoteWheel.toggle()
	window.Visible = not window.Visible
	if window.Visible then
		refresh()
	end
end

local function onPick(emote: EmoteData.Emote)
	if has(emote, owned()) then
		window.Visible = false
		task.spawn(play, emote)
		return
	end
	task.spawn(function()
		local ok, success, message = pcall(function()
			return Remotes.func("BuyEmote"):InvokeServer(emote.key)
		end)
		if ok then
			Toasts.show(tostring(message), if success then "success" else "error")
		end
	end)
end

function EmoteWheel.start()
	local screen = UI.screen("EmoteWheel", 9)
	window = UI.new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(420, 420),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = screen,
	}, { UI.new("UIAspectRatioConstraint", { AspectRatio = 1 }) })
	UI.new("UIScale", { Parent = window })
	local center = UI.new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.28, 0.28),
		BackgroundColor3 = UI.Colors.Panel,
		Text = "😀\nEmotes\n(G)",
		TextColor3 = UI.Colors.Text,
		Font = UI.Font,
		TextSize = 16,
		Parent = window,
	}, { UI.corner(999), UI.stroke(UI.Colors.Stroke, 3) })
	center.Activated:Connect(function()
		window.Visible = false
	end)
	local count = #EmoteData.List
	for index, emote in EmoteData.List do
		local angle = (index - 1) / count * math.pi * 2 - math.pi / 2
		local button = UI.button({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5 + math.cos(angle) * 0.38, 0.5 + math.sin(angle) * 0.38),
			Size = UDim2.fromScale(0.2, 0.2),
			TextSize = 14,
			TextWrapped = true,
			Parent = window,
		})
		local corner = button:FindFirstChildOfClass("UICorner")
		if corner then
			corner.CornerRadius = UDim.new(0.5, 0)
		end
		button.Activated:Connect(function()
			onPick(emote)
		end)
		slots[emote.key] = button
	end
	-- A small 😀 button in the corner, and G on a keyboard.
	UI.button({
		AnchorPoint = Vector2.new(0, 1),
		-- (Above the thumbstick on phones.)
		Position = UDim2.new(0, 12, 1, if game:GetService("UserInputService").TouchEnabled then -210 else -12),
		Size = UDim2.fromOffset(52, 52),
		Text = "😀",
		TextSize = 28,
		Parent = screen,
	}).Activated
		:Connect(EmoteWheel.toggle)
	ContextActionService:BindAction("BottleAStormEmotes", function(_, state)
		if state == Enum.UserInputState.Begin then
			EmoteWheel.toggle()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.G)
	player:GetAttributeChangedSignal("Emotes"):Connect(refresh)
	refresh()
end

return EmoteWheel
