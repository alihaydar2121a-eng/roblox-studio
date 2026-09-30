--[[
	SpawnService
	Owns character lifecycle: spawning at team bases, spawn protection,
	respawn timers and uniform/loadout application.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local MapLayout = require(Shared.Config.MapLayout)

local GameState = require(script.Parent.Parent.GameState)
local TeamService = require(script.Parent.TeamService)
local UniformService = require(script.Parent.UniformService)
local CombatService = require(script.Parent.CombatService)

local SpawnService = {}

local spawnPoints = {} -- teamId -> { CFrame }
local deployFocus = nil -- streaming focus for players on the deploy screen
local spawnTokens = {} -- player -> number, invalidates stale respawn timers
local rng = Random.new()

function SpawnService.setSpawnPoints(points)
	spawnPoints = points
end

--[[
	Players without a character have no streaming focus, so the deploy-screen
	camera would look at an area that never streamed in (the "sky only" bug).
	Point their ReplicationFocus at an anchored marker over the battlefield.
]]
function SpawnService.setDeployFocus(position)
	if not deployFocus then
		deployFocus = Instance.new("Part")
		deployFocus.Name = "DeployFocus"
		deployFocus.Anchored = true
		deployFocus.CanCollide = false
		deployFocus.CanQuery = false
		deployFocus.CanTouch = false
		deployFocus.Transparency = 1
		deployFocus.Size = Vector3.one
		deployFocus.Parent = workspace
	end
	deployFocus.Position = position
	for _, player in ipairs(Players:GetPlayers()) do
		if not player.Character then
			player.ReplicationFocus = deployFocus
		end
	end
end

local function focusDeploy(player)
	if deployFocus and player.Parent == Players then
		player.ReplicationFocus = deployFocus
	end
end

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include

-- Random free spawn point (no character within 4 studs), falling back to any.
local function pickSpawn(teamId)
	local list = spawnPoints[teamId]
	if not list or #list == 0 then
		warn("[SpawnService] no spawn points for team " .. tostring(teamId))
		return CFrame.new(0, 60, 0)
	end
	local free = {}
	for _, cf in ipairs(list) do
		local occupied = false
		for _, other in ipairs(Players:GetPlayers()) do
			local root = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
			if root and (root.Position - cf.Position).Magnitude < 4 then
				occupied = true
				break
			end
		end
		if not occupied then
			table.insert(free, cf)
		end
	end
	local pool = #free > 0 and free or list
	return pool[rng:NextInteger(1, #pool)]
end

-- Snap a spawn frame onto whatever is below it (terrain or map geometry).
local function groundedSpawn(cf)
	local filter = { workspace.Terrain }
	local map = workspace:FindFirstChild("Map")
	if map then
		table.insert(filter, map)
	end
	groundParams.FilterDescendantsInstances = filter
	local hit = workspace:Raycast(cf.Position + Vector3.new(0, 12, 0), Vector3.new(0, -40, 0), groundParams)
	local y = hit and hit.Position.Y or cf.Position.Y
	return CFrame.new(cf.Position.X, y, cf.Position.Z) * cf.Rotation
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
	local spawnCf = groundedSpawn(pickSpawn(teamId))
	-- Make sure the client has the spawn area streamed in before the character lands.
	pcall(function()
		player:RequestStreamAroundAsync(spawnCf.Position, 5)
	end)
	if spawnTokens[player] ~= token or player.Parent ~= Players then
		return -- a newer spawn request superseded this one while we yielded
	end
	player:LoadCharacterWithHumanoidDescription(description)

	local character = player.Character
	if not character or spawnTokens[player] ~= token then
		return
	end
	warnIfNotR6(character)
	player.ReplicationFocus = nil -- stream around the character again
	UniformService.applyGear(character, teamConfig, player)
	character:PivotTo(spawnCf + Vector3.new(0, 3.2, 0))

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
	Players.PlayerAdded:Connect(focusDeploy)
	CombatService.CharacterDied:Connect(function(player)
		if GameState.isActive() then
			SpawnService.scheduleRespawn(player, GameConfig.Respawn.DelaySeconds)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		spawnTokens[player] = nil
	end)
	-- Out-of-bounds guard: below the kill height or past the boundary walls.
	task.spawn(function()
		local limit = MapLayout.HalfSize + 30
		while true do
			task.wait(0.5)
			for _, player in ipairs(Players:GetPlayers()) do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if root and humanoid and humanoid.Health > 0 then
					local p = root.Position
					if p.Y < MapLayout.KillHeight or math.abs(p.X) > limit or math.abs(p.Z) > limit then
						humanoid.Health = 0
					end
				end
			end
		end
	end)
end

return SpawnService
