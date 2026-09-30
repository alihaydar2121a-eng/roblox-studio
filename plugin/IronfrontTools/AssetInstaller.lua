--[[
	AssetInstaller — logic behind the Ironfront Tools "Assets" panel.
	No UI and no plugin globals, so tests/plugin_installer.luau can run it in Lune.

	ctx = {
		ReplicatedStorage, Workspace, ServerStorage,   -- services (or test stand-ins)
		selection = { Instance },                      -- optional: only look at these
		premium = PremiumAssets module table,          -- .List, .find(name)
		points = function(entry) -> { Name = Vector3 } | nil,  -- weapon attachment points
	}

	scan(ctx) -> rows (one per PremiumAssets entry) + unknown imports:
		row.entry       the PremiumAssets entry
		row.installed   Model already under ReplicatedStorage.ImportedAssets.<Path> (or nil)
		row.source      freshly imported Model found in Workspace/selection (or nil)
		row.status      "installed" | "ready" (source found, nothing installed)
		                | "replace" (source found AND something installed) | "missing"
		row.issues      problems found on the source (or on the installed model)
	install(ctx, rows, { replace = bool }) -> report lines
		Installs every "ready" row and re-applies the additive fixes (shared
		SurfaceAppearance, cosmetic flags, attachments) to installed models. "replace" rows are only installed when
		opts.replace is true, and the old model is MOVED to
		ServerStorage.IronfrontAssetBackups, never destroyed.
]]

local AssetInstaller = {}

local BACKUP_FOLDER = "IronfrontAssetBackups"

local function lower(s)
	return string.lower(s)
end

local function isLens(part)
	local name = lower(part.Name)
	return string.find(name, "_glass", 1, true) ~= nil or string.find(name, "_lens", 1, true) ~= nil
end

local function isTextured(part)
	if part:FindFirstChildOfClass("SurfaceAppearance") then
		return true
	end
	return part:IsA("MeshPart") and part.TextureID ~= ""
end

local function destinationOf(ctx, path, create)
	local node = ctx.ReplicatedStorage:FindFirstChild("ImportedAssets")
	if not node then
		if not create then
			return nil, path[#path]
		end
		node = Instance.new("Folder")
		node.Name = "ImportedAssets"
		node.Parent = ctx.ReplicatedStorage
	end
	for i = 1, #path - 1 do
		local child = node:FindFirstChild(path[i])
		if not child then
			if not create then
				return nil, path[#path]
			end
			child = Instance.new("Folder")
			child.Name = path[i]
			child.Parent = node
		end
		node = child
	end
	return node, path[#path]
end

function AssetInstaller.pathString(entry)
	return "ReplicatedStorage.ImportedAssets." .. table.concat(entry.Path, ".")
end

local function findInstalled(ctx, entry)
	local folder, name = destinationOf(ctx, entry.Path, false)
	local model = folder and folder:FindFirstChild(name)
	if model and model:IsA("Model") then
		return model
	end
	return nil
end

-- Bounding box of the model's parts in the Origin marker's frame (the runtime pivot).
local function extentsInOrigin(model, origin)
	local lo = Vector3.new(math.huge, math.huge, math.huge)
	local hi = -lo
	local any = false
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d ~= origin then
			any = true
			local h = d.Size / 2
			for _, sx in ipairs({ -1, 1 }) do
				for _, sy in ipairs({ -1, 1 }) do
					for _, sz in ipairs({ -1, 1 }) do
						local p = origin.CFrame:PointToObjectSpace(d.CFrame:PointToWorldSpace(Vector3.new(h.X * sx, h.Y * sy, h.Z * sz)))
						lo = Vector3.new(math.min(lo.X, p.X), math.min(lo.Y, p.Y), math.min(lo.Z, p.Z))
						hi = Vector3.new(math.max(hi.X, p.X), math.max(hi.Y, p.Y), math.max(hi.Z, p.Z))
					end
				end
			end
		end
	end
	return any and (hi - lo) or Vector3.zero
end

--[[
	inspect(model, entry) -> issues, info
	Read-only checks: Origin marker, scale, axes, required parts, textures.
	info.scale is the factor that would fix the size (1 = fine).
]]
function AssetInstaller.inspect(model, entry)
	local issues = {}
	local info = { scale = 1, parts = 0, untextured = {} }
	local origin = model:FindFirstChild("Origin", true)
	if not (origin and origin:IsA("BasePart")) then
		table.insert(issues, "no Origin part - re-export the FBX; the runtime would use the model pivot")
		origin = nil
	end
	local names = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			names[d.Name] = true
			if d ~= origin then
				info.parts += 1
				if not isLens(d) and not isTextured(d) then
					table.insert(info.untextured, d.Name)
				end
			end
		end
	end
	if info.parts == 0 then
		table.insert(issues, "no mesh parts inside the model")
		return issues, info
	end
	if origin then
		local size = extentsInOrigin(model, origin)
		local want = entry.Size
		local got = { size.X, size.Y, size.Z }
		local longestGot, longestWant = math.max(got[1], got[2], got[3]), math.max(want[1], want[2], want[3])
		local factor = longestWant / math.max(longestGot, 1e-6)
		if math.abs(factor - 1) > 0.12 then
			info.scale = factor
			table.insert(issues, ("size is x%.2f off (longest side %.2f studs, expected %.2f) - will be rescaled; set the importer's File Dimensions to Studs")
				:format(1 / factor, longestGot, longestWant))
		else
			for i, axis in ipairs({ "X", "Y", "Z" }) do
				if math.abs(got[i] - want[i]) > math.max(0.15 * want[i], 0.08) then
					table.insert(issues, ("%s extent %.2f studs, expected %.2f - check the importer's World Forward (-Z) / Up (+Y)")
						:format(axis, got[i], want[i]))
				end
			end
		end
	end
	for _, required in ipairs(entry.Parts or {}) do
		if not names[required] then
			table.insert(issues, "missing part " .. required)
		end
	end
	if #info.untextured == info.parts then
		table.insert(issues, "no textures: no part has a SurfaceAppearance or TextureID (docs/PREMIUM_ASSETS.md, step 3)")
	end
	return issues, info
end

local function isImportCandidate(model)
	if not model:IsA("Model") then
		return false
	end
	local origin = model:FindFirstChild("Origin", true)
	return origin ~= nil and origin:IsA("BasePart")
end

local function sources(ctx)
	local pool = (ctx.selection and #ctx.selection > 0) and ctx.selection or ctx.Workspace:GetChildren()
	return pool
end

function AssetInstaller.scan(ctx)
	local rows, byModel = {}, {}
	for _, entry in ipairs(ctx.premium.List) do
		local row = { entry = entry, issues = {}, installed = findInstalled(ctx, entry) }
		table.insert(rows, row)
		byModel[lower(entry.Model)] = row
	end
	local unknown = {}
	for _, inst in ipairs(sources(ctx)) do
		if inst:IsA("Model") then
			local row = byModel[lower(inst.Name)]
			if row and not row.source then
				row.source = inst
			elseif not row and isImportCandidate(inst) then
				table.insert(unknown, inst)
			end
		end
	end
	for _, row in ipairs(rows) do
		if row.source then
			row.status = row.installed and "replace" or "ready"
			row.issues = AssetInstaller.inspect(row.source, row.entry)
		elseif row.installed then
			row.status = "installed"
			row.issues = AssetInstaller.inspect(row.installed, row.entry)
		else
			row.status = "missing"
		end
	end
	return rows, unknown
end

-- Makes an imported model match what the runtime expects. Mutates the model.
function AssetInstaller.prepare(model, entry, points)
	local notes = {}
	local _, info = AssetInstaller.inspect(model, entry)
	if info.scale ~= 1 then
		local ok = pcall(function()
			model:ScaleTo(model:GetScale() * info.scale)
		end)
		table.insert(notes, ok and ("rescaled x%.3f"):format(info.scale) or "could not rescale - fix the importer's File Dimensions and re-import")
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
	local shared = 0
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
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
				shared += 1
			end
		end
	end
	if shared > 0 then
		table.insert(notes, ("shared the baked SurfaceAppearance with %d part(s)"):format(shared))
	end
	-- Weapon attachment points on the Origin (grip), for inspection in Studio.
	local origin = model:FindFirstChild("Origin", true)
	if points and origin and origin:IsA("BasePart") then
		origin.Transparency = 1
		for name, pos in pairs(points) do
			local a = origin:FindFirstChild(name)
			if not (a and a:IsA("Attachment")) then
				a = Instance.new("Attachment")
				a.Name = name
				a.Parent = origin
			end
			a.Position = pos
		end
		table.insert(notes, "attachment points: " .. (function()
			local list = {}
			for name in pairs(points) do
				table.insert(list, name)
			end
			table.sort(list)
			return table.concat(list, ", ")
		end)())
	end
	return notes
end

local function backup(ctx, old, entry)
	local folder = ctx.ServerStorage:FindFirstChild(BACKUP_FOLDER)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = BACKUP_FOLDER
		folder.Parent = ctx.ServerStorage
	end
	local base = table.concat(entry.Path, "_")
	local n = 1
	while folder:FindFirstChild(base .. "_" .. n) do
		n += 1
	end
	old.Name = base .. "_" .. n
	old.Parent = folder
	return "ServerStorage." .. BACKUP_FOLDER .. "." .. old.Name
end

function AssetInstaller.install(ctx, rows, opts)
	opts = opts or {}
	local report, installed = {}, {}
	for _, row in ipairs(rows) do
		if row.status == "ready" or (row.status == "replace" and opts.replace) then
			local entry = row.entry
			local ok, err = pcall(function()
				local notes = AssetInstaller.prepare(row.source, entry, ctx.points and ctx.points(entry))
				local folder, name = destinationOf(ctx, entry.Path, true)
				if row.installed then
					table.insert(notes, "previous version kept at " .. backup(ctx, row.installed, entry))
				end
				row.source.Name = name
				row.source.Parent = folder
				table.insert(report, ("%s -> %s"):format(entry.Model, AssetInstaller.pathString(entry)))
				for _, note in ipairs(notes) do
					table.insert(report, "    " .. note)
				end
				for _, issue in ipairs(row.issues) do
					if not string.find(issue, "rescaled", 1, true) then
						table.insert(report, "    check: " .. issue)
					end
				end
				table.insert(installed, row.source)
			end)
			if not ok then
				table.insert(report, ("%s: could not install - %s"):format(entry.Model, tostring(err)))
			end
		elseif row.status == "installed" or row.status == "replace" then
			-- Safe, additive fixes on what is already installed (shares a newly added
			-- SurfaceAppearance, cosmetic flags, attachment points). Never replaces it.
			local ok, notes = pcall(AssetInstaller.prepare, row.installed, row.entry, ctx.points and ctx.points(row.entry))
			if ok and #notes > 0 then
				table.insert(report, ("%s (installed): %s"):format(row.entry.Model, table.concat(notes, "; ")))
			end
		end
		if row.status == "replace" and not opts.replace then
			table.insert(report, ("%s: already installed at %s - skipped (use 'Replace installed' to swap it; the old one is backed up)")
				:format(row.entry.Model, AssetInstaller.pathString(row.entry)))
		end
	end
	return report, installed
end

return AssetInstaller
