--[[
	Structures
	Dispatches planned structure entries (from Plans) to builders, and
	implements the non-building structures: perimeters, industrial equipment,
	depots, bridges. Entry fields: Type, X, Z, Yaw (+ type-specific).
]]

local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)
local Buildings = require(script.Parent.Buildings)

local Structures = {}

local M = Enum.Material
local rgb = Color3.fromRGB
local C = Props.Colors

local CONTAINER_COLORS = { rgb(140, 62, 48), rgb(52, 84, 128), rgb(62, 104, 74), rgb(130, 132, 128), rgb(196, 110, 44), rgb(92, 98, 72) }

local function frameFor(ctx, e)
	local y = ctx.hf:groundAt(e.X, e.Z)
	return CFrame.new(e.X, y, e.Z) * CFrame.Angles(0, math.rad(e.Yaw or 0), 0)
end
Structures.frameFor = frameFor

--------------------------------------------------------------- perimeters

-- Rectangle perimeter in the frame `cf` with gaps { Side = { offset, width } }.
local function perimeter(ctx, parent, cf, hx, hz, gates, builder)
	local sides = {
		North = { Vector3.new(-hx, 0, hz), Vector3.new(hx, 0, hz) },
		South = { Vector3.new(-hx, 0, -hz), Vector3.new(hx, 0, -hz) },
		East = { Vector3.new(hx, 0, -hz), Vector3.new(hx, 0, hz) },
		West = { Vector3.new(-hx, 0, -hz), Vector3.new(-hx, 0, hz) },
	}
	for name, ends in pairs(sides) do
		local a, b = ends[1], ends[2]
		local len = (b - a).Magnitude
		local dir = (b - a).Unit
		local cuts = {}
		local gate = gates and gates[name]
		if gate then
			local center = len / 2 + gate[1]
			table.insert(cuts, { center - gate[2] / 2, center + gate[2] / 2 })
		end
		local runs = {}
		local cursor = 0
		for _, c in ipairs(cuts) do
			table.insert(runs, { cursor, c[1] })
			cursor = c[2]
		end
		table.insert(runs, { cursor, len })
		for _, run in ipairs(runs) do
			if run[2] - run[1] > 1 then
				-- Split into short pieces that follow the ground.
				local n = math.max(1, math.ceil((run[2] - run[1]) / 24))
				for i = 0, n - 1 do
					local s0 = run[1] + (run[2] - run[1]) * i / n
					local s1 = run[1] + (run[2] - run[1]) * (i + 1) / n
					local p0 = cf:PointToWorldSpace(a + dir * s0)
					local p1 = cf:PointToWorldSpace(a + dir * s1)
					p0 = Vector3.new(p0.X, ctx.hf:groundAt(p0.X, p0.Z), p0.Z)
					p1 = Vector3.new(p1.X, ctx.hf:groundAt(p1.X, p1.Z), p1.Z)
					builder(p0, p1)
				end
			end
		end
	end
end

function Structures.fence(ctx, parent, e)
	local cf = frameFor(ctx, e)
	local model = Kit.model(parent, "Perimeter")
	perimeter(ctx, model, cf, e.HX, e.HZ, e.Gates, function(a, b)
		Props.fence(model, a, b, e.Style)
	end)
	return model
end

function Structures.hescoPerimeter(ctx, parent, e)
	local cf = frameFor(ctx, e)
	local model = Kit.model(parent, "HescoPerimeter")
	local gates = { South = { 0, e.FrontGap }, North = { 0, e.BackGap } }
	perimeter(ctx, model, cf, e.HX, e.HZ, gates, function(a, b)
		local mid = (a + b) / 2
		local dir = (b - a).Unit
		local frame = Kit.lookAt(mid, mid + dir) * CFrame.Angles(0, math.pi / 2, 0)
		Props.hesco(model, frame, (b - a).Magnitude)
	end)
	return model
end

--------------------------------------------------------------- industrial

function Structures.tankFarm(ctx, parent, e, rng)
	local cf = frameFor(ctx, e)
	local model = Kit.model(parent, "TankFarm", true)
	local tanks = { Vector3.new(-12, 0, 8), Vector3.new(12, 0, 8), Vector3.new(0, 0, -12) }
	local r, h = 7, 18
	local top = h + 0.6
	for i, p in ipairs(tanks) do
		local base = cf:PointToWorldSpace(p)
		Kit.box(model, CFrame.new(base + Vector3.new(0, 0.4, 0)), 2 * r + 2, 0.8, 2 * r + 2, M.Concrete, C.ConcreteDark)
		Kit.column(model, base + Vector3.new(0, 0.8, 0), h - 0.8, 2 * r, M.Metal, rgb(196, 194, 186), { Name = "Tank" })
		Kit.column(model, base + Vector3.new(0, h, 0), 0.6, 2 * r + 0.4, M.Metal, rgb(150, 150, 146))
		Kit.column(model, base + Vector3.new(0, h * 0.35, 0), 1.2, 2 * r + 0.1, M.Metal, i == 2 and C.Hazard or C.Rust, { Decor = true })
		-- Outlet pipe to the rack
		Kit.cylinder(model, base + Vector3.new(0, 2, 0), base + cf:VectorToWorldSpace(Vector3.new(-r - 6, 0, 0)) + Vector3.new(0, 2, 0), 1.2, M.Metal, rgb(80, 100, 112))
	end
	-- Stair to the top of tank 2 and catwalks between tank tops.
	Kit.stairs(model, cf * CFrame.new(20.6, 0, 8 + top), 3.2, top, top, M.DiamondPlate, rgb(110, 112, 114))
	Kit.box(model, cf * CFrame.new(19.8, top - 0.3, 7), 3.6, 0.6, 3.2, M.DiamondPlate, rgb(110, 112, 114))
	local function catwalk(p, q)
		local a = cf:PointToWorldSpace(p) + Vector3.new(0, top - 0.25, 0)
		local b = cf:PointToWorldSpace(q) + Vector3.new(0, top - 0.25, 0)
		local dir = (b - a).Unit
		a -= dir * 2
		b += dir * 2
		Kit.beam(model, a, b, 2.6, 0.5, M.DiamondPlate, rgb(110, 112, 114), { Name = "Catwalk" })
		local side = dir:Cross(Vector3.new(0, 1, 0)).Unit * 1.3
		Kit.railing(model, a + side + Vector3.new(0, 0.25, 0), b + side + Vector3.new(0, 0.25, 0), 3.2, M.Metal, C.Hazard, 6)
		Kit.railing(model, a - side + Vector3.new(0, 0.25, 0), b - side + Vector3.new(0, 0.25, 0), 3.2, M.Metal, C.Hazard, 6)
	end
	catwalk(Vector3.new(5, 0, 8), Vector3.new(-5, 0, 8))
	catwalk(Vector3.new(-8.6, 0, 1.8), Vector3.new(-3.4, 0, -6.2))
	Kit.sign(model, cf * CFrame.new(0, 3, -12 - r - 0.3), 6, 1.2, "FLAMMABLE", rgb(200, 60, 40), rgb(250, 240, 220))
	return model
end

function Structures.silos(ctx, parent, e)
	local cf = frameFor(ctx, e)
	local model = Kit.model(parent, "Silos", true)
	for _, x in ipairs({ -6, 6 }) do
		local base = cf:PointToWorldSpace(Vector3.new(x, 0, 0))
		Kit.column(model, base, 30, 10, M.Metal, rgb(170, 172, 170), { Name = "Silo" })
		Kit.column(model, base + Vector3.new(0, 30, 0), 2, 8, M.Metal, rgb(150, 152, 150))
		Kit.column(model, base + Vector3.new(0, 32, 0), 1.5, 4, M.Metal, rgb(130, 132, 130))
		for band = 1, 3 do
			Kit.column(model, base + Vector3.new(0, band * 8, 0), 0.4, 10.2, M.Metal, rgb(120, 122, 120), { Decor = true })
		end
		Kit.box(model, CFrame.new(base) * CFrame.new(0, 15, -5.3), 0.9, 30, 0.3, M.Metal, C.Steel, { Decor = true, Name = "Ladder" })
	end
	-- Conveyor feeding the silo tops from a ground hopper.
	local low = cf:PointToWorldSpace(Vector3.new(0, 2, 20))
	local high = cf:PointToWorldSpace(Vector3.new(0, 32, 0))
	Kit.beam(model, low, high, 2.4, 1, M.Metal, rgb(90, 96, 100), { Name = "Conveyor" })
	for _, t in ipairs({ 0.3, 0.6 }) do
		local p = low:Lerp(high, t)
		Kit.box(model, CFrame.new(Vector3.new(p.X, (p.Y + cf.Y) / 2, p.Z)), 0.7, p.Y - cf.Y, 0.7, M.Metal, C.Hazard)
	end
	Kit.box(model, cf * CFrame.new(0, 2.5, 22), 5, 5, 5, M.Metal, rgb(120, 110, 90), { Name = "Hopper" })
	return model
end

function Structures.chimney(ctx, parent, e)
	local cf = frameFor(ctx, e)
	local model = Kit.model(parent, "Chimney", true)
	local base = cf.Position
	Kit.box(model, cf * CFrame.new(0, 2, 0), 11, 4, 11, M.Concrete, C.ConcreteDark)
	Kit.column(model, base + Vector3.new(0, 4, 0), 56, 7, M.Brick, rgb(130, 86, 70), { Name = "Stack" })
	for i, y in ipairs({ 50, 54 }) do
		Kit.column(model, base + Vector3.new(0, y, 0), 2, 7.2, M.SmoothPlastic, i == 1 and C.Red or C.White, { Decor = true })
	end
	Kit.column(model, base + Vector3.new(0, 60, 0), 0.8, 7.6, M.Concrete, C.ConcreteDark)
	Kit.box(model, cf * CFrame.new(0, 61, 0), 0.6, 0.6, 0.6, M.Neon, rgb(210, 50, 40), { Decor = true, Name = "AviationLight" })
	return model
end

function Structures.containerStack(ctx, parent, e, rng)
	local cf = frameFor(ctx, e)
	local model = Kit.model(parent, "ContainerStack", true)
	local byKey = {}
	for _, c in ipairs(e.Layout) do
		local x, level = c[1], c[3]
		Props.container(model, cf * CFrame.new(x, level * 8.5, c[2]), CONTAINER_COLORS[rng:int(1, #CONTAINER_COLORS)])
		byKey[x .. ":" .. level] = true
	end
	-- Ground stair onto the first container (climbs toward +X onto its −X side).
	local first = e.Layout[1]
	Kit.stairs(model, cf * CFrame.new(first[1] - 4 - 8.6, 0, first[2]) * CFrame.Angles(0, -math.pi / 2, 0), 3, 8.6, 8.6, M.DiamondPlate, rgb(110, 112, 114))
	-- Stairs from a neighbouring container top up to any second-level container.
	for _, c in ipairs(e.Layout) do
		if c[3] == 1 then
			for _, dir in ipairs({ -1, 1 }) do
				if byKey[(c[1] + dir * 10) .. ":0"] then
					local edge = c[1] + dir * 4 -- side of the upper container
					local start = edge + dir * 8.5
					local yaw = dir == -1 and -math.pi / 2 or math.pi / 2
					Kit.stairs(model, cf * CFrame.new(start, 8.5, c[2] + 5) * CFrame.Angles(0, yaw, 0), 3, 8.5, 8.5, M.DiamondPlate, rgb(110, 112, 114))
					break
				end
			end
		end
	end
	return model
end

function Structures.gantry(ctx, parent, e)
	local cf = frameFor(ctx, e)
	local model = Kit.model(parent, "Gantry", true)
	local span, length, h = e.Span, e.Length, 24
	local yellow = rgb(214, 170, 48)
	for _, z in ipairs({ -length / 2 + 4, length / 2 - 4 }) do
		for _, x in ipairs({ -span / 2, span / 2 }) do
			Kit.beam(model, (cf * CFrame.new(x, 0, z - 2.5)).Position, (cf * CFrame.new(x, h, z)).Position, 1.2, 1.2, M.Metal, yellow)
			Kit.beam(model, (cf * CFrame.new(x, 0, z + 2.5)).Position, (cf * CFrame.new(x, h, z)).Position, 1.2, 1.2, M.Metal, yellow)
			Kit.box(model, cf * CFrame.new(x, 0.6, z), 1.8, 1.2, 7, M.Metal, rgb(60, 60, 60))
		end
		Kit.box(model, cf * CFrame.new(0, h + 1, z), span + 3, 2, 2, M.Metal, yellow)
	end
	for _, x in ipairs({ -span / 2, span / 2 }) do
		Kit.box(model, cf * CFrame.new(x, 0.15, 0), 0.6, 0.3, length, M.Metal, C.Steel, { Decor = true })
	end
	Kit.box(model, cf * CFrame.new(-4, h + 2.6, -length / 4), 5, 1.6, 5, M.Metal, rgb(60, 64, 68), { Name = "Trolley" })
	Kit.box(model, cf * CFrame.new(-4, h / 2 + 7, -length / 4), 0.2, h - 8, 0.2, M.Metal, rgb(30, 30, 30), { Decor = true })
	Kit.box(model, cf * CFrame.new(-4, 11, -length / 4), 1.6, 1.6, 1.6, M.Metal, yellow, { Decor = true, Name = "Hook" })
	for _, x in ipairs({ -span / 2 + 1, span / 2 - 1 }) do
		Kit.box(model, cf * CFrame.new(x, h + 2.2, 0), 1.6, 1.6, length - 6, M.Metal, yellow)
	end
	return model
end

function Structures.pipeRack(ctx, parent, e)
	local cf = frameFor(ctx, e)
	local model = Kit.model(parent, "PipeRack")
	local L = e.Length
	local n = math.floor(L / 8)
	for i = 0, n do
		local z = -L / 2 + i * L / n
		for _, x in ipairs({ -2, 2 }) do
			Kit.box(model, cf * CFrame.new(x, 3.8, z), 0.6, 7.6, 0.6, M.Metal, C.Steel)
		end
		Kit.box(model, cf * CFrame.new(0, 7.4, z), 4.8, 0.5, 0.6, M.Metal, C.Steel)
	end
	local pipes = { { -1.2, 1.4, rgb(150, 154, 156) }, { 0.2, 1, C.Hazard }, { 1.4, 1.6, rgb(80, 100, 112) } }
	for _, p in ipairs(pipes) do
		Kit.cylinder(model, (cf * CFrame.new(p[1], 7.65 + p[2] / 2, -L / 2 - 1)).Position, (cf * CFrame.new(p[1], 7.65 + p[2] / 2, L / 2 + 1)).Position, p[2], M.Metal, p[3])
	end
	return model
end

function Structures.loadingDock(ctx, parent, e)
	local cf = frameFor(ctx, e)
	local model = Kit.model(parent, "LoadingDock")
	local w, d, h = e.W, e.D, 4
	Kit.box(model, cf * CFrame.new(0, h / 2 - 0.5, 0), w, h + 1, d, M.Concrete, C.Concrete, { Name = "Dock" })
	Kit.box(model, cf * CFrame.new(0, h - 0.1, -d / 2 + 0.3), w, 0.25, 0.6, M.SmoothPlastic, C.Hazard, { Decor = true })
	for i = -2, 2 do
		Kit.box(model, cf * CFrame.new(i * w / 5, h * 0.6, -d / 2 - 0.3), 1.4, 1.6, 0.6, M.Rubber, rgb(30, 30, 30))
	end
	Kit.stairs(model, cf * CFrame.new(-w / 2 - 1.8, 0, -d / 2 + 0.5) * CFrame.Angles(0, math.pi, 0), 3.2, h, h + 0.5, M.Concrete, C.ConcreteDark)
	return model
end

--------------------------------------------------------------- depots & military

function Structures.supplyDepot(ctx, parent, e, rng)
	local cf = frameFor(ctx, e)
	local model = Kit.model(parent, "SupplyDepot")
	Props.container(model, cf * CFrame.new(-6, 0, 0), C.Olive)
	Props.crateStack(model, cf * CFrame.new(4, 0, -6), rng)
	Props.crateStack(model, cf * CFrame.new(5, 0, 5), rng)
	Props.barrelGroup(model, cf * CFrame.new(8, 0, -1), rng, 4)
	Props.camoNet(model, cf * CFrame.new(4, 0, 0), 12, 18, 7.5)
	return model
end

function Structures.fuelDepot(ctx, parent, e, rng)
	local cf = frameFor(ctx, e)
	local model = Kit.model(parent, "FuelDepot")
	for i = -1, 1 do
		Props.fuelTank(model, cf * CFrame.new(i * 8, 0, 0) * CFrame.Angles(0, math.pi / 2, 0))
	end
	Props.sandbags(model, cf * CFrame.new(0, 0, -9), 26, rng)
	Props.sandbags(model, cf * CFrame.new(0, 0, 9), 26, rng)
	Props.barrelGroup(model, cf * CFrame.new(14, 0, -4), rng, 4)
	Kit.sign(model, cf * CFrame.new(0, 3, -9.9), 6, 1.2, "NO NAKED FLAMES", rgb(200, 60, 40), rgb(250, 240, 220))
	return model
end

function Structures.containerYard(ctx, parent, e, rng)
	local cf = frameFor(ctx, e)
	local model = Kit.model(parent, "ContainerYard")
	for i = 0, 2 do
		Props.container(model, cf * CFrame.new(-10 + i * 10, 0, 0), CONTAINER_COLORS[rng:int(1, #CONTAINER_COLORS)])
	end
	Props.crateStack(model, cf * CFrame.new(-6, 0, 14), rng)
	Props.pallet(model, cf * CFrame.new(6, 0, 14))
	return model
end

function Structures.commandBunker(ctx, parent, e, rng)
	local cf = frameFor(ctx, e)
	local model = Kit.model(parent, "CommandBunker", true)
	Buildings.bunker(model, cf, e, rng)
	Props.antenna(model, cf * CFrame.new(e.W / 2 - 2, Buildings.FloorTop + 9.6, e.D / 2 - 2))
	Props.table(model, cf * CFrame.new(0, Buildings.FloorTop, 0), 6, 4)
	Props.generator(model, cf * CFrame.new(-e.W / 2 - 4, 0, 0) * CFrame.Angles(0, math.pi / 2, 0))
	return model
end

--------------------------------------------------------------- bridges

function Structures.bridge(ctx, parent, e, rng)
	local hf = ctx.hf
	local water = ctx.layout.WaterLevel
	local deckTop = math.max(water + 4.4, hf:groundAt(e.X, e.Z) + 0.3)
	local cf = CFrame.new(e.X, deckTop, e.Z) * CFrame.Angles(0, math.rad(e.Yaw), 0)
	local model = Kit.model(parent, "Bridge", true)
	local span, width = e.Span, e.Width
	local bed = water - 9
	if e.Kind == "Concrete" then
		Kit.box(model, cf * CFrame.new(0, -0.9, 0), width, 1.8, span, M.Concrete, C.Concrete, { Name = "Deck" })
		Kit.box(model, cf * CFrame.new(0, 0.02, 0), width - 3, 0.1, span, M.Asphalt, rgb(62, 63, 66), { Decor = true, NoShadow = true })
		for side = -1, 1, 2 do
			Kit.box(model, cf * CFrame.new(side * (width / 2 - 0.5), 1.4, 0), 1, 2.8, span, M.Concrete, rgb(160, 158, 150), { Name = "Parapet" })
		end
		for _, z in ipairs({ -span / 4, span / 4 }) do
			Kit.box(model, cf * CFrame.new(0, (bed - deckTop) / 2 - 1, z), width - 4, deckTop - bed, 3, M.Concrete, C.ConcreteDark, { Name = "Pier" })
		end
		for _, z in ipairs({ -span / 2, span / 2 }) do
			Kit.box(model, cf * CFrame.new(0, -4, z), width + 2, 6, 4, M.Concrete, C.ConcreteDark, { Name = "Abutment" })
		end
	elseif e.Kind == "Truss" then
		Kit.box(model, cf * CFrame.new(0, -0.6, 0), width, 1.2, span, M.WoodPlanks, rgb(112, 88, 62), { Name = "Deck" })
		local steel = rgb(74, 84, 70)
		for side = -1, 1, 2 do
			local x = side * (width / 2 + 0.3)
			Kit.box(model, cf * CFrame.new(x, 0.3, 0), 0.6, 0.6, span, M.Metal, steel)
			Kit.box(model, cf * CFrame.new(x, 6.6, 0), 0.6, 0.6, span - 8, M.Metal, steel)
			local n = 5
			for i = 0, n do
				local z = -span / 2 + 4 + i * (span - 8) / n
				Kit.box(model, cf * CFrame.new(x, 3.4, z), 0.5, 6.4, 0.5, M.Metal, steel)
				if i < n then
					local z2 = -span / 2 + 4 + (i + 1) * (span - 8) / n
					Kit.beam(model, (cf * CFrame.new(x, 0.4, z)).Position, (cf * CFrame.new(x, 6.5, z2)).Position, 0.35, 0.35, M.Metal, steel, { Decor = true })
				end
			end
			Kit.beam(model, (cf * CFrame.new(x, 0.4, -span / 2)).Position, (cf * CFrame.new(x, 6.6, -span / 2 + 4)).Position, 0.5, 0.5, M.Metal, steel)
			Kit.beam(model, (cf * CFrame.new(x, 0.4, span / 2)).Position, (cf * CFrame.new(x, 6.6, span / 2 - 4)).Position, 0.5, 0.5, M.Metal, steel)
		end
		for _, z in ipairs({ -span / 2, span / 2 }) do
			Kit.box(model, cf * CFrame.new(0, -3.4, z), width + 2, 5, 3, M.Concrete, C.ConcreteDark, { Name = "Abutment" })
		end
		Kit.box(model, cf * CFrame.new(0, (bed - deckTop) / 2, 0), width - 2, deckTop - bed, 2.4, M.Concrete, C.ConcreteDark, { Name = "Pier" })
	else -- Footbridge
		Kit.box(model, cf * CFrame.new(0, -0.3, 0), 5, 0.6, span, M.WoodPlanks, rgb(116, 92, 66), { Name = "Deck" })
		for side = -1, 1, 2 do
			Kit.railing(model, (cf * CFrame.new(side * 2.3, 0, -span / 2)).Position, (cf * CFrame.new(side * 2.3, 0, span / 2)).Position, 3.2, M.Wood, rgb(84, 66, 50), 5)
		end
		for _, z in ipairs({ -span / 4, span / 4 }) do
			Kit.box(model, cf * CFrame.new(0, (bed - deckTop) / 2, z), 0.8, deckTop - bed, 0.8, M.Wood, rgb(84, 66, 50))
		end
	end
	return model
end

--------------------------------------------------------------- dispatch

local BUILDING = {
	House1 = Buildings.house, House2 = Buildings.house, Cottage = Buildings.house, Shop = Buildings.house, Tavern = Buildings.house,
	Hall = Buildings.hall, Barn = Buildings.barn, Ruin = Buildings.ruin,
	Barracks = Buildings.barracks, CommandPost = Buildings.commandPost, Hangar = Buildings.hangar,
	Warehouse = Buildings.warehouse, Maintenance = Buildings.maintenance, PumpHouse = Buildings.bunker, Bunker = Buildings.bunker,
	Watchtower = Buildings.watchtower, GuardBooth = Buildings.guardBooth, VehicleShed = Buildings.vehicleShed, Tent = Buildings.tent,
}

local SPECIAL = {
	Fence = Structures.fence,
	HescoPerimeter = Structures.hescoPerimeter,
	TankFarm = Structures.tankFarm,
	Silos = Structures.silos,
	Chimney = Structures.chimney,
	ContainerStack = Structures.containerStack,
	Gantry = Structures.gantry,
	PipeRack = Structures.pipeRack,
	LoadingDock = Structures.loadingDock,
	SupplyDepot = Structures.supplyDepot,
	FuelDepot = Structures.fuelDepot,
	ContainerYard = Structures.containerYard,
	CommandBunker = Structures.commandBunker,
}

local SIMPLE = {
	Helipad = function(model, cf)
		Props.helipad(model, cf)
	end,
	Antenna = function(model, cf)
		Props.antenna(model, cf)
	end,
	SandbagNest = function(model, cf, rng)
		Props.sandbagNest(model, cf, rng)
	end,
}

--[[
	build(ctx, parent, entry, rng) -> Model
	ctx: { hf, layout, ... }. Uses the heightfield for the ground level.
]]
function Structures.build(ctx, parent, e, rng)
	local builder = BUILDING[e.Type]
	if builder then
		local model = Kit.model(parent, e.Name or e.Type, true)
		if e.Type == "PumpHouse" then
			e.Pipes = true
		end
		builder(model, frameFor(ctx, e), e, rng)
		return model
	end
	local special = SPECIAL[e.Type]
	if special then
		return special(ctx, parent, e, rng)
	end
	local simple = SIMPLE[e.Type]
	if simple then
		local model = Kit.model(parent, e.Type)
		simple(model, frameFor(ctx, e), rng)
		return model
	end
	warn("[Structures] unknown structure type " .. tostring(e.Type))
	return nil
end

return Structures
