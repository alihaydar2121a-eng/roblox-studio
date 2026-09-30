--[[
	ViewModel
	First-person weapon presentation (local only). Active whenever the camera
	is in first person — always while aiming, or when the player zooms in.

	  • same WeaponRig as the replicated third-person weapon (imported mesh or
	    primitive fallback), so first and third person always match
	  • R6-style sleeved + gloved arms in the player's faction colours whose
	    hands track the grip and support points
	  • sway (camera turn lag), walk bob, recoil spring, sprint lower, equip
	    raise, reload tilt with magazine swap
	  • aim-down-sights: the weapon's Sight point is blended onto the camera;
	    optic geometry is hidden and a reticle / scope overlay drawn instead
	  • wall push-back so the weapon never clips through nearby geometry
	  • everything is destroyed on unequip, death or respawn
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WeaponConfig = require(Shared.Config.WeaponConfig)
local GearModels = require(Shared.Config.GearModels)
local WeaponRig = require(Shared.Assets.WeaponRig)
local PoseLibrary = require(Shared.Animation.PoseLibrary)

local ViewModel = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local current -- active viewmodel state
local overlay -- ScreenGui for reticles

local HIP = {
	Rifle = CFrame.new(0.62, -0.72, -1.15),
	Pistol = CFrame.new(0.42, -0.52, -1.35),
}
local SHOULDERS = { Right = Vector3.new(0.95, -1.5, 0.55), Left = Vector3.new(-0.95, -1.5, 0.55) }

local function rgb(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function v3(t)
	return Vector3.new(t[1], t[2], t[3])
end

local function spring(k, d)
	return { x = 0, v = 0, k = k, d = d }
end

local function stepSpring(s, target, dt)
	local a = (target - s.x) * s.k - s.v * s.d
	s.v += a * dt
	s.x += s.v * dt
	return s.x
end

local function buildOverlay()
	overlay = Instance.new("ScreenGui")
	overlay.Name = "IronfrontSights"
	overlay.IgnoreGuiInset = true
	overlay.ResetOnSpawn = false
	overlay.DisplayOrder = 2
	overlay.Enabled = false
	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(5, 5)
	dot.BackgroundColor3 = Color3.fromRGB(255, 70, 60)
	dot.BorderSizePixel = 0
	Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
	dot.Parent = overlay
	local scope = Instance.new("Frame")
	scope.Name = "Scope"
	scope.Size = UDim2.fromScale(1, 1)
	scope.BackgroundTransparency = 1
	scope.Visible = false
	scope.Parent = overlay
	-- Scope: black surround with a circular window, fine crosshair.
	local ring = Instance.new("ImageLabel")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromScale(1, 1)
	ring.SizeConstraint = Enum.SizeConstraint.RelativeYY
	ring.BackgroundTransparency = 1
	ring.Image = ""
	ring.Parent = scope
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2000
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Parent = ring
	Instance.new("UICorner", ring).CornerRadius = UDim.new(1, 0)
	for _, spec in ipairs({ { UDim2.new(1, 0, 0, 1) }, { UDim2.new(0, 1, 1, 0) } }) do
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Position = UDim2.fromScale(0.5, 0.5)
		line.Size = spec[1]
		line.BackgroundColor3 = Color3.new(0, 0, 0)
		line.BorderSizePixel = 0
		line.Parent = ring
	end
	overlay.Parent = player:WaitForChild("PlayerGui")
end

local function armPart(folder, color, material, name)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Color = color
	p.Material = material
	p.Size = Vector3.new(0.5, 0.5, 1)
	p.Parent = folder
	return p
end

function ViewModel.destroy()
	if current then
		current.folder:Destroy()
		current = nil
	end
	if overlay then
		overlay.Enabled = false
	end
end

function ViewModel.equip(weaponId)
	ViewModel.destroy()
	local weapon = WeaponConfig.get(weaponId)
	if not weapon then
		return
	end
	if not overlay then
		buildOverlay()
	end
	local folder = Instance.new("Model")
	folder.Name = "ViewModel"
	local rig = WeaponRig.build(weaponId, { shadows = false, name = "Weapon" })
	rig.Handle.Anchored = true
	-- Anchor every piece and move them together each frame (no physics lag).
	local moveParts, offsets = { rig.Handle }, { CFrame.new() }
	for _, part in ipairs(rig.Parts) do
		local w = part:FindFirstChildWhichIsA("JointInstance")
		table.insert(moveParts, part)
		table.insert(offsets, w and w.C0 or CFrame.new())
		if w then
			w:Destroy()
		end
		part.Anchored = true
		part.CastShadow = false
	end
	rig.Model.Parent = folder

	local teamId = player.Team and player.Team:GetAttribute("TeamId") or "Alpha"
	local kit = GearModels[teamId] or GearModels.Alpha
	local arms = {}
	for _, side in ipairs({ "Right", "Left" }) do
		arms[side] = {
			sleeve = armPart(folder, rgb(kit.Uniform.Arms), Enum.Material.Fabric, side .. "Sleeve"),
			cuff = armPart(folder, rgb(kit.Palette.cloth), Enum.Material.Fabric, side .. "Cuff"),
			glove = armPart(folder, rgb(kit.Palette.glove), Enum.Material.Fabric, side .. "Glove"),
		}
	end
	folder.Parent = camera
	current = {
		id = weaponId, weapon = weapon, rig = rig, folder = folder, arms = arms,
		sway = { x = spring(90, 14), y = spring(90, 14) },
		recoil = spring(260, 20), recoilRot = spring(220, 18),
		lastCam = camera.CFrame, bob = 0, aim = 0, sprint = 0, push = 0,
		equipStart = os.clock(), magHidden = false, moveParts = moveParts, offsets = offsets,
		magLocal = Vector3.new(0, -0.1, -0.45),
	}
	for _, prim in ipairs(rig.Spec.Parts) do
		if prim.g == "mag" then
			current.magLocal = v3(prim.p)
			break
		end
	end
end

function ViewModel.fire()
	if current then
		current.recoil.v += 7 * (current.weapon.RecoilKickDegrees / 0.6) ^ 0.5
		current.recoilRot.v += 5 * current.weapon.RecoilKickDegrees
	end
end

function ViewModel.getMuzzle()
	return current and current.visible and current.rig.Muzzle.WorldPosition or nil
end

local function placeArm(arm, shoulder, hand)
	local dir = hand - shoulder
	local len = dir.Magnitude
	if len < 0.05 then
		return
	end
	local frame = CFrame.lookAt(shoulder, hand)
	local sleeveLen = math.max(0.1, len - 0.45)
	arm.sleeve.Size = Vector3.new(0.52, 0.52, sleeveLen)
	arm.sleeve.CFrame = frame * CFrame.new(0, 0, -sleeveLen / 2)
	arm.cuff.Size = Vector3.new(0.56, 0.56, 0.12)
	arm.cuff.CFrame = frame * CFrame.new(0, 0, -sleeveLen + 0.05)
	arm.glove.Size = Vector3.new(0.46, 0.5, 0.5)
	arm.glove.CFrame = frame * CFrame.new(0, 0, -len + 0.2)
end

--[[
	update(dt, s)
	s: { firstPerson, aiming, sprinting, speed, reload (0..1|nil), character }
]]
function ViewModel.update(dt, s)
	if not current then
		return
	end
	local visible = s.firstPerson
	current.visible = visible
	current.folder.Parent = visible and camera or nil
	local weapon = current.weapon
	overlay.Enabled = visible and current.aim > 0.9 and weapon.Pose == "Rifle"
	if overlay.Enabled then
		overlay.Dot.Visible = not weapon.Scope
		overlay.Scope.Visible = weapon.Scope == true
	end
	if not visible then
		return
	end

	local cam = camera.CFrame
	local rig = current.rig
	local spec = rig.Spec

	-- Blend weights
	local aimTarget = (s.aiming and not s.reload) and 1 or 0
	local stepSize = dt / weapon.AimTime
	current.aim += math.clamp(aimTarget - current.aim, -stepSize, stepSize)
	current.sprint += ((s.sprinting and 1 or 0) - current.sprint) * math.min(1, dt * 10)
	local aim = current.aim * current.aim * (3 - 2 * current.aim)

	-- Sway from camera rotation between frames.
	local delta = current.lastCam:ToObjectSpace(cam)
	local dx, dy = delta:ToOrientation()
	current.lastCam = cam
	local swayScale = 1 - aim * 0.8
	local sx = stepSpring(current.sway.x, math.clamp(-dy * 1.2, -0.25, 0.25), dt)
	local sy = stepSpring(current.sway.y, math.clamp(-dx * 1.2, -0.25, 0.25), dt)

	-- Walk bob
	current.bob += dt * s.speed * 0.55
	local moving = math.clamp(s.speed / 12, 0, 1) * (1 - aim * 0.85)
	local bobX = math.sin(current.bob) * 0.045 * moving
	local bobY = -math.abs(math.cos(current.bob)) * 0.05 * moving

	-- Recoil springs
	local kick = stepSpring(current.recoil, 0, dt)
	local kickRot = stepSpring(current.recoilRot, 0, dt)

	-- Base placement: hip ↔ sights
	local hip = HIP[weapon.Pose] or HIP.Rifle
	local ads = CFrame.new(-v3(spec.Points.Sight))
	local base = hip:Lerp(ads, aim)

	-- Sprint / equip / reload offsets
	local sprintCf = weapon.Pose == "Pistol" and CFrame.new(0, -0.35, 0.2) * CFrame.Angles(-0.6, 0, 0)
		or CFrame.new(-0.2, -0.25, 0.1) * CFrame.Angles(-0.25, 0.8, 0.3)
	base = base:Lerp(base * sprintCf, current.sprint)
	local equip = math.clamp((os.clock() - current.equipStart) / weapon.EquipTime, 0, 1)
	equip = 1 - (1 - equip) ^ 3
	base = (CFrame.new(0, -1.2 * (1 - equip), 0) * CFrame.Angles(-1.1 * (1 - equip), 0, 0)) * base
	if s.reload then
		local t = s.reload
		local k = t < 0.2 and t / 0.2 or (t > 0.85 and (1 - t) / 0.15 or 1)
		base *= CFrame.new(0, -0.1 * k, 0.1 * k) * CFrame.Angles(0.35 * k, 0, 0.6 * k)
	end

	-- Wall push-back: pull the weapon in when something is right in front.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { current.folder, s.character }
	local hit = workspace:Raycast(cam.Position, cam.LookVector * 3, params)
	local pushTarget = hit and math.clamp(3 - hit.Distance, 0, 1.6) or 0
	current.push += (pushTarget - current.push) * math.min(1, dt * 12)

	local offset = CFrame.new(sx * 0.25 * swayScale + bobX, sy * 0.25 * swayScale + bobY - current.push * 0.2, kick * 0.12 + current.push)
		* CFrame.Angles(sy * 0.6 * swayScale + kickRot * 0.02, sx * 0.6 * swayScale, sx * 0.3 * swayScale)
	local weaponCf = cam * offset * base
	local frames = table.create(#current.offsets)
	for i, o in ipairs(current.offsets) do
		frames[i] = weaponCf * o
	end
	workspace:BulkMoveTo(current.moveParts, frames, Enum.BulkMoveMode.FireCFrameChanged)

	-- Hide optic geometry at full aim (reticle overlay takes over).
	WeaponRig.setGroupVisible(rig, "optic", aim < 0.9)
	local hideMag = s.reload ~= nil and s.reload > 0.3 and s.reload < 0.72
	if hideMag ~= current.magHidden then
		current.magHidden = hideMag
		WeaponRig.setGroupVisible(rig, "mag", not hideMag)
	end

	-- Arms
	local grip = weaponCf.Position
	local support = weaponCf * v3(spec.Points.Support)
	if s.reload then
		support = PoseLibrary.reloadHand(weaponCf, current.magLocal, v3(spec.Points.Support), s.reload, cam * Vector3.new(-0.5, -1.4, -0.9))
	end
	placeArm(current.arms.Right, cam * SHOULDERS.Right, grip)
	placeArm(current.arms.Left, cam * SHOULDERS.Left, support)
end

return ViewModel
