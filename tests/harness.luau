--[[
	Offline map-generation harness (run with Lune: `lune run tests/harness.luau`).

	Executes the real Server.World generator outside Roblox using Lune's
	Roblox datatypes (Instance/CFrame/Vector3/Enum with reflection-checked
	properties). A mock Env replaces engine-only services: terrain writes are
	validated (array dimensions, occupancy range, material types) instead of
	voxelised, raycasts return nothing (builders fall back to the heightfield).

	Checks: generator runs without errors, spawn/objective metadata, part
	validity (finite, positive sizes), structures resting on the ground, part
	budget. Outputs build/Map.rbxm (map parts, no terrain) and
	build/footprints.tsv for scripts/render_heightmap.py overlays.
]]

local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local Instance, Vector3, CFrame, Enum = roblox.Instance, roblox.Vector3, roblox.CFrame, roblox.Enum

local game = Instance.new("DataModel")
local workspace = game:GetService("Workspace")
local lighting = game:GetService("Lighting")

local failures = {}
local function fail(msg)
	table.insert(failures, msg)
end

--------------------------------------------------------------- mocks

local terrainStats = { writes = 0, voxels = 0, water = 0, colors = 0 }
local VALID_WATER_PROPS = { WaterColor = "Color3", WaterReflectance = "number", WaterTransparency = "number", WaterWaveSize = "number", WaterWaveSpeed = "number", Decoration = "boolean" }
local terrain = setmetatable({}, {
	__index = {
		Clear = function() end,
		SetMaterialColor = function(_, material, color)
			assert(typeof(material) == "EnumItem", "SetMaterialColor material must be an EnumItem")
			assert(typeof(color) == "Color3", "SetMaterialColor color must be Color3")
			terrainStats.colors += 1
		end,
		WriteVoxels = function(_, region, resolution, materials, occupancy)
			assert(resolution == 4, "resolution must be 4")
			local size = region.Size
			local nx, ny, nz = size.X / 4, size.Y / 4, size.Z / 4
			assert(nx == math.floor(nx) and ny == math.floor(ny) and nz == math.floor(nz), "region not aligned to 4")
			assert(#materials == nx and #occupancy == nx, ("X dimension mismatch %d vs %d"):format(#materials, nx))
			for i = 1, nx do
				assert(#materials[i] == ny and #occupancy[i] == ny, "Y dimension mismatch")
				for j = 1, ny do
					assert(#materials[i][j] == nz and #occupancy[i][j] == nz, "Z dimension mismatch")
					for k = 1, nz do
						local o = occupancy[i][j][k]
						assert(type(o) == "number" and o >= 0 and o <= 1, "occupancy out of range")
						local m = materials[i][j][k]
						assert(typeof(m) == "EnumItem", "material must be EnumItem")
						if m == Enum.Material.Water then
							terrainStats.water += 1
						end
					end
				end
			end
			terrainStats.writes += 1
			terrainStats.voxels += nx * ny * nz
		end,
	},
	__newindex = function(t, key, value)
		local expected = VALID_WATER_PROPS[key]
		assert(expected, "unknown Terrain property " .. tostring(key))
		assert(typeof(value) == expected, ("Terrain.%s expects %s"):format(key, expected))
		rawset(t, key, value)
	end,
})

local EnvMock = {
	Workspace = workspace,
	Terrain = terrain,
	Lighting = lighting,
	raycast = function()
		return nil
	end,
	terrainY = function()
		return nil
	end,
	yield = function() end,
	waitFrame = function() end,
	isRunning = function()
		return false
	end,
	log = function(message)
		print("  [MapBuilder] " .. message)
	end,
}

local RaycastParamsMock = {
	new = function()
		return {}
	end,
}

local taskMock = {
	wait = function() end,
	defer = function(f, ...)
		f(...)
	end,
	spawn = function(f, ...)
		f(...)
	end,
	delay = function() end,
}

--------------------------------------------------------------- module loader

-- Index the source tree up front (Lune fs calls can't run inside metamethods).
local fileSet, dirSet = {}, {}
local function index(dir)
	dirSet[dir] = true
	for _, name in ipairs(fs.readDir(dir)) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			index(path)
		else
			fileSet[path] = true
		end
	end
end
index("src")
local function isFile(path)
	return fileSet[path] == true
end
local function isDir(path)
	return dirSet[path] == true
end

local proxies = {}
local moduleCache = {}
local makeProxy

-- Virtual Roblox tree → filesystem mapping (mirrors default.project.json).
local services = {
	ReplicatedStorage = { Shared = "src/shared" },
	ServerScriptService = { Server = "src/server" },
}

local function resolveChild(dirPath, name)
	for _, candidate in ipairs({ dirPath .. "/" .. name .. ".lua", dirPath .. "/" .. name .. ".luau" }) do
		if isFile(candidate) then
			return candidate, "file"
		end
	end
	if isDir(dirPath .. "/" .. name) then
		return dirPath .. "/" .. name, "dir"
	end
	return nil
end

function makeProxy(path, kind, parent, name)
	local key = path
	if proxies[key] then
		return proxies[key]
	end
	local proxy = { __path = path, __kind = kind }
	local function child(childName)
		if kind == "service" then
			local mapped = services[name][childName]
			return mapped and makeProxy(mapped, "dir", proxy, childName) or nil
		end
		local dirPath = kind == "dir" and path or nil
		if not dirPath then
			return nil
		end
		local childPath, childKind = resolveChild(dirPath, childName)
		return childPath and makeProxy(childPath, childKind, proxy, childName) or nil
	end
	setmetatable(proxy, {
		__index = function(_, k)
			if k == "Parent" then
				return parent
			elseif k == "Name" then
				return name
			elseif k == "WaitForChild" or k == "FindFirstChild" then
				return function(_, childName)
					local c = child(childName)
					assert(c or k == "FindFirstChild", "harness: no child " .. childName .. " under " .. path)
					return c
				end
			end
			local c = child(k)
			assert(c, "harness: " .. tostring(k) .. " is not a valid member of " .. path)
			return c
		end,
	})
	proxies[key] = proxy
	return proxy
end

local gameProxy = setmetatable({}, {
	__index = function(_, k)
		if k == "GetService" then
			return function(_, serviceName)
				if services[serviceName] then
					return makeProxy("@" .. serviceName, "service", nil, serviceName)
				end
				return game:GetService(serviceName)
			end
		end
		return game[k]
	end,
})

local baseEnv = {
	game = gameProxy, workspace = workspace, Instance = Instance, Vector3 = Vector3, CFrame = CFrame, Enum = Enum,
	Color3 = roblox.Color3, BrickColor = roblox.BrickColor, UDim2 = roblox.UDim2, UDim = roblox.UDim, Vector2 = roblox.Vector2,
	Region3 = roblox.Region3, NumberRange = roblox.NumberRange, NumberSequence = roblox.NumberSequence, ColorSequence = roblox.ColorSequence,
	RaycastParams = RaycastParamsMock, task = taskMock, typeof = typeof, warn = function(...)
		print("  WARN", ...)
	end,
	print = print, math = math, string = string, table = table, os = os, bit32 = bit32, coroutine = coroutine, utf8 = utf8,
	pairs = pairs, ipairs = ipairs, next = next, select = select, type = type, tostring = tostring, tonumber = tonumber,
	pcall = pcall, xpcall = xpcall, error = error, assert = assert, setmetatable = setmetatable, getmetatable = getmetatable,
	rawget = rawget, rawset = rawset, rawequal = rawequal, unpack = table.unpack,
}

local function requireProxy(proxy)
	local path = proxy.__path
	if path:match("src/server/World/Env%.lua$") then
		return EnvMock
	end
	local file = proxy.__kind == "file" and path or (path .. "/init.lua")
	if moduleCache[file] ~= nil then
		return moduleCache[file]
	end
	local source = fs.readFile(file)
	-- Lune copies the environment table's fields, so flatten baseEnv into it.
	local env = table.clone(baseEnv)
	env.script = proxy
	env.require = requireProxy
	local chunk = luau.load(source, { debugName = file, environment = env })
	local result = chunk()
	moduleCache[file] = result
	return result
end
baseEnv.require = requireProxy

--------------------------------------------------------------- run

local server = makeProxy("@ServerScriptService", "service", nil, "ServerScriptService").Server
local World = server.World
local t0 = os.clock()
local MapBuilder = requireProxy(World.MapBuilder)
local ok, mapOrErr, report = pcall(MapBuilder.generate)
if not ok then
	print("GENERATION FAILED: " .. tostring(mapOrErr))
	process.exit(1)
end
local map = mapOrErr
print(("generation finished in %.2fs (offline; Roblox timing differs)"):format(os.clock() - t0))
print(("terrain: %d WriteVoxels calls, %d voxels, %d water voxels"):format(terrainStats.writes, terrainStats.voxels, terrainStats.water))

local meta = MapBuilder.readMetadata(map)
for _, team in ipairs({ "Alpha", "Bravo" }) do
	local n = meta.SpawnPoints[team] and #meta.SpawnPoints[team] or 0
	if n ~= 24 then
		fail(("team %s has %d spawn points"):format(team, n))
	end
end
for _, id in ipairs({ "A", "B", "C" }) do
	local z = meta.Zones[id]
	if not (z and z.Center and z.Flag and z.Ring) then
		fail("objective " .. id .. " metadata incomplete")
	end
end

-- Part validity + footprint export + ground contact
local Plans = requireProxy(World.Plans)
local Heightfield = requireProxy(World.Heightfield)
local MapLayout = requireProxy(makeProxy("@ReplicatedStorage", "service", nil, "ReplicatedStorage").Shared.Config.MapLayout)
local Rng = requireProxy(makeProxy("@ReplicatedStorage", "service", nil, "ReplicatedStorage").Shared.Util.Rng)
local hf = Heightfield.new(MapLayout, Plans.build(MapLayout, Rng))

local counts = { parts = 0, models = 0, lights = 0, guis = 0, instances = 0 }
local rows = {}
local fullRows = {}
local function finite(n)
	return n == n and n ~= math.huge and n ~= -math.huge
end
local function aabb(part)
	local cf, s = part.CFrame, part.Size
	local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
	local ex = math.abs(r.X) * s.X / 2 + math.abs(u.X) * s.Y / 2 + math.abs(l.X) * s.Z / 2
	local ey = math.abs(r.Y) * s.X / 2 + math.abs(u.Y) * s.Y / 2 + math.abs(l.Y) * s.Z / 2
	local ez = math.abs(r.Z) * s.X / 2 + math.abs(u.Z) * s.Y / 2 + math.abs(l.Z) * s.Z / 2
	return cf.Position, ex, ey, ez
end
for _, inst in ipairs(map:GetDescendants()) do
	counts.instances += 1
	if inst:IsA("BasePart") then
		counts.parts += 1
		local p, ex, ey, ez = aabb(inst)
		local s = inst.Size
		if not (finite(p.X) and finite(p.Y) and finite(p.Z)) then
			fail("non-finite position on " .. inst:GetFullName())
		end
		if s.X <= 0 or s.Y <= 0 or s.Z <= 0 then
			fail(("non-positive size %s on %s"):format(tostring(s), inst:GetFullName()))
		end
		if inst.Transparency < 1 then
			local c = inst.Color
			local cf = inst.CFrame
			local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
			local shape = inst.ClassName
			if inst:IsA("Part") then
				shape = tostring(inst.Shape.Name)
			end
			table.insert(fullRows, table.concat({ shape, p.X, p.Y, p.Z, r.X, r.Y, r.Z, u.X, u.Y, u.Z, -l.X, -l.Y, -l.Z, s.X, s.Y, s.Z,
				math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255), inst.Transparency }, "\t"))
			table.insert(rows, ("%.1f\t%.1f\t%.1f\t%.1f\t%.1f\t%d\t%d\t%d"):format(p.X, p.Z, ex, ez, p.Y + ey,
				math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255)))
		end
	elseif inst:IsA("Model") then
		counts.models += 1
	elseif inst:IsA("Light") then
		counts.lights += 1
	elseif inst:IsA("SurfaceGui") then
		counts.guis += 1
	end
end

-- Ground contact: every structure model must reach the ground somewhere.
local floating = {}
local containers = { "FortHarlow", "Millbrook", "KesslerWorks", "HQ_Alpha", "HQ_Bravo", "Outposts", "Bridges" }
local function checkModel(model)
	local lowest = math.huge
	local anyPart = false
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 1 then
			anyPart = true
			local p, _, ey = aabb(d)
			local gap = (p.Y - ey) - hf:groundAt(p.X, p.Z)
			if gap < lowest then
				lowest = gap
			end
		end
	end
	if anyPart and lowest > 0.6 and process.env.HARNESS_DEBUG then
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				local p, _, ey = aabb(d)
				print("   ", model:GetFullName(), d.Name, d.ClassName, ("pos %.1f,%.1f,%.1f bottom %.1f ground %.1f"):format(p.X, p.Y, p.Z, p.Y - ey, hf:groundAt(p.X, p.Z)))
			end
		end
	end
	if anyPart and lowest > 0.6 then
		table.insert(floating, ("%s (lowest part %.1f studs above ground)"):format(model:GetFullName(), lowest))
	end
end
for _, name in ipairs(containers) do
	local c = map:FindFirstChild(name)
	if c then
		for _, child in ipairs(c:GetChildren()) do
			if child:IsA("Model") and #child:GetChildren() > 0 then
				local nested = false
				for _, g in ipairs(child:GetChildren()) do
					if g:IsA("Model") then
						nested = true
						checkModel(g)
					end
				end
				if not nested then
					checkModel(child)
				end
			end
		end
	else
		fail("missing site folder " .. name)
	end
end
for _, f in ipairs(floating) do
	fail("floating: " .. f)
end

print(("instances %d | parts %d | models %d | lights %d | surface guis %d"):format(counts.instances, counts.parts, counts.models, counts.lights, counts.guis))
if report and report.foliage then
	print(("foliage: %d trees, %d bushes, %d rock clusters, %d logs, %d puddles"):format(report.foliage.trees, report.foliage.bushes, report.foliage.rocks, report.foliage.logs, report.puddles or 0))
end
if counts.parts > 45000 then
	fail("part budget exceeded: " .. counts.parts)
end
if counts.lights > 120 then
	fail("light budget exceeded: " .. counts.lights)
end

fs.writeDir("build")
fs.writeFile("build/footprints.tsv", table.concat(rows, "\n"))
fs.writeFile("build/parts.tsv", table.concat(fullRows, "\n"))
fs.writeFile("build/Map.rbxm", roblox.serializeModel({ map }))
print("wrote build/Map.rbxm and build/footprints.tsv")

if #failures > 0 then
	for _, f in ipairs(failures) do
		print("FAIL " .. f)
	end
	print(#failures .. " harness failure(s)")
	process.exit(1)
end
print("harness OK")
