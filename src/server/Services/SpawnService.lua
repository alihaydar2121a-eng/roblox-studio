--[[
	SpawnService
	Owns character lifecycle: spawning at team bases, spawn protection,
	respawn timers and uniform/loadout application.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)

local GameState = require(script.Parent.Parent.GameState)
local TeamService = require(script.Parent.TeamService)
local UniformService = require(script.Parent.UniformService)
local CombatService = require(script.Parent.CombatService)

local SpawnService = {}

local spawnPoints = {} -- teamId -> { CFrame }
local spawnTokens = {} -- player -> number, invalidates stale respawn timers
local rng = Random.new()

function SpawnService.setSpawnPoints(points)
	spawnPoints = points
end

local function pickSpawn(teamId)
	local list = spawnPoints[teamId]
	if not list or #list == 0 then
		return CFrame.new(0, 20, 0)
	end
	return list[rng:NextInteger(1, #list)]
end

local function warnIfNotR6(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.RigType ~= Enum.HumanoidRigType.R6 then
		warn("[SpawnService] Character is not R6. Set Game Settings > Avatar > Avatar Type to R6.")
	end
end

function SpawnService.spawn(player)
	local teamId = TeamService.getTeamId(player)
	if not teamId or player.Parent ~= Players then
		return
	end
	local token = (spawnTokens[player] or 0) + 1
	spawnTokens[player] = token
	player:SetAttribute("RespawnAt", nil)

	local teamConfig = TeamService.getConfig(teamId)
	local description = UniformService.getDescription(player, teamConfig)
	if spawnTokens[player] ~= token or player.Parent ~= Players then
		return -- a newer spawn request superseded this one while the description loaded
	end
	player:LoadCharacterWithHumanoidDescription(description)

	local character = player.Character
	if not character or spawnTokens[player] ~= token then
		return
	end
	warnIfNotR6(character)
	UniformService.applyGear(character, teamConfig)
	character:PivotTo(pickSpawn(teamId) + Vector3.new(0, 3, 0))

	local forceField = Instance.new("ForceField")
	forceField.Visible = true
	forceField.Parent = character
	task.delay(GameConfig.Respawn.SpawnProtectionSeconds, function()
		forceField:Destroy()
	end)

	CombatService.equipLoadout(player, character)
end

function SpawnService.scheduleRespawn(player, delaySeconds)
	local token = (spawnTokens[player] or 0) + 1
	spawnTokens[player] = token
	player:SetAttribute("RespawnAt", workspace:GetServerTimeNow() + delaySeconds)
	task.delay(delaySeconds, function()
		if spawnTokens[player] == token and GameState.isActive() then
			SpawnService.spawn(player)
		end
	end)
end

function SpawnService.respawnAll()
	for _, player in ipairs(Players:GetPlayers()) do
		if TeamService.getTeamId(player) then
			task.spawn(SpawnService.spawn, player)
		end
	end
end

function SpawnService.init()
	TeamService.TeamAssigned:Connect(function(player)
		if GameState.isActive() then
			local character = player.Character
			if character then
				character:Destroy()
			end
			SpawnService.scheduleRespawn(player, 1)
		end
	end)
	CombatService.CharacterDied:Connect(function(player)
		if GameState.isActive() then
			SpawnService.scheduleRespawn(player, GameConfig.Respawn.DelaySeconds)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		spawnTokens[player] = nil
	end)
end

return SpawnService
