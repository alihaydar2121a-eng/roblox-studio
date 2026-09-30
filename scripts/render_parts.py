#!/usr/bin/env python3
"""Oblique software render of generated map parts (QA preview, no terrain).

Reads build/parts.tsv written by tests/harness.luau and draws parts inside a
world-space box with flat shading and painter's-algorithm sorting. Wedges and
corner wedges use the generator's default orientation convention; cylinders
and balls are approximated by prisms.

Usage: python3 scripts/render_parts.py OUT.png CX CY CZ RADIUS [YAW_DEG] [PITCH_DEG]
"""
import math
import sys
from PIL import Image, ImageDraw

def load(path, cx, cy, cz, radius):
    parts = []
    for line in open(path):
        f = line.rstrip("\n").split("\t")
        if len(f) < 20:
            continue
        shape = f[0]
        v = list(map(float, f[1:16]))
        pos, R, U, B, S = v[0:3], v[3:6], v[6:9], v[9:12], v[12:15]
        if abs(pos[0] - cx) > radius or abs(pos[2] - cz) > radius or abs(pos[1] - cy) > radius * 1.5:
            continue
        color = tuple(int(x) for x in f[16:19])
        parts.append((shape, pos, R, U, B, S, color, float(f[19])))
    return parts

def local_mesh(shape, S):
    hx, hy, hz = S[0] / 2, S[1] / 2, S[2] / 2
    if shape == "WedgePart":  # high edge at local +Z (generator default)
        v = [(-hx, -hy, -hz), (hx, -hy, -hz), (hx, -hy, hz), (-hx, -hy, hz), (-hx, hy, hz), (hx, hy, hz)]
        faces = [(0, 3, 2, 1), (2, 3, 4, 5), (0, 1, 5, 4), (0, 4, 3), (1, 2, 5)]
        return v, faces
    if shape == "CornerWedgePart":  # apex above local (+X, -Z) corner (generator default)
        v = [(-hx, -hy, -hz), (hx, -hy, -hz), (hx, -hy, hz), (-hx, -hy, hz), (hx, hy, -hz)]
        faces = [(0, 3, 2, 1), (0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4)]
        return v, faces
    if shape in ("Cylinder", "Ball"):
        n = 10
        r = min(hy, hz)
        v = []
        for side in (-1, 1):
            for i in range(n):
                a = 2 * math.pi * i / n
                v.append((side * hx if shape == "Cylinder" else side * hx * 0.7, r * math.cos(a), r * math.sin(a)))
        faces = [tuple(range(n))[::-1], tuple(range(n, 2 * n))]
        for i in range(n):
            j = (i + 1) % n
            faces.append((i, j, n + j, n + i))
        return v, faces
    v = [(x * hx, y * hy, z * hz) for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)]
    faces = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    return v, faces

def render(out, cx, cy, cz, radius, yaw=35.0, pitch=32.0, size=900):
    parts = load("build/parts.tsv", cx, cy, cz, radius)
    ya, pa = math.radians(yaw), math.radians(pitch)
    fwd = (math.cos(pa) * math.sin(ya), -math.sin(pa), math.cos(pa) * math.cos(ya))
    right = (math.cos(ya), 0, -math.sin(ya))
    up = (fwd[1] * right[2] - fwd[2] * right[1], fwd[2] * right[0] - fwd[0] * right[2], fwd[0] * right[1] - fwd[1] * right[0])
    light = (0.45, 0.8, 0.35)
    scale = size / (radius * 2.4)
    polys = []
    for shape, pos, R, U, B, S, color, tr in parts:
        verts, faces = local_mesh(shape, S)
        world = [(pos[0] + R[0] * x + U[0] * y + B[0] * z, pos[1] + R[1] * x + U[1] * y + B[1] * z, pos[2] + R[2] * x + U[2] * y + B[2] * z) for x, y, z in verts]
        for face in faces:
            pts = [world[i] for i in face]
            a, b, c = pts[0], pts[1], pts[2]
            e1 = (b[0] - a[0], b[1] - a[1], b[2] - a[2])
            e2 = (c[0] - a[0], c[1] - a[1], c[2] - a[2])
            n = (e1[1] * e2[2] - e1[2] * e2[1], e1[2] * e2[0] - e1[0] * e2[2], e1[0] * e2[1] - e1[1] * e2[0])
            ln = math.sqrt(sum(k * k for k in n)) or 1
            n = tuple(k / ln for k in n)
            if sum(n[i] * fwd[i] for i in range(3)) > 0:
                continue  # back face
            shade = 0.45 + 0.55 * max(0.0, sum(n[i] * light[i] for i in range(3)))
            col = tuple(min(255, int(ch * shade)) for ch in color)
            depth = sum(sum(p[i] * fwd[i] for i in range(3)) for p in pts) / len(pts)
            screen = []
            for p in pts:
                d = (p[0] - cx, p[1] - cy, p[2] - cz)
                sx = sum(d[i] * right[i] for i in range(3)) * scale + size / 2
                sy = -sum(d[i] * up[i] for i in range(3)) * scale + size / 2
                screen.append((sx, sy))
            polys.append((depth, screen, col, tr))
    polys.sort(key=lambda p: -p[0])
    img = Image.new("RGB", (size, size), (150, 170, 190))
    draw = ImageDraw.Draw(img, "RGBA")
    for _, screen, col, tr in polys:
        draw.polygon(screen, fill=col + (int(255 * (1 - tr)),))
    img.save(out)
    print(f"rendered {len(parts)} parts -> {out}")

if __name__ == "__main__":
    a = sys.argv
    render(a[1], float(a[2]), float(a[3]), float(a[4]), float(a[5]), float(a[6]) if len(a) > 6 else 35.0, float(a[7]) if len(a) > 7 else 32.0)
