#!/usr/bin/env python3
"""Render a shaded top-down preview of the Kestrel Valley heightfield.

Input: text grid from `luau scripts/dump_heightfield.luau` ("height:Material" cells).
Output: PNG with hillshading, terrain material colours and water.
Usage: luau scripts/dump_heightfield.luau > hf.txt && python3 scripts/render_heightmap.py hf.txt out.png [build/footprints.tsv]
"""
import sys
from PIL import Image

COLORS = {
    "Grass": (96, 120, 64), "LeafyGrass": (74, 100, 52), "Ground": (118, 100, 76), "Mud": (86, 72, 56),
    "Rock": (116, 114, 108), "Slate": (100, 102, 100), "Sand": (186, 170, 132), "Asphalt": (60, 62, 64),
    "Concrete": (150, 148, 140), "Cobblestone": (130, 122, 108), "Pavement": (140, 138, 130), "Water": (54, 90, 104),
}

def overlay(img, path, half=896, step=4, scale=2):
    """Draw part footprints (x, z, extentX, extentZ, top, r, g, b) sorted by height."""
    from PIL import ImageDraw
    draw = ImageDraw.Draw(img)
    rows = []
    for line in open(path):
        f = line.split()
        if len(f) == 8:
            rows.append([float(v) for v in f[:5]] + [int(v) for v in f[5:]])
    rows.sort(key=lambda r: r[4])
    for x, z, ex, ez, top, r, g, b in rows:
        x0 = (x - ex + half) / step * scale
        x1 = (x + ex + half) / step * scale
        y0 = (half - (z + ez)) / step * scale
        y1 = (half - (z - ez)) / step * scale
        draw.rectangle([x0, y0, max(x0, x1), max(y0, y1)], fill=(r, g, b))

def main(src, dst, footprints=None):
    rows = [line.split() for line in open(src) if line.strip()]
    h = [[float(c.split(":")[0]) for c in r] for r in rows]
    m = [[c.split(":")[1] for c in r] for r in rows]
    H, W = len(rows), len(rows[0])
    img = Image.new("RGB", (W, H))
    px = img.load()
    for y in range(H):
        for x in range(W):
            hx = h[y][min(x + 1, W - 1)] - h[y][max(x - 1, 0)]
            hy = h[min(y + 1, H - 1)][x] - h[max(y - 1, 0)][x]
            shade = max(0.45, min(1.35, 1.0 - (hx - hy) * 0.06))
            base = COLORS.get(m[y][x], (255, 0, 255))
            px[x, y] = tuple(max(0, min(255, int(c * shade))) for c in base)
    img = img.resize((W * 2, H * 2), Image.NEAREST)
    if footprints:
        overlay(img, footprints)
    img.save(dst)

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else None)
