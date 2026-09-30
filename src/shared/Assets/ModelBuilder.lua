--[[
	ModelBuilder
	Turns primitive specs (Shared.Config.WeaponModels / GearModels) into welded
	parts, or clones an imported Blender model when one exists.

	Imported assets: place Models under ReplicatedStorage.ImportedAssets
	(Weapons/<Id>, Gear/<Faction>/<Head|Torso|Arm|Leg>) — see docs/ASSET_PIPELINE.md.
	Their pivot must be the spec origin. When absent (or a clone fails), the
	primitive fallback is used, so the game never depends on unpublished assets.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModelBuilder = {}

local DEG = math.pi / 180
local materialCache = {}

local function material(name)
	local m = materialCache[name]
	if not m then
		local ok, value = pcall(function()
			return Enum.Material[name]
		end)
		m = ok and value or Enum.Material.SmoothPlastic
		materialCache[name] = m
	end
	return m
end

-- Measured WedgePart slope direction (published by the server's Kit.calibrate).
local function wedgeRise()
	local state = ReplicatedStorage:FindFirstChild("GameState")
	return (state and state:GetAttribute("WedgeRise")) or 1
end

function ModelBuilder.primitiveCFrame(prim, mirror)
	local p, r = prim.p, prim.r
	local x, y, z = p[1], p[2], p[3]
	local rx, ry, rz = 0, 0, 0
	if r then
		rx, ry, rz = r[1] * DEG, r[2] * DEG, r[3] * DEG
	end
	if mirror then
		x, ry, rz = -x, -ry, -rz
	end
	return CFrame.new(x, y, z) * CFrame.fromEulerAnglesXYZ(rx, ry, rz)
end

local function newPart(prim)
	local part
	if prim.k == "wedge" then
		part = Instance.new("WedgePart")
	else
		part = Instance.new("Part")
	end
	if prim.k == "cyl" then
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(prim.s[3], prim.s[1], prim.s[2])
	else
		part.Size = Vector3.new(prim.s[1], prim.s[2], prim.s[3])
	end
	if prim.k == "ell" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	end
	return part
end

local function localFrame(prim, mirror)
	local cf = ModelBuilder.primitiveCFrame(prim, mirror)
	if prim.k == "cyl" then
		cf *= CFrame.Angles(0, math.pi / 2, 0) -- part X axis → spec Z axis
	elseif prim.k == "wedge" and wedgeRise() ~= 1 then
		cf *= CFrame.Angles(0, math.pi, 0)
	end
	return cf
end

local function styleCosmetic(part)
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
end

local function weld(anchor, part, c0, name)
	part.CFrame = anchor.CFrame * c0
	local w = Instance.new("Weld")
	w.Name = name or "GearWeld"
	w.Part0 = anchor
	w.Part1 = part
	w.C0 = c0
	w.Parent = part
end

--[[
	build(spec, opts) -> { parts = {BasePart}, groups = { [group] = {BasePart} } }
	spec: { Parts|pieces list, Palette, Materials }
	opts: anchor (BasePart), offset (CFrame from anchor to spec origin),
	      parent (Instance), mirror (bool), variants (set), name (string),
	      materials (name map), palette (color map), shadows (bool)
]]
function ModelBuilder.build(prims, opts)
	local result = { parts = {}, groups = {} }
	local offset = opts.offset or CFrame.new()
	for _, prim in ipairs(prims) do
		if not prim.v or (opts.variants and opts.variants[prim.v]) then
			local part = newPart(prim)
			styleCosmetic(part)
			local c = opts.palette[prim.c] or { 128, 128, 128 }
			part.Color = Color3.fromRGB(c[1], c[2], c[3])
			part.Material = material(opts.materials[prim.c] or "SmoothPlastic")
			part.CastShadow = opts.shadows ~= false and (prim.s[1] * prim.s[2] * prim.s[3] > 0.02)
			if prim.c == "glass" or prim.c == "lens" then
				part.Transparency = 0.35
				part.Reflectance = 0.25
			end
			part.Name = (opts.name or "Piece") .. (prim.g and ("_" .. prim.g) or "")
			weld(opts.anchor, part, offset * localFrame(prim, opts.mirror))
			part.Parent = opts.parent
			table.insert(result.parts, part)
			if prim.g then
				result.groups[prim.g] = result.groups[prim.g] or {}
				table.insert(result.groups[prim.g], part)
			end
		end
	end
	return result
end

-- Imported model lookup: ReplicatedStorage.ImportedAssets.<path...>
function ModelBuilder.findImported(...)
	local node = ReplicatedStorage:FindFirstChild("ImportedAssets")
	for _, name in ipairs({ ... }) do
		node = node and node:FindFirstChild(name)
	end
	if node and node:IsA("Model") then
		return node
	end
	return nil
end

-- Premium assets carry baked PBR textures (SurfaceAppearance, or a legacy
-- TextureID); those keep their imported look instead of the flat palette.
local function isTextured(part)
	if part:FindFirstChildOfClass("SurfaceAppearance") then
		return true
	end
	return part:IsA("MeshPart") and part.TextureID ~= ""
end
ModelBuilder.isTextured = isTextured

--[[
	attachImported(template, opts) -> result like build(), or nil on failure.
	Clones an imported model (from the Blender pipeline) and welds every
	BasePart to opts.anchor, keeping its offset from the pivot:
	  • a part named "Origin" marks the spec origin (exported by Blender) and is
	    removed; without it the model's pivot is used
	  • object names follow "<Model>_<colourKey>[_<group>][_v_<variant>]":
	    colours/materials are re-applied from opts.palette/opts.materials (except
	    on textured parts), parts join groups (mag, optic) and variant parts not
	    in opts.variants are dropped
]]
function ModelBuilder.attachImported(template, opts)
	local ok, result = pcall(function()
		local clone = template:Clone()
		local originPart = clone:FindFirstChild("Origin", true)
		local pivot = originPart and originPart:IsA("BasePart") and originPart.CFrame or clone:GetPivot()
		if originPart then
			originPart:Destroy()
		end
		local out = { parts = {}, groups = {} }
		local base = opts.offset or CFrame.new()
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("BasePart") then
				local name = d.Name
				local variant = name:match("_v_(%w+)$")
				local keep = not variant or (opts.variants and opts.variants[variant])
				if keep then
					local stem = name:gsub("_v_%w+$", "")
					local group = stem:match("_(mag)$") or stem:match("_(optic)$")
					if group then
						stem = stem:sub(1, -(#group + 2))
					end
					local colourKey = stem:match("_(%a+)$")
					if opts.palette and colourKey and opts.palette[colourKey] and not isTextured(d) then
						local c = opts.palette[colourKey]
						d.Color = Color3.fromRGB(c[1], c[2], c[3])
						d.Material = material(opts.materials and opts.materials[colourKey] or "SmoothPlastic")
						if colourKey == "glass" or colourKey == "lens" then
							d.Transparency = 0.35
						end
					end
					local rel = pivot:ToObjectSpace(d.CFrame)
					styleCosmetic(d)
					for _, j in ipairs(d:GetChildren()) do
						if j:IsA("JointInstance") or j:IsA("WeldConstraint") then
							j:Destroy()
						end
					end
					d.Parent = opts.parent
					weld(opts.anchor, d, base * rel, "ImportWeld")
					table.insert(out.parts, d)
					if group then
						out.groups[group] = out.groups[group] or {}
						table.insert(out.groups[group], d)
					end
				end
			end
		end
		clone:Destroy()
		if #out.parts == 0 then
			error("imported model has no parts")
		end
		return out
	end)
	if ok then
		return result
	end
	warn("[ModelBuilder] imported asset failed, using primitives: " .. tostring(result))
	return nil
end

return ModelBuilder
