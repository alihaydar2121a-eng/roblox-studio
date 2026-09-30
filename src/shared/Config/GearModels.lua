--[[
	GearModels
	Faction soldier kits as primitive specs in R6 limb-local frames (same
	primitive format as WeaponModels). Used by the Blender asset build and by
	the in-game primitive fallback; every piece is welded to its R6 limb so it
	moves with the rig and never floats.

	Limb frames (R6 part centres): Head is visually ~1.2 studs cube (SpecialMesh
	head); Torso 2×2×1; arms/legs 1×2×1. −Z is the character's front.
	Keys: Head, Torso, Arm, Leg. Arm/Leg pieces are authored for the RIGHT side
	(+X = outside) and mirrored for the left.
	Optional field v = variant name; a player gets a stable variant set.
]]

local GearModels = {}

local function box(p, s, c, r, v)
	return { k = "box", p = p, s = s, c = c, r = r, v = v }
end
local function ell(p, s, c, r, v)
	return { k = "ell", p = p, s = s, c = c, r = r, v = v }
end
local function cyl(p, d, len, c, r, v)
	return { k = "cyl", p = p, s = { d, d, len }, c = c, r = r, v = v }
end
local function wedge(p, s, c, r, v)
	return { k = "wedge", p = p, s = s, c = c, r = r, v = v }
end

GearModels.Materials = {
	helmet = "SmoothPlastic", helmetDark = "SmoothPlastic", vest = "Fabric", plate = "Fabric", pouch = "Fabric",
	strap = "Fabric", pack = "Fabric", glove = "Fabric", boot = "Leather", sole = "Rubber", knee = "SmoothPlastic",
	lens = "Glass", metal = "Metal", camoA = "Fabric", camoB = "Fabric", band = "SmoothPlastic", cloth = "Fabric",
}

---------------------------------------------------------------- Ashford Coalition
-- Olive rounded helmet with cover and goggles, plate carrier with triple mag
-- pouches, rucksack with bedroll, tan gloves, brown boots, olive/tan camo.
GearModels.Alpha = {
	Uniform = { Torso = { 88, 96, 62 }, Arms = { 88, 96, 62 }, Legs = { 76, 84, 56 } },
	Palette = {
		helmet = { 84, 92, 60 }, helmetDark = { 60, 66, 44 }, vest = { 104, 108, 76 }, plate = { 94, 100, 68 },
		pouch = { 112, 114, 80 }, strap = { 62, 66, 46 }, pack = { 92, 96, 64 }, glove = { 150, 132, 96 },
		boot = { 88, 64, 44 }, sole = { 30, 28, 26 }, knee = { 64, 70, 48 }, lens = { 60, 80, 70 },
		metal = { 50, 52, 50 }, camoA = { 66, 74, 46 }, camoB = { 134, 120, 86 }, band = { 214, 190, 90 }, cloth = { 70, 78, 50 },
	},
	Head = {
		ell({ 0, 0.44, 0.04 }, { 1.46, 1.02, 1.52 }, "helmet"), -- shell
		ell({ 0, 0.2, 0.04 }, { 1.56, 0.2, 1.64 }, "helmetDark"), -- rim
		box({ 0.73, 0.28, 0.02 }, { 0.06, 0.14, 0.9 }, "helmetDark"), -- side rails
		box({ -0.73, 0.28, 0.02 }, { 0.06, 0.14, 0.9 }, "helmetDark"),
		box({ 0, 0.5, -0.72 }, { 0.32, 0.22, 0.1 }, "metal"), -- mount
		box({ 0, 0.66, -0.6 }, { 0.92, 0.16, 0.2 }, "strap", nil, "goggles"),
		box({ 0.22, 0.66, -0.71 }, { 0.34, 0.14, 0.04 }, "lens", nil, "goggles"),
		box({ -0.22, 0.66, -0.71 }, { 0.34, 0.14, 0.04 }, "lens", nil, "goggles"),
		ell({ 0, 0.72, 0.1 }, { 1.2, 0.5, 1.1 }, "camoA", nil, "cover"), -- helmet cover blotch
		box({ 0.62, -0.12, 0 }, { 0.14, 0.34, 0.34 }, "helmetDark", nil, "headset"), -- ear cups
		box({ -0.62, -0.12, 0 }, { 0.14, 0.34, 0.34 }, "helmetDark", nil, "headset"),
		box({ 0.6, -0.3, -0.14 }, { 0.04, 0.44, 0.06 }, "strap"), -- chin straps
		box({ -0.6, -0.3, -0.14 }, { 0.04, 0.44, 0.06 }, "strap"),
	},
	Torso = {
		box({ 0, 0.14, 0 }, { 2.1, 1.5, 1.16 }, "vest"),
		box({ 0, 0.2, -0.62 }, { 1.5, 1.1, 0.1 }, "plate"),
		box({ 0, 0.2, 0.62 }, { 1.5, 1.1, 0.1 }, "plate"),
		box({ -0.52, -0.3, -0.74 }, { 0.44, 0.52, 0.2 }, "pouch"), -- mag pouches
		box({ 0, -0.3, -0.74 }, { 0.44, 0.52, 0.2 }, "pouch"),
		box({ 0.52, -0.3, -0.74 }, { 0.44, 0.52, 0.2 }, "pouch"),
		box({ -0.52, -0.05, -0.85 }, { 0.44, 0.08, 0.04 }, "strap"),
		box({ 0, -0.05, -0.85 }, { 0.44, 0.08, 0.04 }, "strap"),
		box({ 0.52, -0.05, -0.85 }, { 0.44, 0.08, 0.04 }, "strap"),
		box({ 0.55, 0.52, -0.72 }, { 0.36, 0.36, 0.16 }, "pouch"), -- radio / admin pouch
		box({ 0.62, 0.95, 0 }, { 0.42, 0.12, 1.2 }, "strap"), -- shoulder straps
		box({ -0.62, 0.95, 0 }, { 0.42, 0.12, 1.2 }, "strap"),
		box({ 0, -0.88, 0 }, { 2.08, 0.24, 1.12 }, "strap"), -- belt
		box({ 0, -0.88, -0.57 }, { 0.3, 0.2, 0.04 }, "metal"), -- buckle
		box({ -0.9, -0.78, -0.3 }, { 0.3, 0.4, 0.34 }, "pouch"), -- utility pouch
		box({ -0.46, 0.5, -0.7 }, { 0.36, 0.22, 0.06 }, "band"), -- faction patch
		-- Rucksack
		box({ 0, 0.05, 0.86 }, { 1.52, 1.44, 0.6 }, "pack"),
		box({ 0, -0.2, 1.18 }, { 1.2, 0.6, 0.1 }, "pouch"),
		box({ 0.8, -0.05, 0.86 }, { 0.14, 0.9, 0.44 }, "pouch"),
		box({ -0.8, -0.05, 0.86 }, { 0.14, 0.9, 0.44 }, "pouch"),
		cyl({ 0, 0.92, 0.84 }, 0.46, 1.56, "camoB", { 0, 90, 0 }, "bedroll"),
		box({ 0.4, 0.4, 1.17 }, { 0.08, 0.9, 0.04 }, "strap"),
		box({ -0.4, 0.4, 1.17 }, { 0.08, 0.9, 0.04 }, "strap"),
		-- Camo patches on the shirt
		box({ -0.8, -0.55, -0.52 }, { 0.4, 0.3, 0.02 }, "camoA"),
		box({ 0.78, 0.7, -0.52 }, { 0.3, 0.26, 0.02 }, "camoB"),
	},
	Arm = {
		box({ 0, 0.62, 0 }, { 1.08, 0.72, 1.08 }, "cloth"), -- upper sleeve
		box({ 0.545, 0.55, 0 }, { 0.03, 0.42, 0.5 }, "band"), -- shoulder flag
		box({ 0, -0.26, 0 }, { 1.06, 0.18, 1.06 }, "cloth"), -- rolled cuff
		box({ 0.51, 0.1, -0.2 }, { 0.02, 0.36, 0.3 }, "camoB"),
		box({ 0, -0.8, 0 }, { 1.08, 0.44, 1.08 }, "glove"),
		box({ 0, -0.96, -0.3 }, { 0.9, 0.12, 0.5 }, "helmetDark"), -- knuckle guard
	},
	Leg = {
		box({ 0, -0.76, -0.06 }, { 1.08, 0.5, 1.2 }, "boot"),
		box({ 0, -0.97, -0.06 }, { 1.12, 0.08, 1.24 }, "sole"),
		box({ 0, -0.52, 0 }, { 1.06, 0.12, 1.06 }, "strap"), -- blousing band
		box({ 0, 0, -0.53 }, { 0.78, 0.5, 0.12 }, "knee"),
		box({ 0.53, 0.25, 0.02 }, { 0.08, 0.52, 0.58 }, "pouch"), -- cargo pocket
		box({ 0.52, 0.56, 0.02 }, { 0.06, 0.08, 0.6 }, "strap"),
		box({ -0.51, 0.4, -0.2 }, { 0.02, 0.4, 0.34 }, "camoA"),
		box({ 0.1, 0.6, 0.51 }, { 0.4, 0.3, 0.02 }, "camoB"),
	},
}

---------------------------------------------------------------- Varn Directorate
-- Angular dark helmet with crest and smoked visor, face mask, blue-grey plate
-- rig with shoulder guards, hard-shell radio pack with antenna, black gloves
-- and boots, grey/blue digital-style patches.
GearModels.Bravo = {
	Uniform = { Torso = { 62, 68, 80 }, Arms = { 62, 68, 80 }, Legs = { 52, 56, 64 } },
	Palette = {
		helmet = { 58, 62, 70 }, helmetDark = { 36, 38, 44 }, vest = { 70, 82, 104 }, plate = { 56, 64, 82 },
		pouch = { 48, 54, 64 }, strap = { 32, 34, 40 }, pack = { 44, 48, 56 }, glove = { 26, 26, 30 },
		boot = { 30, 30, 34 }, sole = { 18, 18, 20 }, knee = { 40, 44, 54 }, lens = { 40, 60, 80 },
		metal = { 110, 116, 124 }, camoA = { 84, 92, 108 }, camoB = { 44, 50, 62 }, band = { 120, 200, 230 }, cloth = { 54, 60, 72 },
	},
	Head = {
		box({ 0, 0.4, 0.02 }, { 1.36, 0.5, 1.42 }, "helmet"), -- angular shell
		wedge({ 0, 0.72, -0.34 }, { 1.3, 0.2, 0.74 }, "helmet"), -- sloped brow
		box({ 0, 0.72, 0.28 }, { 1.3, 0.2, 0.84 }, "helmet"),
		box({ 0, 0.85, 0.06 }, { 0.18, 0.08, 1.2 }, "helmetDark"), -- crest
		box({ 0, 0.16, 0.64 }, { 1.44, 0.28, 0.3 }, "helmetDark", { -18, 0, 0 }), -- neck guard
		box({ 0.69, 0.18, 0.18 }, { 0.06, 0.34, 0.84 }, "helmetDark"), -- side flares
		box({ -0.69, 0.18, 0.18 }, { 0.06, 0.34, 0.84 }, "helmetDark"),
		box({ 0, 0.14, -0.66 }, { 1.24, 0.3, 0.08 }, "lens", nil, "visor"), -- smoked visor
		box({ 0, -0.3, -0.6 }, { 1.16, 0.46, 0.14 }, "strap", nil, "mask"), -- face mask
		box({ 0.35, -0.3, -0.69 }, { 0.2, 0.2, 0.06 }, "metal", nil, "mask"),
		box({ -0.35, -0.3, -0.69 }, { 0.2, 0.2, 0.06 }, "metal", nil, "mask"),
		box({ 0.74, 0.5, -0.1 }, { 0.1, 0.14, 0.3 }, "band"), -- team light
	},
	Torso = {
		box({ 0, 0.1, 0 }, { 2.14, 1.62, 1.2 }, "vest"),
		box({ 0, 0.25, -0.64 }, { 1.7, 0.9, 0.1 }, "plate"),
		wedge({ 0, -0.36, -0.66 }, { 1.4, 0.3, 0.1 }, "plate"),
		box({ -0.6, -0.34, -0.74 }, { 0.5, 0.36, 0.2 }, "pouch"), -- horizontal pouches
		box({ 0.6, -0.34, -0.74 }, { 0.5, 0.36, 0.2 }, "pouch"),
		box({ 0, -0.36, -0.76 }, { 0.5, 0.3, 0.22 }, "strap"),
		box({ 0, 0.62, -0.72 }, { 1.0, 0.14, 0.06 }, "band"), -- chest stripe
		box({ 0.72, 0.9, 0 }, { 0.62, 0.3, 1.26 }, "plate"), -- collar yoke
		box({ -0.72, 0.9, 0 }, { 0.62, 0.3, 1.26 }, "plate"),
		box({ 0, -0.9, 0 }, { 2.1, 0.26, 1.16 }, "strap"),
		box({ 0.92, -0.8, 0.1 }, { 0.26, 0.44, 0.5 }, "pouch"), -- hip holster
		-- Hard-shell radio pack with antenna
		box({ 0, 0.1, 0.84 }, { 1.36, 1.56, 0.56 }, "pack"),
		box({ 0, 0.1, 1.13 }, { 1.16, 1.3, 0.04 }, "helmetDark"),
		box({ 0.42, 0.62, 1.16 }, { 0.3, 0.2, 0.04 }, "band"),
		box({ -0.5, 1.4, 0.9 }, { 0.06, 1.6, 0.06 }, "metal", nil, "antenna"),
		box({ 0, -0.72, 0.9 }, { 1.2, 0.3, 0.5 }, "pouch"),
		box({ -0.8, 0.5, -0.52 }, { 0.3, 0.3, 0.02 }, "camoA"),
		box({ 0.82, -0.6, -0.52 }, { 0.24, 0.24, 0.02 }, "camoB"),
	},
	Arm = {
		box({ 0, 0.78, 0 }, { 1.2, 0.5, 1.18 }, "plate"), -- shoulder guard
		box({ 0.61, 0.72, 0 }, { 0.03, 0.3, 0.46 }, "band"),
		box({ 0, 0.4, 0 }, { 1.08, 0.3, 1.08 }, "cloth"),
		box({ 0, -0.12, -0.03 }, { 1.06, 0.42, 1.12 }, "knee"), -- elbow/forearm guard
		box({ 0.51, 0.1, 0.2 }, { 0.02, 0.24, 0.24 }, "camoA"),
		box({ 0, -0.78, 0 }, { 1.08, 0.48, 1.08 }, "glove"),
		box({ 0, -0.6, 0 }, { 1.12, 0.1, 1.12 }, "strap"),
	},
	Leg = {
		box({ 0, -0.72, -0.05 }, { 1.1, 0.6, 1.2 }, "boot"),
		box({ 0, -0.97, -0.05 }, { 1.14, 0.08, 1.24 }, "sole"),
		box({ 0, -0.38, 0 }, { 1.08, 0.12, 1.08 }, "strap"),
		box({ 0, 0.02, -0.54 }, { 0.84, 0.62, 0.14 }, "knee"),
		box({ 0, 0.02, -0.62 }, { 0.5, 0.3, 0.04 }, "helmetDark"),
		box({ 0.54, 0.45, 0 }, { 0.1, 0.44, 0.5 }, "pouch"), -- thigh panel
		box({ -0.51, 0.3, 0.2 }, { 0.02, 0.28, 0.28 }, "camoA"),
		box({ 0.2, 0.6, 0.51 }, { 0.28, 0.28, 0.02 }, "camoB"),
	},
}

-- Optional pieces and the chance a given soldier has them.
GearModels.Variants = {
	goggles = 0.6, cover = 0.5, headset = 0.5, bedroll = 0.7, visor = 0.6, mask = 0.5, antenna = 0.6,
}

function GearModels.variantsFor(userId)
	local set = {}
	local seed = math.abs(math.floor(userId)) % 2147483647 + 17
	for _, name in ipairs({ "antenna", "bedroll", "cover", "goggles", "headset", "mask", "visor" }) do
		seed = (seed * 16807) % 2147483647
		set[name] = (seed / 2147483647) < GearModels.Variants[name]
	end
	return set
end

return GearModels
