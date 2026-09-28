-- Global leaderboards in the lobby: the top 10 players in the world for
-- wins, knockouts and beds broken (saved in OrderedDataStores), plus avatar
-- statues of the top 3 winners. If the data stores can't be reached
-- (Studio without API access), the boards show this server's players instead.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Format)

local DataService = require(script.Parent.DataService)

local LeaderboardService = {}

type Board = {
	key: string,
	title: string,
	stat: string,
	store: OrderedDataStore?,
	position: Vector3,
	rows: { TextLabel },
}

local UPDATE_SECONDS = 120

local boards: { Board } = {
	{
		key = "Wins",
		title = "🏆 Most Bed Wars Wins",
		stat = "wins",
		position = Vector3.new(-60, 0, -110),
		rows = {},
	},
	{
		key = "Kills",
		title = "⚔️ Most Knockouts",
		stat = "kills",
		position = Vector3.new(0, 0, -116),
		rows = {},
	},
	{
		key = "Beds",
		title = "🛏️ Most Beds Broken",
		stat = "bedsBroken",
		position = Vector3.new(60, 0, -110),
		rows = {},
	},
}

local names: { [number]: string } = {}
local statueIds: { number } = {}
local folder: Folder

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

local function buildBoard(board: Board)
	local part = Instance.new("Part")
	part.Name = "Leaderboard_" .. board.key
	part.Anchored = true
	part.Size = Vector3.new(14, 17, 0.8)
	-- Faces the spawn (toward -Z).
	part.CFrame = CFrame.lookAt(board.position + Vector3.new(0, 10, 0), board.position + Vector3.new(0, 10, -10))
	part.Color = Color3.fromRGB(36, 40, 52)
	part.Material = Enum.Material.Slate
	part.Parent = folder
	for _, x in { -6, 6 } do
		local post = Instance.new("Part")
		post.Anchored = true
		post.Size = Vector3.new(0.8, 2, 0.8)
		post.CFrame = part.CFrame * CFrame.new(x, -9.5, 0)
		post.Color = Color3.fromRGB(70, 66, 62)
		post.Material = Enum.Material.Concrete
		post.Parent = part
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(420, 510)
	gui.LightInfluence = 0.2
	gui.Parent = part
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = gui
	local title = Instance.new("TextLabel")
	title.LayoutOrder = 0
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 56)
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 205, 90)
	title.Text = board.title
	title.Parent = gui
	for i = 1, 10 do
		local row = Instance.new("TextLabel")
		row.LayoutOrder = i
		row.BackgroundTransparency = if i % 2 == 0 then 1 else 0.85
		row.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		row.Size = UDim2.new(1, 0, 0, 40)
		row.Font = Enum.Font.GothamBold
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = if i == 1
			then Color3.fromRGB(255, 215, 80)
			elseif i == 2 then Color3.fromRGB(220, 225, 235)
			elseif i == 3 then Color3.fromRGB(215, 150, 90)
			else Color3.fromRGB(230, 235, 245)
		row.Text = ""
		row.Parent = gui
		table.insert(board.rows, row)
	end
end

local function buildPodium()
	local colors = { Color3.fromRGB(230, 190, 70), Color3.fromRGB(200, 205, 215), Color3.fromRGB(190, 125, 70) }
	local spots = { Vector3.new(0, 0, -88), Vector3.new(-11, 0, -86), Vector3.new(11, 0, -86) }
	for place = 1, 3 do
		local height = 4 - place
		local plinth = Instance.new("Part")
		plinth.Name = "Podium" .. place
		plinth.Anchored = true
		plinth.Size = Vector3.new(7, height + 1, 7)
		plinth.CFrame = CFrame.new(spots[place] + Vector3.new(0, (height + 1) / 2, 0))
		plinth.Color = colors[place]
		plinth.Material = Enum.Material.Marble
		plinth.Parent = folder
	end
end

-- Avatar statues of the top 3 (rebuilt only when the top 3 change).
local function updateStatues(userIds: { number })
	local same = #userIds == #statueIds
	for i, id in userIds do
		same = same and statueIds[i] == id
	end
	if same then
		return
	end
	statueIds = userIds
	for _, child in folder:GetChildren() do
		if child.Name == "Statue" then
			child:Destroy()
		end
	end
	for place, userId in userIds do
		if place > 3 then
			break
		end
		local plinth = folder:FindFirstChild("Podium" .. place) :: BasePart?
		local ok, model = pcall(function()
			return Players:CreateHumanoidModelFromUserId(userId)
		end)
		if ok and model and plinth then
			model.Name = "Statue"
			for _, item in model:GetDescendants() do
				if item:IsA("BasePart") then
					item.Anchored = true
					item.CanCollide = false
				end
			end
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.DisplayName = "#" .. place .. " " .. nameOf(userId)
				humanoid.NameDisplayDistance = 60
			end
			local top = plinth.Position + Vector3.new(0, plinth.Size.Y / 2 + 3, 0)
			model:PivotTo(CFrame.lookAt(top, top + Vector3.new(0, 0, -1)))
			model.Parent = folder
		end
	end
end

local function show(board: Board, entries: { { userId: number, value: number } })
	for i, row in board.rows do
		local entry = entries[i]
		row.Text = if entry
			then "  #" .. i .. "  " .. nameOf(entry.userId) .. "   " .. Format.number(entry.value)
			else ""
	end
end

-- This server's players, for when the data stores can't be reached.
local function localEntries(stat: string): { { userId: number, value: number } }
	local list = {}
	for _, player in Players:GetPlayers() do
		local data = DataService.get(player)
		if data then
			names[player.UserId] = player.Name
			table.insert(list, { userId = player.UserId, value = math.floor(data.stats[stat] or 0) })
		end
	end
	table.sort(list, function(a, b)
		return a.value > b.value
	end)
	return list
end

local function update()
	for _, board in boards do
		local store = board.store
		-- Save everyone's current value.
		if store then
			for _, player in Players:GetPlayers() do
				local data = DataService.get(player)
				if data then
					local value = math.floor(math.min(data.stats[board.stat] or 0, 2 ^ 53))
					pcall(function()
						store:SetAsync(tostring(player.UserId), value)
					end)
				end
			end
		end
		-- Read the world's top 10.
		local entries: { { userId: number, value: number } }? = nil
		if store then
			local ok, page = pcall(function()
				return store:GetSortedAsync(false, 10):GetCurrentPage()
			end)
			if ok and type(page) == "table" then
				local list = {}
				for _, item in page do
					table.insert(list, { userId = tonumber(item.key) or 0, value = item.value })
				end
				entries = list
			end
		end
		local shown = entries or localEntries(board.stat)
		show(board, shown)
		if board.key == "Wins" then
			local top = {}
			for i = 1, math.min(3, #shown) do
				table.insert(top, shown[i].userId)
			end
			task.spawn(updateStatues, top)
		end
	end
end

function LeaderboardService.init()
	folder = Instance.new("Folder")
	folder.Name = "Leaderboards"
	folder.Parent = workspace
	for _, board in boards do
		local ok, store = pcall(function()
			return DataStoreService:GetOrderedDataStore("Leaderboard_" .. board.key .. "_v1")
		end)
		board.store = if ok then store else nil
		buildBoard(board)
	end
	buildPodium()
end

function LeaderboardService.start()
	task.spawn(function()
		task.wait(10) -- let profiles load first
		while true do
			update()
			task.wait(UPDATE_SECONDS)
		end
	end)
end

return LeaderboardService
