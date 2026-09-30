--[[
	MilitaryBase — Objective A "Fort Harlow"
	Fenced installation: barracks row, command post, vaulted hangar,
	warehouses, motor pool, fuel depot, container yard, watchtowers, gates.
]]

local Kit = require(script.Parent.Parent.Kit)
local Props = require(script.Parent.Parent.Props)
local Structures = require(script.Parent.Parent.Structures)

local MilitaryBase = {}

function MilitaryBase.build(ctx, rng)
	local site = ctx.plan.sites.MilitaryBase
	local folder = Kit.model(ctx.map, "FortHarlow")
	local barracks = 0
	for _, s in ipairs(site.Structures) do
		if s.Type == "Barracks" then
			barracks += 1
			s.Label = tostring(barracks)
		end
		Structures.build(ctx, folder, s, rng)
	end
	local y = ctx.hf:groundAt(site.X, site.Z)
	local cf = CFrame.new(site.X, y, site.Z)
	-- Gates: boom barriers across the roads.
	Props.boomGate(folder, cf * CFrame.new(116, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), 18)
	Props.boomGate(folder, cf * CFrame.new(20, 0, -96), 18)
	Props.boomGate(folder, cf * CFrame.new(20, 0, 96), 18)
	Kit.sign(folder, cf * CFrame.new(122, 9, 14) * CFrame.Angles(0, -math.pi / 2, 0), 16, 2.4, "FORT HARLOW", Color3.fromRGB(52, 58, 44), Color3.fromRGB(226, 222, 200))
	for _, p in ipairs({ { 122, 14 }, { 122, 26 } }) do
		Kit.box(folder, cf * CFrame.new(p[1], 4, p[2] - 6), 0.6, 8, 0.6, Enum.Material.Metal, Props.Colors.Steel)
	end
	-- Jersey barriers channel traffic at the east gate; lamps around the parade ground.
	for i = 0, 2 do
		Props.jerseyBarrier(folder, cf * CFrame.new(96 - i * 11, 0, 12))
		Props.jerseyBarrier(folder, cf * CFrame.new(96 - i * 11, 0, -12))
	end
	for _, p in ipairs({ { -42, -34 }, { 42, -34 }, { -42, 34 }, { 42, 34 } }) do
		Props.lampPost(folder, cf * CFrame.new(p[1], 0, p[2]))
	end
	for _, p in ipairs({ { -20, -36 }, { 20, -36 } }) do
		Props.crateStack(folder, cf * CFrame.new(p[1], 0, p[2]), rng)
	end
	Props.barrelGroup(folder, cf * CFrame.new(70, 0, -26), rng, 6)
	Props.generator(folder, cf * CFrame.new(78, 0, 48))
	Props.sandbags(folder, cf * CFrame.new(-60, 0, 24) * CFrame.Angles(0, math.rad(90), 0), 10, rng)
	Props.sandbags(folder, cf * CFrame.new(60, 0, -12) * CFrame.Angles(0, math.rad(90), 0), 10, rng)
	return folder
end

return MilitaryBase
