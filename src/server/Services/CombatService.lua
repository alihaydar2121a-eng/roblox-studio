--[[
	CombatService
	Server-authoritative ranged combat:
	  * tracks per-player ammo / reload / cadence
	  * validates every Fire request (alive, equipped, cadence, ammo, origin, direction)
	  * performs the authoritative raycast and applies damage
	  * attributes kills and publishes CharacterDied for scoring/respawn
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local WeaponLogic = require(Shared.Logic.WeaponLogic)
local Validate = require(Shared.Util.Validate)
local Signal = require(Shared.Util.Signal)
local StanceLogic = require(Shared.Logic.StanceLogic)
local WeaponRig = require(Shared.Assets.WeaponRig)

local Net = require(script.Parent.Parent.Net)
local GameState = require(script.Parent.Parent.GameState)

local CombatService = {}

-- (victimPlayer, killerPlayer?, weaponId?, headshot)
CombatService.CharacterDied = Signal.new()

local states = {} -- player -> loadout state (see equipLoadout)
local lastDamage = {} -- humanoid -> { attacker, weaponId, headshot, time }

local combatCfg = GameConfig.Combat

local function getAliveCharacter(player)
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local head = character:FindFirstChild("Head")
	if not humanoid or humanoid.Health <= 0 or not head then
		return nil
	end
	return character, humanoid, head
end

local function findHumanoidFromPart(hitPart)
	local model = hitPart:FindFirstAncestorOfClass("Model")
	while model do
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			return humanoid, model
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end

local function onDied(player, humanoid)
	local record = lastDamage[humanoid]
	lastDamage[humanoid] = nil
	local killer, weaponId, headshot = nil, nil, false
	if record and os.clock() - record.time <= combatCfg.KillCreditWindow and record.attacker.Parent then
		killer, weaponId, headshot = record.attacker, record.weaponId, record.headshot
	end
	CombatService.CharacterDied:Fire(player, killer, weaponId, headshot)
end

--[[
	Per-player state:
	  loadout = { primary = id, secondary = id }       (chosen on the deploy screen)
	  weapons = { [id] = { ammo, reserve } }          (per life)
	  equipped = id, readyAt (equip delay), lastShot, reloading, reloadToken
	  stanceRequest = { sprint, crouch, aim }
]]
local chosenPrimary = {} -- player -> weapon id (persists across lives)

local HOLD_C0 = {
	Rifle = CFrame.new(0.55, -0.35, -1.05),
	Pistol = CFrame.new(0.25, 0.05, -1.55),
}

local function currentWeapon(state)
	return WeaponConfig.get(state.equipped)
end

local function publish(player, state)
	local weapon = currentWeapon(state)
	local slot = state.weapons[state.equipped]
	player:SetAttribute("WeaponId", weapon.Id)
	player:SetAttribute("Ammo", slot.ammo)
	player:SetAttribute("Reserve", slot.reserve)
	player:SetAttribute("Reloading", state.reloading)
end

local function applyStance(player, state)
	local character = state.character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local stance, aiming, speed = StanceLogic.resolve(state.stanceRequest, state.equipped, state.reloading)
	character:SetAttribute("Stance", stance)
	character:SetAttribute("Aiming", aiming)
	humanoid.WalkSpeed = speed
end

-- Replaces the third-person weapon model welded to the character.
local function attachWeaponModel(character, weaponId)
	local old = character:FindFirstChild("WeaponModel")
	if old then
		old:Destroy()
	end
	local torso = character:FindFirstChild("Torso")
	if not torso then
		return
	end
	local rig = WeaponRig.build(weaponId, { name = "WeaponModel" })
	local weapon = WeaponConfig.get(weaponId)
	local joint = Instance.new("Motor6D")
	joint.Name = "WeaponJoint"
	joint.Part0 = torso
	joint.Part1 = rig.Handle
	joint.C0 = HOLD_C0[weapon.Pose] or HOLD_C0.Rifle
	rig.Handle.CFrame = torso.CFrame * joint.C0
	joint.Parent = rig.Handle
	rig.Model.Parent = character
	character:SetAttribute("EquippedWeapon", weaponId)
	character:SetAttribute("EquipStart", workspace:GetServerTimeNow())
end

local function equip(player, state, weaponId)
	if state.equipped == weaponId or not state.weapons[weaponId] then
		return
	end
	state.reloadToken += 1 -- cancel any reload in progress
	state.reloading = false
	state.equipped = weaponId
	state.readyAt = os.clock() + WeaponConfig.get(weaponId).EquipTime * 0.8
	attachWeaponModel(state.character, weaponId)
	publish(player, state)
	applyStance(player, state)
end

-- Called by SpawnService after a character is spawned and dressed.
function CombatService.equipLoadout(player, character)
	local primary = chosenPrimary[player] or WeaponConfig.DefaultPrimary
	local secondary = WeaponConfig.DefaultSecondary
	local weapons = {}
	for _, id in ipairs({ primary, secondary }) do
		local def = WeaponConfig.get(id)
		weapons[id] = { ammo = def.MagSize, reserve = def.ReserveAmmo }
	end
	local state = {
		loadout = { primary = primary, secondary = secondary },
		weapons = weapons,
		equipped = nil,
		readyAt = 0,
		lastShot = 0,
		reloadToken = 0,
		reloading = false,
		character = character,
		stanceRequest = {},
	}
	states[player] = state
	player:SetAttribute("Primary", primary)
	player:SetAttribute("Secondary", secondary)
	equip(player, state, primary)

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Once(function()
			local model = character:FindFirstChild("WeaponModel")
			if model then
				model:Destroy()
			end
			onDied(player, humanoid)
		end)
	end
end

-- Removes weapons (round end). Characters keep their gear.
function CombatService.disarm(player)
	local state = states[player]
	if state and state.character then
		local model = state.character:FindFirstChild("WeaponModel")
		if model then
			model:Destroy()
		end
		state.character:SetAttribute("EquippedWeapon", nil)
	end
	states[player] = nil
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local function onFire(player, payload)
	if not GameState.isActive() or type(payload) ~= "table" then
		return
	end
	local origin, direction = payload.o, payload.d
	if not Validate.vector3(origin) or not Validate.unitVector3(direction, 0.05) then
		return
	end
	local state = states[player]
	local character, _, head = getAliveCharacter(player)
	if not state or not character or state.character ~= character then
		return
	end
	local weapon = currentWeapon(state)
	local slot = weapon and state.weapons[weapon.Id]
	if not slot or character:GetAttribute("EquippedWeapon") ~= weapon.Id then
		return
	end
	local now = os.clock()
	if state.reloading or slot.ammo <= 0 or now < state.readyAt then
		return
	end
	if not WeaponLogic.canFire(state.lastShot, now, weapon, combatCfg.FireIntervalTolerance) then
		return
	end
	if (origin - head.Position).Magnitude > combatCfg.MaxOriginOffset then
		return
	end

	state.lastShot = now
	slot.ammo -= 1
	player:SetAttribute("Ammo", slot.ammo)

	direction = direction.Unit
	rayParams.FilterDescendantsInstances = { character }
	local result = workspace:Raycast(origin, direction * weapon.Range, rayParams)
	local hitPosition = result and result.Position or (origin + direction * weapon.Range)

	Net.fireAllExcept("ShotFx", player, player, origin, hitPosition)

	if not result then
		return
	end
	local humanoid, model = findHumanoidFromPart(result.Instance)
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local victim = Players:GetPlayerFromCharacter(model)
	if not victim or victim.Team == player.Team then
		return -- no friendly fire; non-player humanoids are ignored in this mode
	end

	local isHead = result.Instance.Name == "Head"
	local damage = WeaponLogic.damageAt(weapon, (result.Position - origin).Magnitude, isHead)
	local hadForceField = model:FindFirstChildOfClass("ForceField") ~= nil
	if not hadForceField then
		lastDamage[humanoid] = { attacker = player, weaponId = weapon.Id, headshot = isHead, time = now }
	end
	humanoid:TakeDamage(damage) -- respects spawn-protection ForceFields

	if not hadForceField then
		Net.fire("HitConfirm", player, { headshot = isHead, killed = humanoid.Health <= 0 })
		Net.fire("DamageTaken", victim, { from = origin, amount = damage })
	end
end

local function onReload(player)
	local state = states[player]
	if not state or state.reloading or not getAliveCharacter(player) then
		return
	end
	local weapon = currentWeapon(state)
	local slot = state.weapons[weapon.Id]
	if slot.ammo >= weapon.MagSize or slot.reserve <= 0 then
		return
	end
	state.reloading = true
	state.reloadToken += 1
	local token = state.reloadToken
	player:SetAttribute("Reloading", true)
	player:SetAttribute("ReloadStart", workspace:GetServerTimeNow())
	applyStance(player, state)
	task.delay(weapon.ReloadTime, function()
		if states[player] ~= state or state.reloadToken ~= token then
			return
		end
		state.reloading = false
		if getAliveCharacter(player) then
			slot.ammo, slot.reserve = WeaponLogic.reloadResult(slot.ammo, slot.reserve, weapon.MagSize)
		end
		publish(player, state)
		applyStance(player, state)
	end)
end

-- EquipWeapon("Primary" | "Secondary")
local function onEquip(player, slotName)
	local state = states[player]
	if not state or not getAliveCharacter(player) or (slotName ~= "Primary" and slotName ~= "Secondary") then
		return
	end
	local id = slotName == "Primary" and state.loadout.primary or state.loadout.secondary
	equip(player, state, id)
end

-- SetStance({ sprint, crouch, aim, pitch })
local function onStance(player, payload)
	local state = states[player]
	if not state or type(payload) ~= "table" or not getAliveCharacter(player) then
		return
	end
	state.stanceRequest = {
		sprint = payload.sprint == true,
		crouch = payload.crouch == true,
		aim = payload.aim == true,
	}
	local pitch = payload.pitch
	if Validate.finiteNumber(pitch) then
		state.character:SetAttribute("AimPitch", math.clamp(math.floor(pitch * 100 + 0.5) / 100, -1.4, 1.4))
	end
	applyStance(player, state)
end

-- SetLoadout(primaryId): applies from the next spawn.
local function onLoadout(player, primaryId)
	if type(primaryId) ~= "string" or not WeaponConfig.isPrimary(primaryId) then
		return
	end
	chosenPrimary[player] = primaryId
	player:SetAttribute("NextPrimary", primaryId)
end

function CombatService.init()
	-- Cadence is enforced separately; the bucket is a coarse flood guard.
	Net.on("Fire", { burst = 20, perSecond = 16 }, onFire)
	Net.on("Reload", { burst = 3, perSecond = 1 }, onReload)
	Net.on("EquipWeapon", { burst = 4, perSecond = 3 }, onEquip)
	Net.on("SetStance", { burst = 12, perSecond = 12 }, onStance)
	Net.on("SetLoadout", { burst = 3, perSecond = 1 }, onLoadout)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
		chosenPrimary[player] = nil
	end)
end

return CombatService
