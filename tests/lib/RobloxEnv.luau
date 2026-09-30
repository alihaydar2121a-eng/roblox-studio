--[[
	RobloxEnv — shared Lune test support.
	Loads repository ModuleScripts as they would run inside Roblox: `script`
	proxies mirror default.project.json, `require` resolves them, and globals are
	Lune's real Roblox datatypes. Engine services that Lune can't provide are
	replaced via `overrides` (path pattern -> module value).
]]

local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local Instance, Vector3, CFrame, Enum = roblox.Instance, roblox.Vector3, roblox.CFrame, roblox.Enum

return function(options)
	options = options or {}
	local game = options.game or Instance.new("DataModel")
	local workspace = game:GetService("Workspace")
	local RaycastParamsMock = { new = function() return {} end }
	local taskMock = options.task or {
		wait = function() end,
		defer = function(f, ...) f(...) end,
		spawn = function(f, ...) f(...) end,
		delay = function() end,
	}
	local overrides = options.overrides or {}


-- Index the source tree up front (Lune fs calls can't run inside metamethods).
local fileSet, dirSet = {}, {}
local function index(dir)
	dirSet[dir] = true
	for _, name in ipairs(fs.readDir(dir)) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			index(path)
		else
			fileSet[path] = true
		end
	end
end
index("src")
local function isFile(path)
	return fileSet[path] == true
end
local function isDir(path)
	return dirSet[path] == true
end

local proxies = {}
local moduleCache = {}
local makeProxy

-- Virtual Roblox tree → filesystem mapping (mirrors default.project.json).
local services = {
	ReplicatedStorage = { Shared = "src/shared" },
	ServerScriptService = { Server = "src/server" },
}

local function resolveChild(dirPath, name)
	for _, candidate in ipairs({ dirPath .. "/" .. name .. ".lua", dirPath .. "/" .. name .. ".luau" }) do
		if isFile(candidate) then
			return candidate, "file"
		end
	end
	if isDir(dirPath .. "/" .. name) then
		return dirPath .. "/" .. name, "dir"
	end
	return nil
end

function makeProxy(path, kind, parent, name)
	local key = path
	if proxies[key] then
		return proxies[key]
	end
	local proxy = { __path = path, __kind = kind }
	local function child(childName)
		if kind == "service" then
			local mapped = services[name][childName]
			return mapped and makeProxy(mapped, "dir", proxy, childName) or nil
		end
		local dirPath = kind == "dir" and path or nil
		if not dirPath then
			return nil
		end
		local childPath, childKind = resolveChild(dirPath, childName)
		return childPath and makeProxy(childPath, childKind, proxy, childName) or nil
	end
	setmetatable(proxy, {
		__index = function(_, k)
			if k == "Parent" then
				return parent
			elseif k == "Name" then
				return name
			elseif k == "WaitForChild" or k == "FindFirstChild" then
				return function(_, childName)
					local c = child(childName)
					assert(c or k == "FindFirstChild", "harness: no child " .. childName .. " under " .. path)
					return c
				end
			end
			local c = child(k)
			assert(c, "harness: " .. tostring(k) .. " is not a valid member of " .. path)
			return c
		end,
	})
	proxies[key] = proxy
	return proxy
end

local gameProxy = setmetatable({}, {
	__index = function(_, k)
		if k == "GetService" then
			return function(_, serviceName)
				if services[serviceName] then
					return makeProxy("@" .. serviceName, "service", nil, serviceName)
				end
				return game:GetService(serviceName)
			end
		end
		return game[k]
	end,
})

local baseEnv = {
	game = gameProxy, workspace = workspace, Instance = Instance, Vector3 = Vector3, CFrame = CFrame, Enum = Enum,
	Color3 = roblox.Color3, BrickColor = roblox.BrickColor, UDim2 = roblox.UDim2, UDim = roblox.UDim, Vector2 = roblox.Vector2,
	Region3 = roblox.Region3, NumberRange = roblox.NumberRange, NumberSequence = roblox.NumberSequence, ColorSequence = roblox.ColorSequence,
	RaycastParams = RaycastParamsMock, task = taskMock, typeof = typeof, warn = function(...)
		print("  WARN", ...)
	end,
	print = print, math = math, string = string, table = table, os = os, bit32 = bit32, coroutine = coroutine, utf8 = utf8,
	pairs = pairs, ipairs = ipairs, next = next, select = select, type = type, tostring = tostring, tonumber = tonumber,
	pcall = pcall, xpcall = xpcall, error = error, assert = assert, setmetatable = setmetatable, getmetatable = getmetatable,
	rawget = rawget, rawset = rawset, rawequal = rawequal, unpack = table.unpack,
}

local function requireProxy(proxy)
	local path = proxy.__path
	for pattern, value in pairs(overrides) do
		if path:match(pattern) then
			return value
		end
	end
	local file = proxy.__kind == "file" and path or (path .. "/init.lua")
	if moduleCache[file] ~= nil then
		return moduleCache[file]
	end
	local source = fs.readFile(file)
	-- Lune copies the environment table's fields, so flatten baseEnv into it.
	local env = table.clone(baseEnv)
	env.script = proxy
	env.require = requireProxy
	local chunk = luau.load(source, { debugName = file, environment = env })
	local result = chunk()
	moduleCache[file] = result
	return result
end
baseEnv.require = requireProxy


	return {
		game = game,
		workspace = workspace,
		require = requireProxy,
		proxy = makeProxy,
		service = function(name)
			return makeProxy("@" .. name, "service", nil, name)
		end,
	}
end
