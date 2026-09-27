-- Optional real 3D models for titans and monsters (ARK-style detail).
--
-- Put models in ServerStorage > CreatureModels, named:
--   Titan_Shellback, Titan_Mossback, Titan_Tuskhorn, Titan_Driftfin (or just
--   "Titan" for every species), and Monster_Gloomling, Monster_Gloomhound,
--   Monster_Thornback, Monster_Golem, Monster_StormKing.
-- The game scales each one to the right size, stands it on the ground under
-- the titan's deck (or in place of the monster), and hides the built-in body.
-- Deck, ladders, saddle and everything you stand on stay the same.
-- Names don't care about capitals, spaces or dashes, and a model left in the
-- Workspace or loose in ServerStorage is picked up too.
-- If a model faces the wrong way, give it a number attribute "YawDegrees"
-- (e.g. 90 or 180). Scripts inside models are removed for safety.

local ServerStorage = game:GetService("ServerStorage")

local CreatureModels = {}

local SLOTS = {
	"Titan",
	"Titan_Shellback",
	"Titan_Mossback",
	"Titan_Tuskhorn",
	"Titan_Driftfin",
	"Monster_Gloomling",
	"Monster_Gloomhound",
	"Monster_Thornback",
	"Monster_Golem",
	"Monster_StormKing",
}

-- "monster gloomling", "Monster_Gloomling " and "MONSTER-GLOOMLING" all match.
local function key(name: string): string
	return (string.lower(name):gsub("[%s_%-]", ""))
end

local slotByKey = {}
for _, slot in SLOTS do
	slotByKey[key(slot)] = slot
end

local folder: Folder

-- Imports can arrive as a single MeshPart rather than a Model; wrap those.
local function asModel(instance: Instance): Model?
	if instance:IsA("Model") then
		return instance
	elseif instance:IsA("BasePart") or instance:IsA("Folder") then
		local model = Instance.new("Model")
		model.Name = instance.Name
		for name, value in instance:GetAttributes() do
			model:SetAttribute(name, value)
		end
		instance.Parent = model
		if instance:IsA("Folder") then
			for _, child in instance:GetChildren() do
				child.Parent = model
			end
			instance:Destroy()
		end
		return model
	end
	return nil
end

-- Gathers every model named after a slot, wherever it was left (ServerStorage,
-- its CreatureModels folder, or the Workspace), into ServerStorage.CreatureModels
-- under its exact slot name. Runs once when the server starts.
local function collect()
	folder = ServerStorage:FindFirstChild("CreatureModels") :: Folder
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "CreatureModels"
		folder.Parent = ServerStorage
	end
	local found = {}
	for _, place in { folder, ServerStorage, workspace } do
		for _, child in place:GetChildren() do
			local slot = slotByKey[key(child.Name)]
			if slot and not found[slot] then
				local model = asModel(child)
				if model then
					model.Name = slot
					model.Parent = folder
					found[slot] = true
				end
			end
		end
	end
	local names = {}
	for slot in found do
		table.insert(names, slot)
	end
	table.sort(names)
	if #names > 0 then
		print("[CreatureModels] Using 3D models: " .. table.concat(names, ", "))
	else
		print("[CreatureModels] No 3D models found. Name them like Monster_Gloomling and put them in ServerStorage > CreatureModels.")
	end
end
collect()

local function template(name: string): Model?
	local found = folder:FindFirstChild(name)
	if found and found:IsA("Model") then
		return found
	end
	return nil
end

-- Returns a cleaned, scaled clone whose bounding box is `height` tall and
-- centred at `center`, or nil if no model is set up under that name.
function CreatureModels.place(names: { string }, height: number, center: CFrame): Model?
	local source = nil
	for _, name in names do
		source = template(name)
		if source then
			break
		end
	end
	if not source then
		return nil
	end
	local model = source:Clone()
	for _, descendant in model:GetDescendants() do
		-- Free models can carry scripts; never run them. A Humanoid would
		-- also fight the constraints that move the creature.
		if descendant:IsA("LuaSourceContainer") or descendant:IsA("Humanoid") then
			descendant:Destroy()
		end
	end
	local _, size = model:GetBoundingBox()
	if size.Y <= 0.05 then
		return nil
	end
	model:ScaleTo(model:GetScale() * height / size.Y)
	local box = model:GetBoundingBox()
	local yaw = math.rad(tonumber(source:GetAttribute("YawDegrees")) or 0)
	-- Keep the pivot where it sits relative to the box, but put the box at `center`.
	model:PivotTo(center * CFrame.Angles(0, yaw, 0) * box:ToObjectSpace(model:GetPivot()))
	return model
end

-- Hides the built-in body parts (anything not named in `keep`) and their
-- particle and light effects.
function CreatureModels.hideBuiltIn(model: Instance, keep: { [string]: boolean }, skipFolder: Instance?)
	for _, descendant in model:GetDescendants() do
		if skipFolder and descendant:IsDescendantOf(skipFolder) then
			continue
		end
		if descendant:IsA("BasePart") and not keep[descendant.Name] then
			descendant.Transparency = 1
		elseif (descendant:IsA("ParticleEmitter") or descendant:IsA("Light")) and descendant.Parent and not keep[descendant.Parent.Name] then
			descendant.Enabled = false
		end
	end
end

-- Makes every part of a placed model non-colliding and either welded to
-- `root` (titans, which are physics assemblies) or anchored (monsters).
function CreatureModels.attach(custom: Model, root: BasePart, welded: boolean)
	for _, descendant in custom:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
			descendant.Anchored = not welded
			if welded then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = root
				weld.Part1 = descendant
				weld.Parent = descendant
			end
		end
	end
end

return CreatureModels
