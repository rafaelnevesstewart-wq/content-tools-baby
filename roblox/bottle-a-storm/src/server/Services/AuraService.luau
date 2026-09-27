-- Island Sky Aura: a cloud canopy above each island takes on the look of the
-- island's best storm, and that storm's weather falls over the island. Rarer
-- storms make a stronger aura; Legendary and Mythic add a light beam into the
-- sky you can see from anywhere on the map. Updates itself every few seconds.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local StormData = require(Shared.StormData)

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)

local AuraService = {}

local CANOPY_HEIGHT = 48
local CANOPY_RADIUS = 32
local PUFFS = 10
local INTENSITY = { 0.4, 0.6, 0.8, 1, 1.3, 1.6, 2 } -- by rarity index

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

type Weather = {
	texture: string,
	color: ColorSequence?, -- nil: use the storm's own colors
	size: number,
	speed: number,
	lifetime: number,
	rate: number,
	spread: number,
	transparency: number,
	light: number,
}

-- What falls from the canopy for each kind of storm (by its particle style).
local WEATHER: { [string]: Weather } = {
	rain = {
		texture = SPARKLE,
		color = ColorSequence.new(Color3.fromRGB(130, 180, 255)),
		size = 0.35,
		speed = 32,
		lifetime = 1.6,
		rate = 70,
		spread = 3,
		transparency = 0.1,
		light = 0.3,
	},
	snow = {
		texture = SPARKLE,
		color = ColorSequence.new(Color3.new(1, 1, 1)),
		size = 0.7,
		speed = 8,
		lifetime = 6,
		rate = 45,
		spread = 25,
		transparency = 0,
		light = 0.5,
	},
	hail = {
		texture = SPARKLE,
		color = ColorSequence.new(Color3.fromRGB(220, 240, 255)),
		size = 0.6,
		speed = 30,
		lifetime = 1.7,
		rate = 30,
		spread = 5,
		transparency = 0,
		light = 0.3,
	},
	fog = {
		texture = SMOKE,
		color = ColorSequence.new(Color3.fromRGB(235, 235, 245)),
		size = 14,
		speed = 3,
		lifetime = 9,
		rate = 4,
		spread = 30,
		transparency = 0.75,
		light = 0,
	},
	wind = {
		texture = SMOKE,
		color = nil,
		size = 6,
		speed = 10,
		lifetime = 4,
		rate = 8,
		spread = 70,
		transparency = 0.7,
		light = 0,
	},
	lightning = {
		texture = SPARKLE,
		color = ColorSequence.new(Color3.fromRGB(255, 240, 100)),
		size = 0.9,
		speed = 22,
		lifetime = 2,
		rate = 16,
		spread = 20,
		transparency = 0,
		light = 1,
	},
	dust = {
		texture = SMOKE,
		color = ColorSequence.new(Color3.fromRGB(220, 185, 130)),
		size = 7,
		speed = 7,
		lifetime = 6,
		rate = 8,
		spread = 50,
		transparency = 0.6,
		light = 0,
	},
	rainbow = {
		texture = SPARKLE,
		color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)),
			ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 80)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(100, 230, 120)),
			ColorSequenceKeypoint.new(0.75, Color3.fromRGB(90, 160, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 100, 255)),
		}),
		size = 0.9,
		speed = 7,
		lifetime = 6,
		rate = 35,
		spread = 30,
		transparency = 0,
		light = 0.9,
	},
	fire = {
		texture = "rbxasset://textures/particles/fire_main.dds",
		color = ColorSequence.new(Color3.fromRGB(255, 170, 60), Color3.fromRGB(255, 70, 30)),
		size = 1.2,
		speed = 9,
		lifetime = 5,
		rate = 25,
		spread = 20,
		transparency = 0.2,
		light = 1,
	},
	stars = {
		texture = SPARKLE,
		color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(160, 180, 255)),
		size = 0.8,
		speed = 5,
		lifetime = 8,
		rate = 30,
		spread = 40,
		transparency = 0,
		light = 1,
	},
	hurricane = {
		texture = SMOKE,
		color = nil,
		size = 9,
		speed = 14,
		lifetime = 3.5,
		rate = 12,
		spread = 90,
		transparency = 0.6,
		light = 0.1,
	},
}

local current: { [Player]: string } = {} -- aura key per owner, to rebuild only on change
local flickers: { [Player]: PointLight } = {} -- lightning auras flash
local models: { [Player]: Model } = {}

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		if key ~= "Parent" then
			(p :: any)[key] = value
		end
	end
	p.Parent = props.Parent
	return p
end

local function bestStorm(data: any): StormData.StormRecord?
	local best: StormData.StormRecord? = nil
	for _, record in data.storms do
		if not best or StormData.incomeOf(record) > StormData.incomeOf(best) then
			best = record
		end
	end
	return best
end

local function clear(owner: Player)
	current[owner] = nil
	flickers[owner] = nil
	local old = models[owner]
	models[owner] = nil
	if old then
		old:Destroy()
	end
end

local function build(owner: Player, record: StormData.StormRecord)
	local plot = PlotService.getPlot(owner)
	local def = StormData.get(record.id)
	if not plot or not def then
		return
	end
	local rarity = StormData.rarityOf(def)
	local mutation = StormData.getMutation(record.mut)
	local intensity = INTENSITY[def.rarity] or 1
	local center = plot.cframe.Position + Vector3.new(0, CANOPY_HEIGHT, 0)

	local aura = Instance.new("Model")
	aura.Name = "SkyAura"

	-- The cloud canopy, tinted with the storm's colors.
	for i = 1, PUFFS do
		local angle = (i / PUFFS) * math.pi * 2
		local size = 20 + (i % 3) * 4
		local color = def.colors[(i - 1) % #def.colors + 1]
		part({
			Name = "Cloud",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(size, size * 0.6, size),
			CFrame = CFrame.new(
				center + Vector3.new(math.cos(angle) * CANOPY_RADIUS, (i % 2) * 3, math.sin(angle) * CANOPY_RADIUS)
			),
			Color = Color3.new(1, 1, 1):Lerp(color, 0.65),
			Material = if def.rarity >= 5 then Enum.Material.Neon else Enum.Material.SmoothPlastic,
			Transparency = if def.rarity >= 5 then 0.35 else 0.15,
			Parent = aura,
		})
	end

	-- Weather falling across the island from a sheet at canopy height.
	local style = WEATHER[def.fx] or WEATHER.fog
	local sheet = part({
		Name = "WeatherSheet",
		Size = Vector3.new(CANOPY_RADIUS * 2.4, 1, CANOPY_RADIUS * 2.4),
		CFrame = CFrame.new(center - Vector3.new(0, 4, 0)),
		Transparency = 1,
		Parent = aura,
	})
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = style.texture
	emitter.Color = style.color or ColorSequence.new(def.colors[1])
	emitter.Size = NumberSequence.new(style.size)
	emitter.Speed = NumberRange.new(style.speed * 0.8, style.speed * 1.2)
	emitter.Lifetime = NumberRange.new(style.lifetime * 0.9, style.lifetime * 1.1)
	emitter.Rate = style.rate * intensity
	emitter.SpreadAngle = Vector2.new(style.spread, style.spread)
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.Transparency = NumberSequence.new(style.transparency, 1)
	emitter.LightEmission = style.light
	emitter.RotSpeed = NumberRange.new(-60, 60)
	emitter.Parent = sheet

	local glow = Instance.new("PointLight")
	glow.Color = rarity.color
	glow.Range = 40
	glow.Brightness = 0.6 * intensity
	glow.Parent = sheet
	if def.fx == "lightning" then
		flickers[owner] = glow
	end

	if mutation then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = mutation.color
		sparkles.Parent = sheet
	end

	-- Legendary and Mythic: a beam into the sky, visible across the map.
	if def.rarity >= 5 then
		local bottom = Instance.new("Attachment")
		bottom.Parent = sheet
		local top = Instance.new("Attachment")
		top.Position = Vector3.new(0, 500, 0)
		top.Parent = sheet
		local beam = Instance.new("Beam")
		beam.Attachment0 = bottom
		beam.Attachment1 = top
		beam.Color = ColorSequence.new(rarity.color, if mutation then mutation.color else rarity.color)
		beam.Width0 = if def.rarity >= 6 then 10 else 6
		beam.Width1 = if def.rarity >= 6 then 16 else 10
		beam.LightEmission = 1
		beam.Transparency = NumberSequence.new(0.2, 1)
		beam.FaceCamera = true
		beam.Parent = sheet
	end

	-- A label you can read from far away.
	local tag = Instance.new("BillboardGui")
	tag.Name = "AuraTag"
	tag.Size = UDim2.fromOffset(320, 50)
	tag.StudsOffsetWorldSpace = Vector3.new(0, 16, 0)
	tag.MaxDistance = 700
	tag.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = rarity.color
	label.TextStrokeTransparency = 0.2
	label.Text = "✨ " .. rarity.name .. " Sky: " .. StormData.displayName(record)
	label.Parent = tag
	tag.Parent = sheet

	aura.Parent = plot.model
	models[owner] = aura
end

local function refresh(owner: Player)
	local data = DataService.get(owner)
	if not data or not PlotService.getPlot(owner) then
		if current[owner] then
			clear(owner)
		end
		return
	end
	local best = bestStorm(data)
	local key = if best then best.id .. ":" .. (best.mut or "") else ""
	if key == current[owner] then
		return
	end
	clear(owner)
	current[owner] = key
	if best then
		build(owner, best)
	end
end

function AuraService.start()
	task.spawn(function()
		while true do
			for _, owner in Players:GetPlayers() do
				refresh(owner)
			end
			task.wait(2)
		end
	end)

	-- Lightning skies flash now and then.
	task.spawn(function()
		local rng = Random.new()
		while true do
			task.wait(rng:NextNumber(1.5, 4))
			for _, light in flickers do
				if light.Parent then
					local normal = light.Brightness
					light.Brightness = 8
					task.delay(0.12, function()
						light.Brightness = normal
					end)
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(clear)
end

return AuraService
