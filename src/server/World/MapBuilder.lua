--[[
	MapBuilder
	Orchestrates generation of Kestrel Valley and decides between a baked map
	and runtime generation.

	* MapBuilder.generate()  – clears terrain + Workspace.Map and rebuilds
	  everything deterministically (same seed ⇒ same map on every run).
	* MapBuilder.bake()      – Studio edit-mode entry point (plugin or command
	  bar). Generates and tags the result so File > Save persists it.
	* MapBuilder.ensure()    – server runtime: reuse a baked map whose
	  GeneratorVersion matches, otherwise generate one now.
	* MapBuilder.readMetadata(map) – spawn points and objective markers, read
	  from instances so baked and generated maps behave identically.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapLayout = require(Shared.Config.MapLayout)
local Rng = require(Shared.Util.Rng)

local Env = require(script.Parent.Env)
local Plans = require(script.Parent.Plans)
local Heightfield = require(script.Parent.Heightfield)
local TerrainGenerator = require(script.Parent.TerrainGenerator)
local Kit = require(script.Parent.Kit)
local Foliage = require(script.Parent.Foliage)
local HQ = require(script.Parent.Sites.HQ)
local Objectives = require(script.Parent.Sites.Objectives)
local MilitaryBase = require(script.Parent.Sites.MilitaryBase)
local Village = require(script.Parent.Sites.Village)
local Industrial = require(script.Parent.Sites.Industrial)
local Outposts = require(script.Parent.Sites.Outposts)

local MapBuilder = {}

-- Bump whenever generation output changes so stale baked maps are rebuilt.
MapBuilder.VERSION = 3

local function buildBoundary(map)
	local half = MapLayout.HalfSize
	local walls = Instance.new("Folder")
	walls.Name = "Boundary"
	for _, spec in ipairs({
		{ Vector3.new(0, 250, -half - 2), Vector3.new(half * 2 + 8, 600, 4) },
		{ Vector3.new(0, 250, half + 2), Vector3.new(half * 2 + 8, 600, 4) },
		{ Vector3.new(-half - 2, 250, 0), Vector3.new(4, 600, half * 2 + 8) },
		{ Vector3.new(half + 2, 250, 0), Vector3.new(4, 600, half * 2 + 8) },
	}) do
		Kit.part(walls, CFrame.new(spec[1]), spec[2], Enum.Material.SmoothPlastic, Color3.new(1, 1, 1),
			{ Transparency = 1, NoQuery = true, NoShadow = true, Name = "Boundary" })
	end
	walls.Parent = map
end

--[[
	generate(options) -> map, report
	options.log(message) (optional)
]]
function MapBuilder.generate(options)
	options = options or {}
	local log = options.log or Env.log
	local t0 = os.clock()
	local report = {}

	local plan = Plans.build(MapLayout, Rng)
	local hf = Heightfield.new(MapLayout, plan)
	Kit.calibrate(Env)
	log(("wedge calibration: rise=%d apex=(%d,%d) measured=%s"):format(
		Kit.orientation.wedgeRise, Kit.orientation.apexX, Kit.orientation.apexZ, tostring(Kit.orientation.calibrated)))

	local old = Env.Workspace:FindFirstChild("Map")
	if old then
		old:Destroy()
	end

	local terrainStats = TerrainGenerator.generate(hf, MapLayout, Env)
	report.terrainSeconds = os.clock() - t0
	log(("terrain: %d chunks, %d voxels in %.1fs"):format(terrainStats.chunks, terrainStats.voxels, report.terrainSeconds))

	local map = Instance.new("Folder")
	map.Name = "Map"
	map:SetAttribute("GeneratorVersion", MapBuilder.VERSION)
	map:SetAttribute("Seed", MapLayout.Seed)
	map:SetAttribute("MapName", MapLayout.Name)

	local ctx = { hf = hf, plan = plan, layout = MapLayout, Env = Env, map = map }
	local partsBefore = Kit.count
	local steps = {
		{ "HQs", function(rng) HQ.build(ctx, rng) end },
		{ "Objectives", function() Objectives.build(ctx) end },
		{ "Fort Harlow", function(rng) MilitaryBase.build(ctx, rng) end },
		{ "Millbrook", function(rng) Village.build(ctx, rng) end },
		{ "Kessler Works", function(rng) Industrial.build(ctx, rng) end },
		{ "Outposts", function(rng) Outposts.build(ctx, rng) end },
		{ "Foliage", function()
			local nature = Kit.model(map, "Nature")
			report.foliage = Foliage.scatter(ctx, nature)
			report.puddles = Foliage.puddles(ctx, nature)
		end },
	}
	for index, step in ipairs(steps) do
		local before = Kit.count
		local ts = os.clock()
		step[2](Rng.new(MapLayout.Seed + index * 1009))
		log(("%s: %d parts in %.2fs"):format(step[1], Kit.count - before, os.clock() - ts))
		Env.yield()
	end
	buildBoundary(map)
	report.parts = Kit.count - partsBefore
	report.seconds = os.clock() - t0
	map:SetAttribute("PartCount", report.parts)
	map.Parent = Env.Workspace
	log(("done: %d parts, %.1fs total"):format(report.parts, report.seconds))
	return map, report
end

-- Studio edit-mode bake: run from the Ironfront Tools plugin or the command bar.
function MapBuilder.bake()
	assert(not Env.isRunning(), "Bake from Edit mode (stop the play session first)")
	local map, report = MapBuilder.generate()
	map:SetAttribute("Baked", true)
	Env.log("Bake complete. Save the place (File > Save / Publish) to persist terrain and map.")
	return map, report
end

function MapBuilder.clear()
	local old = Env.Workspace:FindFirstChild("Map")
	if old then
		old:Destroy()
	end
	Env.Terrain:Clear()
end

function MapBuilder.readMetadata(map)
	local meta = { SpawnPoints = {}, Zones = {} }
	local spawns = map:FindFirstChild("SpawnPoints")
	if spawns then
		local list = spawns:GetChildren()
		table.sort(list, function(a, b)
			return (a:GetAttribute("Index") or 0) < (b:GetAttribute("Index") or 0)
		end)
		for _, part in ipairs(list) do
			local team = part:GetAttribute("Team")
			if team then
				meta.SpawnPoints[team] = meta.SpawnPoints[team] or {}
				table.insert(meta.SpawnPoints[team], part.CFrame)
			end
		end
	end
	local objectives = map:FindFirstChild("Objectives")
	if objectives then
		for _, zone in ipairs(objectives:GetChildren()) do
			local id = zone.Name:match("^Objective_(.+)$")
			if id then
				meta.Zones[id] = {
					Center = zone:GetAttribute("Center"),
					Flag = zone:FindFirstChild("Flag"),
					Ring = zone:FindFirstChild("Ring"),
				}
			end
		end
	end
	return meta
end

-- Runtime entry point. Returns metadata and "baked" | "generated".
function MapBuilder.ensure()
	local existing = Env.Workspace:FindFirstChild("Map")
	if existing and existing:GetAttribute("GeneratorVersion") == MapBuilder.VERSION then
		Env.log("using baked map (version " .. MapBuilder.VERSION .. ")")
		return MapBuilder.readMetadata(existing), "baked"
	end
	if existing then
		warn(("[MapBuilder] baked map version %s is outdated (current %d); regenerating at runtime. Re-bake in Studio to avoid this.")
			:format(tostring(existing:GetAttribute("GeneratorVersion")), MapBuilder.VERSION))
	end
	local map = MapBuilder.generate()
	return MapBuilder.readMetadata(map), "generated"
end

return MapBuilder
