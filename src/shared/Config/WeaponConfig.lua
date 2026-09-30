--[[
	WeaponConfig
	Fictional weapon definitions. Damage values are tuned for 100 HP characters.
]]

local WeaponConfig = {}

WeaponConfig.Weapons = {
	IR7 = {
		Id = "IR7",
		DisplayName = "IR-7 Carbine",
		Damage = 26,
		MinDamage = 17,
		HeadMultiplier = 1.6,
		FalloffStart = 120,
		FalloffEnd = 420,
		Range = 900,
		RPM = 600,
		Automatic = true,
		MagSize = 30,
		ReserveAmmo = 150,
		ReloadTime = 2.2,
		HipSpreadDegrees = 1.1,
		SpreadPerShot = 0.25,
		MaxSpreadDegrees = 3.5,
		SpreadRecoverPerSecond = 6,
		RecoilKickDegrees = 0.6,
		BodyColor = { 48, 50, 54 },
		AccentColor = { 110, 96, 70 },
	},
}

WeaponConfig.DefaultWeapon = "IR7"

function WeaponConfig.get(id)
	return WeaponConfig.Weapons[id]
end

return WeaponConfig
