--[[
	TicketLogic
	Pure helpers for ticket bleed and victory resolution.
]]

local TicketLogic = {}

--[[
	bleedRates(owned, teamIds, totalZones, config) -> { [teamId] = ticketsPerSecond }
	A team bleeds only while the opposing team holds a majority of objectives;
	the rate scales with the objective difference.
]]
function TicketLogic.bleedRates(owned, teamIds, totalZones, config)
	local rates = {}
	local a, b = teamIds[1], teamIds[2]
	local ownedA, ownedB = owned[a] or 0, owned[b] or 0
	rates[a] = 0
	rates[b] = 0
	local majority = totalZones / 2
	if ownedB > majority and ownedB > ownedA then
		rates[a] = (ownedB - ownedA) * config.BleedPerPointPerSecond
	elseif ownedA > majority and ownedA > ownedB then
		rates[b] = (ownedA - ownedB) * config.BleedPerPointPerSecond
	end
	return rates
end

--[[
	resolveWinner(tickets, teamIds, timeUp) -> teamId | "Draw" | nil
	nil means the match continues.
]]
function TicketLogic.resolveWinner(tickets, teamIds, timeUp)
	local a, b = teamIds[1], teamIds[2]
	local ta, tb = tickets[a], tickets[b]
	if ta <= 0 and tb <= 0 then
		return "Draw"
	elseif ta <= 0 then
		return b
	elseif tb <= 0 then
		return a
	end
	if timeUp then
		if ta > tb then
			return a
		elseif tb > ta then
			return b
		end
		return "Draw"
	end
	return nil
end

return TicketLogic
