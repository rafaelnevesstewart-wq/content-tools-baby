-- Fight feedback on your screen:
--   * Damage numbers pop out of whoever you hit (players and training
--     dummies), bigger and redder for heavy hits.
--   * The kill feed on the right side of the screen: knockouts (💀 for final ones)
--     and broken beds, in team colors.
-- Both can be turned off in ⚙️ Settings.

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local MatchData = require(Shared.MatchData)
local Remotes = require(Shared.Remotes)

local Settings = require(script.Parent.Settings)
local Stats = require(script.Parent.Stats)
local UI = require(script.Parent.UI)

local DamageFeed = {}

local FEED_SIZE = 5
local FEED_SECONDS = 7

local feed: Frame
local order = 0

local function teamColor(key: any): Color3
	for _, team in MatchData.Teams do
		if team.key == key then
			return team.color
		end
	end
	return UI.Colors.Text
end

local function showDamage(position: Vector3, amount: number)
	local anchor = Instance.new("Part")
	anchor.Name = "DamageNumber"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(position + Vector3.new(math.random() * 2 - 1, 1.5, math.random() * 2 - 1))
	anchor.Parent = workspace

	local heavy = amount >= 30
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 50)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 150
	gui.Adornee = anchor
	gui.Parent = anchor
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamBlack
	text.TextScaled = true
	text.Text = "-" .. amount
	text.TextColor3 = if heavy then Color3.fromRGB(255, 80, 70) else Color3.fromRGB(255, 225, 90)
	text.TextStrokeTransparency = 0.2
	text.TextStrokeColor3 = Color3.fromRGB(40, 10, 10)
	text.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Scale = 0.4
	scale.Parent = text

	TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = if heavy then 1.3 else 1,
	}):Play()
	TweenService:Create(anchor, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = anchor.CFrame + Vector3.new(0, 3, 0),
	}):Play()
	task.delay(0.45, function()
		TweenService:Create(text, TweenInfo.new(0.45), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
	Debris:AddItem(anchor, 1)
end

-- Adds a line to the kill feed: pieces of text, each in its own color.
local function addLine(pieces: { { text: string, color: Color3 } })
	order += 1
	local line = UI.new("Frame", {
		LayoutOrder = -order, -- newest on top
		Size = UDim2.fromOffset(0, 28),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Color3.fromRGB(10, 12, 18),
		BackgroundTransparency = 0.35,
		Parent = feed,
	}, {
		UI.corner(8),
		UI.new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
		UI.list(5, Enum.FillDirection.Horizontal),
	})
	for index, piece in pieces do
		UI.label({
			LayoutOrder = index,
			Size = UDim2.fromOffset(0, 28),
			AutomaticSize = Enum.AutomaticSize.X,
			Text = piece.text,
			TextSize = 16,
			TextColor3 = piece.color,
			Parent = line,
		})
	end
	-- Only the newest few stay.
	local lines = {}
	for _, child in feed:GetChildren() do
		if child:IsA("Frame") then
			table.insert(lines, child)
		end
	end
	table.sort(lines, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for index = FEED_SIZE + 1, #lines do
		lines[index]:Destroy()
	end
	task.delay(FEED_SECONDS, function()
		if line.Parent then
			line:Destroy()
		end
	end)
end

local function onFeed(entry: any)
	if type(entry) ~= "table" or not Settings.get("killFeed") then
		return
	end
	local white = UI.Colors.Text
	if entry.bed then
		local bedTeam = MatchData.Teams[1]
		for _, team in MatchData.Teams do
			if team.key == entry.bed then
				bedTeam = team
			end
		end
		addLine({
			{ text = tostring(entry.killer), color = teamColor(entry.killerTeam) },
			{ text = "broke", color = white },
			{ text = bedTeam.emoji .. " " .. bedTeam.name .. "'s bed 🛏️", color = bedTeam.color },
		})
	elseif entry.victim then
		local tag = if entry.final then " 💀 FINAL" else ""
		if entry.killer then
			addLine({
				{ text = tostring(entry.killer), color = teamColor(entry.killerTeam) },
				{ text = Stats.WeaponEmoji[entry.weapon] or "⚔️", color = white },
				{ text = tostring(entry.victim) .. tag, color = teamColor(entry.victimTeam) },
			})
		else
			addLine({
				{ text = tostring(entry.victim) .. tag, color = teamColor(entry.victimTeam) },
				{ text = "fell into the void 🕳️", color = white },
			})
		end
	end
end

function DamageFeed.start()
	local screen = UI.screen("KillFeed", 3)
	feed = UI.new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0.3, 0), -- under Roblox's player list
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		Parent = screen,
	}, { UI.list(4, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Right) })

	Remotes.event("DamageShown").OnClientEvent:Connect(function(position, amount)
		if typeof(position) == "Vector3" and type(amount) == "number" and Settings.get("damageNumbers") then
			showDamage(position, amount)
		end
	end)
	Remotes.event("KillFeed").OnClientEvent:Connect(onFeed)
	Settings.Changed:Connect(function(key, value)
		if key == "killFeed" and not value then
			for _, child in feed:GetChildren() do
				if child:IsA("Frame") then
					child:Destroy()
				end
			end
		end
	end)
end

return DamageFeed
