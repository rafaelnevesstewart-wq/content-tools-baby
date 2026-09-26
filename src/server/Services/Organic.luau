-- Rounded, lumpy creature shapes that keep their material's real texture.
--
-- A SpecialMesh sphere draws smooth, flat plastic whatever the material, which
-- is what made titans and monsters look like toys. Instead a round part
-- becomes a Ball (when it is roughly round) or a cluster of overlapping balls
-- that follows its ellipsoid, so slate, rock and leather show their grain and
-- the silhouette reads as muscle and hide. Very flat shapes (rims, fins) keep
-- the old mesh, because they would need too many balls.

local Organic = {}

local MAX_LUMPS = 14

local function sphereMesh(part: BasePart)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
end

local function lump(source: BasePart, diameter: number, offset: CFrame, welded: boolean)
	local ball = Instance.new("Part")
	ball.Name = source.Name .. "Lump"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * diameter
	ball.Color = source.Color
	ball.Material = source.Material
	ball.Reflectance = source.Reflectance
	ball.CastShadow = source.CastShadow
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.Massless = true
	ball.TopSurface = Enum.SurfaceType.Smooth
	ball.BottomSurface = Enum.SurfaceType.Smooth
	ball.CFrame = source.CFrame * offset
	ball.Anchored = not welded
	if welded then
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = source
		weld.Part1 = ball
		weld.Parent = ball
	end
	ball.Parent = source
	return ball
end

-- Makes `part` look like a natural ellipsoid of its current size.
-- welded: true when the part belongs to a physics assembly (titans), false
-- for anchored models (monsters).
function Organic.shape(part: BasePart, welded: boolean)
	local size = part.Size
	local dims = { size.X, size.Y, size.Z }
	local smallest = math.min(size.X, size.Y, size.Z)
	local largest = math.max(size.X, size.Y, size.Z)

	if largest / smallest <= 1.3 then
		-- Round enough: one textured ball.
		local diameter = (size.X + size.Y + size.Z) / 3
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.one * diameter
		return part
	end
	if smallest / largest < 0.28 then
		sphereMesh(part)
		return part
	end

	-- Cluster: a grid of balls across the two longer axes, each ball as thick
	-- as the shortest axis, shrinking towards the edges of the ellipse.
	local short = 1
	for i = 2, 3 do
		if dims[i] < dims[short] then
			short = i
		end
	end
	local axisU = short == 1 and 2 or 1
	local axisV = 6 - short - axisU
	local diameter = smallest
	local countU, countV
	repeat
		countU = math.max(1, math.floor(dims[axisU] / diameter * 1.25 + 0.5))
		countV = math.max(1, math.floor(dims[axisV] / diameter * 1.25 + 0.5))
		if countU * countV > MAX_LUMPS then
			diameter *= 1.15
		end
	until countU * countV <= MAX_LUMPS

	local function spread(count: number, length: number, index: number): number
		if count == 1 then
			return 0
		end
		local span = math.max(0, length - diameter)
		return -span / 2 + span * (index / (count - 1))
	end
	for i = 0, countU - 1 do
		for j = 0, countV - 1 do
			local u = spread(countU, dims[axisU], i)
			local v = spread(countV, dims[axisV], j)
			local edge = (u / (dims[axisU] / 2)) ^ 2 + (v / (dims[axisV] / 2)) ^ 2
			local scale = math.clamp(math.sqrt(math.max(0, 1 - edge * 0.55)), 0.6, 1)
			local offset = { 0, 0, 0 }
			offset[axisU] = u
			offset[axisV] = v
			lump(part, math.min(diameter, smallest * 1.15) * scale, CFrame.new(offset[1], offset[2], offset[3]), welded)
		end
	end
	part.Transparency = 1
	return part
end

return Organic
