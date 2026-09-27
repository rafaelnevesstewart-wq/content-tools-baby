-- Storm battles on this screen: the ⚔️ challenge list, the "wants to battle"
-- pop-up, and the battle window that plays back the fight the server sent
-- (your storms at the bottom, theirs at the top).

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local BattleData = require(Shared.BattleData)
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local StormData = require(Shared.StormData)

local Sfx = require(script.Parent.Sfx)
local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local Battle = {}

type Card = {
	body: Frame,
	fill: Frame,
	hpText: TextLabel,
	stroke: UIStroke,
	maxHp: number,
	baseColor: Color3,
}

local action: RemoteEvent
local menu: Frame
local menuList: ScrollingFrame
local popup: Frame
local popupText: TextLabel
local pendingFrom: number? = nil
local window: Frame
local rows: { Frame } = {}
local names: { TextLabel } = {}
local logLabel: TextLabel
local resultLabel: TextLabel
local playId = 0

local function panel(screen: Instance, name: string, size: UDim2, stroke: Color3): Frame
	return UI.new("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = size,
		BackgroundColor3 = UI.Colors.Panel,
		Visible = false,
		Parent = screen,
	}, { UI.corner(18), UI.stroke(stroke, 3), UI.padding(12) })
end

function Battle.openMenu()
	for _, child in menuList:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	local others = 0
	for index, other in Players:GetPlayers() do
		if other ~= player then
			others += 1
			UI.button({
				LayoutOrder = index,
				Size = UDim2.new(1, -8, 0, 44),
				Text = "⚔️ " .. other.DisplayName,
				TextSize = 20,
				BackgroundColor3 = Color3.fromRGB(255, 150, 150),
				Parent = menuList,
			}).Activated
				:Connect(function()
					action:FireServer("request", other.UserId)
					menu.Visible = false
				end)
		end
	end
	if others == 0 then
		UI.button({
			Size = UDim2.new(1, -8, 0, 44),
			Text = "Nobody else is here yet!",
			TextSize = 18,
			AutoButtonColor = false,
			Parent = menuList,
		})
	end
	menu.Visible = not menu.Visible
end

local function makeCard(row: Frame, order: number, fighter: any): Card
	local def = StormData.get(fighter.id)
	local element = BattleData.Elements[fighter.element] or BattleData.Elements.Wind
	local rarityColor = if def then StormData.rarityOf(def).color else UI.Colors.Muted
	local slot = UI.new("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1 / Config.Battle.TeamSize, -8, 1, 0),
		BackgroundTransparency = 1,
		Parent = row,
	})
	local body = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UI.Colors.PanelLight,
		Parent = slot,
	}, { UI.corner(12) })
	local stroke = UI.stroke(rarityColor, 2)
	stroke.Parent = body
	UI.label({
		Position = UDim2.fromOffset(6, 4),
		Size = UDim2.new(1, -12, 0, 20),
		Text = element.emoji .. " " .. element.name .. "  ·  Lv " .. tostring(fighter.level),
		TextSize = 14,
		TextColor3 = UI.ink(element.color),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = body,
	})
	local nameLabel = UI.label({
		Position = UDim2.fromOffset(6, 24),
		Size = UDim2.new(1, -12, 0, 24),
		Text = tostring(fighter.name),
		TextScaled = true,
		TextColor3 = UI.ink(rarityColor),
		Parent = body,
	})
	UI.new("UITextSizeConstraint", { MaxTextSize = 18, Parent = nameLabel })
	local bar = UI.new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 6, 1, -6),
		Size = UDim2.new(1, -12, 0, 18),
		BackgroundColor3 = UI.Colors.Track,
		Parent = body,
	}, { UI.corner(9) })
	local fill = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UI.Colors.Good,
		Parent = bar,
	}, { UI.corner(9) })
	local hpText = UI.label({
		Size = UDim2.fromScale(1, 1),
		Text = fighter.maxHp .. " HP",
		TextSize = 13,
		Parent = bar,
	})
	return {
		body = body,
		fill = fill,
		hpText = hpText,
		stroke = stroke,
		maxHp = math.max(1, fighter.maxHp),
		baseColor = UI.Colors.PanelLight,
	}
end

local function floatText(card: Card, text: string, color: Color3)
	local label = UI.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(120, 30),
		Text = text,
		TextSize = 26,
		TextColor3 = color,
		TextStrokeColor3 = UI.Colors.Outline,
		TextStrokeTransparency = 0,
		ZIndex = 5,
		Parent = card.body,
	})
	local info = TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService
		:Create(
			label,
			info,
			{ Position = UDim2.fromScale(0.5, 0.05), TextTransparency = 1, TextStrokeTransparency = 1 }
		)
		:Play()
	task.delay(0.8, function()
		label:Destroy()
	end)
end

local function setActive(cards: { Card }, index: number)
	for i, card in cards do
		card.stroke.Thickness = if i == index then 4 else 2
	end
end

local function play(battle: any)
	playId += 1
	local myId = playId
	local mine = if battle.sides[2].userId == player.UserId then 2 else 1
	local theirs = 3 - mine
	-- Row 1 (top) shows the other side, row 2 (bottom) shows yours.
	local rowOf = { [theirs] = 1, [mine] = 2 }
	local cards: { { Card } } = { {}, {} }
	for side = 1, 2 do
		local row = rows[rowOf[side]]
		for _, child in row:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		for index, fighter in battle.sides[side].team do
			cards[side][index] = makeCard(row, index, fighter)
		end
		names[rowOf[side]].Text = (if side == mine then "🫵 You" else "⚔️ " .. tostring(battle.sides[side].name))
		setActive(cards[side], 1)
	end
	resultLabel.Visible = false
	logLabel.Text = "⚔️ Battle start!"
	window.Visible = true
	Sfx.play("chime")
	task.wait(1)

	for _, event in battle.events do
		if myId ~= playId then
			return -- a newer battle started
		end
		local attackerSide = event.side
		local defenderSide = 3 - attackerSide
		local attackerCard = cards[attackerSide][event.attacker]
		local defenderCard = cards[defenderSide][event.defender]
		local fighter = battle.sides[attackerSide].team[event.attacker]
		local target = battle.sides[defenderSide].team[event.defender]
		local element = BattleData.Elements[fighter.element] or BattleData.Elements.Wind
		setActive(cards[attackerSide], event.attacker)
		setActive(cards[defenderSide], event.defender)

		-- Lunge toward the other row, then back.
		local lunge = if rowOf[attackerSide] == 2 then -14 else 14
		local out = TweenService:Create(
			attackerCard.body,
			TweenInfo.new(0.12, Enum.EasingStyle.Quad),
			{ Position = UDim2.fromOffset(0, lunge) }
		)
		out:Play()
		out.Completed:Wait()
		TweenService:Create(attackerCard.body, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Position = UDim2.new() })
			:Play()

		-- The hit.
		Sfx.play(if event.crit then "zap" else "pop", 0.9 + math.random() * 0.2)
		defenderCard.body.BackgroundColor3 = UI.Colors.Bad
		TweenService:Create(defenderCard.body, TweenInfo.new(0.35), { BackgroundColor3 = defenderCard.baseColor })
			:Play()
		local fraction = math.clamp(event.hp / defenderCard.maxHp, 0, 1)
		TweenService:Create(defenderCard.fill, TweenInfo.new(0.3), {
			Size = UDim2.fromScale(fraction, 1),
			BackgroundColor3 = if fraction > 0.5
				then UI.Colors.Good
				elseif fraction > 0.2 then UI.Colors.Warn
				else UI.Colors.Bad,
		}):Play()
		defenderCard.hpText.Text = event.hp .. " HP"
		floatText(defenderCard, "-" .. event.damage, if event.crit then UI.Colors.Spark else UI.Colors.Bad)

		local text = tostring(fighter.name) .. " used " .. element.move .. "! -" .. event.damage
		if event.crit then
			text ..= "  💥 Critical hit!"
		end
		if event.effect == 1 then
			text ..= "  It's super effective!"
		elseif event.effect == -1 then
			text ..= "  Not very effective..."
		end
		if event.fainted then
			text ..= "\n💫 " .. tostring(target.name) .. " is out!"
			defenderCard.body.BackgroundTransparency = 0.5
		end
		logLabel.Text = text
		task.wait(Config.Battle.PlaybackTurnSeconds - 0.12)
	end

	if myId ~= playId then
		return
	end
	local won = battle.winner == mine
	resultLabel.Text = if won then "🏆 You win!" else "💪 Good fight!"
	resultLabel.TextColor3 = if won then UI.Colors.Spark else UI.Colors.Rare
	resultLabel.Visible = true
	Sfx.play(if won then "coins" else "chime")
end

function Battle.start()
	action = Remotes.event("BattleAction")
	local screen = UI.screen("Battle", 7)

	-- Challenge list.
	menu = panel(screen, "BattleMenu", UDim2.fromOffset(300, 320), Color3.fromRGB(255, 130, 130))
	UI.label({ Size = UDim2.new(1, -50, 0, 30), Text = "⚔️ Challenge someone", TextSize = 20, Parent = menu })
	UI.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(40, 32),
		Text = "✕",
		BackgroundColor3 = UI.Colors.Bad,
		Parent = menu,
	}).Activated
		:Connect(function()
			menu.Visible = false
		end)
	UI.label({
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, 0, 0, 36),
		Text = "Your 3 strongest storms fight theirs. Nobody loses a storm!",
		TextSize = 14,
		TextWrapped = true,
		TextColor3 = UI.Colors.Muted,
		Parent = menu,
	})
	menuList = UI.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 74),
		Size = UDim2.new(1, 0, 1, -74),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = menu,
	}, { UI.list(6) })

	-- "X wants to battle!" pop-up.
	popup = UI.new("Frame", {
		Name = "BattleInvite",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 290),
		Size = UDim2.fromOffset(340, 110),
		BackgroundColor3 = UI.Colors.Panel,
		Visible = false,
		Parent = screen,
	}, { UI.corner(14), UI.stroke(Color3.fromRGB(255, 130, 130), 3), UI.padding(10) })
	popupText = UI.label({ Size = UDim2.new(1, 0, 0, 44), TextSize = 20, TextWrapped = true, Parent = popup })
	for index, choice in { { "⚔️ Fight!", UI.Colors.Good, true }, { "❌ No thanks", UI.Colors.Bad, false } } do
		UI.button({
			Position = UDim2.new(if index == 1 then 0 else 0.52, 0, 0, 50),
			Size = UDim2.new(0.48, 0, 0, 40),
			Text = choice[1] :: string,
			BackgroundColor3 = choice[2] :: Color3,
			Parent = popup,
		}).Activated
			:Connect(function()
				if pendingFrom then
					action:FireServer("respond", pendingFrom, choice[3])
				end
				pendingFrom = nil
				popup.Visible = false
			end)
	end

	-- The battle window.
	window = panel(screen, "BattleWindow", UDim2.fromScale(0.94, 0.86), Color3.fromRGB(255, 130, 130))
	UI.new("UISizeConstraint", { MaxSize = Vector2.new(640, 460), Parent = window })
	UI.new("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = window,
	})
	local function nameLabel(order: number): TextLabel
		return UI.label({
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 24),
			TextSize = 20,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = window,
		})
	end
	local function row(order: number): Frame
		return UI.new("Frame", {
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0.27, 0),
			BackgroundTransparency = 1,
			Parent = window,
		}, { UI.list(8, Enum.FillDirection.Horizontal) })
	end
	names[1] = nameLabel(1)
	rows[1] = row(2)
	local middle = UI.new("Frame", {
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0.2, 0),
		BackgroundTransparency = 1,
		Parent = window,
	})
	logLabel = UI.label({
		Size = UDim2.fromScale(1, 1),
		TextSize = 18,
		TextWrapped = true,
		Parent = middle,
	})
	resultLabel = UI.label({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0,
		TextSize = 40,
		Visible = false,
		ZIndex = 4,
		Parent = middle,
	})
	rows[2] = row(4)
	names[2] = nameLabel(5)
	UI.button({
		LayoutOrder = 6,
		Size = UDim2.fromOffset(160, 38),
		Text = "Close",
		TextSize = 20,
		BackgroundColor3 = UI.Colors.PanelLight,
		Parent = window,
	}).Activated
		:Connect(function()
			window.Visible = false
		end)

	Remotes.event("BattleInvite").OnClientEvent:Connect(function(fromUserId, fromName)
		pendingFrom = fromUserId
		popupText.Text = "⚔️ " .. tostring(fromName) .. " wants a storm battle!"
		popup.Visible = true
		Sfx.play("chime")
		task.delay(Config.Battle.RequestSeconds, function()
			if pendingFrom == fromUserId then
				pendingFrom = nil
				popup.Visible = false
			end
		end)
	end)
	Remotes.event("BattlePlay").OnClientEvent:Connect(function(battle)
		if type(battle) == "table" then
			menu.Visible = false
			task.spawn(play, battle)
		end
	end)
end

return Battle
