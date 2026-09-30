--[[
	WeaponLogic
	Pure weapon maths shared by client prediction and server authority.
]]

local WeaponLogic = {}

function WeaponLogic.fireInterval(weapon)
	return 60 / weapon.RPM
end

function WeaponLogic.damageAt(weapon, distance, isHead)
	local damage
	if distance <= weapon.FalloffStart then
		damage = weapon.Damage
	elseif distance >= weapon.FalloffEnd then
		damage = weapon.MinDamage
	else
		local t = (distance - weapon.FalloffStart) / (weapon.FalloffEnd - weapon.FalloffStart)
		damage = weapon.Damage + (weapon.MinDamage - weapon.Damage) * t
	end
	if isHead then
		damage *= weapon.HeadMultiplier
	end
	return math.floor(damage + 0.5)
end

-- Server-side cadence check with jitter tolerance.
function WeaponLogic.canFire(lastShotTime, now, weapon, tolerance)
	return (now - lastShotTime) >= WeaponLogic.fireInterval(weapon) * tolerance
end

-- Returns (newMag, newReserve) after a completed reload.
function WeaponLogic.reloadResult(mag, reserve, magSize)
	local need = magSize - mag
	if need <= 0 or reserve <= 0 then
		return mag, reserve
	end
	local take = math.min(need, reserve)
	return mag + take, reserve - take
end

return WeaponLogic
