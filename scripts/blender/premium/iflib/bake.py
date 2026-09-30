"""Texture atlas baking and Roblox-ready export.

Each asset's non-glass meshes share ONE UV atlas, so a single SurfaceAppearance
(ColorMap / NormalMap / RoughnessMap / MetalnessMap) can be applied to every
MeshPart. The procedural looks from mats.py are baked with Cycles:
  Color     emission bake of OUT_color, multiplied by baked ambient occlusion
  Roughness emission bake of OUT_rough
  Metalness emission bake of OUT_metal (skipped when the asset has no metal)
  Normal    tangent-space normal bake (captures the micro-surface bump)
"""
import math
import os

import bpy
import numpy as np

from . import mats


def select_only(objs, active=None):
    vl = bpy.context.view_layer
    for o in vl.objects:
        o.select_set(False)
    for o in objs:
        o.hide_set(False)
        o.select_set(True)
    vl.objects.active = active or objs[0]


def uv_atlas(objs, margin=0.001, angle=66):
    """One shared, non-overlapping UV layout for all `objs` with uniform texel
    density: Smart UV Project packs every selected object into the same 0-1
    space; a concave re-pack is kept only when it fills the atlas better."""
    select_only(objs)
    for o in objs:
        if not o.data.uv_layers:
            o.data.uv_layers.new(name="UVMap")
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(angle), island_margin=margin, area_weight=0.0,
                             correct_aspect=True, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    _, before = uv_overlap(objs, 256)
    saved = {}
    for o in objs:
        uv = o.data.uv_layers.active.data
        buf = np.empty(len(uv) * 2, dtype=np.float32)
        uv.foreach_get("uv", buf)
        saved[o] = buf
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.pack_islands(udim_source="CLOSEST_UDIM", rotate=True, scale=True, shape_method="CONCAVE",
                            margin_method="FRACTION", margin=margin)
    bpy.ops.object.mode_set(mode="OBJECT")
    overlap, after = uv_overlap(objs, 256)
    if after < before or overlap > 0.01:
        for o, buf in saved.items():
            o.data.uv_layers.active.data.foreach_set("uv", buf)
            o.data.update()


def uv_simple(objs):
    """Plain UVs for parts that are not in the atlas (lenses): some importers
    reject meshes without a UV map."""
    if not objs:
        return
    select_only(objs)
    for o in objs:
        if not o.data.uv_layers:
            o.data.uv_layers.new(name="UVMap")
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.01)
    bpy.ops.object.mode_set(mode="OBJECT")


def _materials(objs):
    out = []
    for o in objs:
        for s in o.material_slots:
            if s.material and s.material not in out and not s.material.get("iron_glass"):
                out.append(s.material)
    return out


def _target(mat, img):
    nt = mat.node_tree
    node = nt.nodes.get("BAKE_TARGET")
    if node is None:
        node = nt.nodes.new("ShaderNodeTexImage")
        node.name = "BAKE_TARGET"
        node.location = (600, 300)
    node.image = img
    nt.nodes.active = node
    return node


def _emit_channel(mat, chan):
    nt = mat.node_tree
    out = nt.nodes.get("Output") or next(n for n in nt.nodes if n.bl_idname == "ShaderNodeOutputMaterial")
    em = nt.nodes.get("BAKE_EMIT") or nt.nodes.new("ShaderNodeEmission")
    em.name = "BAKE_EMIT"
    em.inputs["Strength"].default_value = 1.0
    src = mats.channel(mat, chan)
    for l in list(em.inputs["Color"].links):
        nt.links.remove(l)
    if src is not None:
        nt.links.new(src, em.inputs["Color"])
    nt.links.new(em.outputs[0], out.inputs["Surface"])


def _restore(mat):
    nt = mat.node_tree
    out = nt.nodes.get("Output") or next(n for n in nt.nodes if n.bl_idname == "ShaderNodeOutputMaterial")
    bsdf = nt.nodes.get("BSDF") or next(n for n in nt.nodes if n.bl_idname == "ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs[0], out.inputs["Surface"])


def _new_image(name, size, noncolor, alpha=True):
    img = bpy.data.images.get(name)
    if img:
        bpy.data.images.remove(img)
    img = bpy.data.images.new(name, size, size, alpha=alpha)
    img.colorspace_settings.name = "Non-Color" if noncolor else "sRGB"
    return img


def dilate(arr, mask, iters=32):
    """Grows baked islands into empty texels (8-neighbour average), so mip
    levels never pull in background — without touching any other island."""
    a = arr.copy()
    m = mask.copy()
    offsets = ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1))
    for _ in range(iters):
        if m.all():
            break
        acc = np.zeros_like(a)
        cnt = np.zeros(m.shape, dtype=np.float32)
        for dy, dx in offsets:
            sm = np.roll(m, (dy, dx), axis=(0, 1))
            acc += np.roll(a, (dy, dx), axis=(0, 1)) * sm[..., None]
            cnt += sm
        grow = (~m) & (cnt > 0)
        a[grow] = acc[grow] / cnt[grow][:, None]
        m |= grow
    if not m.all() and m.any():
        a[~m] = a[m].mean(axis=0)
    return a


def _bake(kind, objs, samples):
    """Bakes with NO margin: Cycles' margin would spill one object's islands
    into another object's islands in the shared atlas. Coverage is read from
    the alpha channel afterwards and dilated in numpy instead."""
    scene = bpy.context.scene
    scene.cycles.samples = samples
    scene.render.bake.margin = 0
    scene.render.bake.use_clear = True
    select_only(objs)
    if kind == "NORMAL":
        bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT", margin=0, use_clear=True)
    else:
        bpy.ops.object.bake(type=kind, margin=0, use_clear=True)


def _px(img):
    a = np.empty(len(img.pixels), dtype=np.float32)
    img.pixels.foreach_get(a)
    return a.reshape(img.size[1], img.size[0], 4)


def _set_px(img, arr):
    img.pixels.foreach_set(arr.astype(np.float32).ravel())
    img.update()


def bake_atlas(objs, name, out_dir, size=1024, ao_strength=0.6, samples=16, occluders=()):
    """Bakes the atlas for `objs` into out_dir/<name>_<Map>.png. Other mesh
    objects in the scene are hidden during the bake unless listed in
    `occluders` (those only contribute ambient occlusion)."""
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    os.makedirs(out_dir, exist_ok=True)
    hidden = []
    for o in scene.objects:
        if o.type == "MESH" and o not in objs and o not in occluders and not o.hide_render:
            o.hide_render = True
            hidden.append(o)
    materials = _materials(objs)
    has_metal = any(mats.channel(m, "OUT_metal") is not None and _max_metal(m) > 0.01 for m in materials)
    maps = {}

    coverage = []

    def run(label, noncolor, kind, chan=None, spp=samples):
        img = _new_image(f"{name}_{label}", size, noncolor)
        for m in materials:
            _target(m, img)
            if chan:
                _emit_channel(m, chan)
            else:
                _restore(m)
        _bake(kind, objs, spp)
        px = _px(img)
        if not coverage:
            coverage.append(px[..., 3] > 0.5)
        maps[label] = (img, px)
        return img

    run("Color", False, "EMIT", "OUT_color")
    run("Roughness", True, "EMIT", "OUT_rough")
    if has_metal:
        run("Metalness", True, "EMIT", "OUT_metal")
    for m in materials:
        _restore(m)
    run("Normal", True, "NORMAL", None, 8)
    run("AO", True, "AO", None, 64)
    mask = coverage[0]
    # AO into the colour map (Roblox has no small-scale AO of its own)
    c = maps["Color"][1]
    a = maps["AO"][1][..., :1]
    c[..., :3] *= (1 - ao_strength) + ao_strength * a

    files = {}
    for label, (img, px) in maps.items():
        if label == "AO":
            continue
        out = dilate(px, mask)
        out[..., 3] = 1.0
        # write an RGB (no alpha) PNG
        final = _new_image(f"{name}_{label}_out", size, img.colorspace_settings.name == "Non-Color", alpha=False)
        _set_px(final, out)
        path = os.path.join(out_dir, f"{name}_{label}.png")
        final.filepath_raw = path
        final.file_format = "PNG"
        final.save()
        files[label] = path
        bpy.data.images.remove(final)
    for m in materials:
        node = m.node_tree.nodes.get("BAKE_TARGET")
        if node:
            m.node_tree.nodes.remove(node)
        em = m.node_tree.nodes.get("BAKE_EMIT")
        if em:
            m.node_tree.nodes.remove(em)
        _restore(m)
    for o in hidden:
        o.hide_render = False
    for img, _ in maps.values():
        bpy.data.images.remove(img)
    print(f"[bake] {name}: {mask.mean() * 100:.0f}% of the atlas covered")
    return files


def _max_metal(mat):
    s = mat.get("iron_spec", "")
    try:
        spec = eval(s)  # our own repr() of a plain dict
    except Exception:  # noqa: BLE001
        return 0.0
    return max(spec.get("metal", 0.0), spec.get("wear_metal", 0.0) if spec.get("wear", 0) > 0 else 0.0)


def atlas_material(name, files):
    """Principled material that reads the baked maps (what the exports carry)."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]

    def tex(label, noncolor):
        img = bpy.data.images.load(files[label], check_existing=True)
        img.colorspace_settings.name = "Non-Color" if noncolor else "sRGB"
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image = img
        n.label = label
        return n

    c = tex("Color", False)
    nt.links.new(c.outputs[0], bsdf.inputs["Base Color"])
    r = tex("Roughness", True)
    nt.links.new(r.outputs[0], bsdf.inputs["Roughness"])
    if "Metalness" in files:
        m = tex("Metalness", True)
        nt.links.new(m.outputs[0], bsdf.inputs["Metallic"])
    else:
        bsdf.inputs["Metallic"].default_value = 0.0
    n = tex("Normal", True)
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(n.outputs[0], nm.inputs["Color"])
    nt.links.new(nm.outputs[0], bsdf.inputs["Normal"])
    return mat


def assign(objs, mat, keep_glass=True):
    """Replaces every (non-glass) material slot with `mat`, remembering the
    procedural source material name on the object for re-baking."""
    for o in objs:
        src = [s.material.name for s in o.material_slots if s.material]
        if keep_glass and any(s.material and s.material.get("iron_glass") for s in o.material_slots):
            continue
        o["iron_source_materials"] = ",".join(src)
        for s in o.material_slots:
            if s.material:
                s.material.use_fake_user = True
        o.data.materials.clear()
        o.data.materials.append(mat)


def export(objs, base_path):
    """FBX + GLB with Roblox axes (Y up, -Z forward), 1 unit = 1 stud."""
    os.makedirs(os.path.dirname(base_path), exist_ok=True)
    select_only(objs)
    bpy.ops.export_scene.fbx(
        filepath=base_path + ".fbx", use_selection=True, axis_forward="-Z", axis_up="Y",
        apply_unit_scale=True, apply_scale_options="FBX_SCALE_NONE", mesh_smooth_type="OFF",
        use_mesh_modifiers=True, add_leaf_bones=False, bake_space_transform=True,
        object_types={"MESH"}, path_mode="COPY", embed_textures=True, use_triangles=True, use_tspace=True,
    )
    bpy.ops.export_scene.gltf(
        filepath=base_path + ".glb", use_selection=True, export_format="GLB", export_yup=True,
        export_texcoords=True, export_normals=True, export_tangents=False, export_materials="EXPORT",
        export_image_format="AUTO", export_apply=True,
    )
    for o in bpy.context.view_layer.objects:
        o.select_set(False)


def uv_overlap(objs, res=512):
    """Fraction of covered atlas texels claimed by more than one triangle
    (0 means a clean, non-overlapping atlas)."""
    cover = np.zeros((res, res), dtype=np.int32)
    ys, xs = np.mgrid[0:res, 0:res]
    px = (xs + 0.5) / res
    py = (ys + 0.5) / res
    for o in objs:
        me = o.data
        me.calc_loop_triangles()
        uv = me.uv_layers.active.data
        for tri in me.loop_triangles:
            (ax, ay), (bx, by), (cx, cy) = (tuple(uv[i].uv) for i in tri.loops)
            x0 = max(int(min(ax, bx, cx) * res), 0)
            x1 = min(int(max(ax, bx, cx) * res) + 1, res)
            y0 = max(int(min(ay, by, cy) * res), 0)
            y1 = min(int(max(ay, by, cy) * res) + 1, res)
            if x1 <= x0 or y1 <= y0:
                continue
            X = px[y0:y1, x0:x1]
            Y = py[y0:y1, x0:x1]
            d = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
            if abs(d) < 1e-14:
                continue
            l1 = ((by - cy) * (X - cx) + (cx - bx) * (Y - cy)) / d
            l2 = ((cy - ay) * (X - cx) + (ax - cx) * (Y - cy)) / d
            l3 = 1 - l1 - l2
            inside = (l1 > 1e-4) & (l2 > 1e-4) & (l3 > 1e-4)
            cover[y0:y1, x0:x1] += inside
    covered = (cover > 0).sum()
    return float((cover > 1).sum()) / max(covered, 1), float(covered) / (res * res)
