-- The 🎟️ private match rules (CustomMatchService): a button in the chips on
-- the right for the private server's owner (and a "custom rules" note for
-- everyone when something is changed). The window lists every option; the
-- owner taps one to go to its next choice.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local CustomData = require(Shared.CustomData)
local Remotes = require(Shared.Remotes)

local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local CustomMatch = {}

local window: Frame
local list: ScrollingFrame
local status: TextLabel

local function fill()
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local ok, info = pcall(function()
		return Remotes.func("CustomRules"):InvokeServer("get")
	end)
	if not ok or type(info) ~= "table" then
		return
	end
	status.Text = if info.canEdit
		then "You own this server: tap an option to change it. It applies from the next match."
		else "The server's owner picked these rules."
	for index, option in CustomData.Options do
		local row = UI.new("Frame", {
			LayoutOrder = index,
			Size = UDim2.new(1, -8, 0, 44),
			BackgroundColor3 = UI.Colors.PanelLight,
			Parent = list,
		}, { UI.corner(10), UI.padding(6) })
		UI.label({
			Size = UDim2.new(0.45, 0, 1, 0),
			Text = option.name,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		local current = info.rules[option.key] or option.choices[1]
		local button = UI.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.new(0.55, 0, 0, 32),
			Text = option.labels[current] or current,
			TextSize = 14,
			TextTruncate = Enum.TextTruncate.AtEnd,
			BackgroundColor3 = if current ~= option.choices[1] then UI.Colors.Rare else UI.Colors.Stroke,
			AutoButtonColor = info.canEdit,
			Parent = row,
		})
		if info.canEdit then
			button.Activated:Connect(function()
				local at = table.find(option.choices, current) or 1
				local nextChoice = option.choices[at % #option.choices + 1]
				pcall(function()
					Remotes.func("CustomRules"):InvokeServer("set", option.key, nextChoice)
				end)
				fill()
			end)
		end
	end
end

function CustomMatch.start()
	local screen = UI.screen("CustomMatch", 8)
	local chip = UI.button({
		LayoutOrder = 0,
		Size = UDim2.fromOffset(0, 28),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Color3.fromRGB(60, 120, 170),
		TextSize = 14,
		Visible = false,
		Parent = UI.sideStack(),
	})
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = chip })

	window = UI.new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.9, 0, 0.8, 0),
		BackgroundColor3 = UI.Colors.Panel,
		Visible = false,
		Parent = screen,
	}, {
		UI.corner(18),
		UI.stroke(UI.Colors.Stroke, 3),
		UI.padding(12),
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(500, 520) }),
	})
	UI.label({
		Size = UDim2.new(1, -60, 0, 34),
		Text = "🎟️ Private Match Rules",
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Spark,
		Parent = window,
	})
	UI.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(44, 40),
		Text = "✕",
		TextSize = 22,
		BackgroundColor3 = UI.Colors.Bad,
		Parent = window,
	}).Activated
		:Connect(function()
			window.Visible = false
		end)
	status = UI.label({
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 0, 36),
		Text = "",
		TextSize = 14,
		TextWrapped = true,
		TextColor3 = UI.Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = window,
	})
	list = UI.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 82),
		Size = UDim2.new(1, 0, 1, -82),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = window,
	}, { UI.list(4) })

	chip.Activated:Connect(function()
		window.Visible = not window.Visible
		if window.Visible then
			fill()
		end
	end)
	local function refresh()
		local owner = player:GetAttribute("CanCustomize") == true
		local changed = CustomData.changed()
		chip.Visible = (owner or changed) and not player:GetAttribute("InMatch")
		chip.Text = if owner then "🎟️ Private match rules" else "🎟️ Custom rules are on"
		if window.Visible then
			fill()
		end
	end
	player:GetAttributeChangedSignal("CanCustomize"):Connect(refresh)
	player:GetAttributeChangedSignal("InMatch"):Connect(refresh)
	workspace:GetAttributeChangedSignal("CustomRules"):Connect(refresh)
	refresh()
end

return CustomMatch
