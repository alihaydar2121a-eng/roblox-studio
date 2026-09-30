"""Regenerates PremiumAssets.List (src/shared/Config/PremiumAssets.lua) from the
premium build manifests, so the Studio installer always matches the exports.

  python3 scripts/blender/premium/sync_premium_table.py
"""
import glob
import json
import os
import re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
TARGET = os.path.join(ROOT, "src", "shared", "Config", "PremiumAssets.lua")


def lua_list(items, per_line=6, indent="\t\t\t"):
    rows = []
    for i in range(0, len(items), per_line):
        rows.append(indent + ", ".join(f'"{x}"' for x in items[i:i + per_line]) + ",")
    return "\n".join(rows)


def entry(model, path, size, parts):
    return (
        "\t{\n"
        f'\t\tModel = "{model}",\n'
        f"\t\tPath = {{ {', '.join(repr(p).replace(chr(39), chr(34)) for p in path)} }},\n"
        f"\t\tSize = {{ {size[0]}, {size[1]}, {size[2]} }},\n"
        "\t\tParts = {\n"
        f"{lua_list(parts)}\n"
        "\t\t},\n"
        "\t},\n"
    )


entries = []
for path in sorted(glob.glob(os.path.join(ROOT, "assets", "premium", "weapons", "*", "*.json"))):
    m = json.load(open(path))
    parts = ["Origin"] + sorted(m["objects"])
    entries.append(entry(m["model"], ["Weapons", m["id"]], m["size_studs_xyz"], parts))
for path in sorted(glob.glob(os.path.join(ROOT, "assets", "premium", "characters", "*", "*.json"))):
    m = json.load(open(path))
    for piece in ("Head", "Torso", "Arm", "Arm_L", "Leg", "Leg_L"):
        info = m["pieces"][piece]
        model = os.path.splitext(os.path.basename(info["fbx"]))[0]
        parts = ["Origin"] + sorted(info["objects"])
        entries.append(entry(model, ["Gear", m["team"], piece], info["size_studs_xyz"], parts))

src = open(TARGET).read()
new_list = "PremiumAssets.List = {\n" + "".join(entries) + "}"
src, n = re.subn(r"PremiumAssets\.List = \{\n.*?\n\}", new_list, src, count=1, flags=re.S)
assert n == 1, "PremiumAssets.List block not found"
open(TARGET, "w").write(src)
print(f"PremiumAssets.List: {len(entries)} entries")
