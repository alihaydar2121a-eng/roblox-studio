"""Renders assets/previews/*.png from the *exported* GLBs (baked atlases), so the
previews show exactly what ships, not the procedural source scene.
Usage: python3 scripts/blender/render_previews.py"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402
from mathutils import Matrix  # noqa: E402
from ironfront import geo, soldiers, studio  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
EXPORT = os.path.join(ROOT, "assets", "export")
PREV = os.path.join(ROOT, "assets", "previews")
os.makedirs(PREV, exist_ok=True)
# One loadout per faction for the line-up (variants are per-player in game).
LOADOUT = {"Alpha": {"goggles", "headset", "bedroll"}, "Bravo": {"visor", "antenna"}}


def load(path, offset=(0, 0, 0), variants=None, rot=None):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    objs = [o for o in bpy.data.objects if o not in before]
    keep = []
    for o in objs:
        name = o.name.split(".")[0]
        variant = name.split("_v_")[1] if "_v_" in name else None
        if o.type != "MESH" or name.startswith("Origin") or (variant and variant not in (variants or set())):
            bpy.data.objects.remove(o)
            continue
        m = Matrix.Translation(offset)
        if rot:
            m = m @ rot
        o.matrix_world = m @ o.matrix_world
        keep.append(o)
    return keep


def soldier(team, ox, oy=0.0):
    for piece in soldiers.PIECES:
        r = soldiers.REST[piece]
        load(os.path.join(EXPORT, "gear", f"{team}_{piece}.glb"), (r[0] + ox, r[1] + oy, r[2] + 3.0), LOADOUT[team])
    head = geo.loft(f"{team}_headPreview", [(-0.6, 0.9, 0.9, 2.2), (-0.3, 1.18, 1.14, 2.4), (0.3, 1.18, 1.14, 2.4), (0.6, 0.9, 0.9, 2.2)], 20)
    head.data.transform(Matrix.Translation((ox, oy, 4.5)))
    geo.set_material(head, soldiers.palette(team)["skin"])


# Soldiers
scene = studio.reset()
soldier("Bravo", -1.8)
soldier("Alpha", 1.8)
studio.setup(scene, (1400, 1000), 48, floor_z=0.0)
studio.camera(scene, (2.5, 11.5, 5.0), (0, 0, 3.1), 50)
studio.render(scene, os.path.join(PREV, "soldiers_front.png"))
studio.camera(scene, (-3.0, -11.5, 5.0), (0, 0, 3.1), 50)
studio.render(scene, os.path.join(PREV, "soldiers_back.png"))
studio.camera(scene, (9.0, 6.5, 4.8), (0, 0, 3.1), 50)
studio.render(scene, os.path.join(PREV, "soldiers_side.png"))
studio.camera(scene, (3.2, 5.2, 5.4), (0, 0, 4.2), 45)
studio.render(scene, os.path.join(PREV, "soldiers_closeup.png"))

# Weapon line-up: right-side profiles, muzzle to the right of frame.
scene = studio.reset()
z = 0.0
for wid in ("AR", "CB", "LMG", "SR", "P11"):
    load(os.path.join(EXPORT, "weapons", f"{wid}.glb"), (0, 0, z))
    z -= 1.5
studio.setup(scene, (1200, 1500), 48, floor_z=-7.4)
studio.camera(scene, (10.5, 0.6, -2.9), (0, 0.6, -2.9), 40)
studio.render(scene, os.path.join(PREV, "weapons_lineup.png"))

# Rifle close-up, front three-quarter.
scene = studio.reset()
load(os.path.join(EXPORT, "weapons", "AR.glb"))
studio.setup(scene, (1400, 900), 64, floor_z=-0.6)
studio.camera(scene, (2.6, 3.4, 1.0), (0, 0.4, 0.15), 45)
studio.render(scene, os.path.join(PREV, "rifle_closeup.png"))
print("previews written", flush=True)
sys.stdout.flush()
os._exit(0)
