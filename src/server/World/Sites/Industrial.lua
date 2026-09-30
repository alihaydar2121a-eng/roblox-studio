--[[
	Industrial — Objective C "Kessler Works"
	Walled plant: two warehouses with mezzanines (one with roof access),
	maintenance shop with external stair, tank farm with catwalks, silos and
	conveyor, chimney stack, climbable container stacks under a gantry crane.
]]

local Kit = require(script.Parent.Parent.Kit)
local Props = require(script.Parent.Parent.Props)
local Structures = require(script.Parent.Parent.Structures)

local Industrial = {}

function Industrial.build(ctx, rng)
	local site = ctx.plan.sites.Industrial
	local folder = Kit.model(ctx.map, "KesslerWorks")
	for _, s in ipairs(site.Structures) do
		Structures.build(ctx, folder, s, rng)
	end
	local y = ctx.hf:groundAt(site.X, site.Z)
	local cf = CFrame.new(site.X, y, site.Z)
	Props.boomGate(folder, cf * CFrame.new(-116, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), 18)
	Kit.sign(folder, cf * CFrame.new(-122, 9, -14) * CFrame.Angles(0, math.pi / 2, 0), 16, 2.4, "KESSLER WORKS", Color3.fromRGB(40, 60, 90), Color3.fromRGB(236, 236, 230))
	for _, p in ipairs({ { -122, -8 }, { -122, -20 } }) do
		Kit.box(folder, cf * CFrame.new(p[1], 4, p[2]), 0.6, 8, 0.6, Enum.Material.Metal, Props.Colors.Steel)
	end
	-- Yard clutter: spools, pallets, barrels, tyres and floodlights.
	local spots = { { -30, -30 }, { 26, 26 }, { -8, 36 }, { 30, -38 }, { -44, 16 }, { 8, -30 } }
	for i, p in ipairs(spots) do
		local at = cf * CFrame.new(p[1], 0, p[2]) * CFrame.Angles(0, rng:range(0, 6.28), 0)
		if i % 3 == 0 then
			Props.cableSpool(folder, at)
		elseif i % 3 == 1 then
			Props.barrelGroup(folder, at, rng, 3)
		else
			Props.pallet(folder, at)
			Props.crate(folder, at * CFrame.new(0, 0.6, 0), 3.4)
		end
	end
	Props.tires(folder, cf * CFrame.new(-70, 0, -30))
	for _, p in ipairs({ { -60, -36 }, { 60, 36 }, { -20, 30 }, { 40, -20 } }) do
		Props.lampPost(folder, cf * CFrame.new(p[1], 0, p[2]))
	end
	Props.jerseyBarrier(folder, cf * CFrame.new(-80, 0, 12))
	Props.jerseyBarrier(folder, cf * CFrame.new(-80, 0, -12))
	return folder
end

return Industrial
