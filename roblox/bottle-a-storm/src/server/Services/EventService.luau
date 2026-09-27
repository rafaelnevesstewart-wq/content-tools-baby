-- Server-wide mini events on the Wild Skies:
--   * Golden Hunt: a fast Golden Rare storm appears. First to catch it wins a
--     big Sparks prize.
--   * Storm Race: a Prismatic storm zooms around a ring track. It never dodges
--     but only stays for a short time. First to catch it wins.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local StormData = require(Shared.StormData)

local Modules = script.Parent.Parent.Modules
local Effects = require(Modules.Effects)
local Notify = require(Modules.Notify)

local CaptureService = require(script.Parent.CaptureService)
local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local StormSpawner = require(script.Parent.StormSpawner)

local EventService = {}

local rng = Random.new()
local ringFolder: Folder? = nil

local function raidGoing(): boolean
	local state = workspace:GetAttribute("RaidState")
	return state == "active" or state == "warning"
end

local function randomOf(rarity: number): StormData.StormDef
	local options = StormData.wildOfRarity(rarity)
	return options[rng:NextInteger(1, #options)]
end

local function removeRings()
	if ringFolder then
		ringFolder:Destroy()
		ringFolder = nil
	end
end

-- Announces that a special storm got away if nobody caught it in time.
-- (A catch clears the SpecialStorm attribute first, in onCaught.)
local function watchExpiry(uid: string, lifetime: number, message: string)
	task.delay(lifetime + 1.5, function()
		local storm = StormSpawner.get(uid)
		while storm and storm.catcher do
			task.wait(0.5) -- someone is bottling it right now
			storm = StormSpawner.get(uid)
		end
		if workspace:GetAttribute("SpecialStorm") ~= uid then
			return
		end
		if storm then
			StormSpawner.remove(uid)
		end
		workspace:SetAttribute("SpecialStorm", nil)
		workspace:SetAttribute("SpecialKind", nil)
		removeRings()
		Notify.all(message, "info")
	end)
end

local function golden()
	local def = randomOf(Config.Golden.Rarity)
	local uid = StormSpawner.spawnSpecial(def, {
		tag = "golden",
		mutation = "Golden",
		speedMultiplier = Config.Golden.SpeedMultiplier,
		lifetime = Config.Golden.Lifetime,
	})
	workspace:SetAttribute("SpecialStorm", uid)
	workspace:SetAttribute("SpecialKind", "golden")
	Notify.all(
		"✨ GOLDEN HUNT! A Golden "
			.. def.name
			.. " is zooming around the Wild Skies. First to catch it wins a big prize!",
		"rare"
	)
	watchExpiry(uid, Config.Golden.Lifetime, "💨 The Golden " .. def.name .. " got away! Better luck next hunt.")
end

-- A ring of glowing balls standing up at `position`, facing along `ahead`.
local function ring(parent: Instance, position: Vector3, ahead: Vector3, color: Color3)
	local frame = CFrame.lookAt(position, position + ahead)
	for i = 1, 10 do
		local angle = i / 10 * math.pi * 2
		local part = Instance.new("Part")
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.new(1.2, 1.2, 1.2)
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Material = Enum.Material.Neon
		part.Color = color
		part.CFrame = frame * CFrame.new(math.cos(angle) * 6, math.sin(angle) * 6, 0)
		part.Parent = parent
	end
end

local function buildTrack(): { Vector3 }
	removeRings()
	local folder = Instance.new("Folder")
	folder.Name = "RaceTrack"
	folder.Parent = workspace
	ringFolder = folder

	local points = {}
	local count = Config.Race.Rings
	local start = rng:NextNumber(0, math.pi * 2)
	for i = 1, count do
		local angle = start + i / count * math.pi * 2
		-- Rises and dips so it feels like a roller coaster, but stays low
		-- enough to reach with a jar.
		local height = Config.Wild.HoverHeight + 3 + math.sin(i / count * math.pi * 4) * 3
		local point =
			Vector3.new(math.cos(angle) * Config.Race.TrackRadius, height, math.sin(angle) * Config.Race.TrackRadius)
		local ahead = Vector3.new(-math.sin(angle), 0, math.cos(angle))
		local color = Color3.fromHSV(i / count, 0.55, 1)
		ring(folder, point, ahead, color)
		table.insert(points, point)
	end
	return points
end

local function race()
	Notify.all(
		"🏁 STORM RACE in " .. Config.Race.WarningSeconds .. "s! Get to the Wild Skies and find the rainbow rings!",
		"rare"
	)
	local points = buildTrack()
	-- Holds the slot so a golden hunt doesn't start during the countdown.
	workspace:SetAttribute("SpecialStorm", "countdown")
	task.wait(Config.Race.WarningSeconds)
	if raidGoing() then
		workspace:SetAttribute("SpecialStorm", nil)
		removeRings()
		return
	end
	local def = randomOf(Config.Race.Rarity)
	local uid = StormSpawner.spawnSpecial(def, {
		tag = "race",
		mutation = Config.Race.Mutation,
		path = points,
		speed = Config.Race.Speed,
		lifetime = Config.Race.Lifetime,
		hitsNeeded = Config.Race.HitsNeeded,
		noDodge = true,
	})
	workspace:SetAttribute("SpecialStorm", uid)
	workspace:SetAttribute("SpecialKind", "race")
	Notify.all(
		"🏁 GO! A "
			.. Config.Race.Mutation
			.. " "
			.. def.name
			.. " is racing through the rings. Hit it "
			.. Config.Race.HitsNeeded
			.. " times to catch it!",
		"rare"
	)
	watchExpiry(uid, Config.Race.Lifetime, "🏁 The race storm finished its laps and flew away! Nobody caught it.")
end

local function onCaught(player: Player, _record: any, storm: StormSpawner.WildStorm)
	if storm.tag ~= "golden" and storm.tag ~= "race" then
		return
	end
	workspace:SetAttribute("SpecialStorm", nil)
	workspace:SetAttribute("SpecialKind", nil)
	local settings = if storm.tag == "golden" then Config.Golden else Config.Race
	local prize = math.floor(math.max(settings.PrizeMin, IncomeService.rateOf(player) * settings.PrizeSeconds))
	IncomeService.addSparks(player, prize)
	local data = DataService.get(player)
	if data then
		data.stats.huntsWon += 1
	end
	Effects.confetti(storm.root.Position)
	local what = if storm.tag == "golden" then "won the Golden Hunt" else "won the Storm Race"
	Notify.player(player, "🏆 You " .. what .. "! +⚡" .. Format.number(prize) .. " Sparks!", "rare")
	Notify.allExcept(player, "🏆 " .. player.DisplayName .. " " .. what .. "!", "info")
	if storm.tag == "race" then
		task.delay(2, removeRings)
	end
end

-- Waits `first` seconds, then runs `event` every `interval` seconds (skipping
-- while a Mega-Storm is on or nobody is playing).
local function loop(first: number, interval: number, event: () -> ())
	task.wait(first)
	while true do
		if not raidGoing() and #Players:GetPlayers() > 0 and not workspace:GetAttribute("SpecialStorm") then
			event()
		end
		task.wait(interval)
	end
end

-- Admin panel: start one right now (it's skipped if one is already running).
function EventService.startGolden(): boolean
	if raidGoing() or workspace:GetAttribute("SpecialStorm") then
		return false
	end
	task.spawn(golden)
	return true
end

function EventService.startRace(): boolean
	if raidGoing() or workspace:GetAttribute("SpecialStorm") then
		return false
	end
	task.spawn(race)
	return true
end

function EventService.start()
	CaptureService.Caught:Connect(onCaught)
	local studio = RunService:IsStudio()
	local goldenFirst = if studio then Config.Golden.StudioFirstDelay else Config.Golden.FirstDelay
	local raceFirst = if studio then Config.Race.StudioFirstDelay else Config.Race.FirstDelay
	task.spawn(loop, goldenFirst, Config.Golden.Interval, golden)
	task.spawn(loop, raceFirst, Config.Race.Interval, race)
end

return EventService
