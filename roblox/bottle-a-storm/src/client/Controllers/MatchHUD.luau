-- Bed Wars on your screen: the match banner (waiting / countdown / timer /
-- winner), every team with its bed ✅ or ❌ and players left, and the
-- resources you carry. It also hides the "Break the bed" prompt on your own
-- team's bed.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local MatchData = require(Shared.MatchData)

local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local MatchHUD = {}

local banner: TextLabel
local teamRow: Frame
local wallet: TextLabel
local spectating: TextLabel
local teamChips: { TextLabel } = {}

local function teamInfo(key: string): MatchData.TeamInfo?
	for _, info in MatchData.Teams do
		if info.key == key then
			return info
		end
	end
	return nil
end

local function readTeams(): { any }
	local raw = workspace:GetAttribute("MatchTeams")
	if type(raw) ~= "string" or raw == "" then
		return {}
	end
	local ok, list = pcall(HttpService.JSONDecode, HttpService, raw)
	return if ok and type(list) == "table" then list else {}
end

local function refreshTeams()
	local list = readTeams()
	for index, chip in teamChips do
		if not list[index] then
			chip:Destroy()
			teamChips[index] = nil
		end
	end
	for index, team in list do
		local info = teamInfo(team.key)
		if not info then
			continue
		end
		local chip = teamChips[index]
		if not chip then
			chip = UI.label({
				LayoutOrder = index,
				Size = UDim2.fromOffset(0, 30),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundColor3 = UI.Colors.Panel,
				BackgroundTransparency = 0.15,
				TextSize = 16,
				Parent = teamRow,
			})
			UI.corner(10).Parent = chip
			UI.new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = chip })
			teamChips[index] = chip
		end
		local out = team.alive <= 0
		chip.Text = info.emoji .. " " .. (if team.bed then "🛏️✅" else "🛏️❌") .. " " .. team.alive
		chip.TextColor3 = if out then UI.Colors.Muted else UI.ink(info.color)
		chip.BackgroundTransparency = if out then 0.5 else 0.15
		local stroke = chip:FindFirstChildOfClass("UIStroke") or UI.stroke(info.color, 2)
		stroke.Color = if team.key == player:GetAttribute("TeamKey") then Color3.new(1, 1, 1) else info.color
		stroke.Parent = chip
	end
end

local function refreshBanner()
	local now = workspace:GetServerTimeNow()
	local phase = workspace:GetAttribute("MatchPhase")
	local timer = workspace:GetAttribute("MatchTimer") or 0
	if phase == "waiting" then
		local ready = workspace:GetAttribute("MatchReady") or 0
		local needed = workspace:GetAttribute("MatchNeeded") or Config.Match.MinPlayers
		banner.Text = "⏳ Waiting for players (" .. ready .. "/" .. needed .. ")"
		banner.TextColor3 = UI.Colors.Text
	elseif phase == "starting" then
		banner.Text = "⚔️ Bed Wars starts in " .. math.max(0, math.ceil(timer - now)) .. "!"
		banner.TextColor3 = UI.Colors.Spark
	elseif phase == "playing" then
		local startedAt = workspace:GetAttribute("MatchStartedAt") or now
		local elapsed = now - startedAt
		local text = "⚔️ " .. Format.time(math.max(0, elapsed))
		local tiers = Config.Match.TierUpAt
		if elapsed < tiers[1] then
			text ..= "  ·  💎 Faster generators in " .. Format.time(tiers[1] - elapsed)
		elseif elapsed < tiers[2] then
			text ..= "  ·  💎 Even faster in " .. Format.time(tiers[2] - elapsed)
		elseif elapsed < Config.Match.SuddenDeathAt then
			text ..= "  ·  ⚠️ Sudden Death in " .. Format.time(Config.Match.SuddenDeathAt - elapsed)
		else
			text ..= "  ·  ⚠️ SUDDEN DEATH"
		end
		banner.Text = text
		banner.TextColor3 = UI.Colors.Text
	elseif phase == "ended" then
		local winner = teamInfo(workspace:GetAttribute("MatchWinner") or "")
		banner.Text = if winner then "🏆 " .. winner.emoji .. " " .. winner.name .. " WINS!" else "🏁 Match over!"
		banner.TextColor3 = UI.Colors.Spark
	end
end

local function refreshWallet()
	local inMatch = player:GetAttribute("InMatch") == true and not player:GetAttribute("Spectating")
	wallet.Visible = inMatch
	spectating.Visible = player:GetAttribute("Spectating") == true
	if inMatch then
		local parts = {}
		for _, info in MatchData.Resources do
			local value = player:GetAttribute("Res_" .. info.key)
			table.insert(parts, info.emoji .. " " .. (if type(value) == "number" then value else 0))
		end
		wallet.Text = table.concat(parts, "    ")
	end
end

-- You can't break your own bed.
local function refreshBedPrompts()
	local match = workspace:FindFirstChild("Match")
	local mine = player:GetAttribute("TeamKey")
	if not match then
		return
	end
	for _, prompt in match:GetDescendants() do
		if prompt:IsA("ProximityPrompt") and prompt.Name == "BedPrompt" then
			local enabled = prompt:GetAttribute("Team") ~= mine
			if prompt.Enabled ~= enabled then
				prompt.Enabled = enabled
			end
		end
	end
end

function MatchHUD.start()
	local screen = UI.screen("MatchHUD", 2)
	local top = UI.new("Frame", {
		Name = "Match",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 96),
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		Parent = screen,
	}, { UI.list(6) })
	banner = UI.label({
		LayoutOrder = 1,
		Size = UDim2.fromOffset(0, 34),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.1,
		TextSize = 20,
		Parent = top,
	})
	UI.corner(12).Parent = banner
	UI.stroke(UI.Colors.Stroke, 2).Parent = banner
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), Parent = banner })
	teamRow = UI.new("Frame", {
		LayoutOrder = 2,
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Parent = top,
	}, { UI.list(6, Enum.FillDirection.Horizontal) })

	wallet = UI.label({
		Name = "Resources",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -104),
		Size = UDim2.fromOffset(0, 36),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.15,
		TextSize = 20,
		Visible = false,
		Parent = screen,
	})
	UI.corner(12).Parent = wallet
	UI.stroke(UI.Colors.Spark, 2).Parent = wallet
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), Parent = wallet })

	spectating = UI.label({
		Name = "Spectating",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -104),
		Size = UDim2.fromOffset(0, 40),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = UI.Colors.Bad,
		TextSize = 20,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "💀 You're out! Watching until the next match...",
		Visible = false,
		Parent = screen,
	})
	UI.corner(12).Parent = spectating
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), Parent = spectating })

	workspace:GetAttributeChangedSignal("MatchTeams"):Connect(refreshTeams)
	player.AttributeChanged:Connect(function(name)
		if name == "TeamKey" then
			refreshTeams()
			refreshBedPrompts()
		end
		refreshWallet()
	end)
	refreshTeams()
	refreshWallet()

	task.spawn(function()
		while true do
			refreshBanner()
			refreshBedPrompts()
			task.wait(0.25)
		end
	end)
end

return MatchHUD
