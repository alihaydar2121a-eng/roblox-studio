"""QC: build one weapon (procedural materials, no bake) and render it from 3 angles.
Usage: python3 scripts/blender/qc_weapon.py AR [out_dir]"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402,F401
from ironfront import geo, studio, weapons  # noqa: E402

wid = sys.argv[1]
out = sys.argv[2] if len(sys.argv) > 2 else "/tmp/qc"
scene = studio.reset()
parts = weapons.BUILDERS[wid]()
tris = sum(geo.tri_count(geo.apply_all(p)) for p in parts)
print(f"{wid}: {len(parts)} objects, {tris} triangles")
studio.setup(scene, (1100, 620), 24, floor_z=-0.9)
L = {"AR": 4.0, "CB": 3.0, "LMG": 4.5, "SR": 4.6, "P11": 1.0}[wid]
cy = {"AR": 0.66, "CB": 0.5, "LMG": 0.8, "SR": 0.9, "P11": 0.2}[wid]
studio.camera(scene, (L * 1.25, cy - L * 0.05, 0.35), (0, cy, 0.3), 50)  # right side
studio.render(scene, f"{out}/{wid}_side.png")
studio.camera(scene, (L * 0.85, cy + L * 0.9, L * 0.45), (0, cy, 0.3), 50)  # front 3/4
studio.render(scene, f"{out}/{wid}_front34.png")
studio.camera(scene, (-L * 0.8, cy - L * 0.95, L * 0.5), (0, cy, 0.3), 50)  # rear 3/4, left side
studio.render(scene, f"{out}/{wid}_rear34.png")
sys.stdout.flush()
os._exit(0)
