--[[
	Outposts
	Points of interest between the objectives: woodland checkpoints, ruined
	farmstead and chapel, old mill, radio mast, lookout, woodcutters' cabins,
	bunkers, footbridges; plus road bridges, trench dressing and utility lines.
]]

local Kit = require(script.Parent.Parent.Kit)
local Props = require(script.Parent.Parent.Props)
local Buildings = require(script.Parent.Parent.Buildings)
local Structures = require(script.Parent.Parent.Structures)
local Foliage = require(script.Parent.Parent.Foliage)

local Outposts = {}

local M = Enum.Material
local rgb = Color3.fromRGB

local function building(ctx, parent, e, spec, rng)
	local model = Kit.model(parent, spec.Type, true)
	local cf = Structures.frameFor(ctx, e) * (spec.Offset or CFrame.new())
	local builders = { Ruin = Buildings.ruin, Cottage = Buildings.house, Bunker = Buildings.bunker, Watchtower = Buildings.watchtower, Tent = Buildings.tent }
	builders[spec.Type](model, cf, spec, rng)
	return model
end

local BUILDERS = {}

function BUILDERS.Checkpoint(ctx, parent, e, rng)
	local cf = Structures.frameFor(ctx, e)
	local half = e.RoadWidth / 2
	local booth = Kit.model(parent, "GuardBooth", true)
	Buildings.guardBooth(booth, cf * CFrame.new(half + 5, 0, 3) * CFrame.Angles(0, math.pi / 2, 0), {}, rng)
	Props.boomGate(parent, cf, e.RoadWidth + 1)
	Props.sandbags(parent, cf * CFrame.new(-half - 4, 0, -4) * CFrame.Angles(0, math.pi / 2, 0), 8, rng)
	Props.sandbagNest(parent, cf * CFrame.new(-half - 8, 0, 6) * CFrame.Angles(0, math.pi / 2, 0), rng)
	Props.jerseyBarrier(parent, cf * CFrame.new(half - 2, 0, -14) * CFrame.Angles(0, math.rad(8), 0))
	Props.jerseyBarrier(parent, cf * CFrame.new(-half + 2, 0, 14) * CFrame.Angles(0, math.rad(-8), 0))
	Props.lampPost(parent, cf * CFrame.new(half + 2, 0, -3))
	Props.crateStack(parent, cf * CFrame.new(half + 10, 0, 10), rng)
	Kit.sign(parent, cf * CFrame.new(half + 1, 3, -8), 4, 1.4, "HALT", rgb(200, 50, 40), rgb(250, 245, 235))
end

function BUILDERS.Farmstead(ctx, parent, e, rng)
	building(ctx, parent, e, { Type = "Ruin", W = 16, D = 12, Style = "Stone" }, rng)
	building(ctx, parent, e, { Type = "Ruin", W = 14, D = 18, Style = "Wood", Offset = CFrame.new(-20, 0, 8) * CFrame.Angles(0, math.rad(90), 0) }, rng)
	local cf = Structures.frameFor(ctx, e)
	local function pt(lx, lz)
		local p = cf:PointToWorldSpace(Vector3.new(lx, 0, lz))
		return Vector3.new(p.X, ctx.hf:groundAt(p.X, p.Z), p.Z)
	end
	Props.fence(parent, pt(-30, -18), pt(10, -18), "Wood")
	Props.fence(parent, pt(16, -18), pt(26, -18), "Wood")
	Props.fence(parent, pt(26, -18), pt(26, 22), "Wood")
	Props.fence(parent, pt(-30, -18), pt(-30, 22), "Wood")
	Props.cart(parent, cf * CFrame.new(12, 0, 4) * CFrame.Angles(0, math.rad(35), 0))
	Props.hayBale(parent, cf * CFrame.new(-8, 0, -12))
	Props.hayBale(parent, cf * CFrame.new(-4, 0, -13) * CFrame.Angles(0, 0.5, 0))
	for i = 0, 3 do
		local p = cf * CFrame.new(14 + (i % 2) * 7, 0, 12 + math.floor(i / 2) * 7)
		Foliage.tree(parent, "Oak", p.X, p.Z, p.Y, rng, 0.6)
	end
end

function BUILDERS.Chapel(ctx, parent, e, rng)
	building(ctx, parent, e, { Type = "Ruin", W = 14, D = 22, Style = "Stone" }, rng)
	local cf = Structures.frameFor(ctx, e)
	-- Broken bell tower stump
	Kit.box(parent, cf * CFrame.new(0, 7, -13.5), 6, 14, 5, M.Cobblestone, rgb(150, 145, 136))
	Kit.box(parent, cf * CFrame.new(1.2, 15, -13.5), 3.6, 2, 5, M.Cobblestone, rgb(150, 145, 136))
	local function pt(lx, lz)
		local p = cf:PointToWorldSpace(Vector3.new(lx, 0, lz))
		return Vector3.new(p.X, ctx.hf:groundAt(p.X, p.Z), p.Z)
	end
	Props.fence(parent, pt(-16, -20), pt(-3, -20), "Stone")
	Props.fence(parent, pt(3, -20), pt(16, -20), "Stone")
	Props.fence(parent, pt(16, -20), pt(16, 20), "Stone")
	Props.fence(parent, pt(-16, -20), pt(-16, 20), "Stone")
	for i = 1, 3 do
		local p = cf * CFrame.new(rng:range(-12, 12), 0, rng:range(14, 20))
		Foliage.tree(parent, "Birch", p.X, p.Z, p.Y, rng, 0.8)
	end
end

function BUILDERS.Mill(ctx, parent, e, rng)
	building(ctx, parent, e, { Type = "Ruin", W = 14, D = 12, Style = "Stone" }, rng)
	local cf = Structures.frameFor(ctx, e)
	-- Wheel mounted against the river-facing wall; axle runs into the wall (local Z).
	local wheelCf = cf * CFrame.new(-2, 4.2, -7) * CFrame.Angles(0, math.pi / 2, 0)
	local wheel = Kit.model(parent, "WaterWheel", true)
	Kit.part(wheel, wheelCf, Vector3.new(1.2, 10, 10), M.WoodPlanks, rgb(92, 72, 54), { Shape = Enum.PartType.Cylinder, Name = "Wheel" })
	for i = 0, 7 do
		local a = i * math.pi / 4
		Kit.box(wheel, wheelCf * CFrame.Angles(a, 0, 0) * CFrame.new(0, 5, 0), 2.4, 1.6, 0.3, M.WoodPlanks, rgb(80, 62, 46))
	end
	Kit.cylinder(wheel, (wheelCf * CFrame.new(-3, 0, 0)).Position, (wheelCf * CFrame.new(3, 0, 0)).Position, 0.8, M.Metal, rgb(60, 60, 60))
	Kit.box(wheel, cf * CFrame.new(-2, 1, -8.2), 12, 2, 3.6, M.Cobblestone, rgb(130, 126, 118), { Name = "MillRace" })
end

function BUILDERS.RadioMast(ctx, parent, e, rng)
	local cf = Structures.frameFor(ctx, e)
	local model = Kit.model(parent, "RadioMast", true)
	local h = 52
	local legs = { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }
	local function legPos(i, y)
		local s = 3.5 * (1 - y / h * 0.7)
		return (cf * CFrame.new(legs[i][1] * s, y, legs[i][2] * s)).Position
	end
	for i = 1, 4 do
		Kit.beam(model, legPos(i, 0), legPos(i, h), 0.5, 0.5, M.Metal, rgb(200, 60, 50))
	end
	for level = 0, 4 do
		local y0, y1 = level * h / 5, (level + 1) * h / 5
		for i = 1, 4 do
			local j = i % 4 + 1
			Kit.beam(model, legPos(i, y0), legPos(j, y1), 0.2, 0.2, M.Metal, level % 2 == 0 and rgb(220, 220, 214) or rgb(200, 60, 50), { Decor = true })
			Kit.beam(model, legPos(i, y1), legPos(j, y1), 0.25, 0.25, M.Metal, rgb(220, 220, 214), { Decor = true })
		end
	end
	Kit.box(model, cf * CFrame.new(0, h + 0.5, 0), 2, 1, 2, M.Metal, rgb(90, 90, 90))
	Kit.box(model, cf * CFrame.new(0, h + 1.3, 0), 0.6, 0.6, 0.6, M.Neon, rgb(220, 50, 40), { Decor = true, Name = "AviationLight" })
	Kit.part(model, cf * CFrame.new(1.6, h * 0.7, 0) * CFrame.Angles(0, 0, math.rad(15)), Vector3.new(0.6, 4, 4), M.Metal, rgb(220, 220, 214), { Shape = Enum.PartType.Cylinder, Name = "Dish" })
	Kit.box(model, cf * CFrame.new(0, 0.4, 0), 10, 0.8, 10, M.Concrete, Props.Colors.Concrete)
	local shed = Kit.model(parent, "RelayShed", true)
	Buildings.guardBooth(shed, cf * CFrame.new(9, 0, 4) * CFrame.Angles(0, math.rad(-90), 0), {}, rng)
	Props.generator(parent, cf * CFrame.new(-8, 0, 6))
end

function BUILDERS.Lookout(ctx, parent, e, rng)
	building(ctx, parent, e, { Type = "Watchtower" }, rng)
	local cf = Structures.frameFor(ctx, e)
	Props.sandbagNest(parent, cf * CFrame.new(-9, 0, -4), rng)
	Props.crateStack(parent, cf * CFrame.new(8, 0, 2), rng)
end

function BUILDERS.Cabin(ctx, parent, e, rng)
	building(ctx, parent, e, { Type = "Cottage", W = 11, D = 9, Floors = 1, Style = "Wood" }, rng)
	local cf = Structures.frameFor(ctx, e)
	for i = 0, 3 do
		Kit.cylinder(parent, (cf * CFrame.new(-10, 0.8 + (i % 2) * 1.5, 1 + i * 1.5 - (i % 2) * 0.75)).Position,
			(cf * CFrame.new(-4, 0.8 + (i % 2) * 1.5, 1 + i * 1.5 - (i % 2) * 0.75)).Position, 1.5, M.Wood, rgb(110, 84, 60))
	end
	Kit.column(parent, (cf * CFrame.new(7, 0, -7)).Position, 1.8, 2.2, M.Wood, rgb(100, 78, 56), { Name = "ChoppingBlock" })
end

function BUILDERS.Bunker(ctx, parent, e, rng)
	building(ctx, parent, e, { Type = "Bunker", W = 12, D = 10 }, rng)
	local cf = Structures.frameFor(ctx, e)
	Props.camoNet(parent, cf * CFrame.new(0, 0, 9), 10, 8, 6)
	Props.sandbags(parent, cf * CFrame.new(0, 0, -8), 12, rng)
end

function BUILDERS.Footbridge(ctx, parent, e, rng)
	Structures.bridge(ctx, parent, { X = e.X, Z = e.Z, Yaw = e.Yaw, Span = 24, Width = 5, Kind = "Foot" }, rng)
end

--------------------------------------------------------------- trenches

local function dressTrench(ctx, parent, trench, rng)
	local hf = ctx.hf
	local model = Kit.model(parent, "Trench")
	local half = trench.Width / 2
	local pts = trench.Points
	local total = 0
	for i = 1, #pts - 1 do
		total += math.sqrt((pts[i + 1][1] - pts[i][1]) ^ 2 + (pts[i + 1][2] - pts[i][2]) ^ 2)
	end
	-- Front faces the village (Millbrook) at the map centre.
	local target = ctx.layout.Sites.Village.Center
	local run = 0
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local len = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
		local dx, dz = (b[1] - a[1]) / len, (b[2] - a[2]) / len
		local nx, nz = -dz, dx
		local mx, mz = (a[1] + b[1]) / 2, (a[2] + b[2]) / 2
		if (target[1] - mx) * nx + (target[2] - mz) * nz < 0 then
			nx, nz = -nx, -nz
		end
		local pieces = math.max(1, math.floor(len / 8))
		for p = 0, pieces - 1 do
			local s0, s1 = run + len * p / pieces, run + len * (p + 1) / pieces
			if s0 > 9 and s1 < total - 9 then
				local t = (p + 0.5) / pieces
				local cx, cz = a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t
				local floor = hf:groundAt(cx, cz)
				local plen = len / pieces
				local frame = Kit.lookAt(Vector3.new(cx, floor, cz), Vector3.new(cx + dx, floor, cz + dz))
				Kit.box(model, frame * CFrame.new(0, 0.15, 0), half * 2 - 1.2, 0.3, plen, M.WoodPlanks, rgb(104, 82, 60), { Name = "Duckboard" })
				for side = -1, 1, 2 do
					Kit.box(model, frame * CFrame.new(side * (half - 0.8), 2.6, 0), 0.4, 5.2, plen, M.WoodPlanks, rgb(92, 74, 56), { Name = "Revetment" })
					Kit.box(model, frame * CFrame.new(side * (half - 0.9), 2.6, -plen / 2 + 0.3), 0.5, 5.4, 0.5, M.Wood, rgb(70, 56, 44), { Decor = true })
				end
				local sx, sz = cx + nx * (half + 1.2), cz + nz * (half + 1.2)
				local sy = hf:groundAt(sx, sz)
				Props.sandbags(model, Kit.lookAt(Vector3.new(sx, sy, sz), Vector3.new(sx + dx, sy, sz + dz)) * CFrame.Angles(0, math.pi / 2, 0), plen, rng)
			end
		end
		run += len
	end
end

--------------------------------------------------------------- utility lines

local function utilityLine(ctx, parent)
	local model = Kit.model(parent, "PowerLine")
	local road = ctx.layout.Roads[1]
	local poles = {}
	for i = 1, #road.Points - 1 do
		local a, b = road.Points[i], road.Points[i + 1]
		local len = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
		local dx, dz = (b[1] - a[1]) / len, (b[2] - a[2]) / len
		for s = 0, len - 1, 44 do
			local x, z = a[1] + dx * s + dz * 15, a[2] + dz * s - dx * 15
			local h, info = ctx.hf:height(x, z)
			local inVillage = math.abs(z - 20) < 175 and math.abs(x - 40) < 175
			local nearHQ = math.abs(z) > 520
			if not inVillage and not nearHQ and not info.water and info.riverD > 10 then
				table.insert(poles, Kit.lookAt(Vector3.new(x, h, z), Vector3.new(x + dx, h, z + dz)))
			else
				table.insert(poles, false)
			end
		end
	end
	for i, cf in ipairs(poles) do
		if cf then
			Props.utilityPole(model, cf)
			local nextCf = poles[i + 1]
			if nextCf then
				Props.wires(model, cf, nextCf)
			end
		end
	end
end

function Outposts.build(ctx, rng)
	local folder = Kit.model(ctx.map, "Outposts")
	for _, e in ipairs(ctx.plan.outposts) do
		local builder = BUILDERS[e.Type]
		if builder then
			local sub = Kit.model(folder, e.Type)
			builder(ctx, sub, e, rng)
		end
	end
	local bridges = Kit.model(ctx.map, "Bridges")
	for _, b in ipairs(ctx.plan.bridges) do
		Structures.bridge(ctx, bridges, b, rng)
	end
	local trenches = Kit.model(ctx.map, "Trenches")
	for _, t in ipairs(ctx.layout.Trenches or {}) do
		dressTrench(ctx, trenches, t, rng)
	end
	utilityLine(ctx, folder)
	return folder
end

return Outposts
