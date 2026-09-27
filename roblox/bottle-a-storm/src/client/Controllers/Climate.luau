-- The Climate Shift window: your climate and bonus, what the next shift needs,
-- what it resets and keeps, and the (press twice to confirm) Shift button.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local ClimateData = require(Shared.ClimateData)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local Toasts = require(script.Parent.Toasts)
local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local Climate = {}

local window: Frame
local currentLabel: TextLabel
local nextLabel: TextLabel
local shiftButton: TextButton
local confirming = false

local function refresh()
	local level = player:GetAttribute("Climate") or 0
	local now = ClimateData.at(level)
	local nextClimate = ClimateData.List[level + 2]
	currentLabel.Text = "You're in the "
		.. now.emoji
		.. " "
		.. now.name
		.. "\nPermanent income bonus: x"
		.. now.multiplier
	if not nextClimate then
		nextLabel.Text = "🏆 You've reached the last climate. You're a true Storm Master!"
		shiftButton.Visible = false
		return
	end
	local sparks = player:GetAttribute("Sparks") or 0
	nextLabel.Text = "Next: "
		.. nextClimate.emoji
		.. " "
		.. nextClimate.name
		.. "\n• Needs ⚡"
		.. Format.number(nextClimate.cost)
		.. " (you have ⚡"
		.. Format.number(sparks)
		.. ")"
		.. "\n• Income bonus becomes x"
		.. nextClimate.multiplier
		.. " forever"
		.. "\n• Opens the "
		.. nextClimate.name
		.. " island with 4 new storms"
		.. "\n\n❌ Resets: Sparks, Boots of Wind, Lightning Rod"
		.. "\n✅ Keeps: storms, pedestals, jars, thief styles, passes"
	shiftButton.Visible = true
	local canShift = sparks >= nextClimate.cost
	if confirming and canShift then
		shiftButton.Text = "⚠️ Sure? Press again to SHIFT"
		shiftButton.BackgroundColor3 = UI.Colors.Warn
	else
		confirming = false
		shiftButton.Text = if canShift then "🌍 Climate Shift!" else "🔒 Need more Sparks"
		shiftButton.BackgroundColor3 = if canShift then UI.Colors.Good else UI.Colors.Disabled
	end
end

function Climate.toggle()
	window.Visible = not window.Visible
	confirming = false
	if window.Visible then
		refresh()
	end
end

function Climate.start()
	local screen = UI.screen("Climate", 6)
	window = UI.new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.8),
		BackgroundColor3 = UI.Colors.Panel,
		Visible = false,
		Parent = screen,
	}, {
		UI.corner(18),
		UI.stroke(Color3.fromRGB(110, 170, 255), 3),
		UI.padding(16),
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(480, 440) }),
	})
	UI.label({
		Size = UDim2.new(1, -60, 0, 36),
		Text = "🌍 Climate Shift",
		TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(80, 130, 220),
		Parent = window,
	})
	local close = UI.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(44, 36),
		Text = "✕",
		TextSize = 22,
		BackgroundColor3 = UI.Colors.Bad,
		Parent = window,
	})
	close.Activated:Connect(function()
		window.Visible = false
	end)

	currentLabel = UI.label({
		Position = UDim2.fromOffset(0, 46),
		Size = UDim2.new(1, 0, 0, 50),
		TextSize = 19,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Spark,
		Parent = window,
	})
	nextLabel = UI.label({
		Position = UDim2.fromOffset(0, 104),
		Size = UDim2.new(1, 0, 1, -170),
		TextSize = 17,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = window,
	})
	shiftButton = UI.button({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 52),
		TextSize = 24,
		Parent = window,
	})
	shiftButton.Activated:Connect(function()
		local level = player:GetAttribute("Climate") or 0
		local nextClimate = ClimateData.List[level + 2]
		if not nextClimate or (player:GetAttribute("Sparks") or 0) < nextClimate.cost then
			return
		end
		if not confirming then
			confirming = true
			refresh()
			return
		end
		confirming = false
		local ok, message = Remotes.func("ClimateShift"):InvokeServer()
		Toasts.show(message, if ok then "rare" else "warn")
		refresh()
	end)

	player.AttributeChanged:Connect(function(name)
		if window.Visible and (name == "Sparks" or name == "Climate") then
			refresh()
		end
	end)
end

return Climate
