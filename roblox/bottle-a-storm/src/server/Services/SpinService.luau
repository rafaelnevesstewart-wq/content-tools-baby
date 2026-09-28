-- The daily prize wheel (🎁 Rewards → Spin). One free spin a day; more with
-- the Robux "3 Wheel Spins" product. The server picks the prize, the client
-- spins the wheel to land on it, and the prize message pops up when it stops.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local RewardsData = require(Shared.RewardsData)
local SpinData = require(Shared.SpinData)

local Modules = script.Parent.Parent.Modules
local Notify = require(Modules.Notify)

local DailyService = require(script.Parent.DailyService)
local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local RewardService = require(script.Parent.RewardService)

local SpinService = {}

local rng = Random.new()
local spinning: { [Player]: boolean } = {}

local function pick(): number
	local total = 0
	for _, prize in SpinData.Prizes do
		total += prize.weight
	end
	local roll = rng:NextNumber(0, total)
	for index, prize in SpinData.Prizes do
		roll -= prize.weight
		if roll <= 0 then
			return index
		end
	end
	return 1
end

local function spin(player: Player): (boolean, any)
	local data = DataService.get(player)
	if not data or spinning[player] then
		return false, "The wheel is still spinning!"
	end
	local today = RewardsData.today(os.time())
	if data.spin.day < today then
		data.spin.day = today
	elseif data.spin.extra > 0 then
		data.spin.extra -= 1
	else
		return false, "No spins left. Come back tomorrow, or get more spins!"
	end
	local index = pick()
	local prize = SpinData.Prizes[index]
	-- Give it now (so nothing is lost), but announce it when the wheel stops.
	local problem = RewardService.grant(player, prize.reward, nil, true)
	if problem then
		-- Couldn't give it (it shouldn't happen): pay Sparks instead.
		RewardService.grant(player, { kind = "sparks", amount = 1000 }, nil, true)
	end
	IncomeService.sync(player)
	DailyService.sync(player)
	spinning[player] = true
	task.delay(SpinData.SpinSeconds + 0.3, function()
		spinning[player] = nil
		if player.Parent then
			local text = if problem
				then "🎡 You won " .. prize.label .. ", but something went wrong, so you got ⚡1,000 instead!"
				else "🎡 You won " .. prize.label .. "!"
			Notify.player(player, text, if prize.weight <= 5 then "rare" else "success")
		end
	end)
	return true, index
end

-- The Robux product: 3 extra spins.
function SpinService.addSpins(player: Player, count: number): boolean
	local data = DataService.get(player)
	if not data then
		return false
	end
	data.spin.extra += count
	DailyService.sync(player)
	Notify.player(player, "🎡 +" .. count .. " wheel spins! Open 🎁 Rewards → Spin.", "success")
	return true
end

function SpinService.start()
	Remotes.func("Spin").OnServerInvoke = spin
	Players.PlayerRemoving:Connect(function(player)
		spinning[player] = nil
	end)
end

return SpinService
