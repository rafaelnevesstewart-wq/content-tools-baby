-- One-off visual effects everyone can see.

local Debris = game:GetService("Debris")

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

return Effects
