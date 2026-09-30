--[[
	WeaponModels
	Geometry specs for the five weapons: the single source of truth for both
	the Blender asset build (scripts/blender) and the in-game primitive
	fallback (Shared.Assets.ModelBuilder).

	Frame: origin = right-hand grip point; −Z = barrel/forward; +Y = up;
	+X = right. Units are studs.

	Primitive fields:
	  k  kind: "box" | "cyl" (axis along Z, s = {diameter, diameter, length})
	     | "ell" (ellipsoid, s = full size) | "wedge" (slope rises toward +Z)
	  p  centre {x, y, z};  s  size;  r  rotation degrees {x, y, z} (optional)
	  c  palette key;  g  group ("mag" parts detach during reloads)
	Points: Grip (origin), Support (left hand), Muzzle, Sight (camera eye
	point for aim-down-sights), Stock, Audio (action/sound emitter).
]]

local WeaponModels = {}

local function box(p, s, c, r, g)
	return { k = "box", p = p, s = s, c = c, r = r, g = g }
end
local function cyl(p, d, len, c, r, g)
	return { k = "cyl", p = p, s = { d, d, len }, c = c, r = r, g = g }
end
local function ell(p, s, c, r)
	return { k = "ell", p = p, s = s, c = c, r = r }
end
local function wedge(p, s, c, r)
	return { k = "wedge", p = p, s = s, c = c, r = r }
end

WeaponModels.Materials = {
	body = "SmoothPlastic", metal = "Metal", accent = "SmoothPlastic", rail = "Metal", dark = "SmoothPlastic",
	glass = "Glass", rubber = "Rubber", wood = "Wood", mag = "Metal",
}

-- KR-20 "Warden" infantry rifle: olive polymer furniture, tan handguard, 3× optic.
WeaponModels.AR = {
	Palette = {
		body = { 64, 68, 56 }, metal = { 44, 46, 48 }, accent = { 150, 132, 98 }, rail = { 32, 33, 35 },
		dark = { 22, 22, 24 }, glass = { 70, 120, 140 }, rubber = { 28, 28, 30 }, mag = { 58, 60, 54 },
	},
	Points = {
		Support = { 0, 0.08, -1.36 }, Muzzle = { 0, 0.46, -2.62 }, Sight = { 0, 0.765, 0.32 },
		Stock = { 0, 0.4, 1.26 }, Audio = { 0, 0.45, -0.3 },
	},
	Parts = {
		box({ 0, 0.25, -0.15 }, { 0.24, 0.26, 1.0 }, "body"), -- lower receiver
		box({ 0, 0.46, -0.25 }, { 0.26, 0.2, 1.12 }, "metal"), -- upper receiver
		box({ 0, 0.585, -0.32 }, { 0.16, 0.05, 1.06 }, "rail"), -- top rail
		box({ 0.135, 0.46, -0.22 }, { 0.02, 0.1, 0.26 }, "dark"), -- ejection port
		box({ 0, 0.52, 0.3 }, { 0.3, 0.04, 0.06 }, "metal"), -- charging handle
		box({ 0, 0.43, -1.3 }, { 0.28, 0.3, 0.96 }, "accent"), -- handguard
		box({ 0.145, 0.45, -1.1 }, { 0.02, 0.08, 0.16 }, "dark"),
		box({ 0.145, 0.45, -1.35 }, { 0.02, 0.08, 0.16 }, "dark"),
		box({ 0.145, 0.45, -1.6 }, { 0.02, 0.08, 0.16 }, "dark"),
		box({ -0.145, 0.45, -1.1 }, { 0.02, 0.08, 0.16 }, "dark"),
		box({ -0.145, 0.45, -1.35 }, { 0.02, 0.08, 0.16 }, "dark"),
		box({ -0.145, 0.45, -1.6 }, { 0.02, 0.08, 0.16 }, "dark"),
		box({ 0, 0.59, -1.3 }, { 0.14, 0.04, 0.9 }, "rail"),
		cyl({ 0, 0.46, -2.0 }, 0.09, 0.9, "metal"), -- barrel
		box({ 0, 0.5, -1.86 }, { 0.12, 0.14, 0.1 }, "metal"), -- gas block
		box({ 0, 0.63, -1.76 }, { 0.05, 0.14, 0.05 }, "metal"), -- front sight post
		cyl({ 0, 0.46, -2.5 }, 0.15, 0.24, "metal"), -- muzzle brake
		box({ 0, 0.46, -2.5 }, { 0.16, 0.03, 0.12 }, "dark"), -- brake port
		-- Optic
		box({ 0, 0.635, -0.3 }, { 0.1, 0.06, 0.3 }, "rail", nil, "optic"),
		box({ 0, 0.765, -0.3 }, { 0.15, 0.15, 0.4 }, "metal", nil, "optic"),
		cyl({ 0, 0.765, -0.54 }, 0.2, 0.08, "metal", nil, "optic"),
		cyl({ 0, 0.765, -0.06 }, 0.17, 0.08, "metal", nil, "optic"),
		cyl({ 0, 0.765, -0.585 }, 0.15, 0.02, "glass", nil, "optic"),
		box({ 0.1, 0.77, -0.3 }, { 0.05, 0.06, 0.08 }, "dark", nil, "optic"), -- turret
		-- Grip, trigger, magazine
		box({ 0, -0.12, 0.06 }, { 0.18, 0.46, 0.22 }, "body", { -15, 0, 0 }),
		box({ 0, 0.02, -0.2 }, { 0.05, 0.05, 0.3 }, "metal"),
		box({ 0, 0.07, -0.13 }, { 0.03, 0.1, 0.03 }, "dark"),
		box({ 0, 0.1, -0.46 }, { 0.26, 0.12, 0.32 }, "body"), -- mag well
		box({ 0, -0.16, -0.5 }, { 0.2, 0.6, 0.28 }, "mag", { 12, 0, 0 }, "mag"),
		box({ 0, -0.45, -0.56 }, { 0.22, 0.06, 0.3 }, "dark", { 12, 0, 0 }, "mag"),
		box({ 0, 0.2, -1.36 }, { 0.12, 0.3, 0.12 }, "body"), -- vertical foregrip
		-- Stock
		cyl({ 0, 0.42, 0.52 }, 0.13, 0.52, "metal"),
		box({ 0, 0.37, 0.96 }, { 0.2, 0.38, 0.52 }, "body"),
		box({ 0, 0.6, 0.92 }, { 0.16, 0.06, 0.42 }, "body"),
		box({ 0, 0.36, 1.23 }, { 0.22, 0.44, 0.06 }, "rubber"),
	},
}

-- KC-9 "Talon" carbine: sand furniture, short barrel, skeleton stock, reflex sight.
WeaponModels.CB = {
	Palette = {
		body = { 156, 138, 104 }, metal = { 40, 42, 44 }, accent = { 120, 104, 76 }, rail = { 30, 31, 33 },
		dark = { 20, 20, 22 }, glass = { 150, 60, 50 }, rubber = { 28, 28, 30 }, mag = { 44, 46, 48 },
	},
	Points = {
		Support = { 0, 0.3, -1.08 }, Muzzle = { 0, 0.44, -1.98 }, Sight = { 0, 0.71, 0.3 },
		Stock = { 0, 0.38, 0.98 }, Audio = { 0, 0.44, -0.3 },
	},
	Parts = {
		box({ 0, 0.25, -0.2 }, { 0.22, 0.24, 0.9 }, "body"),
		box({ 0, 0.44, -0.3 }, { 0.24, 0.18, 1.0 }, "metal"),
		box({ 0, 0.555, -0.35 }, { 0.15, 0.045, 0.95 }, "rail"),
		box({ 0.125, 0.44, -0.25 }, { 0.02, 0.09, 0.22 }, "dark"),
		box({ 0, 0.42, -1.12 }, { 0.26, 0.26, 0.62 }, "body"), -- short handguard
		box({ 0, 0.42, -1.12 }, { 0.27, 0.06, 0.5 }, "dark"),
		cyl({ 0, 0.44, -1.62 }, 0.085, 0.6, "metal"),
		cyl({ 0, 0.44, -1.9 }, 0.13, 0.16, "metal"), -- flash hider
		box({ 0, 0.6, -1.36 }, { 0.05, 0.12, 0.05 }, "metal"),
		-- Reflex sight
		box({ 0, 0.6, -0.25 }, { 0.12, 0.05, 0.22 }, "rail", nil, "optic"),
		box({ 0, 0.7, -0.3 }, { 0.14, 0.14, 0.04 }, "metal", nil, "optic"),
		box({ 0, 0.7, -0.3 }, { 0.1, 0.1, 0.02 }, "glass", nil, "optic"),
		box({ 0.065, 0.66, -0.25 }, { 0.02, 0.1, 0.16 }, "metal", nil, "optic"),
		box({ -0.065, 0.66, -0.25 }, { 0.02, 0.1, 0.16 }, "metal", nil, "optic"),
		-- Grip, trigger, magazine
		box({ 0, -0.12, 0.05 }, { 0.17, 0.44, 0.2 }, "body", { -15, 0, 0 }),
		box({ 0, 0.02, -0.2 }, { 0.05, 0.05, 0.28 }, "metal"),
		box({ 0, 0.1, -0.45 }, { 0.24, 0.12, 0.3 }, "body"),
		box({ 0, -0.14, -0.49 }, { 0.19, 0.56, 0.26 }, "mag", { 14, 0, 0 }, "mag"),
		box({ 0, -0.41, -0.56 }, { 0.2, 0.05, 0.28 }, "dark", { 14, 0, 0 }, "mag"),
		box({ 0, 0.24, -1.08 }, { 0.2, 0.12, 0.22 }, "accent"), -- hand stop
		-- Skeleton stock
		box({ 0, 0.46, 0.52 }, { 0.08, 0.06, 0.64 }, "metal"),
		box({ 0, 0.28, 0.55 }, { 0.08, 0.06, 0.55 }, "metal", { 18, 0, 0 }),
		box({ 0, 0.36, 0.86 }, { 0.2, 0.4, 0.08 }, "body"),
		box({ 0, 0.36, 0.93 }, { 0.2, 0.42, 0.05 }, "rubber"),
	},
}

-- MG-44 "Bulwark" support weapon: heavy receiver, box magazine, carry handle, bipod.
WeaponModels.LMG = {
	Palette = {
		body = { 50, 54, 50 }, metal = { 38, 40, 42 }, accent = { 92, 98, 72 }, rail = { 30, 31, 33 },
		dark = { 20, 20, 22 }, glass = { 70, 120, 140 }, rubber = { 26, 26, 28 }, mag = { 92, 98, 72 },
	},
	Points = {
		Support = { 0, 0.2, -1.2 }, Muzzle = { 0, 0.5, -3.02 }, Sight = { 0, 0.82, 0.36 },
		Stock = { 0, 0.42, 1.36 }, Audio = { 0, 0.5, -0.3 },
	},
	Parts = {
		box({ 0, 0.4, -0.3 }, { 0.36, 0.42, 1.3 }, "body"), -- receiver
		box({ 0, 0.64, -0.3 }, { 0.3, 0.08, 1.2 }, "metal"), -- feed cover
		box({ 0, 0.7, -0.1 }, { 0.14, 0.05, 0.7 }, "rail"),
		box({ 0.19, 0.44, -0.2 }, { 0.02, 0.14, 0.32 }, "dark"),
		box({ 0, 0.82, -0.7 }, { 0.08, 0.12, 0.5 }, "metal"), -- carry handle
		box({ 0, 0.74, -0.47 }, { 0.06, 0.12, 0.06 }, "metal"),
		box({ 0, 0.74, -0.93 }, { 0.06, 0.12, 0.06 }, "metal"),
		box({ 0, 0.5, -1.25 }, { 0.34, 0.34, 0.7 }, "accent"), -- handguard
		cyl({ 0, 0.5, -2.1 }, 0.16, 1.3, "metal"), -- heavy barrel
		cyl({ 0, 0.5, -1.8 }, 0.2, 0.08, "dark"),
		cyl({ 0, 0.5, -2.1 }, 0.2, 0.08, "dark"),
		cyl({ 0, 0.5, -2.4 }, 0.2, 0.08, "dark"),
		cyl({ 0, 0.5, -2.88 }, 0.2, 0.26, "metal"),
		box({ 0, 0.68, -2.62 }, { 0.05, 0.16, 0.05 }, "metal"),
		-- Bipod (folded under the barrel)
		box({ 0.06, 0.34, -2.2 }, { 0.04, 0.04, 0.9 }, "metal"),
		box({ -0.06, 0.34, -2.2 }, { 0.04, 0.04, 0.9 }, "metal"),
		box({ 0, 0.36, -2.62 }, { 0.2, 0.08, 0.1 }, "metal"),
		-- Grip, trigger, box magazine
		box({ 0, -0.12, 0.08 }, { 0.2, 0.46, 0.24 }, "body", { -12, 0, 0 }),
		box({ 0, 0.05, -0.2 }, { 0.06, 0.05, 0.34 }, "metal"),
		box({ -0.05, -0.02, -0.62 }, { 0.44, 0.52, 0.52 }, "mag", nil, "mag"),
		box({ -0.05, 0.26, -0.62 }, { 0.3, 0.1, 0.32 }, "dark", nil, "mag"),
		box({ 0, 0.18, -1.2 }, { 0.14, 0.28, 0.14 }, "body"),
		-- Stock
		box({ 0, 0.4, 0.6 }, { 0.26, 0.36, 0.5 }, "body"),
		box({ 0, 0.4, 1.05 }, { 0.22, 0.48, 0.6 }, "body"),
		box({ 0, 0.62, 1.02 }, { 0.16, 0.06, 0.46 }, "body"),
		box({ 0, 0.4, 1.34 }, { 0.24, 0.52, 0.06 }, "rubber"),
		-- Optic
		box({ 0, 0.82, 0.02 }, { 0.14, 0.14, 0.3 }, "metal", nil, "optic"),
		cyl({ 0, 0.82, -0.14 }, 0.16, 0.06, "metal", nil, "optic"),
		cyl({ 0, 0.82, -0.175 }, 0.12, 0.02, "glass", nil, "optic"),
	},
}

-- SR-3 "Kestrel" scout rifle: bolt action, long barrel, walnut-toned stock, scope.
WeaponModels.SR = {
	Palette = {
		body = { 96, 70, 50 }, metal = { 40, 42, 46 }, accent = { 70, 52, 38 }, rail = { 30, 31, 33 },
		dark = { 20, 20, 22 }, glass = { 60, 110, 150 }, rubber = { 26, 26, 28 }, mag = { 40, 42, 46 },
	},
	Points = {
		Support = { 0, 0.28, -1.1 }, Muzzle = { 0, 0.44, -3.16 }, Sight = { 0, 0.72, 0.46 },
		Stock = { 0, 0.36, 1.32 }, Audio = { 0, 0.44, -0.2 },
	},
	Parts = {
		box({ 0, 0.3, -0.7 }, { 0.26, 0.24, 1.7 }, "body"), -- fore-end
		box({ 0, 0.44, -0.2 }, { 0.2, 0.18, 0.9 }, "metal"), -- action
		cyl({ 0, 0.44, -1.95 }, 0.1, 2.1, "metal"), -- barrel
		cyl({ 0, 0.44, -3.0 }, 0.14, 0.3, "metal"), -- suppressor-style brake
		box({ 0.16, 0.46, 0.06 }, { 0.2, 0.05, 0.05 }, "metal"), -- bolt handle
		ell({ 0.28, 0.46, 0.06 }, { 0.09, 0.09, 0.09 }, "metal"),
		-- Scope
		box({ 0, 0.6, -0.36 }, { 0.08, 0.14, 0.06 }, "metal", nil, "optic"),
		box({ 0, 0.6, 0.04 }, { 0.08, 0.14, 0.06 }, "metal", nil, "optic"),
		cyl({ 0, 0.72, -0.16 }, 0.14, 0.9, "metal", nil, "optic"),
		cyl({ 0, 0.72, -0.66 }, 0.24, 0.24, "metal", nil, "optic"),
		cyl({ 0, 0.72, 0.26 }, 0.2, 0.18, "metal", nil, "optic"),
		cyl({ 0, 0.72, -0.785 }, 0.2, 0.02, "glass", nil, "optic"),
		box({ 0, 0.84, -0.16 }, { 0.07, 0.1, 0.07 }, "dark", nil, "optic"),
		box({ 0.1, 0.72, -0.16 }, { 0.1, 0.07, 0.07 }, "dark", nil, "optic"),
		-- Grip, trigger, magazine
		box({ 0, -0.1, 0.1 }, { 0.2, 0.42, 0.24 }, "body", { -20, 0, 0 }),
		box({ 0, 0.06, -0.14 }, { 0.05, 0.05, 0.3 }, "metal"),
		box({ 0, 0.08, -0.4 }, { 0.18, 0.24, 0.3 }, "mag", nil, "mag"),
		-- Stock with cheek riser
		box({ 0, 0.26, 0.58 }, { 0.24, 0.36, 0.7 }, "body"),
		box({ 0, 0.3, 1.0 }, { 0.24, 0.52, 0.6 }, "body"),
		box({ 0, 0.6, 0.9 }, { 0.18, 0.08, 0.5 }, "accent"),
		box({ 0, 0.3, 1.32 }, { 0.26, 0.56, 0.06 }, "rubber"),
	},
}

-- P-11 "Marshal" sidearm: polymer frame, steel slide.
WeaponModels.P11 = {
	Palette = {
		body = { 34, 36, 38 }, metal = { 70, 74, 78 }, accent = { 120, 100, 70 }, rail = { 30, 31, 33 },
		dark = { 18, 18, 20 }, glass = { 70, 120, 140 }, rubber = { 26, 26, 28 }, mag = { 34, 36, 38 },
	},
	Points = {
		Support = { -0.12, -0.02, 0.02 }, Muzzle = { 0, 0.3, -0.62 }, Sight = { 0, 0.43, 1.5 },
		Stock = { 0, 0.2, 0.2 }, Audio = { 0, 0.3, -0.2 },
	},
	Parts = {
		box({ 0, 0.3, -0.18 }, { 0.16, 0.16, 0.86 }, "metal"), -- slide
		box({ 0.085, 0.32, -0.08 }, { 0.01, 0.08, 0.24 }, "dark"), -- ejection port
		box({ 0, 0.31, 0.15 }, { 0.165, 0.12, 0.16 }, "dark"), -- rear serrations
		box({ 0, 0.4, 0.2 }, { 0.12, 0.04, 0.04 }, "dark"), -- rear sight
		box({ 0, 0.4, -0.55 }, { 0.03, 0.04, 0.04 }, "dark"), -- front sight
		box({ 0, 0.18, -0.26 }, { 0.14, 0.1, 0.64 }, "body"), -- frame
		cyl({ 0, 0.3, -0.61 }, 0.07, 0.04, "dark"),
		box({ 0, 0.07, -0.14 }, { 0.04, 0.04, 0.2 }, "body"), -- trigger guard
		box({ 0, -0.12, 0.04 }, { 0.15, 0.42, 0.2 }, "body", { -14, 0, 0 }),
		box({ 0, -0.34, 0.09 }, { 0.14, 0.05, 0.2 }, "mag", { -14, 0, 0 }, "mag"),
	},
}

WeaponModels.Ids = { "AR", "CB", "LMG", "SR", "P11" }

function WeaponModels.get(id)
	return WeaponModels[id]
end

return WeaponModels
