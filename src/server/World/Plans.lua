--[[
	Plans
	Pure (Roblox-free) site planner. Expands Shared.Config.MapLayout into
	concrete, deterministic placements for every building and structure, and
	the terrain features they need (flat pads, painted materials, lanes).

	All placements are world-space tables { X, Z, Yaw (degrees) ... }. Yaw uses
	Roblox's CFrame.Angles(0, rad(Yaw), 0) convention: a structure's front
	(local −Z) faces world direction (−sin Yaw, −cos Yaw).
]]

local Plans = {}

local function yawFromDir(dx, dz)
	return math.deg(math.atan2(-dx, -dz))
end
Plans.yawFromDir = yawFromDir

-- Rotate local (lx, lz) by yaw degrees and add origin.
local function toWorld(ox, oz, yaw, lx, lz)
	local r = math.rad(yaw)
	local c, s = math.cos(r), math.sin(r)
	return ox + lx * c + lz * s, oz - lx * s + lz * c
end
Plans.toWorld = toWorld

local function segmentIntersection(ax, az, bx, bz, cx, cz, dx, dz)
	local rX, rZ = bx - ax, bz - az
	local sX, sZ = dx - cx, dz - cz
	local denom = rX * sZ - rZ * sX
	if math.abs(denom) < 1e-9 then
		return nil
	end
	local t = ((cx - ax) * sZ - (cz - az) * sX) / denom
	local u = ((cx - ax) * rZ - (cz - az) * rX) / denom
	if t >= 0 and t <= 1 and u >= 0 and u <= 1 then
		return ax + rX * t, az + rZ * t
	end
	return nil
end

--------------------------------------------------------------------------- HQ

local function planHQ(plan, teamId, def)
	local cx, cz = def.Position[1], def.Position[2]
	local yaw = yawFromDir(def.Facing[1], def.Facing[2])
	local hq = { Team = teamId, X = cx, Z = cz, Yaw = yaw, Structures = {}, Spawns = {} }
	local function add(t)
		t.X, t.Z = toWorld(cx, cz, yaw, t.LX, t.LZ)
		t.Yaw = yaw + (t.LYaw or 0)
		table.insert(hq.Structures, t)
		return t
	end
	-- Local frame: −Z is toward the battlefield.
	add({ Type = "CommandBunker", LX = -44, LZ = 34, W = 20, D = 14 })
	add({ Type = "Tent", LX = 40, LZ = 40, W = 16, D = 10 })
	add({ Type = "Tent", LX = 40, LZ = 20, W = 16, D = 10 })
	add({ Type = "Tent", LX = -46, LZ = 8, W = 14, D = 10, LYaw = 90 })
	add({ Type = "VehicleShed", LX = 50, LZ = -30, W = 26, D = 14, LYaw = -90 })
	add({ Type = "Watchtower", LX = -64, LZ = -50, LYaw = 225 })
	add({ Type = "Watchtower", LX = 64, LZ = -50, LYaw = 135 })
	add({ Type = "SupplyDepot", LX = -50, LZ = -26 })
	add({ Type = "TeamFlag", LX = 0, LZ = 40 })
	add({ Type = "Antenna", LX = -30, LZ = 46 })
	add({ Type = "HescoPerimeter", LX = 0, LZ = 0, HX = 76, HZ = 60, FrontGap = 22, BackGap = 16 })
	for row = 0, 3 do
		for col = 0, 5 do
			local lx, lz = -30 + col * 12, -4 - row * 9
			local x, z = toWorld(cx, cz, yaw, lx, lz)
			table.insert(hq.Spawns, { X = x, Z = z, Yaw = yaw })
		end
	end
	plan.hqs[teamId] = hq
	table.insert(plan.flats, { Kind = "circle", X = cx, Z = cz, R = 112, Falloff = 70, Clear = true })
	table.insert(plan.paints, { Kind = "rect", X = cx, Z = cz, HX = 78, HZ = 62, Yaw = yaw, Material = "Ground" })
	local ax, az = toWorld(cx, cz, yaw, 0, -14)
	table.insert(plan.paints, { Kind = "rect", X = ax, Z = az, HX = 42, HZ = 20, Yaw = yaw, Material = "Concrete" })
end

--------------------------------------------------------------- Military base

local function planMilitaryBase(plan, site)
	local cx, cz = site.Center[1], site.Center[2]
	local base = { X = cx, Z = cz, HX = 116, HZ = 96, Structures = {} }
	local function add(t)
		t.X, t.Z = cx + t.LX, cz + t.LZ
		t.Yaw = t.Yaw or 0
		table.insert(base.Structures, t)
		return t
	end
	add({ Type = "Barracks", LX = -72, LZ = 62, W = 34, D = 14, Yaw = 0 })
	add({ Type = "Barracks", LX = -32, LZ = 62, W = 34, D = 14, Yaw = 0 })
	add({ Type = "Barracks", LX = 8, LZ = 62, W = 34, D = 14, Yaw = 0 })
	add({ Type = "CommandPost", LX = 62, LZ = 60, W = 22, D = 16, Yaw = 0 })
	add({ Type = "Hangar", LX = -70, LZ = -60, W = 44, D = 36, Yaw = 180 })
	add({ Type = "Warehouse", LX = 2, LZ = -66, W = 28, D = 20, Yaw = 180, Style = "Military" })
	add({ Type = "Warehouse", LX = 48, LZ = -66, W = 26, D = 18, Yaw = 180, Style = "Military" })
	add({ Type = "VehicleShed", LX = 96, LZ = -40, W = 24, D = 14, Yaw = 90 })
	add({ Type = "Watchtower", LX = 102, LZ = 82, Yaw = 45 })
	add({ Type = "Watchtower", LX = -102, LZ = 82, Yaw = -45 })
	add({ Type = "Watchtower", LX = 102, LZ = -82, Yaw = 135 })
	add({ Type = "Watchtower", LX = -102, LZ = -82, Yaw = -135 })
	add({ Type = "GuardBooth", LX = 106, LZ = -16, Yaw = -90 })
	add({ Type = "GuardBooth", LX = 36, LZ = -88, Yaw = 180 })
	add({ Type = "GuardBooth", LX = 36, LZ = 88, Yaw = 0 })
	add({ Type = "FuelDepot", LX = -98, LZ = 0, Yaw = 90 })
	add({ Type = "ContainerYard", LX = -98, LZ = 34, Yaw = 90 })
	add({ Type = "Helipad", LX = 84, LZ = 28 })
	add({ Type = "Antenna", LX = 78, LZ = 70 })
	add({ Type = "SandbagNest", LX = -44, LZ = 36, Yaw = 135 })
	add({ Type = "SandbagNest", LX = 44, LZ = 36, Yaw = -135 })
	add({ Type = "SandbagNest", LX = -44, LZ = -32, Yaw = 45 })
	add({ Type = "SandbagNest", LX = 44, LZ = -32, Yaw = -45 })
	add({ Type = "Fence", LX = 0, LZ = 0, HX = 116, HZ = 96, Style = "Chainlink",
		Gates = { East = { 0, 22 }, South = { 20, 22 }, North = { 20, 22 }, West = { 28, 6 } } })
	plan.sites.MilitaryBase = base
	table.insert(plan.flats, { Kind = "rect", X = cx, Z = cz, HX = site.HalfExtents[1], HZ = site.HalfExtents[2], Falloff = 45, Material = "Ground", Clear = true })
	local function paint(lx, lz, hx, hz, material)
		table.insert(plan.paints, { Kind = "rect", X = cx + lx, Z = cz + lz, HX = hx, HZ = hz, Yaw = 0, Material = material })
	end
	paint(0, 0, 40, 32, "Concrete") -- parade ground
	paint(77, 0, 40, 9, "Asphalt") -- east gate road
	paint(20, 0, 7, 96, "Asphalt") -- north–south internal road
	paint(-70, -36, 24, 8, "Concrete") -- hangar apron
	paint(25, -50, 45, 6, "Concrete") -- warehouse apron
	paint(-32, 48, 58, 5, "Pavement") -- barracks walkway
end

--------------------------------------------------------------- Industrial

local function planIndustrial(plan, site)
	local cx, cz = site.Center[1], site.Center[2]
	local works = { X = cx, Z = cz, HX = 116, HZ = 96, Structures = {} }
	local function add(t)
		t.X, t.Z = cx + t.LX, cz + t.LZ
		t.Yaw = t.Yaw or 0
		table.insert(works.Structures, t)
		return t
	end
	add({ Type = "Warehouse", LX = -50, LZ = 58, W = 44, D = 30, Yaw = 0, Style = "Industrial", Mezzanine = true, RoofAccess = true })
	add({ Type = "Warehouse", LX = 40, LZ = 60, W = 40, D = 28, Yaw = 0, Style = "Industrial", Mezzanine = true })
	add({ Type = "LoadingDock", LX = -50, LZ = 39, W = 34, D = 6, Yaw = 0 })
	add({ Type = "LoadingDock", LX = 40, LZ = 42, W = 30, D = 6, Yaw = 0 })
	add({ Type = "Maintenance", LX = -58, LZ = -60, W = 24, D = 18, Yaw = 180 })
	add({ Type = "PumpHouse", LX = 0, LZ = -68, W = 16, D = 12, Yaw = 180 })
	add({ Type = "TankFarm", LX = 82, LZ = -46, Yaw = 0 })
	add({ Type = "Silos", LX = 100, LZ = 22, Yaw = 90 })
	add({ Type = "Chimney", LX = 102, LZ = 80 })
	add({ Type = "ContainerStack", LX = -96, LZ = 28, Yaw = 90, Layout = { { 0, 0, 0 }, { 10, 0, 0 }, { 0, 0, 1 }, { 20, 0, 0 } } })
	add({ Type = "ContainerStack", LX = -96, LZ = -28, Yaw = 90, Layout = { { 0, 0, 0 }, { 10, 0, 0 }, { 10, 0, 1 }, { -10, 0, 0 } } })
	add({ Type = "Gantry", LX = -96, LZ = 0, Yaw = 90, Span = 34, Length = 70 })
	add({ Type = "PipeRack", LX = 64, LZ = 10, Yaw = 0, Length = 58 })
	add({ Type = "GuardBooth", LX = -106, LZ = -16, Yaw = 90 })
	add({ Type = "GuardBooth", LX = -36, LZ = -88, Yaw = 180 })
	add({ Type = "GuardBooth", LX = -36, LZ = 88, Yaw = 0 })
	add({ Type = "Fence", LX = 0, LZ = 0, HX = 116, HZ = 96, Style = "ConcreteWall",
		Gates = { West = { 0, 22 }, South = { -20, 22 }, North = { -20, 22 } } })
	add({ Type = "SandbagNest", LX = -30, LZ = 22, Yaw = 135 })
	add({ Type = "SandbagNest", LX = 30, LZ = -22, Yaw = -45 })
	plan.sites.Industrial = works
	table.insert(plan.flats, { Kind = "rect", X = cx, Z = cz, HX = site.HalfExtents[1], HZ = site.HalfExtents[2], Falloff = 45, Material = "Concrete", Clear = true })
	local function paint(lx, lz, hx, hz, material)
		table.insert(plan.paints, { Kind = "rect", X = cx + lx, Z = cz + lz, HX = hx, HZ = hz, Yaw = 0, Material = material })
	end
	paint(-60, 0, 58, 9, "Asphalt")
	paint(-20, 0, 8, 96, "Asphalt")
	paint(0, 0, 34, 30, "Pavement") -- central yard
end

--------------------------------------------------------------- Village

local VILLAGE_TYPES = {
	{ "House1", 5 },
	{ "House2", 5 },
	{ "Shop", 3 },
	{ "Cottage", 2 },
}
local STYLES = { "Plaster", "Plaster", "Brick", "Stone", "Timber", "Wood" }

local function planVillage(plan, site, rng)
	local cx, cz = site.Center[1], site.Center[2]
	local village = { X = cx, Z = cz, Buildings = {}, Yards = {}, Decor = {} }
	local footprints = {}

	local function overlaps(x, z, hx, hz)
		for _, f in ipairs(footprints) do
			if math.abs(x - f[1]) < hx + f[3] + 2 and math.abs(z - f[2]) < hz + f[4] + 2 then
				return true
			end
		end
		return false
	end

	-- Slot = local centre, yaw, max width (along front), max depth, kind.
	local slots = {}
	local function slot(lx, lz, yaw, kind, side)
		-- Tier orders filling from the plaza outward so the core is densest.
		local t = math.max(math.abs(lx), math.abs(lz))
		local tier = kind == "row" and (t < 70 and 1 or (t < 100 and 2 or 4)) or (t < 80 and 3 or 5)
		table.insert(slots, { LX = lx, LZ = lz, Yaw = yaw, Kind = kind, Side = side, Tier = tier })
	end
	-- Row one: buildings facing the two main roads.
	for _, t in ipairs({ 60, 86, 112 }) do
		slot(t, 1, 0, "row", "N") -- +X arm north side (front faces −Z → road)
		slot(t, -1, 180, "row", "S")
		slot(-t, 1, 0, "row", "N")
		slot(-t, -1, 180, "row", "S")
		slot(1, t, 90, "row", "E") -- +Z arm east side (front faces −X)
		slot(-1, t, -90, "row", "W")
		slot(1, -t, 90, "row", "E")
		slot(-1, -t, -90, "row", "W")
	end
	-- Outer quadrants: buildings facing the back lanes.
	for _, t in ipairs({ 64, 90, 116 }) do
		slot(t, 1, 0, "outer", "N")
		slot(-t, 1, 0, "outer", "N")
		slot(t, -1, 180, "outer", "S")
		slot(-t, -1, 180, "outer", "S")
	end

	local function makeBuilding(kind, w, d, floors, style, extra)
		local b = { Type = kind, W = w, D = d, Floors = floors, Style = style }
		for k, v in pairs(extra or {}) do
			b[k] = v
		end
		return b
	end

	local function placeAt(b, lx, lz, yaw)
		local r = math.rad(yaw)
		-- axis-aligned half extents in local village space
		local hx = math.abs(math.cos(r)) * b.W / 2 + math.abs(math.sin(r)) * b.D / 2
		local hz = math.abs(math.sin(r)) * b.W / 2 + math.abs(math.cos(r)) * b.D / 2
		if overlaps(lx, lz, hx, hz) then
			return false
		end
		table.insert(footprints, { lx, lz, hx, hz })
		b.X, b.Z, b.Yaw = cx + lx, cz + lz, yaw
		b.LX, b.LZ = lx, lz
		table.insert(village.Buildings, b)
		return true
	end

	-- Plaza corners: landmark buildings facing the east–west road.
	placeAt(makeBuilding("Hall", 22, 16, 2, "Stone"), 30, 13 + 8, 0)
	placeAt(makeBuilding("Tavern", 20, 16, 2, "Timber", { Sign = "THE KESTREL" }), -30, 13 + 8, 0)
	placeAt(makeBuilding("Shop", 18, 14, 2, "Plaster", { Sign = "GENERAL STORE" }), 30, -(13 + 7), 180)
	placeAt(makeBuilding("Shop", 18, 14, 1, "Brick", { Sign = "BAKERY" }), -30, -(13 + 7), 180)

	local signs = { "POST", "TAILOR", "PHARMACY", "HARDWARE", "CAFE" }
	local target = 20
	local order = {}
	for i = 1, #slots do
		order[i] = i
	end
	for i = #order, 2, -1 do -- deterministic shuffle, then stable by tier
		local j = rng:int(1, i)
		order[i], order[j] = order[j], order[i]
	end
	local rank = {}
	for pos, index in ipairs(order) do
		rank[index] = pos
	end
	table.sort(order, function(a, b)
		if slots[a].Tier ~= slots[b].Tier then
			return slots[a].Tier < slots[b].Tier
		end
		return rank[a] < rank[b]
	end)
	for _, index in ipairs(order) do
		if #village.Buildings >= target then
			break
		end
		local s = slots[index]
		local kind = s.Kind == "outer" and rng:weighted({ { "House1", 3 }, { "Barn", 2 }, { "Cottage", 2 } }) or rng:weighted(VILLAGE_TYPES)
		local style = rng:pick(STYLES)
		local w, d, floors
		if kind == "House2" then
			w, d, floors = rng:int(16, 20), rng:int(14, 16), 2
		elseif kind == "House1" then
			w, d, floors = rng:int(13, 17), rng:int(11, 14), 1
		elseif kind == "Cottage" then
			w, d, floors = rng:int(10, 12), rng:int(9, 11), 1
		elseif kind == "Barn" then
			w, d, floors, style = 18, 22, 1, "Barn"
		else -- Shop
			w, d, floors = rng:int(14, 18), rng:int(12, 14), rng:int(1, 2)
		end
		if floors == 2 and w < 16 then
			w = 16
		end
		local b = makeBuilding(kind, w, d, floors, style)
		if kind == "Shop" then
			b.Sign = table.remove(signs, 1) or "SHOP"
		end
		-- Resolve slot centre: offset from the road/lane by setback + half depth.
		local lx, lz = s.LX, s.LZ
		if s.Kind == "row" then
			local roadHalf = (s.Side == "N" or s.Side == "S") and 8 or 9
			local off = roadHalf + 4 + d / 2
			if s.Side == "N" then
				lz = off
			elseif s.Side == "S" then
				lz = -off
			elseif s.Side == "E" then
				lx = off
			else
				lx = -off
			end
		else
			local off = 44 + 3 + 3 + d / 2
			lz = s.Side == "N" and off or -off
		end
		if placeAt(b, lx, lz, s.Yaw) and s.Kind == "row" and kind ~= "Barn" then
			-- Fenced back yard between the building and the back lane.
			local depthToLane = 41 - (((s.Side == "N" or s.Side == "S") and 8 or 9) + 4 + d)
			if depthToLane > 4 then
				table.insert(village.Yards, { Building = b, Depth = math.min(depthToLane - 1, 9) })
			end
		end
	end

	-- Decor in the unused corners of the plaza and lanes.
		table.insert(village.Decor, { Type = "Well", LX = 18, LZ = -34 })
	table.insert(village.Decor, { Type = "MarketStall", LX = -14, LZ = 34, Yaw = 180 })
	table.insert(village.Decor, { Type = "MarketStall", LX = -30, LZ = 36, Yaw = 180 })
	table.insert(village.Decor, { Type = "MarketStall", LX = 22, LZ = 36, Yaw = 180 })
	for _, p in ipairs({ { 16, 16 }, { -16, 16 }, { 16, -16 }, { -16, -16 } }) do
		table.insert(village.Decor, { Type = "LampPost", LX = p[1], LZ = p[2] })
		table.insert(village.Decor, { Type = "Bench", LX = p[1] * 1.25, LZ = p[2] * 0.7, Yaw = p[2] > 0 and 180 or 0 })
	end
	for i = -2, 2 do
		table.insert(village.Decor, { Type = "LampPost", LX = i * 30 + 15, LZ = 13.5 })
		table.insert(village.Decor, { Type = "LampPost", LX = -12.5, LZ = i * 30 + 15 })
	end

	village.Footprints = footprints
	plan.sites.Village = village
	table.insert(plan.flats, { Kind = "circle", X = cx, Z = cz, R = site.Radius, Falloff = 40, Clear = true })
	table.insert(plan.paints, { Kind = "circle", X = cx, Z = cz, R = 24, Material = "Cobblestone" })
	-- Back lanes forming a ring round the centre.
	local e = 130
	for _, lane in ipairs({
		{ { -e, 44 }, { e, 44 } },
		{ { -e, -44 }, { e, -44 } },
		{ { 44, -e }, { 44, e } },
		{ { -44, -e }, { -44, e } },
	}) do
		table.insert(plan.lanes, {
			Name = "Village Lane", Width = 6, Material = "Cobblestone",
			Points = { { cx + lane[1][1], cz + lane[1][2] }, { cx + lane[2][1], cz + lane[2][2] } },
		})
	end
end

--------------------------------------------------------------- Outposts

local OUTPOST_FLATS = {
	Checkpoint = 22, Farmstead = 36, Chapel = 26, Mill = 20, RadioMast = 14,
	Lookout = 12, Cabin = 14, Bunker = 16,
}

local function planOutposts(plan, layout)
	for _, o in ipairs(layout.Outposts) do
		local entry = { Type = o.Type }
		if o.Road then
			local road = layout.Roads[o.Road]
			local a, b = road.Points[o.Segment], road.Points[o.Segment + 1]
			entry.X = a[1] + (b[1] - a[1]) * o.T
			entry.Z = a[2] + (b[2] - a[2]) * o.T
			entry.Yaw = yawFromDir(b[1] - a[1], b[2] - a[2])
			entry.RoadWidth = road.Width
		else
			entry.X, entry.Z = o.Position[1], o.Position[2]
			entry.Yaw = o.Yaw or 0
		end
		table.insert(plan.outposts, entry)
		local r = OUTPOST_FLATS[o.Type]
		if r then
			table.insert(plan.flats, { Kind = "circle", X = entry.X, Z = entry.Z, R = r, Falloff = 22, Clear = true })
		end
	end
end

local function planBridges(plan, layout)
	local roads = {}
	for i, r in ipairs(layout.Roads) do
		roads[i] = r
	end
	for _, river in ipairs(layout.Rivers) do
		for _, road in ipairs(roads) do
			for i = 1, #road.Points - 1 do
				local a, b = road.Points[i], road.Points[i + 1]
				for j = 1, #river.Points - 1 do
					local c, d = river.Points[j], river.Points[j + 1]
					local x, z = segmentIntersection(a[1], a[2], b[1], b[2], c[1], c[2], d[1], d[2])
					if x then
						table.insert(plan.bridges, {
							X = x, Z = z,
							Yaw = yawFromDir(b[1] - a[1], b[2] - a[2]),
							Width = road.Width + 4,
							Span = river.Width + 26,
							Kind = road.Material == "Asphalt" and "Concrete" or "Truss",
							River = river.Name,
						})
					end
				end
			end
		end
	end
end

--------------------------------------------------------------- entry point

function Plans.build(layout, Rng)
	local plan = {
		flats = {},
		paints = {},
		lanes = {},
		hqs = {},
		sites = {},
		outposts = {},
		bridges = {},
	}
	local rng = Rng.new(layout.Seed + 7)
	for teamId, def in pairs(layout.HQs) do
		planHQ(plan, teamId, def)
	end
	planMilitaryBase(plan, layout.Sites.MilitaryBase)
	planIndustrial(plan, layout.Sites.Industrial)
	planVillage(plan, layout.Sites.Village, rng)
	planOutposts(plan, layout)
	planBridges(plan, layout)
	return plan
end

return Plans
