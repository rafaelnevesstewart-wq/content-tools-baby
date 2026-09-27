-- Throwing the Storm Jar. When you click or tap with the jar in hand, this
-- finds the wild storm closest to where you aimed (a little aim assist) and
-- tells the server to throw there. The server decides hit, dodge or catch.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local Aim = require(script.Parent.Aim)
local Sfx = require(script.Parent.Sfx)

local ThrowController = {}

local AIM_ASSIST = 4 -- studs around a storm that still count as aiming at it

function ThrowController.start()
	Aim.hookTool("Storm Jar", function()
		Sfx.play("throw", 0.9 + math.random() * 0.2)
		Remotes.event("ThrowJar"):FireServer(Aim.point(Aim.rootsIn("WildStorms"), AIM_ASSIST))
	end)
end

return ThrowController
