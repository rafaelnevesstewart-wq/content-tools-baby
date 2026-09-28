-- 🎯 Bounties: knock out 3 in a row without going down and a bounty goes on
-- your head (a 🎯 sign over you that everyone can see). It grows with every
-- knockout. Whoever knocks you out claims it: Sparks and Silver. Going down
-- any other way just clears it.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Format)

local Modules = script.Parent.Parent.Modules
local Juice = require(Modules.Juice)
local Notify = require(Modules.Notify)

local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local MatchService = require(script.Parent.MatchService)

local BountyService = {}

local START_AT = 3 -- knockouts in a row
local BASE_SPARKS = 150
local SPARKS_PER_KNOCKOUT = 75

local streaks: { [Player]: number } = {}

local function valueOf(streak: number): number
	return if streak >= START_AT then BASE_SPARKS + (streak - START_AT) * SPARKS_PER_KNOCKOUT else 0
end

local function showSign(player: Player, value: number)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local gui = head:FindFirstChild("BountySign") :: BillboardGui?
	if value <= 0 then
		if gui then
			gui:Destroy()
		end
		return
	end
	if not gui then
		local new = Instance.new("BillboardGui")
		new.Name = "BountySign"
		new.Size = UDim2.fromOffset(180, 44)
		new.StudsOffset = Vector3.new(0, 3.6, 0)
		new.AlwaysOnTop = true
		new.MaxDistance = 160
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.BackgroundColor3 = Color3.fromRGB(170, 30, 30)
		label.BackgroundTransparency = 0.15
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(255, 230, 120)
		label.Parent = new
		local corner = Instance.new("UICorner")
		corner.Parent = label
		new.Parent = head
		gui = new
	end
	local label = (gui :: BillboardGui):FindFirstChild("Text") :: TextLabel?
	if label then
		label.Text = "🎯 BOUNTY ⚡" .. Format.number(value)
	end
end

local function set(player: Player, streak: number)
	if streak > 0 then
		streaks[player] = streak
	else
		streaks[player] = nil
	end
	local value = valueOf(streak)
	player:SetAttribute("Bounty", if value > 0 then value else nil)
	showSign(player, value)
end

local function onKnockout(killer: Player)
	if not MatchService.isPlaying(killer) then
		return
	end
	local streak = (streaks[killer] or 0) + 1
	set(killer, streak)
	if streak == START_AT then
		Notify.all(
			"🎯 " .. killer.DisplayName .. " is on a roll! A bounty of ⚡" .. valueOf(streak) .. " is on their head!",
			"rare"
		)
	elseif streak > START_AT and (streak - START_AT) % 2 == 0 then
		Notify.all(
			"🎯 " .. killer.DisplayName .. "'s bounty is up to ⚡" .. Format.number(valueOf(streak)) .. "!",
			"warn"
		)
	end
end

function BountyService.start()
	MatchService.Killed:Connect(function(killer, victim)
		local value = valueOf(streaks[victim] or 0)
		if value > 0 and killer ~= victim and killer.Parent then
			IncomeService.addSparks(killer, value)
			MatchService.addResource(killer, "Silver", math.floor(value / 50))
			local data = DataService.get(killer)
			if data then
				data.stats.bountiesClaimed = (data.stats.bountiesClaimed or 0) + 1
			end
			Juice.sound(killer, "win")
			Notify.all(
				"🎯 "
					.. killer.DisplayName
					.. " claimed "
					.. victim.DisplayName
					.. "'s bounty of ⚡"
					.. Format.number(value)
					.. "!",
				"rare"
			)
		end
		onKnockout(killer)
	end)
	MatchService.BotKilled:Connect(onKnockout)
	MatchService.Died:Connect(function(player)
		set(player, 0)
	end)
	MatchService.MatchEnded:Connect(function()
		for player in streaks do
			set(player, 0)
		end
		streaks = {}
	end)
	Players.PlayerRemoving:Connect(function(player)
		streaks[player] = nil
	end)
end

return BountyService
