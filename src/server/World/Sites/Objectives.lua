--[[
	Objectives
	Capture point markers: stone plinth, flag pole, flag and ground ring. The
	folder carries a Center attribute (resolved ground position) which the
	ObjectiveService uses; Flag and Ring are recoloured by the owner.
]]

local Kit = require(script.Parent.Parent.Kit)

local Objectives = {}

local M = Enum.Material
local rgb = Color3.fromRGB

function Objectives.build(ctx)
	local root = Instance.new("Folder")
	root.Name = "Objectives"
	root.Parent = ctx.map
	for _, zone in ipairs(ctx.layout.Zones) do
		local x, z = zone.Position[1], zone.Position[2]
		local y = ctx.hf:groundAt(x, z)
		local folder = Instance.new("Model")
		folder.Name = "Objective_" .. zone.Id
		folder.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		folder:SetAttribute("Center", Vector3.new(x, y, z))
		folder:SetAttribute("Radius", zone.Radius)
		folder:SetAttribute("ZoneName", zone.Name)
		local center = CFrame.new(x, y, z)
		Kit.part(folder, center * CFrame.new(0, 0.08, 0) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(0.12, zone.Radius * 2, zone.Radius * 2),
			M.SmoothPlastic, rgb(200, 200, 200), { Shape = Enum.PartType.Cylinder, Transparency = 0.82, Decor = true, NoShadow = true, Name = "Ring" })
		-- Plinth
		Kit.box(folder, center * CFrame.new(0, 0.5, 0), 5, 1, 5, M.Slate, rgb(110, 108, 104))
		Kit.box(folder, center * CFrame.new(0, 1.3, 0), 3.4, 0.6, 3.4, M.Slate, rgb(126, 124, 120))
		Kit.column(folder, center.Position + Vector3.new(0, 1.6, 0), 24, 0.5, M.Metal, rgb(180, 180, 184), { Name = "Pole" })
		Kit.box(folder, center * CFrame.new(0, 21.6, 3.3), 0.15, 3.8, 6.2, M.Fabric, rgb(200, 200, 200), { Decor = true, Name = "Flag" })
		Kit.ball(folder, center.Position + Vector3.new(0, 25.8, 0), 0.8, M.Metal, rgb(200, 180, 110), { Decor = true })
		folder.Parent = root
	end
	return root
end

return Objectives
