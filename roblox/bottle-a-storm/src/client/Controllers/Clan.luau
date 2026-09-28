-- The 🛡️ Clan window: make a clan (name + tag), or see yours (members,
-- wins, invite people in this server, leave, remove members if you lead),
-- plus the 🏆 Top Clans leaderboard. Clan invites pop up at the bottom.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local Clan = {}

local screen: ScreenGui
local window: Frame
local list: ScrollingFrame
local status: TextLabel
local reload: () -> ()

local function clear()
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function act(action: string, a: any?, b: any?)
	status.Text = "..."
	task.spawn(function()
		local ok, success, message = pcall(function()
			return Remotes.func("ClanAction"):InvokeServer(action, a, b)
		end)
		status.Text = if ok then tostring(message) else "Something went wrong."
		status.TextColor3 = if ok and success then UI.Colors.Good else UI.Colors.Bad
		reload()
	end)
end

local order = 0
local function nextOrder(): number
	order += 1
	return order
end

local function heading(text: string, color: Color3?)
	UI.label({
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, -8, 0, 26),
		Text = text,
		TextSize = 17,
		TextColor3 = color or UI.Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = list,
	})
end

local function row(text: string, buttonText: string?, color: Color3?, onClick: (() -> ())?)
	local frame = UI.new("Frame", {
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, -8, 0, 40),
		BackgroundColor3 = UI.Colors.PanelLight,
		Parent = list,
	}, { UI.corner(10), UI.padding(6) })
	UI.label({
		Size = UDim2.new(1, -120, 1, 0),
		Text = text,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = frame,
	})
	if buttonText and onClick then
		UI.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(110, 30),
			Text = buttonText,
			TextSize = 15,
			BackgroundColor3 = color or UI.Colors.Good,
			Parent = frame,
		}).Activated
			:Connect(onClick)
	end
end

local function textBox(placeholder: string, max: number): TextBox
	local box = UI.new("TextBox", {
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, -8, 0, 40),
		BackgroundColor3 = UI.Colors.Track,
		PlaceholderText = placeholder,
		PlaceholderColor3 = UI.Colors.Muted,
		Text = "",
		TextColor3 = UI.Colors.Text,
		Font = UI.Font,
		TextSize = 17,
		ClearTextOnFocus = false,
		Parent = list,
	}, { UI.corner(10), UI.padding(8) })
	box:GetPropertyChangedSignal("Text"):Connect(function()
		if #box.Text > max then
			box.Text = string.sub(box.Text, 1, max)
		end
	end)
	return box
end

local function show(state: any)
	clear()
	order = 0
	if type(state) ~= "table" then
		heading("Still loading. Try again in a moment!")
		return
	end
	local clan = state.clan
	if clan then
		heading("[" .. clan.tag .. "] " .. clan.name, clan.color)
		heading(
			"🏆 " .. Format.number(clan.wins) .. " wins  ·  👥 " .. #clan.members .. "/" .. clan.max .. " members"
		)
		-- 🎖️ The Clan Pass: the clan earns XP together, everyone claims.
		local pass = clan.pass
		if pass then
			heading(
				"🎖️ Clan Pass (" .. pass.season .. " season): " .. Format.number(pass.xp) .. " Clan XP",
				UI.Colors.Spark
			)
			heading("Every member's matches add Clan XP. Claim each tier's prize for yourself!")
			for _, tier in pass.tiers do
				local reached = pass.xp >= tier.xp
				local text = "Tier " .. tier.tier .. ": " .. tier.reward
				if tier.claimed then
					row(text .. "  ✅")
				elseif reached then
					row(text, "Claim!", UI.Colors.Good, function()
						act("claimPass", tier.tier)
					end)
				else
					row(text .. "  🔒 " .. Format.number(tier.xp) .. " XP")
				end
			end
		end
		heading("Members")
		for _, member in clan.members do
			local label = (if member.leader then "👑 " else "🛡️ ")
				.. member.name
				.. (if member.online then "  🟢" else "")
			if clan.leader and member.userId ~= player.UserId then
				row(label, "Remove", UI.Colors.Bad, function()
					act("kick", member.userId)
				end)
			else
				row(label)
			end
		end
		heading("Invite people in this server")
		local inClan: { [number]: boolean } = {}
		for _, member in clan.members do
			inClan[member.userId] = true
		end
		local any = false
		for _, other in Players:GetPlayers() do
			if other ~= player and not inClan[other.UserId] then
				any = true
				row(other.DisplayName, "Invite", UI.Colors.Good, function()
					act("invite", other.UserId)
				end)
			end
		end
		if not any then
			heading("Nobody else to invite right now.")
		end
		row("Leave the clan", "Leave", UI.Colors.Bad, function()
			act("leave")
		end)
	else
		heading("You're not in a clan. Make one, or ask a friend for an invite!", UI.Colors.Spark)
		local name = textBox("Clan name (3-" .. Config.Clans.NameMax .. " letters)", Config.Clans.NameMax)
		local tag =
			textBox("Tag (" .. Config.Clans.TagMin .. "-" .. Config.Clans.TagMax .. " letters)", Config.Clans.TagMax)
		UI.button({
			LayoutOrder = nextOrder(),
			Size = UDim2.new(1, -8, 0, 44),
			Text = "🛡️ Create clan  (⚡" .. Format.number(state.cost) .. ")",
			TextSize = 18,
			BackgroundColor3 = UI.Colors.Good,
			Parent = list,
		}).Activated
			:Connect(function()
				act("create", name.Text, tag.Text)
			end)
	end
	heading("🏆 Top Clans (most wins)", UI.Colors.Spark)
	if #state.top == 0 then
		heading("No clans yet. Be the first!")
	end
	for rank, entry in state.top do
		row(rank .. ". [" .. entry.tag .. "] " .. entry.name .. "  ·  🏆 " .. Format.number(entry.wins))
	end
end

reload = function()
	task.spawn(function()
		local ok, state = pcall(function()
			return Remotes.func("GetClan"):InvokeServer()
		end)
		if window.Visible then
			show(if ok then state else nil)
		end
	end)
end

function Clan.toggle()
	window.Visible = not window.Visible
	if window.Visible then
		status.Text = ""
		reload()
	end
end

local function showInvite(clanId: string, clanName: string, tag: string, fromName: string)
	local card = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -270),
		Size = UDim2.fromOffset(380, 96),
		BackgroundColor3 = UI.Colors.Panel,
		Parent = screen,
	}, { UI.corner(14), UI.stroke(UI.Colors.Rare, 3), UI.padding(10) })
	UI.label({
		Size = UDim2.new(1, 0, 0, 30),
		Text = "🛡️ " .. fromName .. " invited you to [" .. tag .. "] " .. clanName .. "!",
		TextSize = 16,
		TextWrapped = true,
		Parent = card,
	})
	UI.button({
		Position = UDim2.new(0, 0, 1, -38),
		Size = UDim2.new(0.5, -4, 0, 38),
		Text = "Join",
		BackgroundColor3 = UI.Colors.Good,
		Parent = card,
	}).Activated
		:Connect(function()
			card:Destroy()
			act("accept", clanId)
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
			card:Destroy()
		end)
	task.delay(Config.Clans.InviteSeconds, function()
		if card.Parent then
			card:Destroy()
		end
	end)
end

function Clan.start()
	screen = UI.screen("Clan", 7)
	window = UI.new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.9, 0, 0.85, 0),
		BackgroundColor3 = UI.Colors.Panel,
		Visible = false,
		Parent = screen,
	}, {
		UI.corner(18),
		UI.stroke(UI.Colors.Stroke, 3),
		UI.padding(14),
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(500, 620) }),
	})
	UI.label({
		Size = UDim2.new(1, -60, 0, 34),
		Text = "🛡️ Clan",
		TextSize = 28,
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
		Position = UDim2.fromOffset(0, 38),
		Size = UDim2.new(1, 0, 0, 20),
		Text = "",
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = window,
	})
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

	Remotes.event("ClanInvite").OnClientEvent:Connect(function(clanId, clanName, tag, fromName)
		if type(clanId) == "string" and type(clanName) == "string" and type(tag) == "string" then
			showInvite(clanId, clanName, tag, tostring(fromName))
		end
	end)
end

return Clan
