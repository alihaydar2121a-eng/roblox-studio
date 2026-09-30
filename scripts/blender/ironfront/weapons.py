"""
Weapon models for OPERATION IRONFRONT (original fictional designs).

Frame (Blender space): origin = right-hand grip point, +Y = muzzle direction,
+Z = up, X = right. These map to the Roblox frame used by
Shared.Config.WeaponModels (origin = grip, -Z forward, +Y up); the Points
dictionaries below are kept identical to the Luau spec (Roblox axes).

Each builder returns a list of objects tagged with obj["group"] in
{None, "mag", "optic"} so the runtime can hide magazines during reloads and
optics while aiming down sights.
"""
import math

from mathutils import Matrix

from . import geo, mats


def _tag(obj, mat, group=None):
    geo.set_material(obj, mat)
    obj["group"] = group or ""
    return obj


def _ry(deg):
    return Matrix.Rotation(math.radians(deg), 3, "Y")


def _rx(deg):
    return Matrix.Rotation(math.radians(deg), 3, "X")


# ------------------------------------------------------------------ shared parts

def barrel(name, r, y0, y1, z, mat, steps=None):
    prof = [(0.0, y0), (r, y0)]
    for (ry, rr) in (steps or []):
        prof += [(r, ry), (rr, ry)]
        r = rr
    prof += [(r, y1), (0.0, y1)]
    return _tag(geo.lathe(name, prof, (0, z), "Y", 14), mat)


def muzzle_brake(name, y0, length, r, z, mat, ports=3):
    obj = geo.lathe(name, [(0.0, y0), (r * 0.8, y0), (r, y0 + 0.02), (r, y0 + length - 0.02), (r * 0.85, y0 + length), (0.03, y0 + length)], (0, z), "Y", 16, bev=0.006)
    step = (length - 0.08) / ports
    geo.cut_slots(obj, [(0, y0 + 0.06 + i * step + step / 2, z) for i in range(ports)], (r * 3, step * 0.45, r * 0.9))
    return _tag(obj, mat)


def flash_hider(name, y0, length, r, z, mat):
    obj = geo.lathe(name, [(0.0, y0), (r, y0), (r, y0 + length), (r * 0.7, y0 + length)], (0, z), "Y", 16, bev=0.005)
    # Four prongs: cut X and Z slots at the front half.
    geo.cut_slots(obj, [(0, y0 + length * 0.72, z)], (r * 3, length * 0.6, r * 0.35))
    geo.cut_slots(obj, [(0, y0 + length * 0.72, z)], (r * 0.35, length * 0.6, r * 3))
    return _tag(obj, mat)


def pistol_grip(name, y_top0, y_top1, z_top, length, rake, width, mat, grooves=True):
    """Ergonomic pistol grip with finger grooves and a palm swell."""
    t = math.tan(math.radians(rake))
    fy = lambda z: -(z_top - z) * t  # noqa: E731  back-sweep with depth
    pts = [(y_top0, z_top), (y_top1, z_top)]
    zs = [z_top - length * k for k in (0.15, 0.32, 0.5, 0.68, 0.86, 1.0)]
    front = [y_top1 - 0.01, y_top1 - 0.035, y_top1 - 0.01, y_top1 - 0.035, y_top1 - 0.015, y_top1 - 0.03] if grooves else [y_top1] * 6
    for zz, fy0 in zip(zs, front):
        pts.append((fy0 + fy(zz), zz))
    pts.append((y_top0 + fy(z_top - length) - 0.02, z_top - length - 0.01))
    pts.append((y_top0 + fy(z_top - length * 0.55) - 0.03, z_top - length * 0.55))
    pts.append((y_top0 - 0.03, z_top - 0.04))
    obj = geo.extrude(name, pts, width, bev=0.032, seg=3, angle=25)
    return _tag(obj, mat)


def trigger_group(name, y_front, z_bottom, mat_metal, mat_guard):
    guard = geo.tube(name + "_guard", [(0, y_front - 0.32, z_bottom + 0.1), (0, y_front - 0.33, z_bottom), (0, y_front - 0.05, z_bottom - 0.01),
                                        (0, y_front, z_bottom + 0.04), (0, y_front, z_bottom + 0.11)], 0.016, 6)
    trig = geo.extrude(name + "_trigger", [(y_front - 0.2, z_bottom + 0.1), (y_front - 0.17, z_bottom + 0.1), (y_front - 0.19, z_bottom + 0.05),
                                           (y_front - 0.23, z_bottom + 0.02), (y_front - 0.215, z_bottom + 0.055)], 0.03, bev=0.005, seg=1)
    return [_tag(guard, mat_guard), _tag(trig, mat_metal)]


def curved_mag(name, y_top, width, z_top, depth, curve, mat, mat_base, ribs=2):
    """Curved box magazine: front/back follow an arc; ribbed sides; baseplate."""
    pts_front, pts_back = [], []
    n = 6
    for i in range(n + 1):
        k = i / n
        z = z_top - depth * k
        off = curve * (k ** 1.6)
        pts_front.append((y_top + width + off, z))
        pts_back.append((y_top + off - 0.01 * k, z))
    body = geo.extrude(name, pts_front + list(reversed(pts_back)), 0.18, bev=0.018, seg=2)
    if ribs:
        centers = []
        for i in range(ribs):
            k = 0.35 + i * 0.25
            z = z_top - depth * k
            off = curve * (k ** 1.6)
            centers += [(0.09, y_top + off + width / 2, z), (-0.09, y_top + off + width / 2, z)]
        geo.cut_slots(body, centers, (0.02, width * 0.72, 0.022))
    k = 1.0
    off = curve
    base = geo.box(name + "_base", (0.21, width + 0.06, 0.05), (0, y_top + off + width / 2 + 0.005, z_top - depth - 0.015), bev=0.012, rot=_rx(-math.degrees(math.atan(curve * 1.6 / depth)) * 0.6))
    return [_tag(body, mat, "mag"), _tag(base, mat_base, "mag")]


def prism_optic(name, y0, y1, z, r, mat, mat_lens, mat_mount, rail_z):
    """Compact magnified optic: body tube with objective bell, turrets, mount."""
    L = y1 - y0
    body = geo.lathe(name + "_body", [(0.0, y0), (r * 0.9, y0), (r, y0 + 0.03), (r, y0 + L * 0.28), (r * 0.82, y0 + L * 0.35),
                                      (r * 0.82, y0 + L * 0.62), (r * 1.18, y0 + L * 0.8), (r * 1.2, y1 - 0.01), (r * 1.1, y1), (0.0, y1)], (0, z), "Y", 20, bev=0.004)
    lens_f = geo.lathe(name + "_lensF", [(0.0, y1 + 0.001), (r * 1.02, y1 + 0.001), (r * 1.02, y1 + 0.004), (0.0, y1 + 0.004)], (0, z), "Y", 20)
    lens_r = geo.lathe(name + "_lensR", [(0.0, y0 - 0.004), (r * 0.8, y0 - 0.004), (r * 0.8, y0 - 0.001), (0.0, y0 - 0.001)], (0, z), "Y", 16)
    ty = y0 + L * 0.48
    turret_top = geo.lathe(name + "_turretT", [(0.0, z + r * 0.7), (r * 0.42, z + r * 0.7), (r * 0.42, z + r * 1.45), (r * 0.36, z + r * 1.52), (0.0, z + r * 1.52)], (0, ty), "Z", 12, bev=0.003)
    turret_side = geo.lathe(name + "_turretS", [(0.0, 0.0), (r * 0.42, 0.0), (r * 0.42, 0.075), (0.0, 0.075)], (0, 0), "Z", 12)
    geo.transform(turret_side, Matrix.Translation((r * 0.72, ty, z)) @ Matrix.Rotation(math.radians(-90), 4, "Y"))
    mount = geo.extrude(name + "_mount", [(y0 + L * 0.15, rail_z), (y0 + L * 0.72, rail_z), (y0 + L * 0.66, z - r * 0.4), (y0 + L * 0.22, z - r * 0.4)], r * 1.3, bev=0.008)
    screws = []
    for yy in (y0 + L * 0.3, y0 + L * 0.58):
        s = geo.lathe(name + "_screw", [(0.0, 0.0), (0.022, 0.0), (0.022, 0.03), (0.0, 0.03)], (0, 0), "Z", 10)
        geo.transform(s, Matrix.Translation((r * 0.62, yy, rail_z + 0.035)) @ Matrix.Rotation(math.radians(-90), 4, "Y"))
        screws.append(_tag(s, mat_mount, "optic"))
    return [_tag(body, mat, "optic"), _tag(lens_f, mat_lens, "optic"), _tag(lens_r, mat_lens, "optic"), _tag(turret_top, mat, "optic"),
            _tag(turret_side, mat, "optic"), _tag(mount, mat_mount, "optic")] + screws


def sling_loop(name, center, radius, mat, axis="X"):
    pts = []
    for i in range(13):
        a = math.pi * i / 12
        if axis == "X":
            pts.append((center[0], center[1] + math.cos(a) * radius, center[2] - math.sin(a) * radius))
        else:
            pts.append((center[0] + math.cos(a) * radius, center[1], center[2] - math.sin(a) * radius))
    return _tag(geo.tube(name, pts, 0.012, 6), mat)


# ------------------------------------------------------------------ KR-20 "Warden"

AR_POINTS = {"Support": (0, 0.08, -1.36), "Muzzle": (0, 0.46, -2.62), "Sight": (0, 0.765, 0.32), "Stock": (0, 0.4, 1.26), "Audio": (0, 0.45, -0.3)}


def build_AR():
    M = {
        "rec": mats.material("AR_receiver", "anodized", (44, 46, 48)),
        "poly": mats.material("AR_polymer", "polymer", (82, 88, 64)),
        "polyDark": mats.material("AR_polymerDark", "polymer", (44, 45, 46)),
        "metal": mats.material("AR_metal", "metal", (40, 41, 43)),
        "rail": mats.material("AR_rail", "anodized", (46, 47, 49)),
        "lens": mats.material("AR_lens", "lens", (40, 90, 120)),
        "rubber": mats.material("AR_rubber", "rubber", (32, 32, 34)),
    }
    parts = []
    upper = geo.extrude("AR_upper", [(-0.3, 0.36), (0.64, 0.36), (0.68, 0.4), (0.68, 0.53), (0.63, 0.575), (-0.24, 0.575), (-0.3, 0.535)], 0.24, bev=0.014)
    geo.cut_slots(upper, [(0.12, 0.2, 0.46)], (0.06, 0.26, 0.075))  # ejection port
    parts.append(_tag(upper, M["rec"]))
    parts.append(_tag(geo.box("AR_dustcover", (0.012, 0.25, 0.07), (0.1, 0.2, 0.46), bev=0.003, seg=1), M["polyDark"]))
    parts.append(_tag(geo.box("AR_forwardAssist", (0.07, 0.07, 0.07), (0.13, -0.1, 0.49), bev=0.02, seg=2), M["rec"]))
    lower = geo.extrude("AR_lower", [(-0.32, 0.365), (-0.32, 0.22), (-0.2, 0.16), (0.08, 0.16), (0.14, 0.1), (0.3, 0.08), (0.58, 0.08),
                                     (0.64, 0.14), (0.64, 0.365)], 0.22, bev=0.014)
    geo.cut_slots(lower, [(0, 0.44, 0.1)], (0.17, 0.26, 0.12))  # mag well opening
    parts.append(_tag(lower, M["rec"]))
    parts += [_tag(geo.box("AR_selector", (0.02, 0.08, 0.03), (-0.115, -0.08, 0.28), bev=0.006, seg=1), M["metal"]),
              _tag(geo.box("AR_magRelease", (0.02, 0.04, 0.04), (0.115, 0.28, 0.22), bev=0.008, seg=1), M["metal"]),
              _tag(geo.box("AR_boltCatch", (0.018, 0.06, 0.08), (-0.115, 0.32, 0.28), bev=0.005, seg=1), M["metal"])]
    parts += trigger_group("AR", 0.34, 0.1, M["metal"], M["rec"])
    parts.append(pistol_grip("AR_grip", -0.12, 0.08, 0.17, 0.46, 18, 0.17, M["poly"]))

    guard = geo.extrude("AR_handguard", [(0.64, 0.3), (1.74, 0.3), (1.8, 0.35), (1.8, 0.55), (1.74, 0.6), (0.64, 0.6), (0.62, 0.56), (0.62, 0.34)], 0.28, bev=0.03, seg=3)
    vents = []
    for i in range(5):
        y = 0.86 + i * 0.18
        vents += [(0.14, y, 0.47), (-0.14, y, 0.47), (0.14, y + 0.06, 0.38), (-0.14, y + 0.06, 0.38)]
    geo.cut_slots(guard, vents, (0.05, 0.11, 0.045))
    parts.append(_tag(guard, M["poly"]))
    parts.append(_tag(geo.rail("AR_rail", 1.95, -0.3, 0.64), M["rail"]))
    parts.append(_tag(geo.box("AR_railBottom", (0.12, 0.34, 0.035), (0, 1.5, 0.285), bev=0.006, seg=1), M["rail"]))
    parts.append(_tag(geo.extrude("AR_foregrip", [(1.22, 0.29), (1.5, 0.29), (1.47, 0.2), (1.43, 0.05), (1.38, 0.0), (1.28, 0.0), (1.24, 0.04)], 0.13, bev=0.03, seg=3), M["poly"]))
    parts.append(barrel("AR_barrel", 0.05, 1.7, 2.36, 0.46, M["metal"], [(2.02, 0.043)]))
    parts.append(_tag(geo.box("AR_gasBlock", (0.12, 0.1, 0.13), (0, 1.88, 0.48), bev=0.015), M["metal"]))
    parts.append(muzzle_brake("AR_brake", 2.36, 0.27, 0.075, 0.46, M["metal"]))
    parts.append(_tag(geo.extrude("AR_frontSight", [(1.64, 0.64), (1.74, 0.64), (1.72, 0.7), (1.7, 0.74), (1.67, 0.74), (1.66, 0.7)], 0.08, bev=0.006, seg=1), M["rail"]))
    parts.append(_tag(geo.extrude("AR_rearSight", [(-0.1, 0.64), (0.0, 0.64), (-0.01, 0.7), (-0.08, 0.7)], 0.1, bev=0.006, seg=1), M["rail"]))
    parts.append(_tag(geo.box("AR_charging", (0.28, 0.06, 0.04), (0, -0.3, 0.52), bev=0.01), M["metal"]))
    parts += prism_optic("AR_optic", 0.04, 0.66, 0.765, 0.085, M["rail"], M["lens"], M["rec"], 0.64)
    parts += curved_mag("AR_mag", 0.3, 0.26, 0.16, 0.56, 0.12, M["polyDark"], M["polyDark"])
    # Stock: buffer tube, adjustable stock with cheek riser and lightening cut, buttpad.
    parts.append(_tag(geo.lathe("AR_buffer", [(0.0, -0.3), (0.062, -0.3), (0.062, -0.86), (0.0, -0.86)], (0, 0.44), "Y", 14), M["rec"]))
    stock = geo.extrude("AR_stock", [(-0.62, 0.5), (-0.7, 0.56), (-1.14, 0.6), (-1.24, 0.58), (-1.24, 0.24), (-1.17, 0.2), (-1.02, 0.24),
                                     (-0.88, 0.34), (-0.7, 0.36), (-0.62, 0.38)], 0.19, bev=0.03, seg=3, angle=25)
    geo.cut_slots(stock, [(0, -0.96, 0.44)], (0.3, 0.22, 0.07))
    parts.append(_tag(stock, M["poly"]))
    parts.append(_tag(geo.extrude("AR_buttpad", [(-1.24, 0.59), (-1.29, 0.59), (-1.3, 0.24), (-1.24, 0.23)], 0.21, bev=0.02, seg=2), M["rubber"]))
    parts.append(_tag(geo.box("AR_stockLatch", (0.05, 0.12, 0.04), (0, -0.78, 0.33), bev=0.012), M["metal"]))
    parts.append(sling_loop("AR_slingRear", (0.1, -1.1, 0.24), 0.05, M["metal"]))
    parts.append(sling_loop("AR_slingFront", (0.14, 1.66, 0.34), 0.045, M["metal"]))
    return parts


# ------------------------------------------------------------------ KC-9 "Talon"

CB_POINTS = {"Support": (0, 0.3, -1.08), "Muzzle": (0, 0.44, -1.98), "Sight": (0, 0.71, 0.3), "Stock": (0, 0.38, 0.98), "Audio": (0, 0.44, -0.3)}


def build_CB():
    M = {
        "rec": mats.material("CB_receiver", "anodized", (36, 37, 39)),
        "fde": mats.material("CB_fde", "polymer", (158, 138, 102)),
        "fdeDark": mats.material("CB_fdeDark", "polymer", (122, 104, 76)),
        "metal": mats.material("CB_metal", "metal", (38, 39, 41)),
        "lens": mats.material("CB_lens", "lens", (150, 60, 50)),
        "rubber": mats.material("CB_rubber", "rubber", (30, 30, 32)),
    }
    parts = []
    upper = geo.extrude("CB_upper", [(-0.26, 0.35), (0.56, 0.35), (0.6, 0.39), (0.6, 0.51), (0.54, 0.545), (-0.2, 0.545), (-0.26, 0.5)], 0.22, bev=0.013)
    geo.cut_slots(upper, [(0.11, 0.18, 0.44)], (0.06, 0.22, 0.07))
    parts.append(_tag(upper, M["rec"]))
    lower = geo.extrude("CB_lower", [(-0.28, 0.355), (-0.28, 0.22), (-0.18, 0.16), (0.1, 0.16), (0.16, 0.1), (0.3, 0.09), (0.56, 0.09), (0.6, 0.15), (0.6, 0.355)], 0.21, bev=0.013)
    parts.append(_tag(lower, M["fde"]))
    parts += trigger_group("CB", 0.33, 0.11, M["metal"], M["fde"])
    parts.append(pistol_grip("CB_grip", -0.1, 0.08, 0.17, 0.44, 16, 0.16, M["fdeDark"]))
    # Chevron handguard with slots
    guard = geo.extrude("CB_handguard", [(0.6, 0.31), (1.28, 0.31), (1.36, 0.37), (1.36, 0.52), (1.3, 0.56), (0.6, 0.56), (0.58, 0.52), (0.58, 0.34)], 0.26, bev=0.028, seg=3)
    geo.cut_slots(guard, [(sx * 0.13, 0.75 + i * 0.16, 0.44) for i in range(4) for sx in (1, -1)], (0.04, 0.1, 0.05))
    parts.append(_tag(guard, M["fde"]))
    parts.append(_tag(geo.rail("CB_rail", 1.6, -0.26, 0.6), M["rec"]))
    parts.append(_tag(geo.extrude("CB_handstop", [(1.0, 0.31), (1.2, 0.31), (1.16, 0.23), (1.06, 0.22)], 0.12, bev=0.02, seg=2), M["fdeDark"]))
    parts.append(barrel("CB_barrel", 0.045, 1.34, 1.78, 0.44, M["metal"]))
    parts.append(flash_hider("CB_flash", 1.78, 0.2, 0.06, 0.44, M["metal"]))
    parts.append(_tag(geo.extrude("CB_frontSight", [(1.24, 0.6), (1.33, 0.6), (1.31, 0.68), (1.27, 0.68)], 0.07, bev=0.006, seg=1), M["rec"]))
    # Reflex sight: hood ring + base + tinted lens
    hood = geo.lathe("CB_reflexHood", [(0.062, 0.24), (0.082, 0.24), (0.082, 0.36), (0.062, 0.36)], (0, 0.71), "Y", 20, cap=False)
    base = geo.extrude("CB_reflexBase", [(0.18, 0.6), (0.4, 0.6), (0.38, 0.65), (0.2, 0.65)], 0.14, bev=0.01)
    lens = geo.lathe("CB_reflexLens", [(0.0, 0.3), (0.064, 0.3), (0.064, 0.305), (0.0, 0.305)], (0, 0.71), "Y", 20)
    parts += [_tag(hood, M["rec"], "optic"), _tag(base, M["rec"], "optic"), _tag(lens, M["lens"], "optic")]
    # Straight polymer mag with round-count window
    mag = geo.extrude("CB_mag", [(0.3, 0.16), (0.55, 0.16), (0.58, -0.15), (0.6, -0.38), (0.36, -0.4), (0.33, -0.15)], 0.18, bev=0.018)
    geo.cut_slots(mag, [(0.09, 0.47, -0.12)], (0.02, 0.05, 0.3))
    parts.append(_tag(mag, M["fdeDark"], "mag"))
    parts.append(_tag(geo.box("CB_magBase", (0.2, 0.3, 0.045), (0, 0.48, -0.41), bev=0.012), M["rec"], "mag"))
    # Folding skeleton stock
    rod = lambda n, pts: _tag(geo.tube(n, pts, 0.028, 8), M["rec"])  # noqa: E731
    parts.append(rod("CB_stockTop", [(0, -0.28, 0.48), (0, -0.9, 0.5)]))
    parts.append(rod("CB_stockLow", [(0, -0.28, 0.3), (0, -0.62, 0.26), (0, -0.9, 0.26)]))
    parts.append(_tag(geo.box("CB_stockHinge", (0.1, 0.08, 0.26), (0, -0.28, 0.39), bev=0.02), M["rec"]))
    parts.append(_tag(geo.extrude("CB_butt", [(-0.88, 0.58), (-0.96, 0.58), (-0.98, 0.18), (-0.9, 0.18)], 0.2, bev=0.03, seg=3), M["rubber"]))
    parts.append(_tag(geo.box("CB_cheek", (0.16, 0.3, 0.05), (0, -0.7, 0.53), bev=0.02), M["fdeDark"]))
    parts.append(sling_loop("CB_sling", (0.12, 1.2, 0.33), 0.04, M["metal"]))
    return parts


# ------------------------------------------------------------------ MG-44 "Bulwark"

LMG_POINTS = {"Support": (0, 0.2, -1.2), "Muzzle": (0, 0.5, -3.02), "Sight": (0, 0.82, 0.36), "Stock": (0, 0.42, 1.36), "Audio": (0, 0.5, -0.3)}


def build_LMG():
    M = {
        "rec": mats.material("LMG_receiver", "paint", (58, 62, 54)),
        "od": mats.material("LMG_od", "polymer", (76, 82, 58)),
        "metal": mats.material("LMG_metal", "metal", (38, 39, 41)),
        "rail": mats.material("LMG_rail", "anodized", (40, 41, 43)),
        "lens": mats.material("LMG_lens", "lens", (40, 90, 120)),
        "rubber": mats.material("LMG_rubber", "rubber", (30, 30, 32)),
        "canvas": mats.material("LMG_canvas", "fabric", (92, 98, 70)),
    }
    parts = []
    rec = geo.extrude("LMG_receiver", [(-0.4, 0.18), (0.36, 0.18), (0.4, 0.22), (0.4, 0.62), (-0.36, 0.62), (-0.4, 0.58)], 0.36, bev=0.02, seg=2)
    geo.cut_slots(rec, [(0.18, 0.1, 0.44)], (0.06, 0.3, 0.1))
    parts.append(_tag(rec, M["rec"]))
    cover = geo.extrude("LMG_feedCover", [(-0.36, 0.62), (0.36, 0.62), (0.36, 0.66), (0.28, 0.7), (-0.3, 0.7), (-0.36, 0.67)], 0.32, bev=0.012)
    geo.cut_slots(cover, [(0, -0.2 + i * 0.12, 0.7) for i in range(5)], (0.36, 0.04, 0.02))
    parts.append(_tag(cover, M["rec"]))
    parts.append(_tag(geo.rail("LMG_rail", 0.72, -0.36, 0.74), M["rail"]))
    parts.append(_tag(geo.box("LMG_coverLatch", (0.08, 0.06, 0.06), (0, -0.4, 0.66), bev=0.015), M["metal"]))
    # Barrel shroud / handguard with cooling ribs, heavy barrel, flash hider
    guard = geo.extrude("LMG_handguard", [(0.4, 0.33), (1.05, 0.33), (1.12, 0.38), (1.12, 0.62), (1.05, 0.66), (0.4, 0.66)], 0.34, bev=0.03, seg=3)
    geo.cut_slots(guard, [(sx * 0.17, 0.5 + i * 0.14, 0.52) for i in range(4) for sx in (1, -1)], (0.05, 0.08, 0.14))
    parts.append(_tag(guard, M["od"]))
    # Receiver side detail: recessed panel, rivets, left-side charging handle.
    geo.cut_slots(rec, [(-0.18, -0.12, 0.38)], (0.02, 0.4, 0.18))
    for sx in (1, -1):
        for i in range(4):
            for zz in (0.26, 0.54):
                rv = geo.lathe(f"LMG_rivet{sx}{i}{zz}", [(0.0, 0.0), (0.022, 0.0), (0.02, 0.012), (0.0, 0.016)], (0, 0), "Z", 8)
                geo.transform(rv, Matrix.Translation((sx * 0.18, -0.3 + i * 0.2, zz)) @ Matrix.Rotation(math.radians(90 * sx), 4, "Y"))
                parts.append(_tag(rv, M["metal"]))
    parts.append(_tag(geo.box("LMG_chargeSlot", (0.02, 0.5, 0.05), (-0.185, 0.02, 0.56), bev=0.004, seg=1), M["rubber"]))
    parts.append(_tag(geo.tube("LMG_chargeHandle", [(-0.19, 0.2, 0.56), (-0.3, 0.22, 0.56)], 0.022, 8), M["metal"]))
    parts.append(_tag(geo.box("LMG_chargeKnob", (0.06, 0.08, 0.08), (-0.32, 0.22, 0.56), bev=0.025), M["rubber"]))
    shroud = geo.lathe("LMG_shroud", [(0.0, 1.1), (0.11, 1.1), (0.11, 2.1), (0.08, 2.14), (0.0, 2.14)], (0, 0.5), "Y", 18)
    geo.cut_slots(shroud, [(0.0, 1.2 + i * 0.12, 0.5) for i in range(8)], (0.3, 0.05, 0.06))
    parts.append(_tag(shroud, M["metal"]))
    parts.append(barrel("LMG_barrel", 0.075, 2.1, 2.76, 0.5, M["metal"]))
    parts.append(flash_hider("LMG_flash", 2.76, 0.26, 0.09, 0.5, M["metal"]))
    parts.append(_tag(geo.extrude("LMG_frontSight", [(2.58, 0.55), (2.66, 0.55), (2.64, 0.72), (2.6, 0.72)], 0.05, bev=0.006, seg=1), M["metal"]))
    # Carry handle and barrel-change lever
    parts.append(_tag(geo.tube("LMG_carry", [(0, 0.55, 0.62), (0, 0.6, 0.84), (0, 0.9, 0.86), (0, 0.96, 0.62)], 0.03, 8), M["metal"]))
    parts.append(_tag(geo.box("LMG_carryGrip", (0.09, 0.3, 0.07), (0, 0.75, 0.86), bev=0.03), M["rubber"]))
    parts.append(_tag(geo.tube("LMG_barrelLever", [(0.16, 1.06, 0.5), (0.26, 1.08, 0.42), (0.28, 1.2, 0.36)], 0.022, 6), M["metal"]))
    # Folded bipod
    for sx in (-1, 1):
        parts.append(_tag(geo.tube(f"LMG_bipod{sx}", [(sx * 0.07, 2.2, 0.4), (sx * 0.07, 1.5, 0.38)], 0.022, 6), M["metal"]))
        parts.append(_tag(geo.box(f"LMG_bipodFoot{sx}", (0.05, 0.08, 0.05), (sx * 0.07, 1.47, 0.38), bev=0.012), M["rubber"]))
    parts.append(_tag(geo.box("LMG_bipodHinge", (0.2, 0.08, 0.1), (0, 2.22, 0.42), bev=0.02), M["metal"]))
    # Grip, trigger
    parts += trigger_group("LMG", 0.34, 0.12, M["metal"], M["rec"])
    parts.append(pistol_grip("LMG_grip", -0.12, 0.08, 0.19, 0.46, 14, 0.19, M["od"]))
    parts.append(_tag(geo.extrude("LMG_foregrip", [(1.08, 0.33), (1.32, 0.33), (1.28, 0.2), (1.24, 0.06), (1.16, 0.06), (1.12, 0.1)], 0.14, bev=0.03, seg=3), M["od"]))
    # Canvas ammo pouch with feed chute
    pouch2 = geo.box("LMG_ammoBox", (0.44, 0.5, 0.52), (-0.05, 0.62, -0.02), bev=0.06, seg=3)
    geo.cut_slots(pouch2, [(-0.28, 0.62, -0.02)], (0.02, 0.36, 0.3))
    parts.append(_tag(pouch2, M["canvas"], "mag"))
    parts.append(_tag(geo.box("LMG_ammoFlap", (0.46, 0.52, 0.06), (-0.05, 0.62, 0.25), bev=0.02), M["canvas"], "mag"))
    for sx in (1, -1):
        parts.append(_tag(geo.box(f"LMG_ammoLatch{sx}", (0.03, 0.08, 0.14), (-0.05 + sx * 0.235, 0.62, 0.17), bev=0.01), M["metal"], "mag"))
    for k in range(3):
        parts.append(_tag(geo.box(f"LMG_ammoRib{k}", (0.47, 0.03, 0.4), (-0.05, 0.44 + k * 0.18, -0.04), bev=0.008, seg=1), M["canvas"], "mag"))
    parts.append(_tag(geo.box("LMG_ammoLabel", (0.02, 0.24, 0.12), (0.18, 0.62, 0.06), bev=0.004, seg=1), M["rubber"], "mag"))
    parts.append(_tag(geo.box("LMG_chute", (0.22, 0.12, 0.16), (-0.05, 0.62, 0.3), bev=0.02), M["metal"], "mag"))
    # Fixed stock with shoulder rest
    stock = geo.extrude("LMG_stock", [(-0.4, 0.58), (-1.3, 0.66), (-1.34, 0.6), (-1.34, 0.18), (-1.28, 0.12), (-1.1, 0.14), (-0.8, 0.28), (-0.4, 0.3)], 0.24, bev=0.03, seg=3)
    geo.cut_slots(stock, [(0, -0.95, 0.4)], (0.3, 0.2, 0.1))
    parts.append(_tag(stock, M["od"]))
    parts.append(_tag(geo.extrude("LMG_buttpad", [(-1.34, 0.64), (-1.39, 0.64), (-1.4, 0.13), (-1.34, 0.12)], 0.25, bev=0.02), M["rubber"]))
    # Optic: short 1× tube
    parts += prism_optic("LMG_optic", -0.3, 0.14, 0.82, 0.07, M["rail"], M["lens"], M["rec"], 0.74)
    parts.append(sling_loop("LMG_sling", (0.15, -1.1, 0.24), 0.05, M["metal"]))
    return parts


# ------------------------------------------------------------------ SR-3 "Kestrel"

SCOPE_Z = 0.72
SR_POINTS = {"Support": (0, 0.28, -1.1), "Muzzle": (0, 0.44, -3.16), "Sight": (0, 0.72, 0.46), "Stock": (0, 0.36, 1.32), "Audio": (0, 0.44, -0.2)}


def build_SR():
    M = {
        "wood": mats.material("SR_wood", "wood", (112, 78, 52)),
        "metal": mats.material("SR_metal", "metal", (42, 44, 48)),
        "blued": mats.material("SR_blued", "anodized", (34, 36, 42)),
        "lens": mats.material("SR_lens", "lens", (40, 80, 130)),
        "rubber": mats.material("SR_rubber", "rubber", (28, 28, 30)),
    }
    parts = []
    # One-piece sporter-style stock: forend, grip swell, thumbhole, comb, butt.
    stock = geo.extrude("SR_stock", [
        (1.52, 0.37), (1.56, 0.32), (1.5, 0.26), (1.0, 0.22), (0.62, 0.2), (0.2, 0.18), (0.1, 0.14), (0.02, 0.0), (0.06, -0.2),
        (-0.02, -0.25), (-0.12, -0.22), (-0.22, 0.02), (-0.32, 0.1), (-0.6, 0.1), (-1.26, 0.0), (-1.32, 0.03), (-1.32, 0.52),
        (-1.26, 0.56), (-0.46, 0.5), (-0.3, 0.42), (-0.2, 0.37), (0.66, 0.38)], 0.22, bev=0.035, seg=3, angle=25)
    geo.cut_slots(stock, [(sx * 0.11, 1.0 + i * 0.12, 0.3) for i in range(3) for sx in (1, -1)], (0.03, 0.08, 0.06))  # forend stipple vents
    parts.append(_tag(stock, M["wood"]))
    parts.append(_tag(geo.extrude("SR_buttpad", [(-1.3, 0.58), (-1.36, 0.58), (-1.37, 0.05), (-1.3, 0.04)], 0.25, bev=0.02), M["rubber"]))
    parts.append(_tag(geo.box("SR_gripCap", (0.17, 0.12, 0.03), (0, -0.06, -0.245), bev=0.01, rot=_rx(-12)), M["blued"]))
    # Action, bolt, trigger, magazine
    parts.append(_tag(geo.lathe("SR_action", [(0.0, -0.3), (0.085, -0.3), (0.095, -0.26), (0.095, 0.62), (0.085, 0.66), (0.0, 0.66)], (0, 0.44), "Y", 18), M["blued"]))
    parts.append(_tag(geo.tube("SR_boltHandle", [(0.05, -0.08, 0.46), (0.2, -0.1, 0.44), (0.26, -0.14, 0.38)], 0.02, 8), M["metal"]))
    parts.append(_tag(geo.lathe("SR_boltKnob", [(0.0, -0.04), (0.035, -0.035), (0.045, 0.0), (0.035, 0.035), (0.0, 0.04)], (0, 0), "Z", 12), M["metal"]))
    parts[-1].data.transform(Matrix.Translation((0.27, -0.15, 0.37)))
    parts.append(_tag(geo.lathe("SR_boltShroud", [(0.0, -0.4), (0.06, -0.4), (0.07, -0.34), (0.07, -0.3), (0.0, -0.3)], (0, 0.44), "Y", 14), M["metal"]))
    parts += trigger_group("SR", 0.24, 0.1, M["metal"], M["blued"])
    parts.append(_tag(geo.extrude("SR_mag", [(0.28, 0.2), (0.5, 0.2), (0.5, -0.02), (0.28, -0.02)], 0.16, bev=0.015), M["blued"], "mag"))
    # Fluted heavy barrel with brake
    bar = geo.lathe("SR_barrel", [(0.0, 0.64), (0.075, 0.64), (0.075, 1.2), (0.055, 1.6), (0.05, 2.86), (0.0, 2.86)], (0, 0.44), "Y", 16)
    geo.cut_slots(bar, [(0.07, 1.9, 0.44), (-0.07, 1.9, 0.44), (0, 1.9, 0.51), (0, 1.9, 0.37)], (0.03, 1.2, 0.03))
    parts.append(_tag(bar, M["metal"]))
    parts.append(muzzle_brake("SR_brake", 2.86, 0.3, 0.075, 0.44, M["metal"], 4))
    # Scope: tube, objective bell, eyepiece, turrets, rings, sunshade
    tube_prof = [(0.0, -0.22), (0.075, -0.22), (0.08, -0.16), (0.08, 0.02), (0.052, 0.1), (0.052, 0.62), (0.1, 0.74), (0.11, 0.86), (0.11, 0.98), (0.1, 1.0), (0.0, 1.0)]
    parts.append(_tag(geo.lathe("SR_scope", tube_prof, (0, SCOPE_Z), "Y", 20, bev=0.003), M["blued"], "optic"))
    parts.append(_tag(geo.lathe("SR_lensF", [(0.0, 1.001), (0.095, 1.001), (0.095, 1.004), (0.0, 1.004)], (0, SCOPE_Z), "Y", 20), M["lens"], "optic"))
    parts.append(_tag(geo.lathe("SR_lensR", [(0.0, -0.224), (0.065, -0.224), (0.065, -0.221), (0.0, -0.221)], (0, SCOPE_Z), "Y", 16), M["lens"], "optic"))
    parts.append(_tag(geo.lathe("SR_turretT", [(0.0, SCOPE_Z + 0.04), (0.04, SCOPE_Z + 0.04), (0.04, SCOPE_Z + 0.13), (0.035, SCOPE_Z + 0.14), (0.0, SCOPE_Z + 0.14)], (0, 0.3), "Z", 12, bev=0.003), M["blued"], "optic"))
    ts = geo.lathe("SR_turretS", [(0.0, 0.0), (0.04, 0.0), (0.04, 0.09), (0.0, 0.09)], (0, 0), "Z", 12)
    geo.transform(ts, Matrix.Translation((0.05, 0.3, SCOPE_Z)) @ Matrix.Rotation(math.radians(90), 4, "Y"))
    parts.append(_tag(ts, M["blued"], "optic"))
    for yy in (0.05, 0.55):
        ring = geo.lathe("SR_ring", [(0.05, yy - 0.04), (0.068, yy - 0.04), (0.068, yy + 0.04), (0.05, yy + 0.04)], (0, SCOPE_Z), "Y", 18)
        leg = geo.extrude("SR_ringBase", [(yy - 0.05, 0.53), (yy + 0.05, 0.53), (yy + 0.04, SCOPE_Z - 0.05), (yy - 0.04, SCOPE_Z - 0.05)], 0.12, bev=0.01)
        parts += [_tag(ring, M["metal"], "optic"), _tag(leg, M["metal"], "optic")]
    parts.append(sling_loop("SR_slingRear", (0.13, -1.0, 0.16), 0.05, M["metal"]))
    parts.append(sling_loop("SR_slingFront", (0.13, 1.4, 0.22), 0.045, M["metal"]))
    return parts


# ------------------------------------------------------------------ P-11 "Marshal"

P11_POINTS = {"Support": (-0.12, -0.02, 0.02), "Muzzle": (0, 0.3, -0.62), "Sight": (0, 0.43, 1.5), "Stock": (0, 0.2, 0.2), "Audio": (0, 0.3, -0.2)}


def build_P11():
    M = {
        "slide": mats.material("P11_slide", "anodized", (52, 55, 58)),
        "frame": mats.material("P11_frame", "polymer", (122, 108, 84)),
        "metal": mats.material("P11_metal", "metal", (36, 37, 39)),
        "dot": mats.material("P11_dot", "paint", (220, 200, 90)),
    }
    parts = []
    slide = geo.extrude("P11_slide", [(-0.22, 0.24), (0.6, 0.24), (0.62, 0.27), (0.6, 0.36), (0.56, 0.385), (-0.2, 0.385), (-0.23, 0.36)], 0.15, bev=0.012)
    serr = [(sx * 0.075, -0.15 + i * 0.03, 0.315) for i in range(5) for sx in (1, -1)]
    serr += [(sx * 0.075, 0.44 + i * 0.03, 0.315) for i in range(3) for sx in (1, -1)]
    geo.cut_slots(slide, serr, (0.02, 0.012, 0.1))
    geo.cut_slots(slide, [(0.07, 0.1, 0.34)], (0.06, 0.2, 0.06))  # ejection port
    parts.append(_tag(slide, M["slide"]))
    parts.append(_tag(geo.box("P11_chamber", (0.07, 0.18, 0.05), (0.04, 0.1, 0.33), bev=0.008), M["metal"]))
    parts.append(_tag(geo.lathe("P11_muzzle", [(0.0, 0.6), (0.028, 0.6), (0.028, 0.618), (0.018, 0.622), (0.0, 0.622)], (0, 0.3), "Y", 12), M["metal"]))
    parts.append(_tag(geo.extrude("P11_rearSight", [(-0.2, 0.385), (-0.12, 0.385), (-0.13, 0.425), (-0.19, 0.425)], 0.12, bev=0.005, seg=1), M["metal"]))
    parts.append(_tag(geo.extrude("P11_frontSight", [(0.5, 0.385), (0.55, 0.385), (0.54, 0.425), (0.51, 0.425)], 0.035, bev=0.004, seg=1), M["metal"]))
    parts.append(_tag(geo.box("P11_frontDot", (0.015, 0.012, 0.015), (0, 0.52, 0.415), bev=0), M["dot"]))
    frame = geo.extrude("P11_frame", [(-0.2, 0.245), (0.56, 0.245), (0.56, 0.2), (0.5, 0.16), (0.18, 0.16), (0.14, 0.12), (-0.16, 0.13), (-0.24, 0.2)], 0.14, bev=0.012)
    geo.cut_slots(frame, [(0, 0.38 + i * 0.05, 0.16) for i in range(3)], (0.2, 0.02, 0.02))  # accessory rail notches
    parts.append(_tag(frame, M["frame"]))
    parts.append(_tag(geo.tube("P11_guard", [(0, 0.02, 0.15), (0, 0.02, 0.06), (0, 0.24, 0.05), (0, 0.28, 0.1), (0, 0.28, 0.17)], 0.016, 6), M["frame"]))
    parts.append(_tag(geo.extrude("P11_trigger", [(0.1, 0.16), (0.13, 0.16), (0.12, 0.1), (0.09, 0.08), (0.1, 0.11)], 0.028, bev=0.004, seg=1), M["metal"]))
    parts.append(pistol_grip("P11_grip", -0.14, 0.04, 0.16, 0.38, 16, 0.14, M["frame"], grooves=False))
    parts.append(_tag(geo.extrude("P11_beaver", [(-0.2, 0.26), (-0.14, 0.26), (-0.16, 0.18), (-0.27, 0.17), (-0.3, 0.2)], 0.12, bev=0.02, seg=2), M["frame"]))
    parts.append(_tag(geo.box("P11_magBase", (0.15, 0.2, 0.04), (0, -0.1, -0.23), bev=0.012, rot=_rx(-16)), M["metal"], "mag"))
    parts.append(_tag(geo.box("P11_slideStop", (0.02, 0.1, 0.025), (-0.075, 0.12, 0.23), bev=0.005, seg=1), M["metal"]))
    return parts


BUILDERS = {"AR": build_AR, "CB": build_CB, "LMG": build_LMG, "SR": build_SR, "P11": build_P11}
POINTS = {"AR": AR_POINTS, "CB": CB_POINTS, "LMG": LMG_POINTS, "SR": SR_POINTS, "P11": P11_POINTS}
