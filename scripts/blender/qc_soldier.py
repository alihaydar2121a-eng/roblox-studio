"""QC: assemble both factions in the R6 rest pose and render 4 angles.
Usage: python3 scripts/blender/qc_soldier.py [out_dir]"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402,F401
from mathutils import Matrix  # noqa: E402
from ironfront import geo, soldiers, studio  # noqa: E402

out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/qc"
scene = studio.reset()
tris = {}
for team, ox in (("Alpha", -1.8), ("Bravo", 1.8)):
    total = 0
    for piece in soldiers.PIECES:
        objs = soldiers.build(team, piece)
        rest = soldiers.REST[piece]
        for o in objs:
            geo.apply_all(o)
            total += geo.tri_count(o)
            o.data.transform(Matrix.Translation((rest[0] + ox, rest[1], rest[2] + 3.0)))
    # Roblox head stand-in (skin ellipsoid) for the preview
    head = geo.loft(f"{team}_headPreview", [(-0.6, 0.9, 0.9, 2.2), (-0.3, 1.18, 1.14, 2.4), (0.3, 1.18, 1.14, 2.4), (0.6, 0.9, 0.9, 2.2)], 20)
    head.data.transform(Matrix.Translation((ox, 0, 4.5)))
    geo.set_material(head, soldiers.palette(team)["skin"])
    tris[team] = total
print("triangles", tris)
studio.setup(scene, (1200, 900), 32, floor_z=0.0)
studio.camera(scene, (2.5, 11.5, 5.0), (0, 0, 3.1), 50)
studio.render(scene, f"{out}/soldiers_front.png")
studio.camera(scene, (-3.0, -11.5, 5.0), (0, 0, 3.1), 50)
studio.render(scene, f"{out}/soldiers_back.png")
studio.camera(scene, (11.5, 1.0, 4.6), (0, 0, 3.1), 50)
studio.render(scene, f"{out}/soldiers_side.png")
studio.camera(scene, (3.2, 5.2, 5.4), (0, 0, 4.2), 45)
studio.render(scene, f"{out}/soldiers_close.png")
sys.stdout.flush()
os._exit(0)
