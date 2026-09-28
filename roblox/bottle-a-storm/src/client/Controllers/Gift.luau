-- The 🎁 Gift window (GiftService): open it from 👥 Party next to someone's
-- name, then pick a cosmetic they don't own yet and pay for it with your
-- Sparks. It goes straight on them.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local UI = require(script.Parent.UI)

local Gift = {}

local window: Frame
local title: TextLabel
local status: TextLabel
local list: ScrollingFrame
local target: number? = nil

local function clear()
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function fill()
	clear()
	if not target then
		return
	end
	local ok, info = pcall(function()
		return Remotes.func("GetGifts"):InvokeServer(target)
	end)
	if not ok or type(info) ~= "table" then
		title.Text = "🎁 Gift"
		status.Text = "They're not here anymore."
		return
	end
	title.Text = "🎁 Gift to " .. info.name
	status.Text = "You have ⚡" .. Format.number(info.sparks) .. " Sparks"
	if #info.items == 0 then
		UI.label({
			Size = UDim2.new(1, -8, 0, 30),
			Text = info.name .. " already has everything you could gift!",
			TextSize = 15,
			TextColor3 = UI.Colors.Muted,
			Parent = list,
		})
	end
	for index, item in info.items do
		local row = UI.new("Frame", {
			LayoutOrder = index,
			Size = UDim2.new(1, -8, 0, 42),
			BackgroundColor3 = UI.Colors.PanelLight,
			Parent = list,
		}, { UI.corner(10), UI.padding(6) })
		UI.label({
			Size = UDim2.new(1, -130, 1, 0),
			Text = item.emoji .. " " .. item.name .. "  (" .. item.category .. ")",
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = row,
		})
		local affordable = info.sparks >= item.cost
		UI.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(118, 30),
			Text = "🎁 ⚡" .. Format.number(item.cost),
			TextSize = 14,
			BackgroundColor3 = if affordable then UI.Colors.Good else UI.Colors.Disabled,
			Parent = row,
		}).Activated
			:Connect(function()
				local sent, _, message = pcall(function()
					return Remotes.func("SendGift"):InvokeServer(target, item.id)
				end)
				fill()
				if sent and type(message) == "string" then
					status.Text = message
				end
			end)
	end
end

-- Opens the window to gift someone (the Party window calls this).
function Gift.open(userId: number)
	target = userId
	window.Visible = true
	fill()
end

function Gift.start()
	local screen = UI.screen("Gift", 8)
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
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(480, 560) }),
	})
	title = UI.label({
		Size = UDim2.new(1, -60, 0, 34),
		Text = "🎁 Gift",
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Spark,
		TextTruncate = Enum.TextTruncate.AtEnd,
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
			target = nil
		end)
	status = UI.label({
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 0, 22),
		Text = "",
		TextSize = 15,
		TextColor3 = UI.Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = window,
	})
	list = UI.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 68),
		Size = UDim2.new(1, 0, 1, -68),
		BackgroundColor3 = UI.Colors.PanelLight,
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = window,
	}, { UI.corner(10), UI.padding(6), UI.list(4) })
end

return Gift
