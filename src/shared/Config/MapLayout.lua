--[[
	MapLayout
	Data description of the battlefield "Kestrel Valley" (original). The server
	world builder turns this into terrain and parts; the client reads objective
	positions from here for HUD indicators. Units are studs, Y=0 is ground level.
]]

local MapLayout = {}

MapLayout.HalfSize = 720 -- playable area spans -HalfSize..HalfSize on X and Z
MapLayout.Seed = 41027

MapLayout.Bases = {
	Alpha = { Position = { 0, 0, -610 }, Facing = { 0, 0, 1 } },
	Bravo = { Position = { 0, 0, 610 }, Facing = { 0, 0, -1 } },
}

MapLayout.Zones = {
	{ Id = "A", Name = "Millbrook", Position = { -390, 0, -10 }, Radius = 34 },
	{ Id = "B", Name = "Crossroads", Position = { 60, 0, 10 }, Radius = 30 },
	{ Id = "C", Name = "Hollow Farm", Position = { 430, 0, 0 }, Radius = 34 },
}

-- Polylines of road centre points {x, z}; Width in studs.
MapLayout.Roads = {
	{ Width = 22, Points = { { 0, -700 }, { 0, -420 }, { 60, -220 }, { 60, 220 }, { 0, 420 }, { 0, 700 } } },
	{ Width = 18, Points = { { -700, -30 }, { -390, -10 }, { 60, 10 }, { 430, 0 }, { 700, 20 } } },
	{ Width = 14, Points = { { -390, -10 }, { -300, -320 }, { 0, -470 } } },
	{ Width = 14, Points = { { 430, 0 }, { 320, 330 }, { 0, 470 } } },
}

-- Rolling hills: terrain balls sunk into the ground. {x, z, radius, sink}
MapLayout.Hills = {
	{ -200, -250, 90, 60 },
	{ 250, -260, 110, 75 },
	{ -250, 260, 110, 75 },
	{ 210, 250, 90, 60 },
	{ -600, -380, 140, 95 },
	{ 600, 380, 140, 95 },
	{ -600, 380, 130, 90 },
	{ 600, -380, 130, 90 },
	{ -160, 140, 60, 44 },
	{ 180, -120, 60, 44 },
}

-- Building sites near objectives: {x, z, yawDegrees, width, depth, floors, style}
MapLayout.Buildings = {
	-- Millbrook (A)
	{ -440, -60, 0, 26, 20, 2, "Brick" },
	{ -350, -64, 0, 22, 18, 1, "Plaster" },
	{ -445, 45, 180, 24, 18, 1, "Plaster" },
	{ -340, 40, 180, 30, 22, 2, "Brick" },
	{ -475, -45, 90, 18, 16, 1, "Wood" },
	-- Crossroads (B)
	{ 110, -40, 0, 28, 22, 2, "Plaster" },
	{ 10, 60, 180, 24, 20, 1, "Brick" },
	{ 115, 62, 180, 20, 16, 1, "Wood" },
	-- Hollow Farm (C)
	{ 480, -55, 0, 34, 24, 1, "Barn" },
	{ 380, 50, 180, 22, 18, 2, "Plaster" },
	{ 470, 60, 180, 16, 14, 1, "Wood" },
}

-- Forest regions: axis-aligned rectangles {minX, minZ, maxX, maxZ, density per 10k studs^2}
MapLayout.Forests = {
	{ -700, -560, -120, -120, 5 },
	{ 120, -560, 700, -120, 5 },
	{ -700, 120, -120, 560, 5 },
	{ 120, 120, 700, 560, 5 },
	{ -120, -380, 120, -140, 2 },
	{ -120, 140, 120, 380, 2 },
	{ -700, -120, 700, 120, 0.8 },
}

-- Keep-out circles for scatter (trees/rocks): bases get a wide clearing.
MapLayout.BaseClearRadius = 95

function MapLayout.vec(t)
	return Vector3.new(t[1], t[2], t[3])
end

function MapLayout.getZone(id)
	for _, zone in ipairs(MapLayout.Zones) do
		if zone.Id == id then
			return zone
		end
	end
	return nil
end

return MapLayout
