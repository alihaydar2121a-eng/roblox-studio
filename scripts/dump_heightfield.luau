local MapLayout = require("../src/shared/Config/MapLayout")
local Rng = require("../src/shared/Util/Rng")
local Plans = require("../src/server/World/Plans")
local Heightfield = require("../src/server/World/Heightfield")
local plan = Plans.build(MapLayout, Rng)
local hf = Heightfield.new(MapLayout, plan)
local step = 4
local lines = {}
for z = 896, -896, -step do
	local row = {}
	for x = -896, 896, step do
		local h, info = hf:height(x, z)
		local m = hf:material(x, z, h, hf:slopeAt(x, z), info)
		if info.water then m = "Water" end
		table.insert(row, ("%.1f:%s"):format(h, m))
	end
	table.insert(lines, table.concat(row, " "))
end
print(table.concat(lines, "\n"))
