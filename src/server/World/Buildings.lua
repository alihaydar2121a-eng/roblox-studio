--[[
	Buildings
	Parametric building archetypes with enterable interiors, working stairs
	(solid steps + invisible ramp), framed doors/windows and pitched, flat or
	vaulted roofs. Each builder: (model, cf, spec, rng) where cf is the
	ground-level centre of the footprint and local −Z is the front.
]]

local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local Buildings = {}

local M = Enum.Material
local rgb = Color3.fromRGB
local FT = 0.8 -- floor top above the ground pad
local T = 0.8 -- wall thickness
local SW = 3.4 -- stair width

Buildings.FloorTop = FT

local PLASTER = { rgb(214, 204, 180), rgb(206, 182, 140), rgb(184, 190, 168), rgb(222, 216, 204), rgb(196, 160, 128) }

local function styleFor(name, rng)
	if name == "Brick" then
		return { Wall = M.Brick, WallColor = rng:pick({ rgb(138, 82, 66), rgb(122, 74, 62), rgb(146, 96, 72) }),
			Trim = M.Concrete, TrimColor = rgb(196, 190, 176), Roof = M.RoofShingles, RoofColor = rgb(70, 68, 70),
			Base = M.Concrete, BaseColor = rgb(120, 116, 110), Shutters = rgb(52, 74, 64) }
	elseif name == "Stone" then
		return { Wall = M.Cobblestone, WallColor = rgb(150, 145, 136), Trim = M.Limestone, TrimColor = rgb(196, 188, 170),
			Roof = M.Slate, RoofColor = rgb(72, 74, 80), Base = M.Slate, BaseColor = rgb(96, 96, 96), Shutters = rgb(80, 60, 44) }
	elseif name == "Timber" then
		return { Wall = M.Plaster, WallColor = rgb(222, 212, 188), Trim = M.Wood, TrimColor = rgb(70, 52, 40),
			Roof = M.ClayRoofTiles, RoofColor = rgb(142, 76, 56), Base = M.Cobblestone, BaseColor = rgb(120, 116, 108), Beams = true }
	elseif name == "Wood" then
		return { Wall = M.WoodPlanks, WallColor = rng:pick({ rgb(126, 96, 68), rgb(108, 86, 64), rgb(92, 104, 88) }),
			Trim = M.Wood, TrimColor = rgb(214, 206, 188), Roof = M.RoofShingles, RoofColor = rgb(84, 76, 72),
			Base = M.Cobblestone, BaseColor = rgb(110, 106, 100), Shutters = rgb(150, 60, 50) }
	elseif name == "Barn" then
		return { Wall = M.WoodPlanks, WallColor = rgb(128, 52, 44), Trim = M.WoodPlanks, TrimColor = rgb(222, 214, 200),
			Roof = M.CorrodedMetal, RoofColor = rgb(98, 100, 102), Base = M.Concrete, BaseColor = rgb(120, 118, 112) }
	elseif name == "Military" then
		return { Wall = M.Concrete, WallColor = rgb(168, 166, 154), Trim = M.Metal, TrimColor = rgb(86, 94, 70),
			Roof = M.CorrodedMetal, RoofColor = rgb(86, 94, 70), Base = M.Concrete, BaseColor = rgb(124, 122, 116) }
	elseif name == "Industrial" then
		return { Wall = M.Metal, WallColor = rng:pick({ rgb(118, 128, 136), rgb(156, 150, 136), rgb(126, 118, 104) }),
			Trim = M.Metal, TrimColor = rgb(208, 164, 52), Roof = M.CorrodedMetal, RoofColor = rgb(112, 104, 96),
			Base = M.Concrete, BaseColor = rgb(128, 126, 120) }
	end
	return { Wall = M.Plaster, WallColor = rng:pick(PLASTER), Trim = M.Wood, TrimColor = rgb(84, 64, 48),
		Roof = M.ClayRoofTiles, RoofColor = rng:pick({ rgb(150, 78, 56), rgb(128, 70, 54), rgb(112, 62, 50) }),
		Base = M.Cobblestone, BaseColor = rgb(118, 112, 104), Shutters = rng:pick({ rgb(60, 88, 70), rgb(70, 84, 110), rgb(120, 60, 48) }) }
end
Buildings.styleFor = styleFor

--------------------------------------------------------------- shared parts

local function foundation(model, cf, w, d, style)
	-- Deep plinth hides any mismatch between the pad and voxel terrain.
	Kit.box(model, cf * CFrame.new(0, FT - 3, 0), w + 0.8, 6, d + 0.8, style.Base, style.BaseColor, { Name = "Foundation" })
end

local function walls(model, cf, w, d, height, floors, H, style, opts, rng)
	local trim = { Material = style.Trim, Color = style.TrimColor, Shutters = style.Shutters, Door = rgb(92, 66, 46), Ruin = opts.Ruin }
	local function cols(length, door, wide)
		return Kit.bays(length, floors, H, { Door = door, Wide = wide, Bay = opts.Bay, WindowW = opts.WindowW, Sill = opts.Sill, Head = opts.Head,
			DoorW = opts.DoorW, DoorH = opts.DoorH, SkipFloors = opts.SkipFloors })
	end
	local frontCols = opts.FrontColumns or cols(w, opts.FrontDoor or "center", opts.Wide)
	local backCols = opts.BackColumns or cols(w, opts.BackDoor)
	local leftCols = opts.LeftColumns or cols(d - 2 * T, opts.SideDoors and "center" or nil)
	local rightCols = opts.RightColumns or cols(d - 2 * T, opts.SideDoors and "center" or nil)
	Kit.wall(model, cf * CFrame.new(0, FT, -d / 2 + T / 2), w, height, T, frontCols, style.Wall, style.WallColor, trim)
	Kit.wall(model, cf * CFrame.new(0, FT, d / 2 - T / 2) * CFrame.Angles(0, math.pi, 0), w, height, T, backCols, style.Wall, style.WallColor, trim)
	Kit.wall(model, cf * CFrame.new(-w / 2 + T / 2, FT, 0) * CFrame.Angles(0, math.pi / 2, 0), d - 2 * T, height, T, leftCols, style.Wall, style.WallColor, trim)
	Kit.wall(model, cf * CFrame.new(w / 2 - T / 2, FT, 0) * CFrame.Angles(0, -math.pi / 2, 0), d - 2 * T, height, T, rightCols, style.Wall, style.WallColor, trim)
	if opts.Ruin then
		return
	end
	-- Corner quoins / timber posts and floor bands.
	for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		Kit.box(model, cf * CFrame.new(c[1] * (w / 2 - 0.35), FT + height / 2, c[2] * (d / 2 - 0.35)), 1, height, 1, style.Trim, style.TrimColor)
	end
	for f = 2, floors do
		local y = FT + (f - 1) * H
		Kit.box(model, cf * CFrame.new(0, y, -d / 2 + 0.1), w + 0.2, 0.6, 0.6, style.Trim, style.TrimColor, { Decor = true })
		Kit.box(model, cf * CFrame.new(0, y, d / 2 - 0.1), w + 0.2, 0.6, 0.6, style.Trim, style.TrimColor, { Decor = true })
	end
	if style.Beams then
		for i = -1, 1, 2 do
			for f = 1, floors do
				local y0 = FT + (f - 1) * H
				Kit.beam(model, (cf * CFrame.new(i * (w / 2 - 1.2), y0 + 0.4, -d / 2 - 0.05)).Position,
					(cf * CFrame.new(i * (w / 2 - 3.6), y0 + H - 0.6, -d / 2 - 0.05)).Position, 0.5, 0.4, M.Wood, style.TrimColor, { Decor = true })
			end
		end
	end
end

--[[
	Interior levels and stairs. Flights run along the back wall: flight 1 on
	the rear strip climbing toward −X, flight 2 (roof access) on the next strip
	climbing toward +X. Returns the roof hole (if any) for flat roofs.
]]
local function interior(model, cf, w, d, H, floors, roofAccess, floorColor, stairMat, stairColor)
	local xl, xr, zf, zb = -w / 2 + T, w / 2 - T, -d / 2 + T, d / 2 - T
	local roofTop = FT + floors * H + 1
	local flights = (floors - 1) + (roofAccess and 1 or 0)
	local roofHole
	if flights >= 1 then
		local rise1 = (floors > 1 and (FT + H) or roofTop) - FT
		local xs1 = xr - 0.4
		local xe1 = xs1 - rise1
		Kit.stairs(model, cf * CFrame.new(xs1, FT, zb - SW / 2) * CFrame.Angles(0, math.pi / 2, 0), SW, rise1, rise1, stairMat, stairColor)
		local hole1 = { xe1, xr, zb - SW, zb }
		if floors > 1 then
			local y2 = FT + H
			Kit.levelSlab(model, cf * CFrame.new(0, y2, 0), xl, xr, zf, zb, { hole1 }, 0.8, M.WoodPlanks, floorColor)
			Kit.railing(model, (cf * CFrame.new(xe1 + 0.2, y2, zb - SW - 0.15)).Position, (cf * CFrame.new(xr - 0.2, y2, zb - SW - 0.15)).Position, 3, M.Wood, rgb(70, 54, 42))
			if roofAccess then
				local rise2 = roofTop - y2
				local xs2 = xe1 - 0.8
				local xe2 = xs2 + rise2
				Kit.stairs(model, cf * CFrame.new(xs2, y2, zb - 1.5 * SW) * CFrame.Angles(0, -math.pi / 2, 0), SW, rise2, rise2, stairMat, stairColor)
				roofHole = { xs2 - 0.2, xe2 + 0.2, zb - 2 * SW, zb - SW }
			end
		else
			roofHole = hole1
		end
	end
	return roofHole
end

local function furnish(model, cf, w, d, H, floors, rng, kind)
	local xl, xr, zf, zb = -w / 2 + T, w / 2 - T, -d / 2 + T, d / 2 - T
	local freeBack = floors > 1 and (zb - SW - 0.6) or (zb - 0.6)
	for f = 1, floors do
		local y = FT + (f - 1) * H
		local base = cf * CFrame.new(0, y, 0)
		if kind == "Barracks" then
			local n = math.floor((w - 4) / 5)
			for i = 0, n - 1 do
				local x = xl + 3 + i * 5
				Props.bunk(model, base * CFrame.new(x, 0, zb - 3.4))
			end
		elseif f == 1 then
			local zc = (zf + freeBack) / 2
			if (freeBack - zf) > 7 then
				Props.table(model, base * CFrame.new(xl + 3.2, 0, zc), 3, 4)
				Props.chair(model, base * CFrame.new(xl + 5.4, 0, zc) * CFrame.Angles(0, math.pi / 2, 0))
			end
			if kind == "Shop" or kind == "Tavern" then
				Kit.box(model, base * CFrame.new(xr - 1.2, 1.8, (zf + freeBack) / 2), 1.8, 3.6, math.max(2, (freeBack - zf) - 3), M.WoodPlanks, rgb(96, 70, 50), { Name = "Counter" })
			else
				Props.stove(model, base * CFrame.new(xr - 1.8, 0, zf + 1.8))
			end
			Props.rug(model, base * CFrame.new(0, 0, zc), math.min(6, w - 6), math.min(4, freeBack - zf - 1), rng:pick({ rgb(120, 50, 44), rgb(60, 70, 96), rgb(120, 100, 60) }))
		else
			Props.bed(model, base * CFrame.new(xl + 2, 0, zf + 3.6), rng:pick({ rgb(170, 160, 140), rgb(120, 130, 150) }))
			Props.shelf(model, base * CFrame.new(xr - 1, 0, zf + 3) * CFrame.Angles(0, -math.pi / 2, 0), 4)
		end
	end
end

local function chimney(model, cf, w, d, wallTop, pitch, style)
	local x = w / 2 - 2.2
	local z = d / 4
	local top = wallTop + pitch + 2
	local bottom = wallTop + pitch * (1 - (z / (d / 2))) - 1
	Kit.box(model, cf * CFrame.new(x, (top + bottom) / 2, z), 1.8, top - bottom, 1.8, M.Brick, rgb(120, 72, 60), { Name = "Chimney" })
	Kit.box(model, cf * CFrame.new(x, top + 0.2, z), 2.1, 0.4, 2.1, M.Concrete, style.TrimColor, { Decor = true })
end

--------------------------------------------------------------- civil

-- House1 / House2 / Cottage / Shop / Tavern
function Buildings.house(model, cf, b, rng)
	local style = styleFor(b.Style, rng)
	local w, d, floors = b.W, b.D, b.Floors or 1
	local H = 11
	local height = floors * H
	local kind = b.Type
	foundation(model, cf, w, d, style)
	walls(model, cf, w, d, height, floors, H, style, {
		FrontDoor = (kind == "Shop" or kind == "Tavern") and "center" or (w >= 16 and "left" or "center"),
		BackDoor = floors == 1 and "center" or nil,
		Wide = kind == "Shop",
	}, rng)
	-- Ground floor finish and upper levels.
	Kit.box(model, cf * CFrame.new(0, FT + 0.05, 0), w - 2 * T, 0.1, d - 2 * T, M.WoodPlanks, rgb(120, 92, 66), { Decor = true, NoShadow = true })
	interior(model, cf, w, d, H, floors, false, rgb(120, 92, 66), M.WoodPlanks, rgb(104, 78, 56))
	furnish(model, cf, w, d, H, floors, rng, kind)
	-- Ceiling under the attic so interiors read as rooms.
	Kit.box(model, cf * CFrame.new(0, FT + height - 0.3, 0), w - 2 * T, 0.6, d - 2 * T, M.WoodPlanks, rgb(110, 86, 62))
	local pitch = math.min(7, d * 0.38)
	Kit.gableRoof(model, cf * CFrame.new(0, FT + height, 0), w, d, pitch, 1.2, style.Roof, style.RoofColor, style.Wall, style.WallColor, T)
	if kind ~= "Shop" then
		chimney(model, cf, w, d, FT + height, pitch, style)
	end
	-- Door step
	Kit.box(model, cf * CFrame.new((w >= 16 and kind ~= "Shop" and kind ~= "Tavern") and (-w / 2 + (w / math.max(1, math.floor(w / 8))) / 2) or 0, 0.4, -d / 2 - 0.9), 5, 0.8, 1.8, style.Base, style.BaseColor)
	if b.Sign then
		Kit.sign(model, cf * CFrame.new(0, FT + 9.4, -d / 2 - 0.2), math.min(w - 4, 12), 1.8, b.Sign, rgb(58, 44, 34), rgb(236, 220, 180))
	end
	if kind == "Shop" then
		local awningColor = rng:pick({ rgb(150, 60, 50), rgb(60, 90, 70), rgb(64, 80, 120) })
		Kit.slab(model, cf, Vector3.new(0, FT + 8.4, -d / 2), Vector3.new(0, FT + 7.2, -d / 2 - 3), Vector3.new(1, 0, 0), w - 1, 0.15, Vector3.new(0, 1, 0), M.Fabric, awningColor, { NoQuery = true })
	end
	if kind ~= "Shop" and rng:chance(0.6) then
		Props.planter(model, cf * CFrame.new(w / 4, 0, -d / 2 - 1.2), rng)
	end
end

function Buildings.hall(model, cf, b, rng)
	local style = styleFor("Stone", rng)
	local w, d = b.W, b.D
	local tw = 7
	local bw = w - tw
	local body = cf * CFrame.new(tw / 2, 0, 0)
	local H = 11
	foundation(model, cf, w, d, style)
	walls(model, body, bw, d, 2 * H, 2, H, style, { FrontDoor = "center", DoorW = 5.4, DoorH = 9 }, rng)
	interior(model, body, bw, d, H, 2, false, rgb(112, 86, 62), M.WoodPlanks, rgb(96, 72, 52))
	furnish(model, body, bw, d, H, 2, rng, "Hall")
	Kit.box(model, body * CFrame.new(0, FT + 2 * H - 0.3, 0), bw - 2 * T, 0.6, d - 2 * T, M.WoodPlanks, rgb(110, 86, 62))
	Kit.gableRoof(model, body * CFrame.new(0, FT + 2 * H, 0), bw, d, 7, 1.2, style.Roof, style.RoofColor, style.Wall, style.WallColor, T)
	Kit.sign(model, body * CFrame.new(0, FT + 10, -d / 2 - 0.2), 10, 1.8, "MILLBROOK HALL", rgb(40, 44, 50), rgb(230, 222, 200))
	-- Clock tower at the front-left corner facing the plaza.
	local tower = cf * CFrame.new(-w / 2 + tw / 2, 0, -d / 2 + tw / 2)
	local th = FT + 2 * H + 11
	local belfry = { { offset = 0, width = 3.2, gaps = { { th - 6.5, th - 1.5, "open" } } } }
	local ground = { { offset = 0, width = 3.2, gaps = { { 3, 7, "window" }, { H + 3, H + 7, "window" }, { th - 6.5, th - 1.5, "open" } } } }
	local towerStyle = { Material = style.Trim, Color = style.TrimColor }
	Kit.wall(model, tower * CFrame.new(0, 0, -tw / 2 + T / 2), tw, th, T, ground, style.Wall, style.WallColor, towerStyle)
	Kit.wall(model, tower * CFrame.new(0, 0, tw / 2 - T / 2) * CFrame.Angles(0, math.pi, 0), tw, th, T, belfry, style.Wall, style.WallColor, towerStyle)
	Kit.wall(model, tower * CFrame.new(-tw / 2 + T / 2, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), tw - 2 * T, th, T, ground, style.Wall, style.WallColor, towerStyle)
	Kit.wall(model, tower * CFrame.new(tw / 2 - T / 2, 0, 0) * CFrame.Angles(0, -math.pi / 2, 0), tw - 2 * T, th, T, belfry, style.Wall, style.WallColor, towerStyle)
	Kit.box(model, tower * CFrame.new(0, th + 0.4, 0), tw + 0.8, 0.8, tw + 0.8, style.Trim, style.TrimColor)
	Kit.pyramid(model, tower * CFrame.new(0, th + 0.8, 0), tw + 0.6, 7, style.Roof, style.RoofColor)
	Kit.box(model, tower * CFrame.new(0, th - 4, 0), 1.4, 1.4, 1.4, M.Metal, rgb(150, 120, 60), { Name = "Bell" })
	for _, face in ipairs({ { 0, -1 }, { -1, 0 } }) do
		local clock = tower * CFrame.new(face[1] * (tw / 2 + 0.15), th - 9.5, face[2] * (tw / 2 + 0.15))
		local facing = Kit.lookAt(clock.Position, clock.Position + (tower:VectorToWorldSpace(Vector3.new(face[1], 0, face[2]))))
		Kit.part(model, facing * CFrame.Angles(0, math.pi / 2, 0), Vector3.new(0.3, 4.2, 4.2), M.SmoothPlastic, rgb(232, 226, 210), { Shape = Enum.PartType.Cylinder, Name = "Clock" })
		Kit.box(model, facing * CFrame.new(0, 0.8, -0.2), 0.25, 1.7, 0.1, M.Metal, rgb(30, 30, 30), { Decor = true })
		Kit.box(model, facing * CFrame.new(0.5, 0, -0.2) * CFrame.Angles(0, 0, math.rad(-60)), 0.2, 1.2, 0.1, M.Metal, rgb(30, 30, 30), { Decor = true })
	end
end

function Buildings.barn(model, cf, b, rng)
	local style = styleFor("Barn", rng)
	local w, d = b.W, b.D
	local H = 10
	foundation(model, cf, w, d, style)
	local doors = { { offset = 0, width = 8, gaps = { { 0, 8.8, "open" } } } }
	walls(model, cf, w, d, H, 1, H, style, {
		FrontColumns = doors,
		BackColumns = { { offset = 0, width = 4.6, gaps = { { 0, 8, "door" } } } },
		Bay = 7, Sill = 5, Head = 7.4, WindowW = 2.4,
	}, rng)
	-- Hay loft over the back half with stairs up the right wall.
	local xl, xr, zb = -w / 2 + T, w / 2 - T, d / 2 - T
	local loft = FT + 6.5
	Kit.levelSlab(model, cf * CFrame.new(0, loft, 0), xl, xr, -0.5, zb, nil, 0.6, M.WoodPlanks, rgb(120, 92, 62))
	Kit.stairs(model, cf * CFrame.new(xr - 1.8, FT, -7) * CFrame.Angles(0, math.pi, 0), 3.2, 6.5, 6.5, M.WoodPlanks, rgb(104, 78, 56))
	Kit.railing(model, (cf * CFrame.new(xl + 0.2, loft, -0.6)).Position, (cf * CFrame.new(xr - 3.6, loft, -0.6)).Position, 3, M.Wood, rgb(70, 54, 42))
	for i = 0, 2 do
		Props.hayBale(model, cf * CFrame.new(xl + 2.5, loft, 2 + i * 3.8))
	end
	Props.hayBale(model, cf * CFrame.new(-3, FT, -6))
	Props.cart(model, cf * CFrame.new(2, FT, -5) * CFrame.Angles(0, math.rad(15), 0))
	-- Gable roof with the ridge running front-to-back.
	Kit.gableRoof(model, cf * CFrame.new(0, FT + H, 0) * CFrame.Angles(0, math.pi / 2, 0), d, w, 7.5, 1.2, style.Roof, style.RoofColor, style.Wall, style.WallColor, T)
	-- White trim X-braces on the doors.
	Kit.beam(model, (cf * CFrame.new(-4, FT + 0.5, -d / 2 - 0.1)).Position, (cf * CFrame.new(4, FT + 8.3, -d / 2 - 0.1)).Position, 0.4, 0.3, M.WoodPlanks, style.TrimColor, { Decor = true })
end

function Buildings.ruin(model, cf, b, rng)
	local style = styleFor(b.Style or "Stone", rng)
	local w, d = b.W, b.D
	local H = 10
	foundation(model, cf, w, d, style)
	walls(model, cf, w, d, H, 1, H, style, { FrontDoor = "center", BackDoor = "center", Ruin = rng }, rng)
	-- Collapsed roof section, fallen beams and rubble.
	Kit.slab(model, cf, Vector3.new(-w / 4, FT + H * 0.6, -d / 2 + 1), Vector3.new(-w / 4 + 1, FT + 0.5, d / 4), Vector3.new(1, 0, 0), w / 2, 0.6, Vector3.new(0, 1, 0), M.Slate, rgb(72, 70, 70))
	for i = 1, 5 do
		local x, z = rng:range(-w / 2 + 2, w / 2 - 2), rng:range(-d / 2 + 2, d / 2 - 2)
		Kit.box(model, cf * CFrame.new(x, FT + 0.4, z) * CFrame.Angles(rng:range(-0.4, 0.4), rng:range(0, 3), rng:range(-0.4, 0.4)),
			rng:range(1.5, 3.5), rng:range(0.8, 1.6), rng:range(1.5, 3), style.Wall, style.WallColor)
	end
	Kit.beam(model, (cf * CFrame.new(w / 2 - 2, FT + 0.3, -d / 2 + 2)).Position, (cf * CFrame.new(w / 4, FT + 4, d / 2 - 1.5)).Position, 0.7, 0.7, M.Wood, rgb(60, 48, 40))
end

--------------------------------------------------------------- military

function Buildings.barracks(model, cf, b, rng)
	local style = styleFor("Military", rng)
	local w, d = b.W, b.D
	local H = 9
	foundation(model, cf, w, d, style)
	walls(model, cf, w, d, H, 1, H, style, { FrontDoor = "center", SideDoors = true, Bay = 6, Sill = 3.4, Head = 6.6, WindowW = 3 }, rng)
	furnish(model, cf, w, d, H, 1, rng, "Barracks")
	Kit.box(model, cf * CFrame.new(0, FT + H - 0.3, 0), w - 2 * T, 0.6, d - 2 * T, M.WoodPlanks, rgb(150, 140, 120))
	Kit.gableRoof(model, cf * CFrame.new(0, FT + H, 0), w, d, 3.2, 1.4, style.Roof, style.RoofColor, style.Wall, style.WallColor, T)
	-- Entrance canopy
	Kit.slab(model, cf, Vector3.new(0, FT + 8.6, -d / 2), Vector3.new(0, FT + 8, -d / 2 - 3), Vector3.new(1, 0, 0), 7, 0.3, Vector3.new(0, 1, 0), M.Metal, style.RoofColor)
	Kit.sign(model, cf * CFrame.new(0, FT + 7.6, -d / 2 - 0.2), 6, 1.2, "BARRACKS " .. (b.Label or ""), rgb(52, 58, 44), rgb(226, 222, 200))
end

function Buildings.commandPost(model, cf, b, rng)
	local style = styleFor("Military", rng)
	local w, d = b.W, b.D
	local H = 10.5
	foundation(model, cf, w, d, style)
	walls(model, cf, w, d, 2 * H, 2, H, style, { FrontDoor = "center", Bay = 6, WindowW = 3 }, rng)
	local hole = interior(model, cf, w, d, H, 2, true, rgb(140, 132, 118), M.Concrete, rgb(150, 146, 138))
	furnish(model, cf, w, d, H, 2, rng, "Office")
	Kit.flatRoof(model, cf * CFrame.new(0, FT + 2 * H, 0), w, d, 1.4, M.Concrete, style.WallColor, { hole })
	Props.sandbags(model, cf * CFrame.new(-w / 4, FT + 2 * H + 1, -d / 2 + 1.8), 8)
	Props.antenna(model, cf * CFrame.new(w / 2 - 2, FT + 2 * H + 1, -d / 2 + 2))
	Kit.sign(model, cf * CFrame.new(0, FT + 9, -d / 2 - 0.2), 8, 1.3, "COMMAND", rgb(52, 58, 44), rgb(226, 222, 200))
end

function Buildings.hangar(model, cf, b, rng)
	local style = styleFor("Military", rng)
	local span, length = b.W, b.D
	local spring = 4
	local rise = 18
	local segs = 10
	local color = rgb(92, 100, 78)
	Kit.box(model, cf * CFrame.new(0, FT / 2 - 1, 0), span + 1, FT + 2, length + 1, M.Concrete, rgb(132, 130, 124), { Name = "Floor" })
	-- Low side walls
	for side = -1, 1, 2 do
		Kit.box(model, cf * CFrame.new(side * (span / 2 - 0.5), FT + spring / 2, 0), 1, spring, length, M.Concrete, rgb(150, 148, 140))
	end
	local pts = Kit.archRoof(model, cf * CFrame.new(0, FT + spring, 0), span, length + 1.5, rise, segs, M.CorrodedMetal, color)
	-- End walls following the arch profile; the front has a large door opening.
	local doorHalf, doorTop = span * 0.34, 17
	for endSide = -1, 1, 2 do
		local z = endSide * (length / 2 - 0.4)
		for i = 1, #pts - 1 do
			local x0, x1 = pts[i].X, pts[i + 1].X
			local top = FT + spring + math.min(pts[i].Y, pts[i + 1].Y) + 0.3
			local cx, wdt = (x0 + x1) / 2, math.abs(x1 - x0) + 0.2
			if endSide == -1 and math.abs(cx) < doorHalf then
				local bottom = FT + doorTop
				if top > bottom then
					Kit.box(model, cf * CFrame.new(cx, (top + bottom) / 2, z), wdt, top - bottom, 0.8, M.Metal, color)
				end
			else
				Kit.box(model, cf * CFrame.new(cx, top / 2, z), wdt, top, 0.8, M.Metal, color)
			end
		end
	end
	-- Hazard-striped door frame and interior clutter.
	Kit.box(model, cf * CFrame.new(0, FT + doorTop + 0.3, -length / 2 - 0.2), doorHalf * 2 + 1, 0.6, 0.6, M.SmoothPlastic, rgb(214, 170, 48))
	Props.generator(model, cf * CFrame.new(-span / 2 + 5, FT, length / 2 - 5))
	Props.crateStack(model, cf * CFrame.new(span / 2 - 7, FT, length / 2 - 6), rng)
	Props.barrelGroup(model, cf * CFrame.new(span / 2 - 5, FT, 0), rng, 4)
	Props.tires(model, cf * CFrame.new(-span / 2 + 4, FT, 2))
	for i = -1, 1 do
		Kit.lamp(model, (cf * CFrame.new(i * 10, FT + spring + rise - 2, 0)).Position, 1.4, nil, 30, 1.2)
	end
end

function Buildings.warehouse(model, cf, b, rng)
	local style = styleFor(b.Style == "Industrial" and "Industrial" or "Military", rng)
	if b.Style ~= "Industrial" then
		style.Wall, style.WallColor = M.Metal, rgb(98, 106, 84)
	end
	local w, d = b.W, b.D
	local H = 14
	local xl, xr, zf, zb = -w / 2 + T, w / 2 - T, -d / 2 + T, d / 2 - T
	foundation(model, cf, w, d, style)
	local front = {
		{ offset = -w / 4, width = 10, gaps = { { 0, 10, "open" } } },
		{ offset = w / 4, width = 10, gaps = { { 0, 10, "open" } } },
		{ offset = 0, width = 4.4, gaps = { { 0, 8, "door" } } },
	}
	local band = Kit.bays(d - 2 * T, 1, H, { Bay = 7, Sill = 10, Head = 12.4, WindowW = 4 })
	walls(model, cf, w, d, H, 1, H, style, {
		FrontColumns = front,
		BackColumns = { { offset = w / 3, width = 4.4, gaps = { { 0, 8, "door" } } }, { offset = -w / 4, width = 5, gaps = { { 10, 12.4, "window" } } } },
		LeftColumns = band, RightColumns = Kit.bays(d - 2 * T, 1, H, { Bay = 7, Sill = 10, Head = 12.4, WindowW = 4 }),
	}, rng)
	-- Mezzanine along the back wall, stairs up the left wall.
	local roofHole
	if b.Mezzanine then
		local my = FT + 7
		local mz = zb - 8
		Kit.levelSlab(model, cf * CFrame.new(0, my, 0), xl, xr, mz, zb, nil, 0.6, M.DiamondPlate, rgb(120, 124, 126))
		Kit.stairs(model, cf * CFrame.new(xl + 1.8, FT, mz - 7) * CFrame.Angles(0, math.pi, 0), 3.2, 7, 7, M.DiamondPlate, rgb(110, 112, 114))
		Kit.railing(model, (cf * CFrame.new(xl + 3.8, my, mz - 0.1)).Position, (cf * CFrame.new(xr - 0.3, my, mz - 0.1)).Position, 3.2, M.Metal, rgb(214, 170, 48), 6)
		for i = 0, 3 do
			Kit.box(model, cf * CFrame.new(xl + 6 + i * (w - 12) / 3, FT + 3.5, mz + 0.3), 0.6, 7, 0.6, M.Metal, rgb(90, 94, 98))
		end
		if b.RoofAccess then
			local roofTop = FT + H + 1
			local rise = roofTop - my
			local xs = xl + 6
			Kit.stairs(model, cf * CFrame.new(xs, my, zb - SW / 2) * CFrame.Angles(0, -math.pi / 2, 0), SW, rise, rise, M.DiamondPlate, rgb(110, 112, 114))
			roofHole = { xs - 0.2, xs + rise + 0.2, zb - SW, zb }
		end
		for i = 0, 1 do
			Props.rack(model, cf * CFrame.new(-w / 6 + i * w / 3, FT, zf + 6 + i * 4), 10, rng)
		end
	else
		Props.rack(model, cf * CFrame.new(0, FT, zb - 3), w - 12, rng)
	end
	Props.crateStack(model, cf * CFrame.new(xr - 4, FT, 0), rng)
	Props.pallet(model, cf * CFrame.new(0, FT, 0))
	if roofHole then
		Kit.flatRoof(model, cf * CFrame.new(0, FT + H, 0), w, d, 1.3, M.Metal, style.RoofColor, { roofHole })
		Kit.railing(model, (cf * CFrame.new(roofHole[1], FT + H + 1, roofHole[3] - 0.1)).Position, (cf * CFrame.new(roofHole[2], FT + H + 1, roofHole[3] - 0.1)).Position, 3, M.Metal, rgb(214, 170, 48))
	else
		Kit.gableRoof(model, cf * CFrame.new(0, FT + H, 0), w, d, 3.5, 1, style.Roof, style.RoofColor, style.Wall, style.WallColor, T)
	end
	for i = -1, 1, 2 do
		Kit.lamp(model, (cf * CFrame.new(i * w / 4, FT + H - 1.5, 0)).Position, 1.2, nil, 26, 1)
	end
end

function Buildings.maintenance(model, cf, b, rng)
	local style = styleFor("Industrial", rng)
	local w, d = b.W, b.D
	local H = 10
	foundation(model, cf, w, d, style)
	local front = {
		{ offset = -w / 4, width = 8, gaps = { { 0, 8.5, "open" }, { H + 3, H + 7, "window" } } },
		{ offset = w / 4, width = 8, gaps = { { 0, 8.5, "open" }, { H + 3, H + 7, "window" } } },
	}
	local doorZ = -d / 2 + 12.6
	local right = {
		{ offset = doorZ, width = 3.8, gaps = { { H, H + 7.5, "door" } } },
		{ offset = -d / 2 + 5, width = 3, gaps = { { 3.2, 7, "window" } } },
	}
	walls(model, cf, w, d, 2 * H, 2, H, style, { FrontColumns = front, RightColumns = right, BackDoor = "center" }, rng)
	-- Upper office floor (reached by the external stair).
	Kit.levelSlab(model, cf * CFrame.new(0, FT + H, 0), -w / 2 + T, w / 2 - T, -d / 2 + T, d / 2 - T, nil, 0.8, M.Concrete, rgb(140, 138, 132))
	Kit.flatRoof(model, cf * CFrame.new(0, FT + 2 * H, 0), w, d, 1.2, M.Concrete, rgb(120, 118, 112))
	-- External steel stair up the right wall to a landing.
	local sx = w / 2 + 1.9
	Kit.stairs(model, cf * CFrame.new(sx, 0, -d / 2 + 0.5) * CFrame.Angles(0, math.pi, 0), 3.2, FT + H, FT + H, M.DiamondPlate, rgb(110, 112, 114))
	local landingZ0 = -d / 2 + 0.5 + FT + H
	Kit.box(model, cf * CFrame.new(sx, FT + H - 0.3, (landingZ0 + doorZ + 2) / 2), 3.4, 0.6, (doorZ + 2) - landingZ0, M.DiamondPlate, rgb(110, 112, 114))
	Kit.box(model, cf * CFrame.new(sx, (FT + H) / 2, doorZ + 1.4), 0.5, FT + H, 0.5, M.Metal, rgb(214, 170, 48))
	Kit.railing(model, (cf * CFrame.new(sx + 1.6, FT + H, landingZ0)).Position, (cf * CFrame.new(sx + 1.6, FT + H, doorZ + 2)).Position, 3.2, M.Metal, rgb(214, 170, 48))
	Props.generator(model, cf * CFrame.new(0, FT, 3))
	Props.tires(model, cf * CFrame.new(-w / 2 + 3, FT, d / 2 - 3))
	Kit.box(model, cf * CFrame.new(w / 2 - 3, FT + 1.6, d / 2 - 2), 4.5, 3.2, 1.8, M.Metal, rgb(150, 50, 40), { Name = "ToolChest" })
	Kit.sign(model, cf * CFrame.new(0, FT + 9.3, -d / 2 - 0.2), 10, 1.4, "KESSLER WORKS", rgb(40, 60, 90), rgb(236, 236, 230))
end

function Buildings.bunker(model, cf, b, rng)
	local w, d = b.W or 16, b.D or 12
	local H = 8
	local style = { Wall = M.Concrete, WallColor = rgb(138, 136, 128), Trim = M.Concrete, TrimColor = rgb(118, 116, 110), Base = M.Concrete, BaseColor = rgb(118, 116, 110) }
	foundation(model, cf, w, d, style)
	local slits = Kit.bays(w, 1, H, { Bay = 5, Sill = 4.4, Head = 5.6, WindowW = 3.2, Door = nil })
	walls(model, cf, w, d, H, 1, H, style, {
		FrontColumns = slits,
		BackColumns = { { offset = 0, width = 4.4, gaps = { { 0, 7.4, "open" } } } },
		LeftColumns = Kit.bays(d - 2 * T, 1, H, { Bay = 6, Sill = 4.4, Head = 5.6, WindowW = 2.6 }),
		RightColumns = Kit.bays(d - 2 * T, 1, H, { Bay = 6, Sill = 4.4, Head = 5.6, WindowW = 2.6 }),
	}, rng)
	Kit.box(model, cf * CFrame.new(0, FT + H + 0.8, 0), w + 1.6, 1.6, d + 1.6, M.Concrete, rgb(128, 126, 120))
	Props.sandbags(model, cf * CFrame.new(0, FT + H + 1.6, -d / 2 + 0.8), w - 2, rng)
	if b.Pipes then
		for i = -1, 1, 2 do
			Kit.cylinder(model, (cf * CFrame.new(i * 3, FT + 2, d / 2 + 0.2)).Position, (cf * CFrame.new(i * 3, FT + 2, d / 2 + 14)).Position, 1.4, M.Metal, rgb(90, 110, 120))
		end
	end
end

function Buildings.watchtower(model, cf, b, rng)
	local wood = rgb(96, 78, 58)
	local s = 9
	local deck = 14
	local roof = deck + 7
	for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		Kit.box(model, cf * CFrame.new(c[1] * (s / 2 - 0.5), (roof - 1) / 2, c[2] * (s / 2 - 0.5)), 0.9, roof + 1, 0.9, M.Wood, wood)
	end
	-- Cross bracing
	for side = 0, 3 do
		local a = side * math.pi / 2
		local frame = cf * CFrame.Angles(0, a, 0)
		Kit.beam(model, (frame * CFrame.new(-s / 2 + 0.5, 0.5, -s / 2 + 0.5)).Position, (frame * CFrame.new(s / 2 - 0.5, deck - 1, -s / 2 + 0.5)).Position, 0.4, 0.4, M.Wood, wood, { Decor = true })
	end
	Kit.box(model, cf * CFrame.new(0, deck - 0.4, 0), s + 0.6, 0.8, s + 0.6, M.WoodPlanks, rgb(116, 92, 66), { Name = "Deck" })
	-- Parapet with an opening at the back (x −3.5..0) for the stair.
	Kit.box(model, cf * CFrame.new(0, deck + 1.6, -s / 2 + 0.3), s, 3.2, 0.5, M.WoodPlanks, wood)
	Kit.box(model, cf * CFrame.new(-s / 2 + 0.3, deck + 1.6, 0), 0.5, 3.2, s, M.WoodPlanks, wood)
	Kit.box(model, cf * CFrame.new(s / 2 - 0.3, deck + 1.6, 0), 0.5, 3.2, s, M.WoodPlanks, wood)
	Kit.box(model, cf * CFrame.new(s / 4, deck + 1.6, s / 2 - 0.3), s / 2, 3.2, 0.5, M.WoodPlanks, wood)
	Props.sandbags(model, cf * CFrame.new(0, deck, -s / 2 + 1.4), s - 2)
	Kit.box(model, cf * CFrame.new(0, roof + 0.3, 0), s + 1.4, 0.6, s + 1.4, M.CorrodedMetal, rgb(86, 94, 70))
	Kit.pyramid(model, cf * CFrame.new(0, roof + 0.6, 0), s + 1.4, 2.2, M.CorrodedMetal, rgb(86, 94, 70))
	-- Stair from the ground to the deck on the back side.
	Kit.stairs(model, cf * CFrame.new(-1.75, 0, s / 2 + deck), 3, deck, deck, M.WoodPlanks, rgb(104, 82, 60))
	Kit.lamp(model, (cf * CFrame.new(s / 2 - 1, deck + 3.6, -s / 2 + 1)).Position, 1.2, nil, 30, 1.3)
end

function Buildings.guardBooth(model, cf, b, rng)
	local style = styleFor("Military", rng)
	local w, d, H = 6, 6, 8
	foundation(model, cf, w, d, style)
	walls(model, cf, w, d, H, 1, H, style, {
		FrontColumns = { { offset = 0, width = 3.6, gaps = { { 3.4, 6.6, "window" } } } },
		BackColumns = { { offset = 0, width = 3.4, gaps = { { 0, 7.2, "open" } } } },
		LeftColumns = { { offset = 0, width = 3, gaps = { { 3.4, 6.6, "window" } } } },
		RightColumns = { { offset = 0, width = 3, gaps = { { 3.4, 6.6, "window" } } } },
	}, rng)
	Kit.box(model, cf * CFrame.new(0, FT + H + 0.3, 0), w + 2, 0.6, d + 2, M.Metal, style.RoofColor)
	Kit.lamp(model, (cf * CFrame.new(0, FT + H - 0.6, -d / 2 - 0.8)).Position, 0.8, nil, 18, 1)
end

function Buildings.vehicleShed(model, cf, b, rng)
	local w, d, h = b.W, b.D, 9
	local steel = rgb(92, 98, 80)
	Kit.box(model, cf * CFrame.new(0, 0.2, 0), w, 0.8, d, M.Concrete, rgb(128, 126, 120))
	for i = 0, 3 do
		local x = -w / 2 + 0.5 + i * (w - 1) / 3
		Kit.box(model, cf * CFrame.new(x, h / 2, -d / 2 + 0.5), 0.8, h, 0.8, M.Metal, steel)
	end
	Kit.box(model, cf * CFrame.new(0, h / 2, d / 2 - 0.4), w, h, 0.8, M.Metal, steel)
	Kit.box(model, cf * CFrame.new(-w / 2 + 0.4, h / 2, 0.4), 0.8, h, d - 0.8, M.Metal, steel)
	Kit.slab(model, cf, Vector3.new(0, h, d / 2 + 0.6), Vector3.new(0, h - 1.5, -d / 2 - 1.2), Vector3.new(1, 0, 0), w + 1, 0.5, Vector3.new(0, 1, 0), M.CorrodedMetal, rgb(86, 94, 70))
	Props.barrelGroup(model, cf * CFrame.new(-w / 2 + 3, 0.6, d / 2 - 3), rng, 3)
	Props.tires(model, cf * CFrame.new(w / 2 - 3, 0.6, d / 2 - 3))
	Kit.sign(model, cf * CFrame.new(0, h - 1.2, -d / 2 + 0.1), 7, 1.2, "MOTOR POOL", rgb(52, 58, 44), rgb(226, 222, 200))
end

function Buildings.tent(model, cf, b, rng)
	local w, d = b.W, b.D
	local canvas = b.Color or rgb(96, 104, 72)
	local wallH = 4.5
	Kit.box(model, cf * CFrame.new(0, 0.2, 0), w, 0.4, d, M.WoodPlanks, rgb(110, 90, 66))
	local walls = {
		{ Vector3.new(0, 0, -d / 2), w, { { offset = 0, width = 3.2, gaps = { { 0, 4.5, "open" } } } }, 0 },
		{ Vector3.new(0, 0, d / 2), w, {}, math.pi },
		{ Vector3.new(-w / 2, 0, 0), d, {}, math.pi / 2 },
		{ Vector3.new(w / 2, 0, 0), d, {}, -math.pi / 2 },
	}
	for _, wl in ipairs(walls) do
		Kit.wall(model, cf * CFrame.new(wl[1] + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, wl[4], 0), wl[2], wallH, 0.3, wl[3], M.Fabric, canvas)
	end
	Kit.gableRoof(model, cf * CFrame.new(0, 0.4 + wallH, 0), w, d, 3.2, 0.6, M.Fabric, canvas:Lerp(Color3.new(0, 0, 0), 0.12), M.Fabric, canvas, 0.3)
	for i = 0, math.floor(w / 5) - 1 do
		Kit.box(model, cf * CFrame.new(-w / 2 + 2.6 + i * 5, 1.1, d / 2 - 3.6), 2.6, 0.6, 5.6, M.Fabric, rgb(70, 76, 54))
	end
end

return Buildings
