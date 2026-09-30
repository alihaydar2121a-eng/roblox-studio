--[[
	GameState (server)
	Replicated match state lives as attributes on ReplicatedStorage.GameState so
	clients can read it without extra remotes and without depending on
	streamed-in workspace parts.

	Attributes on GameState:   Phase ("Active" | "Ended"), EndsAt (server time),
	                           Winner, Tickets_<TeamId>
	Children of GameState.Zones: one Configuration per zone with attributes
	                           Name, Position, Radius, Owner, Control, Contested, Capturing
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameState = {}

local folder = Instance.new("Folder")
folder.Name = "GameState"
local zones = Instance.new("Folder")
zones.Name = "Zones"
zones.Parent = folder

GameState.Folder = folder
GameState.Zones = zones

function GameState.init()
	folder.Parent = ReplicatedStorage
end

function GameState.set(key, value)
	folder:SetAttribute(key, value)
end

function GameState.get(key)
	return folder:GetAttribute(key)
end

function GameState.isActive()
	return folder:GetAttribute("Phase") == "Active"
end

return GameState
