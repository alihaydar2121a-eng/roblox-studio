--[[
	CharacterAnimator
	Procedural R6 animation for every character on this client (own and
	remote). Drives Motor6D.Transform from replicated state:
	  movement      root velocity → idle breathing / walk / run / sprint, jump,
	                fall and landing
	  Stance        character attribute "Stand" | "Sprint" | "Crouch"
	  Aiming        character attribute (aim-down-sights pose)
	  AimPitch      character attribute (torso/head/weapon pitch)
	  weapon        character.WeaponModel + EquipStart (equip / switch animation)
	  Reloading     player attribute + ReloadStart (reload with magazine swap)
	  shots         ShotFx events and local fire → recoil impulse
	Layers blend through per-joint exponential smoothing, so transitions
	(walk → sprint, hip → aim, stand → crouch) are continuous.

	The default Animate script is replaced by an empty stub
	(src/character/Animate.client.lua) so nothing else writes these joints.
	All of this is cosmetic and runs locally; combat stays server-side.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PoseLibrary = require(Shared.Animation.PoseLibrary)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local WeaponModels = require(Shared.Config.WeaponModels)
local Remotes = require(Shared.Net.Remotes)

local CharacterAnimator = {}

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera
local rigs = {} -- character -> rig state
local localOverride = nil -- function() -> { stance, aiming, pitch } for the local player

local SMOOTH = 14 -- blend speed (1/s)
local JOINTS = { "Right Shoulder", "Left Shoulder", "Right Hip", "Left Hip", "Neck" }

local function v3(t)
	return Vector3.new(t[1], t[2], t[3])
end

local function magPoint(weaponId)
	local spec = WeaponModels.get(weaponId)
	for _, prim in ipairs(spec and spec.Parts or {}) do
		if prim.g == "mag" then
			return v3(prim.p)
		end
	end
	return Vector3.new(0, -0.1, -0.4)
end

local function setup(character)
	local torso = character:WaitForChild("Torso", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not (torso and root and humanoid) then
		return
	end
	local motors = {}
	for _, name in ipairs(JOINTS) do
		local m = torso:WaitForChild(name, 5)
		if m and m:IsA("Motor6D") then
			motors[name] = m
		end
	end
	local rootJoint = root:WaitForChild("RootJoint", 5)
	if not rootJoint then
		return
	end
	local rig = {
		character = character,
		humanoid = humanoid,
		root = root,
		torso = torso,
		motors = motors,
		rootJoint = rootJoint,
		current = {},
		phase = 0,
		wasAir = false,
		land = 0,
		recoil = 0,
		aim = 0,
		sprint = 0,
		pitch = 0,
		accumulator = 0,
		player = Players:GetPlayerFromCharacter(character),
	}
	rigs[character] = rig
	character.AncestryChanged:Connect(function(_, parent)
		if not parent then
			rigs[character] = nil
		end
	end)
	humanoid.Died:Connect(function()
		rigs[character] = nil -- let physics take the body
	end)
end

local function blend(rig, key, target, alpha)
	local cur = rig.current[key]
	if not cur then
		rig.current[key] = target
		return target
	end
	local nextCf = cur:Lerp(target, alpha)
	rig.current[key] = nextCf
	return nextCf
end

local function weaponRig(character)
	local model = character:FindFirstChild("WeaponModel")
	local handle = model and model:FindFirstChild("Handle")
	local joint = handle and handle:FindFirstChild("WeaponJoint")
	return model, handle, joint
end

local function stateFor(rig)
	local character = rig.character
	if rig.player == localPlayer and localOverride then
		return localOverride()
	end
	return {
		stance = character:GetAttribute("Stance") or "Stand",
		aiming = character:GetAttribute("Aiming") == true,
		pitch = character:GetAttribute("AimPitch") or 0,
	}
end

local function step(rig, dt, now)
	local character, root = rig.character, rig.root
	local alpha = 1 - math.exp(-SMOOTH * dt)
	local st = stateFor(rig)

	-- Movement analysis from replicated physics.
	local vel = root.AssemblyLinearVelocity
	local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
	local air = nil
	if vel.Y > 4 then
		air = "Jump"
	elseif vel.Y < -10 then
		air = "Fall"
	end
	if rig.wasAir and not air then
		rig.land = 1
	end
	rig.wasAir = air ~= nil
	rig.land = math.max(0, rig.land - dt / 0.28)
	local freq = st.stance == "Sprint" and 0.62 or (st.stance == "Crouch" and 0.7 or 0.55)
	rig.phase = (rig.phase + dt * speed * freq) % (math.pi * 2)
	rig.pitch += (st.pitch - rig.pitch) * alpha

	local loco = PoseLibrary.locomotion({
		phase = rig.phase, speed = speed, stance = st.stance, air = air, land = rig.land,
		time = now, pitch = rig.pitch,
	})
	-- Bladed stance while holding a weapon (torso turns, head and hips counter-turn).
	local heldModel = character:FindFirstChild("WeaponModel")
	local heldWeapon = heldModel and WeaponConfig.get(heldModel:GetAttribute("WeaponId"))
	local bladeTarget = heldWeapon and PoseLibrary.bladeYaw(heldWeapon.Pose, st.stance == "Sprint" and 1 or 0) or 0
	rig.blade = (rig.blade or 0) + (bladeTarget - (rig.blade or 0)) * alpha
	local blade = rig.blade
	local rj = rig.rootJoint
	rj.Transform = PoseLibrary.toTransform(rj.C0, rj.C1, blend(rig, "root", loco.root * CFrame.Angles(0, blade, 0), alpha))
	for _, hip in ipairs({ "Right Hip", "Left Hip" }) do
		local m = rig.motors[hip]
		if m then
			m.Transform = PoseLibrary.toTransform(m.C0, m.C1, blend(rig, hip, PoseLibrary.limb(hip, CFrame.Angles(0, -blade, 0) * loco[hip]), alpha))
		end
	end
	local neck = rig.motors["Neck"]
	if neck then
		neck.Transform = PoseLibrary.toTransform(neck.C0, neck.C1, blend(rig, "Neck", PoseLibrary.limb("Neck", CFrame.Angles(0, -blade, 0) * loco.neck), alpha))
	end

	-- Upper body: weapon hold with arms solved onto the grip and support points.
	local model, handle, joint = weaponRig(character)
	local rs, ls = rig.motors["Right Shoulder"], rig.motors["Left Shoulder"]
	if model and joint and rs and ls then
		local weaponId = model:GetAttribute("WeaponId")
		local weapon = WeaponConfig.get(weaponId)
		local spec = WeaponModels.get(weaponId)
		if not (weapon and spec) then
			return
		end
		local equipStart = character:GetAttribute("EquipStart") or 0
		local equip = math.clamp((workspace:GetServerTimeNow() - equipStart) / weapon.EquipTime, 0, 1)
		equip = 1 - (1 - equip) ^ 3
		local reload
		local player = rig.player
		if player and player:GetAttribute("Reloading") then
			local started = player:GetAttribute("ReloadStart") or now
			reload = math.clamp((workspace:GetServerTimeNow() - started) / weapon.ReloadTime, 0, 1)
		end
		local aimTarget = (st.aiming and not reload) and 1 or 0
		local aimStep = dt / weapon.AimTime
		rig.aim += math.clamp(aimTarget - rig.aim, -aimStep, aimStep)
		local sprintTarget = st.stance == "Sprint" and 1 or 0
		rig.sprint += (sprintTarget - rig.sprint) * alpha
		rig.recoil = math.max(0, rig.recoil - dt * 9)

		local hold = PoseLibrary.weaponHold({
			pose = weapon.Pose, aim = rig.aim, sprint = rig.sprint, reload = reload, equip = equip,
			recoil = rig.recoil, pitch = rig.pitch, blade = blade, time = now,
			moving = math.clamp(speed / 12, 0, 1), phase = rig.phase,
		})
		joint.Transform = joint.C0:Inverse() * hold
		local grip = hold.Position
		local support = hold * v3(spec.Points.Support)
		if reload then
			local charge = weapon.Pose == "Pistol" and Vector3.new(0, 0.34, 0.15) or Vector3.new(0, 0.52, 0.3)
			support = PoseLibrary.reloadHand(hold, magPoint(weaponId), v3(spec.Points.Support), reload, nil, charge)
		end
		rs.Transform = PoseLibrary.toTransform(rs.C0, rs.C1, blend(rig, "rs", PoseLibrary.armTo("Right Shoulder", grip), alpha * 1.6))
		ls.Transform = PoseLibrary.toTransform(ls.C0, ls.C1, blend(rig, "ls", PoseLibrary.armTo("Left Shoulder", support), alpha * 1.6))

		-- Magazine leaves the weapon mid-reload (local, cosmetic only).
		local hideMag = reload ~= nil and reload > 0.22 and reload < 0.5
		if rig.magHidden ~= hideMag then
			rig.magHidden = hideMag
			for _, part in ipairs(model:GetDescendants()) do
				if part:IsA("BasePart") and part.Name:match("_mag$") then
					part.Transparency = hideMag and 1 or 0
				end
			end
		end
	elseif rs and ls then
		-- Unarmed: counter-swing arms.
		local a = loco.armsSwing
		rs.Transform = PoseLibrary.toTransform(rs.C0, rs.C1, blend(rig, "rs", PoseLibrary.limb("Right Shoulder", CFrame.Angles(-a, 0, 0.05)), alpha))
		ls.Transform = PoseLibrary.toTransform(ls.C0, ls.C1, blend(rig, "ls", PoseLibrary.limb("Left Shoulder", CFrame.Angles(a, 0, -0.05)), alpha))
	end
end

-- Recoil impulse for a character (local shots and ShotFx for remote shooters).
function CharacterAnimator.kick(character)
	local rig = rigs[character]
	if rig then
		rig.recoil = 1
	end
end

-- Lets WeaponController feed the local player's state without network latency.
function CharacterAnimator.setLocalStateProvider(fn)
	localOverride = fn
end

local function watchPlayer(player)
	if player.Character then
		task.spawn(setup, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		task.spawn(setup, character)
	end)
end

function CharacterAnimator.start()
	for _, player in ipairs(Players:GetPlayers()) do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)

	Remotes.get("ShotFx").OnClientEvent:Connect(function(shooter)
		if typeof(shooter) == "Instance" and shooter:IsA("Player") and shooter.Character then
			CharacterAnimator.kick(shooter.Character)
		end
	end)

	RunService.Stepped:Connect(function(now, dt)
		local camPos = camera.CFrame.Position
		for character, rig in pairs(rigs) do
			if rig.root.Parent then
				-- Distant characters update at a lower rate.
				local distance = (rig.root.Position - camPos).Magnitude
				local interval = distance > 250 and 1 / 10 or (distance > 120 and 1 / 20 or 0)
				rig.accumulator += dt
				if rig.accumulator >= interval then
					local ok, err = pcall(step, rig, rig.accumulator, now)
					rig.accumulator = 0
					if not ok then
						warn("[CharacterAnimator] " .. tostring(err))
						rigs[character] = nil
					end
				end
			end
		end
	end)
end

return CharacterAnimator
