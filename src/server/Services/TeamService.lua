--[[
	TeamService
	Creates the two Roblox Teams and handles validated team-selection requests.
]]

local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local TeamLogic = require(Shared.Logic.TeamLogic)
local Signal = require(Shared.Util.Signal)
local Net = require(script.Parent.Parent.Net)

local TeamService = {}

TeamService.TeamAssigned = Signal.new() -- (player, teamId)

local teamById = {}
local teamIds = {}

function TeamService.getTeam(teamId)
	return teamById[teamId]
end

function TeamService.getTeamId(player)
	local team = player.Team
	if team and not player.Neutral then
		return team:GetAttribute("TeamId")
	end
	return nil
end

function TeamService.getTeamIds()
	return teamIds
end

function TeamService.getConfig(teamId)
	for _, def in ipairs(GameConfig.Teams) do
		if def.Id == teamId then
			return def
		end
	end
	return nil
end

local function counts(excluding)
	local result = {}
	for _, id in ipairs(teamIds) do
		result[id] = 0
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= excluding then
			local id = TeamService.getTeamId(player)
			if id then
				result[id] += 1
			end
		end
	end
	return result
end

local function isAlive(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

function TeamService.assign(player, teamId)
	local team = teamById[teamId]
	player.Neutral = false
	player.Team = team
	TeamService.TeamAssigned:Fire(player, teamId)
end

local function onRequestTeam(player, requested)
	if type(requested) ~= "string" then
		return
	end
	-- Switching while alive would allow instant repositioning; only allow while unassigned or dead.
	if TeamService.getTeamId(player) ~= nil and isAlive(player) then
		Net.fire("Notify", player, "You can switch teams while respawning.", "Info")
		return
	end
	local current = counts(player)
	local target
	if requested == "Auto" then
		target = TeamLogic.pickAuto(current, teamIds)
	elseif teamById[requested] then
		target = requested
	else
		return
	end
	if target == TeamService.getTeamId(player) then
		return
	end
	if not TeamLogic.canJoin(current, target, GameConfig.TeamBalanceMaxDifference) then
		Net.fire("Notify", player, "That team is full. Try the other side.", "Warning")
		return
	end
	TeamService.assign(player, target)
end

function TeamService.init()
	for _, def in ipairs(GameConfig.Teams) do
		local team = Instance.new("Team")
		team.Name = def.Name
		team.TeamColor = BrickColor.new(def.TeamColorName)
		team.AutoAssignable = false
		team:SetAttribute("TeamId", def.Id)
		team.Parent = Teams
		teamById[def.Id] = team
		table.insert(teamIds, def.Id)
	end
	Net.on("RequestTeam", { burst = 3, perSecond = 1 }, onRequestTeam)
end

return TeamService
