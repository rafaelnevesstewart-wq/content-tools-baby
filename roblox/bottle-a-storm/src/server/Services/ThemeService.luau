-- Island themes (see ThemeData): bought and picked in the Shop, then applied
-- by recoloring the island's ground, underside and decorations. The
-- original colors are remembered so Meadow (and empty islands) look like new.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Format)
local ThemeData = require(Shared.ThemeData)

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)

local ThemeService = {}

local themedIsland: { [Player]: Model } = {}

local function remember(part: BasePart)
	if part:GetAttribute("BaseColor") == nil then
		part:SetAttribute("BaseColor", part.Color)
		part:SetAttribute("BaseMaterial", part.Material.Name)
	end
end

local function restore(part: BasePart)
	local color = part:GetAttribute("BaseColor")
	local material = part:GetAttribute("BaseMaterial")
	if typeof(color) == "Color3" then
		part.Color = color
	end
	if type(material) == "string" then
		part.Material = (Enum.Material :: any)[material]
	end
end

-- The island parts a theme changes: the ground, the top underside layer and
-- every decoration.
local function themedParts(island: Model): { BasePart }
	local parts = {}
	for _, name in { "Ground", "Underside1" } do
		local part = island:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			table.insert(parts, part)
		end
	end
	local decor = island:FindFirstChild("Decor")
	if decor then
		for _, part in decor:GetChildren() do
			if part:IsA("BasePart") then
				table.insert(parts, part)
			end
		end
	end
	return parts
end

local function applyTheme(island: Model, theme: ThemeData.Theme)
	-- Same seed every time, so an island always gets the same color picks.
	local index = island:GetAttribute("PlotIndex")
	local rng = Random.new(if type(index) == "number" then index else 1)
	local leaf: Color3? = nil
	for _, part in themedParts(island) do
		remember(part)
		if not theme.ground then
			restore(part)
			continue
		end
		local name = part.Name
		if name == "Ground" then
			part.Color = theme.ground
			part.Material = theme.groundMaterial or part.Material
		elseif name == "Underside1" and theme.underside then
			part.Color = theme.underside
		elseif name == "TreeTrunk" and theme.trunk then
			part.Color = theme.trunk
			-- The tops that follow this trunk share one color.
			local leaves = theme.leaves
			leaf = if leaves then leaves[rng:NextInteger(1, #leaves)] else nil
		elseif (name == "TreeTop" or name == "Bush") and theme.leaves then
			local base = if name == "TreeTop" and leaf then leaf else theme.leaves[rng:NextInteger(1, #theme.leaves)]
			part.Color = base:Lerp(Color3.new(1, 1, 1), rng:NextNumber(0, 0.15))
		elseif (name == "Petals" or name == "MushroomCap") and theme.flowers then
			part.Color = theme.flowers[rng:NextInteger(1, #theme.flowers)]
		end
	end
end

local function publish(player: Player, data: any)
	local owned = {}
	for key in data.themes do
		table.insert(owned, key)
	end
	player:SetAttribute("Theme", data.theme)
	player:SetAttribute("UnlockedThemes", table.concat(owned, ","))
end

local function refresh(player: Player)
	local data = DataService.get(player)
	local plot = PlotService.getPlot(player)
	if not data or not plot then
		return
	end
	local theme = ThemeData.get(data.theme) or ThemeData.List[1]
	applyTheme(plot.model, theme)
	themedIsland[player] = plot.model
	publish(player, data)
end

-- "Theme:Candy" from the Shop: buy it with Sparks, or switch to it if owned.
function ThemeService.buyOrEquip(player: Player, key: string): (boolean, string)
	local data = DataService.get(player)
	local theme = ThemeData.get(key)
	if not data or not theme then
		return false, "Unknown theme."
	end
	if data.theme == theme.key then
		return false, "Your island already looks like that!"
	end
	if not data.themes[theme.key] then
		if data.sparks < theme.cost then
			return false, "You need ⚡" .. Format.number(theme.cost - data.sparks) .. " more Sparks."
		end
		data.sparks -= theme.cost
		data.themes[theme.key] = true
	end
	data.theme = theme.key
	refresh(player)
	return true, theme.emoji .. " Your island is now " .. theme.name .. "!"
end

function ThemeService.start()
	PlotService.PlotAssigned:Connect(refresh)
	Players.PlayerRemoving:Connect(function(player)
		local island = themedIsland[player]
		themedIsland[player] = nil
		if island then
			applyTheme(island, ThemeData.List[1]) -- back to Meadow for the next owner
		end
	end)
end

return ThemeService
