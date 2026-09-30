--[[
	TeamLogic
	Pure team balancing rules.
]]

local TeamLogic = {}

-- counts: { [teamId] = number } excluding the requesting player.
function TeamLogic.canJoin(counts, targetId, maxDifference)
	local target = counts[targetId]
	if target == nil then
		return false
	end
	for id, count in pairs(counts) do
		if id ~= targetId and target + 1 - count > maxDifference then
			return false
		end
	end
	return true
end

-- Picks the smallest team; ties broken by the order of teamIds.
function TeamLogic.pickAuto(counts, teamIds)
	local best, bestCount = nil, math.huge
	for _, id in ipairs(teamIds) do
		local c = counts[id] or 0
		if c < bestCount then
			best, bestCount = id, c
		end
	end
	return best
end

return TeamLogic
