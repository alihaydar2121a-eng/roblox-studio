"""OPERATION IRONFRONT – premium asset build (Blender 4.2).

Builds every weapon and faction gear piece from scripts/blender/ironfront,
bakes one texture atlas per asset (Color / Roughness / Metalness PNG),
joins the parts into import-friendly objects and exports:

  * assets/export/weapons/<Id>.fbx|.glb   (+ <Id>_{Color,Roughness,Metalness}.png)
  * assets/export/gear/<Team>_<Piece>.fbx|.glb
  * assets/export/manifest.json

Object naming (read by the Roblox runtime):
  <Asset>_body, <Asset>_mag, <Asset>_optic, <Asset>_v_<variant>, and an
  "Origin" marker (weapon grip / R6 limb centre) that becomes the pivot.

Usage:
  python3 scripts/blender/build_assets.py [--only AR,Alpha_Torso] [--size 1024]
  blender --background --python scripts/blender/build_assets.py -- [...]
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402
import bmesh  # noqa: E402
from ironfront import geo, mats, soldiers, studio, weapons  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "export")
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
ONLY = set(argv[argv.index("--only") + 1].split(",")) if "--only" in argv else None
SIZE = int(argv[argv.index("--size") + 1]) if "--size" in argv else 1024

NAMES = {"AR": "KR-20 Warden", "CB": "KC-9 Talon", "LMG": "RG-7 Bulwark", "SR": "LX-3 Longreach", "P11": "P-11 Sidearm"}


def origin_marker():
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=0.02)
    mesh = bpy.data.meshes.new("OriginMesh")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("Origin", mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def key_of(o):
    if o.get("variant"):
        return "v_" + o["variant"]
    return o.get("group") or "body"


def join_groups(objs, asset):
    groups = {}
    for o in objs:
        groups.setdefault(key_of(o), []).append(o)
    out = []
    for key, items in sorted(groups.items()):
        bpy.ops.object.select_all(action="DESELECT")
        for o in items:
            o.select_set(True)
        bpy.context.view_layer.objects.active = items[0]
        if len(items) > 1:
            bpy.ops.object.join()
        obj = bpy.context.view_layer.objects.active
        obj.name = obj.data.name = f"{asset}_{key}"
        out.append(obj)
    return out


def export(objs, base):
    os.makedirs(os.path.dirname(base), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.fbx(
        filepath=base + ".fbx", use_selection=True, axis_forward="-Z", axis_up="Y",
        apply_unit_scale=True, apply_scale_options="FBX_SCALE_NONE", mesh_smooth_type="FACE",
        use_mesh_modifiers=True, add_leaf_bones=False, bake_space_transform=True, object_types={"MESH"},
        path_mode="COPY", embed_textures=True,
    )
    bpy.ops.export_scene.gltf(filepath=base + ".glb", use_selection=True, export_format="GLB", export_yup=True)


def size_studs(objs):
    xs, ys, zs = [], [], []
    for o in objs:
        for v in o.data.vertices:
            w = o.matrix_world @ v.co
            xs.append(w.x); ys.append(w.y); zs.append(w.z)
    return [round(max(xs) - min(xs), 3), round(max(zs) - min(zs), 3), round(max(ys) - min(ys), 3)]


def build_asset(asset, objs, folder, extra):
    for o in objs:
        geo.apply_all(o)
    tris = sum(geo.tri_count(o) for o in objs)
    tex_dir = os.path.join(OUT, folder)
    paths = mats.bake(objs, asset, tex_dir, size=SIZE, samples=8)
    joined = join_groups(objs, asset)
    size = size_studs(joined)
    export(joined + [origin_marker()], os.path.join(tex_dir, asset))
    entry = {
        "file": f"assets/export/{folder}/{asset}.fbx",
        "objects": sorted([o.name for o in joined] + ["Origin"]),
        "textures": {k: os.path.relpath(p, ROOT) for k, p in paths.items()},
        "triangles": tris, "size_studs": size,
    }
    entry.update(extra)
    print(f"[{folder}] {asset}: {tris} tris, size {size}", flush=True)
    return entry


manifest_path = os.path.join(OUT, "manifest.json")
manifest = {"weapons": {}, "gear": {}}
if ONLY and os.path.exists(manifest_path):
    manifest = json.load(open(manifest_path))
manifest.update({"units": "1 unit = 1 stud", "axes": "Y up, -Z forward (Roblox)", "texture_size": SIZE})

for wid, builder in weapons.BUILDERS.items():
    if ONLY and wid not in ONLY:
        continue
    studio.reset()
    manifest["weapons"][wid] = build_asset(wid, builder(), "weapons", {
        "name": NAMES[wid], "roblox_path": f"ReplicatedStorage.ImportedAssets.Weapons.{wid}"})

for team in ("Alpha", "Bravo"):
    for piece in soldiers.PIECES:
        asset = f"{team}_{piece}"
        if ONLY and asset not in ONLY:
            continue
        studio.reset()
        manifest["gear"][asset] = build_asset(asset, soldiers.build(team, piece), "gear", {
            "roblox_path": f"ReplicatedStorage.ImportedAssets.Gear.{team}.{piece}"})

os.makedirs(OUT, exist_ok=True)
with open(manifest_path, "w") as f:
    json.dump(manifest, f, indent=2)
print("manifest written", flush=True)
sys.stdout.flush()
os._exit(0)
