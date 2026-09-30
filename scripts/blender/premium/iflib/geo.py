"""Geometry toolkit for the Ironfront premium assets.

Everything is authored in Blender space with the Roblox mapping used across the
project: Blender (x, y, z) = Roblox (x, -z, y). So +X is right, +Y is forward
(the muzzle / the character's front) and +Z is up. 1 unit = 1 stud.

The builders below produce clean, closed meshes that survive EXACT booleans and
the bevel modifier: filleted 2D profiles extruded into slabs, lofts through
cross-sections, lathes, swept sections along paths and simple boxes/cylinders.
"""
import math

import bpy  # noqa: F401  (must be imported before bmesh/mathutils with pip bpy)
import bmesh
from mathutils import Matrix, Quaternion, Vector


# ------------------------------------------------------------------ 2D profiles

def fillet(pts, radius, seg=4):
    """Rounds the corners of a closed 2D polygon. `radius` is a scalar or a list
    (one radius per corner, 0 keeps the corner sharp)."""
    n = len(pts)
    radii = list(radius) if isinstance(radius, (list, tuple)) else [radius] * n
    out = []
    for i in range(n):
        p = Vector(pts[i])
        a = Vector(pts[i - 1])
        b = Vector(pts[(i + 1) % n])
        r = radii[i]
        u1, u2 = a - p, b - p
        l1, l2 = u1.length, u2.length
        if r <= 0 or l1 < 1e-9 or l2 < 1e-9:
            out.append(p)
            continue
        u1.normalize()
        u2.normalize()
        theta = math.acos(max(-1.0, min(1.0, u1.dot(u2))))
        if theta < 1e-3 or abs(theta - math.pi) < 1e-3:
            out.append(p)
            continue
        d = r / math.tan(theta / 2)
        dmax = 0.49 * min(l1, l2)
        if d > dmax:
            d = dmax
            r = d * math.tan(theta / 2)
        t1 = p + u1 * d
        t2 = p + u2 * d
        c = p + (u1 + u2).normalized() * (r / math.sin(theta / 2))
        a1 = math.atan2(t1.y - c.y, t1.x - c.x)
        a2 = math.atan2(t2.y - c.y, t2.x - c.x)
        da = a2 - a1
        while da > math.pi:
            da -= 2 * math.pi
        while da < -math.pi:
            da += 2 * math.pi
        for k in range(seg + 1):
            ang = a1 + da * k / seg
            out.append(Vector((c.x + r * math.cos(ang), c.y + r * math.sin(ang))))
    return out


def rrect(w, h, r, seg=3, cx=0.0, cy=0.0):
    """Rounded rectangle, counter-clockwise, starting bottom-left."""
    hw, hh = w / 2, h / 2
    pts = [(cx - hw, cy - hh), (cx + hw, cy - hh), (cx + hw, cy + hh), (cx - hw, cy + hh)]
    return fillet(pts, r, seg)


def circle(r, n=16, cx=0.0, cy=0.0, start=0.0):
    return [Vector((cx + r * math.cos(start + 2 * math.pi * i / n), cy + r * math.sin(start + 2 * math.pi * i / n))) for i in range(n)]


def superellipse(w, h, p=4.0, n=24, cx=0.0, cy=0.0):
    """|x/a|^p + |y/b|^p = 1 — pillowy rectangles for soft goods."""
    out = []
    for i in range(n):
        t = 2 * math.pi * i / n
        c, s = math.cos(t), math.sin(t)
        x = (w / 2) * math.copysign(abs(c) ** (2 / p), c)
        y = (h / 2) * math.copysign(abs(s) ** (2 / p), s)
        out.append(Vector((cx + x, cy + y)))
    return out


def poly_area(pts):
    a = 0.0
    for i in range(len(pts)):
        x1, y1 = pts[i - 1]
        x2, y2 = pts[i]
        a += x1 * y2 - x2 * y1
    return a / 2


def ccw(pts):
    return pts if poly_area(pts) > 0 else list(reversed(pts))


def resample(pts, n):
    """Resamples a closed polyline to n points evenly spaced by arc length."""
    pts = [Vector(p) for p in pts]
    segs = [(pts[i], pts[(i + 1) % len(pts)]) for i in range(len(pts))]
    lengths = [(b - a).length for a, b in segs]
    total = sum(lengths)
    out = []
    acc_i, acc = 0, 0.0
    for k in range(n):
        target = total * k / n
        while acc_i < len(segs) - 1 and acc + lengths[acc_i] < target:
            acc += lengths[acc_i]
            acc_i += 1
        a, b = segs[acc_i]
        t = 0.0 if lengths[acc_i] < 1e-12 else (target - acc) / lengths[acc_i]
        out.append(a.lerp(b, t))
    return out


# ------------------------------------------------------------------ mesh builder

AXES = {"X": (1, 2, 0), "Y": (0, 2, 1), "Z": (0, 1, 2)}  # 2D (u, v) -> 3D indices, then extrusion index


def _map(u, v, w, axis):
    iu, iv, iw = AXES[axis]
    p = [0.0, 0.0, 0.0]
    p[iu], p[iv], p[iw] = u, v, w
    return Vector(p)


class MB:
    """Accumulates geometry in a bmesh; call .obj() to create the object."""

    def __init__(self):
        self.bm = bmesh.new()

    # -- low level
    def ring(self, pts, m=None):
        return [self.bm.verts.new(m @ Vector(p) if m else Vector(p)) for p in pts]

    def face(self, verts):
        try:
            return self.bm.faces.new(verts)
        except ValueError:
            return None

    def bridge(self, r1, r2, closed=True):
        n = len(r1)
        rng = range(n) if closed else range(n - 1)
        for i in rng:
            j = (i + 1) % n
            self.face([r1[i], r1[j], r2[j], r2[i]])

    def cap(self, ring, flip=False):
        return self.face(list(reversed(ring)) if flip else ring)

    # -- primitives
    def prism(self, pts2d, axis="X", a0=-0.5, a1=0.5, m=None):
        """Extrudes a closed 2D profile along `axis` from a0 to a1.
        axis X: profile in (Y, Z); Y: (X, Z); Z: (X, Y)."""
        pts2d = ccw([Vector(p) for p in pts2d])
        r0 = self.ring([_map(p.x, p.y, a0, axis) for p in pts2d], m)
        r1 = self.ring([_map(p.x, p.y, a1, axis) for p in pts2d], m)
        self.bridge(r0, r1)
        self.cap(r0, flip=True)
        self.cap(r1)
        return r0, r1

    def loft(self, sections, cap0=True, cap1=True, closed=True, m=None):
        """Bridges a list of 3D rings (same vertex count, same winding)."""
        rings = [self.ring(s, m) for s in sections]
        for a, b in zip(rings, rings[1:]):
            self.bridge(a, b, closed)
        if closed:
            if cap0:
                self.cap(rings[0], flip=True)
            if cap1:
                self.cap(rings[-1])
        return rings

    def lathe(self, profile, segs=24, axis="Y", center=(0.0, 0.0), m=None, start=0.0):
        """Revolves (radius, position) pairs around an axis through `center`
        (the two other coordinates). Radius 0 at an end makes a pole."""
        rings = []
        poles = []
        for r, t in profile:
            if r <= 1e-9:
                poles.append((len(rings), t))
                rings.append(None)
                continue
            pts = []
            for i in range(segs):
                a = start + 2 * math.pi * i / segs
                u, v = center[0] + r * math.cos(a), center[1] + r * math.sin(a)
                pts.append(_map(u, v, t, axis))
            rings.append(self.ring(pts, m))
        for i in range(len(rings) - 1):
            a, b = rings[i], rings[i + 1]
            if a is None and b is None:
                continue
            if a is None or b is None:
                ring = b if a is None else a
                t = profile[i][1] if a is None else profile[i + 1][1]
                pole = self.bm.verts.new(m @ _map(center[0], center[1], t, axis) if m else _map(center[0], center[1], t, axis))
                for k in range(segs):
                    kk = (k + 1) % segs
                    if a is None:
                        self.face([pole, ring[kk], ring[k]])
                    else:
                        self.face([ring[k], ring[kk], pole])
                continue
            self.bridge(a, b)
        if rings[0] is not None:
            self.cap(rings[0], flip=True)
        if rings[-1] is not None:
            self.cap(rings[-1])
        return rings

    def box(self, center, size, m=None):
        cx, cy, cz = center
        sx, sy, sz = (s / 2 for s in size)
        pts = [(cx - sx, cy - sy), (cx + sx, cy - sy), (cx + sx, cy + sy), (cx - sx, cy + sy)]
        return self.prism(pts, "Z", cz - sz, cz + sz, m)

    def cyl(self, center, r, length, axis="Y", segs=16, m=None):
        """Cylinder along `axis`, centred on `center`."""
        c = Vector(center)
        iu, iv, iw = AXES[axis]
        prof = [(r, c[iw] - length / 2), (r, c[iw] + length / 2)]
        return self.lathe(prof, segs, axis, (c[iu], c[iv]), m)

    def sweep(self, section, path, up=(0, 0, 1), caps=True, scale=None, twist=None, m=None, closed_path=False):
        """Sweeps a closed 2D section (u = side, v = up) along a 3D polyline using
        parallel-transport frames. `scale(i, t)` may return a float or (su, sv)."""
        path = [Vector(p) for p in path]
        n = len(path)
        tangents = []
        for i in range(n):
            if closed_path:
                t = path[(i + 1) % n] - path[i - 1]
            elif i == 0:
                t = path[1] - path[0]
            elif i == n - 1:
                t = path[-1] - path[-2]
            else:
                t = (path[i + 1] - path[i]).normalized() + (path[i] - path[i - 1]).normalized()
            tangents.append(t.normalized())
        normal = Vector(up)
        normal = (normal - tangents[0] * normal.dot(tangents[0])).normalized()
        frames = []
        for i in range(n):
            if i > 0:
                q = tangents[i - 1].rotation_difference(tangents[i])
                normal = q @ normal
                normal = (normal - tangents[i] * normal.dot(tangents[i])).normalized()
            side = tangents[i].cross(normal).normalized()
            frames.append((side, normal))
        rings = []
        total = sum((path[i + 1] - path[i]).length for i in range(n - 1)) or 1.0
        acc = 0.0
        for i in range(n):
            if i > 0:
                acc += (path[i] - path[i - 1]).length
            t = acc / total
            side, nrm = frames[i]
            su = sv = 1.0
            if scale:
                s = scale(i, t)
                su, sv = (s, s) if isinstance(s, (int, float)) else s
            ang = twist(i, t) if twist else 0.0
            ca, sa = math.cos(ang), math.sin(ang)
            pts = []
            for p in section:
                u, v = p[0] * su, p[1] * sv
                u, v = u * ca - v * sa, u * sa + v * ca
                pts.append(path[i] + side * u + nrm * v)
            rings.append(self.ring(pts, m))
        for a, b in zip(rings, rings[1:]):
            self.bridge(a, b)
        if closed_path:
            self.bridge(rings[-1], rings[0])
        elif caps:
            self.cap(rings[0], flip=True)
            self.cap(rings[-1])
        return rings

    def merge(self, dist=1e-6):
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=dist)

    def transform(self, m):
        bmesh.ops.transform(self.bm, matrix=m, verts=self.bm.verts)

    def obj(self, name, mat=None, coll=None, recalc=True, smooth=True):
        if recalc:
            bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        mesh = bpy.data.meshes.new(name)
        self.bm.to_mesh(mesh)
        self.bm.free()
        o = bpy.data.objects.new(name, mesh)
        (coll or bpy.context.scene.collection).objects.link(o)
        if mat is not None:
            o.data.materials.append(mat)
        if smooth:
            for p in mesh.polygons:
                p.use_smooth = True
        return o


# ------------------------------------------------------------------ object ops

def apply_mods(obj):
    """Applies the modifier stack through the depsgraph (no operator context)."""
    dg = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(dg)
    mesh = bpy.data.meshes.new_from_object(ev, preserve_all_data_layers=True, depsgraph=dg)
    old = obj.data
    obj.modifiers.clear()
    obj.data = mesh
    mesh.name = old.name
    if old.users == 0:
        bpy.data.meshes.remove(old)
    return obj


def boolean(target, cutter, op="DIFFERENCE", keep=False, self_intersect=True):
    """EXACT boolean with one cutter object (may contain many closed shells;
    pass self_intersect=True when those shells overlap each other)."""
    mod = target.modifiers.new("Bool", "BOOLEAN")
    mod.operation = op
    mod.solver = "EXACT"
    mod.use_self = self_intersect
    mod.object = cutter
    cutter.hide_render = True
    cutter.hide_viewport = True
    apply_mods(target)
    if not keep:
        bpy.data.objects.remove(cutter, do_unlink=True)
    return target


def cut(target, build, op="DIFFERENCE", self_intersect=True):
    """Convenience: build(mb) adds cutter geometry, which is subtracted/united."""
    mb = MB()
    build(mb)
    c = mb.obj("_cutter", smooth=False)
    return boolean(target, c, op, self_intersect=self_intersect)


STATS = {}


def finish(obj, bevel=0.008, segments=2, angle=32, profile=0.5, harden=True, weighted=True, clamp=True):
    """Bevels hard edges (angle-limited) and sets weighted/hardened normals."""
    for p in obj.data.polygons:
        p.use_smooth = True
    if bevel > 0:
        b = obj.modifiers.new("Bevel", "BEVEL")
        b.width = bevel
        b.segments = segments
        b.profile = profile
        b.limit_method = "ANGLE"
        b.angle_limit = math.radians(angle)
        b.use_clamp_overlap = clamp
        b.harden_normals = harden
        b.miter_outer = "MITER_ARC"
    if weighted:
        w = obj.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL")
        w.keep_sharp = True
        w.mode = "FACE_AREA"
        w.weight = 50
    apply_mods(obj)
    key = obj.name.split(".")[0]
    STATS[key] = STATS.get(key, 0) + tri_count(obj)
    return obj


def smooth(obj, angle=None):
    for p in obj.data.polygons:
        p.use_smooth = True
    if angle is not None:
        obj.data.set_sharp_from_angle(angle=math.radians(angle))
    return obj


def subdivide(obj, levels=1, simple=False):
    m = obj.modifiers.new("Subd", "SUBSURF")
    m.levels = levels
    m.render_levels = levels
    m.subdivision_type = "SIMPLE" if simple else "CATMULL_CLARK"
    apply_mods(obj)
    return obj


def displace_verts(obj, fn):
    """fn(co: Vector, normal: Vector) -> Vector offset (object space)."""
    mesh = obj.data
    offs = [fn(v.co.copy(), v.normal.copy()) for v in mesh.vertices]
    for v, o in zip(mesh.vertices, offs):
        v.co += o
    mesh.update()
    return obj


def join(objs, name):
    """Joins meshes into the first object (keeps each object's materials)."""
    objs = [o for o in objs if o is not None]
    base = objs[0]
    bm = bmesh.new()
    mats = []
    for o in objs:
        me = o.data
        tmp = bmesh.new()
        tmp.from_mesh(me)
        tmp.transform(base.matrix_world.inverted() @ o.matrix_world)
        # material remap
        remap = {}
        for i, mat in enumerate(me.materials):
            if mat not in mats:
                mats.append(mat)
            remap[i] = mats.index(mat)
        for f in tmp.faces:
            f.material_index = remap.get(f.material_index, 0)
        tmp_mesh = bpy.data.meshes.new("_tmp")
        tmp.to_mesh(tmp_mesh)
        tmp.free()
        bm.from_mesh(tmp_mesh)
        bpy.data.meshes.remove(tmp_mesh)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for mat in mats:
        mesh.materials.append(mat)
    # keep per-object custom normals: rebuild from source loops is costly, so
    # callers finish() pieces after joining when they need hardened normals.
    colls = list(base.users_collection)
    for o in objs:
        bpy.data.objects.remove(o, do_unlink=True)
    o = bpy.data.objects.new(name, mesh)
    for c in colls or [bpy.context.scene.collection]:
        c.objects.link(o)
    for p in mesh.polygons:
        p.use_smooth = True
    return o


def join_keep_normals(objs, name):
    """Joins objects preserving custom split normals (uses the join operator)."""
    objs = [o for o in objs if o is not None]
    ctx = bpy.context
    for o in ctx.view_layer.objects:
        o.select_set(False)
    for o in objs:
        o.hide_viewport = False
        o.hide_set(False)
        o.select_set(True)
    ctx.view_layer.objects.active = objs[0]
    with ctx.temp_override(active_object=objs[0], selected_editable_objects=objs, selected_objects=objs):
        bpy.ops.object.join()
    o = objs[0]
    o.name = name
    o.data.name = name
    return o


def tri_count(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def bounds(objs):
    bpy.context.view_layer.update()  # matrix_world is stale after moving objects
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for o in objs:
        if o.type != "MESH":
            continue
        mw = o.matrix_world
        for v in o.data.vertices:
            w = mw @ v.co
            for i in range(3):
                lo[i] = min(lo[i], w[i])
                hi[i] = max(hi[i], w[i])
    return lo, hi


def mirror_x(obj, name):
    """Returns a mirrored (across X) copy with correct normals."""
    me = obj.data.copy()
    o = bpy.data.objects.new(name, me)
    for c in obj.users_collection:
        c.objects.link(o)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.scale(bm, vec=(-1, 1, 1), verts=bm.verts)
    bmesh.ops.reverse_faces(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    o.matrix_world = Matrix.Scale(1, 4)
    return o


def rot(axis, deg):
    return Matrix.Rotation(math.radians(deg), 4, axis)


def tr(x, y, z):
    return Matrix.Translation((x, y, z))


def lerp(a, b, t):
    return a + (b - a) * t


def smoothstep(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


# ------------------------------------------------------------------ soft goods

def block_levels(sz, r_bot, r_top, vseg=3, mid=0):
    """(z, inset) samples for a vertically rounded block of height sz."""
    hz = sz / 2
    out = []
    if r_bot > 0:
        for i in range(vseg + 1):
            a = (math.pi / 2) * i / vseg
            out.append((-hz + r_bot - r_bot * math.cos(a), r_bot - r_bot * math.sin(a)))
    else:
        out.append((-hz, 0.0))
    z0 = out[-1][0]
    z1 = hz - r_top
    for i in range(1, mid + 1):
        out.append((z0 + (z1 - z0) * i / (mid + 1), 0.0))
    if r_top > 0:
        for i in range(vseg + 1):
            a = (math.pi / 2) * i / vseg
            out.append((hz - r_top + r_top * math.sin(a), r_top - r_top * math.cos(a)))
    else:
        out.append((hz, 0.0))
    # drop duplicates
    clean = [out[0]]
    for p in out[1:]:
        if abs(p[0] - clean[-1][0]) > 1e-6 or abs(p[1] - clean[-1][1]) > 1e-6:
            clean.append(p)
    return clean


def soft_block(mb, center, size, r_side=0.05, r_top=0.03, r_bot=0.03, seg=3, vseg=3, mid=0, puff=0.0, dome=0.0,
               cap_top=True, cap_bot=True, m=None, axis="Z"):
    """Rounded, optionally pillowy block (pouches, pads, packs, sleeves).
    Built along `axis` (Z default: size = (x, y, z)); puff bulges the side
    walls, dome raises the caps' centres. Returns the list of rings."""
    cx, cy, cz = center
    if axis == "Z":
        w, d, h = size
    elif axis == "Y":
        w, d, h = size[0], size[2], size[1]
    else:
        w, d, h = size[1], size[2], size[0]
    levels = block_levels(h, r_bot, r_top, vseg, mid)
    hz = h / 2
    rings = []
    for z, inset in levels:
        k = 1.0
        if puff:
            k += puff * max(0.0, 1 - (z / hz) ** 2)
        rw = max(w * k - 2 * inset, 0.002)
        rd = max(d * k - 2 * inset, 0.002)
        rr = max(min(r_side, rw / 2, rd / 2) - inset * 0.5, 0.002)
        pts = rrect(rw, rd, rr, seg)
        ring = []
        for p in pts:
            if axis == "Z":
                ring.append(Vector((cx + p.x, cy + p.y, cz + z)))
            elif axis == "Y":
                ring.append(Vector((cx + p.x, cy + z, cz + p.y)))
            else:
                ring.append(Vector((cx + z, cy + p.x, cz + p.y)))
        rings.append(ring)
    made = [mb.ring(r, m) for r in rings]
    for a, b in zip(made, made[1:]):
        mb.bridge(a, b)

    def cap(ring_verts, pts, sign):
        if dome:
            c = sum((Vector(p) for p in pts), Vector()) / len(pts)
            if axis == "Z":
                c.z += sign * dome
            elif axis == "Y":
                c.y += sign * dome
            else:
                c.x += sign * dome
            cv = mb.bm.verts.new(m @ c if m else c)
            n = len(ring_verts)
            for i in range(n):
                j = (i + 1) % n
                mb.face([ring_verts[i], ring_verts[j], cv] if sign > 0 else [ring_verts[j], ring_verts[i], cv])
        else:
            mb.cap(ring_verts, flip=sign < 0)
    if cap_bot:
        cap(made[0], rings[0], -1)
    if cap_top:
        cap(made[-1], rings[-1], 1)
    return made


def ellipse(rx, ry, n=16, cx=0.0, cy=0.0, rot=0.0):
    ca, sa = math.cos(rot), math.sin(rot)
    out = []
    for i in range(n):
        t = 2 * math.pi * i / n
        x, y = rx * math.cos(t), ry * math.sin(t)
        out.append(Vector((cx + x * ca - y * sa, cy + x * sa + y * ca)))
    return out


def catmull_path(points, per=6):
    """Smooth open path through control points (Catmull-Rom), as Vectors."""
    pts = [Vector(p) for p in points]
    out = []
    for i in range(len(pts) - 1):
        p0 = pts[i - 1] if i > 0 else pts[i] * 2 - pts[i + 1]
        p1, p2 = pts[i], pts[i + 1]
        p3 = pts[i + 2] if i + 2 < len(pts) else pts[i + 1] * 2 - pts[i]
        for k in range(per):
            t = k / per
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(pts[-1])
    return out
