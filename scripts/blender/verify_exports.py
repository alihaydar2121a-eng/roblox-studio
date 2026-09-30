"""Re-imports every exported FBX/GLB and checks size and axes against the manifest.
Roblox axes: barrel along -Z, up +Y. The build writes Roblox (x, y, z) as Blender
(x, -z, y) and the exporters convert that to Y-up/-Z-forward files; importing
converts back, so a correct weapon has its muzzle toward Blender +Y.
Usage: python3 scripts/blender/verify_exports.py   (or blender --background --python ...)"""
import json
import os
import sys

import bpy
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
manifest = json.load(open(os.path.join(ROOT, "assets", "export", "manifest.json")))
failures = 0


def measure():
    lo, hi = Vector((1e9,) * 3), Vector((-1e9,) * 3)
    muzzle_y = None
    for o in bpy.context.scene.objects:
        if o.type != "MESH" or o.name.startswith("Origin"):
            continue
        for v in o.data.vertices:
            w = o.matrix_world @ v.co
            lo = Vector(tuple(min(lo[i], w[i]) for i in range(3)))
            hi = Vector(tuple(max(hi[i], w[i]) for i in range(3)))
    return lo, hi


for kind in ("weapons", "gear"):
    for name, entry in manifest[kind].items():
        for ext in (".fbx", ".glb"):
            bpy.ops.wm.read_factory_settings(use_empty=True)
            path = os.path.join(ROOT, entry["file"].replace(".fbx", ext))
            if ext == ".fbx":
                bpy.ops.import_scene.fbx(filepath=path)
            else:
                bpy.ops.import_scene.gltf(filepath=path)
            lo, hi = measure()
            size = hi - lo
            names = sorted(o.name.split(".")[0] for o in bpy.context.scene.objects if o.type == "MESH")
            ok = set(entry["objects"]) <= set(names)
            if kind == "weapons":
                expected = entry["size_studs"]  # roblox x, y, z
                got = [size.x, size.z, size.y]
                ok = ok and all(abs(a - b) < 0.05 for a, b in zip(expected, got))
                # Muzzle (roblox -Z) is the far end from the grip: Blender +Y after import.
                ok = ok and (hi.y > -lo.y)
            status = "ok" if ok else "MISMATCH"
            if not ok:
                failures += 1
            print(f"{status:8} {name}{ext}  size(x,y,z roblox)=({size.x:.2f}, {size.z:.2f}, {size.y:.2f})")
print("failures:", failures)
sys.stdout.flush()
# os._exit skips interpreter teardown, which crashes in the pip `bpy` module.
os._exit(1 if failures else 0)
