-- Kit powers the server has to run (the others move your own character, so
-- KitController runs them on your screen):
--   💚 Healing Rain    heals you and teammates near you
--   🌉 Instant Bridge  builds a line of your team's blocks in front of you
--   🏹 Arrow Volley    shoots a fan of free arrows where you aim

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent.Parent.Modules
local Juice = require(Modules.Juice)

local BlockService = require(script.Parent.BlockService)
local CombatService = require(script.Parent.CombatService)
local MatchService = require(script.Parent.MatchService)

local KitPowerService = {}

local lastUse: { [Player]: { [string]: number } } = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

-- Green sparkles rising around a player.
local function healGlow(root: BasePart)
	local burst = Instance.new("ParticleEmitter")
	burst.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	burst.Color = ColorSequence.new(Color3.fromRGB(150, 255, 170), Color3.fromRGB(60, 210, 110))
	burst.Size = NumberSequence.new(0.5, 0)
	burst.Lifetime = NumberRange.new(0.8, 1.2)
	burst.Speed = NumberRange.new(3, 6)
	burst.SpreadAngle = Vector2.new(180, 30)
	burst.Acceleration = Vector3.new(0, 6, 0)
	burst.LightEmission = 1
	burst.Rate = 0
	burst.Parent = root
	burst:Emit(30)
	task.delay(1.5, function()
		burst:Destroy()
	end)
end

local POWERS: { [string]: (Player, BasePart, Vector3) -> () } = {
	Heal = function(player, root)
		local team = MatchService.teamOf(player)
		for _, other in Players:GetPlayers() do
			local otherRoot = rootOf(other)
			local humanoid = humanoidOf(other)
			local friendly = other == player or (team ~= nil and MatchService.teamOf(other) == team)
			if
				friendly
				and otherRoot
				and humanoid
				and humanoid.Health > 0
				and MatchService.isPlaying(other)
				and (otherRoot.Position - root.Position).Magnitude <= Config.Kit.HealRange
			then
				humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + Config.Kit.HealAmount)
				healGlow(otherRoot)
				Juice.float(other, "+" .. Config.Kit.HealAmount .. " 💚", otherRoot.Position + Vector3.new(0, 3, 0))
				Juice.sound(other, "chime")
			end
		end
	end,

	Bridge = function(player, root, direction)
		local flat = direction * Vector3.new(1, 0, 1)
		if flat.Magnitude < 0.1 then
			flat = root.CFrame.LookVector * Vector3.new(1, 0, 1)
		end
		flat = flat.Unit
		local size = Config.Match.BlockSize
		-- The row just under your feet, so you can walk straight onto it.
		local feet = root.Position - Vector3.new(0, 3 + size / 2, 0)
		task.spawn(function()
			for step = 1, Config.Kit.BridgeLength do
				if not MatchService.isPlaying(player) then
					return
				end
				if BlockService.placeFor(player, feet + flat * size * step, "CloudWool") then
					Juice.sound(player, "pop")
				end
				task.wait(0.06)
			end
		end)
	end,

	Volley = function(player, _root, aim)
		task.spawn(CombatService.volley, player, aim, Config.Kit.VolleyArrows)
		Juice.sound(player, "arrow")
	end,
}

local function onPower(player: Player, ability: any, vector: any)
	local power = type(ability) == "string" and POWERS[ability]
	if not power or typeof(vector) ~= "Vector3" or not MatchService.isPlaying(player) then
		return
	end
	-- It must be the power of the kit you brought, and recharged.
	if player:GetAttribute("RideAbility") ~= ability then
		return
	end
	local used = lastUse[player] or {}
	lastUse[player] = used
	local scale = player:GetAttribute("KitCooldown")
	local cooldown = (Config.Kit.Cooldowns[ability] or 10) * (if type(scale) == "number" then scale else 1)
	if os.clock() - (used[ability] or 0) < cooldown - 0.5 then
		return
	end
	local root = rootOf(player)
	local humanoid = humanoidOf(player)
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	used[ability] = os.clock()
	power(player, root, vector)
end

function KitPowerService.start()
	Remotes.event("KitPower").OnServerEvent:Connect(onPower)
	Players.PlayerRemoving:Connect(function(player)
		lastUse[player] = nil
	end)
end

return KitPowerService
