"""IR-7 Carbine — original fictional 5.56-class carbine for OPERATION IRONFRONT.

Design language ("Ironfront Arms"): black anodised monolithic receivers,
coyote-tan cerakote handguard with the IR signature slanted vent row, tan
polymer furniture, olive polymer magazine, gunmetal barrel and 3-port brake,
plus a hooded "HX-2" reflex sight.

Frame (Blender): +Y muzzle, +Z up, +X right; origin = right-hand grip point.
Units are studs. Overall length ≈ 2.98 studs (R6 scale, matches the old CB).
"""
import math

import bpy
from mathutils import Matrix, Vector

from iflib import geo, mats
from iflib.geo import MB, fillet, rrect, finish, cut, boolean, rot, tr, catmull_path

NAME = "IR7"
BORE = 0.42          # bore axis height
REC_TOP = 0.52       # upper receiver top (rail base)
RAIL_TOP = 0.575
SIGHT_Z = 0.705      # optic window centre = sight line

# ------------------------------------------------------------------ looks
LOOKS = {
    "anodized": {"color": (38, 39, 42), "color2": (33, 34, 36), "var": 0.3, "mottle": 0.04, "rough": 0.42, "rough_var": 0.035, "metal": 0.55,
                 "wear": 0.55, "wear_color": (150, 152, 156), "wear_rough": 0.26, "wear_metal": 1.0, "wear_radius": 0.005,
                 "bump": {"kind": "peel", "strength": 0.06}},
    "tungsten": {"color": (68, 70, 74), "color2": (62, 64, 68), "var": 0.3, "mottle": 0.04, "rough": 0.42, "rough_var": 0.035, "metal": 0.5,
                 "wear": 0.5, "wear_color": (168, 170, 174), "wear_rough": 0.24, "wear_metal": 1.0, "wear_radius": 0.005,
                 "bump": {"kind": "peel", "strength": 0.07}},
    "gunmetal": {"color": (70, 72, 76), "color2": (60, 62, 66), "var": 0.3, "mottle": 0.05, "rough": 0.34, "rough_var": 0.05, "metal": 0.92,
                 "wear": 0.5, "wear_color": (172, 173, 176), "wear_rough": 0.2, "wear_metal": 1.0, "wear_radius": 0.004,
                 "bump": {"kind": "peel", "strength": 0.04}},
    "cerakote": {"color": (152, 128, 93), "color2": (146, 125, 92), "var": 0.4, "mottle": 0.05, "rough": 0.5, "rough_var": 0.04,
                 "wear": 0.5, "wear_color": (136, 138, 142), "wear_rough": 0.3, "wear_metal": 0.9, "wear_radius": 0.005,
                 "bump": {"kind": "peel", "strength": 0.08}},
    "polymer": {"color": (144, 121, 89), "color2": (134, 112, 82), "var": 0.4, "mottle": 0.05, "rough": 0.6, "rough_var": 0.04,
                "wear": 0.35, "wear_color": (184, 166, 134), "wear_rough": 0.45, "wear_radius": 0.006,
                "bump": {"kind": "grain", "strength": 0.12}},
    "stipple": {"color": (142, 119, 87), "color2": (128, 107, 78), "var": 0.5, "rough": 0.72,
                "wear": 0.3, "wear_color": (182, 164, 132), "wear_rough": 0.5, "wear_radius": 0.006,
                "bump": {"kind": "stipple", "strength": 0.45, "distance": 0.003}},
    "olive": {"color": (86, 92, 62), "color2": (78, 84, 56), "var": 0.4, "mottle": 0.05, "rough": 0.6, "rough_var": 0.04,
              "wear": 0.35, "wear_color": (128, 132, 102), "wear_rough": 0.45, "wear_radius": 0.006,
              "bump": {"kind": "grain", "strength": 0.12}},
    "black_poly": {"color": (32, 32, 34), "rough": 0.62, "rough_var": 0.06, "wear": 0.3, "wear_color": (78, 78, 80),
                   "wear_rough": 0.5, "wear_radius": 0.005, "bump": {"kind": "grain", "strength": 0.1}},
    "rubber": {"color": (27, 27, 28), "rough": 0.86, "mottle": 0.06, "bump": {"kind": "rubber", "strength": 0.12}},
    "knurl": {"color": (62, 64, 68), "rough": 0.38, "metal": 0.9, "wear": 0.5, "wear_color": (170, 170, 174),
              "wear_metal": 1.0, "wear_radius": 0.004, "bump": {"kind": "knurl", "strength": 0.4}},
    "glass": {"glass": True, "color": (120, 150, 140), "rough": 0.02},
}


def M(key):
    return mats.build(f"{NAME}_{key}", LOOKS[key])


# ------------------------------------------------------------------ helpers

def catmull(points, per=6):
    return catmull_path(points, per)


def rail_section(z0, top=RAIL_TOP, half=0.062):
    """Picatinny-style dovetail cross-section (X, Z) sitting on z0."""
    h = top - z0
    pts = [(-half + 0.008, z0), (half - 0.008, z0), (half - 0.008, z0 + 0.22 * h), (half + 0.01, z0 + 0.52 * h),
           (half, top), (-half, top), (-half - 0.01, z0 + 0.52 * h), (-half + 0.008, z0 + 0.22 * h)]
    return fillet(pts, [0, 0, 0.002, 0.003, 0.004, 0.004, 0.003, 0.002], 2)


def rail_slots(mb, y0, y1, top=RAIL_TOP, pitch=0.052, width=0.024, depth=0.016):
    n = int((y1 - y0) / pitch)
    start = (y0 + y1) / 2 - (n - 1) * pitch / 2
    for i in range(n):
        y = start + i * pitch
        mb.box((0, y, top), (0.3, width, depth * 2))


def text_mesh(body, size, depth, m):
    """Extruded text converted to a closed mesh (for engraving booleans)."""
    cu = bpy.data.curves.new("txt", "FONT")
    cu.body = body
    cu.size = size
    cu.extrude = depth
    cu.align_x = "CENTER"
    cu.align_y = "CENTER"
    cu.resolution_u = 2
    o = bpy.data.objects.new("txt", cu)
    bpy.context.scene.collection.objects.link(o)
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(o.evaluated_get(dg))
    bpy.data.objects.remove(o)
    bpy.data.curves.remove(cu)
    me.transform(m)
    t = bpy.data.objects.new("_txt", me)
    bpy.context.scene.collection.objects.link(t)
    return t


# Mapping for text lying on a side face: text +X → world -Y (left side, read
# from the left) or +Y (right side), text +Y → world +Z, text +Z → out of face.
LEFT_FACE = Matrix(((0, 0, -1, 0), (-1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
RIGHT_FACE = Matrix(((0, 0, 1, 0), (1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 0, 1)))


# ------------------------------------------------------------------ parts

def upper_receiver():
    # Cross-section with chamfered shoulders, extruded front to back.
    sec = fillet([(-0.086, 0.33), (0.086, 0.33), (0.092, 0.34), (0.092, 0.468), (0.066, 0.52), (-0.066, 0.52),
                  (-0.092, 0.468), (-0.092, 0.34)], [0.004, 0.004, 0.006, 0.01, 0.006, 0.006, 0.01, 0.006], 3)
    mb = MB()
    mb.prism(sec, "Y", -0.285, 0.645)
    # integrated top rail
    mb2 = MB()
    mb2.prism(rail_section(REC_TOP - 0.004), "Y", -0.225, 0.635)
    up = mb.obj("upper", M("anodized"))
    rail = mb2.obj("rail")
    boolean(up, rail, "UNION")
    cut(up, lambda m: rail_slots(m, -0.225, 0.635))
    # rear: charging-handle channel under the rail
    cut(up, lambda m: m.box((0, -0.27, 0.53), (0.075, 0.07, 0.07)))

    def port(m):  # ejection port (right) + charging-handle slot (left)
        m.prism(rrect(0.23, 0.078, 0.012, 3, 0.225, 0.425), "X", 0.05, 0.2)
        m.prism(rrect(0.30, 0.02, 0.008, 2, 0.45, 0.445), "X", -0.2, -0.078)
        # side relief panels (lightening flats on both sides of the upper)
        m.prism(rrect(0.19, 0.05, 0.02, 3, -0.12, 0.43), "X", 0.087, 0.2)
        m.prism(rrect(0.19, 0.05, 0.02, 3, -0.12, 0.43), "X", -0.2, -0.087)
        # long styling groove on both sides, below the port
        m.prism(rrect(0.8, 0.012, 0.006, 2, 0.2, 0.353), "X", 0.087, 0.2)
        m.prism(rrect(0.8, 0.012, 0.006, 2, 0.2, 0.353), "X", -0.2, -0.087)
    cut(up, port)
    finish(up, 0.0055, 1, 30)
    parts = [up]

    # brass deflector (right, behind the port)
    mb = MB()
    mb.prism(fillet([(0.02, 0.38), (0.095, 0.38), (0.095, 0.41), (0.05, 0.505), (0.02, 0.505)], [0.01, 0.01, 0.02, 0.02, 0.01], 3),
             "X", 0.07, 0.118)
    d = mb.obj("deflector", M("anodized"))
    finish(d, 0.008, 3, 30)
    parts.append(d)

    # dust cover, hinged at the port's lower edge, swung open
    mb = MB()
    mb.prism(rrect(0.23, 0.075, 0.01, 2, 0.225, -0.0375), "X", -0.004, 0.004)
    dc = mb.obj("dust_cover", M("anodized"))
    dc.data.transform(tr(0.098, 0, 0.383) @ rot("Y", 0) @ Matrix.Rotation(math.radians(-62), 4, "Y"))
    finish(dc, 0.002, 2, 30)
    parts.append(dc)
    mb = MB()
    mb.cyl((0.096, 0.225, 0.383), 0.007, 0.25, "Y", 10)
    hinge = mb.obj("hinge", M("gunmetal"))
    finish(hinge, 0.0, 1)

    # bolt carrier face visible through the port
    mb = MB()
    mb.box((0.058, 0.225, 0.425), (0.016, 0.21, 0.062))
    bolt = mb.obj("bolt", M("gunmetal"))
    cut(bolt, lambda m: m.box((0.07, 0.30, 0.425), (0.02, 0.05, 0.02)))
    finish(bolt, 0.003, 2)

    # charging handle: T-latch at the rear
    mb = MB()
    prof = fillet([(-0.3, -0.035), (-0.265, -0.035), (-0.265, -0.1), (-0.3, -0.1), (-0.325, -0.1), (-0.33, -0.08),
                   (-0.33, 0.08), (-0.325, 0.1), (-0.3, 0.1), (-0.265, 0.1), (-0.265, 0.035), (-0.2, 0.035), (-0.2, -0.035)],
                  [0, 0.004, 0.006, 0.0, 0.008, 0.01, 0.01, 0.008, 0.0, 0.006, 0.004, 0.004, 0.004], 2)
    prof = [(p.y, p.x) for p in prof]  # (X, Y) top view
    mb.prism(prof, "Z", 0.495, 0.528)
    ch = mb.obj("charging_handle", M("anodized"))
    finish(ch, 0.004, 2)

    # left-side reciprocating charging knob (forward, in its slot)
    mb = MB()
    mb.lathe([(0.0, -0.16), (0.016, -0.158), (0.021, -0.15), (0.021, -0.118), (0.014, -0.106), (0.011, -0.08)], 16, "X", (0.585, 0.445))
    knob = mb.obj("ch_knob", M("gunmetal"))
    finish(knob, 0.0, 1)
    return parts, [hinge, bolt, knob], [ch]


def lower_receiver():
    body = fillet([(-0.262, 0.335), (0.645, 0.335), (0.645, 0.14), (-0.16, 0.14), (-0.232, 0.172), (-0.262, 0.23)],
                  [0.004, 0.004, 0.0, 0.03, 0.03, 0.03], 3)
    mb = MB()
    mb.prism(body, "X", -0.084, 0.084)
    low = mb.obj("lower", M("tungsten"))
    # flared, forward-raked magazine well: loft of rounded rectangles (top view)
    mb = MB()
    secs = []
    for z, w, y0, y1 in ((0.30, 0.168, 0.295, 0.645), (0.13, 0.168, 0.295, 0.652), (0.08, 0.175, 0.294, 0.66),
                         (0.048, 0.19, 0.289, 0.673), (0.026, 0.196, 0.291, 0.676)):
        ring = rrect(w, y1 - y0, 0.022, 3, 0.0, (y0 + y1) / 2)
        secs.append([Vector((p.x, p.y, z)) for p in ring])
    secs.reverse()
    mb.loft(secs)
    well = mb.obj("well")
    boolean(low, well, "UNION")
    # well opening from below
    cut(low, lambda m: m.prism(rrect(0.128, 0.29, 0.018, 3, 0.0, 0.478), "Z", -0.1, 0.13))

    # side panel recess on the well + roll mark
    def recess(m):
        m.prism(rrect(0.24, 0.12, 0.02, 3, 0.47, 0.235), "X", 0.0805, 0.3)
        m.prism(rrect(0.24, 0.12, 0.02, 3, 0.47, 0.235), "X", -0.3, -0.0805)
    cut(low, recess)
    txt = text_mesh("IR-7", 0.056, 0.006, tr(-0.0805, 0.47, 0.232) @ LEFT_FACE)
    boolean(low, txt)

    def logo(m):  # Ironfront Arms mark: stacked chevrons
        for i, zc in enumerate((0.262, 0.236, 0.21)):
            w = 0.05 - i * 0.008
            pts = [(0.47 - w, zc - 0.006), (0.47, zc + 0.012), (0.47 + w, zc - 0.006), (0.47 + w, zc - 0.018), (0.47, zc), (0.47 - w, zc - 0.018)]
            m.prism(pts, "X", 0.0755, 0.2)
    cut(low, logo)

    # trigger guard swept below the trigger
    path = catmull([(0.0, 0.305, 0.075), (0.0, 0.29, 0.034), (0.0, 0.24, 0.022), (0.0, 0.18, 0.025), (0.0, 0.142, 0.045),
                    (0.0, 0.126, 0.078), (0.0, 0.121, 0.11)], 5)
    mb = MB()
    mb.sweep(rrect(0.052, 0.022, 0.009, 2), path, up=(0, 1, 0))
    tg = mb.obj("guard")
    boolean(low, tg, "UNION")
    finish(low, 0.0055, 1, 30)
    parts = [low]

    metal = []
    # pins (both sides)
    for (y, z) in ((0.59, 0.305), (-0.225, 0.3), (0.2, 0.205), (0.095, 0.22)):
        for sx in (-1, 1):
            mb = MB()
            x0 = sx * 0.083
            mb.lathe([(0.0, x0 + sx * 0.0075), (0.011, x0 + sx * 0.007), (0.0135, x0 + sx * 0.004), (0.0135, x0)] if sx > 0 else
                     [(0.0135, x0), (0.0135, x0 + sx * 0.004), (0.011, x0 + sx * 0.007), (0.0, x0 + sx * 0.0075)], 14, "X", (y, z))
            p = mb.obj("pin", M("gunmetal"))
            finish(p, 0.0, 1)
            metal.append(p)
    # selector levers (ambidextrous)
    dark = []
    for sx in (-1, 1):
        pts = geo.circle(0.024, 14, -0.015, 0.262)
        tip = [Vector((0.07, 0.272)), Vector((0.075, 0.262)), Vector((0.07, 0.252))]
        hull = _hull(pts + tip)
        mb = MB()
        x0, x1 = (0.084, 0.098) if sx > 0 else (-0.098, -0.084)
        mb.prism(hull, "X", x0, x1)
        s = mb.obj("selector", M("black_poly"))
        finish(s, 0.004, 2)
        dark.append(s)
        # selector markings: small raised dots on the receiver
        for (yy, zz) in ((-0.015, 0.31), (0.035, 0.30)):
            mb = MB()
            mb.cyl((sx * 0.086, yy, zz), 0.006, 0.006, "X", 10)
            dot = mb.obj("dot", M("cerakote"))
            finish(dot, 0.0, 1)
            parts.append(dot)
    # magazine release (right) with a fence
    mb = MB()
    mb.lathe([(0.018, 0.08), (0.018, 0.095), (0.015, 0.1), (0.0, 0.101)], 18, "X", (0.305, 0.228))
    mr = mb.obj("mag_release", M("gunmetal"))
    finish(mr, 0.0, 1)
    metal.append(mr)
    mb = MB()
    fence = [(0.27, 0.19), (0.34, 0.19), (0.345, 0.2), (0.335, 0.2), (0.305, 0.198), (0.275, 0.2), (0.265, 0.2)]
    mb.prism(fillet(fence, 0.004, 2), "X", 0.08, 0.098)
    fz = mb.obj("fence", M("anodized"))
    finish(fz, 0.003, 2)
    parts.append(fz)
    # bolt catch paddle (left)
    mb = MB()
    mb.prism(fillet([(0.285, 0.25), (0.33, 0.255), (0.335, 0.32), (0.3, 0.325)], 0.01, 3), "X", -0.097, -0.083)
    bc = mb.obj("bolt_catch", M("anodized"))
    finish(bc, 0.003, 2)
    parts.append(bc)
    # trigger (curved blade)
    path = catmull([(0, 0.185, 0.155), (0, 0.19, 0.125), (0, 0.186, 0.095), (0, 0.174, 0.072), (0, 0.158, 0.062)], 3)
    mb = MB()
    mb.sweep(rrect(0.026, 0.016, 0.006, 2), path, up=(0, 1, 0), scale=lambda i, t: (1.0, 1.0 - 0.3 * t))
    trig = mb.obj("trigger", M("gunmetal"))
    finish(trig, 0.0, 1)
    metal.append(trig)
    return parts, metal, dark


def _hull(pts):
    pts = sorted(set((round(p[0], 6), round(p[1], 6)) for p in pts))
    if len(pts) <= 2:
        return pts

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lower, upper = [], []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return [Vector(p) for p in lower[:-1] + upper[:-1]]


def pistol_grip():
    a = math.radians(18)
    ad = Vector((-math.sin(a), -math.cos(a)))   # down the grip axis (Y, Z)
    pf = Vector((math.cos(a), -math.sin(a)))    # forward, perpendicular
    top = Vector((0.0, 0.0)) - ad * (0.14 / math.cos(a))

    def G(t, s):
        return top + ad * s + pf * t
    # visible outline as a smooth spline: front strap with finger grooves,
    # flared base, palm swell, beavertail; then straight edges hidden in the receiver
    ctrl = [G(0.094, 0.0), G(0.086, 0.07), G(0.093, 0.14), G(0.082, 0.195), G(0.091, 0.25), G(0.082, 0.305), G(0.089, 0.37),
            G(0.097, 0.43), G(0.091, 0.463), G(0.06, 0.474), G(-0.08, 0.478), G(-0.11, 0.465), G(-0.116, 0.41), G(-0.119, 0.3),
            G(-0.114, 0.2), G(-0.1, 0.115), Vector((-0.095, 0.096)), Vector((-0.132, 0.106)), Vector((-0.162, 0.122)),
            Vector((-0.168, 0.137)), Vector((-0.148, 0.15))]
    curve = catmull([(p.x, p.y, 0.0) for p in ctrl], 5)
    prof = [Vector((p.x, p.y)) for p in curve] + [Vector((-0.07, 0.165)), Vector((0.14, 0.165))]
    mb = MB()
    mb.prism(prof, "X", -0.07, 0.07)
    g = mb.obj("grip", M("stipple"))
    finish(g, 0.032, 4, 28)
    return g


def handguard():
    sec = [(-0.048, 0.286), (0.048, 0.286), (0.104, 0.335), (0.104, 0.462), (0.074, 0.52), (-0.074, 0.52), (-0.104, 0.462), (-0.104, 0.335)]
    sec = fillet(sec, 0.012, 3)
    c = Vector((0.0, 0.40))

    def ring(y, s):
        return [Vector((c.x + (p.x - c.x) * s, y, c.y + (p.y - c.y) * s)) for p in sec]
    mb = MB()
    mb.loft([ring(0.645, 1.0), ring(1.455, 1.0), ring(1.49, 0.93), ring(1.5, 0.88)])
    hg = mb.obj("handguard", M("cerakote"))
    mb = MB()
    mb.prism(rail_section(REC_TOP - 0.004), "Y", 0.66, 1.46)
    rail = mb.obj("hg_rail")
    boolean(hg, rail, "UNION")
    cut(hg, lambda m: rail_slots(m, 0.66, 1.46))
    # hollow bore
    inner = fillet([(-0.03, 0.305), (0.03, 0.305), (0.084, 0.345), (0.084, 0.452), (0.058, 0.502), (-0.058, 0.502),
                    (-0.084, 0.452), (-0.084, 0.345)], 0.01, 2)
    cut(hg, lambda m: m.prism(inner, "Y", 0.6, 1.6))

    def slots(m):
        for y in (0.79, 0.955, 1.12, 1.285):
            m.prism(rrect(0.125, 0.036, 0.018, 3, y, 0.395), "X", -0.2, 0.2)       # side M-slots (both sides)
        for y in (0.87, 1.035, 1.2):
            m.prism([(p.y, p.x) for p in rrect(0.125, 0.034, 0.017, 3, y, 0.0)], "Z", 0.2, 0.33)  # bottom
        # IR signature: slanted vents through both upper chamfers
        y = 0.72
        while y < 1.40:
            m.prism([(y, 0.47), (y + 0.028, 0.47), (y + 0.048, 0.508), (y + 0.02, 0.508)], "X", -0.2, 0.2)
            y += 0.072
    cut(hg, slots)
    finish(hg, 0.005, 1, 30)
    # hex screws clamping the handguard to the barrel nut
    screws = []
    for sx in (-1, 1):
        for z in (0.365, 0.43):
            screws.append(hex_screw(sx, 0.104, 0.695, z))

    # hand stop (angled), black polymer
    mb = MB()
    mb.prism(fillet([(1.30, 0.296), (1.45, 0.296), (1.46, 0.28), (1.425, 0.21), (1.395, 0.205), (1.375, 0.24)],
                    [0, 0, 0.01, 0.012, 0.012, 0.03], 3), "X", -0.034, 0.034)
    hs = mb.obj("handstop", M("black_poly"))
    finish(hs, 0.008, 2)
    return hg, hs, screws


def barrel_and_brake():
    mb = MB()
    mb.lathe([(0.048, 0.60), (0.048, 0.68), (0.038, 0.70), (0.036, 1.5), (0.035, 1.66)], 20, "Y", (0.0, BORE))
    bar = mb.obj("barrel", M("gunmetal"))
    finish(bar, 0.003, 2)
    mb = MB()
    prof = [(0.035, 1.628), (0.05, 1.628), (0.054, 1.634), (0.054, 1.668), (0.049, 1.672), (0.049, 1.684),
            (0.058, 1.688), (0.058, 1.905), (0.054, 1.92), (0.047, 1.945), (0.03, 1.95), (0.021, 1.948), (0.021, 1.87)]
    mb.lathe(prof, 20, "Y", (0.0, BORE))
    brake = mb.obj("brake", M("gunmetal"))

    def ports(m):
        for y in (1.73, 1.79, 1.85):
            m.prism(rrect(0.032, 0.066, 0.016, 4, y, BORE), "X", -0.2, 0.2)
        for y in (1.755, 1.815):
            m.cyl((0.0, y, BORE + 0.05), 0.011, 0.06, "Z", 12)
    cut(brake, ports)
    finish(brake, 0.003, 1, 30)
    # knurled lock collar
    mb = MB()
    mb.lathe([(0.0535, 1.636), (0.0545, 1.638), (0.0545, 1.664), (0.0535, 1.666)], 20, "Y", (0.0, BORE))
    collar = mb.obj("collar", M("knurl"))
    finish(collar, 0.0, 1)
    return [bar, brake, collar]


def buis(y0, y1, name):
    """Folded flip-up iron sight on the rail."""
    mb = MB()
    L = y1 - y0
    prof = fillet([(y0, RAIL_TOP - 0.01), (y1, RAIL_TOP - 0.01), (y1, RAIL_TOP + 0.018), (y1 - 0.2 * L, RAIL_TOP + 0.036),
                   (y0 + 0.15 * L, RAIL_TOP + 0.036), (y0, RAIL_TOP + 0.02)], [0.003, 0.003, 0.008, 0.01, 0.01, 0.006], 3)
    mb.prism(prof, "X", -0.056, 0.056)
    b = mb.obj(name, M("anodized"))
    # clamp jaws hugging the rail
    mb = MB()
    for sx in (-1, 1):
        mb.prism(fillet([(y0 + 0.01, RAIL_TOP - 0.035), (y1 - 0.01, RAIL_TOP - 0.035), (y1 - 0.01, RAIL_TOP), (y0 + 0.01, RAIL_TOP)], 0.004, 2),
                 "X", sx * 0.066 - 0.007, sx * 0.066 + 0.007)
    jaws = mb.obj("jaws")
    boolean(b, jaws, "UNION")
    # folded leaf sitting in a recess
    cut(b, lambda m: m.box((0, (y0 + y1) / 2, RAIL_TOP + 0.036), (0.06, L * 0.62, 0.012)))
    finish(b, 0.004, 1)
    mb = MB()
    mb.prism(fillet([(y0 + 0.2 * L, RAIL_TOP + 0.026), (y1 - 0.18 * L, RAIL_TOP + 0.026), (y1 - 0.18 * L, RAIL_TOP + 0.036),
                     (y0 + 0.2 * L, RAIL_TOP + 0.036)], 0.003, 2), "X", -0.026, 0.026)
    leaf = mb.obj(name + "_leaf", M("black_poly"))
    finish(leaf, 0.002, 2)
    mb = MB()
    mb.cyl((0.062, (y0 + y1) / 2, RAIL_TOP + 0.012), 0.012, 0.02, "X", 14)
    knob = mb.obj(name + "_knob", M("knurl"))
    finish(knob, 0.002, 1)
    return b, leaf, knob


def optic():
    """HX-2 micro red dot: sealed tube on a riser ring mount, capped turrets."""
    parts = []
    TZ = SIGHT_Z
    # riser mount: rail clamp + tapered riser into a ring
    mb = MB()
    base = fillet([(0.075, RAIL_TOP - 0.004), (0.285, RAIL_TOP - 0.004), (0.285, 0.598), (0.255, 0.62), (0.105, 0.62), (0.075, 0.598)],
                  [0.003, 0.003, 0.008, 0.012, 0.012, 0.008], 3)
    mb.prism(base, "X", -0.07, 0.07)
    mount = mb.obj("optic_mount", M("anodized"))
    mb = MB()
    for sx in (-1, 1):
        mb.prism(fillet([(0.09, RAIL_TOP - 0.04), (0.27, RAIL_TOP - 0.04), (0.27, 0.6), (0.09, 0.6)], 0.006, 2), "X",
                 sx * 0.069 - 0.009, sx * 0.069 + 0.009)
    # riser web (front view trapezoid) up to the ring
    web = [(-0.05, 0.6), (0.05, 0.6), (0.036, TZ - 0.04), (-0.036, TZ - 0.04)]
    mb.prism(fillet(web, 0.006, 2), "Y", 0.14, 0.23)
    mb.lathe([(0.066, 0.135), (0.07, 0.14), (0.07, 0.225), (0.066, 0.23)], 24, "Y", (0.0, TZ))
    extra = mb.obj("mount_extra")
    boolean(mount, extra, "UNION", self_intersect=True)
    cut(mount, lambda m: (m.cyl((0, 0.1825, TZ), 0.057, 0.2, "Y", 24),                 # ring bore
                           m.box((0.075, 0.1825, TZ), (0.04, 0.2, 0.012))))             # clamp split (right)
    finish(mount, 0.004, 1)
    parts.append(mount)
    # clamp bolts on the ring split
    for y in (0.155, 0.21):
        mb = MB()
        mb.lathe([(0.0, TZ + 0.035), (0.009, TZ + 0.034), (0.011, TZ + 0.03), (0.011, TZ + 0.012)], 12, "Z", (0.07, y))
        bolt = mb.obj("ring_bolt", M("gunmetal"))
        finish(bolt, 0.0, 1)
        parts.append(bolt)
    # tube: rear hood, body, front hood; lathe runs into the openings
    prof = [(0.044, 0.105), (0.044, 0.084), (0.05, 0.074), (0.061, 0.07), (0.064, 0.074), (0.064, 0.098), (0.057, 0.106),
            (0.057, 0.282), (0.063, 0.288), (0.066, 0.296), (0.066, 0.324), (0.061, 0.33), (0.051, 0.33), (0.051, 0.3)]
    mb = MB()
    mb.lathe(prof, 28, "Y", (0.0, TZ))
    tube = mb.obj("optic_tube", M("anodized"))
    # turret boss (square block on top-right of the tube) + turrets
    mb = MB()
    boss = fillet([(-0.042, TZ - 0.02), (0.05, TZ - 0.02), (0.05, TZ + 0.064), (-0.042, TZ + 0.064)], [0.004, 0.004, 0.018, 0.018], 3)
    mb.prism(boss, "Y", 0.15, 0.225)
    b2 = mb.obj("boss")
    boolean(tube, b2, "UNION")
    finish(tube, 0.004, 1)
    parts.append(tube)
    for kind in ("top", "side"):
        mb = MB()
        if kind == "top":
            mb.lathe([(0.03, TZ + 0.06), (0.03, TZ + 0.1), (0.026, TZ + 0.106), (0.0, TZ + 0.107)], 20, "Z", (0.0, 0.1875))
        else:
            mb.lathe([(0.03, 0.046), (0.03, 0.084), (0.026, 0.09), (0.0, 0.091)], 20, "X", (0.1875, TZ + 0.02))
        t = mb.obj("turret", M("knurl"))
        finish(t, 0.003, 1)
        parts.append(t)
    # brightness dial on the left of the boss
    mb = MB()
    mb.lathe([(0.022, -0.04), (0.022, -0.058), (0.018, -0.063), (0.0, -0.064)], 18, "X", (0.1875, TZ + 0.022))
    dial = mb.obj("dial", M("rubber"))
    finish(dial, 0.0, 1)
    parts.append(dial)
    # thumb screw for the rail clamp (left)
    mb = MB()
    mb.lathe([(0.017, -0.078), (0.019, -0.082), (0.019, -0.108), (0.014, -0.113), (0.0, -0.114)], 18, "X", (0.18, 0.552))
    ts = mb.obj("thumbscrew", M("knurl"))
    finish(ts, 0.0, 1)
    parts.append(ts)
    # lenses (separate object, transparent in-game)
    mb = MB()
    mb.cyl((0.0, 0.3, TZ), 0.0515, 0.004, "Y", 24)
    mb.cyl((0.0, 0.09, TZ), 0.0445, 0.004, "Y", 24)
    gl = mb.obj("glass", M("glass"))
    return parts, gl


def magazine():
    ss = sorted(set([i / 30 for i in range(31)] + [0.44, 0.45, 0.49, 0.5, 0.57, 0.58, 0.62, 0.63, 0.7, 0.71, 0.75, 0.76, 0.905, 0.915]))

    def spine(s):
        return Vector((0.0, 0.47 + 0.105 * s ** 1.7, 0.118 - 0.505 * s))
    path = [spine(s) for s in ss]

    def rib(s):
        for a, b in ((0.45, 0.49), (0.58, 0.62), (0.71, 0.75)):
            if a <= s <= b:
                return 1.0
        return 0.0

    def scale(i, t):
        s = ss[i]
        if s >= 0.915:
            return (1.12, 1.07)
        return (1.0 + 0.1 * rib(s), 1.0)
    sec = fillet([(-0.058, -0.112), (0.058, -0.112), (0.058, 0.118), (-0.058, 0.118)], [0.014, 0.014, 0.034, 0.034], 4)
    mb = MB()
    mb.sweep(sec, path, up=(0, 1, 0), scale=scale)
    mg = mb.obj("magazine", M("olive"))
    # front/rear spine grooves and a base-plate pull slot
    finish(mg, 0.006, 2, 28)
    return mg


def stock():
    parts = []
    # buffer tube, castle nut, end plate
    mb = MB()
    mb.lathe([(0.05, -0.30), (0.05, -0.86), (0.046, -0.875), (0.0, -0.878)], 24, "Y", (0.0, BORE - 0.005))
    tube = mb.obj("tube", M("anodized"))
    finish(tube, 0.003, 2)
    mb = MB()
    mb.lathe([(0.048, -0.286), (0.066, -0.29), (0.066, -0.318), (0.048, -0.322)], 24, "Y", (0.0, BORE - 0.005))
    nut = mb.obj("castle_nut", M("gunmetal"))
    axis = Matrix.Translation((0, 0, BORE - 0.005))
    cut(nut, lambda m: [m.box((0, -0.322, 0), (0.026, 0.024, 0.2), m=axis @ rot("Y", a)) for a in (0, 60, 120)])
    finish(nut, 0.002, 2)
    mb = MB()
    mb.prism(fillet([(-0.078, 0.33), (0.078, 0.33), (0.078, 0.47), (-0.078, 0.47)], 0.03, 4), "Y", -0.292, -0.278)
    plate = mb.obj("end_plate", M("anodized"))
    finish(plate, 0.003, 2)
    parts += [tube, plate]

    # stock body — tan polymer, cheek weld, lightening window
    prof = [(-0.50, 0.40), (-0.515, 0.48), (-0.585, 0.522), (-0.92, 0.548), (-0.972, 0.556), (-0.986, 0.545), (-0.986, 0.13),
            (-0.97, 0.118), (-0.925, 0.118), (-0.64, 0.29), (-0.54, 0.325), (-0.505, 0.35)]
    radii = [0.01, 0.03, 0.08, 0.05, 0.02, 0.006, 0.006, 0.02, 0.02, 0.1, 0.04, 0.02]
    mb = MB()
    mb.prism(fillet(prof, radii, 5), "X", -0.066, 0.066)
    st = mb.obj("stock", M("polymer"))
    cut(st, lambda m: m.prism(fillet([(-0.705, 0.318), (-0.9, 0.2), (-0.9, 0.395), (-0.79, 0.41)], [0.03, 0.03, 0.03, 0.05], 5), "X", -0.2, 0.2))
    # sling slot at the heel + side relief panels
    cut(st, lambda m: m.prism(rrect(0.05, 0.022, 0.011, 3, -0.94, 0.165), "X", -0.2, 0.2))
    def relief(m):
        for sx in (-1, 1):
            if sx > 0:
                m.prism(fillet([(-0.62, 0.43), (-0.9, 0.46), (-0.9, 0.5), (-0.62, 0.49)], 0.02, 3), "X", 0.058, 0.2)
            else:
                m.prism(fillet([(-0.62, 0.43), (-0.9, 0.46), (-0.9, 0.5), (-0.62, 0.49)], 0.02, 3), "X", -0.2, -0.058)
    cut(st, relief)
    finish(st, 0.022, 3, 30)
    # adjustment latch under the nose
    mb = MB()
    mb.prism(fillet([(-0.62, 0.305), (-0.53, 0.33), (-0.525, 0.345), (-0.6, 0.33), (-0.625, 0.32)], 0.006, 2), "X", -0.02, 0.02)
    latch = mb.obj("latch", M("black_poly"))
    finish(latch, 0.004, 2)

    # rubber butt pad with ribs
    mb = MB()
    mb.prism(fillet([(-0.984, 0.123), (-1.016, 0.128), (-1.03, 0.16), (-1.03, 0.52), (-1.016, 0.555), (-0.984, 0.56)],
                    [0.004, 0.012, 0.02, 0.02, 0.012, 0.004], 4), "X", -0.07, 0.07)
    pad = mb.obj("buttpad", M("rubber"))
    def ribs(m):
        z = 0.19
        while z < 0.5:
            m.box((0, -1.03, z), (0.3, 0.016, 0.012))
            z += 0.034
    cut(pad, ribs)
    finish(pad, 0.006, 1)
    return parts, st, latch, pad, nut


def hex_screw(sx, x_surface, y, z, r=0.012):
    """Socket-head screw sitting on a side face (sx = +1 right, -1 left)."""
    x0 = sx * (x_surface - 0.002)
    x1 = sx * (x_surface + 0.004)
    mb = MB()
    prof = [(r, x0), (r, x1 - sx * 0.0015), (r * 0.8, x1), (0.0, x1)]
    mb.lathe(prof if sx > 0 else list(reversed(prof)), 14, "X", (y, z))
    sc = mb.obj("screw", M("gunmetal"))
    cut(sc, lambda m: m.lathe([(0.0055, x1 - sx * 0.003), (0.0055, x1 + sx * 0.01)] if sx > 0 else
                              [(0.0055, x1 + sx * 0.01), (0.0055, x1 - sx * 0.003)], 6, "X", (y, z)))
    finish(sc, 0.0, 1)
    return sc


def qd_cup(x0, x1, y, z):
    sx = 1 if x1 > x0 else -1
    mb = MB()
    mb.lathe([(0.018, x0), (0.028, x0), (0.028, x1 - sx * 0.004), (0.024, x1), (0.015, x1), (0.015, x1 - sx * 0.012)] if sx > 0 else
             [(0.015, x1 - sx * 0.012), (0.015, x1), (0.024, x1), (0.028, x1 - sx * 0.004), (0.028, x0), (0.018, x0)], 12, "X", (y, z))
    c = mb.obj("qd", M("gunmetal"))
    finish(c, 0.0, 1)
    return c


# ------------------------------------------------------------------ assembly

def build():
    """Returns ({object_name: obj}, points) — objects grouped by Roblox colour key."""
    up, up_metal, up_dark = upper_receiver()
    low, low_metal, low_dark = lower_receiver()
    grip = pistol_grip()
    hg, hs, screws = handguard()
    barrel = barrel_and_brake()
    rs = buis(-0.215, -0.115, "rear_sight")
    fs = buis(1.35, 1.45, "front_sight")
    op, glass = optic()
    mag = magazine()
    st_parts, st, latch, pad, nut = stock()
    qd1 = qd_cup(-0.078, -0.105, -0.285, BORE + 0.012)
    qd2 = qd_cup(-0.1, -0.124, 1.40, 0.395)

    groups = {
        f"{NAME}_receiver": up + st_parts + [rs[0], fs[0]] + up_dark,
        f"{NAME}_gunmetal": low,
        f"{NAME}_accent": [hg],
        f"{NAME}_polymer": [grip, st],
        f"{NAME}_dark": [hs, latch, rs[1], fs[1]] + low_dark,
        f"{NAME}_metal": barrel + up_metal + low_metal + screws + [nut, qd1, qd2, rs[2], fs[2]],
        f"{NAME}_rubber": [pad],
        f"{NAME}_olive_mag": [mag],
        f"{NAME}_receiver_optic": op,
        f"{NAME}_glass_optic": [glass],
    }
    objs = {}
    for name, items in groups.items():
        objs[name] = geo.join_keep_normals(items, name) if len(items) > 1 else items[0]
        objs[name].name = name
        objs[name].data.name = name
    # Points in Roblox frame (x, y, z) = Blender (x, z, -y)
    points = {
        "Support": [0.0, 0.25, -1.06],
        "Muzzle": [0.0, BORE, -1.95],
        "Sight": [0.0, SIGHT_Z, 0.30],
        "Stock": [0.0, 0.34, 1.03],
        "Audio": [0.0, BORE, -0.3],
    }
    return objs, points
