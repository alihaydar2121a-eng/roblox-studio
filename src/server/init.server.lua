--[[
	OPERATION IRONFRONT — server bootstrap.
	Order: networking + state + player-facing services first (so early team
	requests are handled), then the battlefield (baked or generated), then
	objectives and the match loop.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(script.Net)
local GameState = require(script.GameState)
local TeamService = require(script.Services.TeamService)
local CombatService = require(script.Services.CombatService)
local SpawnService = require(script.Services.SpawnService)
local ObjectiveService = require(script.Services.ObjectiveService)
local MatchService = require(script.Services.MatchService)
local MapBuilder = require(script.World.MapBuilder)
local MapLayout = require(ReplicatedStorage:WaitForChild("Shared").Config.MapLayout)

Net.init()
GameState.init()
GameState.set("MapStatus", "Loading")
TeamService.init()
CombatService.init()
SpawnService.init()
MatchService.init()

local started = os.clock()
local ok, meta, source = pcall(MapBuilder.ensure)
if not ok then
	GameState.set("MapStatus", "Failed")
	error("[Ironfront] battlefield generation failed: " .. tostring(meta))
end
-- Publish the measured WedgePart orientation for client-side gear/weapon builders.
local Kit = require(script.World.Kit)
if not Kit.orientation.calibrated then
	Kit.calibrate(require(script.World.Env))
end
GameState.set("WedgeRise", Kit.orientation.wedgeRise)
print(("[Ironfront] battlefield ready (%s) in %.1fs"):format(source, os.clock() - started))
GameState.set("MapStatus", "Ready")

SpawnService.setSpawnPoints(meta.SpawnPoints)
local village = meta.Zones.B and meta.Zones.B.Center
SpawnService.setDeployFocus((village or Vector3.new(40, 12, 20)) + Vector3.new(0, 40, 0))
ObjectiveService.init(MapLayout.Zones, meta.Zones)
MatchService.start()

print("[Ironfront] Server ready")
