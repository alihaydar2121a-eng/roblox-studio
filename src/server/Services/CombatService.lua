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

local Net = require(script.Parent.Parent.Net)
local GameState = require(script.Parent.Parent.GameState)
local WeaponFactory = require(script.Parent.WeaponFactory)

local CombatService = {}

-- (victimPlayer, killerPlayer?, weaponId?, headshot)
CombatService.CharacterDied = Signal.new()

local states = {} -- player -> { weapon, ammo, reserve, lastShot, reloadToken, reloading, character }
local lastDamage = {} -- humanoid -> { attacker, weaponId, headshot, time }

local combatCfg = GameConfig.Combat

local function setAmmoAttributes(player, state)
	player:SetAttribute("Ammo", state.ammo)
	player:SetAttribute("Reserve", state.reserve)
	player:SetAttribute("Reloading", state.reloading)
	player:SetAttribute("WeaponId", state.weapon.Id)
end

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

-- Called by SpawnService after a character is spawned and dressed.
function CombatService.equipLoadout(player, character)
	local weapon = WeaponConfig.get(WeaponConfig.DefaultWeapon)
	local state = {
		weapon = weapon,
		ammo = weapon.MagSize,
		reserve = weapon.ReserveAmmo,
		lastShot = 0,
		reloadToken = 0,
		reloading = false,
		character = character,
	}
	states[player] = state
	setAmmoAttributes(player, state)

	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		backpack:ClearAllChildren()
		WeaponFactory.create(weapon).Parent = backpack
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Once(function()
			onDied(player, humanoid)
		end)
	end
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
	local tool = character:FindFirstChildOfClass("Tool")
	if not tool or tool:GetAttribute("WeaponId") ~= state.weapon.Id then
		return
	end
	local weapon = state.weapon
	local now = os.clock()
	if state.reloading or state.ammo <= 0 then
		return
	end
	if not WeaponLogic.canFire(state.lastShot, now, weapon, combatCfg.FireIntervalTolerance) then
		return
	end
	if (origin - head.Position).Magnitude > combatCfg.MaxOriginOffset then
		return
	end

	state.lastShot = now
	state.ammo -= 1
	player:SetAttribute("Ammo", state.ammo)

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
	local weapon = state.weapon
	if state.ammo >= weapon.MagSize or state.reserve <= 0 then
		return
	end
	state.reloading = true
	state.reloadToken += 1
	local token = state.reloadToken
	player:SetAttribute("Reloading", true)
	task.delay(weapon.ReloadTime, function()
		if states[player] ~= state or state.reloadToken ~= token then
			return
		end
		state.reloading = false
		if getAliveCharacter(player) then
			state.ammo, state.reserve = WeaponLogic.reloadResult(state.ammo, state.reserve, weapon.MagSize)
		end
		setAmmoAttributes(player, state)
	end)
end

function CombatService.init()
	-- Cadence is enforced separately; the bucket is a coarse flood guard.
	Net.on("Fire", { burst = 20, perSecond = 16 }, onFire)
	Net.on("Reload", { burst = 3, perSecond = 1 }, onReload)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
end

return CombatService
