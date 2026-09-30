--!nocheck
-- Tests for the pure world-planning layer (Plans + Heightfield). Run: luau tests/world.luau
local T = require("./TestRunner")
local describe, eq, near, truthy = T.describe, T.expectEqual, T.expectNear, T.expectTrue

local MapLayout = require("../src/shared/Config/MapLayout")
local Rng = require("../src/shared/Util/Rng")
local Plans = require("../src/server/World/Plans")
local Heightfield = require("../src/server/World/Heightfield")

local t0 = os.clock()
local plan = Plans.build(MapLayout, Rng)
local hf = Heightfield.new(MapLayout, plan)
print(("plan + heightfield init: %.2fs"):format(os.clock() - t0))

local function rotatedCorners(b, inset)
	local out = {}
	for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 }, { 0, 0 } }) do
		local x, z = Plans.toWorld(b.X, b.Z, b.Yaw or 0, c[1] * (b.W / 2 - inset), c[2] * (b.D / 2 - inset))
		table.insert(out, { x, z })
	end
	return out
end

describe("Rng", function(it)
	it("is deterministic and seed-sensitive", function()
		local a, b, c = Rng.new(5), Rng.new(5), Rng.new(6)
		local same, diff = true, false
		for _ = 1, 20 do
			local x, y, z = a:float(), b:float(), c:float()
			same = same and x == y
			diff = diff or x ~= z
			truthy(x >= 0 and x < 1)
		end
		truthy(same, "same seed same stream")
		truthy(diff, "different seeds differ")
	end)
	it("int stays within bounds", function()
		local r = Rng.new(1)
		for _ = 1, 2000 do
			local v = r:int(3, 7)
			truthy(v >= 3 and v <= 7 and v == math.floor(v))
		end
	end)
end)

describe("Plans", function(it)
	it("plans 12-20 village buildings", function()
		local n = #plan.sites.Village.Buildings
		truthy(n >= 12 and n <= 20, "village buildings = " .. n)
	end)
	it("has HQs for both teams with 24 spawns each", function()
		eq(#plan.hqs.Alpha.Spawns, 24)
		eq(#plan.hqs.Bravo.Spawns, 24)
	end)
	it("finds bridges where roads cross rivers", function()
		truthy(#plan.bridges >= 3, "bridges = " .. #plan.bridges)
		local main = false
		for _, b in ipairs(plan.bridges) do
			if b.Kind == "Concrete" then
				main = true
			end
		end
		truthy(main, "main road bridge exists")
	end)
	it("is deterministic", function()
		local again = Plans.build(MapLayout, Rng)
		eq(#again.sites.Village.Buildings, #plan.sites.Village.Buildings)
		for i, b in ipairs(plan.sites.Village.Buildings) do
			local o = again.sites.Village.Buildings[i]
			eq(o.X, b.X)
			eq(o.Z, b.Z)
			eq(o.Type, b.Type)
		end
	end)
	it("village footprints never overlap", function()
		local fp = plan.sites.Village.Footprints
		for i = 1, #fp do
			for j = i + 1, #fp do
				local a, b = fp[i], fp[j]
				local overlap = math.abs(a[1] - b[1]) < a[3] + b[3] and math.abs(a[2] - b[2]) < a[4] + b[4]
				truthy(not overlap, ("footprints %d and %d overlap"):format(i, j))
			end
		end
	end)
	it("everything is inside the playable boundary", function()
		local limit = MapLayout.HalfSize - 20
		local function check(x, z, what)
			truthy(math.abs(x) < limit and math.abs(z) < limit, what .. " outside boundary")
		end
		for _, hq in pairs(plan.hqs) do
			for _, s in ipairs(hq.Spawns) do
				check(s.X, s.Z, "spawn")
			end
		end
		for _, o in ipairs(plan.outposts) do
			check(o.X, o.Z, o.Type)
		end
	end)
end)

describe("Heightfield", function(it)
	it("building footprints are flat (no floating/buried corners)", function()
		local lists = { plan.sites.Village.Buildings, plan.sites.MilitaryBase.Structures, plan.sites.Industrial.Structures }
		local worst = 0
		for _, list in ipairs(lists) do
			for _, b in ipairs(list) do
				if b.W and b.D then
					local ys = {}
					for _, c in ipairs(rotatedCorners(b, 0)) do
						table.insert(ys, (hf:height(c[1], c[2])))
					end
					local lo, hi = math.min(table.unpack(ys)), math.max(table.unpack(ys))
					worst = math.max(worst, hi - lo)
				end
			end
		end
		truthy(worst < 0.6, ("max footprint height variation %.2f"):format(worst))
	end)
	it("HQ spawn pads are flat and dry", function()
		for _, hq in pairs(plan.hqs) do
			local h0 = hf:height(hq.X, hq.Z)
			for _, s in ipairs(hq.Spawns) do
				local h, info = hf:height(s.X, s.Z)
				truthy(math.abs(h - h0) < 0.3, "spawn not level with pad")
				truthy(not info.water and h > MapLayout.WaterLevel + 2, "spawn under water")
			end
		end
	end)
	it("objective centres are on dry flat ground", function()
		for _, z in ipairs(MapLayout.Zones) do
			local x, zz = z.Position[1], z.Position[2]
			local h, info = hf:height(x, zz)
			truthy(not info.water and h > MapLayout.WaterLevel + 2)
			truthy(hf:slopeAt(x + 10, zz + 10) < 0.05, "zone " .. z.Id .. " not flat")
		end
	end)
	it("rivers carry water below water level", function()
		for _, river in ipairs(MapLayout.Rivers) do
			local wet = 0
			for i = 1, #river.Points - 1 do
				local a, b = river.Points[i], river.Points[i + 1]
				local x, z = (a[1] + b[1]) / 2, (a[2] + b[2]) / 2
				if math.abs(x) < 800 and math.abs(z) < 800 then
					local h, info = hf:height(x, z)
					if info.water and h < MapLayout.WaterLevel then
						wet += 1
					end
				end
			end
			truthy(wet >= 3, river.Name .. " wet samples = " .. wet)
		end
	end)
	it("roads have drivable grades", function()
		local worst = 0
		for _, road in ipairs(MapLayout.Roads) do
			for i = 1, #road.Points - 1 do
				local a, b = road.Points[i], road.Points[i + 1]
				local len = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
				local steps = math.floor(len / 4)
				local prev
				for k = 0, steps do
					local t = k / steps
					local x, z = a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t
					local h, info = hf:height(x, z)
					if prev and info.riverD > 14 and math.abs(x) < 740 and math.abs(z) < 740 then
						worst = math.max(worst, math.abs(h - prev) / (len / steps))
					end
					prev = h
				end
			end
		end
		truthy(worst < 0.5, ("max road grade %.2f"):format(worst))
	end)
	it("trenches are carved below the surrounding ground", function()
		local tr = MapLayout.Trenches[1]
		local a, b = tr.Points[3], tr.Points[4]
		local x, z = (a[1] + b[1]) / 2, (a[2] + b[2]) / 2
		local inside, info = hf:height(x, z)
		local flatLayout = table.clone(MapLayout)
		flatLayout.Trenches = {}
		local outside = Heightfield.new(flatLayout, plan):height(x, z)
		truthy(info.trench, "trench flag")
		truthy(outside - inside > 3, ("trench depth %.1f"):format(outside - inside))
	end)
	it("mountains rise beyond the boundary", function()
		local h = hf:height(820, 300)
		truthy(h > 80, ("mountain height %.1f"):format(h))
	end)
	it("materials are valid terrain materials", function()
		local valid = { Grass = true, LeafyGrass = true, Ground = true, Mud = true, Rock = true, Slate = true, Sand = true,
			Asphalt = true, Concrete = true, Cobblestone = true, Pavement = true }
		local r = Rng.new(3)
		for _ = 1, 400 do
			local x, z = r:range(-880, 880), r:range(-880, 880)
			local h, info = hf:height(x, z)
			local m = hf:material(x, z, h, hf:slopeAt(x, z), info)
			truthy(valid[m], "bad material " .. tostring(m))
		end
	end)
	it("samples fast enough for runtime generation", function()
		local t = os.clock()
		local r = Rng.new(9)
		for _ = 1, 20000 do
			hf:height(r:range(-880, 880), r:range(-880, 880))
		end
		local per = (os.clock() - t) / 20000
		print(("height() %.1f us/sample -> ~%.1fs for full terrain"):format(per * 1e6, per * 450 * 450))
		truthy(per < 60e-6)
	end)
end)

if not T.finish() then
	error("tests failed")
end
