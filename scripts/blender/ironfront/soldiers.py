"""
Soldier body + gear models for the two factions (original designs).

Every piece is modelled in its R6 limb's local frame (Blender space:
X right, Y forward, Z up; origin = limb centre). R6 limb extents:
Torso 2×2×1, Arms/Legs 1×2×1; the Roblox head (kept for faces) is ~1.2³
centred 1.5 above the torso centre.

Body meshes are slimmer and shaped (chest/waist taper, deltoids, elbows,
gloved fists, knees, boots); at runtime the blocky R6 limbs are hidden and
these are welded on, while the R6 parts remain the hitboxes.
Pieces tagged obj["variant"] are optional per soldier.
"""
import math

from mathutils import Matrix

from . import geo, mats


def _tag(obj, mat, variant=None):
    geo.set_material(obj, mat)
    obj["variant"] = variant or ""
    return obj


# ------------------------------------------------------------------ palettes

TEAMS = {
    "Alpha": {  # Ashford Coalition — woodland olive, tan kit, brown boots
        "uniform": dict(kind="fabric", rgb=(88, 96, 62), camo=[(98, 106, 70), (70, 78, 50), (134, 120, 86), (52, 56, 40)], digital=False),
        "vest": ("fabric", (106, 110, 78)), "pouch": ("fabric", (116, 116, 82)), "strap": ("fabric", (70, 74, 52)),
        "pack": ("fabric", (94, 98, 66)), "glove": ("leather", (150, 130, 94)), "boot": ("leather", (86, 62, 42)),
        "sole": ("rubber", (34, 32, 30)), "helmet": ("paint", (84, 92, 60)), "helmetDark": ("paint", (58, 62, 44)),
        "metal": ("metal", (60, 62, 60)), "lens": ("lens", (70, 110, 90)), "patch": ("fabric", (214, 190, 90)),
        "knee": ("polymer", (62, 68, 48)), "cloth": ("fabric", (74, 82, 54)),
    },
    "Bravo": {  # Varn Directorate — urban grey/blue digital, black kit, blue accents
        "uniform": dict(kind="fabric", rgb=(62, 68, 80), camo=[(72, 78, 92), (50, 55, 66), (96, 104, 118), (38, 42, 50)], digital=True),
        "vest": ("paint", (64, 76, 98)), "pouch": ("fabric", (50, 56, 66)), "strap": ("fabric", (34, 36, 42)),
        "pack": ("paint", (48, 52, 60)), "glove": ("leather", (30, 30, 34)), "boot": ("leather", (32, 32, 36)),
        "sole": ("rubber", (20, 20, 22)), "helmet": ("paint", (56, 60, 68)), "helmetDark": ("paint", (34, 36, 42)),
        "metal": ("metal", (110, 116, 124)), "lens": ("lens", (40, 70, 100)), "patch": ("paint", (110, 196, 230)),
        "knee": ("polymer", (42, 46, 56)), "cloth": ("fabric", (54, 60, 72)),
    },
}


def palette(team):
    P = TEAMS[team]
    u = P["uniform"]
    out = {"uniform": mats.material(f"{team}_uniform", u["kind"], u["rgb"], camo=u["camo"], digital=u["digital"], scale=0.5)}
    for key, value in P.items():
        if key != "uniform":
            kind, rgb = value
            out[key] = mats.material(f"{team}_{key}", kind, rgb)
    out["skin"] = mats.material("Skin", "skin", (204, 170, 140))
    return out


# ------------------------------------------------------------------ bodies

def torso_body(team, M):
    """Shaped torso: shoulders → chest → waist → hips; collar; belt."""
    body = geo.loft(f"{team}_torsoBody", [
        (-1.0, 1.62, 0.86, 3.2), (-0.8, 1.6, 0.86, 3.2), (-0.5, 1.5, 0.8, 3.0), (-0.1, 1.56, 0.82, 3.0),
        (0.35, 1.76, 0.88, 3.2), (0.72, 1.86, 0.86, 3.6), (0.9, 1.7, 0.76, 3.0), (1.0, 1.1, 0.62, 2.6)], 24)
    collar = geo.ring(f"{team}_collar", (0.94, 1.08), 0.72, 0.64, 0.05, 2.2)
    belt = geo.ring(f"{team}_belt", (-0.98, -0.8), 1.64, 0.9, 0.04, 3.2)
    buckle = geo.box(f"{team}_buckle", (0.26, 0.05, 0.16), (0, 0.47, -0.89), bev=0.015)
    return [_tag(body, M["uniform"]), _tag(collar, M["cloth"]), _tag(belt, M["strap"]), _tag(buckle, M["metal"])]


def arm_body(team, M, side):
    """Slim arm with deltoid, elbow, rolled cuff and a gloved fist.
    side: +1 right, -1 left. The mesh sits slightly inward (toward the torso)."""
    ix = -0.16 * side  # inward shift
    arm = geo.loft(f"{team}_arm{side}", [
        (-0.62, 0.46, 0.5, 2.4, (ix, 0)), (-0.4, 0.52, 0.56, 2.4, (ix, 0)), (-0.1, 0.56, 0.58, 2.5, (ix, 0)),
        (0.25, 0.6, 0.62, 2.5, (ix, 0)), (0.6, 0.68, 0.68, 2.3, (ix - 0.04 * side, 0)), (0.82, 0.66, 0.68, 2.2, (ix - 0.1 * side, 0)),
        (0.94, 0.48, 0.54, 2.0, (ix - 0.16 * side, 0))], 18)
    cuff = geo.ring(f"{team}_cuff{side}", (-0.34, -0.22), 0.6, 0.62, 0.03, 2.4)
    geo.transform(cuff, Matrix.Translation((ix, 0, 0)))
    # Gloved fist: palm block with knuckle row, thumb wrapped forward.
    hand = geo.loft(f"{team}_hand{side}", [(-1.0, 0.44, 0.54, 3.0, (ix, 0.02)), (-0.9, 0.56, 0.64, 3.2, (ix, 0.02)),
                                           (-0.72, 0.58, 0.62, 3.2, (ix, 0.0)), (-0.6, 0.5, 0.52, 2.6, (ix, 0.0))], 16)
    knuckles = geo.box(f"{team}_knuckle{side}", (0.5, 0.14, 0.16), (ix, 0.3, -0.84), bev=0.04, seg=2)
    thumb = geo.box(f"{team}_thumb{side}", (0.16, 0.26, 0.14), (ix - 0.24 * side, 0.18, -0.72), bev=0.05, seg=2,
                    rot=Matrix.Rotation(math.radians(-25 * side), 3, "Y"))
    return [_tag(arm, M["uniform"]), _tag(cuff, M["cloth"]), _tag(hand, M["glove"]), _tag(knuckles, M["knee"]), _tag(thumb, M["glove"])]


def leg_body(team, M, side):
    """Leg with thigh/knee/calf shaping, cargo pocket, knee pad and a sculpted boot."""
    ix = -0.06 * side
    leg = geo.loft(f"{team}_leg{side}", [
        (-0.58, 0.62, 0.66, 2.4, (ix, 0)), (-0.3, 0.7, 0.74, 2.4, (ix, 0)), (0.0, 0.72, 0.74, 2.5, (ix, 0)),
        (0.4, 0.8, 0.8, 2.6, (ix, 0)), (0.8, 0.88, 0.84, 2.8, (ix, 0)), (1.0, 0.9, 0.84, 3.0, (ix, 0))], 18)
    blouse = geo.ring(f"{team}_blouse{side}", (-0.6, -0.5), 0.68, 0.7, 0.05, 2.4)
    geo.transform(blouse, Matrix.Translation((ix, 0, 0)))
    pocket = geo.extrude(f"{team}_cargo{side}", geo.rounded_rect(0.42, 0.4, 0.05, 2, cx=0.02, cz=0.3), 0.08, x=ix + 0.4 * side, bev=0.02)
    flap = geo.extrude(f"{team}_cargoFlap{side}", geo.rounded_rect(0.46, 0.12, 0.04, 2, cx=0.02, cz=0.52), 0.1, x=ix + 0.41 * side, bev=0.015)
    knee = geo.shell(f"{team}_kneepad{side}", (0.6, 0.3, 0.46), (ix, 0.32, -0.05))
    # Boot: shaft, foot with toe cap, sole with heel and tread.
    boot = geo.loft(f"{team}_boot{side}", [(-0.62, 0.66, 0.7, 2.6, (ix, 0)), (-0.72, 0.68, 0.74, 2.8, (ix, 0.04)), (-0.86, 0.7, 0.96, 3.0, (ix, 0.12)),
                                           (-0.95, 0.72, 1.06, 3.2, (ix, 0.15))], 18)
    toe = geo.shell(f"{team}_toe{side}", (0.66, 0.46, 0.34), (ix, 0.5, -0.86))
    sole = geo.extrude_top(f"{team}_sole{side}", geo.rounded_rect(0.74, 1.12, 0.2, 3, cx=ix, cz=0.16), 0.08, z=-0.97, bev=0.02)
    tread = geo.box(f"{team}_tread{side}", (0.7, 0.05, 0.03), (ix, -0.3, -1.015), bev=0)
    geo.array_copy(tread, 7, (0, 0.14, 0))
    laces = geo.box(f"{team}_laces{side}", (0.2, 0.05, 0.3), (ix, 0.38, -0.66), bev=0.01, rot=Matrix.Rotation(math.radians(-25), 3, "X"))
    return [_tag(leg, M["uniform"]), _tag(blouse, M["cloth"]), _tag(pocket, M["uniform"]), _tag(flap, M["uniform"]), _tag(knee, M["knee"]),
            _tag(boot, M["boot"]), _tag(toe, M["boot"]), _tag(sole, M["sole"]), _tag(tread, M["sole"]), _tag(laces, M["strap"])]


# ------------------------------------------------------------------ Ashford gear

def ashford_head(M):
    t = "Alpha"
    shell = geo.shell(f"{t}_helmet", (1.46, 1.5, 1.18), (0, -0.02, 0.24), cut_below=0.12)
    geo.cut_slots(shell, [(0.72, 0.1, 0.13), (-0.72, 0.1, 0.13)], (0.3, 0.55, 0.24))  # high-cut ears
    rim = geo.ring(f"{t}_helmetRim", (0.1, 0.16), 1.5, 1.54, 0.035, 2.0)
    shroud = geo.extrude_front(f"{t}_nvgShroud", geo.rounded_rect(0.34, 0.24, 0.05, 2, cz=0.5), 0.08, y=0.74, bev=0.015)
    rails = [geo.extrude(f"{t}_rail{sx}", [(-0.32, 0.26), (0.34, 0.26), (0.3, 0.36), (-0.28, 0.36)], 0.06, x=sx * 0.72, bev=0.008) for sx in (1, -1)]
    velcro = geo.extrude_front(f"{t}_velcro", geo.rounded_rect(0.5, 0.16, 0.03, 2, cz=0.74), 0.03, y=0.66, bev=0.008)
    parts = [_tag(shell, M["helmet"]), _tag(rim, M["helmetDark"]), _tag(shroud, M["metal"]), _tag(velcro, M["patch"])] + [_tag(r, M["helmetDark"]) for r in rails]
    # Goggles resting on the helmet front (variant)
    band = geo.ring(f"{t}_gogBand", (0.46, 0.56), 1.5, 1.54, 0.03, 2.0)
    frame = geo.extrude_front(f"{t}_gogFrame", geo.rounded_rect(0.9, 0.24, 0.1, 3, cz=0.55), 0.12, y=0.7, bev=0.02)
    lens = geo.extrude_front(f"{t}_gogLens", geo.rounded_rect(0.8, 0.17, 0.07, 3, cz=0.55), 0.03, y=0.77, bev=0.01)
    parts += [_tag(band, M["strap"], "goggles"), _tag(frame, M["strap"], "goggles"), _tag(lens, M["lens"], "goggles")]
    # Headset (variant) and chin strap
    for sx in (1, -1):
        cup = geo.lathe(f"{t}_cup{sx}", [(0.0, 0.0), (0.17, 0.0), (0.2, 0.05), (0.2, 0.12), (0.15, 0.16), (0.0, 0.16)], (0, 0), "Z", 16, bev=0.004)
        geo.transform(cup, Matrix.Translation((sx * 0.6, 0.0, -0.1)) @ Matrix.Rotation(math.radians(90 * sx), 4, "Y"))
        parts.append(_tag(cup, M["helmetDark"], "headset"))
        parts.append(_tag(geo.strap(f"{t}_chin{sx}", [(sx * 0.6, 0.08, 0.1), (sx * 0.56, 0.18, -0.3), (sx * 0.3, 0.42, -0.58), (0, 0.46, -0.62)], 0.06, 0.02), M["strap"]))
    parts.append(_tag(geo.tube(f"{t}_boom", [(0.66, 0.05, -0.12), (0.62, 0.3, -0.3), (0.3, 0.55, -0.38)], 0.02, 6), M["helmetDark"], "headset"))
    return parts


def molle(name, width, rows, x0, z0, y, M):
    strips = []
    for i in range(rows):
        s = geo.box(f"{name}{i}", (width, 0.02, 0.05), (x0, y, z0 - i * 0.11), bev=0.005, seg=1)
        strips.append(_tag(s, M["strap"]))
    return strips


def pouch(name, w, h, d, x, z, y, M, flap_rgb_key="pouch", mag_tops=0):
    body = geo.extrude_front(name, geo.rounded_rect(w, h, 0.05, 2, cx=x, cz=z), d, y=y + d / 2, bev=0.025)
    flap = geo.extrude_front(name + "Flap", geo.rounded_rect(w + 0.02, h * 0.34, 0.05, 2, cx=x, cz=z + h * 0.36), d * 0.3, y=y + d + 0.01, bev=0.015)
    parts = [_tag(body, M["pouch"]), _tag(flap, M[flap_rgb_key])]
    return parts


def ashford_torso(M):
    t = "Alpha"
    parts = []
    front = geo.extrude_front(f"{t}_plateF", [(-0.72, -0.62), (0.72, -0.62), (0.76, 0.3), (0.62, 0.62), (0.34, 0.74), (-0.34, 0.74), (-0.62, 0.62), (-0.76, 0.3)], 0.14, y=0.5, bev=0.04, seg=3)
    back = geo.extrude_front(f"{t}_plateB", [(-0.72, -0.62), (0.72, -0.62), (0.76, 0.3), (0.62, 0.66), (-0.62, 0.66), (-0.76, 0.3)], 0.14, y=-0.5, bev=0.04, seg=3)
    cummer = geo.ring(f"{t}_cummerbund", (-0.62, -0.08), 1.7, 1.02, 0.05, 3.2)
    parts += [_tag(front, M["vest"]), _tag(back, M["vest"]), _tag(cummer, M["vest"])]
    for sx in (1, -1):
        parts.append(_tag(geo.strap(f"{t}_shoulder{sx}", [(sx * 0.5, 0.56, 0.62), (sx * 0.56, 0.36, 0.92), (sx * 0.56, -0.2, 0.94), (sx * 0.5, -0.56, 0.66)], 0.3, 0.06), M["vest"]))
    parts += molle(f"{t}_molleF", 1.3, 3, 0, 0.5, 0.58, M)
    for i, x in enumerate((-0.46, 0.0, 0.46)):
        parts += pouch(f"{t}_magPouch{i}", 0.38, 0.5, 0.18, x, -0.3, 0.57, M)
        parts.append(_tag(geo.box(f"{t}_magTop{i}", (0.26, 0.1, 0.1), (x, 0.66, -0.02), bev=0.02), M["strap"]))
    parts += pouch(f"{t}_admin", 0.46, 0.3, 0.1, 0.0, 0.34, 0.57, M, "pouch")
    parts.append(_tag(geo.extrude_front(f"{t}_flag", geo.rounded_rect(0.34, 0.2, 0.03, 2, cx=-0.44, cz=0.5), 0.02, y=0.66, bev=0.004), M["patch"]))
    # Radio on the left shoulder with antenna
    parts += pouch(f"{t}_radio", 0.26, 0.4, 0.2, -0.62, 0.14, 0.44, M)
    parts.append(_tag(geo.tube(f"{t}_radioAnt", [(-0.66, 0.62, 0.4), (-0.7, 0.6, 1.0)], 0.018, 6), M["strap"]))
    # Rucksack with lid, side pockets, compression straps and bedroll
    pack = geo.loft(f"{t}_pack", [(-0.66, 1.3, 0.54, 3.4, (0, -0.84)), (-0.4, 1.4, 0.62, 3.6, (0, -0.86)), (0.4, 1.38, 0.62, 3.6, (0, -0.86)),
                                  (0.7, 1.26, 0.56, 3.4, (0, -0.84)), (0.78, 1.1, 0.44, 3.0, (0, -0.82))], 24)
    lid = geo.loft(f"{t}_packLid", [(0.66, 1.34, 0.66, 3.6, (0, -0.86)), (0.82, 1.3, 0.62, 3.6, (0, -0.88)), (0.86, 1.1, 0.5, 3.0, (0, -0.88))], 24)
    parts += [_tag(pack, M["pack"]), _tag(lid, M["pouch"])]
    for sx in (1, -1):
        side = geo.loft(f"{t}_packSide{sx}", [(-0.5, 0.26, 0.4, 3.0, (sx * 0.78, -0.86)), (0.2, 0.28, 0.44, 3.0, (sx * 0.78, -0.86)), (0.3, 0.2, 0.34, 2.6, (sx * 0.78, -0.86))], 16)
        parts.append(_tag(side, M["pouch"]))
        parts.append(_tag(geo.box(f"{t}_packStrap{sx}", (0.08, 0.66, 0.05), (sx * 0.36, -1.18, 0.1), bev=0.01, rot=Matrix.Rotation(math.radians(90), 3, "X")), M["strap"]))
    roll = geo.lathe(f"{t}_bedroll", [(0.0, -0.8), (0.2, -0.8), (0.23, -0.76), (0.23, 0.76), (0.2, 0.8), (0.0, 0.8)], (0, 0), "Z", 16, bev=0.01)
    geo.transform(roll, Matrix.Translation((0, -0.84, 1.02)) @ Matrix.Rotation(math.radians(90), 4, "Y"))
    parts.append(_tag(roll, M["cloth"], "bedroll"))
    return parts


# ------------------------------------------------------------------ Varn gear

def varn_head(M):
    t = "Bravo"
    # Angular helmet from a side profile, trimmed to a hex-ish plan.
    # Faceted, low-crowned shell: squarer superellipse sections read as angular without being a box.
    shell = geo.loft(f"{t}_helmet", [(0.06, 1.4, 1.46, 3.4, (0, -0.04)), (0.34, 1.42, 1.48, 3.2, (0, -0.04)),
                                     (0.58, 1.3, 1.36, 3.0, (0, -0.06)), (0.74, 1.0, 1.06, 2.6, (0, -0.08)),
                                     (0.8, 0.56, 0.62, 2.2, (0, -0.08))], 24)
    brow = geo.ring(f"{t}_helmetBrow", (0.04, 0.14), 1.46, 1.52, 0.04, 3.4)
    geo.transform(brow, Matrix.Translation((0, -0.04, 0)))
    neck = geo.extrude(f"{t}_neckGuard", [(-0.72, 0.12), (-0.8, -0.12), (-0.66, -0.16), (-0.6, 0.1)], 1.1, bev=0.02)
    crest = geo.extrude(f"{t}_crest", [(-0.5, 0.74), (0.3, 0.8), (0.4, 0.8), (-0.4, 0.78)], 0.14, bev=0.02)
    parts = [_tag(shell, M["helmet"]), _tag(crest, M["helmetDark"]), _tag(brow, M["helmetDark"]), _tag(neck, M["helmetDark"])]
    for sx in (1, -1):
        ear = geo.extrude(f"{t}_earplate{sx}", [(-0.3, -0.24), (0.24, -0.2), (0.3, 0.24), (-0.34, 0.24)], 0.08, x=sx * 0.7, bev=0.02)
        light = geo.box(f"{t}_teamLight{sx}", (0.04, 0.2, 0.06), (sx * 0.73, 0.04, 0.3), bev=0.01)
        parts += [_tag(ear, M["helmetDark"]), _tag(light, M["patch"])]
    visor = geo.extrude(f"{t}_visor", [(0.64, 0.14), (0.78, 0.18), (0.8, -0.16), (0.66, -0.2)], 1.3, bev=0.02)
    parts.append(_tag(visor, M["lens"], "visor"))
    # Respirator mask with side filters (variant)
    mask = geo.loft(f"{t}_mask", [(-0.56, 0.5, 0.2, 2.4, (0, 0.56)), (-0.36, 0.76, 0.3, 2.4, (0, 0.52)), (-0.14, 0.9, 0.3, 2.6, (0, 0.46))], 16)
    parts.append(_tag(mask, M["helmetDark"], "mask"))
    for sx in (1, -1):
        filt = geo.lathe(f"{t}_filter{sx}", [(0.0, 0.0), (0.13, 0.0), (0.14, 0.03), (0.14, 0.15), (0.12, 0.18), (0.0, 0.18)], (0, 0), "Z", 14, bev=0.004)
        geo.transform(filt, Matrix.Translation((sx * 0.3, 0.62, -0.38)) @ Matrix.Rotation(math.radians(-70), 4, "X") @ Matrix.Rotation(math.radians(25 * sx), 4, "Y"))
        parts.append(_tag(filt, M["metal"], "mask"))
    return parts


def varn_torso(M):
    t = "Bravo"
    parts = []
    # Segmented breastplate: chest plate + two abdomen bands + back plate.
    chest = geo.extrude_front(f"{t}_chest", [(-0.8, -0.1), (0.8, -0.1), (0.86, 0.44), (0.6, 0.78), (0.26, 0.86), (-0.26, 0.86), (-0.6, 0.78), (-0.86, 0.44)], 0.16, y=0.5, bev=0.05, seg=3)
    parts.append(_tag(chest, M["vest"]))
    for i, z in enumerate((-0.24, -0.5)):
        band = geo.extrude_front(f"{t}_abdomen{i}", geo.rounded_rect(1.36 - i * 0.1, 0.22, 0.08, 2, cz=z), 0.12, y=0.47, bev=0.03)
        parts.append(_tag(band, M["vest"]))
    back = geo.extrude_front(f"{t}_back", geo.rounded_rect(1.6, 1.46, 0.18, 3, cz=0.12), 0.14, y=-0.5, bev=0.04)
    gorget = geo.ring(f"{t}_gorget", (0.86, 1.02), 1.1, 0.84, 0.06, 2.4)
    stripe = geo.extrude_front(f"{t}_stripe", geo.rounded_rect(0.9, 0.08, 0.03, 2, cz=0.62), 0.02, y=0.6, bev=0.005)
    parts += [_tag(back, M["vest"]), _tag(gorget, M["helmetDark"]), _tag(stripe, M["patch"])]
    for sx in (1, -1):
        parts.append(_tag(geo.strap(f"{t}_harness{sx}", [(sx * 0.5, 0.58, 0.7), (sx * 0.58, 0.3, 0.96), (sx * 0.58, -0.3, 0.96), (sx * 0.5, -0.58, 0.7)], 0.24, 0.06), M["strap"]))
    # Horizontal belt pouches and a holster
    for i, x in enumerate((-0.5, 0.0, 0.5)):
        parts.append(_tag(geo.extrude_front(f"{t}_beltPouch{i}", geo.rounded_rect(0.4, 0.26, 0.06, 2, cx=x, cz=-0.76), 0.2, y=0.56, bev=0.03), M["pouch"]))
    parts.append(_tag(geo.box(f"{t}_holster", (0.14, 0.3, 0.42), (0.86, 0.1, -0.78), bev=0.05, seg=2), M["pouch"]))
    # Hard-shell radio pack with antenna and handset cable
    pack = geo.loft(f"{t}_radioPack", [(-0.72, 1.2, 0.44, 5.0, (0, -0.8)), (0.62, 1.24, 0.46, 5.0, (0, -0.8)), (0.74, 1.1, 0.4, 4.0, (0, -0.8))], 24)
    panel = geo.extrude_front(f"{t}_packPanel", geo.rounded_rect(0.9, 0.9, 0.1, 3, cz=0.0), 0.04, y=-1.04, bev=0.015)
    lights = geo.extrude_front(f"{t}_packLights", geo.rounded_rect(0.3, 0.08, 0.03, 2, cx=0.3, cz=0.5), 0.02, y=-1.06, bev=0.005)
    parts += [_tag(pack, M["pack"]), _tag(panel, M["helmetDark"]), _tag(lights, M["patch"])]
    parts.append(_tag(geo.tube(f"{t}_antenna", [(-0.44, -0.86, 0.7), (-0.46, -0.9, 2.0)], 0.018, 6), M["metal"], "antenna"))
    parts.append(_tag(geo.tube(f"{t}_cable", [(0.4, -0.96, 0.66), (0.62, -0.7, 0.92), (0.66, 0.1, 0.94), (0.6, 0.52, 0.62)], 0.022, 6), M["strap"]))
    return parts


def varn_arm_extras(M, side):
    t = "Bravo"
    ix = -0.16 * side
    pauldron = geo.shell(f"{t}_pauldron{side}", (0.74, 0.72, 0.44), (ix, 0, 0.8), cut_below=0.6)
    elbow = geo.shell(f"{t}_elbow{side}", (0.4, 0.3, 0.36), (ix, -0.18, -0.12))
    bracer = geo.ring(f"{t}_bracer{side}", (-0.56, -0.3), 0.62, 0.64, 0.05, 3.0)
    geo.transform(bracer, Matrix.Translation((ix, 0, 0)))
    patch = geo.box(f"{t}_armLight{side}", (0.03, 0.24, 0.08), (ix + 0.36 * side, 0.0, 0.62), bev=0.01)
    return [_tag(pauldron, M["vest"]), _tag(elbow, M["knee"]), _tag(bracer, M["knee"]), _tag(patch, M["patch"])]


def ashford_arm_extras(M, side):
    t = "Alpha"
    ix = -0.16 * side
    flag = geo.extrude(f"{t}_sleeveFlag{side}", geo.rounded_rect(0.3, 0.2, 0.03, 2, cx=0.0, cz=0.6), 0.02, x=ix + 0.4 * side, bev=0.004)
    pocket = geo.extrude(f"{t}_sleevePocket{side}", geo.rounded_rect(0.34, 0.3, 0.04, 2, cx=0.02, cz=0.3), 0.05, x=ix + 0.35 * side, bev=0.012)
    return [_tag(flag, M["patch"]), _tag(pocket, M["uniform"])]


def varn_leg_extras(M, side):
    t = "Bravo"
    ix = -0.06 * side
    thigh = geo.extrude(f"{t}_thighPlate{side}", geo.rounded_rect(0.5, 0.44, 0.08, 2, cx=0.04, cz=0.44), 0.08, x=ix + 0.42 * side, bev=0.02)
    shin = geo.shell(f"{t}_shin{side}", (0.5, 0.34, 0.5), (ix, 0.34, -0.4))
    return [_tag(thigh, M["vest"]), _tag(shin, M["knee"])]


def build(team, piece):
    """Returns the objects for one exported piece: Head, Torso, Arm, Arm_L, Leg, Leg_L."""
    M = palette(team)
    alpha = team == "Alpha"
    if piece == "Head":
        return ashford_head(M) if alpha else varn_head(M)
    if piece == "Torso":
        return torso_body(team, M) + (ashford_torso(M) if alpha else varn_torso(M))
    side = -1 if piece.endswith("_L") else 1
    if piece.startswith("Arm"):
        return arm_body(team, M, side) + (ashford_arm_extras(M, side) if alpha else varn_arm_extras(M, side))
    return leg_body(team, M, side) + ([] if alpha else varn_leg_extras(M, side))


PIECES = ["Head", "Torso", "Arm", "Arm_L", "Leg", "Leg_L"]
# Where each piece sits relative to the torso centre (R6 rest pose), Blender space.
REST = {"Head": (0, 0, 1.5), "Torso": (0, 0, 0), "Arm": (1.5, 0, 0), "Arm_L": (-1.5, 0, 0), "Leg": (0.5, 0, -2), "Leg_L": (-0.5, 0, -2)}
