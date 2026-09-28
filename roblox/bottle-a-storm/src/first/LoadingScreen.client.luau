-- The loading screen (runs first, from ReplicatedFirst): the game's name, a
-- spinning storm, a tip that changes every few seconds and a progress bar,
-- until the lobby has loaded and your character is in it. Then it fades out.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- Tips in English, Portuguese and Spanish (your Roblox language picks; the
-- ⚙️ Settings language isn't loaded yet this early).
local TIPS_BY_LANGUAGE = {
	en = {
		"🛏️ Cover your bed in blocks: wool first, then wood, then obsidian.",
		"⛏️ Stand on your generator to pick up Copper and Silver.",
		"🧙 Pick a class before a match: Knight, Archer, Builder or Healer.",
		"🐉 Beat the boss on the middle island for a pile of loot.",
		"🪂 A Glider lets you sail across the gaps: hold jump while falling.",
		"🎣 There's a fishing pond on Games Island. Can you catch the Storm Serpent?",
		"🗺️ New treasure hunt clues every day at the top right.",
		"📋 Everything is in the Menu (press M).",
		"👥 Party up with friends to always play on the same team.",
		"🌠 At night, look up: shooting stars grant wishes!",
	},
	pt = {
		"🛏️ Cubra sua cama com blocos: lã primeiro, depois madeira, depois obsidiana.",
		"⛏️ Fique em cima do seu gerador para pegar Cobre e Prata.",
		"🧙 Escolha uma classe antes da partida: Cavaleiro, Arqueiro, Construtor ou Curandeiro.",
		"🐉 Derrote o chefe na ilha do meio para ganhar muitos prêmios.",
		"🪂 Com um Planador você cruza os buracos: segure pular enquanto cai.",
		"🎣 Tem um lago de pesca na Ilha dos Jogos. Consegue pegar a Serpente da Tempestade?",
		"🗺️ Novas pistas da caça ao tesouro todo dia, no canto de cima à direita.",
		"📋 Tudo fica no Menu (aperte M).",
		"👥 Faça um grupo com amigos para jogar sempre no mesmo time.",
		"🌠 À noite, olhe para o céu: estrelas cadentes realizam desejos!",
	},
	es = {
		"🛏️ Cubre tu cama con bloques: primero lana, luego madera, luego obsidiana.",
		"⛏️ Párate en tu generador para recoger Cobre y Plata.",
		"🧙 Elige una clase antes de la partida: Caballero, Arquero, Constructor o Sanador.",
		"🐉 Vence al jefe de la isla del centro para ganar un montón de premios.",
		"🪂 Con un Planeador cruzas los huecos: mantén saltar mientras caes.",
		"🎣 Hay un estanque de pesca en la Isla de Juegos. ¿Atraparás la Serpiente de la Tormenta?",
		"🗺️ Nuevas pistas de la búsqueda del tesoro cada día, arriba a la derecha.",
		"📋 Todo está en el Menú (pulsa M).",
		"👥 Forma un grupo con amigos para jugar siempre en el mismo equipo.",
		"🌠 De noche, mira arriba: ¡las estrellas fugaces conceden deseos!",
	},
}
local locale = string.lower(string.sub(game:GetService("LocalizationService").RobloxLocaleId, 1, 2))
local TIPS = TIPS_BY_LANGUAGE[locale] or TIPS_BY_LANGUAGE.en

ReplicatedFirst:RemoveDefaultLoadingScreen()

local gui = Instance.new("ScreenGui")
gui.Name = "LoadingScreen"
gui.IgnoreGuiInset = true
gui.DisplayOrder = 100
gui.ResetOnSpawn = false

local background = Instance.new("Frame")
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = Color3.fromRGB(18, 22, 36)
background.Parent = gui
local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new(Color3.fromRGB(40, 60, 110), Color3.fromRGB(14, 16, 28))
gradient.Rotation = 90
gradient.Parent = background

local storm = Instance.new("TextLabel")
storm.BackgroundTransparency = 1
storm.AnchorPoint = Vector2.new(0.5, 0.5)
storm.Position = UDim2.fromScale(0.5, 0.36)
storm.Size = UDim2.fromOffset(120, 120)
storm.Font = Enum.Font.GothamBlack
storm.TextScaled = true
storm.Text = "🌪️"
storm.Parent = background

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.AnchorPoint = Vector2.new(0.5, 0)
title.Position = UDim2.fromScale(0.5, 0.5)
title.Size = UDim2.new(0.9, 0, 0, 56)
title.Font = Enum.Font.GothamBlack
title.TextScaled = true
title.TextColor3 = Color3.fromRGB(255, 210, 90)
title.TextStrokeTransparency = 0.4
title.Text = "Bottle a Storm: Bed Wars"
title.Parent = background
local titleSize = Instance.new("UITextSizeConstraint")
titleSize.MaxTextSize = 52
titleSize.Parent = title

local track = Instance.new("Frame")
track.AnchorPoint = Vector2.new(0.5, 0)
track.Position = UDim2.new(0.5, 0, 0.5, 72)
track.Size = UDim2.new(0.6, 0, 0, 10)
track.BackgroundColor3 = Color3.fromRGB(40, 46, 62)
track.BorderSizePixel = 0
track.Parent = background
local trackCorner = Instance.new("UICorner")
trackCorner.CornerRadius = UDim.new(0, 5)
trackCorner.Parent = track
local fill = Instance.new("Frame")
fill.Size = UDim2.fromScale(0.05, 1)
fill.BackgroundColor3 = Color3.fromRGB(255, 196, 64)
fill.BorderSizePixel = 0
fill.Parent = track
local fillCorner = trackCorner:Clone()
fillCorner.Parent = fill

local tip = Instance.new("TextLabel")
tip.BackgroundTransparency = 1
tip.AnchorPoint = Vector2.new(0.5, 0)
tip.Position = UDim2.new(0.5, 0, 0.5, 96)
tip.Size = UDim2.new(0.85, 0, 0, 48)
tip.Font = Enum.Font.GothamBold
tip.TextScaled = true
tip.TextWrapped = true
tip.TextColor3 = Color3.fromRGB(220, 226, 240)
tip.Text = TIPS[math.random(1, #TIPS)]
tip.Parent = background
local tipSize = Instance.new("UITextSizeConstraint")
tipSize.MaxTextSize = 20
tipSize.Parent = tip

gui.Parent = player:WaitForChild("PlayerGui")

-- Spin the storm and change the tip now and then.
local started = os.clock()
local spin = RunService.RenderStepped:Connect(function(dt)
	storm.Rotation = (storm.Rotation + dt * 90) % 360
end)
task.spawn(function()
	while gui.Parent do
		task.wait(4)
		tip.Text = TIPS[math.random(1, #TIPS)]
	end
end)

local function progress(share: number)
	TweenService:Create(fill, TweenInfo.new(0.3), { Size = UDim2.fromScale(math.clamp(share, 0.05, 1), 1) }):Play()
end

-- 1. The game itself.
if not game:IsLoaded() then
	game.Loaded:Wait()
end
progress(0.4)
-- 2. The lobby (its spawn) and your character.
workspace:WaitForChild("World", 30)
progress(0.6)
local character = player.Character or player.CharacterAdded:Wait()
character:WaitForChild("HumanoidRootPart", 20)
progress(0.8)
-- 3. Whatever's still downloading, but never more than a few seconds.
local waitUntil = os.clock() + 4
while ContentProvider.RequestQueueSize > 0 and os.clock() < waitUntil do
	task.wait(0.2)
end
progress(1)
-- Show it for at least a moment so it doesn't flash.
task.wait(math.max(0, 1.5 - (os.clock() - started)))

local fade = TweenInfo.new(0.6)
TweenService:Create(background, fade, { BackgroundTransparency = 1 }):Play()
for _, item in background:GetDescendants() do
	if item:IsA("TextLabel") then
		TweenService:Create(item, fade, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	elseif item:IsA("Frame") then
		TweenService:Create(item, fade, { BackgroundTransparency = 1 }):Play()
	end
end
task.wait(0.7)
spin:Disconnect()
gui:Destroy()
