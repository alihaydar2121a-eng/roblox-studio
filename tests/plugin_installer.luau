--[[
	Ironfront Tools asset installer (plugin/IronfrontTools/AssetInstaller.lua),
	run against a simulated Studio place built from real Lune Roblox instances.
	Checks: detection of 3D-Importer output, missing/installed/ready states,
	texture + scale + part checks, attachment points, and that an existing
	install is never overwritten without opts.replace (and then only backed up).
	Run: lune run tests/plugin_installer.luau
]]
local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local Instance, Vector3, CFrame, Enum = roblox.Instance, roblox.Vector3, roblox.CFrame, roblox.Enum

local Loader = require("./lib/RobloxEnv")()
local PremiumAssets = Loader.require(Loader.service("ReplicatedStorage").Shared.Config.PremiumAssets)
local WeaponModels = Loader.require(Loader.service("ReplicatedStorage").Shared.Config.WeaponModels)

local env = {
	Instance = Instance, Vector3 = Vector3, CFrame = CFrame, Enum = Enum,
	math = math, string = string, table = table, ipairs = ipairs, pairs = pairs, pcall = pcall,
	tostring = tostring, type = type, error = error, print = print, setmetatable = setmetatable,
}
local Installer = luau.load(fs.readFile("plugin/IronfrontTools/AssetInstaller.lua"), { debugName = "AssetInstaller", environment = env })()

local failures = 0
local function check(cond, msg)
	if not cond then
		failures += 1
		print("  FAIL " .. msg)
	end
end

local game = Instance.new("DataModel")
local RS, WS, SS = game:GetService("ReplicatedStorage"), game:GetService("Workspace"), game:GetService("ServerStorage")

-- Simulated 3D Importer output for an entry: every required part, sized so the
-- model's extents match entry.Size (times `scale`), optionally textured.
local function fakeImport(entry, opts)
	opts = opts or {}
	local scale = opts.scale or 1
	local model = Instance.new("Model")
	model.Name = opts.name or entry.Model
	local at = CFrame.new(40, 5, -12) -- importer drops the model anywhere
	for i, name in ipairs(entry.Parts) do
		if not (opts.drop and opts.drop == name) then
			local p = Instance.new("MeshPart")
			p.Name = name
			if name == "Origin" then
				p.Size = Vector3.new(0.02, 0.02, 0.02)
				p.CFrame = at
			else
				-- the first real part spans the whole expected box; the rest sit inside it
				local s = Vector3.new(entry.Size[1], entry.Size[2], entry.Size[3]) * scale
				p.Size = i == 2 and s or s * 0.2
				p.CFrame = at
				if opts.textured and i == 2 then
					Instance.new("SurfaceAppearance").Parent = p
				end
			end
			p.Parent = model
		end
	end
	model.Parent = WS
	return model
end

local function ctx()
	return {
		ReplicatedStorage = RS, Workspace = WS, ServerStorage = SS, selection = {}, premium = PremiumAssets,
		points = function(entry)
			if entry.Path[1] ~= "Weapons" then
				return nil
			end
			local pts = { Grip = Vector3.zero }
			for k, v in pairs(WeaponModels[entry.Path[2]].Points) do
				pts[k] = Vector3.new(v[1], v[2], v[3])
			end
			return pts
		end,
	}
end
local function rowFor(rows, model)
	for _, r in ipairs(rows) do
		if r.entry.Model == model then
			return r
		end
	end
end

local ir7 = PremiumAssets.find("IR7")
local torso = PremiumAssets.find("Ashford_Torso")
check(ir7 ~= nil and torso ~= nil, "PremiumAssets lists IR7 and Ashford_Torso")

-- 1. Empty place: everything missing.
local rows = Installer.scan(ctx())
check(#rows == #PremiumAssets.List, "one row per premium asset")
for _, r in ipairs(rows) do
	check(r.status == "missing", r.entry.Model .. " should be missing")
end

-- 2. Fresh imports are detected; problems are reported.
local gun = fakeImport(ir7, { textured = true })
fakeImport(torso, { scale = 3.571, drop = "Ashford_Torso_pouch" }) -- metres-vs-studs import, missing part, no textures
local stray = Instance.new("Model")
stray.Name = "IR7 (1)"
local o = Instance.new("Part")
o.Name = "Origin"
o.Parent = stray
local body = Instance.new("MeshPart")
body.Parent = stray
stray.Parent = WS
rows, unknown = Installer.scan(ctx())
check(rowFor(rows, "IR7").status == "ready", "IR7 ready")
check(#rowFor(rows, "IR7").issues == 0, "clean IR7 import has no issues: " .. table.concat(rowFor(rows, "IR7").issues, "; "))
local tIssues = table.concat(rowFor(rows, "Ashford_Torso").issues, " | ")
check(tIssues:find("rescaled") ~= nil, "wrong scale reported")
check(tIssues:find("missing part Ashford_Torso_pouch") ~= nil, "missing part reported")
check(tIssues:find("no textures") ~= nil, "missing textures reported")
check(#unknown == 1 and unknown[1] == stray, "unrecognised import reported")

-- 3. Install: IR7 moves into ImportedAssets with attachments + shared texture.
local report = Installer.install(ctx(), rows, {})
local installed = RS:FindFirstChild("ImportedAssets") and RS.ImportedAssets:FindFirstChild("Weapons") and RS.ImportedAssets.Weapons:FindFirstChild("CB")
check(installed == gun, "IR7 installed at ImportedAssets.Weapons.CB")
local origin = gun:FindFirstChild("Origin")
check(origin and origin:FindFirstChild("Sight") and origin:FindFirstChild("Muzzle") and origin:FindFirstChild("Support"), "weapon attachment points created")
check((origin.Sight.Position - Vector3.new(0, 0.705, 0.3)).Magnitude < 1e-4, "Sight attachment matches WeaponModels")
local sa = 0
for _, d in ipairs(gun:GetDescendants()) do
	if d:IsA("SurfaceAppearance") then
		sa += 1
	end
end
check(sa >= 9, "SurfaceAppearance shared across non-glass parts (got " .. sa .. ")")
local glass = gun:FindFirstChild("IR7_glass_optic")
check(glass and glass.Transparency > 0.3 and not glass:FindFirstChildOfClass("SurfaceAppearance"), "optic glass left see-through")
check(RS.ImportedAssets.Gear.Alpha:FindFirstChild("Torso") ~= nil, "torso installed (with warnings)")

-- 4. Re-import IR7: must NOT overwrite without replace; with replace, old is backed up.
local gun2 = fakeImport(ir7, { textured = true })
rows = Installer.scan(ctx())
check(rowFor(rows, "IR7").status == "replace", "second import flagged as replace")
report = Installer.install(ctx(), rows, {})
check(RS.ImportedAssets.Weapons.CB == gun, "existing install untouched without confirmation")
check(gun2.Parent == WS, "new import left in Workspace")
check(table.concat(report, "\n"):find("skipped") ~= nil, "skip reported")
report = Installer.install(ctx(), Installer.scan(ctx()), { replace = true })
check(RS.ImportedAssets.Weapons:FindFirstChild("CB") == gun2, "replaced after confirmation")
local backups = SS:FindFirstChild("IronfrontAssetBackups")
check(backups and backups:FindFirstChild("Weapons_CB_1") == gun, "old IR7 moved to ServerStorage backup, not destroyed")
check(#RS.ImportedAssets.Weapons:GetChildren() == 1, "no duplicate CB models")

-- 5. Texture added later to an installed model is shared by "Install / fix".
local torsoModel = RS.ImportedAssets.Gear.Alpha.Torso
Instance.new("SurfaceAppearance").Parent = torsoModel:FindFirstChild("Ashford_Torso_vest")
Installer.install(ctx(), Installer.scan(ctx()), {})
check(torsoModel:FindFirstChild("Ashford_Torso_strap"):FindFirstChildOfClass("SurfaceAppearance") ~= nil, "fix shares a new SurfaceAppearance on an installed model")
check(RS.ImportedAssets.Gear.Alpha.Torso == torsoModel, "fix keeps the installed model")

-- 6. Installed state after everything.
rows = Installer.scan(ctx())
check(rowFor(rows, "IR7").status == "installed", "IR7 shows installed")
check(rowFor(rows, "Ashford_Head").status == "missing", "head still missing")

if failures > 0 then
	print(("plugin installer: %d check(s) failed"):format(failures))
	process.exit(1)
end
print("plugin installer OK (scan, checks, install, attachments, no silent overwrite, backups)")
