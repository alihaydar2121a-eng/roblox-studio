"""
OPERATION IRONFRONT — Blender asset build (Blender 4.2+; also runs with the `bpy` pip module).

Builds original low-poly weapon and soldier-gear meshes from the shared Luau specs
(assets/specs/asset_specs.json, written by `lune run tests/assets.luau`), then:
  * assets/export/weapons/<Id>.fbx|.glb       five weapons, pivot = right-hand grip
  * assets/export/gear/<Team>_<Piece>.fbx|.glb faction kits, pivot = R6 limb centre
  * assets/previews/*.png                      Cycles renders for review
  * assets/export/manifest.json                triangle counts, objects, sizes

Conventions (see docs/ASSET_PIPELINE.md):
  - 1 Blender unit = 1 stud. Roblox (x, y, z) is written as Blender (x, -z, y);
    FBX/glTF exporters convert back so the files carry Roblox axes (Y up, -Z forward).
  - One mesh object per palette colour named "<Model>_<colourKey>", so Roblox
    can recolour MeshParts by name; magazine parts end in "_mag", optics in
    "_optic", optional variants in "_v_<variant>". A tiny "Origin" object marks
    the pivot and is removed on import.

Usage:
  blender --background --python scripts/blender/legacy_build_assets.py            # Blender app
  python3 scripts/blender/legacy_build_assets.py                                   # pip `bpy`
  add `-- --no-render` (Blender) or `--no-render` (python) to skip previews.
"""
import json
import math
import os
import sys

import bpy  # must precede bmesh/mathutils when running as the pip module
import bmesh
from mathutils import Euler, Matrix, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SPECS = os.path.join(ROOT, "assets", "specs", "asset_specs.json")
OUT = os.path.join(ROOT, "assets", "export")
PREVIEWS = os.path.join(ROOT, "assets", "previews")
RENDER = "--no-render" not in sys.argv

# Roblox → Blender basis change: (x, y, z) → (x, -z, y)
C = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
C_INV = C.inverted()


def srgb_to_linear(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "NONE"
    return scene


MATERIAL_TRAITS = {
    "Metal": (0.9, 0.38), "Glass": (0.0, 0.05), "Rubber": (0.0, 0.85), "Wood": (0.0, 0.6),
    "Fabric": (0.0, 0.92), "Leather": (0.0, 0.7), "SmoothPlastic": (0.0, 0.5),
}


def make_material(name, rgb, kind):
    mat = bpy.data.materials.get(name)
    if mat:
        return mat
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    metallic, rough = MATERIAL_TRAITS.get(kind, (0.0, 0.55))
    bsdf.inputs["Base Color"].default_value = (srgb_to_linear(rgb[0]), srgb_to_linear(rgb[1]), srgb_to_linear(rgb[2]), 1)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = rough
    if kind == "Glass":
        bsdf.inputs["Alpha"].default_value = 0.55
        mat.blend_method = "BLEND" if hasattr(mat, "blend_method") else None
    return mat


def prim_matrix(prim, mirror):
    x, y, z = prim["p"]
    r = prim.get("r") or [0, 0, 0]
    rx, ry, rz = (math.radians(a) for a in r)
    if mirror:
        x, ry, rz = -x, -ry, -rz
    # Roblox CFrame.fromEulerAnglesXYZ(rx, ry, rz) = Rx * Ry * Rz
    rot = Matrix.Rotation(rx, 4, "X") @ Matrix.Rotation(ry, 4, "Y") @ Matrix.Rotation(rz, 4, "Z")
    return Matrix.Translation((x, y, z)) @ rot


def add_prim(bm, prim, mirror):
    """Adds one primitive to bmesh `bm` in Roblox space (converted to Blender at the end)."""
    kind = prim["k"]
    sx, sy, sz = prim["s"]
    m = prim_matrix(prim, mirror)
    verts = []
    faces = []
    if kind == "box":
        for i in (-1, 1):
            for j in (-1, 1):
                for k in (-1, 1):
                    verts.append((i * sx / 2, j * sy / 2, k * sz / 2))
        faces = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    elif kind == "wedge":  # slope rises toward +Z (spec convention)
        hx, hy, hz = sx / 2, sy / 2, sz / 2
        verts = [(-hx, -hy, -hz), (hx, -hy, -hz), (hx, -hy, hz), (-hx, -hy, hz), (-hx, hy, hz), (hx, hy, hz)]
        faces = [(0, 1, 2, 3), (3, 2, 5, 4), (0, 4, 5, 1), (0, 3, 4), (1, 5, 2)]
    elif kind == "cyl":  # axis along Z, diameter sx, length sz
        n = 12
        r = sx / 2
        for end in (-1, 1):
            for i in range(n):
                a = 2 * math.pi * i / n
                verts.append((r * math.cos(a), r * math.sin(a), end * sz / 2))
        faces.append(tuple(range(n - 1, -1, -1)))
        faces.append(tuple(range(n, 2 * n)))
        for i in range(n):
            j = (i + 1) % n
            faces.append((i, j, n + j, n + i))
    elif kind == "ell":
        rings, segs = 7, 12
        verts.append((0, -sy / 2, 0))
        for ri in range(1, rings):
            phi = math.pi * ri / rings - math.pi / 2
            for si in range(segs):
                th = 2 * math.pi * si / segs
                verts.append((math.cos(phi) * math.cos(th) * sx / 2, math.sin(phi) * sy / 2, math.cos(phi) * math.sin(th) * sz / 2))
        verts.append((0, sy / 2, 0))
        top = len(verts) - 1
        for si in range(segs):
            faces.append((0, 1 + (si + 1) % segs, 1 + si))
        for ri in range(rings - 2):
            base = 1 + ri * segs
            for si in range(segs):
                a, b = base + si, base + (si + 1) % segs
                faces.append((a, b, b + segs, a + segs))
        base = 1 + (rings - 2) * segs
        for si in range(segs):
            faces.append((base + si, base + (si + 1) % segs, top))
    bverts = [bm.verts.new((C @ m @ Vector((*v, 1.0))).xyz) for v in verts]
    for f in faces:
        f = tuple(reversed(f)) if mirror else f
        try:
            bm.faces.new([bverts[i] for i in f])
        except ValueError:
            pass


def build_object(name, prims, mat, mirror, bevel):
    bm = bmesh.new()
    for prim in prims:
        add_prim(bm, prim, mirror)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(mat)
    for poly in mesh.polygons:
        poly.use_smooth = True
    if bevel > 0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        mod.limit_method = "ANGLE"
        mod.angle_limit = math.radians(40)
        mod.harden_normals = True
        wn = obj.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL")
        wn.keep_sharp = True
    return obj


def apply_modifiers(obj):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    for mod in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.select_set(False)


def tri_count(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def origin_marker(name):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=0.02)
    mesh = bpy.data.meshes.new(name + "_OriginMesh")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("Origin", mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def build_model(model_name, prims, palette, materials, mirror=False, bevel=0.012):
    """Groups prims by (colour, group, variant) into named objects."""
    groups = {}
    for prim in prims:
        key = prim["c"]
        suffix = ""
        if prim.get("g"):
            suffix += "_" + prim["g"]
        if prim.get("v"):
            suffix += "_v_" + prim["v"]
        groups.setdefault((key, suffix), []).append(prim)
    objects = []
    for (key, suffix), items in sorted(groups.items()):
        rgb = palette.get(key, [128, 128, 128])
        kind = materials.get(key, "SmoothPlastic")
        mat = make_material(f"{model_name}_{key}", rgb, kind)
        obj = build_object(f"{model_name}_{key}{suffix}", items, mat, mirror, bevel)
        apply_modifiers(obj)
        objects.append(obj)
    objects.append(origin_marker(model_name))
    return objects


def export(objects, path_base):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects:
        o.select_set(True)
    os.makedirs(os.path.dirname(path_base), exist_ok=True)
    bpy.ops.export_scene.fbx(
        filepath=path_base + ".fbx", use_selection=True, axis_forward="-Z", axis_up="Y",
        apply_unit_scale=True, apply_scale_options="FBX_SCALE_NONE", mesh_smooth_type="FACE",
        use_mesh_modifiers=True, add_leaf_bones=False, bake_space_transform=True, object_types={"MESH"},
    )
    bpy.ops.export_scene.gltf(filepath=path_base + ".glb", use_selection=True, export_format="GLB", export_yup=True)
    bpy.ops.object.select_all(action="DESELECT")


def bounds(objects):
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for o in objects:
        for v in o.data.vertices:
            w = o.matrix_world @ v.co
            lo = Vector((min(lo[i], w[i]) for i in range(3)))
            hi = Vector((max(hi[i], w[i]) for i in range(3)))
    # back to Roblox axes: blender (x, y, z) = roblox (x, -z, y)
    size = hi - lo
    return [round(size.x, 3), round(size.z, 3), round(size.y, 3)]


# --------------------------------------------------------------- R6 preview dummy

R6_PARTS = {
    "Head": ((0, 1.5, 0), (1.2, 1.2, 1.2)), "Torso": ((0, 0, 0), (2, 2, 1)),
    "Right Arm": ((1.5, 0, 0), (1, 2, 1)), "Left Arm": ((-1.5, 0, 0), (1, 2, 1)),
    "Right Leg": ((0.5, -2, 0), (1, 2, 1)), "Left Leg": ((-0.5, -2, 0), (1, 2, 1)),
}


def build_soldier(team, gear, origin, pose_arm=True):
    """Assembles an R6 dummy with the faction kit (preview only)."""
    uni = gear["Uniform"]
    objs = []
    skin = make_material("Skin", [204, 170, 140], "SmoothPlastic")
    colors = {"Torso": uni["Torso"], "Right Arm": uni["Arms"], "Left Arm": uni["Arms"], "Right Leg": uni["Legs"], "Left Leg": uni["Legs"]}
    limb_matrix = {}
    for name, (pos, size) in R6_PARTS.items():
        m = Matrix.Translation(Vector(pos) + Vector(origin))
        if pose_arm and name == "Right Arm":
            m = Matrix.Translation(Vector((1.0, 0.5, 0)) + Vector(origin)) @ Matrix.Rotation(math.radians(80), 4, "X") @ Matrix.Rotation(math.radians(-12), 4, "Y") @ Matrix.Translation((0.5, -0.5, 0))
        if pose_arm and name == "Left Arm":
            m = Matrix.Translation(Vector((-1.0, 0.5, 0)) + Vector(origin)) @ Matrix.Rotation(math.radians(70), 4, "X") @ Matrix.Rotation(math.radians(35), 4, "Y") @ Matrix.Translation((-0.5, -0.5, 0))
        limb_matrix[name] = m
        prim = {"k": "ell" if name == "Head" else "box", "p": [0, 0, 0], "s": list(size), "c": "x"}
        mat = skin if name == "Head" else make_material(f"{team}_{name}_uniform", colors[name], "Fabric")
        bm = bmesh.new()
        add_prim(bm, prim, False)
        mesh = bpy.data.meshes.new(f"{team}_{name}")
        bm.to_mesh(mesh)
        bm.free()
        obj = bpy.data.objects.new(f"{team}_{name}", mesh)
        bpy.context.scene.collection.objects.link(obj)
        obj.data.materials.append(mat)
        obj.matrix_world = C @ m @ C_INV
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = 0.04
        mod.segments = 2
        objs.append(obj)
    pieces = [("Head", "Head", False), ("Torso", "Torso", False), ("Right Arm", "Arm", False), ("Left Arm", "Arm", True),
              ("Right Leg", "Leg", False), ("Left Leg", "Leg", True)]
    variants = {"goggles", "cover", "headset", "bedroll", "visor", "mask", "antenna"}
    for limb, piece, mirror in pieces:
        prims = [p for p in gear[piece] if not p.get("v") or p["v"] in variants]
        for obj in build_model(f"{team}_{limb.replace(' ', '')}", prims, gear["Palette"], MATS_GEAR, mirror=mirror, bevel=0.02):
            if obj.name.startswith("Origin"):
                bpy.data.objects.remove(obj)
                continue
            obj.matrix_world = C @ limb_matrix[limb] @ C_INV @ obj.matrix_world
            objs.append(obj)
    return objs, limb_matrix


def setup_render(scene, res=(900, 600), samples=48):
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y = res
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.55, 0.62, 0.7, 1)
    bg.inputs[1].default_value = 0.7
    scene.world = world
    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy = 3.2
    sun_obj = bpy.data.objects.new("Sun", sun)
    sun_obj.rotation_euler = Euler((math.radians(50), math.radians(10), math.radians(35)))
    scene.collection.objects.link(sun_obj)
    fill = bpy.data.lights.new("Fill", "AREA")
    fill.energy = 250
    fill.size = 6
    fill_obj = bpy.data.objects.new("Fill", fill)
    fill_obj.location = (-5, -6, 4)
    fill_obj.rotation_euler = Euler((math.radians(60), 0, math.radians(-40)))
    scene.collection.objects.link(fill_obj)


def ground(scene, size=40, z=0.0):
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=size)
    mesh = bpy.data.meshes.new("Ground")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("Ground", mesh)
    obj.location = (0, 0, z)
    obj.data.materials.append(make_material("GroundMat", [96, 110, 80], "Fabric"))
    scene.collection.objects.link(obj)


def camera(scene, location, target, lens=50):
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.lens = lens
    cam = bpy.data.objects.new("Cam", cam_data)
    cam.location = location
    direction = Vector(target) - Vector(location)
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(cam)
    scene.camera = cam


def render(scene, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


# --------------------------------------------------------------- main

with open(SPECS) as f:
    SPEC = json.load(f)
MATS_WEAPON = SPEC["weaponMaterials"]
MATS_GEAR = SPEC["gearMaterials"]
manifest = {"weapons": {}, "gear": {}, "units": "1 unit = 1 stud", "axes": "Y up, -Z forward (Roblox)"}

for wid, w in SPEC["weapons"].items():
    reset_scene()
    objs = build_model(wid, w["Parts"], w["Palette"], MATS_WEAPON)
    export(objs, os.path.join(OUT, "weapons", wid))
    manifest["weapons"][wid] = {
        "name": w["Name"], "file": f"assets/export/weapons/{wid}.fbx", "objects": sorted(o.name for o in objs),
        "triangles": sum(tri_count(o) for o in objs if o.name != "Origin"), "size_studs": bounds([o for o in objs if o.name != "Origin"]),
        "roblox_path": f"ReplicatedStorage.ImportedAssets.Weapons.{wid}",
    }
    print(f"[weapons] {wid}: {manifest['weapons'][wid]['triangles']} tris, size {manifest['weapons'][wid]['size_studs']}")

for team, gear in SPEC["gear"].items():
    for piece, mirror, out_name in (("Head", False, "Head"), ("Torso", False, "Torso"), ("Arm", False, "Arm"), ("Arm", True, "Arm_L"), ("Leg", False, "Leg"), ("Leg", True, "Leg_L")):
        reset_scene()
        objs = build_model(f"{team}_{out_name}", gear[piece], gear["Palette"], MATS_GEAR, mirror=mirror, bevel=0.02)
        export(objs, os.path.join(OUT, "gear", f"{team}_{out_name}"))
        manifest["gear"][f"{team}_{out_name}"] = {
            "file": f"assets/export/gear/{team}_{out_name}.fbx", "objects": sorted(o.name for o in objs),
            "triangles": sum(tri_count(o) for o in objs if o.name != "Origin"),
            "roblox_path": f"ReplicatedStorage.ImportedAssets.Gear.{team}.{out_name}",
        }
        print(f"[gear] {team}_{out_name}: {manifest['gear'][f'{team}_{out_name}']['triangles']} tris")

os.makedirs(OUT, exist_ok=True)
with open(os.path.join(OUT, "manifest.json"), "w") as f:
    json.dump(manifest, f, indent=2)

if RENDER:
    # Weapon line-up: right-side profiles stacked top to bottom.
    scene = reset_scene()
    setup_render(scene, (1000, 1400), 48)
    offset = 0.0
    for wid, w in SPEC["weapons"].items():
        for o in build_model(wid, w["Parts"], w["Palette"], MATS_WEAPON):
            o.location.z += offset
        offset -= 1.7
    ground(scene, 40, -9.0)
    camera(scene, (10.5, 0.9, -3.3), (0, 0.9, -3.3), 40)
    render(scene, os.path.join(PREVIEWS, "weapons_lineup.png"))
    camera(scene, (5.5, -3.5, 1.2), (0, 0.4, -0.2), 55)
    render(scene, os.path.join(PREVIEWS, "rifle_closeup.png"))

    # Soldiers, one per faction, with rifles in hand
    scene = reset_scene()
    setup_render(scene, (1200, 800), 64)
    for i, (team, gear) in enumerate(SPEC["gear"].items()):
        ox = -2.2 if i == 0 else 2.2
        objs, limbs = build_soldier(team, gear, (ox, 3.0, 0))
        wid = "AR" if team == "Alpha" else "CB"
        weapon = SPEC["weapons"][wid]
        hand = limbs["Right Arm"] @ Matrix.Translation((0, -1, 0))
        grip = Matrix.Translation(hand.to_translation()) @ Matrix.Rotation(math.radians(-6), 4, "X")
        for o in build_model(f"{team}_{wid}", weapon["Parts"], weapon["Palette"], MATS_WEAPON):
            if o.name.startswith("Origin"):
                continue
            o.matrix_world = C @ grip @ C_INV @ o.matrix_world
    ground(scene, 30, 0)
    camera(scene, (6.0, 13.0, 5.8), (0, 0, 2.6), 45)
    render(scene, os.path.join(PREVIEWS, "soldiers_front.png"))
    camera(scene, (-7.5, -11.0, 5.5), (0, 0, 2.6), 45)
    render(scene, os.path.join(PREVIEWS, "soldiers_back.png"))
    camera(scene, (2.2, 6.5, 5.2), (0, 0, 4.2), 50)
    render(scene, os.path.join(PREVIEWS, "soldiers_closeup.png"))

print("done")
sys.stdout.flush()
# os._exit skips interpreter teardown, which crashes in the pip `bpy` module.
os._exit(0)
