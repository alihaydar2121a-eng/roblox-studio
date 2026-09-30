"""
Geometry helpers. All coordinates are in *Blender space* with the Roblox
mapping used by the whole pipeline:
    Blender X = Roblox X (right)
    Blender Y = Roblox -Z (forward)
    Blender Z = Roblox Y (up)
Units: 1 Blender unit = 1 stud.
"""
import math

import bpy  # noqa: F401  (must be imported before bmesh when using the pip module)
import bmesh
from mathutils import Matrix, Vector

COLLECTION = None


def scene():
    return bpy.context.scene


def link(obj):
    scene().collection.objects.link(obj)
    return obj


def mesh_obj(name, bm):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    return link(obj)


def set_material(obj, mat):
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    return obj


def smooth(obj, angle=35):
    for p in obj.data.polygons:
        p.use_smooth = True
    mod = obj.modifiers.new("AutoSmooth", "WEIGHTED_NORMAL")
    mod.keep_sharp = True
    mod.weight = 50
    return obj


def bevel(obj, width=0.015, segments=2, angle=35, clamp=True):
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    mod.angle_limit = math.radians(angle)
    mod.use_clamp_overlap = clamp
    mod.harden_normals = True
    return obj


def subsurf(obj, levels=1):
    mod = obj.modifiers.new("Subsurf", "SUBSURF")
    mod.levels = levels
    mod.render_levels = levels
    return obj


def apply_all(obj):
    bpy.context.view_layer.objects.active = obj
    for o in bpy.context.selected_objects:
        o.select_set(False)
    obj.select_set(True)
    for mod in list(obj.modifiers):
        try:
            bpy.ops.object.modifier_apply(modifier=mod.name)
        except RuntimeError:
            obj.modifiers.remove(mod)
    obj.select_set(False)
    return obj


def transform(obj, matrix):
    obj.data.transform(matrix)
    return obj


# --------------------------------------------------------------- primitives

def extrude(name, pts, width, x=0.0, bev=0.012, seg=2, angle=35):
    """Side-profile silhouette pts [(y, z), ...] (counter-clockwise or not) extruded along X."""
    bm = bmesh.new()
    front = [bm.verts.new((x - width / 2, y, z)) for (y, z) in pts]
    face = bm.faces.new(front)
    ext = bmesh.ops.extrude_face_region(bm, geom=[face])
    moved = [e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, verts=moved, vec=(width, 0, 0))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = mesh_obj(name, bm)
    if bev > 0:
        bevel(obj, bev, seg, angle)
    return smooth(obj)


def extrude_top(name, pts, height, z=0.0, bev=0.012, seg=2):
    """Top-view outline pts [(x, y), ...] extruded along Z (up)."""
    bm = bmesh.new()
    verts = [bm.verts.new((px, py, z - height / 2)) for (px, py) in pts]
    face = bm.faces.new(verts)
    ext = bmesh.ops.extrude_face_region(bm, geom=[face])
    moved = [e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, verts=moved, vec=(0, 0, height))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = mesh_obj(name, bm)
    if bev > 0:
        bevel(obj, bev, seg)
    return smooth(obj)


def box(name, size, center=(0, 0, 0), bev=0.012, seg=2, rot=None):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    if rot:
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=rot)
    bmesh.ops.translate(bm, verts=bm.verts, vec=center)
    obj = mesh_obj(name, bm)
    if bev > 0:
        bevel(obj, bev, seg, 30)
    return smooth(obj)


def lathe(name, profile, center=(0, 0), axis="Y", segs=16, cap=True, bev=0.0):
    """Revolve profile [(r, t), ...] (t along the axis) around an axis through `center`.
    axis 'Y' = forward (barrels/scopes, center=(x, z)); axis 'Z' = up (center=(x, y))."""
    bm = bmesh.new()
    rings = []
    for (r, t) in profile:
        ring = []
        for i in range(segs):
            a = 2 * math.pi * i / segs
            c, s = math.cos(a) * r, math.sin(a) * r
            if axis == "Y":
                co = (center[0] + c, t, center[1] + s)
            else:
                co = (center[0] + c, center[1] + s, t)
            ring.append(bm.verts.new(co))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for i in range(segs):
            j = (i + 1) % segs
            try:
                bm.faces.new((a[i], a[j], b[j], b[i]))
            except ValueError:
                pass
    if cap:
        for ring in (rings[0], rings[-1]):
            if profile[0][0] > 1e-4 or ring is rings[-1]:
                try:
                    bm.faces.new(ring)
                except ValueError:
                    pass
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = mesh_obj(name, bm)
    if bev > 0:
        bevel(obj, bev, 1, 40)
    return smooth(obj)


def superellipse(w, d, n=2.6, segs=20):
    pts = []
    for i in range(segs):
        a = 2 * math.pi * i / segs
        c, s = math.cos(a), math.sin(a)
        x = (w / 2) * math.copysign(abs(c) ** (2 / n), c)
        y = (d / 2) * math.copysign(abs(s) ** (2 / n), s)
        pts.append((x, y))
    return pts


def loft(name, sections, segs=20, cap=True, axis="Z"):
    """Loft superellipse cross-sections along an axis.
    sections: [(t, w, d, n, (ox, oy)), ...] — t position along axis, w/d full size,
    n superellipse exponent (2 = ellipse, 4+ = rounded box), (ox, oy) section offset.
    axis 'Z': sections in XY (limbs, torso); axis 'Y': sections in XZ (magazines, packs)."""
    bm = bmesh.new()
    rings = []
    for sec in sections:
        t, w, d, n = sec[0], sec[1], sec[2], sec[3]
        ox, oy = sec[4] if len(sec) > 4 else (0, 0)
        ring = []
        for (px, py) in superellipse(w, d, n, segs):
            if axis == "Z":
                ring.append(bm.verts.new((ox + px, oy + py, t)))
            else:
                ring.append(bm.verts.new((ox + px, t, oy + py)))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for i in range(segs):
            j = (i + 1) % segs
            bm.faces.new((a[i], a[j], b[j], b[i]))
    if cap:
        bm.faces.new(rings[0])
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = mesh_obj(name, bm)
    return smooth(obj)


def tube(name, points, radius, segs=8, cap=True):
    """Sweep a circle along a 3D polyline (straps, cables, antennas, handles)."""
    bm = bmesh.new()
    pts = [Vector(p) for p in points]
    rings = []
    for i, p in enumerate(pts):
        if i == 0:
            t = (pts[1] - p).normalized()
        elif i == len(pts) - 1:
            t = (p - pts[i - 1]).normalized()
        else:
            t = ((pts[i + 1] - p).normalized() + (p - pts[i - 1]).normalized()).normalized()
        ref = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
        u = t.cross(ref).normalized()
        v = t.cross(u).normalized()
        ring = []
        for k in range(segs):
            a = 2 * math.pi * k / segs
            ring.append(bm.verts.new(p + (u * math.cos(a) + v * math.sin(a)) * radius))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for k in range(segs):
            j = (k + 1) % segs
            bm.faces.new((a[k], a[j], b[j], b[k]))
    if cap:
        bm.faces.new(rings[0])
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return smooth(mesh_obj(name, bm))


def strap(name, points, width, thickness):
    """Flat strap along a polyline; width axis follows the path's surface normal guess."""
    bm = bmesh.new()
    pts = [Vector(p) for p in points]
    left, right = [], []
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        side = t.cross(Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((0, 1, 0))).normalized()
        left.append(p + side * width / 2)
        right.append(p - side * width / 2)
    verts = []
    for l, r in zip(left, right):
        verts.append((bm.verts.new(l), bm.verts.new(r)))
    for (a0, b0), (a1, b1) in zip(verts, verts[1:]):
        bm.faces.new((a0, b0, b1, a1))
    obj = mesh_obj(name, bm)
    mod = obj.modifiers.new("Solidify", "SOLIDIFY")
    mod.thickness = thickness
    mod.offset = 0
    return smooth(obj)


def array_copy(obj, count, offset):
    mod = obj.modifiers.new("Array", "ARRAY")
    mod.count = count
    mod.use_relative_offset = False
    mod.use_constant_offset = True
    mod.constant_offset_displace = offset
    return obj


def boolean(target, cutter, op="DIFFERENCE"):
    apply_all(target)
    apply_all(cutter)
    mod = target.modifiers.new("Bool", "BOOLEAN")
    mod.operation = op
    mod.object = cutter
    mod.solver = "EXACT"
    bpy.context.view_layer.objects.active = target
    target.select_set(True)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    target.select_set(False)
    bpy.data.objects.remove(cutter, do_unlink=True)
    return target


def cut_slots(target, centers, size, rot=None):
    """Cuts slots (vents, ports, serrations) at centers with the given box size.
    All cutters are merged first so the boolean runs once."""
    if not centers:
        return target
    bm = bmesh.new()
    for c in centers:
        tmp = bmesh.new()
        bmesh.ops.create_cube(tmp, size=1.0)
        bmesh.ops.scale(tmp, vec=size, verts=tmp.verts)
        if rot:
            bmesh.ops.rotate(tmp, verts=tmp.verts, cent=(0, 0, 0), matrix=rot)
        bmesh.ops.translate(tmp, verts=tmp.verts, vec=c)
        mesh = bpy.data.meshes.new("_tmp")
        tmp.to_mesh(mesh)
        tmp.free()
        bm.from_mesh(mesh)
        bpy.data.meshes.remove(mesh)
    cutter = mesh_obj("_cutter", bm)
    boolean(target, cutter)
    return target


def rail(name, length, y0, z, width=0.16, teeth_pitch=0.075):
    """Accessory rail: base + slotted cross teeth along +Y starting at y0 (top at z)."""
    base = box(name, (width, length, 0.04), (0, y0 + length / 2, z - 0.035), bev=0.006, seg=1)
    n = max(2, int(length / teeth_pitch) - 1)
    tooth = box(name + "_teeth", (width * 1.06, teeth_pitch * 0.5, 0.035), (0, y0 + teeth_pitch * 0.75, z - 0.0), bev=0.004, seg=1)
    array_copy(tooth, n, (0, teeth_pitch, 0))
    return join([base, tooth], name)


def join(objs, name):
    objs = [o for o in objs if o is not None]
    for o in objs:
        apply_all(o)
    ctx = bpy.context
    for o in ctx.selected_objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    ctx.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    obj = ctx.view_layer.objects.active
    obj.name = name
    obj.data.name = name
    obj.select_set(False)
    return obj


def mirror_x(obj):
    mod = obj.modifiers.new("MirrorX", "MIRROR")
    mod.use_axis[0] = True
    mod.use_clip = True
    return obj


def tri_count(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def extrude_front(name, pts, depth, y=0.0, bev=0.012, seg=2, angle=35):
    """Front-view outline pts [(x, z), ...] extruded along Y (depth) centred on y."""
    bm = bmesh.new()
    verts = [bm.verts.new((px, y - depth / 2, pz)) for (px, pz) in pts]
    face = bm.faces.new(verts)
    ext = bmesh.ops.extrude_face_region(bm, geom=[face])
    moved = [e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, verts=moved, vec=(0, depth, 0))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = mesh_obj(name, bm)
    if bev > 0:
        bevel(obj, bev, seg, angle)
    return smooth(obj)


def rounded_rect(w, h, r, segs=3, cx=0.0, cz=0.0):
    """Outline of a rounded rectangle as [(x, z)] for extrude_front / extrude."""
    pts = []
    corners = [(w / 2 - r, h / 2 - r, 0), (-w / 2 + r, h / 2 - r, 90), (-w / 2 + r, -h / 2 + r, 180), (w / 2 - r, -h / 2 + r, 270)]
    for (x, z, a0) in corners:
        for i in range(segs + 1):
            a = math.radians(a0 + 90 * i / segs)
            pts.append((cx + x + math.cos(a) * r, cz + z + math.sin(a) * r))
    return pts


def shell(name, size, center, cut_below=None, segs=24, rings=12):
    """Ellipsoid shell (helmets, pads); optionally trimmed below a Z height."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=0.5)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    bmesh.ops.translate(bm, verts=bm.verts, vec=center)
    obj = mesh_obj(name, bm)
    if cut_below is not None:
        cutter = box("_trim", (size[0] * 2, size[1] * 2, size[2]), (center[0], center[1], cut_below - size[2] / 2), bev=0)
        cutter.modifiers.clear()
        boolean(obj, cutter)
        mod = obj.modifiers.new("Solidify", "SOLIDIFY")
        mod.thickness = 0.04
        mod.offset = -1
    return smooth(obj)


def ring(name, sections_z, w, d, thickness, n=3.0, segs=24):
    """Band around a body (cummerbunds, belts, cuffs): hollow loft between z0..z1."""
    z0, z1 = sections_z
    outer = loft(name, [(z0, w, d, n), (z1, w, d, n)], segs, cap=False)
    mod = outer.modifiers.new("Solidify", "SOLIDIFY")
    mod.thickness = thickness
    mod.offset = 1
    return outer
