--[[
	WeaponRig
	Builds a weapon model (imported mesh if available, else primitives) around
	an invisible Handle at the grip point, with attachments for the muzzle,
	sight, support hand and audio. Used for the replicated third-person weapon
	(server) and the first-person viewmodel (client), so both always match.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local WeaponModels = require(Shared.Config.WeaponModels)
local ModelBuilder = require(script.Parent.ModelBuilder)

local WeaponRig = {}

local function v3(t)
	return Vector3.new(t[1], t[2], t[3])
end

--[[
	build(weaponId, opts) -> rig
	opts.shadows (bool), opts.name
	rig = { Model, Handle, Muzzle, Sight, Support, Audio (Attachments),
	        Groups = { mag = {...}, optic = {...} }, Source = "imported"|"primitives" }
]]
function WeaponRig.build(weaponId, opts)
	opts = opts or {}
	local spec = WeaponModels.get(weaponId)
	assert(spec, "unknown weapon model " .. tostring(weaponId))
	local model = Instance.new("Model")
	model.Name = opts.name or ("Weapon_" .. weaponId)
	model:SetAttribute("WeaponId", weaponId)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.2, 0.2, 0.2)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.CanQuery = false
	handle.CanTouch = false
	handle.Massless = true
	handle.Anchored = false
	handle.CastShadow = false
	handle.Parent = model
	model.PrimaryPart = handle

	local built
	local source = "primitives"
	local imported = ModelBuilder.findImported("Weapons", weaponId)
	if imported then
		built = ModelBuilder.attachImported(imported, { anchor = handle, parent = model, palette = spec.Palette, materials = WeaponModels.Materials })
		if built then
			source = "imported"
		end
	end
	if not built then
		built = ModelBuilder.build(spec.Parts, {
			anchor = handle, parent = model, palette = spec.Palette, materials = WeaponModels.Materials,
			name = weaponId, shadows = opts.shadows,
		})
	end

	local rig = { Model = model, Handle = handle, Groups = built.groups, Parts = built.parts, Source = source, Spec = spec }
	for name, point in pairs(spec.Points) do
		local a = Instance.new("Attachment")
		a.Name = name
		a.Position = v3(point)
		a.Parent = handle
		rig[name] = a
	end
	model:SetAttribute("AssetSource", source)
	return rig
end

-- Show/hide a part group locally (e.g. hide the optic while aiming, drop the mag).
function WeaponRig.setGroupVisible(rig, group, visible)
	for _, part in ipairs(rig.Groups[group] or {}) do
		part.LocalTransparencyModifier = visible and 0 or 1
	end
end

return WeaponRig
