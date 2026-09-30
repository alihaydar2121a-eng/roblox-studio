--[[
	Ironfront Tools — Roblox Studio plugin
	Toolbar buttons to bake Kestrel Valley into the open place (terrain +
	Workspace.Map) so it is saved with the place, or to clear it again.

	Install:  rojo build plugin.project.json --plugin IronfrontTools.rbxmx
	Requires the game code to be synced (rojo serve) so the generator modules
	exist under ServerScriptService.Server.World.
]]

local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Selection = game:GetService("Selection")

if not RunService:IsEdit() then
	return
end

local toolbar = plugin:CreateToolbar("Ironfront")
local bakeButton = toolbar:CreateButton("Bake Map", "Generate Kestrel Valley (terrain + structures) into this place", "rbxasset://textures/TerrainTools/mt_generate.png")
local clearButton = toolbar:CreateButton("Clear Map", "Remove the baked map and terrain", "rbxasset://textures/TerrainTools/mt_clear.png")
bakeButton.ClickableWhenViewportHidden = true
clearButton.ClickableWhenViewportHidden = true

local busy = false

local function getBuilder()
	local server = ServerScriptService:FindFirstChild("Server")
	local world = server and server:FindFirstChild("World")
	local module = world and world:FindFirstChild("MapBuilder")
	if not module then
		warn("[Ironfront Tools] ServerScriptService.Server.World.MapBuilder not found — start `rojo serve` and connect first.")
		return nil
	end
	return require(module)
end

bakeButton.Click:Connect(function()
	bakeButton:SetActive(false)
	if busy then
		return
	end
	local MapBuilder = getBuilder()
	if not MapBuilder then
		return
	end
	busy = true
	task.spawn(function()
		local ok, err = pcall(function()
			local map, report = MapBuilder.bake()
			Selection:Set({ map })
			print(("[Ironfront Tools] Baked %d parts in %.1fs. Save the place to keep it."):format(report.parts, report.seconds))
		end)
		if not ok then
			warn("[Ironfront Tools] Bake failed: " .. tostring(err))
		end
		busy = false
	end)
end)

clearButton.Click:Connect(function()
	clearButton:SetActive(false)
	if busy then
		return
	end
	local MapBuilder = getBuilder()
	if MapBuilder then
		MapBuilder.clear()
		print("[Ironfront Tools] Map and terrain cleared.")
	end
end)
