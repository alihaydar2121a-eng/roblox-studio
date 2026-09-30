--[[
	Validate
	Defensive checks for values arriving over the network. Every remote
	argument is untrusted: check type, finiteness and bounds.
]]

local Validate = {}

function Validate.finiteNumber(x)
	return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end

function Validate.vector3(v)
	return typeof(v) == "Vector3"
		and Validate.finiteNumber(v.X)
		and Validate.finiteNumber(v.Y)
		and Validate.finiteNumber(v.Z)
end

function Validate.unitVector3(v, tolerance)
	if not Validate.vector3(v) then
		return false
	end
	return math.abs(v.Magnitude - 1) <= (tolerance or 0.02)
end

function Validate.shortString(s, maxLength)
	return type(s) == "string" and #s > 0 and #s <= (maxLength or 32)
end

function Validate.oneOf(value, list)
	for _, v in ipairs(list) do
		if v == value then
			return true
		end
	end
	return false
end

return Validate
