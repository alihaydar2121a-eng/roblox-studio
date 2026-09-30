--[[
	Rng
	Deterministic xorshift32 generator. Unlike Roblox's Random, it behaves the
	same in Roblox, the luau CLI and Lune, so map generation can be verified
	offline and reproduced exactly by every server and every Studio bake.
]]

local Rng = {}
Rng.__index = Rng

local UINT = 4294967296

-- Exact (a * b) mod 2^32 without exceeding double precision.
local function mul32(a, b)
	local alo = a % 65536
	local ahi = (a - alo) / 65536
	return ((ahi * b) % 65536 * 65536 + alo * b) % UINT
end

local function mix(seed)
	local s = math.floor(seed) % UINT
	-- Scramble low-entropy seeds (0, 1, 2 ...) so neighbouring seeds diverge.
	s = bit32.bxor(s, 0x9E3779B9)
	s = mul32(s, 0x85EBCA6B)
	s = bit32.bxor(s, bit32.rshift(s, 13))
	s = mul32(s, 0xC2B2AE35)
	s = bit32.bxor(s, bit32.rshift(s, 16))
	if s == 0 then
		s = 0x2545F491
	end
	return s
end

function Rng.new(seed)
	return setmetatable({ state = mix(seed) }, Rng)
end

-- Stable hash of integer coordinates + seed, for per-cell randomness.
function Rng.hash(a, b, seed)
	local h = mix(mul32(math.floor(a) % UINT, 73856093))
	h = bit32.bxor(h, mix(mul32(math.floor(b) % UINT, 19349663)))
	h = bit32.bxor(h, mix(seed or 0))
	return h
end

function Rng.forCell(a, b, seed)
	return setmetatable({ state = mix(Rng.hash(a, b, seed)) }, Rng)
end

function Rng:nextUInt()
	local x = self.state
	x = bit32.bxor(x, bit32.lshift(x, 13))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	x = bit32.bxor(x, bit32.lshift(x, 5))
	self.state = x
	return x
end

-- [0, 1)
function Rng:float()
	return self:nextUInt() / UINT
end

function Rng:range(a, b)
	return a + (b - a) * self:float()
end

function Rng:int(a, b)
	return math.min(b, a + math.floor(self:float() * (b - a + 1)))
end

function Rng:chance(p)
	return self:float() < p
end

function Rng:pick(list)
	return list[self:int(1, #list)]
end

-- weights: { {value, weight}, ... }
function Rng:weighted(entries)
	local total = 0
	for _, e in ipairs(entries) do
		total += e[2]
	end
	local roll = self:float() * total
	for _, e in ipairs(entries) do
		roll -= e[2]
		if roll < 0 then
			return e[1]
		end
	end
	return entries[#entries][1]
end

return Rng
