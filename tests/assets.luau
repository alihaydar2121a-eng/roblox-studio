--[[
	Asset + animation harness (Lune): builds every weapon rig and faction kit
	with the real runtime code and Roblox datatypes, and checks the pose maths.
	Run: lune run tests/assets.luau
]]

local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local process = require("@lune/process")
local Instance, Vector3, CFrame = roblox.Instance, roblox.Vector3, roblox.CFrame

local Loader = require("./lib/RobloxEnv")()
local shared = Loader.service("ReplicatedStorage").Shared
local WeaponRig = Loader.require(shared.Assets.WeaponRig)
local ModelBuilder = Loader.require(shared.Assets.ModelBuilder)
local WeaponModels = Loader.require(shared.Config.WeaponModels)
local WeaponConfig = Loader.require(shared.Config.WeaponConfig)
local GearModels = Loader.require(shared.Config.GearModels)
local PoseLibrary = Loader.require(shared.Animation.PoseLibrary)

local failures = {}
local function check(cond, msg)
	if not cond then
		table.insert(failures, msg)
	end
end

-- Connectivity: every part must touch a seed box or a part that (transitively) does.
local function aabbIn(frame, part)
	local rel = frame:ToObjectSpace(part.CFrame)
	local r, u, l = rel.RightVector, rel.UpVector, rel.LookVector
	local sz = part.Size
	return rel.Position, Vector3.new(
		math.abs(r.X) * sz.X / 2 + math.abs(u.X) * sz.Y / 2 + math.abs(l.X) * sz.Z / 2,
		math.abs(r.Y) * sz.X / 2 + math.abs(u.Y) * sz.Y / 2 + math.abs(l.Y) * sz.Z / 2,
		math.abs(r.Z) * sz.X / 2 + math.abs(u.Z) * sz.Y / 2 + math.abs(l.Z) * sz.Z / 2)
end
local function floatingParts(frame, parts, seeds, tolerance)
	local boxes = table.clone(seeds)
	local pending = {}
	for _, part in ipairs(parts) do
		local p, e = aabbIn(frame, part)
		table.insert(pending, { p, e, part.Name })
	end
	local tol = Vector3.new(tolerance, tolerance, tolerance)
	local progress = true
	while progress and #pending > 0 do
		progress = false
		for i = #pending, 1, -1 do
			for _, bx in ipairs(boxes) do
				local d = pending[i][1] - bx[1]
				local e = pending[i][2] + bx[2] + tol
				if math.abs(d.X) <= e.X and math.abs(d.Y) <= e.Y and math.abs(d.Z) <= e.Z then
					table.insert(boxes, table.remove(pending, i))
					progress = true
					break
				end
			end
		end
	end
	return pending
end

--------------------------------------------------------------- weapons
print("== Weapons")
for _, id in ipairs(WeaponModels.Ids) do
	local def = WeaponConfig.get(id)
	check(def ~= nil, id .. " missing from WeaponConfig")
	local rig = WeaponRig.build(id)
	local spec = WeaponModels.get(id)
	check(rig.Source == "primitives", id .. " unexpected source")
	check(#rig.Parts == #spec.Parts, id .. " part count mismatch")
	check(rig.Muzzle.Position.Z < -1 or id == "P11", id .. " muzzle not ahead of grip")
	check(rig.Muzzle.Position.Z < -0.5, id .. " muzzle behind grip")
	check(rig.Sight.Position.Y > 0.3, id .. " sight below the bore line")
	check(rig.Groups.mag and #rig.Groups.mag > 0, id .. " has no magazine group")
	if def.Pose == "Rifle" then
		check(rig.Groups.optic and #rig.Groups.optic > 0, id .. " rifle without optic group")
	end
	local length = rig.Spec.Points.Stock[3] - rig.Spec.Points.Muzzle[3]
	for _, piece in ipairs(floatingParts(rig.Handle.CFrame, rig.Parts, { { Vector3.zero, Vector3.new(0.12, 0.12, 0.12) } }, 0.03)) do
		check(false, ("%s part %s floats at %s"):format(id, piece[3], tostring(piece[1])))
	end
	for _, part in ipairs(rig.Parts) do
		local w = part:FindFirstChildOfClass("Weld")
		check(w and w.Part0 == rig.Handle, id .. " part not welded to handle: " .. part.Name)
		check(part.Massless and not part.CanCollide and not part.CanQuery, id .. " part not cosmetic: " .. part.Name)
	end
	print(("  %-4s %-14s %2d parts  length %.2f studs  muzzle z %.2f  source %s"):format(id, def.DisplayName, #rig.Parts, length, rig.Muzzle.Position.Z, rig.Source))
end

--------------------------------------------------------------- imported asset path
print("== Imported-asset path (simulated 3D Importer output)")
do
	local template = Instance.new("Model")
	template.Name = "AR"
	local offset = CFrame.new(5, 2, -3) -- importer places the model anywhere
	local function meshPart(name, pos)
		local m = Instance.new("MeshPart")
		m.Name = name
		m.Size = Vector3.new(0.2, 0.2, 0.2)
		m.CFrame = offset * CFrame.new(pos)
		m.Parent = template
		return m
	end
	meshPart("Origin", Vector3.zero)
	meshPart("AR_body", Vector3.new(0, 0.25, -0.15))
	meshPart("AR_mag_mag", Vector3.new(0, -0.16, -0.5))
	meshPart("AR_metal_optic", Vector3.new(0, 0.76, -0.3))
	meshPart("Alpha_Head_lens_v_goggles", Vector3.new(0, 0.66, -0.7))
	local anchor = Instance.new("Part")
	anchor.CFrame = CFrame.new(0, 10, 0)
	local folder = Instance.new("Folder")
	local spec = WeaponModels.get("AR")
	local result = ModelBuilder.attachImported(template, { anchor = anchor, parent = folder, palette = spec.Palette, materials = WeaponModels.Materials, variants = {} })
	check(result ~= nil, "attachImported failed")
	if result then
		check(#result.parts == 3, "variant part should be dropped / origin removed (got " .. #result.parts .. ")")
		check(result.groups.mag and #result.groups.mag == 1, "mag group missing")
		check(result.groups.optic and #result.groups.optic == 1, "optic group missing")
		for _, part in ipairs(result.parts) do
			local w = part:FindFirstChild("ImportWeld")
			check(w ~= nil, "imported part not welded")
			if part.Name == "AR_body" then
				check((w.C0.Position - Vector3.new(0, 0.25, -0.15)).Magnitude < 1e-4, "pivot offset wrong")
				local c = spec.Palette.body
				check(math.abs(part.Color.R * 255 - c[1]) < 1, "imported part not recoloured")
			end
		end
		print("  pivot, recolour, groups and variants OK")
	end
end

--------------------------------------------------------------- gear
print("== Faction kits")
local LIMBS = {
	{ "Head", Vector3.new(1.25, 1.25, 1.25), "Head", false },
	{ "Torso", Vector3.new(2, 2, 1), "Torso", false },
	{ "Right Arm", Vector3.new(1, 2, 1), "Arm", false },
	{ "Left Arm", Vector3.new(1, 2, 1), "Arm", true },
	{ "Right Leg", Vector3.new(1, 2, 1), "Leg", false },
	{ "Left Leg", Vector3.new(1, 2, 1), "Leg", true },
}
for _, teamId in ipairs({ "Alpha", "Bravo" }) do
	local kit = GearModels[teamId]
	local total = 0
	local allVariants = { goggles = true, cover = true, headset = true, bedroll = true, visor = true, mask = true, antenna = true }
	for _, limb in ipairs(LIMBS) do
		local anchor = Instance.new("Part")
		anchor.Name = limb[1]
		anchor.Size = limb[2]
		anchor.CFrame = CFrame.new(10, 5, 0)
		local folder = Instance.new("Folder")
		local built = ModelBuilder.build(kit[limb[3]], {
			anchor = anchor, parent = folder, palette = kit.Palette, materials = GearModels.Materials,
			mirror = limb[4], variants = allVariants, name = limb[3],
		})
		total += #built.parts
		-- No floating gear: every piece must touch the limb or another piece
		-- that (transitively) touches it. Boxes are compared in limb space.
		local boxes = { { Vector3.zero, limb[2] / 2 } }
		local pending = {}
		for _, part in ipairs(built.parts) do
			local rel = anchor.CFrame:ToObjectSpace(part.CFrame)
			local r, u, l = rel.RightVector, rel.UpVector, rel.LookVector
			local sz = part.Size
			local ext = Vector3.new(
				math.abs(r.X) * sz.X / 2 + math.abs(u.X) * sz.Y / 2 + math.abs(l.X) * sz.Z / 2,
				math.abs(r.Y) * sz.X / 2 + math.abs(u.Y) * sz.Y / 2 + math.abs(l.Y) * sz.Z / 2,
				math.abs(r.Z) * sz.X / 2 + math.abs(u.Z) * sz.Y / 2 + math.abs(l.Z) * sz.Z / 2)
			table.insert(pending, { rel.Position, ext, part.Name })
		end
		local function touches(a, b)
			local d = a[1] - b[1]
			local e = a[2] + b[2] + Vector3.new(0.06, 0.06, 0.06)
			return math.abs(d.X) <= e.X and math.abs(d.Y) <= e.Y and math.abs(d.Z) <= e.Z
		end
		local progress = true
		while progress and #pending > 0 do
			progress = false
			for i = #pending, 1, -1 do
				for _, bx in ipairs(boxes) do
					if touches(pending[i], bx) then
						table.insert(boxes, table.remove(pending, i))
						progress = true
						break
					end
				end
			end
		end
		for _, piece in ipairs(pending) do
			check(false, ("%s %s piece %s floats at %s"):format(teamId, limb[1], piece[3], tostring(piece[1])))
		end
	end
	print(("  %-5s %d gear parts (all variants)"):format(teamId, total))
end
local a, b = GearModels.variantsFor(1), GearModels.variantsFor(1)
check(a.goggles == b.goggles and a.mask == b.mask, "variants not deterministic per player")

--------------------------------------------------------------- poses
print("== Pose maths")
-- Real R6 joint constants.
local R6 = {
	["Right Shoulder"] = { CFrame.new(1, 0.5, 0) * CFrame.Angles(0, math.pi / 2, 0), CFrame.new(-0.5, 0.5, 0) * CFrame.Angles(0, math.pi / 2, 0) },
	["Left Shoulder"] = { CFrame.new(-1, 0.5, 0) * CFrame.Angles(0, -math.pi / 2, 0), CFrame.new(0.5, 0.5, 0) * CFrame.Angles(0, -math.pi / 2, 0) },
	["Right Hip"] = { CFrame.new(1, -1, 0) * CFrame.Angles(0, math.pi / 2, 0), CFrame.new(0.5, 1, 0) * CFrame.Angles(0, math.pi / 2, 0) },
	["Left Hip"] = { CFrame.new(-1, -1, 0) * CFrame.Angles(0, -math.pi / 2, 0), CFrame.new(-0.5, 1, 0) * CFrame.Angles(0, -math.pi / 2, 0) },
	["Neck"] = { CFrame.new(0, 1, 0) * CFrame.Angles(-math.pi / 2, 0, math.pi), CFrame.new(0, -0.5, 0) * CFrame.Angles(-math.pi / 2, 0, math.pi) },
}
local function near(a, b, eps)
	return (a.Position - b.Position).Magnitude < eps and a.LookVector:Dot(b.LookVector) > 1 - eps and a.UpVector:Dot(b.UpVector) > 1 - eps
end
for name, j in pairs(R6) do
	-- Rest pose must produce an identity Transform.
	local rest = PoseLibrary.limb(name, CFrame.new())
	local t = PoseLibrary.toTransform(j[1], j[2], rest)
	check(near(t, CFrame.new(), 1e-4), name .. " rest pose is not identity")
	-- Round trip: Part1 = C0 * T * C1^-1 reproduces the requested pose.
	local want = PoseLibrary.limb(name, CFrame.Angles(0.4, 0.2, -0.3))
	local tt = PoseLibrary.toTransform(j[1], j[2], want)
	check(near(j[1] * tt * j[2]:Inverse(), want, 1e-4), name .. " transform round-trip failed")
end
-- A forward leg swing moves the foot forward (−Z).
local foot = PoseLibrary.limb("Right Hip", CFrame.Angles(0.5, 0, 0)) * Vector3.new(0, -1, 0)
check(foot.Z < -0.3, "positive hip swing should move the foot forward")

-- Arm solving: how close do hands get to the grips, across poses and pitch.
local worstRight, worstLeft = 0, 0
for _, id in ipairs(WeaponModels.Ids) do
	local w = WeaponConfig.get(id)
	local spec = WeaponModels.get(id)
	for _, aim in ipairs({ 0, 1 }) do
		for _, pitch in ipairs({ -0.8, 0, 0.8 }) do
			local blade = PoseLibrary.bladeYaw(w.Pose, 0)
			local hold = PoseLibrary.weaponHold({ pose = w.Pose, aim = aim, sprint = 0, equip = 1, recoil = 0, pitch = pitch, blade = blade })
			-- The muzzle must still point along the aim line in HRP space despite the torso yaw.
			local world = CFrame.Angles(0, blade, 0) * hold
			local expected = Vector3.new(0, math.sin(pitch), -math.cos(pitch))
			check(world.LookVector:Dot(expected) > 0.97, ("%s muzzle off aim (aim=%d pitch=%.1f): %.3f"):format(id, aim, pitch, world.LookVector:Dot(expected)))
			local grip = hold.Position
			local support = hold * Vector3.new(table.unpack(spec.Points.Support))
			local rArm = PoseLibrary.armTo("Right Shoulder", grip)
			local lArm = PoseLibrary.armTo("Left Shoulder", support)
			local rHand = rArm * Vector3.new(0, -1, 0)
			local lHand = lArm * Vector3.new(0, -1, 0)
			worstRight = math.max(worstRight, (rHand - grip).Magnitude)
			worstLeft = math.max(worstLeft, (lHand - support).Magnitude)
		end
	end
end
print(("  worst hand-to-grip gap: right %.2f studs, left %.2f studs (R6 arms are rigid 2-stud limbs)"):format(worstRight, worstLeft))
check(worstRight < 0.35, "right hand misses the grip")
check(worstLeft < 0.9, "left hand far from support point")

-- Locomotion outputs are finite across states.
for _, stance in ipairs({ "Stand", "Sprint", "Crouch" }) do
	for _, air in ipairs({ false, "Jump", "Fall" }) do
		local pose = PoseLibrary.locomotion({ phase = 1.3, speed = 16, stance = stance, air = air or nil, land = 0.5, time = 2, pitch = 0.3 })
		local p = pose.root.Position
		check(p.X == p.X and p.Y == p.Y, "locomotion produced NaN for " .. stance)
	end
end

-- Export weapon + gear specs for the Blender asset build.
local serde = require("@lune/serde")
local export = { weapons = {}, gear = {}, weaponMaterials = WeaponModels.Materials, gearMaterials = GearModels.Materials }
for _, id in ipairs(WeaponModels.Ids) do
	local spec = WeaponModels.get(id)
	export.weapons[id] = { Parts = spec.Parts, Palette = spec.Palette, Points = spec.Points, Name = WeaponConfig.get(id).DisplayName }
end
for _, teamId in ipairs({ "Alpha", "Bravo" }) do
	local kit = GearModels[teamId]
	export.gear[teamId] = { Head = kit.Head, Torso = kit.Torso, Arm = kit.Arm, Leg = kit.Leg, Palette = kit.Palette, Uniform = kit.Uniform }
end
fs.writeDir("assets/specs")
fs.writeFile("assets/specs/asset_specs.json", serde.encode("json", export, true))
print("wrote assets/specs/asset_specs.json")

if #failures > 0 then
	for _, f in ipairs(failures) do
		print("FAIL " .. f)
	end
	process.exit(1)
end
print("assets harness OK")
