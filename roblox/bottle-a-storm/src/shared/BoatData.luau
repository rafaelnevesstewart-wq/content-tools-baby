--!strict
-- 🚤 The Sky Boat Race (BoatService): take a flying boat from the dock by the
-- castle gate and fly through every ring around the lobby islands, in
-- order, as fast as you can. Your boat flies where you look.

local Config = require(script.Parent.Config)

local L = Config.Lobby.Center

local BoatData = {}

BoatData.Dock = L + Vector3.new(62, 0, 48)
BoatData.Start = CFrame.lookAt(L + Vector3.new(62, 10, 60), L + Vector3.new(60, 18, 110))
BoatData.RingRadius = 10
BoatData.Speed = 72 -- studs a second at full speed
BoatData.TimeLimit = 180
BoatData.StartSparks = 900 -- prize: this minus 5 per second...
BoatData.MinSparks = 150 -- ...but never less than this

BoatData.Rings = {
	L + Vector3.new(60, 18, 110),
	L + Vector3.new(160, 22, 100),
	L + Vector3.new(265, 28, 80),
	L + Vector3.new(305, 24, 0),
	L + Vector3.new(265, 30, -80),
	L + Vector3.new(150, 34, -140),
	L + Vector3.new(60, 38, -200),
	L + Vector3.new(0, 30, -265),
	L + Vector3.new(-60, 26, -200),
	L + Vector3.new(-150, 30, -140),
	L + Vector3.new(-280, 24, -80),
	L + Vector3.new(-320, 20, 0),
	L + Vector3.new(-280, 26, 90),
	L + Vector3.new(-160, 22, 115),
	L + Vector3.new(-60, 40, 125),
	L + Vector3.new(95, 26, 70),
} :: { Vector3 }

return BoatData
