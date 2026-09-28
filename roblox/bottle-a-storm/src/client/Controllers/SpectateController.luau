-- 🎥 After you're knocked out for good, the camera follows the players (and
-- bots) still fighting. ◀ ▶ switch who you watch; 🏠 goes back to the sky
-- box view. It switches by itself when the one you watch is knocked out.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local MatchData = require(Shared.MatchData)

local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local SpectateController = {}

type Target = { name: string, humanoid: Humanoid, teamKey: string? }

local bar: Frame
local nameLabel: TextLabel
local watching = false
local index = 1
local current: Humanoid? = nil

local function teamOf(key: string?): (string, Color3)
	for _, team in MatchData.Teams do
		if team.key == key then
			return team.emoji .. " " .. team.name, team.color
		end
	end
	return "", UI.Colors.Text
end

-- Everyone still in the match: players, then bots.
local function targets(): { Target }
	local list: { Target } = {}
	for _, other in Players:GetPlayers() do
		if other ~= player and other:GetAttribute("InMatch") and not other:GetAttribute("Spectating") then
			local character = other.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				table.insert(
					list,
					{ name = other.DisplayName, humanoid = humanoid, teamKey = other:GetAttribute("TeamKey") }
				)
			end
		end
	end
	local bots = workspace:FindFirstChild("Bots")
	if bots then
		for _, model in bots:GetChildren() do
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				table.insert(list, { name = model.Name, humanoid = humanoid, teamKey = model:GetAttribute("BotTeam") })
			end
		end
	end
	return list
end

local function ownView()
	local camera = workspace.CurrentCamera
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if camera and humanoid then
		camera.CameraSubject = humanoid
	end
	current = nil
end

local function show(step: number)
	local list = targets()
	if #list == 0 then
		nameLabel.Text = "Nobody left to watch"
		ownView()
		return
	end
	index = (index - 1 + step) % #list + 1
	local target = list[index]
	current = target.humanoid
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraSubject = target.humanoid
	end
	local teamName, color = teamOf(target.teamKey)
	nameLabel.Text = "👀 " .. target.name .. (if teamName ~= "" then "  ·  " .. teamName else "")
	nameLabel.TextColor3 = color
end

local function setWatching(on: boolean)
	watching = on
	bar.Visible = player:GetAttribute("Spectating") == true
	if on then
		show(0)
	else
		ownView()
		nameLabel.Text = "🏠 Sky box view"
		nameLabel.TextColor3 = UI.Colors.Text
	end
end

function SpectateController.start()
	local screen = UI.screen("Spectate", 4)
	bar = UI.new("Frame", {
		Name = "Window", -- frees the mouse so you can click the buttons
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -156),
		Size = UDim2.fromOffset(0, 46),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = screen,
	}, { UI.corner(12), UI.stroke(UI.Colors.Stroke, 2), UI.padding(5), UI.list(6, Enum.FillDirection.Horizontal) })
	local function button(order: number, text: string, width: number, onClick: () -> ())
		UI.button({
			LayoutOrder = order,
			Size = UDim2.fromOffset(width, 36),
			Text = text,
			TextSize = 18,
			Parent = bar,
		}).Activated
			:Connect(onClick)
	end
	button(1, "◀", 44, function()
		setWatching(true)
		show(-1)
	end)
	nameLabel = UI.label({
		LayoutOrder = 2,
		Size = UDim2.fromOffset(0, 36),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = 18,
		Parent = bar,
	})
	button(3, "▶", 44, function()
		setWatching(true)
		show(1)
	end)
	button(4, "🏠", 44, function()
		setWatching(not watching)
	end)

	player:GetAttributeChangedSignal("Spectating"):Connect(function()
		if player:GetAttribute("Spectating") then
			task.delay(2, function()
				if player:GetAttribute("Spectating") then
					setWatching(true)
				end
			end)
		else
			setWatching(false)
			bar.Visible = false
		end
	end)
	player.CharacterAdded:Connect(function()
		if not player:GetAttribute("Spectating") then
			watching = false
			current = nil
			bar.Visible = false
		end
	end)
	-- The one you watch got knocked out: on to the next.
	local last = 0
	RunService.Heartbeat:Connect(function()
		if not watching or os.clock() - last < 0.5 then
			return
		end
		last = os.clock()
		if not current or current.Health <= 0 or not current.Parent then
			task.delay(1.5, function()
				if watching and (not current or current.Health <= 0 or not current.Parent) then
					show(0)
				end
			end)
		end
	end)
end

return SpectateController
