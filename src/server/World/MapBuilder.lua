--[[
	MapBuilder
	Generates "Kestrel Valley" from Shared.Config.MapLayout: terrain and hills,
	roads, villages, forests, rocks, two team bases and three objectives.
	Generation is deterministic (seeded) so every server builds the same map.
]]

local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapLayout = require(Shared.Config.MapLayout)
local GameConfig = require(Shared.Config.GameConfig)
local toColor = require(Shared.Util.Color)
local Builder = require(script.Parent.Builder)

local MapBuilder = {}

local GROUND_DEPTH = 16
local FLOOR_HEIGHT = 12

local BUILDING_STYLES = {
	Brick = { Wall = Enum.Material.Brick, WallColor = Color3.fromRGB(140, 82, 66), Trim = Color3.fromRGB(90, 86, 80) },
	Plaster = { Wall = Enum.Material.Plaster, WallColor = Color3.fromRGB(214, 204, 180), Trim = Color3.fromRGB(110, 84, 62) },
	Wood = { Wall = Enum.Material.WoodPlanks, WallColor = Color3.fromRGB(120, 92, 64), Trim = Color3.fromRGB(70, 60, 50) },
	Barn = { Wall = Enum.Material.WoodPlanks, WallColor = Color3.fromRGB(128, 52, 44), Trim = Color3.fromRGB(220, 214, 200) },
}

local function yawCFrame(x, y, z, yawDegrees)
	return CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yawDegrees), 0)
end

local function setupLighting()
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(199, 206, 214)
	atmosphere.Decay = Color3.fromRGB(106, 112, 125)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.4
	atmosphere.Parent = Lighting

	local grade = Instance.new("ColorCorrectionEffect")
	grade.Saturation = -0.08
	grade.Contrast = 0.06
	grade.TintColor = Color3.fromRGB(255, 250, 240)
	grade.Parent = Lighting
end

local function buildTerrain(ctx)
	local terrain = workspace.Terrain
	local half = MapLayout.HalfSize + 80
	local chunk = 256
	for x = -half, half - 1, chunk do
		for z = -half, half - 1, chunk do
			local sx = math.min(chunk, half - x)
			local sz = math.min(chunk, half - z)
			terrain:FillBlock(
				CFrame.new(x + sx / 2, -GROUND_DEPTH / 2, z + sz / 2),
				Vector3.new(sx, GROUND_DEPTH, sz),
				Enum.Material.Grass
			)
		end
	end
	-- Forest floors get leafy ground for visual variety.
	for _, f in ipairs(MapLayout.Forests) do
		if f[5] >= 2 then
			local sx, sz = f[3] - f[1], f[4] - f[2]
			terrain:FillBlock(CFrame.new(f[1] + sx / 2, -2, f[2] + sz / 2), Vector3.new(sx, 4, sz), Enum.Material.LeafyGrass)
		end
	end
	for _, h in ipairs(MapLayout.Hills) do
		terrain:FillBall(Vector3.new(h[1], -h[4], h[2]), h[3], Enum.Material.Grass)
		-- Rocky crowns on the larger hills.
		if h[3] >= 110 then
			terrain:FillBall(Vector3.new(h[1], h[3] - h[4] - 10, h[2]), 18, Enum.Material.Rock)
		end
	end
	ctx.groundParams = RaycastParams.new()
	ctx.groundParams.FilterType = Enum.RaycastFilterType.Include
	ctx.groundParams.FilterDescendantsInstances = { terrain }
end

local function groundY(ctx, x, z)
	local result = workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -800, 0), ctx.groundParams)
	return result and result.Position.Y or 0
end

local function buildRoads(ctx, parent)
	for _, road in ipairs(MapLayout.Roads) do
		local paved = road.Width >= 18
		local material = paved and Enum.Material.Asphalt or Enum.Material.Ground
		local color = paved and Color3.fromRGB(62, 64, 66) or Color3.fromRGB(116, 96, 70)
		local points = road.Points
		for i = 1, #points - 1 do
			local a = Vector3.new(points[i][1], 0.3, points[i][2])
			local b = Vector3.new(points[i + 1][1], 0.3, points[i + 1][2])
			local length = (b - a).Magnitude
			Builder.part(parent, {
				Name = "Road",
				Size = Vector3.new(road.Width, 0.6, length),
				CFrame = CFrame.lookAt((a + b) / 2, b),
				Material = material,
				Color = color,
			})
			if paved then
				-- Dashed centre line
				local dashes = math.floor(length / 16)
				for d = 1, dashes do
					local t = (d - 0.5) / dashes
					Builder.part(parent, {
						Name = "Marking",
						Size = Vector3.new(0.5, 0.05, 6),
						CFrame = CFrame.lookAt(a:Lerp(b, t), b) + Vector3.new(0, 0.32, 0),
						Material = Enum.Material.SmoothPlastic,
						Color = Color3.fromRGB(220, 210, 170),
						CanCollide = false,
						CanQuery = false,
						CastShadow = false,
					})
				end
			end
			table.insert(ctx.segments, { a.X, a.Z, b.X, b.Z, road.Width / 2 })
		end
		for _, pt in ipairs(points) do
			Builder.part(parent, {
				Name = "RoadJoint",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.6, road.Width, road.Width),
				CFrame = CFrame.new(pt[1], 0.29, pt[2]) * CFrame.Angles(0, 0, math.rad(90)),
				Material = material,
				Color = color,
			})
		end
	end
end

local function buildBuilding(ctx, parent, def)
	local x, z, yaw, width, depth, floors, styleName = table.unpack(def)
	local style = BUILDING_STYLES[styleName] or BUILDING_STYLES.Plaster
	local height = styleName == "Barn" and 18 or FLOOR_HEIGHT * floors
	local model = Instance.new("Model")
	model.Name = styleName .. "Building"
	local origin = yawCFrame(x, 0, z, yaw)
	local wallProps = { Material = style.Wall, Color = style.WallColor }
	local t = 1

	-- Foundation / ground floor
	Builder.part(model, {
		Name = "Foundation",
		Size = Vector3.new(width + 1, 1.2, depth + 1),
		CFrame = origin * CFrame.new(0, 0.6, 0),
		Material = Enum.Material.Concrete,
		Color = style.Trim,
	})

	-- One column per bay; each column has a gap per floor (door on the ground floor if requested).
	local function wallSide(cf, length, hasDoor)
		local columns = {}
		local bays = math.max(1, math.floor(length / 8))
		local nFloors = styleName == "Barn" and 1 or floors
		local doorBay = math.ceil(bays / 2)
		for i = 1, bays do
			local offset = -length / 2 + (i - 0.5) * (length / bays)
			local isDoor = hasDoor and i == doorBay
			local column = { offset = offset, width = 3.5, gaps = {} }
			for f = 1, nFloors do
				local base = 1.2 + (f - 1) * FLOOR_HEIGHT
				if isDoor and f == 1 then
					local barn = styleName == "Barn"
					column.width = barn and 10 or 5
					table.insert(column.gaps, { base, base + (barn and 12 or 8) })
				else
					table.insert(column.gaps, { base + 3.5, base + 7.5 })
				end
			end
			table.insert(columns, column)
		end
		Builder.wall(model, cf, length, height + 1.2, t, columns, wallProps)
	end

	-- Front (-Z local, door), back (+Z, rear door), left/right (windows only)
	wallSide(origin * CFrame.new(0, 0, -depth / 2 + t / 2), width, true)
	wallSide(origin * CFrame.new(0, 0, depth / 2 - t / 2), width, true)
	wallSide(origin * CFrame.new(-width / 2 + t / 2, 0, 0) * CFrame.Angles(0, math.rad(90), 0), depth - 2 * t, false)
	wallSide(origin * CFrame.new(width / 2 - t / 2, 0, 0) * CFrame.Angles(0, math.rad(90), 0), depth - 2 * t, false)

	-- Upper floors with a ramp along the left wall
	if styleName ~= "Barn" and floors > 1 then
		local rampWidth, rampLength = 4, math.min(16, depth - 4)
		local innerW, innerD = width - 2 * t, depth - 2 * t
		for f = 2, floors do
			local y = 1.2 + (f - 1) * FLOOR_HEIGHT
			-- main slab beside the ramp strip
			Builder.part(model, {
				Name = "Floor",
				Size = Vector3.new(innerW - rampWidth, 1, innerD),
				CFrame = origin * CFrame.new(rampWidth / 2, y - 0.5, 0),
				Material = Enum.Material.WoodPlanks,
				Color = Color3.fromRGB(110, 84, 60),
			})
			-- strip beyond the ramp
			local stripDepth = innerD - rampLength
			if stripDepth > 0.5 then
				Builder.part(model, {
					Name = "Floor",
					Size = Vector3.new(rampWidth, 1, stripDepth),
					CFrame = origin * CFrame.new(-innerW / 2 + rampWidth / 2, y - 0.5, innerD / 2 - stripDepth / 2),
					Material = Enum.Material.WoodPlanks,
					Color = Color3.fromRGB(110, 84, 60),
				})
			end
			Builder.part(model, {
				ClassName = "WedgePart",
				Name = "Stairs",
				Size = Vector3.new(rampWidth, FLOOR_HEIGHT, rampLength),
				CFrame = origin * CFrame.new(-innerW / 2 + rampWidth / 2, y - FLOOR_HEIGHT + FLOOR_HEIGHT / 2, -innerD / 2 + rampLength / 2),
				Material = Enum.Material.WoodPlanks,
				Color = Color3.fromRGB(96, 74, 54),
			})
		end
	end

	-- Roof with parapet
	local roofY = height + 1.2
	Builder.part(model, {
		Name = "Roof",
		Size = Vector3.new(width + 1.5, 1, depth + 1.5),
		CFrame = origin * CFrame.new(0, roofY + 0.5, 0),
		Material = styleName == "Barn" and Enum.Material.CorrodedMetal or Enum.Material.Slate,
		Color = styleName == "Barn" and Color3.fromRGB(96, 98, 100) or Color3.fromRGB(78, 74, 72),
	})
	if floors > 1 and styleName ~= "Barn" then
		Builder.part(model, {
			Name = "Trim",
			Size = Vector3.new(width + 0.6, 0.6, depth + 0.6),
			CFrame = origin * CFrame.new(0, 1.2 + FLOOR_HEIGHT - 0.3, 0),
			Material = Enum.Material.SmoothPlastic,
			Color = style.Trim,
			CanCollide = false,
			CanQuery = false,
		})
	end

	CollectionService:AddTag(model, "Building")
	model.Parent = parent
	table.insert(ctx.keepOut, { x, z, math.max(width, depth) * 0.75 + 6 })
end

local function buildCover(parent, cf, kind)
	if kind == "Sandbags" then
		for i = -2, 2 do
			Builder.part(parent, {
				Name = "Sandbag",
				Size = Vector3.new(2.4, 1.2, 1.4),
				CFrame = cf * CFrame.new(i * 2.3, 0.6, 0) * CFrame.Angles(0, math.rad((i % 2) * 4), 0),
				Material = Enum.Material.Fabric,
				Color = Color3.fromRGB(170, 152, 112),
			})
			Builder.part(parent, {
				Name = "Sandbag",
				Size = Vector3.new(2.4, 1.2, 1.4),
				CFrame = cf * CFrame.new(i * 2.3 + 1.1, 1.8, 0),
				Material = Enum.Material.Fabric,
				Color = Color3.fromRGB(160, 142, 104),
			})
		end
	else -- Crates
		Builder.part(parent, {
			Name = "Crate",
			Size = Vector3.new(4, 4, 4),
			CFrame = cf * CFrame.new(0, 2, 0),
			Material = Enum.Material.WoodPlanks,
			Color = Color3.fromRGB(122, 98, 64),
		})
		Builder.part(parent, {
			Name = "Crate",
			Size = Vector3.new(3, 3, 3),
			CFrame = cf * CFrame.new(3.6, 1.5, 0.6) * CFrame.Angles(0, math.rad(20), 0),
			Material = Enum.Material.WoodPlanks,
			Color = Color3.fromRGB(110, 90, 60),
		})
	end
end

local function buildZone(ctx, parent, zone)
	local folder = Builder.folder(parent, "Objective_" .. zone.Id)
	local p = zone.Position
	local center = CFrame.new(p[1], 0, p[3])
	local ring = Builder.part(folder, {
		Name = "Ring",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, zone.Radius * 2, zone.Radius * 2),
		CFrame = center * CFrame.new(0, 0.7, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.75,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Color = Color3.fromRGB(200, 200, 200),
	})
	Builder.part(folder, {
		Name = "Pole",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(22, 0.5, 0.5),
		CFrame = center * CFrame.new(0, 11, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(180, 180, 184),
	})
	local flag = Builder.part(folder, {
		Name = "Flag",
		Size = Vector3.new(0.15, 3.5, 6),
		CFrame = center * CFrame.new(0, 19.8, 3.2),
		Material = Enum.Material.Fabric,
		CanCollide = false,
		Color = Color3.fromRGB(200, 200, 200),
	})
	-- Cover ring around the objective
	for i = 0, 3 do
		local angle = math.rad(i * 90 + 45)
		local r = zone.Radius * 0.55
		local cf = center * CFrame.new(math.cos(angle) * r, 0, math.sin(angle) * r) * CFrame.Angles(0, -angle + math.rad(90), 0)
		buildCover(folder, cf, i % 2 == 0 and "Sandbags" or "Crates")
	end
	table.insert(ctx.keepOut, { p[1], p[3], zone.Radius + 12 })
	return { Flag = flag, Ring = ring }
end

local function buildBase(ctx, parent, teamId, base)
	local teamCfg
	for _, def in ipairs(GameConfig.Teams) do
		if def.Id == teamId then
			teamCfg = def
		end
	end
	local folder = Builder.folder(parent, "Base_" .. teamId)
	local pos = MapLayout.vec(base.Position)
	local facing = MapLayout.vec(base.Facing)
	local cf = CFrame.lookAt(pos, pos + facing)
	local accent = toColor(teamCfg.Uniform.Band)

	Builder.part(folder, {
		Name = "Pad",
		Size = Vector3.new(110, 1, 80),
		CFrame = cf * CFrame.new(0, 0.5, 0),
		Material = Enum.Material.Concrete,
		Color = Color3.fromRGB(128, 126, 120),
	})
	-- Perimeter barriers (open toward the battlefield: local -Z is forward)
	local barrierProps = { Material = Enum.Material.Fabric, Color = Color3.fromRGB(150, 138, 108) }
	Builder.wall(folder, cf * CFrame.new(0, 1, 40), 110, 5, 3, {}, barrierProps)
	Builder.wall(folder, cf * CFrame.new(-55, 1, 0) * CFrame.Angles(0, math.rad(90), 0), 80, 5, 3, {}, barrierProps)
	Builder.wall(folder, cf * CFrame.new(55, 1, 0) * CFrame.Angles(0, math.rad(90), 0), 80, 5, 3, {}, barrierProps)
	Builder.wall(folder, cf * CFrame.new(-36, 1, -40), 38, 5, 3, {}, barrierProps)
	Builder.wall(folder, cf * CFrame.new(36, 1, -40), 38, 5, 3, {}, barrierProps)

	-- Tents
	for i = -1, 1, 2 do
		local tentCf = cf * CFrame.new(i * 36, 1, 22)
		Builder.part(folder, {
			Name = "Tent",
			Size = Vector3.new(18, 8, 12),
			CFrame = tentCf * CFrame.new(0, 4, 0),
			Material = Enum.Material.Fabric,
			Color = toColor(teamCfg.Uniform.Torso),
		})
		Builder.part(folder, {
			Name = "TentStripe",
			Size = Vector3.new(18.2, 1, 12.2),
			CFrame = tentCf * CFrame.new(0, 6.5, 0),
			Material = Enum.Material.Fabric,
			Color = accent,
			CanCollide = false,
		})
	end

	-- Flag
	Builder.part(folder, {
		Name = "Pole",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(26, 0.6, 0.6),
		CFrame = cf * CFrame.new(0, 14, 30) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(180, 180, 184),
	})
	Builder.part(folder, {
		Name = "TeamFlag",
		Size = Vector3.new(0.15, 4.5, 8),
		CFrame = cf * CFrame.new(0, 24, 34.2),
		Material = Enum.Material.Fabric,
		CanCollide = false,
		Color = toColor(teamCfg.UiColor),
	})

	-- Spawn points: 3 rows x 6, facing the battlefield
	local points = {}
	for row = 0, 2 do
		for col = -2.5, 2.5 do
			local spawnCf = cf * CFrame.new(col * 8, 1, 4 - row * 8)
			table.insert(points, spawnCf)
			Builder.part(folder, {
				Name = "SpawnMarker",
				Size = Vector3.new(4, 0.1, 4),
				CFrame = spawnCf * CFrame.new(0, 0.05, 0),
				Material = Enum.Material.SmoothPlastic,
				Color = accent,
				Transparency = 0.4,
				CanCollide = false,
				CanQuery = false,
				CastShadow = false,
			})
		end
	end
	return points
end

local function isClear(ctx, x, z)
	local half = MapLayout.HalfSize - 10
	if math.abs(x) > half or math.abs(z) > half then
		return false
	end
	for _, s in ipairs(ctx.segments) do
		if Builder.distanceToSegment2D(x, z, s[1], s[2], s[3], s[4]) < s[5] + 6 then
			return false
		end
	end
	for _, k in ipairs(ctx.keepOut) do
		if (x - k[1]) ^ 2 + (z - k[2]) ^ 2 < k[3] ^ 2 then
			return false
		end
	end
	return true
end

local function buildTree(ctx, parent, rng, x, z)
	local y = groundY(ctx, x, z)
	local pine = rng:NextNumber() < 0.55
	local trunkHeight = rng:NextNumber(14, 24)
	local trunkWidth = rng:NextNumber(1.4, 2.4)
	Builder.part(parent, {
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(trunkHeight, trunkWidth, trunkWidth),
		CFrame = CFrame.new(x, y + trunkHeight / 2 - 0.5, z) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(92 + rng:NextInteger(-10, 10), 70, 52),
	})
	local leafColor = pine and Color3.fromRGB(46, 84 + rng:NextInteger(-8, 8), 52)
		or Color3.fromRGB(78 + rng:NextInteger(-10, 10), 112 + rng:NextInteger(-10, 10), 58)
	local canopies = pine and 3 or 1
	for i = 1, canopies do
		local size = pine and (13 - i * 3) or rng:NextNumber(14, 20)
		local cy = pine and (y + trunkHeight * 0.45 + i * 4.5) or (y + trunkHeight + size * 0.2)
		Builder.part(parent, {
			Name = "Canopy",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(size, size, size),
			CFrame = CFrame.new(x + rng:NextNumber(-0.6, 0.6), cy, z + rng:NextNumber(-0.6, 0.6)),
			Material = Enum.Material.Grass,
			Color = leafColor,
			CanCollide = false,
			CanQuery = false, -- foliage conceals but does not stop rounds
			CanTouch = false,
		})
	end
end

local function scatter(ctx, parent)
	local rng = Random.new(MapLayout.Seed)
	local trees = Builder.folder(parent, "Trees")
	local rocks = Builder.folder(parent, "Rocks")
	for _, f in ipairs(MapLayout.Forests) do
		local area = (f[3] - f[1]) * (f[4] - f[2])
		local count = math.floor(area / 10000 * f[5])
		for _ = 1, count do
			local x, z = rng:NextNumber(f[1], f[3]), rng:NextNumber(f[2], f[4])
			if isClear(ctx, x, z) then
				buildTree(ctx, trees, rng, x, z)
			end
		end
	end
	for _ = 1, 90 do
		local x = rng:NextNumber(-MapLayout.HalfSize, MapLayout.HalfSize)
		local z = rng:NextNumber(-MapLayout.HalfSize, MapLayout.HalfSize)
		if isClear(ctx, x, z) then
			local s = rng:NextNumber(3, 9)
			Builder.part(rocks, {
				Name = "Rock",
				Size = Vector3.new(s * rng:NextNumber(0.8, 1.6), s, s * rng:NextNumber(0.8, 1.4)),
				CFrame = CFrame.new(x, groundY(ctx, x, z) + s * 0.25, z)
					* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.3, 0.3)),
				Material = Enum.Material.Slate,
				Color = Color3.fromRGB(110, 112, 110),
			})
		end
	end
end

local function buildBoundary(parent)
	local half = MapLayout.HalfSize
	local walls = Builder.folder(parent, "Boundary")
	for _, spec in ipairs({
		{ Vector3.new(0, 100, -half - 2), Vector3.new(half * 2 + 8, 200, 4) },
		{ Vector3.new(0, 100, half + 2), Vector3.new(half * 2 + 8, 200, 4) },
		{ Vector3.new(-half - 2, 100, 0), Vector3.new(4, 200, half * 2 + 8) },
		{ Vector3.new(half + 2, 100, 0), Vector3.new(4, 200, half * 2 + 8) },
	}) do
		Builder.part(walls, {
			Name = "Boundary",
			Size = spec[2],
			CFrame = CFrame.new(spec[1]),
			Transparency = 1,
			CanQuery = false,
			CastShadow = false,
		})
	end
end

--[[
	MapBuilder.build() -> { SpawnPoints = { [teamId] = {CFrame} }, ZoneVisuals = { [zoneId] = {Flag, Ring} } }
]]
function MapBuilder.build()
	local map = Instance.new("Folder")
	map.Name = "Map"
	local ctx = { segments = {}, keepOut = {} }

	setupLighting()
	buildTerrain(ctx)

	local spawnPoints = {}
	local bases = Builder.folder(map, "Bases")
	for teamId, base in pairs(MapLayout.Bases) do
		spawnPoints[teamId] = buildBase(ctx, bases, teamId, base)
		table.insert(ctx.keepOut, { base.Position[1], base.Position[3], MapLayout.BaseClearRadius })
	end

	buildRoads(ctx, Builder.folder(map, "Roads"))

	local zoneVisuals = {}
	local objectives = Builder.folder(map, "Objectives")
	for _, zone in ipairs(MapLayout.Zones) do
		zoneVisuals[zone.Id] = buildZone(ctx, objectives, zone)
	end

	local buildings = Builder.folder(map, "Buildings")
	for _, def in ipairs(MapLayout.Buildings) do
		buildBuilding(ctx, buildings, def)
	end

	scatter(ctx, map)
	buildBoundary(map)
	map.Parent = workspace

	return { SpawnPoints = spawnPoints, ZoneVisuals = zoneVisuals }
end

return MapBuilder
