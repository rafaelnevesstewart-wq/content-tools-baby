-- 🚤 Flying your sky boat in the Sky Boat Race (BoatService): hold forward
-- and it flies where your camera looks; let go and it hovers. The next ring
-- glows gold with a line pointing to it, and a chip at the top right shows
-- the ring and your time (tap it to quit the race).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local BoatData = require(Shared.BoatData)
local Remotes = require(Shared.Remotes)

local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local BoatController = {}

local NEXT = Color3.fromRGB(255, 210, 80)
local NORMAL = Color3.fromRGB(90, 200, 255)

local function paintRings(current: number?)
	local course = workspace:FindFirstChild("BoatCourse")
	if not course then
		return
	end
	for index = 1, #BoatData.Rings do
		local ring = course:FindFirstChild("Ring" .. index)
		if ring then
			for _, p in ring:GetChildren() do
				if p:IsA("BasePart") and p.Name ~= "Center" then
					p.Color = if index == current or (current == nil and index == #BoatData.Rings) then NEXT else NORMAL
				end
			end
		end
	end
end

function BoatController.start()
	local chip = UI.button({
		LayoutOrder = -2,
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Color3.fromRGB(40, 120, 170),
		TextSize = 15,
		Visible = false,
		Parent = UI.sideStack(),
	})
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = chip })
	chip.Activated:Connect(function()
		Remotes.event("BoatAction"):FireServer("stop")
	end)

	-- A gold line from you to the next ring.
	local pointer = Instance.new("Part")
	pointer.Anchored = true
	pointer.CanCollide = false
	pointer.CanQuery = false
	pointer.CanTouch = false
	pointer.Transparency = 1
	pointer.Size = Vector3.one
	local far = Instance.new("Attachment")
	far.Parent = pointer
	local near = Instance.new("Attachment")
	local beam = Instance.new("Beam")
	beam.Attachment0 = near
	beam.Attachment1 = far
	beam.Color = ColorSequence.new(NEXT)
	beam.Width0 = 0.3
	beam.Width1 = 0.3
	beam.Transparency = NumberSequence.new(0.3, 0.8)
	beam.FaceCamera = true
	beam.Parent = pointer

	local velocity = Vector3.zero
	local lastRing: number? = -1
	RunService.Heartbeat:Connect(function(dt)
		local boating = player:GetAttribute("Boating") == true
		local ring = player:GetAttribute("BoatRing")
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		chip.Visible = boating
		local current = if boating and type(ring) == "number" then ring else nil
		if current ~= lastRing then
			lastRing = current
			paintRings(current)
		end
		if not boating or not root or not humanoid then
			pointer.Parent = nil
			velocity = Vector3.zero
			return
		end
		local started = player:GetAttribute("BoatStarted")
		local time = if type(started) == "number" then workspace:GetServerTimeNow() - started else 0
		chip.Text = "🚤 Ring "
			.. tostring(current)
			.. "/"
			.. #BoatData.Rings
			.. " · "
			.. string.format("%.1f", time)
			.. "s  (tap to quit)"
		-- Fly where the camera looks while moving; hover otherwise.
		local look = workspace.CurrentCamera.CFrame.LookVector
		local moving = humanoid.MoveDirection.Magnitude > 0.1
		local target = if moving then look * BoatData.Speed else Vector3.zero
		velocity = velocity:Lerp(target, math.min(1, dt * 3))
		root.AssemblyLinearVelocity = velocity
		if current and BoatData.Rings[current] then
			near.Parent = root
			pointer.CFrame = CFrame.new(BoatData.Rings[current])
			pointer.Parent = workspace
		end
	end)
end

return BoatController
