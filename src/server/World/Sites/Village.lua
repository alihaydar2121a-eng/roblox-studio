--[[
	Village — Objective B "Millbrook"
	18 buildings on a street grid round a cobbled plaza: clock-tower hall,
	tavern, shops, houses, cottages and barns, fenced back yards, lanes,
	market stalls, well, lamps, gardens and trees.
]]

local Kit = require(script.Parent.Parent.Kit)
local Props = require(script.Parent.Parent.Props)
local Structures = require(script.Parent.Parent.Structures)
local Foliage = require(script.Parent.Parent.Foliage)

local Village = {}

local rgb = Color3.fromRGB

local function yard(ctx, parent, entry, rng)
	local b = entry.Building
	local cf = Structures.frameFor(ctx, b)
	local w, d, depth = b.W, b.D, entry.Depth
	local style = rng:chance(0.5) and "Stone" or "Wood"
	local function pt(lx, lz)
		local p = cf:PointToWorldSpace(Vector3.new(lx, 0, lz))
		return Vector3.new(p.X, ctx.hf:groundAt(p.X, p.Z), p.Z)
	end
	local back = d / 2 + depth
	-- Back fence with a gate gap, and side fences.
	Props.fence(parent, pt(-w / 2, back), pt(-1.8, back), style)
	Props.fence(parent, pt(1.8, back), pt(w / 2, back), style)
	Props.fence(parent, pt(-w / 2, d / 2 + 0.6), pt(-w / 2, back), style)
	Props.fence(parent, pt(w / 2, d / 2 + 0.6), pt(w / 2, back), style)
	-- Yard contents
	local roll = rng:float()
	local inside = cf * CFrame.new(rng:range(-w / 4, w / 4), 0, d / 2 + depth / 2)
	if roll < 0.3 then
		local p = inside.Position
		Foliage.tree(parent, rng:chance(0.5) and "Oak" or "Birch", p.X, p.Z, p.Y, rng, 0.7)
	elseif roll < 0.5 then
		Props.cart(parent, inside * CFrame.Angles(0, math.rad(rng:range(60, 120)), 0))
	elseif roll < 0.7 then
		-- Vegetable beds
		for i = -1, 1 do
			Kit.box(parent, inside * CFrame.new(i * 2.4, 0.3, 0), 1.6, 0.6, math.max(2, depth - 3), Enum.Material.Mud, rgb(80, 64, 50), { Decor = true })
			Kit.box(parent, inside * CFrame.new(i * 2.4, 0.9, 0), 1.2, 0.6, math.max(1.5, depth - 3.5), Enum.Material.Grass, rgb(90, 130, 60), { Decor = true, NoShadow = true })
		end
	else
		Props.hayBale(parent, inside)
		Props.barrel(parent, inside * CFrame.new(3, 0, 0), rgb(96, 70, 50))
	end
end

function Village.build(ctx, rng)
	local site = ctx.plan.sites.Village
	local folder = Kit.model(ctx.map, "Millbrook")
	local buildings = Kit.model(folder, "Buildings")
	for _, b in ipairs(site.Buildings) do
		b.Name = b.Type .. (b.Sign and ("_" .. b.Sign) or "")
		Structures.build(ctx, buildings, b, rng)
	end
	local yards = Kit.model(folder, "Yards")
	for _, entry in ipairs(site.Yards) do
		yard(ctx, yards, entry, rng)
	end

	local y = ctx.hf:groundAt(site.X, site.Z)
	local center = CFrame.new(site.X, y, site.Z)
	local decor = Kit.model(folder, "Decor")
	for _, dItem in ipairs(site.Decor) do
		local cf = center * CFrame.new(dItem.LX, 0, dItem.LZ) * CFrame.Angles(0, math.rad(dItem.Yaw or 0), 0)
		if dItem.Type == "Well" then
			Props.well(decor, cf)
		elseif dItem.Type == "MarketStall" then
			Props.marketStall(decor, cf, rng:pick({ rgb(160, 70, 50), rgb(70, 100, 140), rgb(190, 150, 60), rgb(80, 120, 80) }))
		elseif dItem.Type == "LampPost" then
			Props.lampPost(decor, cf)
		elseif dItem.Type == "Bench" then
			Props.bench(decor, cf)
		end
	end
	-- Plaza trees and planters, orchard patches in the outer quadrants.
	for _, p in ipairs({ { 36, 36 }, { -38, -34 }, { 36, -36 }, { -38, 38 } }) do
		local c = center * CFrame.new(p[1], 0, p[2])
		Foliage.tree(decor, "Oak", c.X, c.Z, c.Y, rng, 0.75)
	end
	for _, x in ipairs({ 22, 26, -22, -26 }) do
		Props.planter(decor, center * CFrame.new(x, 0, 10.8), rng)
	end
	for _, quadrant in ipairs({ { 1, 1 }, { -1, -1 } }) do
		for r = 0, 2 do
			for c = 0, 1 do
				local lx = quadrant[1] * (60 + c * 10)
				local lz = quadrant[2] * (100 + r * 10)
				local p = center * CFrame.new(lx, 0, lz)
				local h, info = ctx.hf:height(p.X, p.Z)
				if info.roadD > 3 then
					Foliage.tree(decor, "Oak", p.X, p.Z, h, rng, 0.55)
				end
			end
		end
	end
	Kit.sign(decor, center * CFrame.new(-130, 5, 12) * CFrame.Angles(0, math.pi / 2, 0), 8, 1.6, "MILLBROOK", rgb(250, 248, 240), rgb(40, 40, 40))
	Kit.box(decor, center * CFrame.new(-130, 2.2, 12), 0.4, 4.4, 0.4, Enum.Material.Metal, Props.Colors.Steel)
	return folder
end

return Village
