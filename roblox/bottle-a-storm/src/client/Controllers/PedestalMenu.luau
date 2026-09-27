-- The small menu that pops up when you press F ("Options") at one of your
-- own pedestals: Ride it, make it your Guard, or Sell it (tap Sell twice).

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local StormData = require(Shared.StormData)

local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local PedestalMenu = {}

local window: Frame
local title: TextLabel
local info: TextLabel
local guardButton: TextButton
local buddyButton: TextButton
local sellButton: TextButton
local currentBase: BasePart? = nil
local sellArmed = false

local function close()
	window.Visible = false
	currentBase = nil
end

local function send(action: string)
	local base = currentBase
	local slot = base and base:GetAttribute("Slot")
	if type(slot) == "number" then
		Remotes.event("PedestalAction"):FireServer(slot, action)
	end
	close()
end

local function sellPrice(base: BasePart): number
	local id = base:GetAttribute("StormId")
	local mut = base:GetAttribute("StormMut")
	if type(id) ~= "string" then
		return 0
	end
	local record = { id = id, mut = if type(mut) == "string" then mut else nil }
	return math.floor(StormData.incomeOf(record) * Config.Income.SellSeconds)
end

local function open(base: BasePart)
	local id = base:GetAttribute("StormId")
	local def = if type(id) == "string" then StormData.get(id) else nil
	if not def then
		return
	end
	local mut = base:GetAttribute("StormMut")
	local record = { id = def.id, mut = if type(mut) == "string" then mut else nil }
	currentBase = base
	sellArmed = false

	title.Text = StormData.displayName(record)
	title.TextColor3 = UI.ink(StormData.rarityOf(def).color)
	local level = base:GetAttribute("StormLevel")
	info.Text = "Lv "
		.. (if type(level) == "number" then level else 1)
		.. " · "
		.. StormData.rarityOf(def).name
		.. " · ⚡"
		.. Format.number(StormData.incomeOf(record))
		.. "/s base"

	local guarding = player:GetAttribute("GuardUid") ~= nil
		and player:GetAttribute("GuardUid") == base:GetAttribute("StormUid")
	guardButton.Text = if guarding then "🛡️ Stop guarding" else "🛡️ Guard my island"
	local isBuddy = player:GetAttribute("BuddyUid") ~= nil
		and player:GetAttribute("BuddyUid") == base:GetAttribute("StormUid")
	buddyButton.Text = if isBuddy then "💕 Stop following me" else "💕 Make it my buddy"
	sellButton.Text = "💰 Sell for ⚡" .. Format.number(sellPrice(base))
	sellButton.BackgroundColor3 = UI.Colors.Warn
	window.Visible = true
end

function PedestalMenu.start()
	local screen = UI.screen("PedestalMenu", 5)
	window = UI.new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(300, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = UI.Colors.Panel,
		Visible = false,
		Parent = screen,
	}, { UI.corner(18), UI.stroke(UI.Colors.Stroke, 3), UI.padding(12), UI.list(8) })

	-- Shrinks on short (phone) screens so every button fits.
	local scale = UI.new("UIScale", { Parent = window })
	local function fit()
		local camera = workspace.CurrentCamera
		local height = if camera then camera.ViewportSize.Y else 800
		scale.Scale = math.clamp((height - 40) / 480, 0.55, 1)
	end
	fit()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end

	title = UI.label({ LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 28), TextSize = 22, Parent = window })
	info = UI.label({
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 15,
		TextColor3 = UI.Colors.Muted,
		Parent = window,
	})

	local function big(order: number, text: string, color: Color3): TextButton
		return UI.button({
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 44),
			Text = text,
			TextSize = 20,
			BackgroundColor3 = color,
			Parent = window,
		})
	end

	big(3, "🌪️ Ride", Color3.fromRGB(140, 195, 255)).Activated:Connect(function()
		send("ride")
	end)
	guardButton = big(4, "🛡️ Guard my island", UI.Colors.Rare)
	guardButton.Activated:Connect(function()
		send("guard")
	end)
	buddyButton = big(5, "💕 Make it my buddy", Color3.fromRGB(255, 160, 200))
	buddyButton.Activated:Connect(function()
		send("buddy")
	end)
	sellButton = big(6, "💰 Sell", UI.Colors.Warn)
	sellButton.Activated:Connect(function()
		local base = currentBase
		if not base then
			return
		end
		if not sellArmed then
			sellArmed = true
			sellButton.Text = "Tap again to sell for ⚡" .. Format.number(sellPrice(base))
			sellButton.BackgroundColor3 = UI.Colors.Bad
			return
		end
		send("sell")
	end)
	big(7, "Close", UI.Colors.PanelLight).Activated:Connect(close)

	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who ~= player or prompt.Name ~= "OptionsPrompt" then
			return
		end
		local base = prompt.Parent
		if base and base:IsA("BasePart") and base:GetAttribute("OwnerUserId") == player.UserId then
			open(base)
		end
	end)

	-- Close when you walk away or the storm leaves the pedestal.
	task.spawn(function()
		while true do
			task.wait(0.3)
			local base = currentBase
			if window.Visible and base then
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local far = not root or (root.Position - base.Position).Magnitude > 20
				if far or base:GetAttribute("HasStorm") ~= true or base:GetAttribute("BeingStolen") == true then
					close()
				end
			end
		end
	end)
end

return PedestalMenu
