--[[
	WeaponController
	Client side of ranged combat. Responsibilities:
	  * over-the-shoulder combat camera while a weapon is equipped
	  * input (mouse / gamepad / touch buttons) for fire and reload
	  * client-predicted cadence, spread and visual recoil
	  * sends { o = origin, d = direction } to the server, which is authoritative
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WeaponConfig = require(Shared.Config.WeaponConfig)
local WeaponLogic = require(Shared.Logic.WeaponLogic)
local Remotes = require(Shared.Net.Remotes)
local Signal = require(Shared.Util.Signal)

local EffectsController = require(script.Parent.EffectsController)
local SoundPlayer = require(script.Parent.SoundPlayer)

local WeaponController = {}
WeaponController.Fired = Signal.new() -- (spreadDegrees)
WeaponController.EquippedChanged = Signal.new() -- (weapon | nil)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local FIRE_ACTION = "IronfrontFire"
local RELOAD_ACTION = "IronfrontReload"
local CAMERA_BIND = "IronfrontCombatCamera"
local SHOULDER_OFFSET = Vector3.new(1.75, 0.6, 0)

local fireRemote, reloadRemote
local equippedTool, weapon
local triggerHeld = false
local lastShot = 0
local spread = 0
local recoilPitch = 0
local localAmmo = 0
local freeCursor = false

local rng = Random.new()
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local function getCharacterParts()
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	local head = character:FindFirstChild("Head")
	if not humanoid or humanoid.Health <= 0 or not root or not head then
		return nil
	end
	return character, humanoid, root, head
end

local function isReloading()
	return player:GetAttribute("Reloading") == true
end

local function requestReload()
	if weapon and not isReloading() and localAmmo < weapon.MagSize and (player:GetAttribute("Reserve") or 0) > 0 then
		reloadRemote:FireServer()
		SoundPlayer.play("Reload")
	end
end

local function aimPoint(character)
	local viewport = camera.ViewportSize
	local ray = camera:ViewportPointToRay(viewport.X / 2, viewport.Y / 2)
	rayParams.FilterDescendantsInstances = { character, workspace:FindFirstChild("ClientFx") }
	local result = workspace:Raycast(ray.Origin, ray.Direction * weapon.Range, rayParams)
	return result and result.Position or (ray.Origin + ray.Direction * weapon.Range)
end

local function tryFire()
	if not weapon or not equippedTool then
		return
	end
	local character, _, _, head = getCharacterParts()
	if not character or isReloading() then
		return
	end
	local now = os.clock()
	if now - lastShot < WeaponLogic.fireInterval(weapon) then
		return
	end
	if localAmmo <= 0 then
		triggerHeld = false
		requestReload()
		return
	end
	lastShot = now
	localAmmo -= 1

	local origin = head.Position
	local target = aimPoint(character)
	local cone = math.rad(weapon.HipSpreadDegrees + spread)
	local aim = CFrame.lookAt(origin, target)
		* CFrame.Angles(0, 0, rng:NextNumber(0, math.pi * 2))
		* CFrame.Angles(rng:NextNumber(0, cone), 0, 0)
	local direction = aim.LookVector

	fireRemote:FireServer({ o = origin, d = direction })

	-- Local cosmetic prediction; the server decides what was actually hit.
	rayParams.FilterDescendantsInstances = { character, workspace:FindFirstChild("ClientFx") }
	local result = workspace:Raycast(origin, direction * weapon.Range, rayParams)
	local hitPos = result and result.Position or (origin + direction * weapon.Range)
	local muzzle = EffectsController.muzzleFlash(equippedTool) or origin
	EffectsController.tracer(muzzle, hitPos)
	if result then
		EffectsController.impact(hitPos)
	end
	SoundPlayer.play("Shot")

	spread = math.min(weapon.MaxSpreadDegrees, spread + weapon.SpreadPerShot)
	recoilPitch += math.rad(weapon.RecoilKickDegrees)
	WeaponController.Fired:Fire(weapon.HipSpreadDegrees + spread)

	if not weapon.Automatic then
		triggerHeld = false
	end
end

local function onFireAction(_, state)
	if state == Enum.UserInputState.Begin then
		triggerHeld = true
		tryFire()
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		triggerHeld = false
	end
	return Enum.ContextActionResult.Sink
end

local function onReloadAction(_, state)
	if state == Enum.UserInputState.Begin then
		requestReload()
	end
	return Enum.ContextActionResult.Sink
end

local function combatCameraStep(dt)
	local character, humanoid, root = getCharacterParts()
	if not character or not weapon then
		return
	end
	-- Face the camera direction (client owns its character's physics).
	local look = camera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude > 0.01 then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
	end
	humanoid.CameraOffset = SHOULDER_OFFSET

	if not UserInputService.TouchEnabled or UserInputService.MouseEnabled then
		UserInputService.MouseBehavior = freeCursor and Enum.MouseBehavior.Default or Enum.MouseBehavior.LockCenter
	end

	-- Visual recoil applied after the camera update, decaying back to rest.
	if recoilPitch > 0 then
		camera.CFrame *= CFrame.Angles(recoilPitch, 0, 0)
		recoilPitch = math.max(0, recoilPitch - dt * math.rad(12))
	end
	spread = math.max(0, spread - weapon.SpreadRecoverPerSecond * dt)

	if triggerHeld and weapon.Automatic then
		tryFire()
	end
end

local function unequip()
	if not equippedTool then
		return
	end
	equippedTool, weapon = nil, nil
	triggerHeld = false
	ContextActionService:UnbindAction(FIRE_ACTION)
	ContextActionService:UnbindAction(RELOAD_ACTION)
	RunService:UnbindFromRenderStep(CAMERA_BIND)
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
	local _, humanoid = getCharacterParts()
	if humanoid then
		humanoid.AutoRotate = true
		humanoid.CameraOffset = Vector3.zero
	end
	WeaponController.EquippedChanged:Fire(nil)
end

local function equip(tool)
	local def = WeaponConfig.get(tool:GetAttribute("WeaponId"))
	if not def then
		return
	end
	unequip()
	equippedTool, weapon = tool, def
	localAmmo = player:GetAttribute("Ammo") or def.MagSize
	spread = 0
	local _, humanoid = getCharacterParts()
	if humanoid then
		humanoid.AutoRotate = false
	end
	UserInputService.MouseIconEnabled = false
	ContextActionService:BindAction(FIRE_ACTION, onFireAction, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
	ContextActionService:BindAction(RELOAD_ACTION, onReloadAction, true, Enum.KeyCode.R, Enum.KeyCode.ButtonX)
	ContextActionService:SetTitle(FIRE_ACTION, "FIRE")
	ContextActionService:SetTitle(RELOAD_ACTION, "R")
	ContextActionService:SetPosition(FIRE_ACTION, UDim2.new(1, -150, 1, -170))
	ContextActionService:SetPosition(RELOAD_ACTION, UDim2.new(1, -230, 1, -110))
	RunService:BindToRenderStep(CAMERA_BIND, Enum.RenderPriority.Camera.Value + 1, combatCameraStep)
	WeaponController.EquippedChanged:Fire(def)
end

local function watchCharacter(character)
	unequip()
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child:GetAttribute("WeaponId") then
			equip(child)
		end
	end)
	character.ChildRemoved:Connect(function(child)
		if child == equippedTool then
			unequip()
		end
	end)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	humanoid.Died:Connect(unequip)
	-- Auto-equip the primary weapon when the loadout arrives.
	local backpack = player:WaitForChild("Backpack", 10)
	if not backpack then
		return
	end
	local autoEquipped = false -- once per life, so players can still holster
	local function tryAutoEquip(tool)
		if not autoEquipped and tool:IsA("Tool") and tool:GetAttribute("WeaponId") and humanoid.Health > 0 then
			autoEquipped = true
			task.defer(function()
				if tool.Parent == backpack and player.Character == character then
					humanoid:EquipTool(tool)
				end
			end)
		end
	end
	for _, child in ipairs(backpack:GetChildren()) do
		tryAutoEquip(child)
	end
	backpack.ChildAdded:Connect(tryAutoEquip)
end

function WeaponController.getWeapon()
	return weapon
end

function WeaponController.getAmmo()
	return localAmmo
end

function WeaponController.start()
	fireRemote = Remotes.get("Fire")
	reloadRemote = Remotes.get("Reload")

	player:GetAttributeChangedSignal("Ammo"):Connect(function()
		local serverAmmo = player:GetAttribute("Ammo") or 0
		-- Accept server corrections upward (reload) or when idle; ignore stale values mid-burst.
		if serverAmmo > localAmmo or os.clock() - lastShot > 0.4 then
			localAmmo = serverAmmo
		end
	end)

	-- Hold Left Alt to free the cursor (menus, scoreboard) on PC.
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
		watchCharacter(player.Character)
	end
	player.CharacterAdded:Connect(watchCharacter)
end

return WeaponController
