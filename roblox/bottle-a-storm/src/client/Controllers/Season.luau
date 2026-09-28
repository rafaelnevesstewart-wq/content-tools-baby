-- The 🎟️ battle pass window: this season's theme and time left, your stars,
-- and a scrolling row of 30 tiers with a free reward on top and a premium
-- reward below (Sparks, kits, exclusive kits and exclusive cosmetics). Tap a
-- glowing reward to claim it.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Format)
local Products = require(Shared.Products)
local Remotes = require(Shared.Remotes)
local CosmeticsData = require(Shared.CosmeticsData)
local SeasonData = require(Shared.SeasonData)
local StormData = require(Shared.StormData)

local Toasts = require(script.Parent.Toasts)
local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local Season = {}

type Progress = { id: number, xp: number, premium: boolean, claimedFree: { number }, claimedPremium: { number } }

local window: Frame
local titleLabel: TextLabel
local timeLabel: TextLabel
local xpFill: Frame
local xpLabel: TextLabel
local track: ScrollingFrame
local premiumButton: TextButton
local progress: Progress? = nil

local function rewardText(reward: SeasonData.Reward, theme: SeasonData.Theme): string
	if reward.kind == "sparks" then
		return "⚡ " .. Format.number(reward.amount or 0) .. "\nSparks"
	elseif reward.kind == "kit" then
		local rarity = StormData.Rarities[reward.rarity or 3]
		return (if reward.mutated then "✨ Shiny\n" else "🎁 Random\n") .. rarity.name .. " kit"
	elseif reward.kind == "exclusive" then
		local def = StormData.get(theme.storms[reward.slot or 1])
		return "🌟 " .. (if def then def.name else "Exclusive kit")
	elseif reward.kind == "cosmetic" then
		local item = CosmeticsData.get(reward.id or theme.cosmetics[reward.slot or 1])
		return if item then item.emoji .. " " .. item.name else "🎨 Cosmetic"
	end
	return "?"
end

local function rewardColor(reward: SeasonData.Reward, theme: SeasonData.Theme): Color3
	if reward.kind == "exclusive" or reward.kind == "cosmetic" then
		return UI.ink(theme.color)
	elseif reward.kind == "kit" then
		return UI.ink(StormData.Rarities[reward.rarity or 3].color)
	end
	return UI.Colors.Text
end

local function claim(tier: number, trackName: string)
	local ok, message = Remotes.func("SeasonClaim"):InvokeServer(tier, trackName)
	if not ok then
		Toasts.show(message, "warn")
	end
	Season.refresh()
end

local function cell(
	parent: Instance,
	order: number,
	reward: SeasonData.Reward?,
	theme: SeasonData.Theme,
	state: string,
	onClaim: () -> ()
)
	local box = UI.button({
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0.5, -4),
		Text = "",
		AutoButtonColor = state == "ready",
		BackgroundColor3 = if state == "ready"
			then UI.Colors.Good
			elseif state == "claimed" then Color3.fromRGB(34, 70, 54)
			else UI.Colors.PanelLight,
		Parent = parent,
	})
	UI.label({
		Size = UDim2.new(1, -6, 1, -6),
		Position = UDim2.fromOffset(3, 3),
		Text = if reward
			then rewardText(reward, theme) .. (if state == "claimed"
				then "\n✓"
				elseif state == "locked-premium" then "\n🔒"
				else "")
			else "—",
		TextScaled = true,
		TextColor3 = if reward then rewardColor(reward, theme) else UI.Colors.Muted,
		TextTransparency = if state == "locked" or state == "locked-premium" then 0.45 else 0,
		Parent = box,
	})
	if state == "ready" then
		box.Activated:Connect(onClaim)
	end
end

local function rebuild()
	local current = progress
	if not current then
		return
	end
	for _, child in track:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local _, theme = SeasonData.current(workspace:GetServerTimeNow())
	local tier = SeasonData.tierFor(current.xp)
	local claimedFree, claimedPremium = {}, {}
	for _, t in current.claimedFree do
		claimedFree[t] = true
	end
	for _, t in current.claimedPremium do
		claimedPremium[t] = true
	end

	for t = 1, SeasonData.Tiers do
		local rewards = SeasonData.Rewards[t] or {}
		local column = UI.new("Frame", {
			Name = "Tier" .. t,
			LayoutOrder = t,
			Size = UDim2.new(0, 104, 1, 0),
			BackgroundTransparency = 1,
			Parent = track,
		}, { UI.list(4) })
		UI.label({
			LayoutOrder = 0,
			Size = UDim2.new(1, 0, 0, 20),
			Text = (if t <= tier then "⭐ " else "") .. "Tier " .. t,
			TextSize = 15,
			TextColor3 = if t <= tier then UI.Colors.Spark else UI.Colors.Muted,
			Parent = column,
		})
		local body = UI.new("Frame", {
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 1, -24),
			BackgroundTransparency = 1,
			Parent = column,
		}, { UI.list(6) })

		local function state(reward: SeasonData.Reward?, claimed: boolean, premium: boolean): string
			if not reward then
				return "empty"
			elseif claimed then
				return "claimed"
			elseif premium and not current.premium then
				return "locked-premium"
			elseif t > tier then
				return "locked"
			end
			return "ready"
		end
		cell(body, 1, rewards.free, theme, state(rewards.free, claimedFree[t] == true, false), function()
			claim(t, "free")
		end)
		cell(body, 2, rewards.premium, theme, state(rewards.premium, claimedPremium[t] == true, true), function()
			claim(t, "premium")
		end)
	end
end

local function refreshHeader()
	local now = workspace:GetServerTimeNow()
	local number, theme, endsAt = SeasonData.current(now)
	titleLabel.Text = theme.emoji .. " Battle Pass: " .. theme.name .. "  ·  Season " .. (number + 1)
	titleLabel.TextColor3 = UI.ink(theme.color)
	local left = math.max(0, endsAt - now)
	timeLabel.Text = "Ends in " .. math.floor(left / 86400) .. "d " .. math.floor(left % 86400 / 3600) .. "h"
	local xp = player:GetAttribute("SeasonXp") or 0
	local tier = SeasonData.tierFor(xp)
	if tier >= SeasonData.Tiers then
		xpFill.Size = UDim2.fromScale(1, 1)
		xpLabel.Text = "⭐ Tier " .. tier .. ": max! You finished the season."
	else
		local into = xp - tier * SeasonData.XpPerTier
		xpFill.Size = UDim2.fromScale(into / SeasonData.XpPerTier, 1)
		xpLabel.Text = "⭐ Tier "
			.. tier
			.. "  ·  "
			.. Format.number(into)
			.. "/"
			.. SeasonData.XpPerTier
			.. " stars to tier "
			.. (tier + 1)
	end
	local premium = player:GetAttribute("SeasonPremium") == true
	premiumButton.Text = if premium
		then "🎟️ Premium ✓"
		else "🎟️ Unlock Premium  R$" .. (Products.get("SeasonPremium") :: Products.Item).price
	premiumButton.BackgroundColor3 = if premium then UI.Colors.Disabled else UI.Colors.Robux
end

function Season.refresh()
	local data = Remotes.func("GetSeason"):InvokeServer()
	if type(data) == "table" then
		progress = data
	end
	refreshHeader()
	rebuild()
end

function Season.toggle()
	window.Visible = not window.Visible
	if window.Visible then
		Season.refresh()
	end
end

local function buy(key: string)
	local item = Products.get(key)
	if not item then
		return
	end
	if item.id ~= 0 then
		MarketplaceService:PromptProductPurchase(player, item.id)
	elseif RunService:IsStudio() then
		Remotes.event("DevPurchase"):FireServer(key)
	else
		Toasts.show(item.name .. " is coming soon!", "info")
	end
end

function Season.start()
	local screen = UI.screen("Season", 6)
	window = UI.new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.94, 0.8),
		BackgroundColor3 = UI.Colors.Panel,
		Visible = false,
		Parent = screen,
	}, {
		UI.corner(18),
		UI.stroke(UI.Colors.Spark, 3),
		UI.padding(14),
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(820, 470) }),
	})

	titleLabel = UI.label({
		Size = UDim2.new(1, -60, 0, 32),
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = window,
	})
	local close = UI.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(44, 34),
		Text = "✕",
		TextSize = 22,
		BackgroundColor3 = UI.Colors.Bad,
		Parent = window,
	})
	close.Activated:Connect(function()
		window.Visible = false
	end)
	timeLabel = UI.label({
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(0.5, 0, 0, 20),
		TextSize = 15,
		TextColor3 = UI.Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = window,
	})

	local bar = UI.new("Frame", {
		Position = UDim2.fromOffset(0, 60),
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundColor3 = UI.Colors.Track,
		Parent = window,
	}, { UI.corner(10) })
	xpFill = UI.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = UI.Colors.Spark,
		Parent = bar,
	}, { UI.corner(10) })
	xpLabel = UI.label({
		Size = UDim2.fromScale(1, 1),
		TextSize = 15,
		TextStrokeTransparency = 0.3,
		ZIndex = 2,
		Parent = bar,
	})

	UI.label({
		Position = UDim2.fromOffset(0, 92),
		Size = UDim2.new(1, 0, 0, 18),
		Text = "Top row: free rewards  ·  Bottom row: 🎟️ Premium rewards  ·  Earn ⭐ by playing Bed Wars: knockouts, beds and wins",
		TextSize = 13,
		TextWrapped = true,
		TextColor3 = UI.Colors.Muted,
		Parent = window,
	})

	track = UI.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 116),
		Size = UDim2.new(1, 0, 1, -172),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
		Parent = window,
	}, { UI.list(6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left) })

	premiumButton = UI.button({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(0.6, -4, 0, 46),
		TextSize = 20,
		Parent = window,
	})
	premiumButton.Activated:Connect(function()
		if player:GetAttribute("SeasonPremium") ~= true then
			buy("SeasonPremium")
		end
	end)
	local skip = UI.button({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.new(0.4, -4, 0, 46),
		Text = "⏭️ Skip a tier  R$" .. (Products.get("SeasonSkip") :: Products.Item).price,
		TextSize = 18,
		BackgroundColor3 = UI.Colors.Robux,
		Parent = window,
	})
	skip.Activated:Connect(function()
		buy("SeasonSkip")
	end)

	player.AttributeChanged:Connect(function(name)
		if window.Visible and (name == "SeasonXp" or name == "SeasonPremium" or name == "SeasonTier") then
			if name == "SeasonXp" then
				refreshHeader()
			else
				Season.refresh()
			end
		end
	end)
end

return Season
