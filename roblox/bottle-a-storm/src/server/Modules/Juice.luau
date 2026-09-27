-- Little feel-good effects that only one player needs to see or hear:
-- floating numbers, sparkle bursts, sounds and screen shake. The client side
-- is JuiceController.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local juice = Remotes.event("Juice")

local Juice = {}

-- Floating text that rises and fades at a spot, with a sparkle burst.
function Juice.float(player: Player, text: string, position: Vector3, color: Color3?)
	juice:FireClient(player, "float", text, position, color)
end

-- A sound from src/shared/Sounds.luau, e.g. "pop", "coins", "zap", "chime".
function Juice.sound(player: Player, name: string)
	juice:FireClient(player, "sound", name)
end

-- The "welcome back" pop-up with what your storms earned while you were away.
function Juice.welcome(player: Player, amount: number, awaySeconds: number)
	juice:FireClient(player, "welcome", amount, awaySeconds)
end

-- The big rare-catch moment: a screen flash, a camera zoom on the storm and
-- a banner with its name.
function Juice.rareCatch(player: Player, name: string, rarityName: string, color: Color3, position: Vector3)
	juice:FireClient(player, "rareCatch", name, rarityName, color, position)
end

-- Pushes the player's character (their own screen moves it). Used by water
-- balloons and grumpy cloud raindrops.
function Juice.knock(player: Player, velocity: Vector3)
	juice:FireClient(player, "knock", velocity)
end

-- Shakes the player's camera.
function Juice.shake(player: Player, strength: number?)
	juice:FireClient(player, "shake", strength or 1)
end

return Juice
