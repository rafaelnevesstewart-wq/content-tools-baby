-- The 🎁 Rewards window, with four tabs:
--   * Daily: 7-day login streak. Claim one reward a day.
--   * Quests: 3 small goals that change every day.
--   * Index: every storm in the game. Ones you haven't found show as "???".
--     Finding all storms of a rarity completes a row (+5% Sparks forever).
--   * Titles: earned by playing; pick one to show above your name.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Products = require(Shared.Products)
local Remotes = require(Shared.Remotes)
local RewardsData = require(Shared.RewardsData)
local SpinData = require(Shared.SpinData)
local StormData = require(Shared.StormData)
local TitleData = require(Shared.TitleData)

local Toasts = require(script.Parent.Toasts)
local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local Rewards = {}

type QuestInfo = { text: string, progress: number, target: number, claimed: boolean }
type Info = {
	dailyReady: boolean,
	nextStreak: number,
	streak: number,
	quests: { QuestInfo },
	discovered: { string },
	rows: number,
}

local window: Frame
local pages: { [string]: Frame } = {}
local tabs: { [string]: TextButton } = {}
local currentTab = "Daily"
local info: Info? = nil
type TitleInfo = { equipped: string?, list: { { id: string, unlocked: boolean, progress: number } } }
local titles: TitleInfo? = nil
local busy = false

local function clear(frame: Instance)
	for _, child in frame:GetChildren() do
		child:Destroy()
	end
end

-- A label whose text shrinks to fit, but never grows past `maxSize`.
local function capped(props: { [string]: any }, maxSize: number): TextLabel
	local label = UI.label(props)
	UI.new("UITextSizeConstraint", { MaxTextSize = maxSize, Parent = label })
	return label
end

local function claimWith(remote: string, arg: any?)
	if busy then
		return
	end
	busy = true
	local ok, message = Remotes.func(remote):InvokeServer(arg)
	busy = false
	Toasts.show(message, if ok then "success" else "warn")
	Rewards.refresh()
end

local function buildDaily(page: Frame, data: Info)
	UI.label({
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 24),
		Text = "Come back every day! Miss a day and your streak starts over.",
		TextSize = 16,
		TextColor3 = UI.Colors.Muted,
		Parent = page,
	})
	local row = UI.new("Frame", {
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 120),
		BackgroundTransparency = 1,
		Parent = page,
	}, { UI.list(6, Enum.FillDirection.Horizontal) })
	for day, reward in RewardsData.Daily do
		local claimed = if data.dailyReady then day < data.nextStreak else day <= data.streak
		local ready = data.dailyReady and day == data.nextStreak
		local tile = UI.new("Frame", {
			LayoutOrder = day,
			Size = UDim2.new(1 / #RewardsData.Daily, -6, 1, 0),
			BackgroundColor3 = if ready
				then UI.Colors.Good
				elseif claimed then Color3.fromRGB(34, 70, 54)
				else UI.Colors.PanelLight,
			Parent = row,
		}, {
			UI.corner(12),
			UI.stroke(if ready then UI.Colors.Outline else UI.Colors.Stroke, if ready then 3 else 1.5),
		})
		UI.label({
			Size = UDim2.new(1, 0, 0, 22),
			Position = UDim2.fromOffset(0, 4),
			Text = "Day " .. day,
			TextSize = 16,
			TextColor3 = if ready then Color3.new(1, 1, 1) else UI.Colors.Text,
			TextStrokeColor3 = UI.Colors.Outline,
			TextStrokeTransparency = if ready then 0.2 else 1,
			Parent = tile,
		})
		capped({
			Size = UDim2.new(1, -8, 1, -32),
			Position = UDim2.fromOffset(4, 28),
			Text = RewardsData.describe(reward) .. (if claimed then "\n✓" else ""),
			TextScaled = true,
			TextWrapped = true,
			TextColor3 = if day >= 6 then UI.ink(StormData.Rarities[reward.rarity or 3].color) else UI.Colors.Text,
			TextTransparency = if claimed then 0.4 else 0,
			Parent = tile,
		}, 16)
	end
	local button = UI.button({
		LayoutOrder = 3,
		Size = UDim2.fromOffset(260, 48),
		Text = if data.dailyReady then "🎁 Claim Day " .. data.nextStreak else "✓ Come back tomorrow!",
		TextSize = 22,
		BackgroundColor3 = if data.dailyReady then UI.Colors.Good else UI.Colors.Disabled,
		AutoButtonColor = data.dailyReady,
		Parent = page,
	})
	if data.dailyReady then
		button.Activated:Connect(function()
			claimWith("ClaimDaily", nil)
		end)
	end
end

local function buildQuests(page: Frame, data: Info)
	UI.label({
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 24),
		Text = "New quests every day. Each one pays Sparks and " .. Config.Quests.RewardStars .. " ⭐ Season Stars.",
		TextSize = 16,
		TextColor3 = UI.Colors.Muted,
		Parent = page,
	})
	for index, quest in data.quests do
		local done = quest.progress >= quest.target
		local card = UI.new("Frame", {
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, 70),
			BackgroundColor3 = UI.Colors.PanelLight,
			Parent = page,
		}, { UI.corner(12), UI.padding(8) })
		UI.label({
			Size = UDim2.new(1, -150, 0, 26),
			Text = "📜 " .. quest.text,
			TextSize = 19,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = card,
		})
		local bar = UI.new("Frame", {
			Position = UDim2.fromOffset(0, 32),
			Size = UDim2.new(1, -150, 0, 20),
			BackgroundColor3 = UI.Colors.Track,
			Parent = card,
		}, { UI.corner(10) })
		UI.new("Frame", {
			Size = UDim2.fromScale(math.clamp(quest.progress / math.max(quest.target, 1), 0, 1), 1),
			BackgroundColor3 = if done then UI.Colors.Good else UI.Colors.Rare,
			Parent = bar,
		}, { UI.corner(10) })
		UI.label({
			Size = UDim2.fromScale(1, 1),
			Text = math.floor(quest.progress) .. " / " .. quest.target,
			TextSize = 14,
			Parent = bar,
		})
		local canClaim = done and not quest.claimed
		local button = UI.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(136, 44),
			Text = if quest.claimed then "✓ Done" elseif done then "🎁 Claim" else "In progress",
			TextSize = 18,
			BackgroundColor3 = if canClaim then UI.Colors.Good else UI.Colors.Disabled,
			AutoButtonColor = canClaim,
			Parent = card,
		})
		if canClaim then
			button.Activated:Connect(function()
				claimWith("ClaimQuest", index)
			end)
		end
	end
end

-- Where to look for a storm you haven't found yet.
local function hint(def: StormData.StormDef): string
	if def.holiday then
		return "Holiday event"
	elseif def.season then
		return "Season pass"
	elseif def.hybrid then
		return "Storm Mixer"
	elseif def.biome then
		return "Climate island"
	end
	return "Wild Skies"
end

local function buildIndex(page: Frame, data: Info)
	local found: { [string]: boolean } = {}
	for _, id in data.discovered do
		found[id] = true
	end
	local list: { StormData.StormDef } = {}
	local totals: { [number]: { have: number, all: number } } = {}
	local have, all = 0, 0
	for _, def in StormData.Storms do
		table.insert(list, def)
		if not StormData.isExclusive(def) then
			totals[def.rarity] = totals[def.rarity] or { have = 0, all = 0 }
			totals[def.rarity].all += 1
			all += 1
			if found[def.id] then
				totals[def.rarity].have += 1
				have += 1
			end
		end
	end
	table.sort(list, function(a, b)
		local sa, sb = if StormData.isExclusive(a) then 1 else 0, if StormData.isExclusive(b) then 1 else 0
		if sa ~= sb then
			return sa < sb
		end
		if a.rarity ~= b.rarity then
			return a.rarity < b.rarity
		end
		return a.name < b.name
	end)

	UI.label({
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 24),
		Text = "📖 "
			.. have
			.. " / "
			.. all
			.. " storms found · "
			.. data.rows
			.. " rows complete (+"
			.. math.floor(data.rows * Config.Index.RowBonus * 100 + 0.5)
			.. "% Sparks)",
		TextSize = 18,
		Parent = page,
	})
	local rowsLine = {}
	for rarity, count in totals do
		local name = StormData.Rarities[rarity].name
		table.insert(rowsLine, {
			rarity,
			name .. " " .. count.have .. "/" .. count.all .. (if count.have == count.all then " ✓" else ""),
		})
	end
	table.sort(rowsLine, function(a, b)
		return a[1] < b[1]
	end)
	local parts = {}
	for _, entry in rowsLine do
		table.insert(parts, entry[2])
	end
	capped({
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 20),
		Text = table.concat(parts, "  ·  "),
		TextSize = 14,
		TextColor3 = UI.Colors.Muted,
		TextScaled = true,
		Parent = page,
	}, 14)

	local scroll = UI.new("ScrollingFrame", {
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 1, -56),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = UI.Colors.Stroke,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = page,
	}, {
		UI.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(118, 64),
			CellPadding = UDim2.fromOffset(6, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
		UI.padding(4),
	})
	for order, def in list do
		local known = found[def.id] == true
		local color = StormData.rarityOf(def).color
		local tile = UI.new("Frame", {
			LayoutOrder = order,
			BackgroundColor3 = if known then UI.Colors.Panel else UI.Colors.Disabled,
			Parent = scroll,
		}, { UI.corner(10), UI.stroke(if known then color else UI.Colors.Muted, 2) })
		capped({
			Position = UDim2.fromOffset(4, 4),
			Size = UDim2.new(1, -8, 0, 30),
			Text = if known then def.name else "???",
			TextScaled = true,
			TextColor3 = if known then UI.ink(color) else UI.Colors.Muted,
			Parent = tile,
		}, 17)
		capped({
			Position = UDim2.fromOffset(4, 36),
			Size = UDim2.new(1, -8, 0, 22),
			Text = (if def.holiday then "🎉 " elseif def.season then "🌟 " else "")
				.. StormData.rarityOf(def).name
				.. (if known then "" else " · " .. hint(def)),
			TextScaled = true,
			TextColor3 = UI.Colors.Muted,
			Parent = tile,
		}, 13)
	end
end

local function buildTitles(page: Frame)
	local data = titles
	if not data then
		UI.label({ Size = UDim2.new(1, 0, 0, 30), Text = "Loading...", Parent = page })
		return
	end
	local header = UI.new("Frame", {
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 1,
		Parent = page,
	})
	UI.label({
		Size = UDim2.new(1, -150, 1, 0),
		Text = "Earn titles by playing. Tap one you've earned to show it above your name!",
		TextSize = 15,
		TextWrapped = true,
		TextColor3 = UI.Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = header,
	})
	UI.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(140, 36),
		Text = "Hide my title",
		TextSize = 16,
		Parent = header,
	}).Activated
		:Connect(function()
			claimWith("SetTitle", nil)
		end)

	local scroll = UI.new("ScrollingFrame", {
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 1, -46),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = UI.Colors.Stroke,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = page,
	}, {
		UI.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(186, 76),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
		UI.padding(4),
	})
	for order, entry in data.list do
		local title = TitleData.get(entry.id)
		if not title then
			continue
		end
		local showing = data.equipped == entry.id
		local tile = UI.button({
			LayoutOrder = order,
			Text = "",
			AutoButtonColor = entry.unlocked,
			BackgroundColor3 = if showing
				then Color3.fromRGB(78, 64, 30)
				elseif entry.unlocked then UI.Colors.Panel
				else UI.Colors.Disabled,
			Parent = scroll,
		})
		capped({
			Position = UDim2.fromOffset(6, 4),
			Size = UDim2.new(1, -12, 0, 26),
			Text = title.emoji .. " " .. title.name,
			TextScaled = true,
			TextColor3 = if entry.unlocked then UI.ink(title.color) else UI.Colors.Muted,
			Parent = tile,
		}, 19)
		capped({
			Position = UDim2.fromOffset(6, 30),
			Size = UDim2.new(1, -12, 0, 18),
			Text = title.goal,
			TextScaled = true,
			TextColor3 = UI.Colors.Muted,
			Parent = tile,
		}, 13)
		capped({
			Position = UDim2.fromOffset(6, 50),
			Size = UDim2.new(1, -12, 0, 20),
			Text = if showing
				then "✓ Showing"
				elseif entry.unlocked then "Tap to show"
				else "🔒 " .. math.floor(entry.progress) .. " / " .. title.target,
			TextScaled = true,
			TextColor3 = if entry.unlocked then UI.Colors.Good else UI.Colors.Muted,
			Parent = tile,
		}, 14)
		if entry.unlocked and not showing then
			tile.Activated:Connect(function()
				claimWith("SetTitle", entry.id)
			end)
		end
	end
end

local function buildCodes(page: Frame)
	UI.label({
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 24),
		Text = "🎟️ Got a code? Type it here! Codes are posted on our social media.",
		TextSize = 16,
		TextColor3 = UI.Colors.Muted,
		Parent = page,
	})
	local row = UI.new("Frame", {
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundTransparency = 1,
		Parent = page,
	})
	local box: TextBox = UI.new("TextBox", {
		Size = UDim2.new(1, -150, 1, 0),
		BackgroundColor3 = UI.Colors.Track,
		Font = UI.Font,
		TextSize = 20,
		TextColor3 = UI.Colors.Text,
		PlaceholderText = "Enter code",
		PlaceholderColor3 = UI.Colors.Muted,
		Text = "",
		ClearTextOnFocus = false,
		Parent = row,
	}, { UI.corner(10), UI.stroke(UI.Colors.Stroke, 1.5) })
	UI.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 140, 1, 0),
		Text = "Redeem",
		TextSize = 20,
		BackgroundColor3 = UI.Colors.Good,
		Parent = row,
	}).Activated
		:Connect(function()
			local text = box.Text
			if text ~= "" then
				box.Text = ""
				claimWith("RedeemCode", text)
			end
		end)

	local group = UI.new("Frame", {
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 70),
		BackgroundColor3 = UI.Colors.PanelLight,
		Parent = page,
	}, { UI.corner(12), UI.padding(10) })
	local inGroup = player:GetAttribute("InGroup") == true
	local bonus = math.floor(Config.Group.Bonus * 100)
	UI.label({
		Size = UDim2.new(1, -170, 1, 0),
		Text = if inGroup
			then "👥 Group bonus is ON: +" .. bonus .. "% Sparks. Thanks for joining!"
			else "👥 Join " .. Config.Group.Name .. " on Roblox for +" .. bonus .. "% Sparks forever!",
		TextSize = 16,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = group,
	})
	if not inGroup then
		UI.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(160, 42),
			Text = "I joined! Check",
			TextSize = 16,
			BackgroundColor3 = UI.Colors.Stroke,
			Parent = group,
		}).Activated
			:Connect(function()
				claimWith("CheckGroup", nil)
			end)
	end
	UI.label({
		LayoutOrder = 4,
		Size = UDim2.new(1, 0, 0, 40),
		Text = "👍 Like the game! At "
			.. Config.LikeGoal.Goal
			.. " likes we'll post "
			.. Config.LikeGoal.Reward
			.. ".",
		TextSize = 16,
		TextWrapped = true,
		Parent = page,
	})
end

local wheelSpinning = false

local function buildSpin(page: Frame)
	local free = player:GetAttribute("FreeSpin") == true
	local extra = player:GetAttribute("ExtraSpins") or 0
	UI.label({
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 22),
		Text = "🎡 One free spin every day!"
			.. (if extra > 0 then "  You also have " .. extra .. " extra spins." else ""),
		TextSize = 16,
		TextColor3 = UI.Colors.Muted,
		Parent = page,
	})
	local area = UI.new("Frame", {
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 1, -90),
		BackgroundTransparency = 1,
		Parent = page,
	})
	local wheel = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(250, 250),
		BackgroundColor3 = UI.Colors.PanelLight,
		Parent = area,
	}, { UI.corner(125), UI.stroke(UI.Colors.Spark, 4) })
	UI.new("UIAspectRatioConstraint", { Parent = wheel })
	local count = #SpinData.Prizes
	for index, prize in SpinData.Prizes do
		local angle = math.rad((index - 1) * 360 / count)
		local slice = UI.label({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5 + math.sin(angle) * 0.36, 0.5 - math.cos(angle) * 0.36),
			Size = UDim2.fromOffset(78, 26),
			Rotation = (index - 1) * 360 / count,
			BackgroundColor3 = prize.color,
			BackgroundTransparency = 0,
			Text = prize.label,
			TextScaled = true,
			TextColor3 = Color3.new(1, 1, 1),
			Parent = wheel,
		})
		UI.corner(8).Parent = slice
	end
	UI.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(50, 50),
		BackgroundColor3 = UI.Colors.Spark,
		BackgroundTransparency = 0,
		Text = "🎡",
		TextSize = 26,
		Parent = wheel,
	})
	UI.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0.52, -122),
		Size = UDim2.fromOffset(40, 30),
		Text = "▼",
		TextSize = 30,
		TextColor3 = UI.Colors.Spark,
		ZIndex = 3,
		Parent = area,
	})

	local buttons = UI.new("Frame", {
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundTransparency = 1,
		Parent = page,
	}, { UI.list(10, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center) })
	local canSpin = free or extra > 0
	local spinButton = UI.button({
		LayoutOrder = 1,
		Size = UDim2.fromOffset(200, 46),
		Text = if free
			then "🎡 Free spin!"
			elseif extra > 0 then "🎡 Spin (" .. extra .. " left)"
			else "Come back tomorrow",
		TextSize = 20,
		BackgroundColor3 = if canSpin then UI.Colors.Good else UI.Colors.Disabled,
		AutoButtonColor = canSpin,
		Parent = buttons,
	})
	local product = Products.get("SpinWheel3")
	UI.button({
		LayoutOrder = 2,
		Size = UDim2.fromOffset(200, 46),
		Text = "+3 spins  R$ " .. (if product then product.price else "?"),
		TextSize = 18,
		BackgroundColor3 = UI.Colors.Robux,
		Parent = buttons,
	}).Activated
		:Connect(function()
			if not product then
				return
			end
			if product.id ~= 0 then
				MarketplaceService:PromptProductPurchase(player, product.id)
			elseif RunService:IsStudio() then
				Remotes.event("DevPurchase"):FireServer(product.key)
			else
				Toasts.show("Extra spins are coming soon!", "info")
			end
		end)
	spinButton.Activated:Connect(function()
		if not canSpin or wheelSpinning then
			return
		end
		wheelSpinning = true
		local ok, result = Remotes.func("Spin"):InvokeServer()
		if not ok or type(result) ~= "number" then
			wheelSpinning = false
			Toasts.show(tostring(result), "warn")
			return
		end
		-- Turn so the prize's slice ends under the pointer at the top.
		local target = -(result - 1) * 360 / count
		local current = wheel.Rotation
		local final = current + 360 * 5 + ((target - current) % 360)
		local tween = TweenService:Create(
			wheel,
			TweenInfo.new(SpinData.SpinSeconds, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
			{ Rotation = final }
		)
		tween:Play()
		tween.Completed:Wait()
		wheelSpinning = false
		Rewards.refresh()
	end)
end

local function rebuild()
	local data = info
	for name, page in pages do
		page.Visible = name == currentTab
		tabs[name].BackgroundColor3 = if name == currentTab then UI.Colors.Rare else UI.Colors.PanelLight
	end
	local page = pages[currentTab]
	clear(page)
	UI.list(10).Parent = page
	if currentTab == "Titles" then
		buildTitles(page)
		return
	elseif currentTab == "Codes" then
		buildCodes(page)
		return
	elseif currentTab == "Spin" then
		buildSpin(page)
		return
	end
	if not data then
		UI.label({ Size = UDim2.new(1, 0, 0, 30), Text = "Loading...", Parent = page })
		return
	end
	if currentTab == "Daily" then
		buildDaily(page, data)
	elseif currentTab == "Quests" then
		buildQuests(page, data)
	else
		buildIndex(page, data)
	end
end

function Rewards.refresh()
	local data = Remotes.func("GetRewards"):InvokeServer()
	if type(data) == "table" then
		info = data
	end
	local titleData = Remotes.func("GetTitles"):InvokeServer()
	if type(titleData) == "table" then
		titles = titleData
	end
	if window.Visible and not wheelSpinning then
		rebuild()
	end
end

function Rewards.open(tab: string?)
	currentTab = tab or currentTab
	window.Visible = true
	rebuild()
	task.spawn(Rewards.refresh)
end

function Rewards.toggle()
	if window.Visible then
		window.Visible = false
	else
		Rewards.open(nil)
	end
end

function Rewards.start()
	local screen = UI.screen("Rewards", 6)
	window = UI.new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.94, 0.82),
		BackgroundColor3 = UI.Colors.Panel,
		Visible = false,
		Parent = screen,
	}, {
		UI.corner(18),
		UI.stroke(UI.Colors.Stroke, 3),
		UI.padding(14),
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(820, 480) }),
	})
	UI.label({
		Size = UDim2.new(1, -60, 0, 32),
		Text = "🎁 Rewards",
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = window,
	})
	UI.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(44, 34),
		Text = "✕",
		TextSize = 22,
		BackgroundColor3 = UI.Colors.Bad,
		Parent = window,
	}).Activated
		:Connect(function()
			window.Visible = false
		end)

	local tabRow = UI.new("Frame", {
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundTransparency = 1,
		Parent = window,
	}, { UI.list(8, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left) })
	for order, entry in
		{
			{ "Daily", "📅 Daily" },
			{ "Quests", "📜 Quests" },
			{ "Index", "📖 Index" },
			{ "Titles", "🏷️ Titles" },
			{ "Codes", "🎟️ Codes" },
			{ "Spin", "🎡 Spin" },
		}
	do
		local name = entry[1]
		local button = UI.button({
			LayoutOrder = order,
			Size = UDim2.new(1 / 6, -8, 1, 0),
			Text = entry[2],
			TextSize = 18,
			Parent = tabRow,
		})
		button.Activated:Connect(function()
			currentTab = name
			rebuild()
		end)
		tabs[name] = button
		pages[name] = UI.new("Frame", {
			Name = name,
			Position = UDim2.fromOffset(0, 88),
			Size = UDim2.new(1, 0, 1, -88),
			BackgroundTransparency = 1,
			Visible = false,
			Parent = window,
		})
	end

	-- Refresh the open window when quests progress or a new day starts.
	player:GetAttributeChangedSignal("RewardsReady"):Connect(function()
		if window.Visible then
			Rewards.refresh()
		end
	end)

	-- Pop the Daily tab open once, the first time a reward is waiting.
	task.spawn(function()
		local deadline = os.clock() + 30
		while player:GetAttribute("DailyReady") == nil and os.clock() < deadline do
			task.wait(1)
		end
		task.wait(4) -- let the welcome pop-ups settle first
		if player:GetAttribute("DailyReady") == true and not window.Visible then
			Rewards.open("Daily")
		end
	end)
end

return Rewards
