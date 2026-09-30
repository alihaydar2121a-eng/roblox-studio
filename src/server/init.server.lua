--[[
	OPERATION IRONFRONT — server bootstrap.
	Initialisation order matters: networking and state first, then the world,
	then gameplay services, then the match loop.
]]

local Net = require(script.Net)
local GameState = require(script.GameState)
local MapBuilder = require(script.World.MapBuilder)
local TeamService = require(script.Services.TeamService)
local CombatService = require(script.Services.CombatService)
local SpawnService = require(script.Services.SpawnService)
local ObjectiveService = require(script.Services.ObjectiveService)
local MatchService = require(script.Services.MatchService)
local MapLayout = require(game:GetService("ReplicatedStorage").Shared.Config.MapLayout)

Net.init()
GameState.init()

local world = MapBuilder.build()

TeamService.init()
CombatService.init()
SpawnService.setSpawnPoints(world.SpawnPoints)
SpawnService.init()
ObjectiveService.init(MapLayout.Zones, world.ZoneVisuals)
MatchService.init()
MatchService.start()

print("[Ironfront] Server ready")
