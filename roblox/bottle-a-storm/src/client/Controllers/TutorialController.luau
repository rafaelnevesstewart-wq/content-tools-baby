-- 🎓 The first-match tutorial on your screen (TutorialService sets
-- "Tutorial" in your very first match): a banner above your resources with
-- one step at a time. Each step moves on by itself when you've done it.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Lang = require(Shared.Lang)
local Remotes = require(Shared.Remotes)

local Sfx = require(script.Parent.Sfx)
local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local TutorialController = {}

local function resources(): number
	local total = 0
	for _, key in { "Copper", "Silver", "Crystals", "Cores" } do
		local value = player:GetAttribute("Res_" .. key)
		total += if type(value) == "number" then value else 0
	end
	return total
end

local function blocks(): number
	local total = 0
	for name, value in player:GetAttributes() do
		if string.sub(name, 1, 7) == "Blocks_" and type(value) == "number" then
			total += value
		end
	end
	return total
end

type Step = { text: string, done: (started: number, mark: any) -> boolean, mark: (() -> any)? }

local STEPS: { Step } = {
	{
		text = "tutorial.bed",
		done = function(started)
			return os.clock() - started > 8
		end,
	},
	{
		text = "tutorial.generator",
		mark = resources,
		done = function(_, before)
			return resources() >= before + 3
		end,
	},
	{
		text = "tutorial.shop",
		done = function()
			return blocks() > 0
		end,
	},
	{
		text = "tutorial.place",
		mark = blocks,
		done = function(started, before)
			return blocks() <= before - 3 or os.clock() - started > 40
		end,
	},
	{
		text = "tutorial.attack",
		done = function(started)
			return os.clock() - started > 14
		end,
	},
}

function TutorialController.start()
	local screen = UI.screen("Tutorial", 5)
	local banner = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -150),
		Size = UDim2.new(0.9, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.05,
		Visible = false,
		Parent = screen,
	}, {
		UI.corner(12),
		UI.stroke(UI.Colors.Spark, 2.5),
		UI.padding(10),
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(560, 200) }),
	})
	local counter = UI.label({
		Size = UDim2.new(1, -90, 0, 18),
		Text = "",
		TextSize = 13,
		TextColor3 = UI.Colors.Spark,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = banner,
	})
	local text = UI.label({
		Position = UDim2.fromOffset(0, 20),
		Size = UDim2.new(1, -90, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = "",
		TextSize = 17,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = banner,
	})
	local skip = UI.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(80, 30),
		Text = Lang.t("tutorial.skip"),
		TextSize = 13,
		BackgroundColor3 = UI.Colors.PanelLight,
		Parent = banner,
	})

	local index = 0
	local started = 0
	local mark: any = nil
	local function go(to: number)
		index = to
		local step = STEPS[index]
		if not step then
			banner.Visible = false
			Remotes.event("TutorialDone"):FireServer()
			return
		end
		started = os.clock()
		mark = if step.mark then step.mark() else nil
		counter.Text = Lang.t("tutorial.title") .. "  " .. index .. "/" .. #STEPS
		text.Text = Lang.t(step.text)
		banner.Visible = true
		Sfx.play("chime")
	end
	skip.Activated:Connect(function()
		go(#STEPS + 1)
	end)
	player:GetAttributeChangedSignal("Tutorial"):Connect(function()
		if player:GetAttribute("Tutorial") then
			go(1)
		else
			banner.Visible = false
			index = 0
		end
	end)
	local last = 0
	RunService.Heartbeat:Connect(function()
		if index == 0 or os.clock() - last < 0.5 then
			return
		end
		last = os.clock()
		local step = STEPS[index]
		if step and step.done(started, mark) then
			go(index + 1)
		end
	end)
end

return TutorialController
