-- The 👥 Party window: your party (leave, or remove someone if you lead it)
-- and everyone else in the server with an Invite button. Invites pop up at
-- the bottom with Join / No thanks. Party members always play on the same
-- team (PartyService).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local Party = {}

type Member = { userId: number, name: string, leader: boolean }

local window: Frame
local list: ScrollingFrame
local screen: ScreenGui

local function members(): { Member }
	local raw = player:GetAttribute("Party")
	if type(raw) ~= "string" then
		return {}
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
	return if ok and type(decoded) == "table" then decoded else {}
end

local function send(action: string, userId: number?)
	Remotes.event("PartyAction"):FireServer(action, userId)
end

local function row(order: number, text: string, buttonText: string?, color: Color3?, onClick: (() -> ())?)
	local frame = UI.new("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, 44),
		BackgroundColor3 = UI.Colors.PanelLight,
		Parent = list,
	}, { UI.corner(10), UI.padding(6) })
	UI.label({
		Size = UDim2.new(1, -130, 1, 0),
		Text = text,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = frame,
	})
	if buttonText and onClick then
		UI.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(118, 32),
			Text = buttonText,
			TextSize = 15,
			BackgroundColor3 = color or UI.Colors.Good,
			Parent = frame,
		}).Activated
			:Connect(onClick)
	end
end

local function build()
	for _, child in list:GetChildren() do
		if child:IsA("Frame") or child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	local party = members()
	local inParty: { [number]: boolean } = {}
	local iLead = false
	for _, member in party do
		inParty[member.userId] = true
		if member.userId == player.UserId and member.leader then
			iLead = true
		end
	end
	local order = 0
	local function heading(text: string)
		order += 1
		UI.label({
			LayoutOrder = order,
			Size = UDim2.new(1, -8, 0, 24),
			Text = text,
			TextSize = 16,
			TextColor3 = UI.Colors.Muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = list,
		})
	end
	if #party > 0 then
		heading("Your party (" .. #party .. "/" .. Config.Party.MaxSize .. ")")
		for _, member in party do
			order += 1
			local label = (if member.leader then "👑 " else "👤 ") .. member.name
			if member.userId == player.UserId then
				row(order, label .. " (you)", "Leave", UI.Colors.Bad, function()
					send("leave")
				end)
			elseif iLead then
				row(order, label, "Remove", UI.Colors.Bad, function()
					send("kick", member.userId)
				end)
			else
				row(order, label)
			end
		end
	else
		heading("You're not in a party. Invite someone to team up!")
	end
	heading("Players in this server")
	local others = 0
	for _, other in Players:GetPlayers() do
		if other ~= player and not inParty[other.UserId] then
			others += 1
			order += 1
			row(order, other.DisplayName, "Invite", UI.Colors.Good, function()
				send("invite", other.UserId)
			end)
		end
	end
	if others == 0 then
		heading("Nobody else is here yet.")
	end
end

function Party.toggle()
	window.Visible = not window.Visible
	if window.Visible then
		build()
	end
end

-- An invite pops up at the bottom of the screen.
local function showInvite(fromUserId: number, fromName: string)
	local card = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -160),
		Size = UDim2.fromOffset(360, 96),
		BackgroundColor3 = UI.Colors.Panel,
		Parent = screen,
	}, { UI.corner(14), UI.stroke(UI.Colors.Good, 3), UI.padding(10) })
	UI.label({
		Size = UDim2.new(1, 0, 0, 30),
		Text = "👥 " .. fromName .. " invited you to their party!",
		TextSize = 17,
		TextWrapped = true,
		Parent = card,
	})
	local function answer(action: string)
		send(action, fromUserId)
		card:Destroy()
	end
	UI.button({
		Position = UDim2.new(0, 0, 1, -38),
		Size = UDim2.new(0.5, -4, 0, 38),
		Text = "Join",
		BackgroundColor3 = UI.Colors.Good,
		Parent = card,
	}).Activated
		:Connect(function()
			answer("accept")
		end)
	UI.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 1, -38),
		Size = UDim2.new(0.5, -4, 0, 38),
		Text = "No thanks",
		BackgroundColor3 = UI.Colors.Bad,
		Parent = card,
	}).Activated
		:Connect(function()
			answer("decline")
		end)
	task.delay(Config.Party.InviteSeconds, function()
		if card.Parent then
			card:Destroy()
		end
	end)
end

function Party.start()
	screen = UI.screen("Party", 7)
	window = UI.new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.9, 0, 0.75, 0),
		BackgroundColor3 = UI.Colors.Panel,
		Visible = false,
		Parent = screen,
	}, {
		UI.corner(18),
		UI.stroke(UI.Colors.Stroke, 3),
		UI.padding(14),
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(460, 480) }),
	})
	UI.label({
		Size = UDim2.new(1, -60, 0, 34),
		Text = "👥 Party",
		TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Spark,
		Parent = window,
	})
	UI.label({
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, 0, 0, 20),
		Text = "Party members always play on the same team.",
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

	Remotes.event("PartyInvite").OnClientEvent:Connect(function(fromUserId, fromName)
		if type(fromUserId) == "number" and type(fromName) == "string" then
			showInvite(fromUserId, fromName)
		end
	end)
	local function refresh()
		if window.Visible then
			build()
		end
	end
	player:GetAttributeChangedSignal("Party"):Connect(refresh)
	Players.PlayerAdded:Connect(refresh)
	Players.PlayerRemoving:Connect(function()
		task.defer(refresh)
	end)
end

return Party
