-- The 🌪️ Kits window (Bed Wars): every storm you own is a kit. Pick the one
-- you bring to matches; it floats beside you and gives its power on Shift.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local Toasts = require(script.Parent.Toasts)
local UI = require(script.Parent.UI)

local Kits = {}

local window: Frame
local list: ScrollingFrame
local busy = false

local function clear()
	for _, child in list:GetChildren() do
		if child:IsA("Frame") or child:IsA("TextLabel") then
			child:Destroy()
		end
	end
end

local function build()
	clear()
	local kits = Remotes.func("GetKits"):InvokeServer()
	if type(kits) ~= "table" then
		return
	end
	if #kits == 0 then
		UI.label({
			Size = UDim2.new(1, 0, 0, 60),
			Text = "No storms yet! Open a Mystery Jar in the 🏪 Market to get one.",
			TextWrapped = true,
			TextColor3 = UI.Colors.Muted,
			Parent = list,
		})
		return
	end
	for index, kit in kits do
		local card = UI.new("Frame", {
			LayoutOrder = index,
			Size = UDim2.new(1, -8, 0, 74),
			BackgroundColor3 = UI.Colors.PanelLight,
			Parent = list,
		}, { UI.corner(12), UI.padding(8), UI.stroke(if kit.chosen then UI.Colors.Good else kit.color, 2) })
		UI.label({
			Size = UDim2.new(1, -120, 0, 24),
			Text = kit.name,
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = UI.ink(kit.color),
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = card,
		})
		UI.label({
			Position = UDim2.fromOffset(0, 26),
			Size = UDim2.new(1, -120, 0, 32),
			Text = kit.rarity
				.. " · Shift: "
				.. kit.power
				.. " ("
				.. kit.powerText
				.. ", every "
				.. kit.cooldown
				.. "s)",
			TextSize = 13,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = UI.Colors.Muted,
			Parent = card,
		})
		local button = UI.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(108, 42),
			Text = if kit.chosen then "✓ Chosen" else "Choose",
			TextSize = 17,
			BackgroundColor3 = if kit.chosen then UI.Colors.Disabled else UI.Colors.Good,
			AutoButtonColor = not kit.chosen,
			Parent = card,
		})
		if not kit.chosen then
			button.Activated:Connect(function()
				if busy then
					return
				end
				busy = true
				local ok, message = Remotes.func("ChooseKit"):InvokeServer(kit.uid)
				busy = false
				Toasts.show(message, if ok then "success" else "warn")
				build()
			end)
		end
	end
end

function Kits.toggle()
	window.Visible = not window.Visible
	if window.Visible then
		build()
	end
end

function Kits.start()
	local screen = UI.screen("Kits", 5)
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
		UI.padding(14),
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(520, 500) }),
	})
	UI.label({
		Size = UDim2.new(1, -60, 0, 36),
		Text = "🌪️ Storm Kits",
		TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Spark,
		Parent = window,
	})
	UI.label({
		Position = UDim2.fromOffset(0, 38),
		Size = UDim2.new(1, 0, 0, 36),
		Text = "Your kit floats beside you in matches and gives you its power on Shift. Rarer storms look cooler!",
		TextSize = 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Muted,
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
	list = UI.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 80),
		Size = UDim2.new(1, 0, 1, -80),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = window,
	}, { UI.list(8) })
end

return Kits
