-- Day (the Migration) and night (Nightfall). During Nightfall the herd stops,
-- monsters hunt in waves, stealing is off, and at dawn the whole herd shares
-- loot based on how many titans survived. Also owns the sky: an overcast,
-- foggy day and a near-black night with storms and lightning.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)

local CycleService = {}
local S

local phase = "Day"
local nightNumber = 0
local stormUntil = 0
local atmosphere, colorCorrection, bloom, sunRays, clouds

local function now(): number
	return workspace:GetServerTimeNow()
end

local DAY_LENGTH = RunService:IsStudio() and Config.Cycle.StudioDayLength or Config.Cycle.DayLength
local NIGHT_LENGTH = RunService:IsStudio() and Config.Cycle.StudioNightLength or Config.Cycle.NightLength

function CycleService:IsDay(): boolean
	return phase == "Day"
end

function CycleService:NightNumber(): number
	return nightNumber
end

function CycleService:IsStorm(): boolean
	return now() < stormUntil
end

function CycleService:IsBossNight(): boolean
	return phase == "Night" and nightNumber % Config.Cycle.BossEvery == 0
end

-- Sky and mood ------------------------------------------------------------------

local function setupSky()
	pcall(function()
		Lighting.Technology = Enum.Technology.Future -- not settable from scripts in some versions
	end)
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.GeographicLatitude = 35

	atmosphere = Instance.new("Atmosphere")
	atmosphere.Parent = Lighting
	colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Parent = Lighting
	bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 30
	bloom.Threshold = 1.4
	bloom.Parent = Lighting
	sunRays = Instance.new("SunRaysEffect")
	sunRays.Intensity = 0.08
	sunRays.Spread = 0.6
	sunRays.Parent = Lighting

	clouds = Instance.new("Clouds")
	clouds.Parent = workspace.Terrain
	workspace.Terrain.WaterColor = Color3.fromRGB(30, 50, 55)
	workspace.Terrain.WaterTransparency = 0.6
	workspace.Terrain.WaterWaveSize = 0.2
end

local function tween(object: Instance, props)
	TweenService:Create(object, TweenInfo.new(5), props):Play()
end

local function applyLighting()
	if phase == "Night" then
		tween(Lighting, {
			ClockTime = 0.5,
			Brightness = 0.6,
			Ambient = Color3.fromRGB(15, 15, 25),
			OutdoorAmbient = Color3.fromRGB(40, 40, 60),
			ExposureCompensation = -0.2,
		})
		tween(atmosphere, { Density = 0.5, Offset = 0.1, Color = Color3.fromRGB(40, 45, 70), Decay = Color3.fromRGB(20, 15, 35), Glare = 0, Haze = 2.5 })
		tween(colorCorrection, { Saturation = -0.35, Contrast = 0.2, Brightness = -0.03, TintColor = Color3.fromRGB(190, 200, 255) })
		tween(clouds, { Cover = 0.85, Density = 0.8, Color = Color3.fromRGB(40, 40, 50) })
	elseif CycleService:IsStorm() then
		tween(Lighting, {
			ClockTime = 16,
			Brightness = 1.2,
			Ambient = Color3.fromRGB(40, 40, 50),
			OutdoorAmbient = Color3.fromRGB(90, 85, 110),
			ExposureCompensation = -0.1,
		})
		tween(atmosphere, { Density = 0.45, Offset = 0.2, Color = Color3.fromRGB(110, 105, 130), Decay = Color3.fromRGB(60, 50, 80), Glare = 0, Haze = 3 })
		tween(colorCorrection, { Saturation = -0.3, Contrast = 0.2, Brightness = -0.02, TintColor = Color3.fromRGB(215, 205, 240) })
		tween(clouds, { Cover = 0.95, Density = 0.9, Color = Color3.fromRGB(70, 65, 85) })
	else
		tween(
			Lighting,
			{ ClockTime = 16.5, Brightness = 2, Ambient = Color3.fromRGB(50, 50, 55), OutdoorAmbient = Color3.fromRGB(120, 115, 110), ExposureCompensation = 0 }
		)
		tween(
			atmosphere,
			{ Density = 0.33, Offset = 0.25, Color = Color3.fromRGB(190, 185, 170), Decay = Color3.fromRGB(110, 95, 85), Glare = 0.4, Haze = 1.6 }
		)
		tween(colorCorrection, { Saturation = -0.15, Contrast = 0.12, Brightness = 0, TintColor = Color3.fromRGB(255, 245, 230) })
		tween(clouds, { Cover = 0.7, Density = 0.6, Color = Color3.fromRGB(190, 190, 195) })
	end
end

-- A lightning flash in the sky every few seconds during storms and nights.
local function lightningLoop()
	while true do
		task.wait(math.random(5, 14))
		if CycleService:IsStorm() or (phase == "Night" and math.random() < 0.5) then
			local brightness = Lighting.Brightness
			Lighting.Brightness = brightness + 4
			task.wait(0.08)
			Lighting.Brightness = brightness + 1
			task.wait(0.06)
			Lighting.Brightness = brightness + 3
			task.wait(0.1)
			Lighting.Brightness = brightness
		end
	end
end

function CycleService:StartStorm(seconds: number, byPlayer: Player?)
	stormUntil = math.max(stormUntil, now()) + seconds
	ReplicatedStorage:SetAttribute("StormUntil", stormUntil)
	if byPlayer then
		S.PlayerService:NotifyAll(string.format("⚡ %s started a Storm! Rare mutations are more likely for everyone.", byPlayer.DisplayName))
	else
		S.PlayerService:NotifyAll("⚡ A storm rolls in! Rare mutations are more likely.")
	end
	applyLighting()
	task.delay(seconds + 0.5, function()
		if not self:IsStorm() then
			applyLighting()
		end
	end)
end

-- Titan Roar -------------------------------------------------------------------

function CycleService:Roar(player: Player)
	local profile = S.PlayerService:GetProfile(player)
	local session = S.PlayerService:GetSession(player)
	local record = S.TitanService:GetTitan(player)
	if not profile or not record then
		return
	end
	if profile.Stage < Config.Nightfall.RoarStage then
		S.PlayerService:Notify(player, "Titan Roar unlocks when your titan is an Adult.")
		return
	end
	if phase ~= "Night" then
		S.PlayerService:Notify(player, "Titan Roar only works during Nightfall.")
		return
	end
	if session.RoarNight == nightNumber then
		S.PlayerService:Notify(player, "Your titan already roared tonight.")
		return
	end
	session.RoarNight = nightNumber
	local stunned = S.MonsterService:StunNear(record.Root.Position, Config.Nightfall.RoarRadius * record.Scale, Config.Nightfall.RoarStun)
	S.PlayerService:NotifyAll(string.format("%s's titan ROARS! %d monsters stunned.", player.DisplayName, stunned))
end

-- Phases -------------------------------------------------------------------------

local function setPhase(newPhase: string, length: number)
	phase = newPhase
	ReplicatedStorage:SetAttribute("Phase", phase)
	ReplicatedStorage:SetAttribute("PhaseEndsAt", now() + length)
	ReplicatedStorage:SetAttribute("NightNumber", nightNumber)
	ReplicatedStorage:SetAttribute("BossNight", CycleService:IsBossNight())
	applyLighting()
end

function CycleService:_runNight()
	nightNumber += 1
	for _, session in S.PlayerService:AllSessions() do
		session.NightDamage = 0
		session.BossDamage = 0
	end
	setPhase("Night", NIGHT_LENGTH)
	S.StealService:OnNightfall()
	for player in S.PlayerService:AllSessions() do
		S.TitanService:RefreshDeck(player) -- homesick Riders expire now
	end
	local boss = self:IsBossNight()
	S.PlayerService:NotifyAll(
		boss and "🌩 NIGHTFALL: The Storm King approaches! Protect the herd!" or "🌙 Nightfall! Monsters are hunting. Protect the herd!"
	)
	if boss then
		S.MonsterService:SpawnBoss()
	end

	local endsAt = os.clock() + NIGHT_LENGTH
	local nextWave = os.clock() + 3
	while os.clock() < endsAt do
		if os.clock() >= nextWave then
			nextWave = os.clock() + Config.Nightfall.WaveInterval
			S.MonsterService:SpawnWave(nightNumber)
		end
		task.wait(0.5)
	end
	self:_dawn(boss)
end

function CycleService:_dawn(wasBoss: boolean)
	S.MonsterService:ClearNight()
	local survivors, total = 0, 0
	for player, record in S.TitanService:AllTitans() do
		total += 1
		local profile = S.PlayerService:GetProfile(player)
		if record.Exhausted then
			if profile then
				profile.NightsSurvivedStreak = 0
			end
		else
			survivors += 1
			if profile then
				profile.NightsSurvivedStreak += 1
			end
		end
	end

	local pool = Config.Nightfall.LootPerSurvivor * survivors * (1 + nightNumber * 0.1)
	if wasBoss then
		pool *= Config.Nightfall.BossLootMult
	end
	local share = total > 0 and math.floor(pool / total) or 0
	for player in S.PlayerService:AllSessions() do
		if share > 0 then
			S.PlayerService:AddCoins(player, share)
		end
		S.PlayerService:Notify(player, string.format("☀ Dawn! %d/%d titans survived. Herd loot: +%s coins each.", survivors, total, Util.formatNumber(share)))
	end

	if wasBoss then
		local top, topDamage = nil, 0
		for player, session in S.PlayerService:AllSessions() do
			player:SetAttribute("Guardian", nil)
			if session.BossDamage > topDamage then
				top, topDamage = player, session.BossDamage
			end
		end
		if top then
			top:SetAttribute("Guardian", true)
			S.PlayerService:NotifyAll(string.format("👑 %s is the Herd Guardian until the next Storm King!", top.DisplayName))
		end
		-- Survivors of a boss night get a bonus egg.
		for player, record in S.TitanService:AllTitans() do
			if not record.Exhausted and S.PlayerService:FreeEggSlots(player) > 0 then
				S.PlayerService:AddEgg(player, S.PlayerService:RollRarity(player, "Rare"))
			end
		end
	end
	S.TitanService:HealAll()
end

function CycleService:Init(services)
	S = services
	setupSky()
	ReplicatedStorage:SetAttribute("Phase", phase)
	ReplicatedStorage:SetAttribute("PhaseEndsAt", now() + DAY_LENGTH)
	ReplicatedStorage:SetAttribute("NightNumber", 0)
	ReplicatedStorage:SetAttribute("StormUntil", 0)
end

function CycleService:Start()
	task.spawn(lightningLoop)
	while true do
		setPhase("Day", DAY_LENGTH)
		if math.random() < Config.Cycle.StormChance then
			task.delay(20, function()
				self:StartStorm(Config.Cycle.StormLength)
			end)
		end
		task.wait(DAY_LENGTH)
		self:_runNight()
	end
end

return CycleService
