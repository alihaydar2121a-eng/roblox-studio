--[[
	Foliage
	Tree species built from primitives, plus bushes, rocks, logs and puddles,
	scattered over the heightfield with a deterministic jittered grid.

	Species: Spruce (layered corner-wedge pyramids), Pine (tall, crown only),
	Oak (branching trunk + clustered canopy), Birch (pale trunk, light canopy),
	Snag (dead tree). Canopies don't collide or block bullets; trunks do.
]]

local Kit = require(script.Parent.Kit)
local Rng = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Util.Rng)

local Foliage = {}

local M = Enum.Material
local rgb = Color3.fromRGB

local LEAF = { Decor = true, Name = "Foliage" }
local LEAF_NOSHADOW = { Decor = true, NoShadow = true, Name = "Foliage" }

local function vary(color, rng, amount)
	local k = rng:range(-amount, amount)
	return Color3.new(math.clamp(color.R + k, 0, 1), math.clamp(color.G + k * 1.2, 0, 1), math.clamp(color.B + k * 0.6, 0, 1))
end

local function trunk(model, base, height, diameter, color, lean)
	local top = base + Vector3.new(lean.X, height, lean.Z)
	Kit.cylinder(model, base - Vector3.new(0, 1.5, 0), top, diameter, M.Wood, color, { Name = "Trunk" })
	return top
end

function Foliage.spruce(model, base, rng, scale)
	scale = scale or 1
	local h = rng:range(15, 22) * scale
	local lean = Vector3.new(rng:range(-0.4, 0.4), 0, rng:range(-0.4, 0.4))
	trunk(model, base, h * 0.75, rng:range(1.3, 1.9) * scale, rgb(84, 64, 50), lean)
	local color = vary(rgb(44, 74, 50), rng, 0.035)
	local size = rng:range(11, 14) * scale
	local y = base.Y + 2.2 * scale
	for tier = 0, 2 do
		local s = size * (1 - 0.27 * tier)
		local th = s * 0.95
		local yaw = tier % 2 == 0 and math.rad(45) or 0
		local cf = CFrame.new(base.X + lean.X * tier * 0.3, y, base.Z + lean.Z * tier * 0.3) * CFrame.Angles(0, yaw + rng:range(-0.2, 0.2), 0)
		Kit.pyramid(model, cf, s, th, M.Grass, tier == 2 and vary(color, rng, 0.02) or color, tier == 0 and LEAF or LEAF_NOSHADOW)
		y += th * 0.52
	end
end

function Foliage.pine(model, base, rng, scale)
	scale = scale or 1
	local h = rng:range(24, 32) * scale
	local lean = Vector3.new(rng:range(-0.8, 0.8), 0, rng:range(-0.8, 0.8))
	local top = trunk(model, base, h, rng:range(1.4, 2) * scale, rgb(104, 72, 52), lean)
	local color = vary(rgb(52, 82, 52), rng, 0.03)
	local s = rng:range(9, 11) * scale
	Kit.pyramid(model, CFrame.new(top - Vector3.new(0, 9 * scale, 0)) * CFrame.Angles(0, math.rad(rng:range(0, 90)), 0), s, s * 0.8, M.Grass, color, LEAF)
	Kit.pyramid(model, CFrame.new(top - Vector3.new(0, 3.5 * scale, 0)) * CFrame.Angles(0, math.rad(rng:range(0, 90)), 0), s * 0.7, s * 0.75, M.Grass, color, LEAF_NOSHADOW)
end

function Foliage.oak(model, base, rng, scale)
	scale = scale or 1
	local h = rng:range(8, 11) * scale
	local lean = Vector3.new(rng:range(-0.6, 0.6), 0, rng:range(-0.6, 0.6))
	local top = trunk(model, base, h, rng:range(2, 2.8) * scale, rgb(92, 72, 56), lean)
	local color = vary(rgb(82, 108, 56), rng, 0.04)
	local autumn = rng:chance(0.08)
	if autumn then
		color = vary(rgb(150, 116, 56), rng, 0.04)
	end
	for i = 1, 2 do
		local a = rng:range(0, math.pi * 2)
		local tip = top + Vector3.new(math.cos(a) * 4 * scale, rng:range(1, 3) * scale, math.sin(a) * 4 * scale)
		Kit.cylinder(model, top - Vector3.new(0, 2 * scale, 0), tip, 0.9 * scale, M.Wood, rgb(92, 72, 56), { Decor = true })
	end
	local blobs = rng:int(4, 5)
	for i = 1, blobs do
		local a = (i / blobs) * math.pi * 2 + rng:range(-0.3, 0.3)
		local r = rng:range(2.5, 4.5) * scale
		local size = rng:range(8, 12) * scale
		local p = top + Vector3.new(math.cos(a) * r, rng:range(1, 4) * scale, math.sin(a) * r)
		Kit.ball(model, p, size, M.Grass, vary(color, rng, 0.03), i == 1 and LEAF or LEAF_NOSHADOW)
	end
	Kit.ball(model, top + Vector3.new(0, 5 * scale, 0), rng:range(9, 12) * scale, M.Grass, vary(color, rng, 0.03), LEAF)
end

function Foliage.birch(model, base, rng, scale)
	scale = scale or 1
	local h = rng:range(13, 17) * scale
	local lean = Vector3.new(rng:range(-1, 1), 0, rng:range(-1, 1))
	local top = trunk(model, base, h, 1.1 * scale, rgb(214, 210, 198), lean)
	-- Dark bark bands
	for i = 1, 3 do
		local p = base:Lerp(top, i / 4)
		Kit.cylinder(model, p, p + Vector3.new(0, 0.35, 0), 1.2 * scale, M.Wood, rgb(60, 58, 56), { Decor = true, NoShadow = true })
	end
	local color = vary(rgb(120, 146, 72), rng, 0.04)
	for i = 1, 3 do
		local p = top + Vector3.new(rng:range(-2, 2) * scale, rng:range(-3, 2) * scale, rng:range(-2, 2) * scale)
		Kit.ball(model, p, rng:range(5.5, 7.5) * scale, M.Grass, vary(color, rng, 0.03), i == 1 and LEAF or LEAF_NOSHADOW)
	end
end

function Foliage.snag(model, base, rng)
	local h = rng:range(11, 16)
	local lean = Vector3.new(rng:range(-1.2, 1.2), 0, rng:range(-1.2, 1.2))
	local top = trunk(model, base, h, rng:range(1.3, 1.8), rgb(112, 104, 94), lean)
	for i = 1, 2 do
		local from = base:Lerp(top, rng:range(0.5, 0.85))
		local a = rng:range(0, math.pi * 2)
		Kit.cylinder(model, from, from + Vector3.new(math.cos(a) * 4, rng:range(2, 4), math.sin(a) * 4), 0.5, M.Wood, rgb(112, 104, 94), { Decor = true })
	end
end

function Foliage.bush(model, base, rng, scale)
	scale = scale or 1
	local color = vary(rgb(64, 92, 48), rng, 0.04)
	for i = 1, rng:int(2, 3) do
		local s = rng:range(3, 5.5) * scale
		Kit.ball(model, base + Vector3.new(rng:range(-1.5, 1.5), s * 0.3, rng:range(-1.5, 1.5)), s, M.Grass, vary(color, rng, 0.03), { Decor = true, NoShadow = true, Name = "Bush" })
	end
end

function Foliage.rocks(model, base, rng, big)
	local n = big and rng:int(2, 3) or rng:int(1, 2)
	local mats = { M.Rock, M.Slate, M.Basalt }
	for _ = 1, n do
		local s = (big and rng:range(5, 12) or rng:range(2, 5))
		local p = base + Vector3.new(rng:range(-s / 2, s / 2), s * 0.15, rng:range(-s / 2, s / 2))
		Kit.part(model, CFrame.new(p) * CFrame.Angles(rng:range(-0.5, 0.5), rng:range(0, 6.28), rng:range(-0.5, 0.5)),
			Vector3.new(s * rng:range(0.9, 1.6), s * rng:range(0.5, 0.9), s * rng:range(0.8, 1.3)), rng:pick(mats), vary(rgb(110, 108, 102), rng, 0.05), { Name = "Rock" })
	end
end

function Foliage.log(model, base, rng)
	local a = rng:range(0, math.pi * 2)
	local len = rng:range(10, 16)
	local dir = Vector3.new(math.cos(a), 0, math.sin(a))
	Kit.cylinder(model, base + Vector3.new(0, 0.7, 0), base + dir * len + Vector3.new(0, 0.9, 0), rng:range(1.4, 2), M.Wood, rgb(96, 78, 60), { Name = "Log" })
	Kit.column(model, base - dir * 2 - Vector3.new(0, 0.5, 0), 1.6, 2, M.Wood, rgb(96, 78, 60), { Name = "Stump" })
end

Foliage.Species = {
	Spruce = Foliage.spruce,
	Pine = Foliage.pine,
	Oak = Foliage.oak,
	Birch = Foliage.birch,
	Snag = Foliage.snag,
}

-- Places one tree (as an atomic streaming model) on the terrain surface.
function Foliage.tree(parent, species, x, z, y, rng, scale)
	local model = Instance.new("Model")
	model.Name = species
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	Foliage.Species[species](model, Vector3.new(x, y, z), rng, scale)
	model.Parent = parent
	return model
end

local function speciesFor(rng, h, info, density, hf)
	if rng:chance(0.025) then
		return "Snag"
	end
	if info.riverD < 40 then
		return rng:weighted({ { "Birch", 5 }, { "Oak", 3 }, { "Spruce", 1 } })
	end
	if h > 40 or info.mountain > 0.2 then
		return rng:weighted({ { "Spruce", 6 }, { "Pine", 4 }, { "Birch", 0.5 } })
	end
	if density > 0.6 then
		return rng:weighted({ { "Spruce", 4 }, { "Pine", 3 }, { "Oak", 2 }, { "Birch", 1 } })
	end
	return rng:weighted({ { "Oak", 4 }, { "Spruce", 2 }, { "Birch", 2 }, { "Pine", 1 } })
end

--[[
	scatter(ctx, parent) -> stats
	Deterministic: each grid cell derives its own Rng from (cell, seed).
]]
function Foliage.scatter(ctx, parent)
	local hf, layout, Env = ctx.hf, ctx.layout, ctx.Env
	local trees = Kit.model(parent, "Trees")
	local undergrowth = Kit.model(parent, "Undergrowth")
	local rocks = Kit.model(parent, "Rocks")
	local stats = { trees = 0, bushes = 0, rocks = 0, logs = 0 }
	local extent = layout.HalfSize + 60
	local cell = 15
	local seed = layout.Seed + 101

	local function surface(x, z, fallback)
		return Env.terrainY(x, z) or fallback
	end

	for i = math.floor(-extent / cell), math.floor(extent / cell) do
		for k = math.floor(-extent / cell), math.floor(extent / cell) do
			local rng = Rng.forCell(i, k, seed)
			local x = (i + rng:float()) * cell
			local z = (k + rng:float()) * cell
			local density = hf:forestDensity(x, z)
			local roll = rng:float()
			if roll < density * 0.62 then
				local ok, h, info = hf:isWild(x, z, 1)
				if ok and hf:slopeAt(x, z) < 0.85 then
					local species = speciesFor(rng, h, info, density, hf)
					Foliage.tree(trees, species, x, z, surface(x, z, h), rng, rng:range(0.85, 1.2))
					stats.trees += 1
					if density > 0.5 and rng:chance(0.05) then
						local model = Kit.model(undergrowth, "Log")
						local lx, lz = x + rng:range(-5, 5), z + rng:range(-5, 5)
						Foliage.log(model, Vector3.new(lx, surface(lx, lz, h), lz), rng)
						stats.logs += 1
					end
				end
			elseif roll < density * 0.62 + 0.035 + density * 0.12 then
				local ok, h = hf:isWild(x, z, 0)
				if ok then
					local model = Kit.model(undergrowth, "Bush")
					Foliage.bush(model, Vector3.new(x, surface(x, z, h), z), rng, rng:range(0.8, 1.3))
					stats.bushes += 1
				end
			end
			-- Rocks favour slopes and the mountain fringe.
			if rng:chance(0.012) then
				local ok, h, info = hf:isWild(x, z, 0)
				if ok then
					local slope = hf:slopeAt(x, z)
					if rng:chance(0.35 + math.min(slope, 1) * 0.5 + info.mountain * 0.5) then
						local model = Kit.model(rocks, "Rocks")
						Foliage.rocks(model, Vector3.new(x, surface(x, z, h), z), rng, slope > 0.4 or info.mountain > 0.3)
						stats.rocks += 1
					end
				end
			end
		end
		Env.yield()
	end
	return stats
end

-- Puddles along dirt roads.
function Foliage.puddles(ctx, parent)
	local hf, layout, Env = ctx.hf, ctx.layout, ctx.Env
	local Props = require(script.Parent.Props)
	local folder = Kit.model(parent, "Puddles")
	local rng = Rng.new(layout.Seed + 33)
	local count = 0
	for _, road in ipairs(layout.Roads) do
		if road.Material == "Ground" then
			for i = 1, #road.Points - 1 do
				local a, b = road.Points[i], road.Points[i + 1]
				local len = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
				for s = 10, len - 10, 22 do
					if rng:chance(0.3) then
						local t = s / len
						local off = rng:range(-road.Width * 0.3, road.Width * 0.3)
						local dx, dz = (b[1] - a[1]) / len, (b[2] - a[2]) / len
						local x = a[1] + (b[1] - a[1]) * t - dz * off
						local z = a[2] + (b[2] - a[2]) * t + dx * off
						local h, info = hf:height(x, z)
						if not info.water and info.riverD > 20 then
							local y = Env.terrainY(x, z) or h
							Props.puddle(folder, Vector3.new(x, y + 0.04, z), rng:range(3, 6))
							count += 1
						end
					end
				end
			end
		end
	end
	return count
end

return Foliage
