--[[
	TerrainGenerator
	Writes the Heightfield into Roblox smooth terrain with chunked WriteVoxels
	(32×32 columns per call, only the vertical band that contains surface).
	Also applies the terrain palette, water look and grass decoration.
]]

local TerrainGenerator = {}

local RES = 4
local CHUNK = 32

-- Cohesive natural palette (muted greens, warm earth, cool stone).
local PALETTE = {
	Grass = Color3.fromRGB(94, 116, 62),
	LeafyGrass = Color3.fromRGB(72, 96, 50),
	Ground = Color3.fromRGB(110, 94, 72),
	Mud = Color3.fromRGB(76, 64, 50),
	Rock = Color3.fromRGB(112, 110, 104),
	Slate = Color3.fromRGB(94, 96, 94),
	Sand = Color3.fromRGB(170, 156, 122),
	Asphalt = Color3.fromRGB(62, 63, 66),
	Concrete = Color3.fromRGB(142, 140, 134),
	Cobblestone = Color3.fromRGB(122, 116, 106),
	Pavement = Color3.fromRGB(130, 128, 122),
}

function TerrainGenerator.applySettings(terrain)
	for name, color in pairs(PALETTE) do
		terrain:SetMaterialColor(Enum.Material[name], color)
	end
	terrain.WaterColor = Color3.fromRGB(44, 72, 70)
	terrain.WaterReflectance = 0.55
	terrain.WaterTransparency = 0.72
	terrain.WaterWaveSize = 0.08
	terrain.WaterWaveSpeed = 7
	-- Animated grass blades on Grass material; ignored if the engine refuses it.
	pcall(function()
		terrain.Decoration = true
	end)
end

local materialCache = {}
local function enumMaterial(name)
	local m = materialCache[name]
	if not m then
		m = Enum.Material[name]
		materialCache[name] = m
	end
	return m
end

--[[
	generate(hf, layout, Env) -> stats
	Clears existing terrain and writes the whole map. Yields cooperatively.
]]
function TerrainGenerator.generate(hf, layout, Env)
	local terrain = Env.Terrain
	terrain:Clear()
	TerrainGenerator.applySettings(terrain)

	local half = layout.TerrainHalfSize
	local columns = math.floor(half * 2 / RES)
	local chunks = math.ceil(columns / CHUNK)
	local waterLevel = layout.WaterLevel
	local AIR, WATER = Enum.Material.Air, Enum.Material.Water
	local stats = { chunks = 0, voxels = 0 }

	for ci = 0, chunks - 1 do
		for ck = 0, chunks - 1 do
			local baseX = -half + ci * CHUNK * RES
			local baseZ = -half + ck * CHUNK * RES
			local nx = math.min(CHUNK, columns - ci * CHUNK)
			local nz = math.min(CHUNK, columns - ck * CHUNK)

			-- Heights with a one-column border for slope estimation.
			local H = {}
			local infos = {}
			local minH, maxH = math.huge, -math.huge
			for i = 0, nx + 1 do
				local row = {}
				local infoRow = {}
				H[i] = row
				infos[i] = infoRow
				local x = baseX + (i - 1) * RES + RES / 2
				for k = 0, nz + 1 do
					local z = baseZ + (k - 1) * RES + RES / 2
					local h, info = hf:height(x, z)
					row[k] = h
					if i >= 1 and i <= nx and k >= 1 and k <= nz then
						infoRow[k] = info
						if h < minH then
							minH = h
						end
						if h > maxH then
							maxH = h
						end
					end
				end
			end

			local surface, sub, waterTop = {}, {}, {}
			for i = 1, nx do
				surface[i], sub[i], waterTop[i] = {}, {}, {}
				local x = baseX + (i - 1) * RES + RES / 2
				for k = 1, nz do
					local z = baseZ + (k - 1) * RES + RES / 2
					local h = H[i][k]
					local sx = (H[i + 1][k] - H[i - 1][k]) / (2 * RES)
					local sz = (H[i][k + 1] - H[i][k - 1]) / (2 * RES)
					local info = infos[i][k]
					surface[i][k] = enumMaterial(hf:material(x, z, h, math.sqrt(sx * sx + sz * sz), info))
					sub[i][k] = info.mountain > 0.3 and Enum.Material.Rock or Enum.Material.Ground
					waterTop[i][k] = info.water and waterLevel or nil
				end
			end

			local yMin = math.floor((minH - 10) / RES) * RES
			local yMax = math.ceil((math.max(maxH, waterLevel) + 2) / RES) * RES
			local ny = (yMax - yMin) / RES

			local materials, occupancy = {}, {}
			for i = 1, nx do
				local mi, oi = {}, {}
				materials[i], occupancy[i] = mi, oi
				for j = 1, ny do
					local mj, oj = {}, {}
					mi[j], oi[j] = mj, oj
					local yb = yMin + (j - 1) * RES
					for k = 1, nz do
						local h = H[i][k]
						local fill = (h - yb) / RES
						local top = waterTop[i][k]
						if fill >= 1 then
							mj[k] = (h - yb) < 2 * RES and surface[i][k] or sub[i][k]
							oj[k] = 1
						elseif fill > 0 then
							if top and yb < top and fill < 0.5 then
								mj[k] = WATER
								oj[k] = math.min(1, (top - yb) / RES)
							else
								mj[k] = surface[i][k]
								oj[k] = math.max(fill, 0.08)
							end
						elseif top and yb < top then
							mj[k] = WATER
							oj[k] = math.min(1, (top - yb) / RES)
						else
							mj[k] = AIR
							oj[k] = 0
						end
					end
				end
			end

			local region = Region3.new(
				Vector3.new(baseX, yMin, baseZ),
				Vector3.new(baseX + nx * RES, yMax, baseZ + nz * RES)
			)
			terrain:WriteVoxels(region, RES, materials, occupancy)
			stats.chunks += 1
			stats.voxels += nx * ny * nz
			Env.yield()
		end
	end
	return stats
end

return TerrainGenerator
