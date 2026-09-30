"""Re-imports every premium FBX/GLB and checks it against its manifest:
object names, size and axes (Roblox: Y up, -Z forward), UVs, embedded textures,
and that the Origin marker sits at the pivot.

  python3 scripts/blender/premium/verify_premium.py
  blender --background --python scripts/blender/premium/verify_premium.py
"""
import glob
import json
import os
import sys

import bpy
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
failures = []


def fail(msg):
    failures.append(msg)
    print("  FAIL", msg)


def load(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if path.endswith(".fbx"):
        bpy.ops.import_scene.fbx(filepath=path)
    else:
        bpy.ops.import_scene.gltf(filepath=path)
    bpy.context.view_layer.update()
    return [o for o in bpy.context.scene.objects if o.type == "MESH"]


def measure(objs):
    lo, hi = Vector((1e9,) * 3), Vector((-1e9,) * 3)
    for o in objs:
        if o.name.split(".")[0] == "Origin":
            continue
        for v in o.data.vertices:
            w = o.matrix_world @ v.co
            for i in range(3):
                lo[i] = min(lo[i], w[i])
                hi[i] = max(hi[i], w[i])
    return lo, hi


def check(path, expected_objects, size_xyz, forward_check=None):
    objs = load(path)
    names = {o.name.split(".")[0] for o in objs}
    missing = set(expected_objects) - names
    if missing:
        fail(f"{os.path.basename(path)} missing objects {sorted(missing)}")
    if "Origin" not in names:
        fail(f"{os.path.basename(path)} has no Origin marker")
    else:
        origin = next(o for o in objs if o.name.split(".")[0] == "Origin")
        c = origin.matrix_world @ (sum((v.co for v in origin.data.vertices), Vector()) / len(origin.data.vertices))
        if c.length > 1e-3:
            fail(f"{os.path.basename(path)} Origin not at the pivot ({c})")
    lo, hi = measure(objs)
    size = hi - lo
    # importing converts back to Blender axes, where Roblox (x, y, z) = Blender (x, -z, y)
    got = [size.x, size.z, size.y]
    for i, axis in enumerate("xyz"):
        if abs(got[i] - size_xyz[i]) > 0.02:
            fail(f"{os.path.basename(path)} size {axis} {got[i]:.3f} != {size_xyz[i]:.3f}")
    if forward_check:
        forward_check(lo, hi, path)
    for o in objs:
        if o.name.split(".")[0] == "Origin":
            continue
        if not o.data.uv_layers:
            fail(f"{os.path.basename(path)} {o.name} has no UVs")
    if path.endswith(".glb"):
        imgs = [i for i in bpy.data.images if i.size[0] > 0]
        if not imgs:
            fail(f"{os.path.basename(path)} has no embedded textures")
    tris = sum(len(p.vertices) - 2 for o in objs for p in o.data.polygons)
    print(f"  checked {os.path.relpath(path, ROOT)}: {len(objs)} meshes, {tris} tris, size {[round(g, 3) for g in got]}")
    return tris


def weapon_forward(lo, hi, path):
    # Roblox -Z forward becomes Blender +Y after import: the muzzle end is the far +Y side.
    if not hi.y > -lo.y:
        fail(f"{os.path.basename(path)} muzzle is not toward Roblox -Z")


for manifest_path in sorted(glob.glob(os.path.join(ROOT, "assets", "premium", "weapons", "*", "*.json"))):
    m = json.load(open(manifest_path))
    print(f"== {m['name']} ({m['model']})")
    for ext in ("fbx", "glb"):
        check(os.path.join(ROOT, m["files"][ext]), list(m["objects"]) + ["Origin"], m["size_studs_xyz"], weapon_forward)

for manifest_path in sorted(glob.glob(os.path.join(ROOT, "assets", "premium", "characters", "*", "*.json"))):
    m = json.load(open(manifest_path))
    print(f"== {m['name']}")
    for piece, info in m["pieces"].items():
        if "size_studs_xyz" not in info:
            fail(f"{piece}: manifest has no size (rebuild the kit)")
            continue
        for ext in ("fbx", "glb"):
            check(os.path.join(ROOT, info[ext]), list(info["objects"]) + ["Origin"], info["size_studs_xyz"])

print("premium failures:", len(failures))
sys.stdout.flush()
os._exit(1 if failures else 0)
