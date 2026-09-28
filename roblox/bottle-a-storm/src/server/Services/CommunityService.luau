-- Things that help the game grow: redeem codes (see Modules/Codes), the group
-- bonus (Config.Group) and the like-goal sign (Config.LikeGoal).

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent.Parent.Modules
local Codes = require(Modules.Codes)
local Notify = require(Modules.Notify)

local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local RewardService = require(script.Parent.RewardService)

local CommunityService = {}

local lastTry: { [Player]: number } = {}
local lastGroupCheck: { [Player]: number } = {}

local function redeem(player: Player, text: any): (boolean, string)
	local data = DataService.get(player)
	if not data or type(text) ~= "string" then
		return false, "Type a code first."
	end
	if os.clock() - (lastTry[player] or 0) < 2 then
		return false, "Slow down a little!"
	end
	lastTry[player] = os.clock()
	local typed = string.upper((string.gsub(text, "%s", "")))
	for _, entry in Codes do
		if entry.code == typed then
			if entry.expires and os.time() > entry.expires then
				return false, "That code has expired."
			end
			if data.codes[typed] then
				return false, "You already used that code."
			end
			local problem = RewardService.grant(player, entry.reward, nil)
			if problem then
				return false, problem
			end
			data.codes[typed] = true
			return true, "🎟️ Code " .. typed .. " redeemed!"
		end
	end
	return false, "That code doesn't exist. Check the spelling!"
end

local function checkGroup(player: Player): boolean
	if Config.Group.Id == 0 then
		return false
	end
	local ok, member = pcall(function()
		return player:IsInGroup(Config.Group.Id)
	end)
	local inGroup = ok and member == true
	local was = player:GetAttribute("InGroup") == true
	player:SetAttribute("InGroup", inGroup)
	if inGroup and not was then
		IncomeService.sync(player)
	end
	return inGroup
end

-- The like-goal sign near the lobby spawn.
local function buildLikeSign()
	local board = Instance.new("Part")
	board.Name = "LikeGoalSign"
	board.Anchored = true
	board.Size = Vector3.new(12, 6, 0.6)
	board.CFrame = CFrame.new(44, 5, -88)
	board.Color = Color3.fromRGB(96, 70, 48)
	board.Material = Enum.Material.Wood
	board.Parent = workspace
	for _, x in { -5, 5 } do
		local post = Instance.new("Part")
		post.Anchored = true
		post.Size = Vector3.new(0.6, 5, 0.6)
		post.CFrame = CFrame.new(44 + x, 1, -88)
		post.Color = Color3.fromRGB(80, 60, 42)
		post.Material = Enum.Material.Wood
		post.Parent = board
	end
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.CanvasSize = Vector2.new(480, 240)
		gui.Parent = board
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, 1)
		text.Font = Enum.Font.GothamBold
		text.TextScaled = true
		text.TextColor3 = Color3.fromRGB(245, 240, 225)
		text.Text = "👍 Like the game!\nAt "
			.. Config.LikeGoal.Goal
			.. " likes we'll post\n"
			.. Config.LikeGoal.Reward
			.. "!"
		text.Parent = gui
	end
end

function CommunityService.start()
	Remotes.func("RedeemCode").OnServerInvoke = redeem
	Remotes.func("CheckGroup").OnServerInvoke = function(player): (boolean, string)
		if Config.Group.Id == 0 then
			return false, "The group bonus isn't set up yet."
		end
		if os.clock() - (lastGroupCheck[player] or 0) < 10 then
			return false, "Wait a few seconds and try again."
		end
		lastGroupCheck[player] = os.clock()
		if checkGroup(player) then
			return true, "👥 Thanks for joining! +" .. math.floor(Config.Group.Bonus * 100) .. "% Sparks is on."
		end
		return false, "You're not in " .. Config.Group.Name .. " yet. Join it on Roblox, then check again!"
	end

	DataService.ProfileLoaded:Connect(function(player)
		if checkGroup(player) then
			Notify.player(
				player,
				"👥 Group member bonus: +" .. math.floor(Config.Group.Bonus * 100) .. "% Sparks!",
				"success"
			)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastTry[player] = nil
		lastGroupCheck[player] = nil
	end)
	buildLikeSign()
end

return CommunityService
