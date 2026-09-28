-- 🌟 The Hall of Legends (outside the castle, back left): a marble hall with
-- statues of the best players of all time (the #1 in the world for wins,
-- knockouts, beds broken and rank, from the leaderboards' data stores) and a
-- wall of plaques for every 🏅 Monthly Champion (saved in a data store when
-- a month ends). Without data stores (Studio) it shows this server's best.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local MonthlyData = require(Shared.MonthlyData)

local DataService = require(script.Parent.DataService)

local LegendsService = {}

local UPDATE_SECONDS = 600
local CENTER = Config.Lobby.Center + Vector3.new(-58, 0, -50)
local FACING = Vector3.new(0, 0, 1) -- the open side faces the path to Base Island

type Category = { key: string, title: string, stat: string, userId: number? }

local categories: { Category } = {
	{ key = "Wins", title = "🏆 Most Wins", stat = "wins" },
	{ key = "Kills", title = "⚔️ Most Knockouts", stat = "kills" },
	{ key = "Beds", title = "🛏️ Most Beds", stat = "bedsBroken" },
	{ key = "Ranked", title = "👑 Top Ranked", stat = "rankPoints" },
}

local hall: Model
local frame: CFrame
local captions: { [string]: TextLabel } = {}
local plaqueText: TextLabel
local champions: DataStore? = nil

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = hall
	return p
end

local function textOn(target: BasePart, canvas: Vector2, color: Color3): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = canvas
	gui.Parent = target
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextWrapped = true
	label.TextColor3 = color
	label.Text = ""
	label.Parent = gui
	return label
end

local function build()
	hall = Instance.new("Model")
	hall.Name = "HallOfLegends"
	frame = CFrame.lookAt(CENTER, CENTER + FACING)
	local marble = Color3.fromRGB(236, 232, 224)
	local gold = Color3.fromRGB(230, 190, 80)
	-- Floor, back wall, side walls, roof and columns along the open front.
	part({
		Size = Vector3.new(20, 0.6, 13),
		CFrame = frame * CFrame.new(0, 0.3, 0),
		Color = marble,
		Material = Enum.Material.Marble,
	})
	part({
		Size = Vector3.new(20, 10, 0.8),
		CFrame = frame * CFrame.new(0, 5, 6.2),
		Color = marble,
		Material = Enum.Material.Marble,
	})
	for _, x in { -9.6, 9.6 } do
		part({
			Size = Vector3.new(0.8, 10, 13),
			CFrame = frame * CFrame.new(x, 5, 0),
			Color = marble,
			Material = Enum.Material.Marble,
		})
	end
	part({
		Size = Vector3.new(21, 0.8, 14),
		CFrame = frame * CFrame.new(0, 10.4, 0),
		Color = marble,
		Material = Enum.Material.Marble,
	})
	part({
		Size = Vector3.new(21.2, 0.4, 14.2),
		CFrame = frame * CFrame.new(0, 10.9, 0),
		Color = gold,
		Material = Enum.Material.Foil,
	})
	for _, x in { -6, -2, 2, 6 } do
		part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(9.8, 1.2, 1.2),
			CFrame = frame * CFrame.new(x, 5.2, -6) * CFrame.Angles(0, 0, math.rad(90)),
			Color = marble,
			Material = Enum.Material.Marble,
		})
	end
	-- The name over the entrance (on the roof's front edge).
	local banner = part({
		Size = Vector3.new(14, 1.8, 0.3),
		CFrame = frame * CFrame.new(0, 12, -6.9),
		Color = Color3.fromRGB(60, 40, 70),
		Material = Enum.Material.SmoothPlastic,
	})
	textOn(banner, Vector2.new(560, 72), gold).Text = "🌟 Hall of Legends"
	-- Four plinths along the back wall, each with its title.
	for index, category in categories do
		local x = -7.5 + (index - 1) * 5
		local plinth = part({
			Name = "Plinth" .. category.key,
			Size = Vector3.new(3.6, 2, 3.6),
			CFrame = frame * CFrame.new(x, 1.6, 3),
			Color = gold,
			Material = Enum.Material.Marble,
		})
		local sign = part({
			Size = Vector3.new(3.6, 1.2, 0.2),
			CFrame = frame * CFrame.new(x, 1.4, 1.1),
			Color = Color3.fromRGB(40, 30, 24),
			Material = Enum.Material.SmoothPlastic,
		})
		captions[category.key] = textOn(sign, Vector2.new(240, 80), Color3.fromRGB(255, 230, 150))
		captions[category.key].Text = category.title
		plinth:SetAttribute("Category", category.key)
	end
	-- The Monthly Champions wall (inside, on the left wall).
	local plaque = part({
		Size = Vector3.new(9, 6, 0.2),
		CFrame = frame * CFrame.new(-9.1, 5, -0.5) * CFrame.Angles(0, math.rad(-90), 0),
		Color = Color3.fromRGB(60, 40, 70),
		Material = Enum.Material.SmoothPlastic,
	})
	plaqueText = textOn(plaque, Vector2.new(360, 240), Color3.fromRGB(255, 220, 140))
	plaqueText.Text = "🏅 Monthly Champions\n(the first one is crowned when this month ends)"
	hall.Parent = workspace
end

-- The world's #1 for a category (or this server's best).
local function topOf(category: Category): (number?, number)
	local ok, page = pcall(function()
		local store = DataStoreService:GetOrderedDataStore("Leaderboard_" .. category.key .. "_v1")
		return store:GetSortedAsync(false, 1):GetCurrentPage()
	end)
	if ok and type(page) == "table" and page[1] then
		return tonumber(page[1].key), page[1].value
	end
	local best, bestValue = nil, 0
	for _, player in Players:GetPlayers() do
		local data = DataService.get(player)
		local value = data and data.stats[category.stat] or 0
		if value > bestValue then
			best, bestValue = player.UserId, value
		end
	end
	return best, bestValue
end

local function nameOf(userId: number): string
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	return if ok and name then name else "Player"
end

local function statue(category: Category, userId: number)
	local plinth = hall:FindFirstChild("Plinth" .. category.key) :: BasePart?
	local old = hall:FindFirstChild("Statue" .. category.key)
	if old then
		old:Destroy()
	end
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromUserId(userId)
	end)
	if not ok or not model or not plinth then
		return
	end
	model.Name = "Statue" .. category.key
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			-- Golden statues.
			item.Color = Color3.fromRGB(230, 190, 80)
			item.Material = Enum.Material.Foil
		elseif item:IsA("Decal") then
			item.Color3 = Color3.fromRGB(230, 190, 80)
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayName = category.title .. ": " .. nameOf(userId)
		humanoid.NameDisplayDistance = 40
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end
	local top = plinth.Position + Vector3.new(0, plinth.Size.Y / 2 + 3, 0)
	model:PivotTo(CFrame.lookAt(top, top + frame.LookVector)) -- facing out of the hall
	model.Parent = hall
end

-- When a month is over, crown its #1 on the champions wall (once).
local function crownLastMonth(list: { any }): { any }
	local now = os.time()
	local date = os.date("!*t", now) :: any
	local intoMonth = (date.day - 1) * 86400 + date.hour * 3600 + date.min * 60 + date.sec
	local lastMonth = now - intoMonth - 3600
	local key = MonthlyData.key(lastMonth)
	for _, entry in list do
		if entry.month == key then
			return list
		end
	end
	local ok, page = pcall(function()
		return DataStoreService:GetOrderedDataStore("Monthly_" .. key):GetSortedAsync(false, 1):GetCurrentPage()
	end)
	if not ok or type(page) ~= "table" or not page[1] then
		return list
	end
	local userId = tonumber(page[1].key) or 0
	local entry = {
		month = key,
		label = MonthlyData.name(lastMonth) .. " " .. string.sub(key, 1, 4),
		name = nameOf(userId),
		points = page[1].value,
	}
	local store = champions
	if not store then
		return list
	end
	local saved, updated = pcall(function()
		return store:UpdateAsync("list", function(old)
			local current = if type(old) == "table" then old else {}
			for _, existing in current do
				if existing.month == key then
					return current
				end
			end
			table.insert(current, 1, entry)
			return current
		end)
	end)
	return if saved and type(updated) == "table" then updated else list
end

local function update()
	for _, category in categories do
		local userId, value = topOf(category)
		if userId and userId ~= category.userId then
			category.userId = userId
			statue(category, userId)
		end
		if userId then
			captions[category.key].Text = category.title .. "\n" .. nameOf(userId) .. " · " .. Format.number(value)
		end
	end
	local store = champions
	if store then
		local ok, list = pcall(function()
			return store:GetAsync("list")
		end)
		local current = if ok and type(list) == "table" then list else {}
		current = crownLastMonth(current)
		if #current > 0 then
			local lines = { "🏅 Monthly Champions" }
			for index, entry in current do
				if index > 8 then
					break
				end
				table.insert(
					lines,
					"🥇 " .. entry.label .. ": " .. entry.name .. " (" .. Format.number(entry.points) .. ")"
				)
			end
			plaqueText.Text = table.concat(lines, "\n")
		end
	end
end

function LegendsService.start()
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore("MonthlyChampions_v1")
	end)
	champions = if ok then store else nil
	build()
	task.spawn(function()
		task.wait(15)
		while true do
			pcall(update)
			task.wait(UPDATE_SECONDS)
		end
	end)
end

return LegendsService
