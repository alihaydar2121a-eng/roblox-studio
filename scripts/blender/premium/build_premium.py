"""OPERATION IRONFRONT — premium asset build (Blender 4.2+, or the `bpy` pip module).

Builds the hand-modelled premium assets, bakes their Roblox texture atlases,
exports FBX + GLB + .blend and renders review images.

  python3 scripts/blender/premium/build_premium.py ir7 ashford
  blender --background --python scripts/blender/premium/build_premium.py -- ir7

Options: --no-render (skip previews), --quick (low samples / resolution).

Outputs (per asset) under assets/premium/<kind>/<Name>/:
  <Name>.blend  source scene (procedural source materials kept for re-baking)
  <Name>.fbx / <Name>.glb  Roblox-ready exports (Y up, -Z forward, 1 unit = 1 stud)
  textures/     1024² atlas: Color (with baked AO), Normal, Roughness, Metalness
  renders/      front, side, rear, three-quarter, hero close-ups, wireframe
  <Name>.json   manifest: objects, triangle counts, sizes, attachment points
"""
import json
import math
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Vector  # noqa: E402

from iflib import bake, geo, render  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
RENDER = "--no-render" not in ARGS
QUICK = "--quick" in ARGS
TARGETS = [a for a in ARGS if not a.startswith("--")] or ["ir7", "ashford"]


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    geo.STATS.clear()
    scene = bpy.context.scene
    scene.unit_settings.system = "NONE"
    return scene


def origin_marker(coll):
    mb = geo.MB()
    mb.box((0, 0, 0), (0.02, 0.02, 0.02))
    o = mb.obj("Origin", coll=coll, smooth=False)
    return o


def move_to(objs, coll):
    for o in objs:
        for c in list(o.users_collection):
            c.objects.unlink(o)
        coll.objects.link(o)


def rel(path):
    return os.path.relpath(path, ROOT).replace(os.sep, "/")


def save_blend(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=path, compress=True)
    try:
        bpy.ops.file.make_paths_relative()
        bpy.ops.wm.save_as_mainfile(filepath=path, compress=True)
    except RuntimeError:
        pass
    for f in (path + "1",):
        if os.path.exists(f):
            os.remove(f)


def add_view_cameras(scene, lo, hi, views, lens=85):
    cams = {}
    for name, d in views.items():
        cam = render.camera(scene, f"Cam_{name}", lens)
        render.frame(scene, cam, lo, hi, d, margin=0.05)
        cams[name] = cam
    return cams


def shoot(scene, cams, out_dir, prefix):
    for name, cam in cams.items():
        scene.camera = cam
        render.render(scene, os.path.join(out_dir, f"{prefix}_{name}.png"))


# ------------------------------------------------------------------ weapons

def ship_weapon(module, roblox_id, display):
    t0 = time.time()
    scene = reset()
    name = module.NAME
    out = os.path.join(ROOT, "assets", "premium", "weapons", name)
    coll = bpy.data.collections.new(f"{name}_Export")
    scene.collection.children.link(coll)
    objs, points = module.build()
    move_to(list(objs.values()), coll)
    marker = origin_marker(coll)
    atlas_objs = [o for n, o in objs.items() if "_glass" not in n]
    print(f"[{name}] modelled in {time.time() - t0:.1f}s")

    bake.uv_atlas(atlas_objs)
    overlap, usage = bake.uv_overlap(atlas_objs)
    print(f"[{name}] atlas: {usage * 100:.0f}% used, {overlap * 100:.2f}% overlap")
    size = 512 if QUICK else 1024
    files = bake.bake_atlas(atlas_objs, name, os.path.join(out, "textures"), size=size, samples=8 if QUICK else 16)
    print(f"[{name}] baked {sorted(files)} in {time.time() - t0:.1f}s")
    atlas = bake.atlas_material(f"{name}_Atlas", files)
    bake.assign(atlas_objs, atlas)
    bake.uv_simple([o for n, o in objs.items() if "_glass" in n])
    export_objs = list(objs.values()) + [marker]
    bake.export(export_objs, os.path.join(out, name))

    lo, hi = geo.bounds(list(objs.values()))
    size_rb = [round(hi.x - lo.x, 3), round(hi.z - lo.z, 3), round(hi.y - lo.y, 3)]
    manifest = {
        "name": display, "id": roblox_id, "model": name,
        "roblox_path": f"ReplicatedStorage.ImportedAssets.Weapons.{roblox_id}",
        "files": {"blend": rel(os.path.join(out, name + ".blend")), "fbx": rel(os.path.join(out, name + ".fbx")),
                  "glb": rel(os.path.join(out, name + ".glb"))},
        "textures": {k: rel(v) for k, v in files.items()},
        "objects": {n: geo.tri_count(o) for n, o in sorted(objs.items())},
        "triangles": sum(geo.tri_count(o) for o in objs.values()),
        "size_studs_xyz": size_rb,
        "points_roblox": points,
        "atlas": {"size": size, "usage": round(usage, 3), "overlap": round(overlap, 4)},
        "units": "1 unit = 1 stud", "axes": "Y up, -Z forward (Roblox); pivot = right-hand grip (object 'Origin')",
    }
    with open(os.path.join(out, name + ".json"), "w") as f:
        json.dump(manifest, f, indent=2)
    print(f"[{name}] {manifest['triangles']} tris, size {size_rb} studs")

    if RENDER:
        render_weapon(scene, module, objs, lo, hi, out, name)
    save_blend(os.path.join(out, name + ".blend"))
    print(f"[{name}] done in {time.time() - t0:.1f}s")
    return manifest


def render_weapon(scene, module, objs, lo, hi, out, name):
    rdir = os.path.join(out, "renders")
    res = (960, 600) if QUICK else (1600, 1000)
    render.setup(scene, res, 24 if QUICK else 64)
    render.studio(scene, lo, hi)
    views = {k: render.VIEWS[k] for k in ("front", "side", "rear", "threequarter", "threequarter_left")}
    cams = add_view_cameras(scene, lo, hi, views)
    shoot(scene, cams, rdir, name)
    # hero close-up on the receiver/optic
    hero = render.camera(scene, "Cam_hero", 60)
    c, half = Vector((0.06, 0.3, 0.38)), Vector((0.2, 0.62, 0.42))
    render.frame(scene, hero, c - half, c + half, (0.95, 0.42, 0.34), margin=0.0)
    scene.camera = hero
    render.render(scene, os.path.join(rdir, f"{name}_hero.png"))
    # sight line check: camera at the Sight point looking down the bore
    sight = render.camera(scene, "Cam_sightline", 50)
    sp = module.build_points()["Sight"] if hasattr(module, "build_points") else None
    sight.location = (0.0, -0.30, module.SIGHT_Z) if sp is None else (sp[0], -sp[2], sp[1])
    sight.rotation_euler = Vector((0, 1, 0)).to_track_quat("-Z", "Y").to_euler()
    scene.camera = sight
    render.render(scene, os.path.join(rdir, f"{name}_sightline.png"))
    # clay + wireframe topology pass
    ms = list(objs.values())
    undo = render.clay(ms)
    wires, wcoll = render.wire_overlay(ms, thickness=0.0012)
    scene.camera = cams["side"]
    render.render(scene, os.path.join(rdir, f"{name}_wireframe_side.png"))
    scene.camera = cams["threequarter"]
    render.render(scene, os.path.join(rdir, f"{name}_wireframe_threequarter.png"))
    for w in wires:
        bpy.data.objects.remove(w)
    bpy.data.collections.remove(wcoll)
    render.unclay(undo)
    scene.camera = cams["threequarter"]


# ------------------------------------------------------------------ main

if __name__ == "__main__":
    results = {}
    for target in TARGETS:
        if target == "ir7":
            from assets import ir7
            results["ir7"] = ship_weapon(ir7, "CB", "IR-7 Carbine")
        elif target == "ashford":
            from assets import ashford
            results["ashford"] = ashford.ship(sys.modules[__name__])
        else:
            print("unknown target", target)
    print("built:", ", ".join(results))
    sys.stdout.flush()
    # os._exit skips interpreter teardown, which can crash the pip `bpy` module.
    os._exit(0)
