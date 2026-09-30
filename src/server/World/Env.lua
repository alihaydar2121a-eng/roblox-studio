--[[
	Env
	The only place the world builders touch engine services directly. Keeping
	this seam small lets tests/harness.luau run the complete generator under
	Lune (with real Roblox datatypes) by substituting a mock Env.
]]

local RunService = game:GetService("RunService")

local Env = {}

Env.Workspace = workspace
Env.Terrain = workspace.Terrain
Env.Lighting = game:GetService("Lighting")

local terrainParams = RaycastParams.new()
terrainParams.FilterType = Enum.RaycastFilterType.Include
terrainParams.FilterDescendantsInstances = { workspace.Terrain }
terrainParams.IgnoreWater = true

function Env.raycast(origin, direction, params)
	return workspace:Raycast(origin, direction, params)
end

-- Exact rendered terrain surface height at (x, z), or nil if nothing was hit.
function Env.terrainY(x, z)
	local result = workspace:Raycast(Vector3.new(x, 600, z), Vector3.new(0, -1200, 0), terrainParams)
	return result and result.Position.Y or nil
end

local sliceStart = os.clock()
-- Cooperative yielding so long generation never trips script timeouts or
-- freezes a running server; cheap to call often.
function Env.yield()
	if os.clock() - sliceStart > 0.03 then
		task.wait()
		sliceStart = os.clock()
	end
end

function Env.waitFrame()
	task.wait()
end

function Env.isRunning()
	return RunService:IsRunning()
end

function Env.log(message)
	print("[MapBuilder] " .. message)
end

return Env
