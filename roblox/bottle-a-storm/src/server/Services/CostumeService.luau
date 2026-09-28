-- 🎭 Costume parties in the lobby (taking turns with the other lobby events,
-- LobbyEventService): a theme is picked and everyone has a few minutes to
-- dress up (🎨 Style: hats, trails, auras...) and get on the stage at the end
-- of 🛍️ Shop Street. Everyone on the stage when time's up is in; then players
-- vote 1-5 stars on each costume (the 🎭 window's 👀 Look takes you next to
-- them). The best average wins Sparks and counts toward the 🎭 Fashion Star
-- title.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent.Parent.Modules
local Juice = require(Modules.Juice)
local Notify = require(Modules.Notify)
local Usage = require(Modules.Usage)

local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)

local CostumeService = {}

local DRESS_SECONDS = 3 * 60
local VOTE_SECONDS = 90
local PRIZES = { 1500, 800, 400 }
local ENTRY_SPARKS = 150
local VOTER_SPARKS = 40
local THEMES = {
	"👻 Spooky",
	"👑 Royal",
	"🏴‍☠️ Pirate",
	"🌈 Super colorful",
	"🤖 Robot",
	"🧙 Wizard",
	"🦸 Superhero",
	"❄️ Winter",
	"🌪️ Stormy",
	"🌸 Spring",
	"🖤 All dark",
	"✨ Sparkly",
}

local STREET = Config.Lobby.Center + Vector3.new(0, 0, -Config.Lobby.StreetDistance)
local STAGE = STREET + Vector3.new(0, 0, -44) -- the stage's middle, at the ground
local STAGE_SIZE = Vector3.new(12, 1.2, 6)

type Entry = { player: Player, name: string }

local phase = "break"
local theme = ""
local endsAt = 0
local entries: { [number]: Entry } = {}
local votes: { [number]: { [number]: number } } = {}
local lastAction: { [Player]: number } = {}

local function publish()
	workspace:SetAttribute("Costume", HttpService:JSONEncode({ phase = phase, theme = theme, endsAt = endsAt }))
end

local function pay(player: Player, amount: number)
	if player.Parent then
		IncomeService.addSparks(player, amount)
	end
end

local function onStage(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or player:GetAttribute("InMatch") then
		return false
	end
	local offset = root.Position - STAGE
	return math.abs(offset.X) <= STAGE_SIZE.X / 2 + 1
		and math.abs(offset.Z) <= STAGE_SIZE.Z / 2 + 1
		and offset.Y > -1
		and offset.Y < 10
end

-- Waits `seconds`, or less if an admin skips ahead (🧪 Test).
local skipping = false
local function waitPhase(seconds: number)
	local ends = os.clock() + seconds
	skipping = false
	while os.clock() < ends and not skipping do
		task.wait(0.5)
	end
	skipping = false
end

-- Ends the current phase early (admins, for testing).
function CostumeService.skip()
	skipping = true
end

local function tally()
	local results = {}
	for userId, entry in entries do
		local sum, count = 0, 0
		for _, given in votes do
			local stars = given[userId]
			if stars then
				sum += stars
				count += 1
			end
		end
		table.insert(results, { entry = entry, average = if count > 0 then sum / count else 0, count = count })
		pay(entry.player, ENTRY_SPARKS)
	end
	table.sort(results, function(a, b)
		if a.average ~= b.average then
			return a.average > b.average
		end
		return a.count > b.count
	end)
	local lines = {}
	for place, result in results do
		local prize = PRIZES[place]
		if not prize or result.count == 0 then
			break
		end
		local player = result.entry.player
		pay(player, prize)
		local medal = ({ "🥇", "🥈", "🥉" })[place]
		table.insert(lines, medal .. " " .. result.entry.name .. string.format(" (%.1f⭐)", result.average))
		if place == 1 then
			local data = DataService.get(player)
			if data then
				data.stats.costumeWins = (data.stats.costumeWins or 0) + 1
			end
			Juice.sound(player, "win")
		end
		Notify.player(player, medal .. " Your costume placed #" .. place .. "! +⚡" .. Format.number(prize), "rare")
	end
	if #lines > 0 then
		Notify.all("🎭 Costume party results: " .. table.concat(lines, "  "), "rare")
	else
		Notify.all("🎭 The costume party is over, but nobody voted!", "info")
	end
end

local function runParty()
	theme = THEMES[math.random(1, #THEMES)]
	phase = "dress"
	entries = {}
	votes = {}
	endsAt = workspace:GetServerTimeNow() + DRESS_SECONDS
	publish()
	Notify.all(
		"🎭 COSTUME PARTY! Theme: "
			.. theme
			.. ". Dress up in 🎨 Style and get on the stage at the end of 🛍️ Shop Street!",
		"rare"
	)
	waitPhase(DRESS_SECONDS)
	for _, player in Players:GetPlayers() do
		if onStage(player) then
			entries[player.UserId] = { player = player, name = player.DisplayName }
			Usage.track("costumeEntry", player)
		end
	end
	local count = 0
	for _ in entries do
		count += 1
	end
	if count == 0 then
		Notify.all("🎭 Nobody was on the stage this time. Next party soon!", "info")
		return
	end
	phase = "vote"
	endsAt = workspace:GetServerTimeNow() + VOTE_SECONDS
	publish()
	Notify.all("🎭 Vote on the costumes! Open 🎭 at the top right and give stars.", "rare")
	waitPhase(VOTE_SECONDS)
	tally()
end

local function info(player: Player): any
	local list = {}
	local mine = votes[player.UserId] or {}
	for userId, entry in entries do
		if entry.player.Parent then
			table.insert(list, {
				userId = userId,
				name = entry.name,
				stars = mine[userId],
				you = entry.player == player,
			})
		end
	end
	table.sort(list, function(a, b)
		return a.name < b.name
	end)
	return { phase = phase, theme = theme, endsAt = endsAt, entries = list }
end

local function onAction(player: Player, action: any, userId: any, stars: any): any
	if action == "info" then
		return info(player)
	end
	if os.clock() - (lastAction[player] or 0) < 0.3 then
		return false, "Slow down!"
	end
	lastAction[player] = os.clock()
	local entry = if type(userId) == "number" then entries[userId] else nil
	if not entry or not entry.player.Parent then
		return false, "They're not in the costume party."
	end
	if action == "look" then
		local character = player.Character
		local theirs = entry.player.Character
		local theirRoot = theirs and theirs:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not character or player:GetAttribute("InMatch") or not theirRoot or entry.player:GetAttribute("InMatch") then
			return false, "You can look from the lobby (and they have to be in it too)."
		end
		local spot = theirRoot.CFrame * CFrame.new(0, 0, -6)
		character:PivotTo(CFrame.lookAt(spot.Position, theirRoot.Position))
		return true, "👀 That's " .. entry.name .. "'s costume!"
	elseif action == "vote" then
		if phase ~= "vote" then
			return false, "Voting hasn't started yet."
		end
		if entry.player == player then
			return false, "You can't vote for yourself!"
		end
		if type(stars) ~= "number" or stars ~= stars then
			return false, "Pick 1 to 5 stars."
		end
		local given = votes[player.UserId]
		if not given then
			given = {}
			votes[player.UserId] = given
			pay(player, VOTER_SPARKS)
		end
		given[userId] = math.clamp(math.floor(stars), 1, 5)
		return true, "⭐ You gave " .. entry.name .. " " .. given[userId] .. " stars!"
	end
	return false, "Can't do that."
end

-- The stage: a raised platform with lights and a sign.
local function buildStage()
	local folder = Instance.new("Folder")
	folder.Name = "CostumeStage"
	local stage = Instance.new("Part")
	stage.Anchored = true
	stage.Size = STAGE_SIZE
	stage.CFrame = CFrame.new(STAGE + Vector3.new(0, STAGE_SIZE.Y / 2, 0))
	stage.Color = Color3.fromRGB(150, 40, 110)
	stage.Material = Enum.Material.Fabric
	stage.Parent = folder
	local step = Instance.new("Part")
	step.Anchored = true
	step.Size = Vector3.new(4, 0.6, 1.4)
	step.CFrame = CFrame.new(STAGE + Vector3.new(0, 0.3, STAGE_SIZE.Z / 2 + 0.7))
	step.Color = Color3.fromRGB(120, 30, 90)
	step.Material = Enum.Material.Fabric
	step.Parent = folder
	for _, x in { -5.5, 5.5 } do
		local lamp = Instance.new("Part")
		lamp.Anchored = true
		lamp.Size = Vector3.new(0.6, 6, 0.6)
		lamp.CFrame = CFrame.new(STAGE + Vector3.new(x, STAGE_SIZE.Y + 3, -2.6))
		lamp.Color = Color3.fromRGB(50, 50, 56)
		lamp.Material = Enum.Material.Metal
		lamp.Parent = folder
		local bulb = Instance.new("Part")
		bulb.Anchored = true
		bulb.CanCollide = false
		bulb.Shape = Enum.PartType.Ball
		bulb.Size = Vector3.one * 1.2
		bulb.CFrame = lamp.CFrame * CFrame.new(0, 3.3, 0)
		bulb.Color = Color3.fromRGB(255, 200, 240)
		bulb.Material = Enum.Material.Neon
		bulb.Parent = folder
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Bottom
		light.Range = 16
		light.Brightness = 3
		light.Color = Color3.fromRGB(255, 200, 240)
		light.Parent = bulb
	end
	local board = Instance.new("Part")
	board.Anchored = true
	board.Size = Vector3.new(10, 2.4, 0.3)
	board.CFrame =
		CFrame.lookAt(STAGE + Vector3.new(0, STAGE_SIZE.Y + 6.5, -2.8), STAGE + Vector3.new(0, STAGE_SIZE.Y + 6.5, 10))
	board.Color = Color3.fromRGB(60, 30, 60)
	board.Material = Enum.Material.Wood
	board.Parent = folder
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(400, 96)
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 220, 245)
	label.Text = "🎭 Costume Stage"
	label.Parent = gui
	folder.Parent = workspace
end

local running = false

-- Starts a costume party now (LobbyEventService takes turns with the other
-- lobby events; admins can start one from 🧪 Test). False if one is on.
function CostumeService.startNow(): boolean
	if running then
		return false
	end
	running = true
	task.spawn(function()
		local ok, problem = pcall(runParty)
		if not ok then
			warn("[Bottle a Storm] Costume party failed: " .. tostring(problem))
		end
		phase = "break"
		entries = {}
		votes = {}
		endsAt = 0
		publish()
		running = false
	end)
	return true
end

function CostumeService.isRunning(): boolean
	return running
end

function CostumeService.start()
	buildStage()
	Remotes.func("Costume").OnServerInvoke = onAction
	publish()
	Players.PlayerRemoving:Connect(function(player)
		lastAction[player] = nil
	end)
end

return CostumeService
