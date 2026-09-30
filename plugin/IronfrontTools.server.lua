--[[
	Ironfront Tools — Roblox Studio plugin
	Toolbar buttons to bake Kestrel Valley into the open place (terrain +
	Workspace.Map) so it is saved with the place, or to clear it again, and to
	install premium Blender assets imported with the 3D Importer.

	Install:  rojo build plugin.project.json --plugin IronfrontTools.rbxmx
	Requires the game code to be synced (rojo serve) so the generator modules
	exist under ServerScriptService.Server.World and the asset table under
	ReplicatedStorage.Shared.Config.PremiumAssets.
]]

local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")

if not RunService:IsEdit() then
	return
end

local toolbar = plugin:CreateToolbar("Ironfront")
local bakeButton = toolbar:CreateButton("Bake Map", "Generate Kestrel Valley (terrain + structures) into this place", "rbxasset://textures/TerrainTools/mt_generate.png")
local clearButton = toolbar:CreateButton("Clear Map", "Remove the baked map and terrain", "rbxasset://textures/TerrainTools/mt_clear.png")
local installButton = toolbar:CreateButton("Install Assets", "Move imported premium models (IR7, Ashford_*) into ReplicatedStorage.ImportedAssets", "")
bakeButton.ClickableWhenViewportHidden = true
clearButton.ClickableWhenViewportHidden = true
installButton.ClickableWhenViewportHidden = true

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

---------------------------------------------------------------- premium assets

local function premiumList()
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local config = shared and shared:FindFirstChild("Config")
	local module = config and config:FindFirstChild("PremiumAssets")
	if not module then
		warn("[Ironfront Tools] ReplicatedStorage.Shared.Config.PremiumAssets not found — start `rojo serve` and connect first.")
		return nil
	end
	local ok, result = pcall(require, module)
	if not ok then
		warn("[Ironfront Tools] PremiumAssets failed to load: " .. tostring(result))
		return nil
	end
	return result
end

local function destination(path)
	local node = ReplicatedStorage:FindFirstChild("ImportedAssets")
	if not node then
		node = Instance.new("Folder")
		node.Name = "ImportedAssets"
		node.Parent = ReplicatedStorage
	end
	for i = 1, #path - 1 do
		local child = node:FindFirstChild(path[i])
		if not child then
			child = Instance.new("Folder")
			child.Name = path[i]
			child.Parent = node
		end
		node = child
	end
	return node, path[#path]
end

local function sortedSize(v)
	local t = { v.X, v.Y, v.Z }
	table.sort(t)
	return t
end

local function isLens(part)
	local name = string.lower(part.Name)
	return string.find(name, "_glass", 1, true) ~= nil or string.find(name, "_lens", 1, true) ~= nil
end

-- Makes an imported model match what the runtime expects and reports problems.
local function prepare(model, entry)
	local notes = {}
	-- Unit check: the importer's "File Dimensions" can scale the model; fix it.
	local got = sortedSize(model:GetExtentsSize())
	local want = sortedSize(Vector3.new(entry.Size[1], entry.Size[2], entry.Size[3]))
	local factor = want[3] / math.max(got[3], 1e-6)
	if math.abs(factor - 1) > 0.12 then
		model:ScaleTo(model:GetScale() * factor)
		table.insert(notes, ("rescaled x%.3f (longest side was %.2f studs, expected %.2f) — check the importer's File Dimensions"):format(factor, got[3], want[3]))
	end
	-- Orientation check: measure the parts in the Origin marker's frame (the
	-- runtime pivot) and compare each axis with the expected size.
	local origin = model:FindFirstChild("Origin", true)
	if origin and origin:IsA("BasePart") then
		local lo = Vector3.new(math.huge, math.huge, math.huge)
		local hi = -lo
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") and d ~= origin then
				local h = d.Size / 2
				for _, c in ipairs({ Vector3.new(-1, -1, -1), Vector3.new(1, -1, -1), Vector3.new(-1, 1, -1), Vector3.new(1, 1, -1),
					Vector3.new(-1, -1, 1), Vector3.new(1, -1, 1), Vector3.new(-1, 1, 1), Vector3.new(1, 1, 1) }) do
					local p = origin.CFrame:PointToObjectSpace(d.CFrame:PointToWorldSpace(h * c))
					lo = lo:Min(p)
					hi = hi:Max(p)
				end
			end
		end
		local size = hi - lo
		local axes = { size.X, size.Y, size.Z }
		for i, name in ipairs({ "X", "Y", "Z" }) do
			if math.abs(axes[i] - entry.Size[i]) > math.max(0.15 * entry.Size[i], 0.08) then
				table.insert(notes, ("%s extent is %.2f studs, expected %.2f — check the importer's World Forward/Up (should be -Z forward, +Y up)")
					:format(name, axes[i], entry.Size[i]))
			end
		end
	else
		table.insert(notes, "no Origin part — the runtime will fall back to the model pivot")
	end
	-- One baked atlas is shared by every non-glass part: copy the importer's
	-- SurfaceAppearance to any part that did not get one.
	local surface
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("SurfaceAppearance") and d.Parent and not isLens(d.Parent) then
			surface = d
			break
		end
	end
	local names = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			names[d.Name] = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			if d:IsA("MeshPart") then
				pcall(function()
					d.CollisionFidelity = Enum.CollisionFidelity.Box
					d.RenderFidelity = Enum.RenderFidelity.Automatic
				end)
			end
			if isLens(d) then
				for _, sa in ipairs(d:GetChildren()) do
					if sa:IsA("SurfaceAppearance") then
						sa:Destroy()
					end
				end
				d.Material = Enum.Material.Glass
				d.Transparency = 0.35
			elseif surface and d.Name ~= "Origin" and not d:FindFirstChildOfClass("SurfaceAppearance") then
				surface:Clone().Parent = d
			end
		end
	end
	if not surface then
		table.insert(notes, "no SurfaceAppearance found — parts use the flat palette (see docs/PREMIUM_ASSETS.md, step 3)")
	end
	for _, required in ipairs(entry.Parts or {}) do
		if not names[required] then
			table.insert(notes, "missing part " .. required)
		end
	end
	return notes
end

installButton.Click:Connect(function()
	installButton:SetActive(false)
	local premium = premiumList()
	if not premium then
		return
	end
	local candidates = {}
	local selected = Selection:Get()
	local pool = #selected > 0 and selected or workspace:GetChildren()
	for _, inst in ipairs(pool) do
		if inst:IsA("Model") and premium.find(inst.Name) then
			table.insert(candidates, inst)
		end
	end
	if #candidates == 0 then
		warn("[Ironfront Tools] No imported premium models found. Import e.g. assets/premium/weapons/IR7/IR7.fbx with the 3D Importer first (it creates a Model named IR7 in Workspace), or select the models.")
		return
	end
	local recording
	pcall(function()
		recording = ChangeHistoryService:TryBeginRecording("Install Ironfront assets")
	end)
	local installed = {}
	for _, model in ipairs(candidates) do
		local entry = premium.find(model.Name)
		local ok, err = pcall(function()
			local notes = prepare(model, entry)
			local folder, name = destination(entry.Path)
			local old = folder:FindFirstChild(name)
			if old then
				old:Destroy()
			end
			model.Name = name
			model.Parent = folder
			local where = "ReplicatedStorage.ImportedAssets." .. table.concat(entry.Path, ".")
			print(("[Ironfront Tools] %s -> %s"):format(entry.Model, where))
			for _, note in ipairs(notes) do
				warn("[Ironfront Tools]   " .. entry.Model .. ": " .. note)
			end
			table.insert(installed, model)
		end)
		if not ok then
			warn("[Ironfront Tools] Could not install " .. model.Name .. ": " .. tostring(err))
		end
	end
	if recording then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	else
		ChangeHistoryService:SetWaypoint("Install Ironfront assets")
	end
	Selection:Set(installed)
	print(("[Ironfront Tools] Installed %d asset(s). Save the place to keep them."):format(#installed))
end)
