-- 💬 Taunts and voice lines (TauntData): a speech bubble over your head for a
-- few seconds with a sound everyone near you hears. Your character also
-- speaks up by itself after a knockout, a broken bed or a win.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Sounds = require(Shared.Sounds)
local TauntData = require(Shared.TauntData)

local MatchService = require(script.Parent.MatchService)

local TauntService = {}

local lastSaid: { [Player]: number } = {}
local rng = Random.new()

-- Shows `text` over a player's head and plays a sound from their head.
function TauntService.say(player: Player, text: string, soundName: string?, pitch: number?)
	local character = player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local old = head:FindFirstChild("TauntBubble")
	if old then
		old:Destroy()
	end
	local bubble = Instance.new("BillboardGui")
	bubble.Name = "TauntBubble"
	bubble:SetAttribute("OwnerId", player.UserId)
	bubble.Size = UDim2.fromOffset(220, 44)
	bubble.StudsOffset = Vector3.new(0, 5.4, 0)
	bubble.MaxDistance = 90
	bubble.Parent = head
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.Parent = bubble
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = frame
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -12, 1, -6)
	label.Position = UDim2.fromOffset(6, 3)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(30, 30, 40)
	label.Text = text
	label.Parent = frame
	CollectionService:AddTag(bubble, "TauntBubble")
	Debris:AddItem(bubble, 3.2)
	local info = soundName and Sounds[soundName]
	if info then
		local sound = Instance.new("Sound")
		sound.SoundId = info.id
		sound.Volume = info.volume
		sound.PlaybackSpeed = info.pitch * (pitch or 1)
		sound.RollOffMaxDistance = 70
		sound.Parent = head
		sound:Play()
		Debris:AddItem(sound, 3)
	end
end

local function auto(player: Player, kind: string, chance: number)
	local lines = TauntData.Auto[kind]
	if not lines or rng:NextNumber() > chance or os.clock() - (lastSaid[player] or 0) < 2 then
		return
	end
	lastSaid[player] = os.clock()
	TauntService.say(player, lines[rng:NextInteger(1, #lines)], "pop", 1.2)
end

function TauntService.start()
	Remotes.event("Taunt").OnServerEvent:Connect(function(player, key)
		local taunt = type(key) == "string" and TauntData.get(key)
		if not taunt or os.clock() - (lastSaid[player] or 0) < 3 then
			return
		end
		lastSaid[player] = os.clock()
		TauntService.say(player, taunt.text, taunt.sound, taunt.pitch)
	end)
	MatchService.Killed:Connect(function(killer)
		auto(killer, "kill", 0.45)
	end)
	MatchService.BedBroken:Connect(function(breaker)
		auto(breaker, "bed", 1)
	end)
	MatchService.Won:Connect(function(player)
		task.delay(math.random() * 1.5, auto, player, "win", 1)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastSaid[player] = nil
	end)
end

return TauntService
