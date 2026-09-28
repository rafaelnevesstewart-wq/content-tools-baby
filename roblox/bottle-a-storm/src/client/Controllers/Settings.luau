-- The ⚙️ Settings window, and every other controller's way to read a
-- setting: Settings.get("damageNumbers"). Choices are saved on the server
-- (SettingsService) and come back as the "Settings" attribute; a change
-- shows right away and Settings.Changed fires (key, value).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Lang = require(Shared.Lang)
local Remotes = require(Shared.Remotes)
local SettingsData = require(Shared.SettingsData)
local Signal = require(Shared.Signal)

local Sfx = require(script.Parent.Sfx)
local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local Settings = {}

Settings.Changed = Signal.new()

local chosen: { [string]: any } = {}
local window: Frame
local list: ScrollingFrame

local function load()
	local raw = player:GetAttribute("Settings")
	if type(raw) ~= "string" then
		return
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
	if ok and type(decoded) == "table" then
		local before = chosen
		chosen = decoded
		for _, setting in SettingsData.List do
			local old = before[setting.key]
			local new = decoded[setting.key]
			if old ~= new then
				Settings.Changed:Fire(setting.key, Settings.get(setting.key))
			end
		end
	end
end

function Settings.get(key: string): any
	local value = chosen[key]
	if value ~= nil then
		return value
	end
	local setting = SettingsData.find(key)
	return if setting then setting.default else nil
end

local function set(key: string, value: any)
	chosen[key] = value
	Settings.Changed:Fire(key, value)
	Remotes.event("SaveSetting"):FireServer(key, value)
end

local function shown(setting: SettingsData.Setting): boolean
	local touch = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
	if setting.mouseOnly and touch then
		return false
	end
	if setting.touchOnly and not UserInputService.TouchEnabled then
		return false
	end
	return true
end

local function valueText(setting: SettingsData.Setting, value: any): string
	if setting.kind == "toggle" then
		return if value then Lang.t("settings.on") else Lang.t("settings.off")
	end
	if setting.labels then
		return setting.labels[value :: number] or tostring(value)
	end
	return math.floor((value :: number) * 100 + 0.5) .. "%"
end

local function build()
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for order, setting in SettingsData.List do
		if shown(setting) then
			local card = UI.new("Frame", {
				LayoutOrder = order,
				Size = UDim2.new(1, -8, 0, 62),
				BackgroundColor3 = UI.Colors.PanelLight,
				Parent = list,
			}, { UI.corner(10), UI.padding(8) })
			UI.label({
				Size = UDim2.new(1, -110, 0, 24),
				Text = Lang.t("setting." .. setting.key .. ".name", setting.name),
				TextSize = 17,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Parent = card,
			})
			UI.label({
				Position = UDim2.fromOffset(0, 24),
				Size = UDim2.new(1, -110, 0, 22),
				Text = Lang.t("setting." .. setting.key .. ".hint", setting.hint),
				TextSize = 13,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = UI.Colors.Muted,
				Parent = card,
			})
			local value = Settings.get(setting.key)
			local on = setting.kind ~= "toggle" or value == true
			local button = UI.button({
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.fromOffset(96, 38),
				Text = valueText(setting, value),
				TextSize = 17,
				BackgroundColor3 = if on then UI.Colors.Good else UI.Colors.Disabled,
				Parent = card,
			})
			button.Activated:Connect(function()
				local current = Settings.get(setting.key)
				local nextValue: any
				if setting.kind == "toggle" then
					nextValue = not current
				else
					local levels = setting.levels or { 1 }
					local index = table.find(levels, current) or #levels
					nextValue = levels[index % #levels + 1]
				end
				set(setting.key, nextValue)
				build()
			end)
		end
	end
end

function Settings.toggle()
	window.Visible = not window.Visible
	if window.Visible then
		build()
	end
end

function Settings.start()
	load()
	player:GetAttributeChangedSignal("Settings"):Connect(load)
	Sfx.volume = Settings.get("sfx")
	Settings.Changed:Connect(function(key, value)
		if key == "sfx" then
			Sfx.volume = value
		end
	end)

	local screen = UI.screen("Settings", 7)
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
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(520, 560) }),
	})
	UI.label({
		Size = UDim2.new(1, -60, 0, 34),
		Text = Lang.t("settings.title"),
		TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Spark,
		Parent = window,
	})
	UI.label({
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, 0, 0, 20),
		Text = "Saved with your profile, so they follow you to every server.",
		TextSize = 14,
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
		Position = UDim2.fromOffset(0, 62),
		Size = UDim2.new(1, 0, 1, -62),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = window,
	}, { UI.list(6) })
end

return Settings
