--[[
	PoseLibrary
	Pure pose maths for the procedural R6 animation system. Poses are expressed
	as "relative CFrames": the desired CFrame of a limb (Part1) in its parent's
	(Part0) space. toTransform() converts that into Motor6D.Transform using the
	joint's own C0/C1, so no axis conventions are hard-coded:

	    Part1 = Part0 * C0 * Transform * C1:Inverse()
	    Transform = C0:Inverse() * rel * C1

	Everything here depends only on CFrame/Vector3 maths (usable in Lune tests).
]]

local PoseLibrary = {}

local CF, V3 = CFrame.new, Vector3.new
local rx, ry, rz = function(a)
	return CFrame.Angles(a, 0, 0)
end, function(a)
	return CFrame.Angles(0, a, 0)
end, function(a)
	return CFrame.Angles(0, 0, a)
end

-- Pivots: parent-space point and limb-space point that coincide (R6 defaults).
PoseLibrary.Joints = {
	["Right Shoulder"] = { parent = V3(1, 0.5, 0), limb = V3(-0.5, 0.5, 0), hand = V3(0, -1, 0) },
	["Left Shoulder"] = { parent = V3(-1, 0.5, 0), limb = V3(0.5, 0.5, 0), hand = V3(0, -1, 0) },
	["Right Hip"] = { parent = V3(1, -1, 0), limb = V3(0.5, 1, 0) },
	["Left Hip"] = { parent = V3(-1, -1, 0), limb = V3(-0.5, 1, 0) },
	["Neck"] = { parent = V3(0, 1, 0), limb = V3(0, -0.5, 0) },
}

function PoseLibrary.toTransform(c0, c1, rel)
	return c0:Inverse() * rel * c1
end

-- Limb rotated by R about its joint pivot.
function PoseLibrary.limb(jointName, R)
	local j = PoseLibrary.Joints[jointName]
	return CF(j.parent) * R * CF(-j.limb)
end

local function frameFrom(a, b)
	local c = a:Cross(b)
	return CFrame.fromMatrix(Vector3.zero, a, b, c)
end

--[[
	armTo(jointName, target) -> rel
	Points a rigid R6 arm so its hand reaches toward `target` (Torso space).
	The arm keeps its palm side facing up/forward. If the target is out of reach
	the shoulder is allowed to slide a little along the arm (up to 0.55 studs)
	which reads as natural reach on a rigid R6 limb.
]]
function PoseLibrary.armTo(jointName, target)
	local j = PoseLibrary.Joints[jointName]
	local v0 = j.hand - j.limb
	local toTarget = target - j.parent
	local dist = toTarget.Magnitude
	if dist < 1e-3 then
		return PoseLibrary.limb(jointName, CFrame.new())
	end
	local d = toTarget / dist
	local a = v0.Unit
	local a2 = V3(0, 0, -1)
	local ref = math.abs(d.Y) > 0.95 and V3(0, 0, -1) or V3(0, 1, 0)
	local d2 = (ref - d * ref:Dot(d)).Unit
	local R = frameFrom(d, d2) * frameFrom(a, a2):Inverse()
	local shift = math.clamp(dist - v0.Magnitude, -0.25, 0.55)
	return CF(j.parent + d * shift) * R * CF(-j.limb)
end

--------------------------------------------------------------- locomotion

--[[
	locomotion(s) -> { root = CFrame (Torso in HumanoidRootPart space),
	                   ["Right Hip"] = R, ["Left Hip"] = R, armsSwing = angle, neck = R }
	s: { phase, speed (studs/s), stance ("Stand"|"Sprint"|"Crouch"), air ("Jump"|"Fall"|nil),
	     land (0..1 remaining landing impulse), time, pitch }
]]
function PoseLibrary.locomotion(s)
	local speed = s.speed
	local moving = math.clamp(speed / 6, 0, 1)
	local sprint = s.stance == "Sprint"
	local crouch = s.stance == "Crouch"
	local amp = sprint and 1.05 or (speed > 13 and 0.8 or 0.55)
	if crouch then
		amp = 0.35
	end
	local swing = math.sin(s.phase) * amp * moving
	local bob = math.abs(math.sin(s.phase)) * (sprint and 0.22 or 0.12) * moving
	local breathe = math.sin(s.time * 1.7) * 0.035 * (1 - moving)
	local lean = sprint and -0.2 or -0.05 * moving
	lean += math.clamp(s.pitch or 0, -1, 1) * 0.12

	local drop = 0
	local rightHip, leftHip = rx(swing), rx(-swing)
	if crouch then
		drop = 1.2
		-- Kneeling crouch: right knee down behind, left foot forward; small steps when moving.
		rightHip = rx(-1.35 + swing * 0.6) * rz(0.05)
		leftHip = rx(0.8 - swing * 0.6) * rz(-0.05)
		lean -= 0.12
	end
	if s.air == "Jump" then
		rightHip, leftHip = rx(0.45), rx(-0.25)
	elseif s.air == "Fall" then
		local flail = math.sin(s.time * 9) * 0.12
		rightHip, leftHip = rx(0.25 + flail) * rz(0.1), rx(-0.15 - flail) * rz(-0.1)
	end
	drop += (s.land or 0) * 0.45

	return {
		root = CF(0, bob * 0.5 + breathe - drop, 0) * rx(lean) * ry(math.sin(s.phase) * 0.05 * moving),
		["Right Hip"] = rightHip,
		["Left Hip"] = leftHip,
		armsSwing = swing * (sprint and 1.2 or 0.9),
		neck = rx(math.clamp(s.pitch or 0, -1.2, 1.2) * 0.55 - lean * 0.5) * rx(breathe * 0.4),
	}
end

--------------------------------------------------------------- weapon holds

-- Grip frames (Handle CFrame in Torso space) per hold pose, before pitch.
local HOLDS = {
	Rifle = {
		Hip = CF(0.5, -0.3, -1.1) * ry(0.06) * rz(0.04),
		Aim = CF(0.42, 0.12, -1.28),
		Sprint = CF(0.2, -0.55, -0.85) * ry(0.95) * rx(-0.45),
		Reload = CF(0.42, -0.3, -1.1) * rz(0.55) * rx(0.28),
		Low = CF(0.4, -1.1, -0.6) * rx(-1.1),
	},
	Pistol = {
		Hip = CF(0.22, -0.15, -1.42),
		Aim = CF(0.18, 0.28, -1.55),
		Sprint = CF(0.62, -0.95, -0.55) * rx(-1.25),
		Reload = CF(0.2, -0.2, -1.3) * rz(0.5) * rx(0.35),
		Low = CF(0.5, -1.1, -0.4) * rx(-1.3),
	},
}
PoseLibrary.Holds = HOLDS

local CHEST = CF(0, 0.75, 0)

local function lerp(a, b, t)
	return a:Lerp(b, math.clamp(t, 0, 1))
end

-- Bladed shooting stance: the torso turns so the support shoulder leads.
PoseLibrary.BladeYaw = { Rifle = -0.42, Pistol = -0.18 }

function PoseLibrary.bladeYaw(pose, sprint)
	return (PoseLibrary.BladeYaw[pose] or 0) * (1 - 0.8 * (sprint or 0))
end

--[[
	weaponHold(w) -> handle CFrame in Torso space
	w: { pose ("Rifle"|"Pistol"), aim (0..1), sprint (0..1), reload (0..1 phase or nil),
	     equip (0..1, 1 = fully equipped), recoil (0..1), pitch (radians),
	     blade (torso yaw to counter, radians), time, moving (0..1), phase }
]]
function PoseLibrary.weaponHold(w)
	local set = HOLDS[w.pose] or HOLDS.Rifle
	local cf = lerp(set.Hip, set.Aim, w.aim)
	cf = lerp(cf, set.Sprint, w.sprint)
	if w.reload then
		-- Tilt in, hold, tilt back.
		local t = w.reload
		local k = t < 0.2 and t / 0.2 or (t > 0.85 and (1 - t) / 0.15 or 1)
		cf = lerp(cf, set.Reload, k)
	end
	cf = lerp(set.Low, cf, w.equip)
	local pitch = math.clamp(w.pitch or 0, -1.3, 1.3) * (1 - w.sprint)
	cf = CHEST * rx(pitch) * CHEST:Inverse() * cf
	if w.recoil and w.recoil > 0 then
		cf *= CF(0, 0.02 * w.recoil, 0.28 * w.recoil) * rx(0.12 * w.recoil)
	end
	-- Breathing sway at rest, bob while walking (reduced when aiming).
	local t = w.time or 0
	local calm = 1 - 0.6 * w.aim
	local moving = w.moving or 0
	local ph = w.phase or 0
	cf = CF(math.sin(ph) * 0.03 * moving * calm, math.abs(math.cos(ph)) * -0.04 * moving * calm + math.sin(t * 1.4) * 0.012 * calm, 0)
		* cf * rx(math.sin(t * 1.4 + 0.6) * 0.008 * calm) * ry(math.sin(t * 0.9) * 0.01 * calm)
	-- Counter the bladed torso so the muzzle stays on the aim line.
	if w.blade and w.blade ~= 0 then
		cf = ry(-w.blade) * cf
	end
	return cf
end

--[[
	Left hand target during a reload (keyframed path):
	  0.00–0.18 support → magazine      0.18–0.40 pull mag down to the belt pouch
	  0.40–0.62 fresh mag up to the well 0.62–0.82 hand to the charging handle
	  0.82–1.00 back to the support grip
	chargePoint is optional (pistols rack the slide at the rear sight instead).
]]
local function ease(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

function PoseLibrary.reloadHand(hold, magPoint, supportPoint, t, belt, chargePoint)
	local mag = hold * magPoint
	local support = hold * supportPoint
	belt = belt or V3(-0.55, -0.75, -0.75) -- Torso space default
	local charge = hold * (chargePoint or V3(0, 0.5, 0.25))
	if t < 0.18 then
		return support:Lerp(mag, ease(t / 0.18))
	elseif t < 0.4 then
		return mag:Lerp(belt, ease((t - 0.18) / 0.22))
	elseif t < 0.62 then
		return belt:Lerp(mag, ease((t - 0.4) / 0.22))
	elseif t < 0.82 then
		return mag:Lerp(charge, ease((t - 0.62) / 0.2))
	end
	return charge:Lerp(support, ease((t - 0.82) / 0.18))
end

return PoseLibrary
