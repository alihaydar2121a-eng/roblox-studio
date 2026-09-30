--[[
	CaptureLogic
	Pure, deterministic capture-point simulation for a two-team mode.

	Control is a number in [-1, 1]: +1 means fully held by teamA, -1 fully held
	by teamB, 0 neutral. A point must be dragged through 0 (neutralized) before
	the other side can capture it. If both teams are present the point is
	contested and frozen. No Roblox APIs are used so this is unit-testable.
]]

local CaptureLogic = {}

local function clamp(x, lo, hi)
	if x < lo then
		return lo
	elseif x > hi then
		return hi
	end
	return x
end

function CaptureLogic.newState()
	return { owner = nil, control = 0, contested = false, capturingTeam = nil }
end

function CaptureLogic.captureSpeed(count, config)
	if count <= 0 then
		return 0
	end
	local counted = math.min(count, config.MaxCapturers)
	return config.RatePerSecond * (1 + (counted - 1) * config.CapturerBonus)
end

--[[
	step(state, teamA, teamB, countA, countB, dt, config)
	Returns (newState, events) where events is a list of
	{ kind = "Captured" | "Neutralized", team = teamId, previousOwner = teamId? }.
	`team` is the team responsible for the change.
]]
function CaptureLogic.step(state, teamA, teamB, countA, countB, dt, config)
	local new = {
		owner = state.owner,
		control = state.control,
		contested = false,
		capturingTeam = nil,
	}
	local events = {}

	if countA > 0 and countB > 0 then
		new.contested = true
		return new, events
	end

	local control = state.control
	if countA > 0 or countB > 0 then
		local dir = countA > 0 and 1 or -1
		local speed = CaptureLogic.captureSpeed(countA > 0 and countA or countB, config)
		local target = dir -- the side being pushed toward
		if (dir == 1 and control < 1) or (dir == -1 and control > -1) then
			new.capturingTeam = dir == 1 and teamA or teamB
		end
		control = clamp(control + dir * speed * dt, -1, 1)
		if math.abs(control - target) < 1e-9 then
			control = target
		end
	else
		-- Nobody present: drift back toward the owner (or toward neutral if unowned).
		local rest = 0
		if state.owner == teamA then
			rest = 1
		elseif state.owner == teamB then
			rest = -1
		end
		local step = config.IdleRecoverPerSecond * dt
		if control < rest then
			control = math.min(rest, control + step)
		elseif control > rest then
			control = math.max(rest, control - step)
		end
	end

	-- Ownership transitions.
	local owner = state.owner
	if owner == teamA and control <= 0 then
		table.insert(events, { kind = "Neutralized", team = teamB, previousOwner = teamA })
		owner = nil
	elseif owner == teamB and control >= 0 then
		table.insert(events, { kind = "Neutralized", team = teamA, previousOwner = teamB })
		owner = nil
	end
	if owner == nil then
		if control >= 1 then
			owner = teamA
			table.insert(events, { kind = "Captured", team = teamA })
		elseif control <= -1 then
			owner = teamB
			table.insert(events, { kind = "Captured", team = teamB })
		end
	end

	new.control = control
	new.owner = owner
	return new, events
end

return CaptureLogic
