--[[
	StanceLogic
	Pure rules resolving a client's requested movement state into the
	authoritative stance, aim flag and walk speed.
]]

local StanceLogic = {}

StanceLogic.Speeds = {
	Stand = 16,
	Sprint = 23,
	Crouch = 9,
	AimWalk = 11,
	CrouchAim = 7.5,
}

-- Heavier weapons slow the carrier slightly.
StanceLogic.WeaponSpeedPenalty = { LMG = 1.5, SR = 0.5 }

--[[
	resolve(request, weaponId, reloading) -> stance, aiming, walkSpeed
	request: { sprint = bool, crouch = bool, aim = bool }
	Sprinting cancels aiming and crouching; reloading prevents sprinting and aiming
	(aiming is allowed again the moment the reload finishes).
]]
function StanceLogic.resolve(request, weaponId, reloading)
	local sprint = request.sprint == true
	local crouch = request.crouch == true
	local aim = request.aim == true
	if reloading then
		sprint, aim = false, false
	end
	if aim then
		sprint = false
	end
	if sprint then
		crouch = false
	end
	local stance = sprint and "Sprint" or (crouch and "Crouch" or "Stand")
	local speed
	if stance == "Sprint" then
		speed = StanceLogic.Speeds.Sprint
	elseif stance == "Crouch" then
		speed = aim and StanceLogic.Speeds.CrouchAim or StanceLogic.Speeds.Crouch
	else
		speed = aim and StanceLogic.Speeds.AimWalk or StanceLogic.Speeds.Stand
	end
	speed -= StanceLogic.WeaponSpeedPenalty[weaponId] or 0
	return stance, aim, speed
end

-- Spread multiplier for the current movement state.
function StanceLogic.spreadMultiplier(weapon, moving, stance, aiming)
	local m = 1
	if moving then
		m *= weapon.MoveSpreadMultiplier
	end
	if stance == "Crouch" then
		m *= weapon.CrouchSpreadMultiplier
	end
	if aiming then
		m *= weapon.AimSpreadMultiplier
	end
	if stance == "Sprint" then
		m *= 2.5
	end
	return m
end

return StanceLogic
