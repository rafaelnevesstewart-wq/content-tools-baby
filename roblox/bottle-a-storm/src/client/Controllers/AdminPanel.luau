-- The 👑 Admin panel (only shown to admins; the server checks every command).
-- Start Admin Abuse, luck, a storm rain, a Mega-Storm, a Golden Hunt, a
-- Storm Race, any weather, or give everyone Sparks. In Bed Wars: start or
-- end a match.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local WeatherEvents = require(Shared.WeatherEvents)

local Toasts = require(script.Parent.Toasts)
local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local AdminPanel = {}

local window: Frame

local function run(command: string, arg: any?)
	local ok, message = Remotes.func("AdminCommand"):InvokeServer(command, arg)
	Toasts.show(message, if ok then "success" else "warn")
end

function AdminPanel.toggle()
	window.Visible = not window.Visible
end

function AdminPanel.isAdmin(): boolean
	return player:GetAttribute("IsAdmin") == true
end

function AdminPanel.start()
	local screen = UI.screen("AdminPanel", 8)
	window = UI.new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(460, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = UI.Colors.Panel,
		Visible = false,
		Parent = screen,
	}, { UI.corner(18), UI.stroke(UI.Colors.Spark, 3), UI.padding(14), UI.list(8) })
	UI.label({
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 30),
		Text = "👑 Admin Panel",
		TextSize = 24,
		Parent = window,
	})

	local grid = UI.new("Frame", {
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = window,
	}, {
		UI.new("UIGridLayout", {
			CellSize = UDim2.new(0.5, -4, 0, 42),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local actions = if Config.GameMode == "BedWars"
		then {
			{ "👑 ADMIN ABUSE", "abuse", UI.Colors.Spark },
			{ "⚔️ Start match now", "startmatch", UI.Colors.Good },
			{ "🏁 End match", "endmatch", UI.Colors.Bad },
		}
		else {
			{ "👑 ADMIN ABUSE", "abuse", UI.Colors.Spark },
			{ "🍀 10x Luck", "luck", UI.Colors.Good },
			{ "🌧️ Storm Rain", "rain", UI.Colors.Stroke },
			{ "🌪️ Mega-Storm now", "boss", UI.Colors.Bad },
			{ "✨ Golden Hunt", "golden", UI.Colors.Warn },
			{ "🏁 Storm Race", "race", UI.Colors.Rare },
		}
	for order, action in actions do
		UI.button({
			LayoutOrder = order,
			Text = action[1],
			TextSize = 17,
			BackgroundColor3 = action[3],
			Parent = grid,
		}).Activated
			:Connect(function()
				run(action[2])
			end)
	end
	for order, event in WeatherEvents.List do
		UI.button({
			LayoutOrder = 100 + order,
			Text = event.emoji .. " " .. event.name,
			TextSize = 15,
			Parent = grid,
		}).Activated
			:Connect(function()
				run("weather", event.key)
			end)
	end
	for order, amount in { 1000, 100000 } do
		UI.button({
			LayoutOrder = 200 + order,
			Text = "💸 Everyone +⚡" .. (if amount >= 1000 then amount // 1000 .. "K" else tostring(amount)),
			TextSize = 15,
			BackgroundColor3 = UI.Colors.Robux,
			Parent = grid,
		}).Activated
			:Connect(function()
				run("sparks", amount)
			end)
	end
	UI.button({
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 38),
		Text = "Close",
		BackgroundColor3 = UI.Colors.PanelLight,
		Parent = window,
	}).Activated
		:Connect(function()
			window.Visible = false
		end)
end

return AdminPanel
