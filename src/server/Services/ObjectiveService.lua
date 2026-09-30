--[[
	ObjectiveService
	Runs the authoritative capture simulation for every zone and mirrors state to
	GameState.Zones attributes + the in-world flag visuals.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local CaptureLogic = require(Shared.Logic.CaptureLogic)
local Signal = require(Shared.Util.Signal)
local toColor = require(Shared.Util.Color)

local GameState = require(script.Parent.Parent.GameState)
local TeamService = require(script.Parent.TeamService)

local ObjectiveService = {}

-- (zoneId, kind "Captured"|"Neutralized", teamId, playersOfTeamInZone)
ObjectiveService.ZoneChanged = Signal.new()

local zones = {} -- ordered list of { def, state, config (Configuration), visuals }
local neutralColor = Color3.fromRGB(200, 200, 200)
local capCfg = GameConfig.Capture

local function teamColor(teamId)
	local cfg = teamId and TeamService.getConfig(teamId)
	return cfg and toColor(cfg.UiColor) or neutralColor
end

local function publish(zone)
	local state, config = zone.state, zone.config
	config:SetAttribute("Owner", state.owner or "")
	config:SetAttribute("Control", math.floor(state.control * 100 + 0.5) / 100)
	config:SetAttribute("Contested", state.contested)
	config:SetAttribute("Capturing", state.capturingTeam or "")
	local visuals = zone.visuals
	if visuals then
		local color = teamColor(state.owner)
		if visuals.Flag then
			visuals.Flag.Color = color
		end
		if visuals.Ring then
			visuals.Ring.Color = color
		end
	end
end

-- zoneDefs: MapLayout.Zones; visualsById: { [zoneId] = { Flag = Part, Ring = Part } }
function ObjectiveService.init(zoneDefs, visualsById)
	for _, def in ipairs(zoneDefs) do
		local config = Instance.new("Configuration")
		config.Name = def.Id
		config:SetAttribute("Name", def.Name)
		config:SetAttribute("Position", Vector3.new(def.Position[1], def.Position[2], def.Position[3]))
		config:SetAttribute("Radius", def.Radius)
		config.Parent = GameState.Zones
		local zone = {
			def = def,
			state = CaptureLogic.newState(),
			config = config,
			visuals = visualsById[def.Id],
			center = Vector3.new(def.Position[1], def.Position[2], def.Position[3]),
		}
		table.insert(zones, zone)
		publish(zone)
	end

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < capCfg.TickSeconds then
			return
		end
		local step = accumulator
		accumulator = 0
		if GameState.isActive() then
			ObjectiveService._tick(step)
		end
	end)
end

local function collectOccupants()
	-- Single pass over players: O(players * zones), fine for 80 players x 3 zones.
	local occupants = {}
	for _, zone in ipairs(zones) do
		occupants[zone] = {}
	end
	for _, player in ipairs(Players:GetPlayers()) do
		local teamId = TeamService.getTeamId(player)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if teamId and root and humanoid and humanoid.Health > 0 then
			local pos = root.Position
			for _, zone in ipairs(zones) do
				local offset = pos - zone.center
				local flat = Vector3.new(offset.X, 0, offset.Z).Magnitude
				if flat <= zone.def.Radius and math.abs(offset.Y) <= capCfg.HeightTolerance then
					local list = occupants[zone][teamId]
					if not list then
						list = {}
						occupants[zone][teamId] = list
					end
					table.insert(list, player)
				end
			end
		end
	end
	return occupants
end

function ObjectiveService._tick(dt)
	local ids = TeamService.getTeamIds()
	local teamA, teamB = ids[1], ids[2]
	local occupants = collectOccupants()
	for _, zone in ipairs(zones) do
		local inZone = occupants[zone]
		local a, b = inZone[teamA] or {}, inZone[teamB] or {}
		local newState, events = CaptureLogic.step(zone.state, teamA, teamB, #a, #b, dt, capCfg)
		local changed = newState.owner ~= zone.state.owner
			or newState.contested ~= zone.state.contested
			or newState.capturingTeam ~= zone.state.capturingTeam
			or math.abs(newState.control - zone.state.control) >= 0.005
		zone.state = newState
		if changed then
			publish(zone)
		end
		for _, event in ipairs(events) do
			ObjectiveService.ZoneChanged:Fire(zone.def.Id, event.kind, event.team, inZone[event.team] or {})
		end
	end
end

function ObjectiveService.getOwnedCounts()
	local owned = {}
	for _, zone in ipairs(zones) do
		local owner = zone.state.owner
		if owner then
			owned[owner] = (owned[owner] or 0) + 1
		end
	end
	return owned, #zones
end

function ObjectiveService.reset()
	for _, zone in ipairs(zones) do
		zone.state = CaptureLogic.newState()
		publish(zone)
	end
end

return ObjectiveService
