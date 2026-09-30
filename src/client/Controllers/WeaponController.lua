--[[
	WeaponController
	Client side of combat and movement stance.

	  Input      PC: LMB fire · RMB aim · R reload · 1/2 or Q switch · Shift sprint ·
	             C / Ctrl crouch · Alt free cursor
	             Gamepad: R2 fire · L2 aim · X reload · Y switch · L3 sprint · B crouch
	             Touch: on-screen FIRE / AIM / R / SWAP / RUN / CROUCH buttons
	  Stance     sprint / crouch / aim + aim pitch sent to the server (SetStance),
	             which sets WalkSpeed and the replicated character attributes.
	  Camera     over-the-shoulder third person; aiming switches to first
	             person with a per-weapon FOV (scope zoom on the scout rifle).
	  Firing     client-predicted cadence, stance-dependent spread and camera
	             recoil; the server validates and resolves every shot.
	Feeds CharacterAnimator (local pose without latency) and ViewModel.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WeaponConfig = require(Shared.Config.WeaponConfig)
local WeaponLogic = require(Shared.Logic.WeaponLogic)
local StanceLogic = require(Shared.Logic.StanceLogic)
local Remotes = require(Shared.Net.Remotes)
local Signal = require(Shared.Util.Signal)

local EffectsController = require(script.Parent.EffectsController)
local SoundPlayer = require(script.Parent.SoundPlayer)
local CharacterAnimator = require(script.Parent.CharacterAnimator)
local ViewModel = require(script.Parent.ViewModel)

local WeaponController = {}
WeaponController.Fired = Signal.new() -- (spreadDegrees)
WeaponController.EquippedChanged = Signal.new() -- (weapon | nil)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local CAMERA_BIND = "IronfrontCombatCamera"
local SHOULDER_OFFSET = Vector3.new(1.75, 0.6, 0)
local BASE_FOV = 70

local remotes = {}
local weapon, weaponId
local character
local triggerHeld = false
local aiming, sprinting, crouching = false, false, false
local lastShot = 0
local spread = 0
local recoilPitch, recoilYaw = 0, 0
local localAmmo = 0
local freeCursor = false
local lastStanceSent = ""
local lastStanceTime = 0
local zoomBeforeAim = nil

local rng = Random.new()
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local function parts()
	local c = player.Character
	if not c then
		return nil
	end
	local humanoid = c:FindFirstChildOfClass("Humanoid")
	local root = c:FindFirstChild("HumanoidRootPart")
	local head = c:FindFirstChild("Head")
	if not humanoid or humanoid.Health <= 0 or not root or not head then
		return nil
	end
	return c, humanoid, root, head
end

local function isReloading()
	return player:GetAttribute("Reloading") == true
end

local function reloadProgress()
	if not isReloading() or not weapon then
		return nil
	end
	local started = player:GetAttribute("ReloadStart") or workspace:GetServerTimeNow()
	return math.clamp((workspace:GetServerTimeNow() - started) / weapon.ReloadTime, 0, 1)
end

local function firstPerson()
	local _, _, _, head = parts()
	return head ~= nil and (camera.CFrame.Position - head.Position).Magnitude < 1.4
end

local function aimPitch()
	return math.asin(math.clamp(camera.CFrame.LookVector.Y, -1, 1))
end

local function stanceName()
	return sprinting and "Sprint" or (crouching and "Crouch" or "Stand")
end

local function sendStance(force)
	local pitch = math.floor(aimPitch() * 20 + 0.5) / 20
	local key = ("%s%s%s%.2f"):format(tostring(sprinting), tostring(crouching), tostring(aiming), pitch)
	local now = os.clock()
	if key ~= lastStanceSent and (force or now - lastStanceTime > 0.1) then
		lastStanceSent = key
		lastStanceTime = now
		remotes.SetStance:FireServer({ sprint = sprinting, crouch = crouching, aim = aiming, pitch = pitch })
	end
end

local function setAiming(value)
	value = value and weapon ~= nil and not isReloading()
	if value then
		sprinting = false
	end
	if aiming ~= value then
		aiming = value
		if aiming then
			zoomBeforeAim = (camera.CFrame.Position - camera.Focus.Position).Magnitude
			player.CameraMode = Enum.CameraMode.LockFirstPerson
		else
			player.CameraMode = Enum.CameraMode.Classic
			-- Return to the zoom the player had before aiming.
			local restore = zoomBeforeAim or 12
			if restore > 1.5 then
				player.CameraMinZoomDistance = restore
				task.delay(0.1, function()
					player.CameraMinZoomDistance = 0.5
				end)
			end
		end
		sendStance(true)
	end
end

local function requestReload()
	if weapon and not isReloading() and localAmmo < weapon.MagSize and (player:GetAttribute("Reserve") or 0) > 0 then
		setAiming(false)
		remotes.Reload:FireServer()
		SoundPlayer.play("Reload")
	end
end

local function aimPoint(c)
	local viewport = camera.ViewportSize
	local ray = camera:ViewportPointToRay(viewport.X / 2, viewport.Y / 2)
	rayParams.FilterDescendantsInstances = { c, camera, workspace:FindFirstChild("ClientFx") }
	local result = workspace:Raycast(ray.Origin, ray.Direction * weapon.Range, rayParams)
	return result and result.Position or (ray.Origin + ray.Direction * weapon.Range)
end

local function currentSpread(root)
	local vel = root.AssemblyLinearVelocity
	local moving = Vector3.new(vel.X, 0, vel.Z).Magnitude > 2
	return (weapon.HipSpreadDegrees + spread) * StanceLogic.spreadMultiplier(weapon, moving, stanceName(), aiming)
end

local function tryFire()
	if not weapon then
		return
	end
	local c, _, root, head = parts()
	if not c or isReloading() or c:GetAttribute("EquippedWeapon") ~= weaponId then
		return
	end
	local equipStart = c:GetAttribute("EquipStart") or 0
	if workspace:GetServerTimeNow() - equipStart < weapon.EquipTime * 0.8 then
		return
	end
	local now = os.clock()
	if now - lastShot < WeaponLogic.fireInterval(weapon) then
		return
	end
	if localAmmo <= 0 then
		triggerHeld = false
		SoundPlayer.play("DryFire")
		requestReload()
		return
	end
	if sprinting then
		sprinting = false
		sendStance(true)
	end
	lastShot = now
	localAmmo -= 1

	local origin = head.Position
	local target = aimPoint(c)
	local cone = math.rad(currentSpread(root))
	local aim = CFrame.lookAt(origin, target)
		* CFrame.Angles(0, 0, rng:NextNumber(0, math.pi * 2))
		* CFrame.Angles(rng:NextNumber(0, cone), 0, 0)
	local direction = aim.LookVector
	remotes.Fire:FireServer({ o = origin, d = direction })

	-- Cosmetic prediction (server decides hits).
	rayParams.FilterDescendantsInstances = { c, camera, workspace:FindFirstChild("ClientFx") }
	local result = workspace:Raycast(origin, direction * weapon.Range, rayParams)
	local hitPos = result and result.Position or (origin + direction * weapon.Range)
	local muzzle = ViewModel.getMuzzle()
	if not muzzle then
		local model = c:FindFirstChild("WeaponModel")
		local handle = model and model:FindFirstChild("Handle")
		local attachment = handle and handle:FindFirstChild("Muzzle")
		muzzle = attachment and attachment.WorldPosition or origin
	end
	EffectsController.flashAt(muzzle)
	EffectsController.tracer(muzzle, hitPos)
	if result then
		EffectsController.impact(hitPos)
	end
	SoundPlayer.play("Shot_" .. weaponId)

	spread = math.min(weapon.MaxSpreadDegrees, spread + weapon.SpreadPerShot)
	local kick = aiming and 0.7 or 1
	recoilPitch += math.rad(weapon.RecoilKickDegrees) * kick
	recoilYaw += math.rad(rng:NextNumber(-1, 1) * weapon.RecoilYawDegrees) * kick
	ViewModel.fire()
	CharacterAnimator.kick(c)
	WeaponController.Fired:Fire(currentSpread(root))
	if not weapon.Automatic then
		triggerHeld = false
	end
end

--------------------------------------------------------------- input

local function onAction(name, state)
	local began = state == Enum.UserInputState.Begin
	local ended = state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel
	if name == "IronfrontFire" then
		if began then
			triggerHeld = true
			tryFire()
		elseif ended then
			triggerHeld = false
		end
	elseif name == "IronfrontAim" then
		local touchOnly = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
		if touchOnly then
			if began then
				setAiming(not aiming) -- toggle on touch
			end
		elseif began then
			setAiming(true)
		elseif ended then
			setAiming(false)
		end
	elseif name == "IronfrontReload" and began then
		requestReload()
	elseif name == "IronfrontSwitch" and began then
		local primary = player:GetAttribute("Primary")
		remotes.EquipWeapon:FireServer(weaponId == primary and "Secondary" or "Primary")
	elseif name == "IronfrontPrimary" and began then
		remotes.EquipWeapon:FireServer("Primary")
	elseif name == "IronfrontSecondary" and began then
		remotes.EquipWeapon:FireServer("Secondary")
	elseif name == "IronfrontSprint" then
		local touchOnly = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
		if touchOnly then
			if began then
				sprinting = not sprinting
			end
		elseif began then
			sprinting = true
		elseif ended then
			sprinting = false
		end
		if sprinting then
			crouching = false
			setAiming(false)
		end
		sendStance(true)
	elseif name == "IronfrontCrouch" and began then
		crouching = not crouching
		if crouching then
			sprinting = false
		end
		sendStance(true)
	end
	return Enum.ContextActionResult.Sink
end

local ACTIONS = {
	{ "IronfrontFire", "FIRE", { Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2 }, UDim2.new(1, -140, 1, -175) },
	{ "IronfrontAim", "AIM", { Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonL2 }, UDim2.new(1, -215, 1, -215) },
	{ "IronfrontReload", "R", { Enum.KeyCode.R, Enum.KeyCode.ButtonX }, UDim2.new(1, -225, 1, -130) },
	{ "IronfrontSwitch", "SWAP", { Enum.KeyCode.Q, Enum.KeyCode.ButtonY }, UDim2.new(1, -150, 1, -255) },
	{ "IronfrontSprint", "RUN", { Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3 }, UDim2.new(0, 40, 1, -250) },
	{ "IronfrontCrouch", "CRCH", { Enum.KeyCode.C, Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonB }, UDim2.new(1, -75, 1, -255) },
	{ "IronfrontPrimary", nil, { Enum.KeyCode.One } },
	{ "IronfrontSecondary", nil, { Enum.KeyCode.Two } },
}

local function bindActions()
	for _, a in ipairs(ACTIONS) do
		ContextActionService:BindAction(a[1], onAction, a[2] ~= nil, table.unpack(a[3]))
		if a[2] then
			ContextActionService:SetTitle(a[1], a[2])
			ContextActionService:SetPosition(a[1], a[4])
		end
	end
end

local function unbindActions()
	for _, a in ipairs(ACTIONS) do
		ContextActionService:UnbindAction(a[1])
	end
end

--------------------------------------------------------------- per frame

local function cameraStep(dt)
	local c, humanoid, root = parts()
	if not c then
		return
	end
	humanoid.AutoRotate = weapon == nil
	if not weapon then
		return
	end
	local fp = firstPerson()
	local look = camera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude > 0.01 then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
	end
	humanoid.CameraOffset = fp and Vector3.zero or SHOULDER_OFFSET
	if UserInputService.MouseEnabled then
		UserInputService.MouseBehavior = freeCursor and Enum.MouseBehavior.Default or Enum.MouseBehavior.LockCenter
	end

	-- FOV: per-weapon aim zoom.
	local targetFov = aiming and weapon.AimFov or (sprinting and BASE_FOV + 6 or BASE_FOV)
	camera.FieldOfView += (targetFov - camera.FieldOfView) * math.min(1, dt * 12)

	-- Camera recoil (applied after the camera module; recovers smoothly).
	if recoilPitch > 0 or math.abs(recoilYaw) > 0 then
		camera.CFrame *= CFrame.Angles(recoilPitch, recoilYaw, 0)
		recoilPitch = math.max(0, recoilPitch - dt * math.rad(14))
		recoilYaw -= recoilYaw * math.min(1, dt * 10)
	end
	spread = math.max(0, spread - weapon.SpreadRecoverPerSecond * dt)

	sendStance(false)

	local vel = root.AssemblyLinearVelocity
	ViewModel.update(dt, {
		firstPerson = fp,
		aiming = aiming,
		sprinting = sprinting,
		speed = Vector3.new(vel.X, 0, vel.Z).Magnitude,
		reload = reloadProgress(),
		character = c,
	})

	if triggerHeld and weapon.Automatic then
		tryFire()
	end
end

--------------------------------------------------------------- equip lifecycle

local function clearWeapon()
	if weapon then
		WeaponController.EquippedChanged:Fire(nil)
	end
	weapon, weaponId = nil, nil
	triggerHeld = false
	setAiming(false)
	ViewModel.destroy()
end

local function onEquippedChanged()
	local c = character
	local id = c and c:GetAttribute("EquippedWeapon")
	local def = id and WeaponConfig.get(id)
	if not def then
		clearWeapon()
		return
	end
	if id == weaponId then
		return
	end
	weapon, weaponId = def, id
	localAmmo = player:GetAttribute("Ammo") or def.MagSize
	spread = 0
	setAiming(false)
	ViewModel.equip(id)
	SoundPlayer.play("Equip")
	WeaponController.EquippedChanged:Fire(def)
end

local function onCharacter(c)
	clearWeapon()
	character = c
	sprinting, crouching = false, false
	lastStanceSent = ""
	local humanoid = c:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	humanoid.AutoRotate = false
	c:GetAttributeChangedSignal("EquippedWeapon"):Connect(onEquippedChanged)
	onEquippedChanged()
	unbindActions()
	RunService:UnbindFromRenderStep(CAMERA_BIND)
	bindActions()
	RunService:BindToRenderStep(CAMERA_BIND, Enum.RenderPriority.Camera.Value + 1, cameraStep)
	humanoid.Died:Connect(function()
		clearWeapon()
		unbindActions()
		RunService:UnbindFromRenderStep(CAMERA_BIND)
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		player.CameraMode = Enum.CameraMode.Classic
		camera.FieldOfView = BASE_FOV
	end)
end

function WeaponController.getWeapon()
	return weapon
end

function WeaponController.getAmmo()
	return localAmmo
end

function WeaponController.getState()
	return { aiming = aiming, sprinting = sprinting, crouching = crouching }
end

function WeaponController.start()
	for _, name in ipairs({ "Fire", "Reload", "EquipWeapon", "SetStance", "SetLoadout" }) do
		remotes[name] = Remotes.get(name)
	end
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)
	CharacterAnimator.setLocalStateProvider(function()
		return { stance = stanceName(), aiming = aiming, pitch = aimPitch() }
	end)

	player:GetAttributeChangedSignal("Ammo"):Connect(function()
		local serverAmmo = player:GetAttribute("Ammo") or 0
		if serverAmmo > localAmmo or os.clock() - lastShot > 0.4 then
			localAmmo = serverAmmo
		end
	end)
	player:GetAttributeChangedSignal("WeaponId"):Connect(function()
		localAmmo = player:GetAttribute("Ammo") or localAmmo
	end)
	player:GetAttributeChangedSignal("Reloading"):Connect(function()
		if isReloading() then
			setAiming(false)
		end
	end)

	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftAlt then
			freeCursor = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftAlt then
			freeCursor = false
		end
	end)

	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)
end

-- Loadout selection for the next deployment (validated by the server).
function WeaponController.setPrimary(id)
	if remotes.SetLoadout then
		remotes.SetLoadout:FireServer(id)
	end
end

return WeaponController
