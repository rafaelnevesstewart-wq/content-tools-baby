-- Storm moods. Every owned storm has a mood from 0 to 100:
--   😄 Happy (70+) earns x1.25, 🙂 Content x1, 😐 Bored (15+) x0.8, 😤 Restless x0.5.
-- Moods drop slowly while you're online. Pet a storm (E on your pedestal), ride
-- it, or buy Storm Snacks to cheer it up. A Restless storm may try to escape:
-- its jar shakes and you have 30 seconds to calm it (E) before it flies back
-- to the Wild Skies. The Storm Tamer pass stops escapes.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Products = require(Shared.Products)
local StormData = require(Shared.StormData)
local Signal = require(Shared.Signal)

local Modules = script.Parent.Parent.Modules
local Notify = require(Modules.Notify)

local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local PlotService = require(script.Parent.PlotService)
local RideService = require(script.Parent.RideService)
local StormSpawner = require(script.Parent.StormSpawner)

local MoodService = {}

-- (owner) every time a storm is petted.
MoodService.Petted = Signal.new()

local TICK_SECONDS = 10

type Escape = {
	owner: Player,
	uid: string,
	endsAt: number,
	pivot: CFrame?,
}

local escaping: { [string]: Escape } = {} -- by storm uid
local lastPet: { [string]: number } = {} -- by storm uid
local lastPetToast: { [Player]: number } = {}
local rng = Random.new()

local function hasTamer(player: Player): boolean
	return player:GetAttribute(Products.passAttribute("StormTamer")) == true
end

local function findRecord(data: any, uid: string): StormData.StormRecord?
	for _, record in data.storms do
		if record.uid == uid then
			return record
		end
	end
	return nil
end

-- Changes one storm's mood and refreshes its label if the mood tier changed.
local function setMood(owner: Player, record: StormData.StormRecord, value: number)
	local before = StormData.moodOf(record)
	record.mood = math.clamp(value, 0, 100)
	PlotService.updateSlotLabel(owner, record.slot)
	if StormData.moodOf(record) ~= before then
		IncomeService.sync(owner)
	end
end

local function stopEscape(uid: string)
	local escape = escaping[uid]
	if not escape then
		return
	end
	escaping[uid] = nil
	local data = DataService.get(escape.owner)
	local record = data and findRecord(data, uid)
	if record then
		PlotService.setSlotAlert(escape.owner, record.slot, nil, nil)
		local display = PlotService.slotDisplay(escape.owner, record.slot)
		if display and escape.pivot then
			display:PivotTo(escape.pivot)
		end
	end
end

local function startEscape(owner: Player, record: StormData.StormRecord)
	local display = PlotService.slotDisplay(owner, record.slot)
	escaping[record.uid] = {
		owner = owner,
		uid = record.uid,
		endsAt = os.clock() + Config.Mood.EscapeWarnSeconds,
		pivot = if display then display:GetPivot() else nil,
	}
	PlotService.setSlotAlert(owner, record.slot, "💨 ESCAPING! Press E to calm it!", "Calm it down!")
	Notify.player(
		owner,
		"😤 Your "
			.. StormData.displayName(record)
			.. " is trying to escape! Go to your island and press E on it within "
			.. Config.Mood.EscapeWarnSeconds
			.. "s!",
		"warn"
	)
end

-- Time ran out: the storm leaves and becomes a wild storm again.
local function escapeNow(escape: Escape)
	local owner = escape.owner
	local data = DataService.get(owner)
	stopEscape(escape.uid)
	if not data then
		return
	end
	for index, record in data.storms do
		if record.uid == escape.uid then
			table.remove(data.storms, index)
			PlotService.refreshSlot(owner, record.slot)
			IncomeService.sync(owner)
			local def = StormData.get(record.id)
			if def and not def.hybrid then
				StormSpawner.spawnSpecific(def)
			end
			local where = if def and not def.hybrid then " It flew back to the Wild Skies. Catch it again!" else ""
			Notify.player(owner, "💨 Your " .. StormData.displayName(record) .. " escaped!" .. where, "warn")
			return
		end
	end
end

local function pet(owner: Player, slot: number)
	local data = DataService.get(owner)
	local record = data and PlotService.stormInSlot(data, slot)
	if not record then
		return
	end
	local name = StormData.displayName(record)
	if escaping[record.uid] then
		stopEscape(record.uid)
		setMood(owner, record, math.max(StormData.moodValue(record), Config.Mood.CalmTo))
		lastPet[record.uid] = os.clock()
		Notify.player(owner, "😮‍💨 Phew! " .. name .. " calmed down.", "success")
		return
	end
	local wait = Config.Mood.PetCooldown - (os.clock() - (lastPet[record.uid] or -math.huge))
	if wait > 0 then
		if os.clock() - (lastPetToast[owner] or 0) > 2 then
			lastPetToast[owner] = os.clock()
			Notify.player(owner, name .. " was just petted. Try again in " .. math.ceil(wait) .. "s.", "info")
		end
		return
	end
	lastPet[record.uid] = os.clock()
	setMood(owner, record, StormData.moodValue(record) + Config.Mood.PetAmount)
	MoodService.Petted:Fire(owner)
	local tier = StormData.moodOf(record)
	Notify.player(owner, "🥰 " .. name .. " loves that! Mood: " .. tier.emoji .. " " .. tier.name, "success")
end

-- Storm Snacks: every storm becomes fully Happy.
function MoodService.feedAll(owner: Player)
	local data = DataService.get(owner)
	if not data then
		return
	end
	for _, record in data.storms do
		stopEscape(record.uid)
		setMood(owner, record, 100)
	end
	IncomeService.sync(owner)
end

local function tick()
	local minutes = TICK_SECONDS / 60
	for _, owner in Players:GetPlayers() do
		local data = DataService.get(owner)
		if data and PlotService.getPlot(owner) then
			local tamer = hasTamer(owner)
			local decay = Config.Mood.DecayPerMinute * minutes * (if tamer then Config.Mood.TamerDecayMultiplier else 1)
			local ridden = RideService.mountUid(owner)
			for _, record in data.storms do
				if not escaping[record.uid] and not PlotService.isSlotStolen(owner, record.slot) then
					if record.uid == ridden then
						setMood(owner, record, StormData.moodValue(record) + Config.Mood.RideGainPerMinute * minutes)
					else
						setMood(owner, record, StormData.moodValue(record) - decay)
					end
					local restless = StormData.moodValue(record) < Config.Mood.EscapeBelow
					if restless and not tamer and rng:NextNumber() < Config.Mood.EscapeChancePerMinute * minutes then
						startEscape(owner, record)
					end
				end
			end
		end
	end
end

function MoodService.start()
	PlotService.PetRequested:Connect(pet)

	task.spawn(function()
		while true do
			task.wait(TICK_SECONDS)
			tick()
		end
	end)

	-- Shake escaping jars and let them go when time runs out.
	task.spawn(function()
		while true do
			task.wait(0.08)
			local t = os.clock()
			for uid, escape in escaping do
				local data = DataService.get(escape.owner)
				local record = data and findRecord(data, uid)
				if not record or PlotService.isSlotStolen(escape.owner, record.slot) then
					-- Sold, traded, mixed or being stolen: nothing left to escape.
					escaping[uid] = nil
					if record then
						PlotService.setSlotAlert(escape.owner, record.slot, nil, nil)
					end
				elseif t >= escape.endsAt then
					escapeNow(escape)
				else
					local display = PlotService.slotDisplay(escape.owner, record.slot)
					if display and escape.pivot then
						local wobble = CFrame.Angles(rng:NextNumber(-0.12, 0.12), 0, rng:NextNumber(-0.12, 0.12))
						display:PivotTo(escape.pivot * wobble)
					end
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastPetToast[player] = nil
		for uid, escape in escaping do
			if escape.owner == player then
				escaping[uid] = nil
			end
		end
	end)
end

return MoodService
