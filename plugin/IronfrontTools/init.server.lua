--[[
	Ironfront Tools — Roblox Studio plugin
	Toolbar buttons to bake Kestrel Valley into the open place (terrain +
	Workspace.Map) so it is saved with the place, or to clear it again, and to
	install premium Blender assets imported with the 3D Importer.

	Install:  Sync-Ironfront.cmd builds it, or: rojo build plugin.project.json --plugin IronfrontTools.rbxmx
	Requires the game code to be synced (rojo serve) so the generator modules
	exist under ServerScriptService.Server.World and the asset table under
	ReplicatedStorage.Shared.Config.PremiumAssets.
]]

local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ServerStorage = game:GetService("ServerStorage")
local AssetInstaller = require(script.AssetInstaller)
local Selection = game:GetService("Selection")

if not RunService:IsEdit() then
	return
end

local toolbar = plugin:CreateToolbar("Ironfront")
local bakeButton = toolbar:CreateButton("Bake Map", "Generate Kestrel Valley (terrain + structures) into this place", "rbxasset://textures/TerrainTools/mt_generate.png")
local clearButton = toolbar:CreateButton("Clear Map", "Remove the baked map and terrain", "rbxasset://textures/TerrainTools/mt_clear.png")
local installButton = toolbar:CreateButton("Assets", "Open the asset panel: check and install imported premium models (IR7, Ashford_*)", "rbxasset://textures/StudioToolbox/AssetPreview/Model.png")
bakeButton.ClickableWhenViewportHidden = true
clearButton.ClickableWhenViewportHidden = true
installButton.ClickableWhenViewportHidden = true

local busy = false
local bakeArmed = nil

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
	-- Re-baking replaces the saved map: require a second click within 8 s.
	if workspace:FindFirstChild("Map") and os.clock() - (bakeArmed or -math.huge) > 8 then
		bakeArmed = os.clock()
		warn("[Ironfront Tools] A baked map already exists. Re-baking REPLACES Workspace.Map and the terrain. Save a copy of the place first, then click Bake Map again within 8 seconds to confirm.")
		return
	end
	bakeArmed = nil
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

---------------------------------------------------------------- asset panel

local function premiumList()
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local config = shared and shared:FindFirstChild("Config")
	local module = config and config:FindFirstChild("PremiumAssets")
	if not module then
		return nil, "ReplicatedStorage.Shared.Config.PremiumAssets not found - run Sync-Ironfront and connect Rojo first."
	end
	local ok, result = pcall(require, module)
	if not ok then
		return nil, "PremiumAssets failed to load: " .. tostring(result)
	end
	return result
end

-- Weapon attachment points from Shared.Config.WeaponModels (Grip is the origin).
local function weaponPoints(entry)
	if entry.Path[1] ~= "Weapons" then
		return nil
	end
	local module = ReplicatedStorage:FindFirstChild("Shared") and ReplicatedStorage.Shared:FindFirstChild("Config")
		and ReplicatedStorage.Shared.Config:FindFirstChild("WeaponModels")
	local ok, models = pcall(function()
		return module and require(module)
	end)
	local spec = ok and models and models[entry.Path[2]]
	if not (spec and spec.Points) then
		return nil
	end
	local points = { Grip = Vector3.zero }
	for name, p in pairs(spec.Points) do
		points[name] = Vector3.new(p[1], p[2], p[3])
	end
	return points
end

local function context()
	local premium, err = premiumList()
	if not premium then
		return nil, err
	end
	return {
		ReplicatedStorage = ReplicatedStorage, Workspace = workspace, ServerStorage = ServerStorage,
		selection = Selection:Get(), premium = premium, points = weaponPoints,
	}
end

local widget = plugin:CreateDockWidgetPluginGui("IronfrontAssets",
	DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right, false, false, 380, 460, 300, 260))
widget.Title = "Ironfront Assets"

local root = Instance.new("Frame")
root.Size = UDim2.fromScale(1, 1)
root.BackgroundColor3 = Color3.fromRGB(37, 37, 37)
root.BorderSizePixel = 0
root.Parent = widget

local function button(text, x, color)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0.333, -6, 0, 30)
	b.Position = UDim2.new(x, 4, 0, 6)
	b.BackgroundColor3 = color
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.SourceSansBold
	b.TextSize = 15
	b.Text = text
	b.AutoButtonColor = true
	b.Parent = root
	return b
end
local refreshBtn = button("Refresh", 0, Color3.fromRGB(70, 70, 70))
local installBtn = button("Install / fix", 0.333, Color3.fromRGB(46, 110, 60))
local replaceBtn = button("Replace installed", 0.666, Color3.fromRGB(130, 70, 40))

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.new(0, 4, 0, 42)
list.Size = UDim2.new(1, -8, 1, -46)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.ScrollBarThickness = 6
list.Parent = root
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 4)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

local STATUS = {
	installed = { "INSTALLED", Color3.fromRGB(90, 190, 110) },
	ready = { "READY TO INSTALL", Color3.fromRGB(110, 170, 240) },
	replace = { "NEW IMPORT - ALREADY INSTALLED", Color3.fromRGB(240, 170, 80) },
	missing = { "NOT IMPORTED", Color3.fromRGB(150, 150, 150) },
}

local function line(text, color, order, size)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, -8, 0, 0)
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Font = Enum.Font.SourceSans
	l.TextSize = size or 14
	l.TextColor3 = color
	l.Text = text
	l.LayoutOrder = order
	l.Parent = list
	return l
end

local rows = {}
local replaceArmed = nil

local function render(extra)
	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("TextLabel") then
			c:Destroy()
		end
	end
	local ctx, err = context()
	if not ctx then
		line(err, Color3.fromRGB(240, 110, 100), 1)
		rows = {}
		return
	end
	local unknown
	rows, unknown = AssetInstaller.scan(ctx)
	local order = 0
	local counts = { installed = 0, ready = 0, replace = 0, missing = 0 }
	for _, row in ipairs(rows) do
		counts[row.status] += 1
		local s = STATUS[row.status]
		order += 1
		local title = line(("%s  -  %s"):format(row.entry.Model, s[1]), s[2], order, 15)
		title.Font = Enum.Font.SourceSansBold
		order += 1
		line("    " .. AssetInstaller.pathString(row.entry), Color3.fromRGB(170, 170, 170), order, 13)
		for _, issue in ipairs(row.issues) do
			order += 1
			line("    ! " .. issue, Color3.fromRGB(240, 200, 90), order, 13)
		end
	end
	for _, model in ipairs(unknown) do
		order += 1
		line(("Unrecognised import '%s' in Workspace - rename it to the FBX name (e.g. IR7, Ashford_Torso) to install it."):format(model.Name),
			Color3.fromRGB(240, 200, 90), order, 13)
	end
	order += 1
	line(("%d installed, %d ready, %d need confirmation, %d not imported. Import FBX files from assets/premium with Home > Import 3D."):format(
		counts.installed, counts.ready, counts.replace, counts.missing), Color3.fromRGB(200, 200, 200), 0, 13)
	if extra then
		order += 1
		line(extra, Color3.fromRGB(120, 220, 140), order, 13)
	end
	installBtn.Text = counts.ready > 0 and ("Install / fix (%d)"):format(counts.ready) or "Install / fix"
	replaceBtn.Text = counts.replace > 0 and ("Replace installed (%d)"):format(counts.replace) or "Replace installed"
end

local function runInstall(replace)
	local ctx, err = context()
	if not ctx then
		warn("[Ironfront Tools] " .. err)
		return
	end
	rows = AssetInstaller.scan(ctx)
	local recording
	pcall(function()
		recording = ChangeHistoryService:TryBeginRecording("Install Ironfront assets")
	end)
	local report, installed = AssetInstaller.install(ctx, rows, { replace = replace })
	if recording then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	else
		ChangeHistoryService:SetWaypoint("Install Ironfront assets")
	end
	for _, l in ipairs(report) do
		print("[Ironfront Tools] " .. l)
	end
	if #installed > 0 then
		Selection:Set(installed)
		print(("[Ironfront Tools] Installed %d asset(s). SAVE THE PLACE to keep them (File > Save)."):format(#installed))
	elseif #report == 0 then
		print("[Ironfront Tools] Nothing to install. Import an FBX from assets/premium first (Home > Import 3D).")
	end
	render(#installed > 0 and ("Installed %d asset(s) - save the place."):format(#installed) or nil)
end

refreshBtn.MouseButton1Click:Connect(function()
	render()
end)
installBtn.MouseButton1Click:Connect(function()
	runInstall(false)
end)
replaceBtn.MouseButton1Click:Connect(function()
	-- Replacing needs a second click; the old model is moved to ServerStorage, not deleted.
	if not replaceArmed or os.clock() - replaceArmed > 8 then
		replaceArmed = os.clock()
		replaceBtn.Text = "Click again to confirm"
		warn("[Ironfront Tools] Replace will swap the installed models for the new imports. The old ones are moved to ServerStorage.IronfrontAssetBackups. Click 'Replace installed' again within 8 s to confirm.")
		return
	end
	replaceArmed = nil
	runInstall(true)
end)

installButton.Click:Connect(function()
	widget.Enabled = not widget.Enabled
	installButton:SetActive(widget.Enabled)
	if widget.Enabled then
		render()
	end
end)
widget:GetPropertyChangedSignal("Enabled"):Connect(function()
	installButton:SetActive(widget.Enabled)
end)
