--[[
	Net (server)
	Creates the remotes declared in Shared.Net.Remotes and wraps every inbound
	handler with a per-player token-bucket rate limit and error isolation.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)
local RateLimiter = require(Shared.Util.RateLimiter)

local Net = {}

local remotes = {}
local limiters = {}
local violations = {}

function Net.init()
	local folder = Instance.new("Folder")
	folder.Name = Remotes.FolderName
	for name, className in pairs(Remotes.Definitions) do
		local remote = Instance.new(className)
		remote.Name = name
		remote.Parent = folder
		remotes[name] = remote
	end
	folder.Parent = ReplicatedStorage
	Remotes._setFolder(folder)

	Players.PlayerRemoving:Connect(function(player)
		for _, limiter in pairs(limiters) do
			limiter:reset(player.UserId)
		end
		violations[player] = nil
	end)
end

local function recordViolation(player, name)
	local count = (violations[player] or 0) + 1
	violations[player] = count
	if count % 50 == 1 then
		warn(("[Net] %s exceeded rate limit on %s (%d drops)"):format(player.Name, name, count))
	end
end

--[[
	Net.on(name, limit, handler)
	limit = { burst = number, perSecond = number }
	handler(player, ...) receives raw, untrusted arguments and must validate them.
]]
function Net.on(name, limit, handler)
	local remote = assert(remotes[name], "Remote not defined: " .. name)
	local limiter = RateLimiter.new(limit.burst, limit.perSecond)
	limiters[name] = limiter
	remote.OnServerEvent:Connect(function(player, ...)
		if not limiter:allow(player.UserId) then
			recordViolation(player, name)
			return
		end
		local ok, err = pcall(handler, player, ...)
		if not ok then
			warn(("[Net] handler %s errored for %s: %s"):format(name, player.Name, tostring(err)))
		end
	end)
end

function Net.fire(name, player, ...)
	remotes[name]:FireClient(player, ...)
end

function Net.fireAll(name, ...)
	remotes[name]:FireAllClients(...)
end

function Net.fireAllExcept(name, except, ...)
	local remote = remotes[name]
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= except then
			remote:FireClient(player, ...)
		end
	end
end

return Net
