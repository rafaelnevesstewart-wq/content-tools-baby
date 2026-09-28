-- 🏅 The monthly season: Season Points from matches this month
-- (MonthlyData.Points), a board in the castle with the world's top 10 (an
-- OrderedDataStore per month) and your own rank, and prizes for the top 100
-- when the month is over. Prizes are handed out the next time you join (or
-- right away if you're online when the month changes).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local CustomData = require(Shared.CustomData)
local Format = require(Shared.Format)
local MonthlyData = require(Shared.MonthlyData)

local Modules = script.Parent.Parent.Modules
local Juice = require(Modules.Juice)
local Notify = require(Modules.Notify)
local WorldBuilder = require(Modules.WorldBuilder)

local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local MatchService = require(script.Parent.MatchService)
local RewardService = require(script.Parent.RewardService)

local MonthlyService = {}

local UPDATE_SECONDS = 120
local stores: { [string]: OrderedDataStore } = {}
local names: { [number]: string } = {}
local rows: { TextLabel } = {}
local titleLabel: TextLabel
local footLabel: TextLabel

local function storeFor(month: string): OrderedDataStore?
	if stores[month] then
		return stores[month]
	end
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore("Monthly_" .. month)
	end)
	if ok and store then
		stores[month] = store
		return store
	end
	return nil
end

local function monthlyOf(data: any): any
	data.monthly = data.monthly or { month = "", points = 0, paid = "" }
	return data.monthly
end

local function nameOf(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	names[userId] = if ok and name then name else "Player"
	return names[userId]
end

-- Your rank in a month's store (nil if not in the top 100 or unreachable).
local function rankIn(month: string, userId: number): number?
	local store = storeFor(month)
	if not store then
		return nil
	end
	local ok, page = pcall(function()
		return store:GetSortedAsync(false, 100):GetCurrentPage()
	end)
	if not ok or type(page) ~= "table" then
		return nil
	end
	for index, item in page do
		if tonumber(item.key) == userId then
			return index
		end
	end
	return nil
end

-- A month ended since you last played it: give its prize, then start fresh.
local function rollOver(player: Player, data: any)
	local monthly = monthlyOf(data)
	local now = MonthlyData.key(os.time())
	if monthly.month == now then
		return
	end
	local old, points = monthly.month, monthly.points
	monthly.month = now
	monthly.points = 0
	if old == "" or points <= 0 or monthly.paid == old then
		return
	end
	monthly.paid = old
	local rank = rankIn(old, player.UserId)
	local prize = if rank then MonthlyData.prizeFor(rank) else nil
	if prize then
		data.sparks += prize.sparks
		IncomeService.sync(player)
		local kit = MonthlyData.kitReward(prize)
		if kit then
			RewardService.grant(player, kit)
		end
		if prize.title == "MonthlyChampion" then
			data.stats.monthlyChampion = (data.stats.monthlyChampion or 0) + 1
		end
		if prize.title then
			data.stats.monthlyTop10 = (data.stats.monthlyTop10 or 0) + 1
		end
		Notify.player(
			player,
			"🏅 Last month you finished #"
				.. (rank :: number)
				.. "! Your prize: ⚡"
				.. Format.number(prize.sparks)
				.. (if kit then " and a kit" else "")
				.. "!",
			"rare"
		)
		Juice.sound(player, "win")
	else
		data.sparks += MonthlyData.ThanksSparks
		IncomeService.sync(player)
		Notify.player(
			player,
			"🏅 Thanks for playing last month's season! +⚡"
				.. MonthlyData.ThanksSparks
				.. ". A new season has started!",
			"success"
		)
	end
end

local function addPoints(player: Player, amount: number)
	local data = DataService.get(player)
	-- (Private servers with their own rules don't count toward the season.)
	if not data or CustomData.changed() then
		return
	end
	rollOver(player, data)
	local monthly = monthlyOf(data)
	monthly.points += amount
	player:SetAttribute("MonthlyPoints", monthly.points)
end

local function build()
	local frame = WorldBuilder.LobbySpots.monthly
	local part = Instance.new("Part")
	part.Name = "MonthlyBoard"
	part.Anchored = true
	part.Size = Vector3.new(12, 16, 0.8)
	part.CFrame = frame * CFrame.new(0, 10, 0)
	part.Color = Color3.fromRGB(46, 36, 70)
	part.Material = Enum.Material.Slate
	part.Parent = workspace
	for _, x in { -5, 5 } do
		local post = Instance.new("Part")
		post.Anchored = true
		post.Size = Vector3.new(0.8, 2, 0.8)
		post.CFrame = part.CFrame * CFrame.new(x, -9, 0)
		post.Color = Color3.fromRGB(230, 190, 70)
		post.Material = Enum.Material.Marble
		post.Parent = part
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(360, 480)
	gui.LightInfluence = 0.2
	gui.Parent = part
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 3)
	layout.Parent = gui
	local function line(order: number, height: number, color: Color3): TextLabel
		local label = Instance.new("TextLabel")
		label.LayoutOrder = order
		label.BackgroundTransparency = if order % 2 == 0 then 1 else 0.88
		label.BackgroundColor3 = Color3.new(1, 1, 1)
		label.Size = UDim2.new(1, 0, 0, height)
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextColor3 = color
		label.Text = ""
		label.Parent = gui
		return label
	end
	titleLabel = line(0, 50, Color3.fromRGB(255, 205, 90))
	for i = 1, 10 do
		local row = line(i, 32, if i <= 3 then Color3.fromRGB(255, 225, 140) else Color3.fromRGB(230, 235, 245))
		row.TextXAlignment = Enum.TextXAlignment.Left
		table.insert(rows, row)
	end
	footLabel = line(20, 60, Color3.fromRGB(190, 200, 230))
	footLabel.TextWrapped = true
end

local function update()
	local now = os.time()
	local month = MonthlyData.key(now)
	local store = storeFor(month)
	for _, player in Players:GetPlayers() do
		local data = DataService.get(player)
		if data then
			rollOver(player, data)
			local monthly = monthlyOf(data)
			player:SetAttribute("MonthlyPoints", monthly.points)
			if store and monthly.points > 0 then
				pcall(function()
					store:SetAsync(tostring(player.UserId), math.floor(monthly.points))
				end)
			end
		end
	end
	local entries = {}
	local ok, page = false, nil
	if store then
		ok, page = pcall(function()
			return store:GetSortedAsync(false, 10):GetCurrentPage()
		end)
	end
	if ok and type(page) == "table" then
		for _, item in page do
			table.insert(entries, { userId = tonumber(item.key) or 0, value = item.value })
		end
	else
		-- No data stores (Studio): this server's players.
		for _, player in Players:GetPlayers() do
			local data = DataService.get(player)
			if data and monthlyOf(data).points > 0 then
				names[player.UserId] = player.Name
				table.insert(entries, { userId = player.UserId, value = monthlyOf(data).points })
			end
		end
		table.sort(entries, function(a, b)
			return a.value > b.value
		end)
	end
	titleLabel.Text = "🏅 " .. MonthlyData.name(now) .. " Season"
	for i, row in rows do
		local entry = entries[i]
		row.Text = if entry
			then "  #" .. i .. "  " .. nameOf(entry.userId) .. "   " .. Format.number(entry.value)
			else ""
	end
	local days = math.floor(MonthlyData.secondsLeft(now) / 86400)
	footLabel.Text = "Ends in "
		.. (if days >= 1 then days .. " days" else "less than a day")
		.. ". Top 100 win prizes! #1 gets ⚡25,000 + a Legendary kit"
end

function MonthlyService.start()
	build()
	MatchService.Played:Connect(function(player)
		addPoints(player, MonthlyData.Points.Played)
	end)
	MatchService.Won:Connect(function(player)
		addPoints(player, MonthlyData.Points.Won)
	end)
	MatchService.Killed:Connect(function(killer, _victim, final)
		if killer then
			addPoints(killer, MonthlyData.Points.Kill + (if final then MonthlyData.Points.FinalKill else 0))
		end
	end)
	MatchService.BotKilled:Connect(function(killer, final)
		addPoints(killer, MonthlyData.Points.Kill + (if final then MonthlyData.Points.FinalKill else 0))
	end)
	MatchService.BedBroken:Connect(function(breaker)
		if typeof(breaker) == "Instance" and breaker:IsA("Player") then
			addPoints(breaker, MonthlyData.Points.Bed)
		end
	end)
	DataService.ProfileLoaded:Connect(function(player, data)
		task.spawn(function()
			rollOver(player, data)
			player:SetAttribute("MonthlyPoints", monthlyOf(data).points)
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		local data = DataService.get(player)
		local store = storeFor(MonthlyData.key(os.time()))
		if data and store and monthlyOf(data).points > 0 then
			pcall(function()
				store:SetAsync(tostring(player.UserId), math.floor(monthlyOf(data).points))
			end)
		end
	end)
	task.spawn(function()
		task.wait(12)
		while true do
			update()
			task.wait(UPDATE_SECONDS)
		end
	end)
end

return MonthlyService
