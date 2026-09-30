"""Ashford Coalition soldier kit — premium R6 cosmetic set (team "Alpha").

Everything is modelled in R6 character space (Blender: +X right, +Y front,
+Z up; torso centre at the origin) around the real R6 limb blocks, then split
per limb with the pivot at the limb centre, exactly how UniformService welds
gear: Head, Torso, Arm (right), Arm_L, Leg (right), Leg_L.

Design: olive "Ashford Woodland" camo uniform with ripstop weave, mid-cut
helmet with rubber edge trim, NVG shroud, side rails, velcro and flag patch;
ranger-green plate carrier with shoulder pads, cummerbund webbing, open-top mag
pouches with shock-cord retention, admin pouch with the Ashford shield (ash
leaf), rolled shemagh, zip-on assault pack with compression straps, radio and
hydration tube; coyote gloves with knuckle armour, knee pads, bloused
trousers and coyote boots with leather toe caps. Variants follow
GearModels.Variants: cover, goggles, headset, bedroll, antenna.
"""
import math
import os
import json

import bpy
from mathutils import Matrix, Vector

from iflib import bake, geo, mats, render
from iflib.geo import MB, fillet, rrect, finish, soft_block, ellipse, catmull_path, tr, rot

NAME = "Ashford"
TEAM = "Alpha"
CENTRES = {"Head": (0, 0, 1.5), "Torso": (0, 0, 0), "Arm": (1.5, 0, 0), "Arm_L": (-1.5, 0, 0),
           "Leg": (0.5, 0, -2), "Leg_L": (-0.5, 0, -2)}
ATLASES = {"Head": ["Head"], "Torso": ["Torso"], "Arms": ["Arm", "Arm_L"], "Legs": ["Leg", "Leg_L"]}
VARIANTS = ["cover", "goggles", "headset", "bedroll", "antenna"]

CAMO = [((64, 72, 45), 0.50), ((96, 88, 60), 0.56), ((140, 134, 98), 0.615)]
FABRIC = {"kind": "ripstop", "scale": 1.0, "strength": 0.22, "distance": 0.004}
WEAVE = {"kind": "weave", "scale": 1.6, "strength": 0.2, "distance": 0.003}
LOOKS = {
    "uniform": {"color": (92, 99, 66), "camo": CAMO, "camo_scale": 1.5, "rough": 0.86, "mottle": 0.05, "wear": 0.2,
                "wear_color": (126, 128, 100), "wear_rough": 0.9, "wear_radius": 0.02, "bump": FABRIC},
    "scarf": {"color": (128, 122, 90), "color2": (112, 108, 78), "var": 0.6, "rough": 0.9, "mottle": 0.08, "bump": WEAVE},
    "vest": {"color": (78, 84, 58), "color2": (70, 76, 52), "var": 0.4, "rough": 0.8, "mottle": 0.05, "wear": 0.25,
             "wear_color": (112, 116, 86), "wear_rough": 0.9, "wear_radius": 0.015, "bump": WEAVE},
    "plate": {"color": (81, 87, 60), "color2": (73, 79, 54), "var": 0.4, "rough": 0.8, "mottle": 0.05, "wear": 0.25,
              "wear_color": (114, 118, 88), "wear_rough": 0.9, "wear_radius": 0.015, "bump": WEAVE},
    "pouch": {"color": (85, 91, 63), "color2": (76, 82, 56), "var": 0.4, "rough": 0.8, "mottle": 0.05, "wear": 0.3,
              "wear_color": (118, 122, 92), "wear_rough": 0.9, "wear_radius": 0.012, "bump": WEAVE},
    "pack": {"color": (82, 88, 60), "color2": (74, 80, 54), "var": 0.45, "rough": 0.82, "mottle": 0.06, "wear": 0.3,
             "wear_color": (116, 120, 90), "wear_rough": 0.9, "wear_radius": 0.018, "bump": WEAVE},
    "webbing": {"color": (60, 64, 46), "rough": 0.75, "mottle": 0.04, "wear": 0.2, "wear_color": (92, 96, 72),
                "wear_radius": 0.006, "bump": {"kind": "webbing", "scale": 1.0, "strength": 0.3, "distance": 0.002}},
    "velcro": {"color": (68, 74, 50), "rough": 0.95, "mottle": 0.05, "bump": {"kind": "grain", "scale": 0.5, "strength": 0.35}},
    "helmet": {"color": (82, 88, 62), "color2": (76, 82, 57), "var": 0.4, "rough": 0.62, "mottle": 0.05, "wear": 0.35,
               "wear_color": (56, 58, 50), "wear_rough": 0.5, "wear_radius": 0.01, "bump": {"kind": "peel", "scale": 0.6, "strength": 0.25}},
    "rubber": {"color": (40, 42, 38), "rough": 0.78, "mottle": 0.05, "bump": {"kind": "rubber", "strength": 0.1}},
    "polymer_black": {"color": (38, 40, 38), "rough": 0.5, "mottle": 0.04, "wear": 0.3, "wear_color": (88, 90, 86),
                      "wear_radius": 0.004, "bump": {"kind": "grain", "strength": 0.1}},
    "metal": {"color": (58, 60, 62), "rough": 0.38, "metal": 0.85, "wear": 0.4, "wear_color": (150, 150, 152),
              "wear_metal": 1.0, "wear_radius": 0.004},
    "patch_base": {"color": (60, 66, 43), "rough": 0.85, "bump": WEAVE},
    "patch_emblem": {"color": (198, 180, 128), "rough": 0.8, "bump": WEAVE},
    "patch_border": {"color": (150, 132, 92), "rough": 0.8, "bump": WEAVE},
    "lens": {"glass": True, "color": (70, 82, 80), "rough": 0.03},
    "mag_tan": {"color": (142, 120, 88), "rough": 0.6, "mottle": 0.05, "wear": 0.3, "wear_color": (176, 158, 126),
                "wear_radius": 0.005, "bump": {"kind": "grain", "strength": 0.12}},
    "glove": {"color": (146, 124, 90), "color2": (134, 113, 82), "var": 0.5, "rough": 0.78, "mottle": 0.06, "wear": 0.3,
              "wear_color": (176, 158, 124), "wear_radius": 0.02, "bump": {"kind": "leather", "scale": 1.5, "strength": 0.22}},
    "glove_palm": {"color": (112, 94, 68), "rough": 0.7, "mottle": 0.06, "bump": {"kind": "leather", "scale": 2.0, "strength": 0.3}},
    "kneepad": {"color": (72, 78, 54), "rough": 0.55, "mottle": 0.04, "wear": 0.4, "wear_color": (110, 112, 90),
                "wear_radius": 0.012, "bump": {"kind": "grain", "strength": 0.12}},
    "kneecap": {"color": (52, 56, 43), "rough": 0.72, "mottle": 0.04, "bump": {"kind": "rubber", "strength": 0.15}},
    "boot": {"color": (136, 112, 81), "color2": (122, 100, 72), "var": 0.5, "rough": 0.86, "mottle": 0.07, "wear": 0.3,
             "wear_color": (104, 88, 66), "wear_radius": 0.02, "bump": {"kind": "leather", "scale": 2.5, "strength": 0.3}},
    "boot_leather": {"color": (100, 78, 55), "color2": (88, 68, 48), "var": 0.5, "rough": 0.55, "mottle": 0.06, "wear": 0.18,
                     "wear_color": (128, 104, 78), "wear_radius": 0.01, "bump": {"kind": "leather", "scale": 1.5, "strength": 0.2}},
    "sole": {"color": (34, 32, 30), "rough": 0.9, "mottle": 0.05, "bump": {"kind": "rubber", "strength": 0.2}},
    "bedroll": {"color": (110, 116, 82), "color2": (98, 104, 72), "var": 0.5, "rough": 0.9, "mottle": 0.06,
                "bump": {"kind": "grain", "scale": 0.4, "strength": 0.25}},
}


def M(key):
    return mats.build(f"{NAME}_{key}", LOOKS[key])


class Kit:
    """Collects (object, piece, colour key, variant) during modelling."""

    def __init__(self):
        self.items = []

    def add(self, obj, piece, key, variant=None):
        self.items.append((obj, piece, key, variant))
        return obj


def soft(name, mat, center, size, finish_bevel=0.0, tiny=False, **kw):
    kw.setdefault("seg", 1 if tiny else 2)
    kw.setdefault("vseg", 1 if tiny else 2)
    mb = MB()
    soft_block(mb, center, size, **kw)
    o = mb.obj(name, mat)
    if finish_bevel:
        finish(o, finish_bevel, 2, 35)
    else:
        geo.smooth(o)
    return o


def sweep_obj(name, mat, section, path, up=(0, 0, 1), closed=False, scale=None, smooth_angle=None):
    mb = MB()
    mb.sweep(section, path, up=up, caps=not closed, closed_path=closed, scale=scale)
    o = mb.obj(name, mat)
    geo.smooth(o, smooth_angle)
    return o


def wrinkle(obj, fn):
    """Displaces vertices along their horizontal normal by fn(co, theta)."""
    me = obj.data
    me.update()
    cache = [(v.co.copy(), v.normal.copy()) for v in me.vertices]
    for v, (co, n) in zip(me.vertices, cache):
        h = Vector((n.x, n.y, 0.0))
        if h.length < 0.3:
            continue
        h.normalize()
        theta = math.atan2(h.y, h.x)
        v.co += h * fn(co, theta)
    me.update()


def bell(x, c, w):
    return math.exp(-((x - c) / w) ** 2)


def crease_wave(x):
    """Cloth-fold profile: broad rounded ridges with tighter valleys."""
    v = math.sin(x)
    return (abs(v) ** 0.6) * (1 if v > 0 else -0.6)


# ------------------------------------------------------------------ head

HZC, AX, AY, AZ, HYC = 1.56, 0.76, 0.815, 0.70, -0.03
BRIM_KEYS = [(0, 1.785), (28, 1.765), (55, 1.69), (72, 1.71), (90, 1.76), (108, 1.71), (126, 1.62), (150, 1.53), (180, 1.49)]


def _brim_lin(deg):
    a = abs(((deg + 180) % 360) - 180)
    for (a0, z0), (a1, z1) in zip(BRIM_KEYS, BRIM_KEYS[1:]):
        if a <= a1:
            return z0 + (z1 - z0) * (a - a0) / (a1 - a0)
    return BRIM_KEYS[-1][1]


def brim_z(phi):
    deg = math.degrees(phi)
    return sum(_brim_lin(deg + d) for d in (-12, -8, -4, 0, 4, 8, 12)) / 7


def e_brim(phi):
    return math.asin(max(-1.0, min(1.0, (brim_z(phi) - HZC) / AZ)))


def shell_pt(phi, e, off=0.0):
    return Vector(((AX + off) * math.cos(e) * math.sin(phi), HYC + (AY + off) * math.cos(e) * math.cos(phi),
                   HZC + (AZ + off) * math.sin(e)))


def shell_surface(nu=40, nv=11, off=0.0, lift=0.0):
    """Helmet-shaped dome from the brim (+lift radians) to a pole on top."""
    mb = MB()
    rings = []
    for j in range(nv):
        t = j / nv
        ring = []
        for i in range(nu):
            phi = 2 * math.pi * i / nu
            eb = e_brim(phi) + lift
            e = eb + (math.pi / 2 - eb) * (1 - (1 - t) ** 1.25)
            ring.append(shell_pt(phi, e, off))
        rings.append(mb.ring(ring))
    for a, b in zip(rings, rings[1:]):
        mb.bridge(a, b)
    pole = mb.bm.verts.new(shell_pt(0, math.pi / 2, off))
    last = rings[-1]
    for i in range(nu):
        mb.face([last[i], last[(i + 1) % nu], pole])
    return mb


def shell_slab(phi0, phi1, e0, e1, off0, off1, nu=8, nv=4, e_fn=None):
    """Thick patch lying on the shell (velcro, shroud, patches)."""
    mb = MB()

    def grid(off):
        g = []
        for j in range(nv + 1):
            row = []
            for i in range(nu + 1):
                phi = phi0 + (phi1 - phi0) * i / nu
                e = e0 + (e1 - e0) * j / nv
                if e_fn:
                    e = e_fn(phi, j / nv)
                row.append(mb.bm.verts.new(shell_pt(phi, e, off)))
            g.append(row)
        return g
    lo, hi = grid(off0), grid(off1)
    for j in range(nv):
        for i in range(nu):
            mb.face([hi[j][i], hi[j][i + 1], hi[j + 1][i + 1], hi[j + 1][i]])
            mb.face([lo[j][i], lo[j + 1][i], lo[j + 1][i + 1], lo[j][i + 1]])
    border = [lo[0][i] for i in range(nu + 1)] + [lo[j][nu] for j in range(1, nv + 1)] + \
             [lo[nv][i] for i in range(nu - 1, -1, -1)] + [lo[j][0] for j in range(nv - 1, 0, -1)]
    border_hi = [hi[0][i] for i in range(nu + 1)] + [hi[j][nu] for j in range(1, nv + 1)] + \
                [hi[nv][i] for i in range(nu - 1, -1, -1)] + [hi[j][0] for j in range(nv - 1, 0, -1)]
    mb.bridge(border, border_hi)
    return mb


def helmet(kit):
    P = "Head"
    # shell + solidify
    mb = shell_surface(40, 11)
    shell = mb.obj("helmet_shell", M("helmet"))
    sol = shell.modifiers.new("Solid", "SOLIDIFY")
    sol.thickness = 0.03
    sol.offset = -1
    sol.use_even_offset = True
    sol.use_rim = True
    geo.apply_mods(shell)
    finish(shell, 0.0, 1)
    kit.add(shell, P, "helmet")
    # rubber edge trim
    path = [shell_pt(2 * math.pi * i / 40, e_brim(2 * math.pi * i / 40), -0.014) for i in range(40)]
    kit.add(sweep_obj("trim", M("rubber"), geo.circle(0.021, 8), path, closed=True), P, "helmetDark")
    # NVG shroud + mount
    eb0 = e_brim(0)
    mb = shell_slab(-0.2, 0.2, eb0 + 0.04, eb0 + 0.24, 0.004, 0.026, 6, 3)
    shroud = mb.obj("shroud", M("polymer_black"))
    finish(shroud, 0.006, 1)
    kit.add(shroud, P, "helmetDark")
    front = shell_pt(0, eb0 + 0.04, 0.03)
    kit.add(soft("nvg_mount", M("polymer_black"), (0, front.y + 0.02, front.z - 0.035), (0.12, 0.065, 0.09),
                 r_side=0.02, r_top=0.015, r_bot=0.015, finish_bevel=0.004), P, "helmetDark")
    # side rails that follow the high cut
    for s in (-1, 1):
        pts = []
        for k in range(13):
            phi = s * math.radians(52 + 76 * k / 12)
            z = brim_z(phi) + 0.07
            e = math.asin((z - HZC) / AZ)
            pts.append(shell_pt(phi, e, 0.016))
        rail = sweep_obj("rail", M("polymer_black"), rrect(0.03, 0.058, 0.008, 1), pts, up=(0, 0, 1))
        finish(rail, 0.0, 1)
        kit.add(rail, P, "helmetDark")
        for k in (3, 9):  # rail screws
            p = pts[k]
            n = (p - Vector((0, HYC, HZC))).normalized()
            mb = MB()
            m = Matrix.Translation(p + n * 0.016) @ n.to_track_quat("Z", "Y").to_matrix().to_4x4()
            mb.lathe([(0.0, 0.006), (0.012, 0.004), (0.014, 0.0)], 10, "Z", (0.0, 0.0), m=m)
            kit.add(mb.obj("screw", M("metal")), P, "metal")
    # velcro: top and back, flag patch on the back velcro
    kit.add(geo.smooth(shell_slab(-0.36, 0.36, 0.92, 1.22, 0.001, 0.009, 6, 3).obj("velcro_top", M("velcro"))), P, "strap")
    kit.add(geo.smooth(shell_slab(math.pi - 0.42, math.pi + 0.42, 0.06, 0.4, 0.001, 0.009, 6, 3).obj("velcro_back", M("velcro"))), P, "strap")
    kit.add(geo.smooth(shell_slab(math.pi - 0.3, math.pi + 0.3, 0.1, 0.34, 0.009, 0.015, 6, 3).obj("flag", M("patch_base"))), P, "band")
    kit.add(geo.smooth(shell_slab(math.pi - 0.3, math.pi + 0.3, 0.19, 0.25, 0.015, 0.018, 6, 1).obj("flag_band", M("patch_emblem"))), P, "band")
    # chin straps + buckles
    for s in (-1, 1):
        path = catmull_path([(s * 0.672, 0.05, 1.64), (s * 0.628, 0.1, 1.46), (s * 0.622, 0.16, 1.3), (s * 0.61, 0.22, 1.12),
                             (s * 0.57, 0.27, 0.99)], 3)
        st = sweep_obj("chinstrap", M("webbing"), rrect(0.05, 0.012, 0.004, 1), path, up=(s, 0, 0))
        kit.add(st, P, "strap")
        kit.add(soft("buckle", M("polymer_black"), (s * 0.632, 0.19, 1.2), (0.03, 0.08, 0.09), r_side=0.012, r_top=0.01,
                     r_bot=0.01, tiny=True), P, "helmetDark")

    # --- variant: fabric helmet cover (camo) with a bungee band
    mb = shell_surface(40, 10, off=0.009, lift=0.05)
    cover = mb.obj("cover", M("uniform"))
    wrinkle(cover, lambda co, th: 0.004 * math.sin(40 * co.z + 3 * th) * bell(co.z, 1.8, 0.2))
    geo.smooth(cover)
    kit.add(cover, P, "camoA", "cover")
    band = [shell_pt(2 * math.pi * i / 32, math.asin((1.9 - HZC) / AZ), 0.022) for i in range(32)]
    kit.add(sweep_obj("bungee", M("webbing"), geo.circle(0.012, 6), band, closed=True), P, "strap", "cover")

    # --- variant: goggles pushed up on the helmet front
    zc = 1.92
    ec = math.asin((zc - HZC) / AZ)

    def bend(obj, depth_front):
        """Curves a flat, front-facing (XZ) piece around the helmet front."""
        for v in obj.data.vertices:
            x = v.co.x
            ex = (AX + 0.03) * math.cos(ec)
            ey = (AY + 0.03) * math.cos(ec)
            yfront = HYC + ey * math.sqrt(max(0.0, 1 - (x / ex) ** 2))
            v.co.y += yfront - depth_front
        obj.data.update()
    mb = MB()
    outer = geo.superellipse(0.68, 0.2, 3.4, 28)
    mb.prism(outer, "Y", -0.03, 0.045)
    frame = mb.obj("goggle_frame", M("rubber"))
    geo.cut(frame, lambda m: m.prism(geo.superellipse(0.6, 0.13, 3.4, 28), "Y", -0.1, 0.1))
    frame.data.transform(tr(0, 0, zc))
    bend(frame, 0.0)
    finish(frame, 0.008, 1)
    kit.add(frame, P, "helmetDark", "goggles")
    mb = MB()
    mb.prism(geo.superellipse(0.62, 0.15, 3.4, 28), "Y", 0.0, 0.01)
    lens = mb.obj("goggle_lens", M("lens"))
    lens.data.transform(tr(0, 0, zc))
    bend(lens, 0.0)
    geo.smooth(lens)
    kit.add(lens, P, "lens", "goggles")
    strap = [shell_pt(2 * math.pi * i / 32, ec, 0.012) for i in range(32)]
    kit.add(sweep_obj("goggle_strap", M("webbing"), [(-0.006, -0.035), (0.006, -0.035), (0.006, 0.035), (-0.006, 0.035)], strap,
                      closed=True), P, "strap", "goggles")

    # --- variant: comms headset (ear cups under the high cut, boom mic)
    for s in (-1, 1):
        mb = MB()
        prof = [(0.16, 0.598), (0.185, 0.62), (0.19, 0.67), (0.18, 0.715), (0.13, 0.738), (0.0, 0.742)]
        mb.lathe([(r, s * x) for r, x in (prof if s > 0 else list(reversed(prof)))], 20, "X", (0.0, 1.42))
        cup = mb.obj("ear_cup", M("polymer_black"))
        finish(cup, 0.0, 1)
        kit.add(cup, P, "helmetDark", "headset")
        stub = catmull_path([(s * 0.668, 0.0, 1.58), (s * 0.668, 0.0, 1.66), (s * 0.66, -0.02, 1.74)], 2)
        kit.add(sweep_obj("band_stub", M("polymer_black"), rrect(0.06, 0.02, 0.006, 1), stub, up=(s, 0, 0)), P, "helmetDark", "headset")
    boom = catmull_path([(-0.73, 0.1, 1.38), (-0.7, 0.34, 1.3), (-0.56, 0.56, 1.23), (-0.34, 0.66, 1.2)], 3)
    kit.add(sweep_obj("boom", M("polymer_black"), geo.circle(0.013, 6), boom, up=(0, 0, 1)), P, "helmetDark", "headset")
    kit.add(soft("mic", M("rubber"), (-0.31, 0.665, 1.2), (0.09, 0.045, 0.045), r_side=0.02, r_top=0.02, r_bot=0.02, axis="X", tiny=True),
            P, "helmetDark", "headset")


# ------------------------------------------------------------------ patches

def shield_outline(w, h):
    return fillet([(-w / 2, h / 2), (w / 2, h / 2), (w / 2, -h * 0.05), (0, -h / 2), (-w / 2, -h * 0.05)],
                  [w * 0.12, w * 0.12, w * 0.3, w * 0.12, w * 0.3], 3)


def ash_leaf(scale):
    """Stylised pinnate ash leaf: 3 leaflet pairs, a tip leaflet and a stem."""
    shapes = [[Vector((-0.035 * scale, -0.5 * scale)), Vector((0.035 * scale, -0.5 * scale)),
               Vector((0.035 * scale, 0.3 * scale)), Vector((-0.035 * scale, 0.3 * scale))]]
    for k, zc in enumerate((-0.18, 0.04, 0.24)):
        size = (0.22 - 0.03 * k) * scale
        for s in (-1, 1):
            shapes.append(ellipse(size, size * 0.34, 14, s * (size * 0.8), zc * scale + size * 0.25, s * math.radians(28)))
    shapes.append(ellipse(0.1 * scale, 0.2 * scale, 14, 0, 0.42 * scale))
    return shapes


def insignia(kit, piece, key_pos, axis, facing, size=0.2):
    """Ashford shield patch: tan border, olive field, tan ash leaf.
    key_pos: patch centre; axis: 'Y' (front/back facing) or 'X' (side facing);
    facing: +1/-1 direction the patch faces."""
    cx, cy, cz = key_pos

    def plate(outline, a0, a1, mat, name):
        mb = MB()
        if axis == "Y":
            mb.prism([(p.x * facing + cx, p.y + cz) for p in outline], "Y", cy + facing * a0, cy + facing * a1)
        else:
            mb.prism([(p.x * -facing + cy, p.y + cz) for p in outline], "X", cx + facing * a0, cx + facing * a1)
        o = mb.obj(name, mat)
        geo.smooth(o, 40)
        return o
    kit.add(plate(shield_outline(size * 1.12, size * 1.25), -0.004, 0.004, M("patch_border"), "patch_border"), piece, "band")
    kit.add(plate(shield_outline(size, size * 1.12), 0.0, 0.007, M("patch_base"), "patch_field"), piece, "band")
    for i, shape in enumerate(ash_leaf(size * 0.9)):
        kit.add(plate([p + Vector((0, -size * 0.04)) for p in shape], 0.004, 0.0095, M("patch_emblem"), "patch_leaf"), piece, "band")


# ------------------------------------------------------------------ torso

def mag_pouch(kit, x, plate_y):
    P = "Torso"
    yc = plate_y + 0.075
    kit.add(soft("mag_pouch", M("pouch"), (x, yc, -0.3), (0.29, 0.15, 0.4), r_side=0.04, r_top=0.03, r_bot=0.05, puff=0.04, mid=1),
            P, "pouch")
    kit.add(soft("mag", M("mag_tan"), (x, yc, -0.05), (0.21, 0.105, 0.16), r_side=0.02, r_top=0.0, r_bot=0.0, tiny=True), P, "camoB")
    kit.add(soft("mag_base", M("mag_tan"), (x, yc, 0.045), (0.228, 0.12, 0.034), r_side=0.02, r_top=0.012, r_bot=0.006, tiny=True),
            P, "camoB")
    path = catmull_path([(x, yc + 0.078, -0.16), (x, yc + 0.072, -0.02), (x, yc + 0.045, 0.058), (x, yc, 0.072),
                         (x, yc - 0.045, 0.058), (x, yc - 0.072, -0.02), (x, yc - 0.076, -0.12)], 3)
    kit.add(sweep_obj("bungee", M("webbing"), geo.circle(0.012, 5), path, up=(1, 0, 0)), P, "strap")
    kit.add(soft("pull_tab", M("rubber"), (x, yc + 0.085, 0.0), (0.075, 0.016, 0.05), r_side=0.006, r_top=0.01, r_bot=0.01,
                 tiny=True), P, "helmetDark")
    # pouch front elastic band
    kit.add(soft("pouch_band", M("webbing"), (x, yc + 0.078, -0.2), (0.28, 0.012, 0.05), r_side=0.004, r_top=0.004, r_bot=0.004,
                 tiny=True), P, "strap")


def molle_strip(kit, piece, pts, height, mat_key="webbing"):
    sec = [(-0.006, -height / 2), (0.006, -height / 2), (0.006, height / 2), (-0.006, height / 2)]
    kit.add(sweep_obj("molle", M(mat_key), sec, pts, up=(0, 0, 1), smooth_angle=40), piece, "strap")


def side_arc(w, d, r, x_min, z, off, side):
    pts = [p for p in rrect(w + 2 * off, d + 2 * off, r + off, 3) if p.x > x_min]
    pts = [Vector((side * p.x, p.y, z)) for p in pts]
    return pts if side > 0 else list(reversed(pts))


def torso(kit):
    P = "Torso"
    # combat shirt shell (visible at the sides, shoulders and waist)
    mb = MB()
    soft_block(mb, (0, 0, 0.005), (2.04, 1.06, 2.03), r_side=0.16, r_top=0.12, r_bot=0.0, seg=3, vseg=3, mid=4, cap_bot=False)
    shirt = mb.obj("shirt", M("uniform"))
    wrinkle(shirt, lambda co, th: 0.006 * math.sin(18 * co.z + 2 * th) * bell(co.z, -0.75, 0.25))
    geo.smooth(shirt)
    kit.add(shirt, P, "cloth")
    # rolled shemagh around the neck (R6 heads have no neck, so it frames the head)
    path = [Vector((0.655 * math.sin(a), 0.03 + 0.625 * math.cos(a), 1.03 + 0.03 * math.cos(a))) for a in
            (2 * math.pi * i / 32 for i in range(32))]
    scarf = sweep_obj("scarf", M("scarf"), geo.ellipse(0.058, 0.075, 8), path, closed=True)
    wrinkle(scarf, lambda co, th: 0.0)
    for v in scarf.data.vertices:
        a = math.atan2(v.co.x, v.co.y)
        v.co.z += 0.018 * math.sin(7 * a) + 0.01 * math.sin(13 * a + 1)
    geo.smooth(scarf)
    kit.add(scarf, P, "camoB")

    # plate carrier: front and back plate bags (shooter's cut), wrapped
    outline = fillet([(-0.64, -0.56), (0.64, -0.56), (0.64, 0.36), (0.46, 0.74), (-0.46, 0.74), (-0.64, 0.36)],
                     [0.08, 0.08, 0.1, 0.06, 0.06, 0.1], 4)
    for s in (1, -1):
        mb = MB()
        mb.prism(outline, "Y", s * 0.515, s * 0.655)
        plate = mb.obj("plate_bag", M("plate"))
        for v in plate.data.vertices:
            v.co.y -= s * 0.07 * (v.co.x / 0.64) ** 2
        finish(plate, 0.035, 3, 35)
        kit.add(plate, P, "plate")
    plate_front = lambda x: 0.655 - 0.07 * (x / 0.64) ** 2  # noqa: E731
    # shoulder straps with pads
    for s in (-1, 1):
        path = catmull_path([(s * 0.5, 0.57, 0.62), (s * 0.505, 0.52, 0.86), (s * 0.515, 0.33, 1.035), (s * 0.52, 0.0, 1.075),
                             (s * 0.515, -0.33, 1.035), (s * 0.505, -0.52, 0.86), (s * 0.5, -0.57, 0.62)], 3)
        st = sweep_obj("shoulder_strap", M("vest"), rrect(0.24, 0.05, 0.02, 1), path, up=(0, 1, 0),
                       scale=lambda i, t: (1 + 0.18 * bell(t, 0.5, 0.2), 1 + 0.5 * bell(t, 0.5, 0.2)))
        kit.add(st, P, "vest")
    # cummerbund band (closed ring with rims)
    mb = MB()
    rings = []
    for (w, d, z) in ((2.03, 1.11, -0.62), (2.075, 1.155, -0.62), (2.075, 1.155, 0.16), (2.03, 1.11, 0.16)):
        rings.append([Vector((p.x, p.y, z)) for p in rrect(w, d, 0.22, 6)])
    made = mb.loft(rings, cap0=False, cap1=False)
    mb.bridge(made[-1], made[0])
    cb = mb.obj("cummerbund", M("vest"))
    finish(cb, 0.012, 2, 35)
    kit.add(cb, P, "vest")
    for s in (-1, 1):
        for z in (-0.46, -0.26, -0.06):
            molle_strip(kit, P, side_arc(2.075, 1.155, 0.22, 0.72, z, 0.008, s), 0.06)
    # triple open-top magazine pouches
    for x in (-0.33, 0.0, 0.33):
        mag_pouch(kit, x, plate_front(x))
    # MOLLE rows on the plate bag behind the pouches
    for z in (-0.53, 0.17):
        pts = [Vector((x / 5.0, plate_front(x / 5.0) + 0.006, z)) for x in range(-3, 4)]
        molle_strip(kit, P, pts, 0.05)
    # admin pouch with the Ashford shield
    kit.add(soft("admin", M("pouch"), (0, 0.698, 0.41), (0.6, 0.09, 0.3), r_side=0.04, r_top=0.03, r_bot=0.03, puff=0.03),
            P, "pouch")
    kit.add(soft("zip_pull", M("metal"), (0.24, 0.75, 0.53), (0.04, 0.012, 0.06), r_side=0.006, r_top=0.008, r_bot=0.008, tiny=True),
            P, "metal")
    insignia(kit, P, (0.0, 0.743, 0.4), "Y", 1, 0.2)

    # battle belt, buckle, back pouches
    belt = [Vector((p.x, p.y, -0.93)) for p in rrect(2.09, 1.17, 0.24, 3)]
    kit.add(sweep_obj("belt", M("webbing"), rrect(0.032, 0.15, 0.008, 1), belt, closed=True, smooth_angle=50), P, "strap")
    kit.add(soft("buckle", M("polymer_black"), (0, 0.608, -0.93), (0.22, 0.03, 0.12), r_side=0.02, r_top=0.02, r_bot=0.02,
                 tiny=True), P, "helmetDark")
    kit.add(soft("ifak", M("pouch"), (0, -0.665, -0.92), (0.36, 0.15, 0.24), r_side=0.05, r_top=0.04, r_bot=0.04, puff=0.05),
            P, "pouch")
    for s in (-1, 1):
        kit.add(soft("util", M("pouch"), (s * 0.62, -0.655, -0.92), (0.22, 0.13, 0.21), r_side=0.04, r_top=0.03, r_bot=0.03,
                     puff=0.05), P, "pouch")

    # zip-on assault pack
    kit.add(soft("pack_body", M("pack"), (0, -0.865, 0.04), (1.34, 0.46, 1.3), r_side=0.13, r_top=0.1, r_bot=0.09, puff=0.05,
                 mid=3, seg=4), P, "pack")
    kit.add(soft("pack_lid", M("pack"), (0, -0.87, 0.725), (1.3, 0.46, 0.14), r_side=0.12, r_top=0.05, r_bot=0.02, dome=0.02,
                 seg=4), P, "pack")
    kit.add(soft("pack_pocket", M("pack"), (0, -1.155, -0.12), (1.0, 0.17, 0.7), r_side=0.08, r_top=0.07, r_bot=0.07, puff=0.06,
                 mid=2), P, "pack")
    for s in (-1, 1):
        kit.add(soft("bottle", M("pouch"), (s * 0.745, -0.86, -0.26), (0.16, 0.34, 0.5), r_side=0.05, r_top=0.04, r_bot=0.05,
                     puff=0.06), P, "pouch")
    for z in (-0.3, -0.12, 0.06):
        pts = [Vector((x / 5.0, -1.245, z)) for x in range(-2, 3)]
        molle_strip(kit, P, pts, 0.045)
    for s in (-1, 1):  # vertical compression straps + buckles
        path = catmull_path([(s * 0.3, -1.06, 0.8), (s * 0.3, -1.1, 0.72), (s * 0.3, -1.25, 0.22), (s * 0.3, -1.25, -0.42),
                             (s * 0.3, -1.1, -0.63)], 3)
        kit.add(sweep_obj("comp_strap", M("webbing"), rrect(0.07, 0.012, 0.004, 1), path, up=(0, -1, 0)), P, "strap")
        kit.add(soft("pack_buckle", M("polymer_black"), (s * 0.3, -1.262, 0.34), (0.1, 0.028, 0.09), r_side=0.012, r_top=0.012,
                     r_bot=0.012, tiny=True), P, "helmetDark")
    handle = catmull_path([(-0.16, -0.87, 0.79), (-0.1, -0.87, 0.85), (0.1, -0.87, 0.85), (0.16, -0.87, 0.79)], 3)
    kit.add(sweep_obj("handle", M("webbing"), rrect(0.05, 0.014, 0.004, 1), handle, up=(0, 0, 1)), P, "strap")
    # radio in a pouch on the pack's left side, antenna is a variant
    kit.add(soft("radio_pouch", M("pouch"), (-0.755, -0.8, 0.28), (0.17, 0.26, 0.42), r_side=0.04, r_top=0.02, r_bot=0.04,
                 puff=0.04), P, "pouch")
    kit.add(soft("radio_top", M("polymer_black"), (-0.755, -0.8, 0.53), (0.13, 0.19, 0.09), r_side=0.02, r_top=0.02, r_bot=0.0,
                 tiny=True), P, "helmetDark")
    mb = MB()
    mb.lathe([(0.02, 0.575), (0.02, 0.62), (0.014, 0.63), (0.0, 0.632)], 12, "Z", (-0.72, -0.76))
    kit.add(geo.smooth(mb.obj("radio_knob", M("rubber"))), P, "helmetDark")
    ant = [Vector((-0.78, -0.84 - 0.1 * t * t, 0.57 + 1.15 * t)) for t in (k / 8 for k in range(9))]
    kit.add(sweep_obj("antenna", M("rubber"), geo.circle(0.016, 6), ant, up=(1, 0, 0), scale=lambda i, t: 1 - 0.45 * t),
            P, "helmetDark", "antenna")
    # hydration tube over the right shoulder, clipped to the strap
    tube = catmull_path([(0.38, -0.72, 0.8), (0.46, -0.45, 1.06), (0.52, -0.1, 1.12), (0.54, 0.25, 1.1), (0.54, 0.55, 0.9),
                         (0.53, 0.66, 0.66)], 4)
    kit.add(sweep_obj("hydration", M("rubber"), geo.circle(0.02, 6), tube, up=(1, 0, 0)), P, "helmetDark")
    kit.add(soft("bite_valve", M("rubber"), (0.53, 0.675, 0.6), (0.05, 0.05, 0.1), r_side=0.02, r_top=0.02, r_bot=0.02, tiny=True),
            P, "helmetDark")
    # bedroll strapped on the lid (variant)
    mb = MB()
    mb.lathe([(0.0, -0.66), (0.16, -0.66), (0.19, -0.635), (0.19, 0.635), (0.16, 0.66), (0.0, 0.66)], 24, "X", (-0.87, 0.99))
    roll = mb.obj("bedroll", M("bedroll"))
    geo.smooth(roll, 50)
    kit.add(roll, P, "camoB", "bedroll")
    for x in (-0.4, 0.4):
        mb = MB()
        mb.lathe([(0.188, x - 0.03), (0.2, x - 0.028), (0.2, x + 0.028), (0.188, x + 0.03)], 24, "X", (-0.87, 0.99))
        kit.add(geo.smooth(mb.obj("roll_strap", M("webbing"))), P, "strap", "bedroll")


# ------------------------------------------------------------------ arms

def arm(kit, s):
    P = "Arm" if s > 0 else "Arm_L"
    cx = 1.5 * s
    # sleeve: z -0.58 .. 1.03 (clear of the R6 arm's top face to avoid z-fighting)
    mb = MB()
    soft_block(mb, (cx, 0, 0.225), (1.075, 1.075, 1.61), r_side=0.2, r_top=0.17, r_bot=0.0, seg=3, vseg=3, mid=14, cap_bot=False)
    sleeve = mb.obj("sleeve", M("uniform"))

    def folds(co, th):
        z = co.z
        crease = crease_wave(22 * z + 3.2 * math.sin(2 * th) + th)          # diagonal elbow folds
        return (0.03 * crease * bell(z, -0.05, 0.22) + 0.018 * crease_wave(40 * z + 4 * th) * bell(z, -0.5, 0.08) +
                0.008 * math.sin(9 * z + 2 * th) + 0.018 * (z - 0.2) / 0.8)  # slight taper toward the cuff
    wrinkle(sleeve, folds)
    geo.smooth(sleeve)
    kit.add(sleeve, P, "cloth")
    # seam piping down the front and back outer edges of the sleeve
    for y in (0.47, -0.47):
        seam = [Vector((cx + s * 0.47, y, z)) for z in (0.95, 0.6, 0.2, -0.2, -0.5)]
        kit.add(sweep_obj("seam", M("uniform"), geo.circle(0.011, 5), seam, up=(s, 0, 0)), P, "cloth")
    # shoulder pocket + flap, patch (flag on the right, shield on the left)
    kit.add(soft("pocket", M("uniform"), (cx + s * 0.555, 0.02, 0.5), (0.05, 0.5, 0.44), r_side=0.02, r_top=0.04, r_bot=0.05),
            P, "cloth")
    kit.add(soft("flap", M("uniform"), (cx + s * 0.568, 0.02, 0.765), (0.06, 0.54, 0.14), r_side=0.025, r_top=0.03, r_bot=0.04),
            P, "cloth")
    if s > 0:
        mb = MB()
        mb.prism(rrect(0.36, 0.22, 0.02, 2, 0.02, 0.49), "X", cx + 0.578, cx + 0.588)
        kit.add(geo.smooth(mb.obj("flag", M("patch_base")), 40), P, "band")
        mb = MB()
        mb.prism(rrect(0.36, 0.06, 0.0, 1, 0.02, 0.49), "X", cx + 0.586, cx + 0.592)
        kit.add(geo.smooth(mb.obj("flag_stripe", M("patch_emblem")), 40), P, "band")
        mb = MB()
        mb.prism([(-0.14, 0.6), (-0.04, 0.49), (-0.14, 0.38), (-0.1, 0.38), (0.0, 0.49), (-0.1, 0.6)], "X", cx + 0.586, cx + 0.593)
        kit.add(geo.smooth(mb.obj("flag_chevron", M("patch_border")), 40), P, "band")
    else:
        insignia(kit, P, (cx - 0.578, 0.02, 0.5), "X", -1, 0.19)
    # integrated elbow pad
    kit.add(soft("elbow_pad", M("kneepad"), (cx + s * 0.548, -0.03, -0.1), (0.05, 0.44, 0.36), r_side=0.02, r_top=0.12, r_bot=0.12),
            P, "knee")
    # cuff with velcro tab
    cuff = [Vector((cx + p.x, p.y, -0.56)) for p in rrect(1.1, 1.1, 0.23, 3)]
    kit.add(sweep_obj("cuff", M("uniform"), rrect(0.028, 0.08, 0.01, 1), cuff, closed=True), P, "cloth")
    kit.add(soft("cuff_tab", M("uniform"), (cx + s * 0.568, 0.2, -0.56), (0.03, 0.15, 0.07), r_side=0.01, r_top=0.02, r_bot=0.02,
                 tiny=True), P, "cloth")
    # glove (hand = lower 0.42 of the R6 arm): shell, knuckles, back plate, wrist strap, palm
    mb = MB()
    soft_block(mb, (cx, 0, -0.815), (1.1, 1.1, 0.42), r_side=0.24, r_top=0.0, r_bot=0.15, seg=3, vseg=3, mid=1, puff=0.02,
               cap_top=False)
    glove = mb.obj("glove", M("glove"))
    geo.smooth(glove)
    kit.add(glove, P, "glove")
    for y in (-0.3, -0.1, 0.1, 0.3):
        kit.add(soft("knuckle", M("kneecap"), (cx + s * 0.562, y, -0.9), (0.04, 0.17, 0.1), r_side=0.02, r_top=0.035, r_bot=0.035,
                     tiny=True), P, "knee")
    kit.add(soft("hand_plate", M("kneecap"), (cx + s * 0.562, 0.0, -0.77), (0.036, 0.6, 0.11), r_side=0.02, r_top=0.04,
                 r_bot=0.04, tiny=True), P, "knee")
    wrist = [Vector((cx + p.x, p.y, -0.655)) for p in rrect(1.12, 1.12, 0.25, 3)]
    kit.add(sweep_obj("wrist_strap", M("webbing"), rrect(0.02, 0.06, 0.006, 1), wrist, closed=True), P, "strap")
    kit.add(soft("wrist_tab", M("webbing"), (cx + s * 0.575, -0.22, -0.655), (0.028, 0.2, 0.07), r_side=0.01, r_top=0.02,
                 r_bot=0.02, tiny=True), P, "strap")
    kit.add(soft("palm", M("glove_palm"), (cx - s * 0.548, 0.0, -0.86), (0.035, 0.8, 0.3), r_side=0.02, r_top=0.08, r_bot=0.08,
                 tiny=True), P, "glove")


# ------------------------------------------------------------------ legs

def leg(kit, s):
    P = "Leg" if s > 0 else "Leg_L"
    cx = 0.5 * s
    mb = MB()
    soft_block(mb, (cx + s * 0.012, 0, -1.725), (1.066, 1.07, 1.45), r_side=0.2, r_top=0.0, r_bot=0.0, seg=3, mid=16,
               cap_top=False, cap_bot=False)
    tr_ = mb.obj("trousers", M("uniform"))

    def folds(co, th):
        z = co.z
        blouse = 0.05 * bell(z, -2.37, 0.09)
        return (blouse + 0.022 * crease_wave(46 * z + 5 * th) * bell(z, -2.32, 0.1) +
                0.026 * crease_wave(20 * z + 2.5 * math.sin(3 * th) + th) * bell(z, -2.05, 0.16) +
                0.01 * math.sin(8 * z + 2 * th) + 0.012 * bell(z, -1.3, 0.3))
    wrinkle(tr_, folds)
    geo.smooth(tr_)
    kit.add(tr_, P, "cloth")
    # bellowed cargo pocket on the outer thigh
    kit.add(soft("cargo", M("uniform"), (cx + s * 0.55, 0.02, -1.58), (0.06, 0.48, 0.46), r_side=0.02, r_top=0.03, r_bot=0.06,
                 puff=0.12, mid=1), P, "cloth")
    kit.add(soft("cargo_flap", M("uniform"), (cx + s * 0.565, 0.02, -1.34), (0.07, 0.52, 0.13), r_side=0.025, r_top=0.03,
                 r_bot=0.04), P, "cloth")
    for y in (-0.14, 0.18):
        mb = MB()
        x0 = cx + s * 0.6
        prof = [(0.0, x0 + s * 0.012), (0.018, x0 + s * 0.01), (0.022, x0)]
        mb.lathe([(r, x) for r, x in (prof if s > 0 else list(reversed(prof)))], 8, "X", (y, -1.37))
        kit.add(geo.smooth(mb.obj("snap", M("metal"))), P, "metal")
    # knee pad: shell, rubber cap, straps around the back
    kit.add(soft("knee_pad", M("kneepad"), (cx, 0.582, -1.97), (0.6, 0.14, 0.46), r_side=0.13, r_top=0.12, r_bot=0.12, puff=0.08,
                 seg=3, vseg=3), P, "knee")
    kit.add(soft("knee_cap", M("kneecap"), (cx, 0.646, -1.97), (0.38, 0.04, 0.28), r_side=0.15, r_top=0.12, r_bot=0.12,
                 seg=3, vseg=3), P, "knee")
    for z in (-1.92, -1.97, -2.02):
        kit.add(soft("knee_rib", M("kneecap"), (cx, 0.667, z), (0.26, 0.012, 0.018), r_side=0.006, r_top=0.008, r_bot=0.008,
                     tiny=True), P, "knee")
    for z in (-1.82, -2.13):
        # strap runs around the back of the leg, from one side of the pad to the other
        ring = [Vector((cx + p.x, p.y, z)) for p in rrect(1.1, 1.1, 0.23, 3)]
        start = max(range(len(ring)), key=lambda i: (ring[i].y < 0.5 and ring[i - 1].y >= 0.5))
        run = []
        for k in range(len(ring)):
            p = ring[(start + k) % len(ring)]
            if p.y >= 0.5:
                break
            run.append(p)
        sec = [(-0.009, -0.03), (0.009, -0.03), (0.009, 0.03), (-0.009, 0.03)]
        kit.add(sweep_obj("pad_strap", M("webbing"), sec, run, up=(0, 0, 1), smooth_angle=40), P, "strap")
    # boot: suede upper, leather toe and heel, sole, laces, eyelets, pull loop
    mb = MB()
    soft_block(mb, (cx, 0.03, -2.71), (1.1, 1.14, 0.62), r_side=0.22, r_top=0.0, r_bot=0.0, seg=3, mid=2, cap_top=False)
    upper = mb.obj("boot_upper", M("boot"))
    geo.smooth(upper)
    kit.add(upper, P, "boot")
    kit.add(soft("toe", M("boot_leather"), (cx, 0.4, -2.89), (1.03, 0.5, 0.23), r_side=0.22, r_top=0.11, r_bot=0.0, seg=3,
                 vseg=3, dome=0.015), P, "boot")
    kit.add(soft("heel", M("boot_leather"), (cx, -0.43, -2.865), (1.05, 0.28, 0.27), r_side=0.12, r_top=0.08, r_bot=0.0),
            P, "boot")
    collar = [Vector((cx + p.x, 0.03 + p.y, -2.415)) for p in rrect(1.12, 1.16, 0.24, 3)]
    kit.add(sweep_obj("boot_collar", M("boot_leather"), geo.circle(0.032, 6), collar, closed=True), P, "boot")
    kit.add(soft("sole", M("sole"), (cx, 0.04, -2.99), (1.14, 1.24, 0.09), r_side=0.24, r_top=0.012, r_bot=0.02, seg=3),
            P, "sole")
    for k, z in enumerate((-2.49, -2.57, -2.65, -2.73)):
        mb = MB()
        m = tr(cx, 0.612, z) @ rot("Y", 12 if k % 2 else -12)
        mb.cyl((0, 0, 0), 0.014, 0.3, "X", 6, m=m)
        kit.add(geo.smooth(mb.obj("lace", M("webbing"))), P, "strap")
        for ex in (-0.17, 0.17):
            mb = MB()
            mb.lathe([(0.018, 0.598), (0.02, 0.608), (0.012, 0.612), (0.0, 0.613)], 6, "Y", (cx + ex, z))
            kit.add(geo.smooth(mb.obj("eyelet", M("metal"))), P, "metal")
    loop = catmull_path([(cx - 0.07, -0.565, -2.46), (cx, -0.6, -2.34), (cx + 0.07, -0.565, -2.46)], 3)
    kit.add(sweep_obj("pull_loop", M("webbing"), rrect(0.05, 0.012, 0.004, 1), loop, up=(0, -1, 0)), P, "strap")


# ------------------------------------------------------------------ assembly

def build():
    """Models the kit in character space. Returns {piece: {object name: obj}}
    with every object's mesh moved into its limb's local frame."""
    kit = Kit()
    helmet(kit)
    torso(kit)
    for s in (1, -1):
        arm(kit, s)
        leg(kit, s)
    groups = {}
    for obj, piece, key, variant in kit.items:
        name = f"{NAME}_{piece}_{key}" + (f"_v_{variant}" if variant else "")
        groups.setdefault(piece, {}).setdefault(name, []).append(obj)
    out = {}
    for piece, named in groups.items():
        c = Vector(CENTRES[piece])
        out[piece] = {}
        for name, objs in sorted(named.items()):
            o = geo.join_keep_normals(objs, name) if len(objs) > 1 else objs[0]
            o.name = name
            o.data.name = name
            o.data.transform(Matrix.Translation(-c))
            out[piece][name] = o
    return out


# ------------------------------------------------------------------ R6 preview body

SKIN = (222, 176, 138)


def r6_body(coll):
    """R6 dummy (preview only, never exported): limb blocks, R6-style head, a
    simple original face."""
    parts = {}
    skin = mats.flat("M_Skin", SKIN, 0.55)
    uni = mats.flat("M_Uniform_Base", (88, 96, 62), 0.85)
    for piece, (c, size) in {"Torso": ((0, 0, 0), (2, 1, 2)), "Arm": ((1.5, 0, 0), (1, 1, 2)), "Arm_L": ((-1.5, 0, 0), (1, 1, 2)),
                             "Leg": ((0.5, 0, -2), (1, 1, 2)), "Leg_L": ((-0.5, 0, -2), (1, 1, 2))}.items():
        mb = MB()
        mb.box((0, 0, 0), size)
        o = mb.obj(f"R6_{piece}", uni, coll)
        finish(o, 0.02, 2)
        parts[piece] = [o]
    mb = MB()
    prof = [(0.0, -0.6), (0.4, -0.6), (0.52, -0.57), (0.585, -0.5), (0.6, -0.4), (0.6, 0.4), (0.585, 0.5), (0.52, 0.57),
            (0.4, 0.6), (0.0, 0.6)]
    mb.lathe([(r, z) for r, z in prof], 32, "Z", (0, 0))
    head = mb.obj("R6_Head", skin, coll)
    geo.smooth(head, 40)
    face = mats.flat("M_Face", (28, 24, 22), 0.4)
    feats = []
    for s in (-1, 1):
        mb = MB()
        mb.prism(ellipse(0.055, 0.085, 16, s * 0.2, 0.08), "Y", 0.585, 0.6)
        feats.append(mb.obj("eye", face, coll))
        mb = MB()
        mb.prism(fillet([(s * 0.1, 0.22), (s * 0.3, 0.24), (s * 0.3, 0.27), (s * 0.1, 0.25)], 0.01, 2), "Y", 0.585, 0.6)
        feats.append(mb.obj("brow", face, coll))
    mb = MB()
    mb.sweep(geo.circle(0.014, 6), [Vector((x, 0.598, -0.2 + 0.25 * x * x)) for x in (-0.14, -0.07, 0.0, 0.07, 0.14)], up=(0, 1, 0))
    feats.append(mb.obj("mouth", face, coll))
    for f in feats:
        for v in f.data.vertices:  # sit just proud of the curved head
            v.co.y = math.sqrt(max(0.0, 0.6 ** 2 - v.co.x ** 2)) + 0.002 + (v.co.y - 0.585)
    parts["Head"] = [head] + feats
    for piece, objs in parts.items():
        for o in objs:
            o.location = CENTRES[piece]
    return parts


# ------------------------------------------------------------------ ship

def ship(bp):
    import time
    t0 = time.time()
    scene = bp.reset()
    out = os.path.join(bp.ROOT, "assets", "premium", "characters", NAME)
    pieces = build()
    print(f"[{NAME}] modelled in {time.time() - t0:.1f}s")
    export_coll = bpy.data.collections.new(f"{NAME}_Export")
    scene.collection.children.link(export_coll)
    for objs in pieces.values():
        bp.move_to(list(objs.values()), export_coll)

    size = 512 if bp.QUICK else 1024
    textures = {}
    for atlas, members in ATLASES.items():
        objs = [o for p in members for n, o in pieces[p].items() if "_lens" not in n]
        # bake in character space so shared atlases (arms, legs) see their own limb
        for p in members:
            for o in pieces[p].values():
                o.location = CENTRES[p]
        bake.uv_atlas(objs)
        overlap, usage = bake.uv_overlap(objs)
        files = bake.bake_atlas(objs, f"{NAME}_{atlas}", os.path.join(out, "textures"), size=size, samples=8 if bp.QUICK else 16)
        mat = bake.atlas_material(f"{NAME}_{atlas}_Atlas", files)
        bake.assign(objs, mat)
        textures[atlas] = {"files": {k: bp.rel(v) for k, v in files.items()}, "usage": round(usage, 3), "overlap": round(overlap, 4)}
        print(f"[{NAME}] atlas {atlas}: {usage * 100:.0f}% used, baked in {time.time() - t0:.0f}s")

    bake.uv_simple([o for objs in pieces.values() for n, o in objs.items() if "_lens" in n])
    manifest = {"name": "Ashford Coalition", "team": TEAM, "pieces": {}, "textures": textures, "variants": VARIANTS,
                "units": "1 unit = 1 stud", "axes": "Y up, -Z forward (Roblox); pivot = R6 limb centre (object 'Origin')"}
    for piece, objs in pieces.items():
        for o in objs.values():
            o.location = (0, 0, 0)
        marker = bp.origin_marker(export_coll)
        base = os.path.join(out, f"{NAME}_{piece}")
        bake.export(list(objs.values()) + [marker], base)
        bpy.data.objects.remove(marker)
        lo, hi = geo.bounds(list(objs.values()))
        manifest["pieces"][piece] = {
            "fbx": bp.rel(base + ".fbx"), "glb": bp.rel(base + ".glb"),
            "size_studs_xyz": [round(hi.x - lo.x, 3), round(hi.z - lo.z, 3), round(hi.y - lo.y, 3)],
            "roblox_path": f"ReplicatedStorage.ImportedAssets.Gear.{TEAM}.{piece}",
            "objects": {n: geo.tri_count(o) for n, o in objs.items()},
            "triangles": sum(geo.tri_count(o) for o in objs.values()),
            "triangles_base": sum(geo.tri_count(o) for n, o in objs.items() if "_v_" not in n),
        }
        for o in objs.values():
            o.location = CENTRES[piece]
    manifest["triangles_all_variants"] = sum(p["triangles"] for p in manifest["pieces"].values())
    manifest["triangles_base"] = sum(p["triangles_base"] for p in manifest["pieces"].values())
    os.makedirs(out, exist_ok=True)
    with open(os.path.join(out, f"{NAME}.json"), "w") as f:
        json.dump(manifest, f, indent=2)
    print(f"[{NAME}] {manifest['triangles_base']} tris base, {manifest['triangles_all_variants']} with all variants")

    if bp.RENDER:
        render_soldier(bp, scene, pieces, out)
    bp.save_blend(os.path.join(out, f"{NAME}.blend"))
    print(f"[{NAME}] done in {time.time() - t0:.0f}s")
    return manifest


def render_soldier(bp, scene, pieces, out):
    rdir = os.path.join(out, "renders")
    body_coll = bpy.data.collections.new("R6_Preview_Body")
    scene.collection.children.link(body_coll)
    body = r6_body(body_coll)
    everything = [o for objs in pieces.values() for o in objs.values()] + [o for objs in body.values() for o in objs]
    lo, hi = geo.bounds(everything)
    res = (900, 1100) if bp.QUICK else (1400, 1700)
    render.setup(scene, res, 24 if bp.QUICK else 64)
    render.studio(scene, lo, hi)
    views = {k: render.VIEWS[k] for k in ("front", "side", "rear", "threequarter", "threequarter_left")}
    cams = {}
    for name, d in views.items():
        cam = render.camera(scene, f"Cam_{name}", 70)
        render.frame(scene, cam, lo, hi, d, margin=0.04)
        cams[name] = cam
    bp.shoot(scene, cams, rdir, NAME)
    # close-ups: head/helmet and chest rig
    for name, (c, half, d) in {"head": (Vector((0, 0.1, 1.55)), Vector((0.85, 0.8, 0.75)), (0.8, 0.9, 0.25)),
                               "chest": (Vector((0, 0.2, 0.1)), Vector((1.2, 0.8, 1.0)), (0.5, 1.0, 0.2)),
                               "back": (Vector((0, -0.6, 0.2)), Vector((1.1, 0.9, 1.0)), (-0.6, -1.0, 0.35)),
                               "boots": (Vector((0, 0.1, -2.6)), Vector((1.2, 0.7, 0.55)), (0.6, 1.0, 0.25))}.items():
        cam = render.camera(scene, f"Cam_{name}", 60)
        render.frame(scene, cam, c - half, c + half, d, margin=0.0)
        scene.camera = cam
        render.render(scene, os.path.join(rdir, f"{NAME}_{name}.png"))
    # clay + wire
    ms = [o for objs in pieces.values() for o in objs.values()]
    undo = render.clay(ms)
    wires, wcoll = render.wire_overlay(ms, thickness=0.004)
    scene.camera = cams["threequarter"]
    render.render(scene, os.path.join(rdir, f"{NAME}_wireframe_threequarter.png"))
    for w in wires:
        bpy.data.objects.remove(w)
    bpy.data.collections.remove(wcoll)
    render.unclay(undo)
    # hero: aiming the IR-7 (arms posed about their R6 joints)
    render_hero(bp, scene, pieces, body, rdir)


def aim(piece, target):
    """Rotation about the R6 shoulder so the hand points at `target` (what the
    game's arm solver does; rigid 2-stud arms may fall short)."""
    j = Vector((1.0, 0, 0.5)) if piece == "Arm" else Vector((-1.0, 0, 0.5))
    h = Vector((0.5, 0, -1.5)) if piece == "Arm" else Vector((-0.5, 0, -1.5))
    q = h.normalized().rotation_difference((Vector(target) - j).normalized())
    world = Matrix.Translation(j) @ q.to_matrix().to_4x4() @ Matrix.Translation(-j) @ Matrix.Translation(CENTRES[piece])
    hand = j + q @ h
    return world, hand


def render_hero(bp, scene, pieces, body, rdir):
    from assets import ir7
    right, grip = aim("Arm", (0.62, 1.05, -0.35))
    tilt = Matrix.Rotation(math.radians(-24), 4, "X") @ Matrix.Rotation(math.radians(22), 4, "Z")
    support = grip + tilt @ Vector((0, 1.06, 0.25))
    left, _ = aim("Arm_L", support)
    restore = []
    for piece, mw in (("Arm", right), ("Arm_L", left)):
        for o in list(pieces[piece].values()) + body[piece]:
            restore.append((o, o.matrix_world.copy()))
            local = Matrix.Translation(-Vector(CENTRES[piece])) @ o.matrix_world
            o.matrix_world = mw @ local
    gun, _ = ir7.build()
    for o in gun.values():
        o.matrix_world = Matrix.Translation(grip) @ tilt @ o.matrix_world
    everything = [o for objs in pieces.values() for o in objs.values()] + [o for objs in body.values() for o in objs] + list(gun.values())
    lo, hi = geo.bounds(everything)
    cam = render.camera(scene, "Cam_hero", 55)
    render.frame(scene, cam, lo, hi, (0.75, 1.1, 0.22), margin=0.02)
    scene.camera = cam
    render.render(scene, os.path.join(rdir, f"{NAME}_hero_ir7.png"))
    for o in gun.values():
        bpy.data.objects.remove(o)
    for o, m in restore:
        o.matrix_world = m
