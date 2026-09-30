--[[
	MatchService
	Owns the round: timer, tickets, bleed, scoring, leaderstats, victory and
	intermission/reset.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local TicketLogic = require(Shared.Logic.TicketLogic)

local Net = require(script.Parent.Parent.Net)
local GameState = require(script.Parent.Parent.GameState)
local TeamService = require(script.Parent.TeamService)
local CombatService = require(script.Parent.CombatService)
local ObjectiveService = require(script.Parent.ObjectiveService)
local SpawnService = require(script.Parent.SpawnService)

local MatchService = {}

local matchCfg = GameConfig.Match
local tickets = {}

local function stat(player, name)
	local leaderstats = player:FindFirstChild("leaderstats")
	return leaderstats and leaderstats:FindFirstChild(name)
end

local function addStat(player, name, amount)
	local value = stat(player, name)
	if value then
		value.Value += amount
	end
end

function MatchService.addScore(player, amount)
	addStat(player, "Score", amount)
end

local function publishTickets()
	for id, value in pairs(tickets) do
		GameState.set("Tickets_" .. id, math.max(0, math.ceil(value)))
	end
end

local function removeTickets(teamId, amount)
	if tickets[teamId] then
		tickets[teamId] = math.max(0, tickets[teamId] - amount)
	end
end

local function setupLeaderstats(player)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	for _, name in ipairs({ "Score", "Kills", "Deaths" }) do
		local value = Instance.new("IntValue")
		value.Name = name
		value.Parent = folder
	end
	folder.Parent = player
end

local function startRound()
	for _, id in ipairs(TeamService.getTeamIds()) do
		tickets[id] = matchCfg.StartingTickets
	end
	publishTickets()
	ObjectiveService.reset()
	for _, player in ipairs(Players:GetPlayers()) do
		for _, name in ipairs({ "Score", "Kills", "Deaths" }) do
			local value = stat(player, name)
			if value then
				value.Value = 0
			end
		end
	end
	GameState.set("Winner", "")
	GameState.set("EndsAt", workspace:GetServerTimeNow() + matchCfg.DurationSeconds)
	GameState.set("Phase", "Active")
	SpawnService.respawnAll()
end

local function endRound(winner)
	GameState.set("Phase", "Ended")
	GameState.set("Winner", winner)
	GameState.set("EndsAt", workspace:GetServerTimeNow() + matchCfg.IntermissionSeconds)
	-- Freeze combat: remove weapons so nobody keeps shooting during the scoreboard.
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		CombatService.disarm(player)
		if humanoid then
			humanoid.WalkSpeed = 0
		end
		player:SetAttribute("RespawnAt", nil)
	end
	task.delay(matchCfg.IntermissionSeconds, startRound)
end

local function onCharacterDied(victim, killer, _weaponId, headshot)
	addStat(victim, "Deaths", 1)
	local victimTeam = TeamService.getTeamId(victim)
	if victimTeam and GameState.isActive() then
		removeTickets(victimTeam, matchCfg.TicketLossPerDeath)
		publishTickets()
	end
	local killerTeam = killer and TeamService.getTeamId(killer)
	if killer and killer ~= victim then
		addStat(killer, "Kills", 1)
		MatchService.addScore(killer, GameConfig.Score.Kill + (headshot and GameConfig.Score.HeadshotBonus or 0))
	end
	Net.fireAll("KillFeed", {
		killer = killer and killer.DisplayName or nil,
		victim = victim.DisplayName,
		killerTeam = killerTeam,
		victimTeam = victimTeam,
		headshot = headshot == true,
	})
end

local function onZoneChanged(zoneId, kind, teamId, players)
	local reward = kind == "Captured" and GameConfig.Score.Capture or GameConfig.Score.Neutralize
	for _, player in ipairs(players) do
		MatchService.addScore(player, reward)
	end
	local teamCfg = TeamService.getConfig(teamId)
	local verb = kind == "Captured" and "captured" or "neutralized"
	Net.fireAll("Notify", ("%s %s objective %s"):format(teamCfg and teamCfg.Name or teamId, verb, zoneId), kind)
end

local function tick(dt)
	if not GameState.isActive() then
		return
	end
	local ids = TeamService.getTeamIds()
	local owned, total = ObjectiveService.getOwnedCounts()
	local rates = TicketLogic.bleedRates(owned, ids, total, matchCfg)
	for _, id in ipairs(ids) do
		removeTickets(id, rates[id] * dt)
	end
	publishTickets()
	local timeUp = workspace:GetServerTimeNow() >= (GameState.get("EndsAt") or 0)
	local winner = TicketLogic.resolveWinner(tickets, ids, timeUp)
	if winner then
		endRound(winner)
	end
end

function MatchService.init()
	Players.PlayerAdded:Connect(setupLeaderstats)
	for _, player in ipairs(Players:GetPlayers()) do
		setupLeaderstats(player)
	end
	CombatService.CharacterDied:Connect(onCharacterDied)
	ObjectiveService.ZoneChanged:Connect(onZoneChanged)
end

function MatchService.start()
	startRound()
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(1)
			local now = os.clock()
			tick(now - last)
			last = now
		end
	end)
end

return MatchService
