-- Your fighter's vitals and belongings: health, power and XP bars with your
-- level and strength, the inventory panel, the death screen and level-up flash.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Util = require(Shared:WaitForChild("Util"))

local player = Players.LocalPlayer
local state = nil

local FONT = Enum.Font.GothamMedium
local PANEL = Color3.fromRGB(28, 32, 44)
local GOLD = Color3.fromRGB(214, 180, 116)

local function make(className: string, props, children)
	local instance = Instance.new(className)
	for key, value in props or {} do
		instance[key] = value
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	return instance
end

local function corner(radius: number)
	return make("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function label(props)
	local defaults = { BackgroundTransparency = 1, Font = FONT, TextColor3 = Color3.new(1, 1, 1), TextScaled = true }
	for key, value in props do
		defaults[key] = value
	end
	return make("TextLabel", defaults)
end

local gui = make("ScreenGui", { Name = "Vitals", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })

-- Vitals bars --------------------------------------------------------------------

local vitals = make("Frame", {
	Size = UDim2.fromOffset(380, 66),
	Position = UDim2.new(0.5, -190, 1, -152),
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.15,
}, { corner(12) })
vitals.Parent = gui

local levelBadge = label({
	Size = UDim2.fromOffset(54, 54),
	Position = UDim2.fromOffset(6, 6),
	BackgroundTransparency = 0,
	BackgroundColor3 = Color3.fromRGB(60, 45, 20),
	TextColor3 = GOLD,
	Text = "Lv 1",
	Parent = vitals,
})
corner(27).Parent = levelBadge
make("UIStroke", { Color = GOLD, Thickness = 2 }).Parent = levelBadge

local function vitalBar(row: number, color: Color3, icon: string)
	local back = make("Frame", {
		Size = UDim2.new(1, -72 - 70, 0, 16),
		Position = UDim2.fromOffset(66, 5 + row * 20),
		BackgroundColor3 = Color3.fromRGB(45, 48, 60),
	}, { corner(6) })
	local fill = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color }, { corner(6) })
	fill.Parent = back
	local text = label({ Size = UDim2.fromScale(1, 1), Text = "", ZIndex = 2, TextStrokeTransparency = 0.4, Parent = back })
	make("UITextSizeConstraint", { MaxTextSize = 13 }).Parent = text
	label({ Size = UDim2.fromOffset(16, 16), Position = UDim2.new(1, 4, 0, 0), Text = icon, Parent = back })
	back.Parent = vitals
	return fill, text
end

local healthFill, healthText = vitalBar(0, Color3.fromRGB(150, 36, 36), "HP")
local powerFill, powerText = vitalBar(1, Color3.fromRGB(52, 82, 150), "MP")
local xpFill, xpText = vitalBar(2, GOLD, "XP")

local strengthLabel = label({
	Size = UDim2.fromOffset(52, 40),
	Position = UDim2.new(1, -56, 0.5, -20),
	TextColor3 = Color3.fromRGB(255, 150, 110),
	Text = "STR\n100",
	Parent = vitals,
})
make("UITextSizeConstraint", { MaxTextSize = 16 }).Parent = strengthLabel

local function setBar(fill: Frame, text: TextLabel, value: number, maxValue: number, suffix: string?)
	fill.Size = UDim2.fromScale(math.clamp(value / math.max(maxValue, 1), 0, 1), 1)
	text.Text = string.format("%d / %d%s", math.floor(value + 0.5), math.floor(maxValue), suffix or "")
end

RunService.RenderStepped:Connect(function()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		setBar(healthFill, healthText, humanoid.Health, humanoid.MaxHealth)
	end
	setBar(powerFill, powerText, player:GetAttribute("Power") or 0, player:GetAttribute("MaxPower") or Config.Power.Base)
end)

-- Floating "+XP" when a kill lands.
local function xpPopup(amount: number)
	local popup = label({
		Size = UDim2.fromOffset(160, 30),
		Position = UDim2.new(0.5, -80, 1, -186),
		TextColor3 = GOLD,
		TextStrokeTransparency = 0.3,
		Text = "+" .. amount .. " XP",
		Parent = gui,
	})
	local tween = TweenService:Create(popup, TweenInfo.new(1.2), { Position = UDim2.new(0.5, -80, 1, -250), TextTransparency = 1, TextStrokeTransparency = 1 })
	tween:Play()
	tween.Completed:Once(function()
		popup:Destroy()
	end)
end

local function levelUpFlash(level: number)
	local banner = label({
		Size = UDim2.fromOffset(520, 80),
		Position = UDim2.new(0.5, -260, 0.28, 0),
		Font = Enum.Font.GothamBlack,
		TextColor3 = GOLD,
		TextStrokeTransparency = 0,
		TextStrokeColor3 = Color3.fromRGB(80, 40, 0),
		Text = "LEVEL UP!  " .. level,
		TextTransparency = 1,
		Parent = gui,
	})
	TweenService:Create(banner, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()
	task.delay(2, function()
		local tween = TweenService:Create(banner, TweenInfo.new(0.6), { TextTransparency = 1, TextStrokeTransparency = 1 })
		tween:Play()
		tween.Completed:Wait()
		banner:Destroy()
	end)
end

-- Inventory ------------------------------------------------------------------------

local inventory = make("Frame", {
	Name = "Inventory",
	Visible = false,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(0.5, 0, 0.7, 0),
	BackgroundColor3 = PANEL,
}, { corner(16), make("UISizeConstraint", { MaxSize = Vector2.new(560, 600), MinSize = Vector2.new(300, 320) }) })
inventory.Parent = gui

label({
	Size = UDim2.new(1, -70, 0, 40),
	Position = UDim2.fromOffset(16, 8),
	TextColor3 = GOLD,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "Inventory",
	Parent = inventory,
})
local closeButton = make("TextButton", {
	Size = UDim2.fromOffset(36, 36),
	Position = UDim2.new(1, -46, 0, 10),
	BackgroundColor3 = Color3.fromRGB(120, 44, 40),
	Font = FONT,
	TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "X",
}, { corner(8) })
closeButton.Activated:Connect(function()
	inventory.Visible = false
end)
closeButton.Parent = inventory

local invList = make("ScrollingFrame", {
	Size = UDim2.new(1, -24, 1, -62),
	Position = UDim2.fromOffset(12, 54),
	BackgroundTransparency = 1,
	CanvasSize = UDim2.new(),
	ScrollingDirection = Enum.ScrollingDirection.Y,
	ScrollBarThickness = 10,
	ScrollBarImageColor3 = GOLD,
	VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
})
local invLayout = make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
invLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	invList.CanvasSize = UDim2.fromOffset(0, invLayout.AbsoluteContentSize.Y + 12)
end)
invLayout.Parent = invList
invList.Parent = inventory

local invOrder = 0
local function invHeader(title: string)
	invOrder += 1
	local header = label({
		Size = UDim2.new(1, -8, 0, 26),
		TextColor3 = GOLD,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = title,
		LayoutOrder = invOrder,
		Parent = invList,
	})
	make("UITextSizeConstraint", { MaxTextSize = 20 }).Parent = header
end

local function invRow(title: string, detail: string, buttonText: string?, onClick)
	invOrder += 1
	local row = make("Frame", { Size = UDim2.new(1, -8, 0, 44), BackgroundColor3 = Color3.fromRGB(44, 50, 66), LayoutOrder = invOrder }, { corner(8) })
	local name = label({
		Size = UDim2.new(0.45, -10, 1, -12),
		Position = UDim2.fromOffset(10, 6),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = title,
		Parent = row,
	})
	make("UITextSizeConstraint", { MaxTextSize = 18 }).Parent = name
	local info = label({
		Size = UDim2.new(0.55, buttonText and -100 or -10, 1, -12),
		Position = UDim2.new(0.45, 0, 0, 6),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(190, 200, 215),
		Text = detail,
		Parent = row,
	})
	make("UITextSizeConstraint", { MaxTextSize = 15 }).Parent = info
	if buttonText then
		local b = make("TextButton", {
			Size = UDim2.fromOffset(84, 32),
			Position = UDim2.new(1, -92, 0.5, -16),
			BackgroundColor3 = Color3.fromRGB(58, 84, 112),
			Font = FONT,
			TextScaled = true,
			TextColor3 = Color3.new(1, 1, 1),
			Text = buttonText,
		}, { corner(8), make("UITextSizeConstraint", { MaxTextSize = 16 }) })
		b.Activated:Connect(onClick)
		b.Parent = row
	end
	row.Parent = invList
end

local function findTool(name: string): Tool?
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	return (backpack and backpack:FindFirstChild(name)) or (character and character:FindFirstChild(name))
end

local function rebuildInventory()
	if not state or not inventory.Visible then
		return
	end
	for _, child in invList:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	invOrder = 0

	invHeader("Fighter")
	invRow("Level " .. state.Level, state.XPToNext and string.format("%d / %d XP to next level", state.XP, state.XPToNext) or "Max level!")
	invRow("Strength " .. state.Strength, "Damage with weapons and spells (100 = normal)")
	invRow("Kills", tostring(state.Kills))

	invHeader("Weapons")
	for _, weapon in Config.Weapons do
		if weapon.Currency == "Free" or table.find(state.Weapons, weapon.Key) then
			local tool = findTool(weapon.Name)
			local equipped = tool ~= nil and player.Character ~= nil and tool.Parent == player.Character
			invRow(weapon.Name, string.format("%d dmg • %s", weapon.Damage, weapon.Kind), equipped and "Put away" or "Equip", function()
				local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				local current = findTool(weapon.Name)
				if not humanoid or not current then
					return
				end
				if current.Parent == player.Character then
					humanoid:UnequipTools()
				else
					humanoid:EquipTool(current)
				end
				task.wait(0.1)
				rebuildInventory()
			end)
		end
	end

	invHeader("Spells")
	local anySpell = false
	for _, spell in Config.Spells do
		local level = state.Spells[spell.Key] or 0
		if level > 0 then
			anySpell = true
			invRow(string.format("[%s] %s", spell.Hotkey, spell.Name), string.format("Level %d • %d power • %s", level, spell.PowerCost, spell.Type))
		end
	end
	if not anySpell then
		invRow("No spells yet", "Unlock them at the Spell Shrine in town")
	end

	invHeader("Items")
	invRow("Coins", Util.formatNumber(state.Coins))
	invRow("Food", string.format("%d / %d", state.Food, state.FoodCap))
	invRow("Eggs", string.format("%d / %d", state.Eggs, state.EggSlots))
	invRow("Riders", string.format("%d / %d", state.Riders, state.RiderSlots))

	invHeader("Upgrades")
	for _, upgrade in Config.Upgrades do
		invRow(upgrade.Name, string.format("Level %d / %d", state.Upgrades[upgrade.Key] or 0, upgrade.MaxLevel))
	end
end

local function toggleInventory()
	inventory.Visible = not inventory.Visible
	rebuildInventory()
end

local invButton = make("TextButton", {
	Size = UDim2.fromOffset(120, 40),
	Position = UDim2.new(0, 140, 0, 236),
	BackgroundColor3 = Color3.fromRGB(104, 78, 52),
	Font = FONT,
	TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "Items (I)",
}, { corner(12), make("UITextSizeConstraint", { MaxTextSize = 20 }) })
invButton.Activated:Connect(toggleInventory)
invButton.Parent = gui

UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.I then
		toggleInventory()
	end
end)

-- Quest tracker -------------------------------------------------------------------------

local questPanel = make("Frame", {
	Size = UDim2.fromOffset(250, 186),
	Position = UDim2.fromOffset(12, 286),
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.15,
}, { corner(12) })
questPanel.Parent = gui
local questTitle = label({
	Size = UDim2.new(1, -16, 0, 22),
	Position = UDim2.fromOffset(8, 4),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = GOLD,
	Text = "Quests",
	Parent = questPanel,
})
make("UITextSizeConstraint", { MaxTextSize = 18 }).Parent = questTitle

local questRows = {}
for i = 1, 3 do
	local row = make("Frame", { Size = UDim2.new(1, -16, 0, 48), Position = UDim2.fromOffset(8, 28 + (i - 1) * 52), BackgroundTransparency = 1 })
	local text = label({ Size = UDim2.new(1, -70, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, Text = "", Parent = row })
	make("UITextSizeConstraint", { MaxTextSize = 15 }).Parent = text
	local reward = label({
		Size = UDim2.new(1, -70, 0, 14),
		Position = UDim2.fromOffset(0, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(190, 200, 215),
		Text = "",
		Parent = row,
	})
	make("UITextSizeConstraint", { MaxTextSize = 12 }).Parent = reward
	local back = make(
		"Frame",
		{ Size = UDim2.new(1, -70, 0, 8), Position = UDim2.fromOffset(0, 37), BackgroundColor3 = Color3.fromRGB(45, 48, 60) },
		{ corner(4) }
	)
	local fill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(120, 210, 110) }, { corner(4) })
	fill.Parent = back
	back.Parent = row
	local claim = make("TextButton", {
		Size = UDim2.fromOffset(62, 32),
		Position = UDim2.new(1, -62, 0, 8),
		BackgroundColor3 = Color3.fromRGB(66, 104, 66),
		Font = FONT,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "Claim",
		Visible = false,
	}, { corner(8), make("UITextSizeConstraint", { MaxTextSize = 16 }) })
	claim.Activated:Connect(function()
		Remotes.Action:FireServer("ClaimQuest", i)
	end)
	claim.Parent = row
	row.Parent = questPanel
	questRows[i] = { Text = text, Reward = reward, Fill = fill, Claim = claim }
end

local function refreshQuests()
	local quests = state and state.Quests
	if not quests then
		return
	end
	questTitle.Text = string.format("Quests • new in %s", Util.formatTime(quests.RefreshIn))
	for i, row in questRows do
		local quest = quests.List[i]
		if quest then
			row.Text.Text = (quest.Claimed and "Done: " or "") .. quest.Text
			row.Text.TextColor3 = quest.Claimed and Color3.fromRGB(140, 150, 160) or Color3.new(1, 1, 1)
			row.Reward.Text = string.format("%d/%d • %sg, %d XP", quest.Progress, quest.Goal, Util.formatNumber(quest.Coins), quest.XP)
			row.Fill.Size = UDim2.fromScale(math.clamp(quest.Progress / quest.Goal, 0, 1), 1)
			row.Claim.Visible = not quest.Claimed and quest.Progress >= quest.Goal
		end
	end
end

-- Reading the quest board in town makes the tracker pulse.
local function pulseQuests()
	local stroke = make("UIStroke", { Color = GOLD, Thickness = 3 })
	stroke.Parent = questPanel
	TweenService:Create(stroke, TweenInfo.new(1.5), { Transparency = 1 }):Play()
	task.delay(1.6, function()
		stroke:Destroy()
	end)
end

-- Death screen ----------------------------------------------------------------------

local deathGui = make("ScreenGui", { Name = "DeathScreen", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 20, Enabled = false })
local deathBack = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(40, 0, 0), BackgroundTransparency = 1 })
make("UIGradient", {
	Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.6), NumberSequenceKeypoint.new(1, 0) }),
	Rotation = 90,
}).Parent =
	deathBack
deathBack.Parent = deathGui
local deathTitle = label({
	Size = UDim2.new(0.8, 0, 0, 110),
	Position = UDim2.new(0.1, 0, 0.32, 0),
	Font = Enum.Font.Merriweather,
	TextColor3 = Color3.fromRGB(220, 30, 30),
	TextStrokeTransparency = 0,
	Text = "YOU WERE SLAIN",
	Parent = deathGui,
})
local deathBy = label({
	Size = UDim2.new(0.6, 0, 0, 40),
	Position = UDim2.new(0.2, 0, 0.32, 118),
	TextColor3 = Color3.fromRGB(230, 200, 200),
	Text = "",
	Parent = deathGui,
})
local deathCount = label({
	Size = UDim2.new(0.6, 0, 0, 30),
	Position = UDim2.new(0.2, 0, 0.32, 166),
	TextColor3 = Color3.fromRGB(180, 160, 160),
	Text = "",
	Parent = deathGui,
})
deathGui.Parent = player:WaitForChild("PlayerGui")

local deathToken = 0
local function showDeath(info)
	deathToken += 1
	local token = deathToken
	deathGui.Enabled = true
	inventory.Visible = false
	deathBack.BackgroundTransparency = 1
	deathTitle.TextTransparency = 1
	TweenService:Create(deathBack, TweenInfo.new(1.2), { BackgroundTransparency = 0.15 }):Play()
	TweenService:Create(deathTitle, TweenInfo.new(0.8), { TextTransparency = 0 }):Play()
	deathBy.Text = info.By and ("by " .. info.By) or ""
	local respawnAt = os.clock() + (info.Respawn or Config.Combat.RespawnTime)
	task.spawn(function()
		while token == deathToken and deathGui.Enabled do
			local left = math.max(0, math.ceil(respawnAt - os.clock()))
			deathCount.Text = left > 0 and string.format("Rising again on your titan in %d…", left) or "Rising again…"
			task.wait(0.2)
		end
	end)
end

player.CharacterAdded:Connect(function()
	deathToken += 1
	deathGui.Enabled = false
end)

-- Updates from the server -------------------------------------------------------------

Remotes.State.OnClientEvent:Connect(function(newState)
	state = newState
	levelBadge.Text = "Lv " .. (state.Level or 1)
	strengthLabel.Text = "STR\n" .. (state.Strength or 100)
	if state.XPToNext then
		setBar(xpFill, xpText, state.XP, state.XPToNext, " XP")
	else
		xpFill.Size = UDim2.fromScale(1, 1)
		xpText.Text = "MAX LEVEL"
	end
	rebuildInventory()
	refreshQuests()
end)

Remotes.Ui.OnClientEvent:Connect(function(message)
	if type(message) ~= "table" then
		return
	end
	if message.Died then
		showDeath(message.Died)
	elseif message.LevelUp then
		levelUpFlash(message.LevelUp)
	elseif message.XPGain then
		xpPopup(message.XPGain)
	elseif message.Open == "Quests" then
		pulseQuests()
	end
end)

gui.Parent = player:WaitForChild("PlayerGui")
