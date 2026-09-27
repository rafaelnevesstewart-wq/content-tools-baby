-- Brings every storm creature to life on this screen: a gentle bob and a
-- slow drifting sway, like a real cloud. Storms are tagged "StormCreature" by
-- StormModel; their visible parts hang off a "BodyWeld" we animate locally.
-- At night every storm glows softly in its own color.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local StormAnimator = {}

local DRAW_DISTANCE = 170 -- storms farther than this don't animate

type Tracked = {
	weld: Weld,
	phase: number,
	scale: number,
}

local tracked: { [Model]: Tracked } = {}
local rng = Random.new()

local function add(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local root = instance:WaitForChild("Root", 5)
	local weld = root and root:WaitForChild("BodyWeld", 5)
	if not weld or not weld:IsA("Weld") or not instance.Parent then
		return
	end
	local scale = instance:GetAttribute("Scale")
	tracked[instance] = {
		weld = weld,
		phase = rng:NextNumber(0, math.pi * 2),
		scale = if type(scale) == "number" then scale else 1,
	}
end

-- 0 in the day, 1 at night (same curve as the server's day cycle).
local function nightness(): number
	local clock = Lighting.ClockTime
	if clock >= 7 and clock <= 17 then
		return 0
	elseif clock > 17 and clock < 19 then
		return (clock - 17) / 2
	elseif clock > 5 and clock < 7 then
		return (7 - clock) / 2
	end
	return 1
end

local function updateNightGlow()
	local night = nightness()
	for model, entry in tracked do
		local root = entry.weld.Part0
		if not root then
			continue
		end
		local glow = root:FindFirstChild("NightGlow") :: PointLight?
		if night <= 0 then
			if glow then
				glow.Enabled = false
			end
			continue
		end
		if not glow then
			local body = entry.weld.Part1
			local light = Instance.new("PointLight")
			light.Name = "NightGlow"
			light.Color = if body then body.Color:Lerp(Color3.new(1, 1, 1), 0.3) else Color3.new(1, 1, 1)
			light.Range = 10 * entry.scale
			light.Shadows = false
			light.Parent = root
			glow = light
		end
		local light = glow :: PointLight
		light.Enabled = model.Parent ~= nil
		light.Brightness = 1.4 * night
	end
end

function StormAnimator.start()
	for _, model in CollectionService:GetTagged("StormCreature") do
		task.spawn(add, model)
	end
	CollectionService:GetInstanceAddedSignal("StormCreature"):Connect(add)
	CollectionService:GetInstanceRemovedSignal("StormCreature"):Connect(function(model)
		tracked[model :: Model] = nil
	end)

	task.spawn(function()
		while true do
			updateNightGlow()
			task.wait(1)
		end
	end)

	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local eye = camera.CFrame.Position
		local t = os.clock()
		for model, entry in tracked do
			local root = entry.weld.Part0
			if not model.Parent or not root then
				tracked[model] = nil
				continue
			end
			if (root.Position - eye).Magnitude > DRAW_DISTANCE then
				continue
			end
			local p = entry.phase
			local bob = math.sin(t * 1.3 + p) * 0.25 * entry.scale
			local sway = math.sin(t * 0.8 + p) * 0.05
			local nod = math.sin(t * 0.9 + p) * 0.03
			entry.weld.C0 = CFrame.new(0, bob, 0) * CFrame.Angles(nod, 0, sway)
		end
	end)
end

return StormAnimator
