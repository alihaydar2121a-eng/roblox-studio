--[[
	Remotes
	Single source of truth for network endpoints. The server creates them
	(see ServerScriptService.Server.Net); clients look them up here.

	Direction key: C->S client to server, S->C server to client.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

Remotes.FolderName = "Remotes"

Remotes.Definitions = {
	RequestTeam = "RemoteEvent", -- C->S (teamId | "Auto")
	Fire = "RemoteEvent", -- C->S { o = Vector3 origin, d = Vector3 unit direction }
	Reload = "RemoteEvent", -- C->S ()
	HitConfirm = "RemoteEvent", -- S->C { headshot, killed }
	DamageTaken = "RemoteEvent", -- S->C { from = Vector3, amount }
	KillFeed = "RemoteEvent", -- S->C { killer, victim, weapon, headshot, killerTeam, victimTeam }
	Notify = "RemoteEvent", -- S->C (text, kind)
	ShotFx = "UnreliableRemoteEvent", -- S->C (shooter, origin, hitPosition) cosmetic only
}

local folder

function Remotes.get(name)
	assert(Remotes.Definitions[name], "Unknown remote " .. tostring(name))
	if not folder then
		assert(RunService:IsClient(), "Server must create remotes via Net.init first")
		folder = ReplicatedStorage:WaitForChild(Remotes.FolderName)
	end
	return folder:WaitForChild(name)
end

function Remotes._setFolder(f)
	folder = f
end

return Remotes
