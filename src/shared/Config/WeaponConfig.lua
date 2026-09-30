--[[
	WeaponConfig
	Five original fictional weapons. Damage values assume 100 HP. Geometry lives
	in Shared.Config.WeaponModels; this file is gameplay tuning only.

	Spread: HipSpreadDegrees (standing still, hip fire) is scaled by
	MoveSpreadMultiplier while moving, AimSpreadMultiplier while aiming and
	CrouchSpreadMultiplier while crouched.
]]

local WeaponConfig = {}

local function weapon(t)
	t.MoveSpreadMultiplier = t.MoveSpreadMultiplier or 1.8
	t.AimSpreadMultiplier = t.AimSpreadMultiplier or 0.25
	t.CrouchSpreadMultiplier = t.CrouchSpreadMultiplier or 0.75
	t.SpreadRecoverPerSecond = t.SpreadRecoverPerSecond or 6
	t.EquipTime = t.EquipTime or 0.45
	t.AimTime = t.AimTime or 0.18
	t.AimFov = t.AimFov or 55
	return t
end

WeaponConfig.Weapons = {
	AR = weapon({
		Id = "AR", DisplayName = "KR-20 Warden", Class = "Infantry Rifle", Slot = "Primary", Pose = "Rifle",
		Damage = 27, MinDamage = 18, HeadMultiplier = 1.6, FalloffStart = 140, FalloffEnd = 480, Range = 1000,
		RPM = 620, Automatic = true, MagSize = 30, ReserveAmmo = 150, ReloadTime = 2.3,
		HipSpreadDegrees = 1.2, SpreadPerShot = 0.22, MaxSpreadDegrees = 3.4, RecoilKickDegrees = 0.55, RecoilYawDegrees = 0.18,
		AimFov = 52,
	}),
	CB = weapon({
		Id = "CB", DisplayName = "KC-9 Talon", Class = "Carbine", Slot = "Primary", Pose = "Rifle",
		Damage = 23, MinDamage = 15, HeadMultiplier = 1.5, FalloffStart = 90, FalloffEnd = 320, Range = 800,
		RPM = 760, Automatic = true, MagSize = 30, ReserveAmmo = 180, ReloadTime = 2.0,
		HipSpreadDegrees = 1.0, SpreadPerShot = 0.2, MaxSpreadDegrees = 3.0, RecoilKickDegrees = 0.45, RecoilYawDegrees = 0.22,
		MoveSpreadMultiplier = 1.4, EquipTime = 0.35, AimTime = 0.15, AimFov = 58,
	}),
	LMG = weapon({
		Id = "LMG", DisplayName = "MG-44 Bulwark", Class = "Support Weapon", Slot = "Primary", Pose = "Rifle",
		Damage = 25, MinDamage = 17, HeadMultiplier = 1.4, FalloffStart = 150, FalloffEnd = 520, Range = 1000,
		RPM = 560, Automatic = true, MagSize = 90, ReserveAmmo = 270, ReloadTime = 4.6,
		HipSpreadDegrees = 2.0, SpreadPerShot = 0.16, MaxSpreadDegrees = 4.2, RecoilKickDegrees = 0.5, RecoilYawDegrees = 0.3,
		MoveSpreadMultiplier = 2.2, CrouchSpreadMultiplier = 0.55, EquipTime = 0.8, AimTime = 0.28, AimFov = 55,
	}),
	SR = weapon({
		Id = "SR", DisplayName = "SR-3 Kestrel", Class = "Scout Rifle", Slot = "Primary", Pose = "Rifle",
		Damage = 68, MinDamage = 52, HeadMultiplier = 2.0, FalloffStart = 300, FalloffEnd = 900, Range = 1400,
		RPM = 50, Automatic = false, MagSize = 5, ReserveAmmo = 30, ReloadTime = 3.0,
		HipSpreadDegrees = 3.5, SpreadPerShot = 1.2, MaxSpreadDegrees = 5, RecoilKickDegrees = 2.6, RecoilYawDegrees = 0.4,
		AimSpreadMultiplier = 0.02, MoveSpreadMultiplier = 2.4, EquipTime = 0.6, AimTime = 0.3, AimFov = 22, Scope = true,
	}),
	P11 = weapon({
		Id = "P11", DisplayName = "P-11 Marshal", Class = "Sidearm", Slot = "Secondary", Pose = "Pistol",
		Damage = 22, MinDamage = 13, HeadMultiplier = 1.5, FalloffStart = 60, FalloffEnd = 220, Range = 500,
		RPM = 420, Automatic = false, MagSize = 12, ReserveAmmo = 60, ReloadTime = 1.6,
		HipSpreadDegrees = 1.4, SpreadPerShot = 0.5, MaxSpreadDegrees = 3.5, RecoilKickDegrees = 1.1, RecoilYawDegrees = 0.25,
		MoveSpreadMultiplier = 1.3, EquipTime = 0.3, AimTime = 0.12, AimFov = 62,
	}),
}

WeaponConfig.Primaries = { "AR", "CB", "LMG", "SR" }
WeaponConfig.DefaultPrimary = "AR"
WeaponConfig.DefaultSecondary = "P11"
WeaponConfig.DefaultWeapon = "AR"

function WeaponConfig.get(id)
	return WeaponConfig.Weapons[id]
end

function WeaponConfig.isPrimary(id)
	return table.find(WeaponConfig.Primaries, id) ~= nil
end

return WeaponConfig
