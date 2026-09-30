--[[
	MapLayout — "Kestrel Valley"
	Macro geography of the battlefield as plain data. Site details (building
	placements, lanes, pads) are derived from this by Server.World.Plans; the
	terrain heightfield and every builder consume the result. Units are studs.
	Coordinates are {x, z}; heights come from the heightfield at build time.

	Orientation: Ashford Coalition (Alpha) holds the south (−Z), Varn
	Directorate (Bravo) the north (+Z). Objectives run west → east:
	A Fort Harlow (military base) · B Millbrook (village) · C Kessler Works (industrial).
]]

local MapLayout = {}

MapLayout.Name = "Kestrel Valley"
MapLayout.Seed = 41027
MapLayout.HalfSize = 768 -- playable boundary (invisible walls)
MapLayout.TerrainHalfSize = 896 -- terrain continues past the boundary as mountain backdrop
MapLayout.BaseHeight = 12
MapLayout.WaterLevel = 4
MapLayout.KillHeight = -40 -- below this Y players are out of bounds

MapLayout.HQs = {
	Alpha = { Position = { 0, -640 }, Facing = { 0, 1 } },
	Bravo = { Position = { 0, 640 }, Facing = { 0, -1 } },
}

-- Capture objectives. Centers are resolved to terrain height at build time.
MapLayout.Zones = {
	{ Id = "A", Name = "Fort Harlow", Site = "MilitaryBase", Position = { -440, 20 }, Radius = 36 },
	{ Id = "B", Name = "Millbrook", Site = "Village", Position = { 40, 20 }, Radius = 30 },
	{ Id = "C", Name = "Kessler Works", Site = "Industrial", Position = { 440, 20 }, Radius = 36 },
}

MapLayout.Sites = {
	MilitaryBase = { Center = { -440, 20 }, HalfExtents = { 125, 105 } },
	Village = { Center = { 40, 20 }, Radius = 150 },
	Industrial = { Center = { 440, 20 }, HalfExtents = { 125, 105 } },
}

-- Roads: Material is a terrain material painted onto the ground; the terrain is
-- also smoothed along the road so vehicles and players get even grades.
MapLayout.Roads = {
	{ -- 1: main north–south highway through Millbrook
		Name = "Valley Highway", Width = 18, Material = "Asphalt",
		Points = { { 0, -760 }, { 0, -560 }, { 10, -420 }, { 40, -250 }, { 40, 20 }, { 40, 250 }, { 10, 420 }, { 0, 560 }, { 0, 760 } },
	},
	{ -- 2: east–west road Fort Harlow → Millbrook → river bridge → Kessler Works
		Name = "Harlow Road", Width = 16, Material = "Asphalt",
		Points = { { -316, 20 }, { -200, 24 }, { -80, 20 }, { 40, 20 }, { 160, 20 }, { 228, 20 }, { 316, 20 } },
	},
	{ Name = "South Fort Track", Width = 10, Material = "Ground",
		Points = { { -60, -600 }, { -160, -500 }, { -240, -380 }, { -330, -230 }, { -420, -84 } } },
	{ Name = "North Fort Track", Width = 10, Material = "Ground",
		Points = { { -60, 600 }, { -160, 500 }, { -240, 380 }, { -330, 230 }, { -420, 124 } } },
	{ Name = "South Works Track", Width = 10, Material = "Ground",
		Points = { { 60, -600 }, { 140, -500 }, { 170, -400 }, { 260, -350 }, { 300, -220 }, { 420, -84 } } },
	{ Name = "North Works Track", Width = 10, Material = "Ground",
		Points = { { 60, 600 }, { 140, 500 }, { 170, 400 }, { 260, 350 }, { 300, 220 }, { 420, 124 } } },
	{ Name = "South Ridge Trail", Width = 7, Material = "Ground",
		Points = { { -90, 20 }, { -140, -80 }, { -160, -148 } } },
	{ Name = "North Ridge Trail", Width = 7, Material = "Ground",
		Points = { { -90, 20 }, { -140, 120 }, { -160, 188 } } },
	{ Name = "Mill Lane", Width = 7, Material = "Ground",
		Points = { { 160, 20 }, { 180, -60 }, { 196, -112 } } },
}

-- Rivers flow at WaterLevel. Width = water width, Depth below water level,
-- Valley = half-width of the gently lowered floodplain either side.
MapLayout.Rivers = {
	{
		Name = "Kestrel River", Width = 24, Depth = 7, Valley = 70,
		Points = {
			{ 300, 960 }, { 275, 720 }, { 240, 560 }, { 214, 440 }, { 214, 380 }, { 236, 220 }, { 222, 90 },
			{ 228, 20 }, { 240, -80 }, { 222, -200 }, { 214, -340 }, { 214, -420 }, { 240, -560 }, { 275, -720 }, { 300, -960 },
		},
	},
	{
		Name = "Harlow Brook", Width = 10, Depth = 4, Valley = 26,
		Points = {
			{ -640, 960 }, { -650, 700 }, { -610, 520 }, { -660, 340 }, { -630, 160 }, { -660, -20 },
			{ -620, -200 }, { -660, -380 }, { -630, -560 }, { -650, -720 }, { -640, -960 },
		},
	},
}

-- Rolling hills: { x, z, radius, height }
MapLayout.Hills = {
	{ -180, -240, 150, 38 }, -- Hill 214 (south trench line)
	{ -180, 280, 150, 36 }, -- Hill 188 (north trench line)
	{ 360, -420, 125, 48 }, -- Kestrel Rock hill
	{ 360, 440, 120, 44 }, -- Lookout hill
	{ -330, 440, 115, 50 }, -- Signal Hill (radio mast)
	{ -330, -440, 110, 42 },
	{ 110, -400, 90, 20 },
	{ 110, 420, 90, 18 },
	{ 560, -300, 150, 56 },
	{ 560, 330, 150, 54 },
	{ -120, -90, 70, 12 },
	{ -120, 130, 70, 10 },
	{ -560, -40, 120, 26 },
}

-- Sharp rock landmarks: { x, z, radius, height }
MapLayout.Spires = {
	{ 372, -432, 22, 42 }, -- Kestrel Rock
	{ -700, 600, 40, 60 },
	{ 700, -620, 36, 55 },
}

-- Forest masks: { x, z, radius, density 0..1 }
MapLayout.Forests = {
	{ -215, 20, 110, 0.75 }, -- Harlow Woods (between the fort and the village)
	{ -430, -320, 200, 0.95 },
	{ -430, 330, 200, 0.95 },
	{ 420, -300, 170, 0.85 },
	{ 420, 330, 170, 0.85 },
	{ -20, -350, 130, 0.65 },
	{ -20, 380, 130, 0.65 },
	{ 170, -230, 70, 0.55 },
	{ 170, 250, 70, 0.55 },
}

-- Named points of interest built by Server.World.Sites.Outposts.
-- Checkpoints attach to a road segment (index into Roads, segment, t along it).
MapLayout.Outposts = {
	{ Type = "Checkpoint", Road = 3, Segment = 2, T = 0.55 },
	{ Type = "Checkpoint", Road = 4, Segment = 2, T = 0.55 },
	{ Type = "Checkpoint", Road = 5, Segment = 2, T = 0.4 },
	{ Type = "Checkpoint", Road = 6, Segment = 2, T = 0.4 },
	{ Type = "Farmstead", Position = { 110, -300 }, Yaw = 20 },
	{ Type = "Chapel", Position = { 110, 330 }, Yaw = 200 },
	{ Type = "Mill", Position = { 200, -122 }, Yaw = -90 },
	{ Type = "RadioMast", Position = { -330, 440 } },
	{ Type = "Lookout", Position = { 350, 450 }, Yaw = 200 },
	{ Type = "Cabin", Position = { -470, -250 }, Yaw = 30 },
	{ Type = "Cabin", Position = { -470, 270 }, Yaw = 150 },
	{ Type = "Bunker", Position = { -250, -120 }, Yaw = 60 },
	{ Type = "Bunker", Position = { -250, 160 }, Yaw = 120 },
	{ Type = "Footbridge", Position = { -620, -200 }, Yaw = 90 },
	{ Type = "Footbridge", Position = { -630, 160 }, Yaw = 90 },
}

-- Zig-zag trench lines carved into the hills facing Millbrook.
MapLayout.Trenches = {
	{ Width = 7, Depth = 5, Points = { { -262, -186 }, { -236, -170 }, { -210, -188 }, { -184, -168 }, { -158, -186 }, { -132, -168 }, { -110, -184 } } },
	{ Width = 7, Depth = 5, Points = { { -262, 226 }, { -236, 210 }, { -210, 228 }, { -184, 208 }, { -158, 226 }, { -132, 208 }, { -110, 224 } } },
}

function MapLayout.getZone(id)
	for _, zone in ipairs(MapLayout.Zones) do
		if zone.Id == id then
			return zone
		end
	end
	return nil
end

return MapLayout
