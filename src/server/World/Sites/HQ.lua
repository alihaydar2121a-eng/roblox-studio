--[[
	HQ
	Team headquarters: fortified camp, spawn apron with persisted spawn points.
	Spawn points are saved as invisible parts under Map.SpawnPoints (attribute
	Team) so a baked map carries them with it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.GameConfig)
local toColor = require(ReplicatedStorage.Shared.Util.Color)

local Kit = require(script.Parent.Parent.Kit)
local Props = require(script.Parent.Parent.Props)
local Structures = require(script.Parent.Parent.Structures)

local HQ = {}

local function teamConfig(teamId)
	for _, def in ipairs(GameConfig.Teams) do
		if def.Id == teamId then
			return def
		end
	end
	return nil
end

function HQ.build(ctx, rng)
	local spawnFolder = Instance.new("Folder")
	spawnFolder.Name = "SpawnPoints"
	spawnFolder.Parent = ctx.map
	for teamId, hq in pairs(ctx.plan.hqs) do
		local def = teamConfig(teamId)
		local folder = Kit.model(ctx.map, "HQ_" .. teamId)
		for _, s in ipairs(hq.Structures) do
			if s.Type == "TeamFlag" then
				local cf = Structures.frameFor(ctx, s)
				local model = Kit.model(folder, "TeamFlag")
				Props.flag(model, cf, toColor(def.UiColor), 26)
			elseif s.Type == "Tent" then
				s.Color = toColor(def.Uniform.Torso)
				Structures.build(ctx, folder, s, rng)
			else
				Structures.build(ctx, folder, s, rng)
			end
		end
		local accent = toColor(def.Uniform.Band)
		for index, sp in ipairs(hq.Spawns) do
			local y = ctx.hf:groundAt(sp.X, sp.Z)
			local cf = CFrame.new(sp.X, y, sp.Z) * CFrame.Angles(0, math.rad(sp.Yaw), 0)
			local marker = Kit.part(spawnFolder, cf * CFrame.new(0, 0.5, 0), Vector3.new(4, 1, 4), Enum.Material.SmoothPlastic, accent,
				{ Transparency = 1, Decor = true, NoShadow = true, Name = "Spawn" })
			marker.CanCollide = false
			marker:SetAttribute("Team", teamId)
			marker:SetAttribute("Index", index)
			-- Visible pad marking
			Kit.box(folder, cf * CFrame.new(0, 0.06, 0), 4.2, 0.12, 4.2, Enum.Material.Concrete, accent:Lerp(Color3.new(0.5, 0.5, 0.5), 0.35), { Decor = true, NoShadow = true, Name = "SpawnPad" })
		end
		-- Jersey barriers either side of the gate and lights around the apron.
		local gate = CFrame.new(hq.X, ctx.hf:groundAt(hq.X, hq.Z), hq.Z) * CFrame.Angles(0, math.rad(hq.Yaw), 0)
		for side = -1, 1, 2 do
			Props.jerseyBarrier(folder, gate * CFrame.new(side * 18, 0, -66) * CFrame.Angles(0, math.rad(side * 20), 0))
			Props.lampPost(folder, gate * CFrame.new(side * 36, 0, -2))
			Props.lampPost(folder, gate * CFrame.new(side * 36, 0, -34))
		end
		Kit.sign(folder, gate * CFrame.new(0, 8, -61), 16, 2.2, string.upper(def.Name) .. " HQ", Color3.fromRGB(40, 44, 40), toColor(def.UiColor))
		for side = -1, 1, 2 do
			Kit.box(folder, gate * CFrame.new(side * 8.6, 4.5, -61), 0.8, 9, 0.8, Enum.Material.Metal, Props.Colors.Steel)
		end
	end
	return spawnFolder
end

return HQ
