--[[
	Props
	Reusable set dressing. Every function takes (parent, cf, ...) where cf is a
	ground-level frame (Y = ground surface, −Z = front). Pure primitives only.
]]

local Kit = require(script.Parent.Kit)

local Props = {}

local M = Enum.Material
local rgb = Color3.fromRGB

Props.Colors = {
	Olive = rgb(88, 96, 66),
	OliveDark = rgb(66, 72, 50),
	Sand = rgb(170, 152, 112),
	Canvas = rgb(150, 140, 108),
	Wood = rgb(116, 88, 62),
	WoodDark = rgb(78, 60, 46),
	Steel = rgb(96, 100, 104),
	SteelLight = rgb(150, 154, 156),
	Rust = rgb(136, 84, 58),
	Concrete = rgb(150, 148, 142),
	ConcreteDark = rgb(118, 116, 112),
	Hazard = rgb(214, 170, 48),
	White = rgb(226, 224, 216),
	Red = rgb(160, 52, 44),
}
local C = Props.Colors

function Props.crate(parent, cf, size, color)
	size = size or 4
	Kit.box(parent, cf * CFrame.new(0, size / 2, 0), size, size, size, M.WoodPlanks, color or C.Wood, { Name = "Crate" })
	-- Reinforcing band
	Kit.box(parent, cf * CFrame.new(0, size / 2, 0), size + 0.12, size * 0.18, size + 0.12, M.Wood, C.WoodDark, { Decor = true })
end

function Props.crateStack(parent, cf, rng)
	Props.crate(parent, cf, 4)
	Props.crate(parent, cf * CFrame.new(4.3, 0, 0.3) * CFrame.Angles(0, math.rad(rng:range(-12, 12)), 0), 3.6)
	Props.crate(parent, cf * CFrame.new(0.4, 4, 0.2) * CFrame.Angles(0, math.rad(rng:range(-20, 20)), 0), 3.2, C.Olive)
end

function Props.barrel(parent, cf, color)
	Kit.column(parent, cf.Position, 3.6, 2.4, M.Metal, color or C.OliveDark, { Name = "Barrel" })
	Kit.column(parent, cf.Position + Vector3.new(0, 1.1, 0), 0.2, 2.5, M.Metal, C.Steel, { Decor = true })
	Kit.column(parent, cf.Position + Vector3.new(0, 2.5, 0), 0.2, 2.5, M.Metal, C.Steel, { Decor = true })
end

function Props.barrelGroup(parent, cf, rng, count)
	for i = 1, count or 4 do
		local offset = Vector3.new((i % 2) * 2.7, 0, math.floor((i - 1) / 2) * 2.7)
		local colors = { C.OliveDark, C.Rust, rgb(52, 70, 96), C.OliveDark }
		Props.barrel(parent, cf * CFrame.new(offset), colors[rng:int(1, #colors)])
	end
end

function Props.pallet(parent, cf)
	Kit.box(parent, cf * CFrame.new(0, 0.3, 0), 4.2, 0.6, 4.2, M.WoodPlanks, C.Wood)
end

-- Row of sandbags two courses high along local X, length in studs.
function Props.sandbags(parent, cf, length, rng)
	local n = math.max(1, math.floor(length / 2.3))
	for course = 0, 1 do
		for i = 0, n - 1 do
			local x = -length / 2 + (i + 0.5) * (length / n) + course * 1.1
			if x < length / 2 then
				local jitter = rng and math.rad(rng:range(-5, 5)) or 0
				Kit.box(parent, cf * CFrame.new(x, 0.6 + course * 1.15, 0) * CFrame.Angles(0, jitter, 0),
					2.3, 1.2, 1.5, M.Fabric, course == 0 and C.Sand or rgb(160, 142, 104), { Name = "Sandbag" })
			end
		end
	end
end

-- Semi-circular sandbag nest opening toward local +Z.
function Props.sandbagNest(parent, cf, rng)
	for i = 0, 4 do
		local a = math.rad(-90 + i * 45)
		local r = 5
		Props.sandbags(parent, cf * CFrame.new(math.sin(a) * r, 0, -math.cos(a) * r) * CFrame.Angles(0, -a, 0), 4, rng)
	end
	Props.crate(parent, cf * CFrame.new(3, 0, 2.5), 2.4, C.Olive)
end

-- Gabion blast barrier units along local X.
function Props.hesco(parent, cf, length)
	local n = math.max(1, math.floor(length / 4.2 + 0.5))
	local unit = length / n
	for i = 0, n - 1 do
		local x = -length / 2 + (i + 0.5) * unit
		Kit.box(parent, cf * CFrame.new(x, 2.6, 0), unit - 0.15, 5.2, 4, M.Fabric, C.Canvas, { Name = "Hesco" })
		Kit.box(parent, cf * CFrame.new(x, 5.2, 0), unit, 0.25, 4.1, M.Ground, rgb(110, 94, 72), { Decor = true })
	end
end

function Props.jerseyBarrier(parent, cf)
	Kit.box(parent, cf * CFrame.new(0, 0.7, 0), 10, 1.4, 2.4, M.Concrete, C.Concrete, { Name = "Barrier" })
	Kit.box(parent, cf * CFrame.new(0, 2.1, 0), 10, 1.4, 1.2, M.Concrete, C.Concrete)
end

-- Fence segment from world point a to b.
function Props.fence(parent, a, b, style)
	local len = (b - a).Magnitude
	if len < 0.5 then
		return
	end
	local dir = (b - a).Unit
	local n = math.max(1, math.ceil(len / 8))
	if style == "Chainlink" then
		for i = 0, n do
			local p = a:Lerp(b, i / n)
			Kit.column(parent, p - Vector3.new(0, 1, 0), 9.5, 0.45, M.Metal, C.SteelLight)
		end
		local mid = (a + b) / 2
		Kit.part(parent, Kit.lookAt(mid + Vector3.new(0, 4.3, 0), mid + Vector3.new(0, 4.3, 0) + dir), Vector3.new(0.08, 7.4, len),
			M.Fabric, rgb(88, 92, 96), { Transparency = 0.55, NoQuery = true, Name = "Mesh" })
		Kit.beam(parent, a + Vector3.new(0, 8.1, 0), b + Vector3.new(0, 8.1, 0), 0.25, 0.25, M.Metal, C.SteelLight)
		-- Barbed top wire
		Kit.beam(parent, a + Vector3.new(0, 8.6, 0), b + Vector3.new(0, 8.6, 0), 0.1, 0.1, M.Metal, C.Steel, { Decor = true })
	elseif style == "ConcreteWall" then
		local mid = (a + b) / 2
		Kit.part(parent, Kit.lookAt(mid + Vector3.new(0, 3, 0), mid + Vector3.new(0, 3, 0) + dir), Vector3.new(0.8, 9, len),
			M.Concrete, C.ConcreteDark, { Name = "Wall" })
		for i = 0, n do
			local p = a:Lerp(b, i / n)
			Kit.box(parent, Kit.lookAt(p + Vector3.new(0, 3.5, 0), p + Vector3.new(0, 3.5, 0) + dir), 1.4, 10, 1.4, M.Concrete, C.Concrete)
		end
	elseif style == "Stone" then
		local mid = (a + b) / 2
		Kit.part(parent, Kit.lookAt(mid + Vector3.new(0, 0.9, 0), mid + Vector3.new(0, 0.9, 0) + dir), Vector3.new(1.4, 2.6, len),
			M.Cobblestone, rgb(136, 130, 120), { Name = "StoneWall" })
	else -- wooden post and rail / picket
		for i = 0, n do
			local p = a:Lerp(b, i / n)
			Kit.box(parent, Kit.lookAt(p + Vector3.new(0, 1.6, 0), p + Vector3.new(0, 1.6, 0) + dir), 0.45, 3.6, 0.45, M.Wood, C.WoodDark)
		end
		local mid = (a + b) / 2
		Kit.part(parent, Kit.lookAt(mid + Vector3.new(0, 2.2, 0), mid + Vector3.new(0, 2.2, 0) + dir), Vector3.new(0.2, 0.35, len), M.WoodPlanks, C.Wood)
		Kit.part(parent, Kit.lookAt(mid + Vector3.new(0, 1.1, 0), mid + Vector3.new(0, 1.1, 0) + dir), Vector3.new(0.2, 0.35, len), M.WoodPlanks, C.Wood)
	end
end

function Props.lampPost(parent, cf)
	local base = cf.Position
	Kit.column(parent, base, 11, 0.45, M.Metal, rgb(46, 48, 50), { Name = "LampPost" })
	Kit.box(parent, cf * CFrame.new(0, 10.8, -0.9), 0.3, 0.3, 2, M.Metal, rgb(46, 48, 50))
	Kit.lamp(parent, (cf * CFrame.new(0, 10.4, -1.7)).Position, 1.1, nil, 18, 1)
end

function Props.bench(parent, cf)
	Kit.box(parent, cf * CFrame.new(0, 1.4, 0), 5, 0.3, 1.5, M.WoodPlanks, C.Wood, { Name = "Bench" })
	Kit.box(parent, cf * CFrame.new(0, 2.3, 0.65), 5, 1.2, 0.25, M.WoodPlanks, C.Wood)
	for side = -1, 1, 2 do
		Kit.box(parent, cf * CFrame.new(side * 2.2, 0.7, 0), 0.3, 1.4, 1.3, M.Metal, rgb(46, 48, 50))
	end
end

function Props.well(parent, cf)
	for i = 0, 7 do
		local a = i * math.pi / 4
		Kit.box(parent, cf * CFrame.new(math.cos(a) * 2.6, 1.3, math.sin(a) * 2.6) * CFrame.Angles(0, -a, 0), 1, 2.6, 2.3, M.Cobblestone, rgb(140, 134, 124), { Name = "Well" })
	end
	Kit.column(parent, cf.Position + Vector3.new(0, -0.5, 0), 1, 4.2, M.Glass, rgb(40, 60, 62), { Decor = true })
	for side = -1, 1, 2 do
		Kit.box(parent, cf * CFrame.new(side * 2.6, 4.2, 0), 0.4, 5.6, 0.4, M.Wood, C.WoodDark)
	end
	Kit.gableRoof(parent, cf * CFrame.new(0, 6.8, 0), 6.6, 4.6, 1.8, 0.3, M.ClayRoofTiles, rgb(140, 74, 54), M.WoodPlanks, C.WoodDark, 0.3)
	Kit.cylinder(parent, cf.Position + Vector3.new(-2.4, 5.4, 0), cf.Position + Vector3.new(2.4, 5.4, 0), 0.4, M.Wood, C.Wood)
end

function Props.marketStall(parent, cf, color)
	Kit.box(parent, cf * CFrame.new(0, 1.7, 0), 6, 0.4, 3, M.WoodPlanks, C.Wood, { Name = "Stall" })
	Kit.box(parent, cf * CFrame.new(0, 0.8, 0.8), 6, 1.6, 1.2, M.WoodPlanks, C.WoodDark)
	for _, p in ipairs({ { -2.8, -1.3 }, { 2.8, -1.3 }, { -2.8, 1.3 }, { 2.8, 1.3 } }) do
		Kit.box(parent, cf * CFrame.new(p[1], 2.8, p[2]), 0.3, 5.6, 0.3, M.Wood, C.WoodDark)
	end
	Kit.slab(parent, cf, Vector3.new(0, 6.2, 1.8), Vector3.new(0, 5, -2.2), Vector3.new(1, 0, 0), 6.8, 0.15, Vector3.new(0, 1, 0), M.Fabric, color or rgb(160, 70, 50), { NoQuery = true })
	for i = -1, 1 do
		Kit.box(parent, cf * CFrame.new(i * 1.8, 2.3, 0), 1.2, 0.8, 1, M.WoodPlanks, rgb(170, 130, 80), { Decor = true })
	end
end

function Props.hayBale(parent, cf)
	Kit.part(parent, cf * CFrame.new(0, 1.8, 0) * CFrame.Angles(0, 0, 0), Vector3.new(4, 3.6, 3.6), M.Grass, rgb(190, 164, 96), { Shape = Enum.PartType.Cylinder, Name = "HayBale" })
end

function Props.cart(parent, cf)
	Kit.box(parent, cf * CFrame.new(0, 2.3, 0), 4, 1.6, 7, M.WoodPlanks, C.Wood, { Name = "Cart" })
	for side = -1, 1, 2 do
		Kit.part(parent, cf * CFrame.new(side * 2.3, 1.6, 0.5), Vector3.new(0.4, 3.2, 3.2), M.Wood, C.WoodDark, { Shape = Enum.PartType.Cylinder })
	end
	Kit.beam(parent, (cf * CFrame.new(0, 1.8, -3.5)).Position, (cf * CFrame.new(0, 0.8, -7.5)).Position, 0.4, 0.4, M.Wood, C.Wood)
end

function Props.planter(parent, cf, rng)
	Kit.box(parent, cf * CFrame.new(0, 0.6, 0), 4, 1.2, 1.6, M.Brick, rgb(126, 76, 60))
	for i = -1, 1 do
		Kit.ball(parent, (cf * CFrame.new(i * 1.2, 1.5, 0)).Position, rng:range(1.1, 1.6), M.Grass,
			rng:chance(0.4) and rgb(176, 60, 70) or rgb(80, 118, 60), { Decor = true })
	end
end

function Props.utilityPole(parent, cf)
	Kit.column(parent, cf.Position - Vector3.new(0, 1, 0), 21, 0.9, M.Wood, rgb(84, 66, 50), { Name = "UtilityPole" })
	Kit.box(parent, cf * CFrame.new(0, 18.5, 0), 5, 0.4, 0.4, M.Wood, rgb(84, 66, 50))
	for i = -1, 1, 2 do
		Kit.column(parent, (cf * CFrame.new(i * 2, 18.7, 0)).Position, 0.6, 0.35, M.Glass, rgb(170, 200, 190), { Decor = true })
	end
end

-- Sagging-free wire pair between two utility poles (world frames).
function Props.wires(parent, cfA, cfB)
	for i = -1, 1, 2 do
		local a = (cfA * CFrame.new(i * 2, 19.2, 0)).Position
		local b = (cfB * CFrame.new(i * 2, 19.2, 0)).Position
		Kit.beam(parent, a, b, 0.08, 0.08, M.Metal, rgb(30, 30, 30), { Decor = true, NoShadow = true })
	end
end

function Props.generator(parent, cf)
	Kit.box(parent, cf * CFrame.new(0, 1.6, 0), 6, 3.2, 3.2, M.Metal, C.OliveDark, { Name = "Generator" })
	Kit.box(parent, cf * CFrame.new(0, 3.4, 0), 5.4, 0.4, 2.6, M.DiamondPlate, C.Steel)
	Kit.column(parent, (cf * CFrame.new(2.2, 3.2, 0.8)).Position, 2, 0.4, M.Metal, rgb(40, 40, 40))
end

function Props.fuelTank(parent, cf)
	for side = -1, 1, 2 do
		Kit.box(parent, cf * CFrame.new(side * 4.5, 1.2, 0), 0.8, 2.4, 5, M.Concrete, C.Concrete)
	end
	Kit.part(parent, cf * CFrame.new(0, 4.4, 0), Vector3.new(14, 5.6, 5.6), M.Metal, C.Olive, { Shape = Enum.PartType.Cylinder, Name = "FuelTank" })
	Kit.box(parent, cf * CFrame.new(0, 7.3, 0), 1.2, 0.5, 1.2, M.Metal, C.Steel)
end

function Props.antenna(parent, cf)
	Kit.column(parent, cf.Position, 26, 0.4, M.Metal, C.SteelLight, { Name = "Antenna" })
	Kit.box(parent, cf * CFrame.new(0, 0.5, 0), 2.4, 1, 2.4, M.Concrete, C.Concrete)
	for i = 0, 2 do
		local a = i * math.pi * 2 / 3
		Kit.beam(parent, (cf * CFrame.new(0, 18, 0)).Position, (cf * CFrame.new(math.cos(a) * 7, 0.1, math.sin(a) * 7)).Position, 0.06, 0.06, M.Metal, rgb(40, 40, 40), { Decor = true, NoShadow = true })
	end
	Kit.box(parent, cf * CFrame.new(0, 26.2, 0), 0.5, 0.5, 0.5, M.Neon, rgb(200, 60, 50), { Decor = true })
end

function Props.helipad(parent, cf)
	Kit.part(parent, cf * CFrame.new(0, 0.15, 0) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(0.3, 24, 24), M.Concrete, C.ConcreteDark, { Shape = Enum.PartType.Cylinder, Name = "Helipad" })
	local paint = { Decor = true, NoShadow = true }
	Kit.box(parent, cf * CFrame.new(-2.2, 0.33, 0), 1, 0.05, 8, M.SmoothPlastic, C.White, paint)
	Kit.box(parent, cf * CFrame.new(2.2, 0.33, 0), 1, 0.05, 8, M.SmoothPlastic, C.White, paint)
	Kit.box(parent, cf * CFrame.new(0, 0.33, 0), 4.4, 0.05, 1, M.SmoothPlastic, C.White, paint)
end

function Props.camoNet(parent, cf, w, d, h)
	for _, p in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		Kit.box(parent, cf * CFrame.new(p[1] * (w / 2 - 0.3), h / 2, p[2] * (d / 2 - 0.3)), 0.35, h, 0.35, M.Wood, C.WoodDark)
	end
	Kit.box(parent, cf * CFrame.new(0, h, 0), w + 1, 0.2, d + 1, M.Fabric, rgb(78, 88, 58), { NoQuery = true, Transparency = 0.15, Name = "CamoNet" })
end

function Props.boomGate(parent, cf, span)
	Kit.box(parent, cf * CFrame.new(-span / 2 - 0.8, 1.6, 0), 1.2, 3.2, 1.2, M.Concrete, C.Concrete)
	Kit.box(parent, cf * CFrame.new(span / 2 + 0.6, 1.2, 0), 0.6, 2.4, 0.6, M.Metal, C.Steel)
	local n = 6
	for i = 0, n - 1 do
		local x = -span / 2 + (i + 0.5) * span / n
		Kit.box(parent, cf * CFrame.new(x, 2.9, 0), span / n, 0.45, 0.35, M.SmoothPlastic, i % 2 == 0 and C.Red or C.White, { Name = "BoomArm" })
	end
end

function Props.container(parent, cf, color)
	Kit.box(parent, cf * CFrame.new(0, 4.25, 0), 8, 8.5, 20, M.CorrodedMetal, color, { Name = "Container" })
	-- Corrugation ribs and door end frame
	for i = -3, 3 do
		Kit.box(parent, cf * CFrame.new(0, 4.25, i * 2.8), 8.15, 8.2, 0.3, M.Metal, color, { Decor = true })
	end
	Kit.box(parent, cf * CFrame.new(0, 4.25, -10.05), 7.6, 8, 0.15, M.Metal, color:Lerp(Color3.new(0, 0, 0), 0.15))
	Kit.box(parent, cf * CFrame.new(0, 4.25, -10.15), 0.2, 7.6, 0.2, M.Metal, C.Steel, { Decor = true })
end

function Props.cableSpool(parent, cf)
	Kit.part(parent, cf * CFrame.new(0, 2.2, 0), Vector3.new(3, 4.4, 4.4), M.WoodPlanks, C.Wood, { Shape = Enum.PartType.Cylinder, Name = "Spool" })
end

function Props.tires(parent, cf)
	for i = 0, 2 do
		Kit.part(parent, cf * CFrame.new(0, 0.5 + i, 0) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(0.9, 3, 3), M.Rubber, rgb(30, 30, 32), { Shape = Enum.PartType.Cylinder })
	end
end

-- Flagpole with a coloured flag (world objective flags are made by Objectives).
function Props.flag(parent, cf, color, height)
	height = height or 24
	Kit.column(parent, cf.Position, height, 0.5, M.Metal, C.SteelLight, { Name = "FlagPole" })
	Kit.box(parent, cf * CFrame.new(0, 0.4, 0), 2.6, 0.8, 2.6, M.Concrete, C.Concrete)
	return Kit.box(parent, cf * CFrame.new(0, height - 2.4, -3.2), 0.12, 3.8, 6, M.Fabric, color, { Decor = true, Name = "Flag" })
end

function Props.puddle(parent, pos, size)
	Kit.part(parent, CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(0.06, size, size), M.Glass, rgb(58, 66, 66),
		{ Shape = Enum.PartType.Cylinder, Transparency = 0.3, Reflectance = 0.25, Decor = true, NoShadow = true, Name = "Puddle" })
end

-- Interior furniture ------------------------------------------------------

function Props.table(parent, cf, w, d)
	w, d = w or 4, d or 2.6
	Kit.box(parent, cf * CFrame.new(0, 2.5, 0), w, 0.3, d, M.WoodPlanks, C.Wood, { Name = "Table" })
	Kit.box(parent, cf * CFrame.new(0, 1.2, 0), w * 0.2, 2.4, d * 0.4, M.Wood, C.WoodDark)
end

function Props.chair(parent, cf)
	Kit.box(parent, cf * CFrame.new(0, 1.4, 0), 1.4, 0.25, 1.4, M.WoodPlanks, C.Wood)
	Kit.box(parent, cf * CFrame.new(0, 2.3, 0.6), 1.4, 1.8, 0.2, M.WoodPlanks, C.Wood)
	Kit.box(parent, cf * CFrame.new(0, 0.65, 0), 1.1, 1.3, 1.1, M.Wood, C.WoodDark, { Decor = true })
end

function Props.bed(parent, cf, color)
	Kit.box(parent, cf * CFrame.new(0, 0.8, 0), 3.2, 1.6, 6.5, M.Wood, C.WoodDark, { Name = "Bed" })
	Kit.box(parent, cf * CFrame.new(0, 1.75, 0.4), 3, 0.35, 5.6, M.Fabric, color or rgb(170, 160, 140))
end

function Props.bunk(parent, cf)
	for level = 0, 1 do
		local y = 1.2 + level * 3.6
		Kit.box(parent, cf * CFrame.new(0, y, 0), 3, 0.5, 6.4, M.Fabric, level == 0 and C.Olive or C.OliveDark)
	end
	for _, p in ipairs({ { -1.4, -3.1 }, { 1.4, -3.1 }, { -1.4, 3.1 }, { 1.4, 3.1 } }) do
		Kit.box(parent, cf * CFrame.new(p[1], 3.2, p[2]), 0.25, 6.4, 0.25, M.Metal, C.Steel, { Decor = true })
	end
end

function Props.shelf(parent, cf, w)
	w = w or 5
	Kit.box(parent, cf * CFrame.new(0, 3.5, 0), w, 7, 1.6, M.WoodPlanks, C.WoodDark, { Name = "Shelf" })
end

function Props.rack(parent, cf, length, rng)
	-- Industrial pallet racking with a few loads.
	for i = 0, 2 do
		local x = -length / 2 + i * length / 2
		Kit.box(parent, cf * CFrame.new(x, 5, 0), 0.4, 10, 3.6, M.Metal, rgb(200, 110, 40))
	end
	for level = 1, 3 do
		Kit.box(parent, cf * CFrame.new(0, level * 3.2, 0), length, 0.3, 3.6, M.Metal, rgb(60, 90, 140))
		if rng:chance(0.7) then
			Kit.box(parent, cf * CFrame.new(rng:range(-length / 3, length / 3), level * 3.2 + 1.3, 0), 3.4, 2.3, 3.2, M.Cardboard, rgb(170, 140, 100), { Decor = true })
		end
	end
end

function Props.stove(parent, cf)
	Kit.box(parent, cf * CFrame.new(0, 1.6, 0), 3, 3.2, 2.2, M.Metal, rgb(40, 40, 42), { Name = "Stove" })
	Kit.column(parent, (cf * CFrame.new(0.6, 3.2, 0.5)).Position, 6, 0.5, M.Metal, rgb(40, 40, 42), { Decor = true })
end

function Props.rug(parent, cf, w, d, color)
	Kit.box(parent, cf * CFrame.new(0, 0.05, 0), w, 0.1, d, M.Fabric, color, { Decor = true, NoShadow = true })
end

return Props
