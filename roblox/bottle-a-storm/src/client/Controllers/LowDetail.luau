-- ⚡ Faster mode (⚙️ Settings → "Faster mode"): hides the little things only
-- on your screen (flowers, mushrooms, bushes, tree roots and branches, map
-- props like coral and seaweed, glass bubbles) so slow phones and computers
-- run smoother. Turning it off brings them all back.

local Settings = require(script.Parent.Settings)

local LowDetail = {}

-- Names of the small decorations (WorldBuilder and MapService).
local SMALL: { [string]: boolean } = {
	Stem = true,
	Petals = true,
	FlowerMiddle = true,
	MushroomStem = true,
	MushroomCap = true,
	Bush = true,
	TreeRoot = true,
	TreeBranch = true,
	BubbleDome = true,
}

local hidden: { [Instance]: Instance } = {} -- thing -> where it was
local watching: RBXScriptConnection? = nil

local function isSmall(item: Instance): boolean
	if not item:IsA("BasePart") then
		return false
	end
	if SMALL[item.Name] then
		return true
	end
	-- Map props you can't bump into (hiding solid ones would let you walk
	-- through things that are really there).
	local props = item:FindFirstAncestor("MapProps")
	return props ~= nil and not item.CanCollide
end

local function hide(item: Instance)
	if hidden[item] == nil and item.Parent and isSmall(item) then
		hidden[item] = item.Parent
		item.Parent = nil
	end
end

local function apply(on: boolean)
	if on then
		for _, item in workspace:GetDescendants() do
			hide(item)
		end
		if not watching then
			watching = workspace.DescendantAdded:Connect(function(item)
				if item:IsA("BasePart") then
					task.defer(hide, item)
				end
			end)
		end
	else
		if watching then
			watching:Disconnect()
			watching = nil
		end
		for item, parent in hidden do
			if parent.Parent then
				item.Parent = parent
			end
		end
		hidden = {}
	end
end

function LowDetail.start()
	-- Forget things whose home is gone (a finished match's props).
	task.spawn(function()
		while true do
			task.wait(60)
			for item, parent in hidden do
				if not parent:IsDescendantOf(game) then
					hidden[item] = nil
				end
			end
		end
	end)
	task.delay(3, function()
		apply(Settings.get("lowDetail") == true)
	end)
	Settings.Changed:Connect(function(key, value)
		if key == "lowDetail" then
			apply(value == true)
		end
	end)
end

return LowDetail
