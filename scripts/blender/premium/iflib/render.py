"""Preview renders for review: a neutral studio (seamless backdrop, soft key,
fill and rim), auto-framed cameras for the front / side / rear / three-quarter
views, and a clay + wireframe pass that shows the real topology."""
import math
import os

import bpy
from mathutils import Vector

from . import geo, mats


def setup(scene, res=(1600, 1000), samples=96, exposure=0.0):
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_adaptive_sampling = True
    scene.cycles.adaptive_threshold = 0.03
    scene.cycles.use_denoising = True
    try:
        scene.cycles.denoiser = "OPENIMAGEDENOISE"
    except TypeError:
        pass
    scene.cycles.max_bounces = 8
    scene.cycles.transparent_max_bounces = 8
    scene.cycles.transmission_bounces = 8
    scene.render.resolution_x, scene.render.resolution_y = res
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.view_settings.exposure = exposure
    # review renders are high-quality JPEGs (about 4x smaller than PNG in git)
    scene.render.image_settings.file_format = "JPEG"
    scene.render.image_settings.color_mode = "RGB"
    scene.render.image_settings.quality = 93


def studio(scene, lo, hi, backdrop=(46, 48, 52), floor_z=None, key=1.0):
    """Lights + curved backdrop scaled to the subject bounds (lo, hi)."""
    coll = bpy.data.collections.new("Studio")
    scene.collection.children.link(coll)
    center = (lo + hi) / 2
    size = max((hi - lo).length, 0.5)
    world = bpy.data.worlds.new("StudioWorld")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = mats.rgba((120, 124, 132))
    bg.inputs[1].default_value = 0.35
    scene.world = world

    # seamless cyclorama: floor that curves up into a back wall (behind -Y... we
    # put it behind every view by making it a bowl: floor + large sphere-ish wall)
    fz = lo.z - 0.002 if floor_z is None else floor_z
    mb = geo.MB()
    R = size * 6
    prof = []
    steps = 10
    curve_r = size * 1.2
    prof.append((0.0, fz))
    prof.append((R - curve_r, fz))
    for i in range(1, steps + 1):
        a = (math.pi / 2) * i / steps
        prof.append((R - curve_r + math.sin(a) * curve_r, fz + curve_r - math.cos(a) * curve_r))
    prof.append((R, fz + R * 0.9))
    # lathe around Z: bowl
    mb.lathe([(r, z) for r, z in prof], 64, "Z", (center.x, center.y))
    bowl = mb.obj("Backdrop", coll=coll)
    bowl_mat = mats.build("M_Backdrop", {"color": backdrop, "rough": 0.55, "mottle": 0.03})
    bowl.data.materials.append(bowl_mat)
    for p in bowl.data.polygons:
        p.use_smooth = True
    bowl.visible_glossy = True

    def area(name, loc, energy, sz, color=(255, 250, 244)):
        light = bpy.data.lights.new(name, "AREA")
        light.shape = "RECTANGLE"
        light.size = sz[0]
        light.size_y = sz[1]
        light.energy = energy
        light.color = tuple(c / 255 for c in color)
        o = bpy.data.objects.new(name, light)
        o.location = loc
        d = center - Vector(loc)
        o.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
        coll.objects.link(o)
        return o

    d = size
    e = d * d
    area("Key", center + Vector((-1.6 * d, 1.4 * d, 1.9 * d)), 260 * e * key, (1.4 * d, 1.0 * d))
    area("Fill", center + Vector((1.8 * d, 1.2 * d, 0.6 * d)), 70 * e * key, (1.6 * d, 1.6 * d), (236, 242, 255))
    area("Rim", center + Vector((1.2 * d, -1.8 * d, 1.3 * d)), 220 * e * key, (0.6 * d, 1.4 * d), (255, 244, 230))
    area("Top", center + Vector((0.0, 0.0, 2.4 * d)), 90 * e * key, (1.6 * d, 1.6 * d))
    return coll


def camera(scene, name="Cam", lens=70):
    data = bpy.data.cameras.new(name)
    data.lens = lens
    data.sensor_width = 36
    data.clip_start = 0.01
    data.clip_end = 500
    cam = bpy.data.objects.new(name, data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    return cam


def frame(scene, cam, lo, hi, direction, up=(0, 0, 1), margin=0.08, target=None):
    """Points `cam` at the bounds from `direction` and backs off until every
    bounding-box corner fits inside the frame (with a margin)."""
    direction = Vector(direction).normalized()
    center = Vector(target) if target is not None else (lo + hi) / 2
    fwd = -direction
    right = fwd.cross(Vector(up)).normalized()
    upv = right.cross(fwd).normalized()
    rx, ry = scene.render.resolution_x, scene.render.resolution_y
    fov = 2 * math.atan(cam.data.sensor_width / (2 * cam.data.lens))
    if rx >= ry:
        tx = math.tan(fov / 2)
        ty = tx * ry / rx
    else:
        ty = math.tan(fov / 2)
        tx = ty * rx / ry
    tx *= 1 - margin
    ty *= 1 - margin
    dist = 0.0
    for i in range(8):
        c = Vector((hi.x if i & 1 else lo.x, hi.y if i & 2 else lo.y, hi.z if i & 4 else lo.z)) - center
        x, y, z = c.dot(right), c.dot(upv), c.dot(direction)
        dist = max(dist, z + abs(x) / tx, z + abs(y) / ty)
    cam.location = center + direction * dist
    cam.rotation_euler = fwd.to_track_quat("-Z", "Y").to_euler()
    return cam


def render(scene, path):
    path = os.path.splitext(path)[0] + (".jpg" if scene.render.image_settings.file_format == "JPEG" else ".png")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("[render]", os.path.relpath(path))


VIEWS = {
    # name: direction from subject to camera (Blender: +Y = front of subject)
    "front": (0.0, 1.0, 0.08),
    "side": (1.0, 0.0, 0.06),
    "rear": (0.0, -1.0, 0.08),
    "threequarter": (0.85, 0.75, 0.42),
    "threequarter_left": (-0.9, 0.7, 0.35),
}


def wire_overlay(objs, coll_name="Wire", thickness=0.0016):
    """Duplicates meshes with a Wireframe modifier (dark lines) for a clay + wire
    render. Returns the created objects so the caller can remove them."""
    coll = bpy.data.collections.new(coll_name)
    bpy.context.scene.collection.children.link(coll)
    wmat = mats.flat("M_Wire", (18, 20, 24), 0.8)
    made = []
    for o in objs:
        if o.type != "MESH":
            continue
        w = bpy.data.objects.new(o.name + "_wire", o.data)
        w.matrix_world = o.matrix_world.copy()
        coll.objects.link(w)
        mod = w.modifiers.new("Wire", "WIREFRAME")
        mod.thickness = thickness
        mod.use_replace = True
        mod.use_even_offset = True
        made.append(w)
    for w in made:
        # object-level material override so the shared mesh keeps its own
        for slot in w.material_slots:
            slot.link = "OBJECT"
            slot.material = wmat
    return made, coll


def clay(objs):
    """Swaps materials to clay via object-level slots; returns an undo list."""
    cmat = mats.flat("M_Clay", (170, 170, 168), 0.55)
    undo = []
    for o in objs:
        if o.type != "MESH":
            continue
        for slot in o.material_slots:
            undo.append((slot, slot.link, slot.material))
            slot.link = "OBJECT"
            slot.material = cmat
    return undo


def unclay(undo):
    for slot, link, mat in reversed(undo):
        slot.material = None
        slot.link = link
