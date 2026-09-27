-- One-off visual effects everyone can see.

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Effects = {}

local CONFETTI = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 130, 170)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 100)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(120, 230, 170)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(130, 190, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 140, 255)),
})

-- A burst of colorful confetti at a point.
function Effects.confetti(position: Vector3, amount: number?)
	local holder = Instance.new("Part")
	holder.Name = "Confetti"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanTouch = false
	holder.CanQuery = false
	holder.Transparency = 1
	holder.Size = Vector3.new(1, 1, 1)
	holder.CFrame = CFrame.new(position)
	holder.Parent = workspace

	local burst = Instance.new("ParticleEmitter")
	burst.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	burst.Color = CONFETTI
	burst.Size = NumberSequence.new(0.6, 0.2)
	burst.Speed = NumberRange.new(18, 34)
	burst.SpreadAngle = Vector2.new(55, 55)
	burst.Acceleration = Vector3.new(0, -35, 0)
	burst.Drag = 2
	burst.Lifetime = NumberRange.new(1, 1.8)
	burst.Rotation = NumberRange.new(0, 360)
	burst.RotSpeed = NumberRange.new(-300, 300)
	burst.LightEmission = 0.4
	burst.EmissionDirection = Enum.NormalId.Top
	burst.Rate = 0
	burst.Parent = holder
	burst:Emit(amount or 50)

	Debris:AddItem(holder, 2.5)
end

-- A burst of water drops (water balloons and raindrops).
function Effects.splash(position: Vector3, color: Color3?)
	local holder = Instance.new("Part")
	holder.Name = "Splash"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanTouch = false
	holder.CanQuery = false
	holder.Transparency = 1
	holder.Size = Vector3.new(1, 1, 1)
	holder.CFrame = CFrame.new(position)
	holder.Parent = workspace

	local drops = Instance.new("ParticleEmitter")
	drops.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	drops.Color = ColorSequence.new(color or Color3.fromRGB(120, 200, 255), Color3.fromRGB(230, 245, 255))
	drops.Size = NumberSequence.new(0.7, 0.2)
	drops.Speed = NumberRange.new(12, 24)
	drops.SpreadAngle = Vector2.new(70, 70)
	drops.Acceleration = Vector3.new(0, -50, 0)
	drops.Lifetime = NumberRange.new(0.5, 0.9)
	drops.LightEmission = 0.3
	drops.EmissionDirection = Enum.NormalId.Top
	drops.Rate = 0
	drops.Parent = holder
	drops:Emit(35)

	Debris:AddItem(holder, 1.5)
end

-- Throws `part` in an arc from `from` to `to`, then destroys it and calls
-- `onLanded`. The part should be anchored.
function Effects.lob(part: BasePart, from: Vector3, to: Vector3, duration: number, onLanded: (() -> ())?)
	local height = math.min((to - from).Magnitude * 0.2, 10)
	local progress = Instance.new("NumberValue")
	progress.Changed:Connect(function(alpha)
		local position = from:Lerp(to, alpha) + Vector3.new(0, math.sin(alpha * math.pi) * height, 0)
		part.CFrame = CFrame.new(position) * CFrame.Angles(alpha * 6, alpha * 4, 0)
	end)
	part.CFrame = CFrame.new(from)
	part.Parent = workspace
	local tween = TweenService:Create(progress, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Value = 1 })
	tween.Completed:Connect(function()
		progress:Destroy()
		part:Destroy()
		if onLanded then
			onLanded()
		end
	end)
	tween:Play()
end

return Effects
