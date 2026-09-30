--[[
	RateLimiter
	Token bucket keyed by an arbitrary key (usually a player UserId).
	`clock` is injectable for testing; defaults to os.clock.
]]

local RateLimiter = {}
RateLimiter.__index = RateLimiter

function RateLimiter.new(capacity, refillPerSecond, clock)
	return setmetatable({
		capacity = capacity,
		refill = refillPerSecond,
		clock = clock or os.clock,
		buckets = {},
	}, RateLimiter)
end

function RateLimiter:allow(key, cost)
	cost = cost or 1
	local now = self.clock()
	local bucket = self.buckets[key]
	if bucket == nil then
		bucket = { tokens = self.capacity, last = now }
		self.buckets[key] = bucket
	else
		bucket.tokens = math.min(self.capacity, bucket.tokens + (now - bucket.last) * self.refill)
		bucket.last = now
	end
	if bucket.tokens >= cost then
		bucket.tokens -= cost
		return true
	end
	return false
end

function RateLimiter:reset(key)
	self.buckets[key] = nil
end

return RateLimiter
