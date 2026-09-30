--[[
	Heightfield
	Pure, deterministic terrain function for Kestrel Valley. Given MapLayout and
	the site plan it answers "how high is the ground at (x, z) and what is it
	made of?". Used by the voxel terrain writer and by every builder that needs
	to sit geometry on the ground, and unit-tested offline (no Roblox APIs;
	math.noise is part of the Luau standard library).

	Pipeline per column:
	  raw noise + hills + mountains + spires
	  → river floodplains lowered
	  → flat pads (sites, HQs, outposts) blended in
	  → roads blended to a smoothed longitudinal profile
	  → river channels carved
	  → trenches carved
]]

local Heightfield = {}
Heightfield.__index = Heightfield

local CELL = 64
local ROAD_SHOULDER = 10
local ROAD_SAMPLE = 8

local function clamp(x, a, b)
	return x < a and a or (x > b and b or x)
end

local function smooth01(t)
	t = clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

-- Distance from p to segment ab plus the segment parameter t.
local function segDistance(px, pz, ax, az, bx, bz)
	local dx, dz = bx - ax, bz - az
	local len2 = dx * dx + dz * dz
	local t = 0
	if len2 > 0 then
		t = clamp(((px - ax) * dx + (pz - az) * dz) / len2, 0, 1)
	end
	local qx, qz = ax + dx * t - px, az + dz * t - pz
	return math.sqrt(qx * qx + qz * qz), t
end

--------------------------------------------------------------- spatial hash

local function cellKey(cx, cz)
	return (cx + 1024) * 4096 + (cz + 1024)
end

local function insert(grid, item, minX, minZ, maxX, maxZ)
	for cx = math.floor(minX / CELL), math.floor(maxX / CELL) do
		for cz = math.floor(minZ / CELL), math.floor(maxZ / CELL) do
			local key = cellKey(cx, cz)
			local bucket = grid[key]
			if not bucket then
				bucket = {}
				grid[key] = bucket
			end
			table.insert(bucket, item)
		end
	end
end

local EMPTY = {}
local function query(grid, x, z)
	return grid[cellKey(math.floor(x / CELL), math.floor(z / CELL))] or EMPTY
end

--------------------------------------------------------------- construction

function Heightfield.new(layout, plan)
	local self = setmetatable({}, Heightfield)
	self.layout = layout
	self.plan = plan
	self.water = layout.WaterLevel
	self.seedZ = (layout.Seed % 997) + 0.371
	self.rivers = {} -- grid of river segments
	self.flatGrid = {}
	self.roadGrid = {}
	self.trenchGrid = {}
	self.riverList = {}

	-- Rivers
	for _, river in ipairs(layout.Rivers) do
		local half = river.Width / 2
		local reach = half + river.Valley
		for i = 1, #river.Points - 1 do
			local a, b = river.Points[i], river.Points[i + 1]
			local seg = { a[1], a[2], b[1], b[2], river = river, half = half }
			table.insert(self.riverList, seg)
			insert(self.rivers, seg, math.min(a[1], b[1]) - reach, math.min(a[2], b[2]) - reach, math.max(a[1], b[1]) + reach, math.max(a[2], b[2]) + reach)
		end
	end

	-- Flats: target height sampled from the natural terrain at their centre.
	self.flats = {}
	for index, f in ipairs(plan.flats) do
		local flat = table.clone(f)
		flat.index = index
		flat.height = f.Height or self:_natural(f.X, f.Z)
		local reach
		if f.Kind == "circle" then
			reach = f.R + f.Falloff
		else
			local r = math.rad(f.Yaw or 0)
			local c, s = math.abs(math.cos(r)), math.abs(math.sin(r))
			reach = math.max(f.HX * c + f.HZ * s, f.HX * s + f.HZ * c) + f.Falloff
		end
		table.insert(self.flats, flat)
		insert(self.flatGrid, flat, f.X - reach, f.Z - reach, f.X + reach, f.Z + reach)
	end

	-- Roads (MapLayout roads + planned lanes) sampled into smoothed profiles.
	self.roads = {}
	local allRoads = {}
	for _, r in ipairs(layout.Roads) do
		table.insert(allRoads, r)
	end
	for _, r in ipairs(plan.lanes) do
		table.insert(allRoads, r)
	end
	for id, road in ipairs(allRoads) do
		self:_buildRoad(id, road)
	end

	-- Trenches
	for _, trench in ipairs(layout.Trenches or {}) do
		local total = 0
		local lengths = {}
		for i = 1, #trench.Points - 1 do
			local a, b = trench.Points[i], trench.Points[i + 1]
			lengths[i] = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
			total += lengths[i]
		end
		local run = 0
		for i = 1, #trench.Points - 1 do
			local a, b = trench.Points[i], trench.Points[i + 1]
			local seg = { a[1], a[2], b[1], b[2], half = trench.Width / 2, depth = trench.Depth, s0 = run, len = lengths[i], total = total }
			run += lengths[i]
			local reach = trench.Width
			insert(self.trenchGrid, seg, math.min(a[1], b[1]) - reach, math.min(a[2], b[2]) - reach, math.max(a[1], b[1]) + reach, math.max(a[2], b[2]) + reach)
		end
	end
	return self
end

--------------------------------------------------------------- natural terrain

function Heightfield:_fbm(x, z, octaves, salt)
	local sum, amp, freq, norm = 0, 1, 1, 0
	for i = 1, octaves do
		sum += amp * math.noise(x * freq, z * freq, self.seedZ + salt + i * 17.13)
		norm += amp
		amp *= 0.5
		freq *= 2.03
	end
	return sum / norm
end

-- Mountain factor 0..1 (0 in the playable interior, 1 on the backdrop ridges).
function Heightfield:mountainFactor(x, z)
	local ax, az = math.abs(x), math.abs(z)
	-- Rounded-square (superellipse) distance with a noisy, irregular edge.
	local m = (ax ^ 6 + az ^ 6) ^ (1 / 6)
	m += 55 * math.noise(x / 260, z / 260, self.seedZ + 3.3) + 18 * math.noise(x / 80, z / 80, self.seedZ + 3.9)
	local e = smooth01((m - 610) / 230)
	if az >= ax and az > 480 then
		-- Passes behind each HQ where the highway leaves the valley.
		local notch = 1 - smooth01((ax - 60) / 170)
		e *= 1 - 0.85 * notch
	end
	return e
end

function Heightfield:_raw(x, z)
	local layout = self.layout
	local h = layout.BaseHeight
		+ 9 * self:_fbm(x / 340, z / 340, 3, 0)
		+ 2.2 * math.noise(x / 55, z / 55, self.seedZ + 41.7)
	for _, hill in ipairs(layout.Hills) do
		local dx, dz = x - hill[1], z - hill[2]
		local d2 = dx * dx + dz * dz
		local r = hill[3]
		if d2 < r * r then
			local t = 1 - math.sqrt(d2) / r
			local shape = t * t * (3 - 2 * t)
			h += hill[4] * shape * (0.85 + 0.3 * math.noise(x / 70, z / 70, self.seedZ + 9.1))
		end
	end
	local e = self:mountainFactor(x, z)
	if e > 0 then
		local ridge = 1 - math.abs(math.noise(x / 120, z / 120, self.seedZ + 61.2))
		h += e ^ 1.5 * (140 + 70 * self:_fbm(x / 170, z / 170, 3, 50) + 45 * ridge * ridge)
	end
	for _, spire in ipairs(layout.Spires or {}) do
		local dx, dz = x - spire[1], z - spire[2]
		local d = math.sqrt(dx * dx + dz * dz)
		if d < spire[3] then
			local t = 1 - d / spire[3]
			h += spire[4] * t ^ 1.3 * (0.8 + 0.4 * math.noise(x / 9, z / 9, self.seedZ + 5.5))
		end
	end
	return h
end

-- Nearest river distance and the river it belongs to.
function Heightfield:_river(x, z)
	local best, bestSeg = math.huge, nil
	for _, seg in ipairs(query(self.rivers, x, z)) do
		local d = segDistance(x, z, seg[1], seg[2], seg[3], seg[4])
		if d < best then
			best, bestSeg = d, seg
		end
	end
	return best, bestSeg
end

-- Raw terrain with river floodplains lowered (used for flat pad targets).
function Heightfield:_natural(x, z)
	local h = self:_raw(x, z)
	local d, seg = self:_river(x, z)
	if seg then
		local river = seg.river
		local target = self.water + 2.5 + math.max(0, d - seg.half) * 0.04
		if h > target then
			local w = 1 - smooth01((d - seg.half) / river.Valley)
			h = lerp(h, target, w)
		end
	end
	return h
end

local function flatWeight(flat, x, z)
	if flat.Kind == "circle" then
		local d = math.sqrt((x - flat.X) ^ 2 + (z - flat.Z) ^ 2)
		return 1 - smooth01((d - flat.R) / flat.Falloff)
	end
	local dx, dz = x - flat.X, z - flat.Z
	if flat.Yaw and flat.Yaw ~= 0 then
		local r = math.rad(flat.Yaw)
		local c, s = math.cos(r), math.sin(r)
		dx, dz = dx * c - dz * s, dx * s + dz * c
	end
	local ox = math.max(0, math.abs(dx) - flat.HX)
	local oz = math.max(0, math.abs(dz) - flat.HZ)
	return 1 - smooth01(math.sqrt(ox * ox + oz * oz) / flat.Falloff)
end

-- Applies flats; returns height, max weight, material of the dominant pad, clear flag.
function Heightfield:_applyFlats(h, x, z)
	local padW, padMat, clear = 0, nil, false
	for _, flat in ipairs(query(self.flatGrid, x, z)) do
		local w = flatWeight(flat, x, z)
		if w > 0 then
			h = lerp(h, flat.height, w)
			if w > padW then
				padW = w
				padMat = flat.Material
			end
			if flat.Clear and w > 0.25 then
				clear = true
			end
		end
	end
	return h, padW, padMat, clear
end

--------------------------------------------------------------- roads

function Heightfield:_buildRoad(id, road)
	-- Sample the polyline every ROAD_SAMPLE studs.
	local samples = {}
	local pts = road.Points
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local len = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
		local n = math.max(1, math.ceil(len / ROAD_SAMPLE))
		for k = 0, n - 1 do
			local t = k / n
			table.insert(samples, { x = a[1] + (b[1] - a[1]) * t, z = a[2] + (b[2] - a[2]) * t })
		end
	end
	table.insert(samples, { x = pts[#pts][1], z = pts[#pts][2] })

	for _, s in ipairs(samples) do
		local h = self:_natural(s.x, s.z)
		local padW
		h, padW = self:_applyFlats(h, s.x, s.z)
		s.h = h
		s.pinned = padW > 0.98
		-- Keep crossings high enough for a bridge deck above the water.
		local d, seg = self:_river(s.x, s.z)
		if seg and d < seg.half + 22 then
			s.h = math.max(s.h, self.water + 4.2)
			s.pinned = true
		end
	end
	-- Smooth the longitudinal profile (pinned samples stay put).
	for _ = 1, 6 do
		local prev = {}
		for i, s in ipairs(samples) do
			prev[i] = s.h
		end
		for i = 2, #samples - 1 do
			local s = samples[i]
			if not s.pinned then
				s.h = prev[i - 1] * 0.25 + prev[i] * 0.5 + prev[i + 1] * 0.25
			end
		end
	end

	local half = road.Width / 2
	local reach = half + ROAD_SHOULDER + 2
	local info = { id = id, half = half, material = road.Material, name = road.Name }
	table.insert(self.roads, info)
	for i = 1, #samples - 1 do
		local a, b = samples[i], samples[i + 1]
		local seg = { a.x, a.z, b.x, b.z, ha = a.h, hb = b.h, road = info }
		insert(self.roadGrid, seg, math.min(a.x, b.x) - reach, math.min(a.z, b.z) - reach, math.max(a.x, b.x) + reach, math.max(a.z, b.z) + reach)
	end
end

--------------------------------------------------------------- full sample

--[[
	height(x, z) -> h, info
	info fields: roadW (0..1 surface weight), roadMat, roadD (distance past the
	road edge), riverD (distance past the water edge), water (bool: fill with
	water up to WaterLevel), padW, padMat, clear (inside a site pad), trench (bool),
	mountain (0..1).
]]
function Heightfield:height(x, z)
	local info = {}
	local h = self:_raw(x, z)
	info.mountain = self:mountainFactor(x, z)

	local riverDist, riverSeg = self:_river(x, z)
	if riverSeg then
		local target = self.water + 2.5 + math.max(0, riverDist - riverSeg.half) * 0.04
		if h > target then
			h = lerp(h, target, 1 - smooth01((riverDist - riverSeg.half) / riverSeg.river.Valley))
		end
	end

	local padW, padMat, clear
	h, padW, padMat, clear = self:_applyFlats(h, x, z)
	info.padW, info.padMat, info.clear = padW, padMat, clear

	-- Roads: nearest segment per road, applied in road order.
	local best = {}
	for _, seg in ipairs(query(self.roadGrid, x, z)) do
		local d, t = segDistance(x, z, seg[1], seg[2], seg[3], seg[4])
		local id = seg.road.id
		local cur = best[id]
		if not cur or d < cur.d then
			best[id] = { d = d, h = lerp(seg.ha, seg.hb, t), road = seg.road }
		end
	end
	info.roadW, info.roadD = 0, math.huge
	for id = 1, #self.roads do
		local r = best[id]
		if r then
			local w = 1 - smooth01((r.d - r.road.half) / ROAD_SHOULDER)
			if w > 0 then
				h = lerp(h, r.h, w)
			end
			local surface = 1 - smooth01((r.d - (r.road.half - 1)) / 2)
			if surface > info.roadW then
				info.roadW = surface
				info.roadMat = r.road.material
			end
			info.roadD = math.min(info.roadD, r.d - r.road.half)
		end
	end

	-- River channel
	info.riverD = math.huge
	if riverSeg then
		local half = riverSeg.half
		info.riverD = riverDist - half
		local bankR = half + 3
		if riverDist < bankR then
			local bed = self.water - riverSeg.river.Depth * (1 - (riverDist / bankR) ^ 2)
			if bed < h then
				h = bed
			end
			info.water = h < self.water - 0.2
		end
	end

	-- Trenches
	for _, seg in ipairs(query(self.trenchGrid, x, z)) do
		local d, t = segDistance(x, z, seg[1], seg[2], seg[3], seg[4])
		if d < seg.half + 1 then
			local along = seg.s0 + t * seg.len
			local taper = smooth01(math.min(along, seg.total - along) / 10)
			local w = 1 - smooth01((d - (seg.half - 1.5)) / 2)
			local cut = seg.depth * w * taper
			if cut > 0.5 then
				info.trench = true
			end
			h -= cut
			break
		end
	end
	return h, info
end

--------------------------------------------------------------- materials

-- Natural forest density 0..1 (drives LeafyGrass and tree scatter).
function Heightfield:forestDensity(x, z)
	local d = 0.03
	-- Domain-warp the sample point so forest edges meander instead of forming circles.
	local wx = x + 70 * math.noise(x / 150, z / 150, self.seedZ + 81.3)
	local wz = z + 70 * math.noise(x / 150, z / 150, self.seedZ + 93.7)
	for _, f in ipairs(self.layout.Forests) do
		local dist = math.sqrt((wx - f[1]) ^ 2 + (wz - f[2]) ^ 2)
		if dist < f[3] * 1.2 then
			d = math.max(d, f[4] * (1 - smooth01((dist - f[3] * 0.5) / (f[3] * 0.6))))
		end
	end
	local e = self:mountainFactor(x, z)
	if e > 0.05 and e < 0.75 then
		d = math.max(d, 0.55 * (1 - math.abs(e - 0.35) / 0.4))
	end
	d += 0.22 * math.noise(x / 130, z / 130, self.seedZ + 71.1)
	return clamp(d, 0, 1)
end

function Heightfield:material(x, z, h, slope, info)
	if info.water then
		return math.noise(x / 18, z / 18, self.seedZ + 2) > 0 and "Mud" or "Ground"
	end
	if info.trench then
		return "Mud"
	end
	if info.roadW > 0.5 and info.roadMat then
		return info.roadMat
	end
	if info.roadW > 0.05 and info.roadD < 2.5 then
		return math.noise(x / 6, z / 6, self.seedZ + 8) > 0.1 and "Mud" or "Ground"
	end
	for _, paint in ipairs(self.plan.paints) do
		local inside
		if paint.Kind == "circle" then
			inside = (x - paint.X) ^ 2 + (z - paint.Z) ^ 2 <= paint.R ^ 2
		else
			local dx, dz = x - paint.X, z - paint.Z
			if paint.Yaw and paint.Yaw ~= 0 then
				local r = math.rad(paint.Yaw)
				local c, s = math.cos(r), math.sin(r)
				dx, dz = dx * c - dz * s, dx * s + dz * c
			end
			inside = math.abs(dx) <= paint.HX and math.abs(dz) <= paint.HZ
		end
		if inside then
			return paint.Material
		end
	end
	if info.padW > 0.96 and info.padMat then
		-- Break up large pads with worn patches.
		local worn = self:_fbm(x / 34, z / 34, 2, 44)
		if info.padMat == "Ground" and worn > 0.28 then
			return "Grass"
		elseif info.padMat == "Concrete" and worn > 0.3 then
			return "Pavement"
		end
		return info.padMat
	end
	if info.riverD < 5 then
		return math.noise(x / 10, z / 10, self.seedZ + 4) > 0.15 and "Sand" or "Mud"
	end
	if slope > 1.1 then
		return "Rock"
	end
	if slope > 0.7 then
		return self:_fbm(x / 40, z / 40, 2, 6) > 0 and "Slate" or "Ground"
	end
	if h > 175 then
		return self:_fbm(x / 50, z / 50, 2, 12) > -0.15 and "Rock" or "Slate"
	end
	if info.mountain > 0.5 and slope > 0.45 then
		return self:_fbm(x / 30, z / 30, 2, 13) > 0.1 and "Rock" or "Ground"
	end
	local patch = self:_fbm(x / 90, z / 90, 3, 21)
	if patch > 0.34 and h < self.layout.BaseHeight + 3 and info.padW < 0.5 then
		return "Mud"
	end
	local forest = self:forestDensity(x, z)
	if forest > 0.5 then
		return self:_fbm(x / 26, z / 26, 2, 31) > 0.3 and "Ground" or "LeafyGrass"
	end
	if patch < -0.38 then
		return "Ground"
	end
	return "Grass"
end

--------------------------------------------------------------- queries for builders

function Heightfield:groundAt(x, z)
	return (self:height(x, z))
end

-- Slope magnitude (rise/run) by central differences.
function Heightfield:slopeAt(x, z)
	local e = 2
	local hx1 = self:height(x + e, z)
	local hx0 = self:height(x - e, z)
	local hz1 = self:height(x, z + e)
	local hz0 = self:height(x, z - e)
	return math.sqrt(((hx1 - hx0) / (2 * e)) ^ 2 + ((hz1 - hz0) / (2 * e)) ^ 2)
end

-- Whether natural foliage/rocks may be placed here.
function Heightfield:isWild(x, z, margin)
	margin = margin or 0
	local h, info = self:height(x, z)
	if info.clear or info.trench or info.water then
		return false, h, info
	end
	if info.roadD < 4 + margin or info.riverD < 5 + margin then
		return false, h, info
	end
	if h < self.water + 1 then
		return false, h, info
	end
	return true, h, info
end

return Heightfield
