-- Whether a player is in the middle of something a teleport or another
-- activity would break: a match, a 1v1 or 2v2 fight, or the boat race.
-- Features that move people around or start something ask first.

local Busy = {}

-- Why a player is busy (nil if they're free).
function Busy.reason(player: Player): string?
	if player:GetAttribute("InMatch") then
		return "in a match"
	elseif player:GetAttribute("Dueling") then
		return "in a fight"
	elseif player:GetAttribute("Boating") then
		return "in the boat race"
	end
	return nil
end

return Busy
