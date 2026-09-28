-- Holiday events (see HolidayData): on their dates, every Bed Wars match
-- earns the event currency, the lobby gets themed decorations, and the event
-- shop sells the event's exclusive kits.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local HolidayData = require(Shared.HolidayData)
local Remotes = require(Shared.Remotes)
local StormData = require(Shared.StormData)

local Modules = script.Parent.Parent.Modules
local Juice = require(Modules.Juice)
local Notify = require(Modules.Notify)
local WorldBuilder = require(Modules.WorldBuilder)

local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local MatchService = require(script.Parent.MatchService)
local RewardService = require(script.Parent.RewardService)

local HolidayService = {}

local current: HolidayData.Holiday? = nil
local currentKey: string? = nil
local decorFolder: Folder? = nil
local lastBuy: { [Player]: number } = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function piece(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

local function oval(parent: Instance, size: Vector3, color: Color3, cframe: CFrame, material: Enum.Material): Part
	local p = piece(parent, { Size = size, Color = color, CFrame = cframe, Material = material })
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

local DECOR: { [string]: (Instance, CFrame) -> () } = {
	-- Carved pumpkins that glow at night.
	pumpkins = function(parent, at)
		local size = 2.2 + math.random() * 1.2
		local body = at * CFrame.new(0, size * 0.4, 0)
		for i = 0, 5 do
			oval(
				parent,
				Vector3.new(size * 0.55, size * 0.8, size),
				rgb(214, 112, 30),
				body * CFrame.Angles(0, i * math.pi / 6, 0),
				Enum.Material.SmoothPlastic
			)
		end
		piece(parent, {
			Size = Vector3.new(0.3, 0.7, 0.3),
			Color = rgb(90, 110, 50),
			Material = Enum.Material.Wood,
			CFrame = body * CFrame.new(0, size * 0.45, 0),
		})
		for _, side in { -1, 1 } do
			piece(parent, {
				Size = Vector3.new(size * 0.18, size * 0.15, 0.1),
				Color = rgb(255, 200, 80),
				Material = Enum.Material.Neon,
				CFrame = body * CFrame.new(side * size * 0.18, size * 0.1, -size * 0.49),
			})
		end
		local mouth = piece(parent, {
			Size = Vector3.new(size * 0.45, size * 0.1, 0.1),
			Color = rgb(255, 200, 80),
			Material = Enum.Material.Neon,
			CFrame = body * CFrame.new(0, -size * 0.12, -size * 0.49),
		})
		local light = Instance.new("PointLight")
		light.Color = rgb(255, 170, 70)
		light.Range = 10
		light.Brightness = 1.2
		light.Parent = mouth
	end,
	-- Snowmen with coal eyes and a carrot nose.
	snowmen = function(parent, at)
		local snow = rgb(245, 248, 252)
		piece(parent, {
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 3.2,
			Color = snow,
			Material = Enum.Material.Snow,
			CFrame = at * CFrame.new(0, 1.5, 0),
		})
		piece(parent, {
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 2.4,
			Color = snow,
			Material = Enum.Material.Snow,
			CFrame = at * CFrame.new(0, 3.9, 0),
		})
		local head = at * CFrame.new(0, 5.7, 0)
		piece(parent, {
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 1.7,
			Color = snow,
			Material = Enum.Material.Snow,
			CFrame = head,
		})
		for _, side in { -1, 1 } do
			piece(parent, {
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 0.22,
				Color = rgb(25, 25, 28),
				Material = Enum.Material.Slate,
				CFrame = head * CFrame.new(side * 0.3, 0.2, -0.78),
			})
		end
		piece(parent, {
			Size = Vector3.new(0.2, 0.2, 0.8),
			Color = rgb(235, 120, 40),
			Material = Enum.Material.SmoothPlastic,
			CFrame = head * CFrame.new(0, 0, -1.1),
		})
		piece(parent, {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.35, 1.9, 1.9),
			Color = rgb(170, 40, 45),
			Material = Enum.Material.Fabric,
			CFrame = at * CFrame.new(0, 4.95, 0) * CFrame.Angles(0, 0, math.rad(90)),
		})
	end,
	-- Striped beach umbrellas with towels.
	umbrellas = function(parent, at)
		piece(parent, {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(6, 0.25, 0.25),
			Color = rgb(235, 235, 230),
			Material = Enum.Material.Metal,
			CFrame = at * CFrame.new(0, 3, 0) * CFrame.Angles(0, 0, math.rad(90)),
		})
		local colors = { rgb(230, 70, 70), rgb(245, 245, 240) }
		for i = 0, 7 do
			piece(parent, {
				Size = Vector3.new(0.1, 0.5, 3.2),
				Color = colors[i % 2 + 1],
				Material = Enum.Material.Fabric,
				CFrame = at
					* CFrame.new(0, 6, 0)
					* CFrame.Angles(0, i * math.pi / 4, 0)
					* CFrame.new(0, -0.6, 1.4)
					* CFrame.Angles(math.rad(25), 0, 0),
			})
		end
		piece(parent, {
			Size = Vector3.new(2.2, 0.08, 4),
			Color = rgb(70, 160, 220),
			Material = Enum.Material.Fabric,
			CFrame = at * CFrame.new(2.5, 0.05, 0),
		})
	end,
}

local function removeDecor()
	if decorFolder then
		decorFolder:Destroy()
		decorFolder = nil
	end
end

local function buildDecor(holiday: HolidayData.Holiday)
	removeDecor()
	local build = DECOR[holiday.decor]
	if not build then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "HolidayDecor"
	local placed, tries = 0, 0
	local random = Random.new(7)
	while placed < 18 and tries < 400 do
		tries += 1
		local angle = random:NextNumber(0, math.pi * 2)
		local radius = random:NextNumber(20, Config.Lobby.Radius - 8)
		local spot = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		if not WorldBuilder.isLobbyBlocked(spot) then
			placed += 1
			build(
				folder,
				CFrame.new(Config.Lobby.Center + spot) * CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0)
			)
		end
	end
	folder.Parent = workspace
	decorFolder = folder
end

-- The player's event currency, reset for each year's event.
local function pointsOf(data: any): number
	if data.holiday.key ~= currentKey then
		data.holiday = { key = currentKey or "", points = 0 }
	end
	return data.holiday.points
end

local function sync(player: Player)
	local data = DataService.get(player)
	if data and current then
		player:SetAttribute("HolidayPoints", pointsOf(data))
	else
		player:SetAttribute("HolidayPoints", nil)
	end
end

local function refresh()
	local studioKey = Config.Holiday.StudioEvent
	local holiday, key
	if RunService:IsStudio() and studioKey then
		holiday, key = HolidayData.get(studioKey), "Studio" .. tostring(studioKey)
	else
		holiday, key = HolidayData.active(os.time())
	end
	if key == currentKey then
		return
	end
	current, currentKey = holiday, key
	if holiday then
		buildDecor(holiday)
		workspace:SetAttribute("Holiday", holiday.key)
		workspace:SetAttribute("HolidayEndsAt", HolidayData.endsAt(os.time(), holiday))
		Notify.all(
			holiday.emoji
				.. " "
				.. string.upper(holiday.name)
				.. " has started! Play Bed Wars for "
				.. holiday.currencyEmoji
				.. " "
				.. holiday.currency
				.. " and spend it in 🏪 Market → Event.",
			"rare"
		)
	else
		removeDecor()
		workspace:SetAttribute("Holiday", nil)
		workspace:SetAttribute("HolidayEndsAt", nil)
	end
	for _, player in Players:GetPlayers() do
		sync(player)
	end
end

local function getHoliday(player: Player)
	local data = DataService.get(player)
	local holiday = current
	if not data or not holiday then
		return nil
	end
	local shop = {}
	for _, item in holiday.shop do
		table.insert(shop, { label = item.label, cost = item.cost, stormId = item.stormId })
	end
	return {
		key = holiday.key,
		name = holiday.name,
		emoji = holiday.emoji,
		currency = holiday.currency,
		currencyEmoji = holiday.currencyEmoji,
		endsAt = workspace:GetAttribute("HolidayEndsAt"),
		points = pointsOf(data),
		shop = shop,
	}
end

local function buy(player: Player, index: any): (boolean, string)
	local data = DataService.get(player)
	local holiday = current
	if not data or not holiday or type(index) ~= "number" then
		return false, "The event is over."
	end
	if os.clock() - (lastBuy[player] or 0) < 0.4 then
		return false, "Slow down!"
	end
	lastBuy[player] = os.clock()
	local item = holiday.shop[index]
	if not item then
		return false, "Unknown item."
	end
	local points = pointsOf(data)
	if points < item.cost then
		return false,
			"You need " .. item.cost - points .. " more " .. holiday.currencyEmoji .. " " .. holiday.currency .. "."
	end
	local problem
	local def = item.stormId and StormData.get(item.stormId)
	if def then
		problem = RewardService.giveKit(player, def, nil)
	elseif item.reward then
		problem = RewardService.grant(player, item.reward :: any, nil)
	end
	if problem then
		return false, problem
	end
	data.holiday.points -= item.cost
	sync(player)
	IncomeService.sync(player)
	return true, holiday.emoji .. " Bought " .. item.label .. "!"
end

function HolidayService.start()
	Remotes.func("GetHoliday").OnServerInvoke = getHoliday
	Remotes.func("BuyHoliday").OnServerInvoke = buy
	DataService.ProfileLoaded:Connect(sync)
	Players.PlayerRemoving:Connect(function(player)
		lastBuy[player] = nil
	end)

	local function earn(player: Player, gain: number)
		local holiday = current
		local data = DataService.get(player)
		if not holiday or not data then
			return
		end
		pointsOf(data)
		data.holiday.points += gain
		sync(player)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			Juice.float(player, "+" .. gain .. " " .. holiday.currencyEmoji, root.Position + Vector3.new(0, 4, 0))
		end
	end
	local points = HolidayData.Points
	MatchService.Killed:Connect(function(killer, _victim, final)
		earn(killer, if final then points.FinalKill else points.Kill)
	end)
	MatchService.BedBroken:Connect(function(breaker)
		earn(breaker, points.Bed)
	end)
	MatchService.Won:Connect(function(player)
		earn(player, points.Win)
	end)
	MatchService.Played:Connect(function(player)
		earn(player, points.Played)
	end)

	refresh()
	task.spawn(function()
		while true do
			task.wait(30)
			refresh()
		end
	end)
end

return HolidayService
