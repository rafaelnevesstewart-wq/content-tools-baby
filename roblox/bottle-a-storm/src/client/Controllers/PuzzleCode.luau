-- The 🔐 Code Door keypad (PuzzleService): four number wheels (tap ▲ or ▼)
-- and Open. Opened from the Code Door's prompt in the puzzle rooms.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local UI = require(script.Parent.UI)

local PuzzleCode = {}

local window: Frame
local status: TextLabel
local digits = { 0, 0, 0, 0 }

function PuzzleCode.toggle()
	window.Visible = not window.Visible
	status.Text = "Find the number for each symbol on the paintings."
end

function PuzzleCode.start()
	local screen = UI.screen("PuzzleCode", 8)
	window = UI.new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(340, 300),
		BackgroundColor3 = UI.Colors.Panel,
		Visible = false,
		Parent = screen,
	}, { UI.corner(18), UI.stroke(UI.Colors.Stroke, 3), UI.padding(12) })
	UI.label({
		Size = UDim2.new(1, -50, 0, 32),
		Text = "🔐 Code Door",
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Spark,
		Parent = window,
	})
	UI.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(40, 36),
		Text = "✕",
		TextSize = 20,
		BackgroundColor3 = UI.Colors.Bad,
		Parent = window,
	}).Activated
		:Connect(function()
			window.Visible = false
		end)
	for index = 1, 4 do
		local x = (index - 1) * 76 + 10
		local number = UI.label({
			Position = UDim2.fromOffset(x, 92),
			Size = UDim2.fromOffset(60, 60),
			BackgroundColor3 = UI.Colors.Track,
			BackgroundTransparency = 0,
			Text = "0",
			TextSize = 36,
			Parent = window,
		})
		UI.corner(10).Parent = number
		local function change(by: number)
			digits[index] = (digits[index] + by) % 10
			number.Text = tostring(digits[index])
		end
		UI.button({
			Position = UDim2.fromOffset(x, 50),
			Size = UDim2.fromOffset(60, 36),
			Text = "▲",
			TextSize = 20,
			Parent = window,
		}).Activated
			:Connect(function()
				change(1)
			end)
		UI.button({
			Position = UDim2.fromOffset(x, 158),
			Size = UDim2.fromOffset(60, 36),
			Text = "▼",
			TextSize = 20,
			Parent = window,
		}).Activated
			:Connect(function()
				change(-1)
			end)
	end
	status = UI.label({
		Position = UDim2.fromOffset(0, 200),
		Size = UDim2.new(1, 0, 0, 36),
		Text = "",
		TextSize = 14,
		TextWrapped = true,
		TextColor3 = UI.Colors.Muted,
		Parent = window,
	})
	UI.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(160, 40),
		Text = "🔓 Open",
		TextSize = 18,
		BackgroundColor3 = UI.Colors.Good,
		Parent = window,
	}).Activated
		:Connect(function()
			local guess = ""
			for _, digit in digits do
				guess ..= tostring(digit)
			end
			local ok, opened, message = pcall(function()
				return Remotes.func("PuzzleCode"):InvokeServer(guess)
			end)
			if ok and type(message) == "string" then
				status.Text = message
			end
			if ok and opened then
				window.Visible = false
			end
		end)
end

return PuzzleCode
