"""
Procedural PBR materials and texture baking.

Materials are authored as Cycles node trees (object-space noise, edge wear
from geometry pointiness, cavity darkening from AO, camo patterns), then baked
into one texture atlas per asset: Color (with wear + AO baked in), Roughness
and Metalness. After baking every object is switched to a simple image-based
material so FBX/GLB exports carry real textures.
"""
import math
import os

import bpy


def srgb(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def rgba(rgb):
    return (srgb(rgb[0]), srgb(rgb[1]), srgb(rgb[2]), 1.0)


PRESETS = {
    # kind: (metallic, roughness, noise_scale, noise_strength, wear_strength, wear_rgb)
    "polymer": (0.0, 0.58, 38.0, 0.10, 0.18, (140, 140, 134)),
    "metal": (0.6, 0.52, 60.0, 0.14, 0.55, (120, 122, 124)),
    "anodized": (0.45, 0.48, 45.0, 0.08, 0.5, (130, 130, 134)),
    "wood": (0.0, 0.55, 8.0, 0.25, 0.3, (170, 130, 90)),
    "fabric": (0.0, 0.9, 90.0, 0.12, 0.15, (200, 195, 170)),
    "rubber": (0.0, 0.85, 70.0, 0.08, 0.1, (80, 80, 80)),
    "leather": (0.0, 0.62, 30.0, 0.15, 0.35, (150, 120, 90)),
    "paint": (0.0, 0.62, 20.0, 0.08, 0.55, (150, 145, 125)),
    "lens": (0.0, 0.05, 1.0, 0.0, 0.0, (255, 255, 255)),
    "skin": (0.0, 0.55, 10.0, 0.04, 0.0, (255, 255, 255)),
}


def _node(nodes, kind, loc, **props):
    n = nodes.new(kind)
    n.location = loc
    for k, v in props.items():
        setattr(n, k, v)
    return n


def material(name, kind, rgb, camo=None, digital=False, scale=1.0):
    """Creates (or returns) a procedural material.
    camo: list of up to 4 RGB colours for a camouflage pattern (fabric/paint).
    digital: pixelated pattern instead of organic blotches."""
    mat = bpy.data.materials.get(name)
    if mat:
        return mat
    metallic, rough, nscale, nstrength, wear, wear_rgb = PRESETS[kind]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nodes, links = nt.nodes, nt.links
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = rough
    if kind == "lens":
        bsdf.inputs["Base Color"].default_value = rgba(rgb)
        bsdf.inputs["Roughness"].default_value = 0.05
        bsdf.inputs["Coat Weight"].default_value = 1.0
        mat["ironfront_kind"] = kind
        return mat

    coord = _node(nodes, "ShaderNodeTexCoord", (-1400, 0))
    vec = coord.outputs["Object"]
    if camo and digital:
        snap = _node(nodes, "ShaderNodeVectorMath", (-1200, 300), operation="SNAP")
        snap.inputs[1].default_value = (0.07 * scale, 0.07 * scale, 0.07 * scale)
        links.new(vec, snap.inputs[0])
        vec_camo = snap.outputs[0]
    else:
        vec_camo = vec

    # Base colour: flat or camouflage.
    if camo:
        cn = _node(nodes, "ShaderNodeTexNoise", (-1000, 300))
        cn.inputs["Scale"].default_value = (2.2 if not digital else 3.0) / scale
        cn.inputs["Detail"].default_value = 3.0 if not digital else 0.0
        cn.inputs["Roughness"].default_value = 0.55
        links.new(vec_camo, cn.inputs["Vector"])
        ramp = _node(nodes, "ShaderNodeValToRGB", (-800, 300))
        ramp.color_ramp.interpolation = "CONSTANT"
        stops = [0.0, 0.42, 0.52, 0.62][: len(camo)]
        els = ramp.color_ramp.elements
        while len(els) < len(camo):
            els.new(0.5)
        for el, pos, col in zip(els, stops, camo):
            el.position = pos
            el.color = rgba(col)
        links.new(cn.outputs["Fac"], ramp.inputs["Fac"])
        base = ramp.outputs["Color"]
    else:
        solid = _node(nodes, "ShaderNodeRGB", (-800, 300))
        solid.outputs[0].default_value = rgba(rgb)
        base = solid.outputs[0]

    # Subtle mottling / grain.
    noise = _node(nodes, "ShaderNodeTexNoise", (-1000, 0))
    noise.inputs["Scale"].default_value = nscale / scale
    noise.inputs["Detail"].default_value = 6.0
    links.new(vec, noise.inputs["Vector"])
    if kind == "wood":
        wave = _node(nodes, "ShaderNodeTexWave", (-1000, -150))
        wave.inputs["Scale"].default_value = 3.0 / scale
        wave.inputs["Distortion"].default_value = 6.0
        links.new(vec, wave.inputs["Vector"])
        grain_src = wave.outputs["Fac"]
    else:
        grain_src = noise.outputs["Fac"]
    grain = _node(nodes, "ShaderNodeMix", (-600, 200), data_type="RGBA", blend_type="MULTIPLY")
    grain.inputs["Factor"].default_value = nstrength
    links.new(base, grain.inputs[6])
    links.new(grain_src, grain.inputs[7])
    col = grain.outputs[2]

    # Edge wear from pointiness (convex edges get lighter, bare material).
    if wear > 0:
        geo = _node(nodes, "ShaderNodeNewGeometry", (-1000, -400))
        wramp = _node(nodes, "ShaderNodeValToRGB", (-800, -400))
        wramp.color_ramp.elements[0].position = 0.56
        wramp.color_ramp.elements[1].position = 0.66
        links.new(geo.outputs["Pointiness"], wramp.inputs["Fac"])
        wmask = _node(nodes, "ShaderNodeMath", (-600, -400), operation="MULTIPLY")
        wmask.inputs[1].default_value = wear
        links.new(wramp.outputs["Color"], wmask.inputs[0])
        wmix = _node(nodes, "ShaderNodeMix", (-400, 200), data_type="RGBA", blend_type="MIX")
        wcol = _node(nodes, "ShaderNodeRGB", (-600, -200))
        wcol.outputs[0].default_value = rgba(wear_rgb)
        links.new(wmask.outputs[0], wmix.inputs["Factor"])
        links.new(col, wmix.inputs[6])
        links.new(wcol.outputs[0], wmix.inputs[7])
        col = wmix.outputs[2]
        # Worn edges are smoother (and bare metal on metal parts).
        rmix = _node(nodes, "ShaderNodeMath", (-400, -600), operation="MULTIPLY_ADD")
        rmix.inputs[1].default_value = -0.25
        rmix.inputs[2].default_value = rough
        links.new(wmask.outputs[0], rmix.inputs[0])
        links.new(rmix.outputs[0], bsdf.inputs["Roughness"])

    # Cavity darkening from ambient occlusion.
    ao = _node(nodes, "ShaderNodeAmbientOcclusion", (-600, 500))
    ao.inputs["Distance"].default_value = 0.08
    ao.samples = 8
    aomix = _node(nodes, "ShaderNodeMix", (-200, 300), data_type="RGBA", blend_type="MULTIPLY")
    aomix.inputs["Factor"].default_value = 0.55
    links.new(col, aomix.inputs[6])
    links.new(ao.outputs["AO"], aomix.inputs[7])
    links.new(aomix.outputs[2], bsdf.inputs["Base Color"])
    mat["ironfront_kind"] = kind
    return mat


def _select_only(objs):
    for o in bpy.context.selected_objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]


def unwrap(objs, margin=0.004):
    _select_only(objs)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=margin, area_weight=0.0, scale_to_bounds=False)
    bpy.ops.uv.pack_islands(margin=margin, rotate=True)
    bpy.ops.object.mode_set(mode="OBJECT")


def bake(objs, name, out_dir, size=1024, samples=12):
    """Bakes Color / Roughness / Metalness for objs into shared images; returns image paths."""
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    unwrap(objs)
    images = {}
    for kind in ("Color", "Roughness", "Metalness"):
        img = bpy.data.images.new(f"{name}_{kind}", size, size, alpha=False)
        img.colorspace_settings.name = "sRGB" if kind == "Color" else "Non-Color"
        images[kind] = img
    mats = []
    for o in objs:
        for slot in o.material_slots:
            if slot.material and slot.material not in mats:
                mats.append(slot.material)

    def target(img):
        for m in mats:
            nodes = m.node_tree.nodes
            node = nodes.get("_bake_target") or nodes.new("ShaderNodeTexImage")
            node.name = "_bake_target"
            node.image = img
            nodes.active = node

    _select_only(objs)
    bake_settings = scene.render.bake
    bake_settings.margin = 6
    bake_settings.use_selected_to_active = False

    target(images["Color"])
    bake_settings.use_pass_direct = False
    bake_settings.use_pass_indirect = False
    bake_settings.use_pass_color = True
    bpy.ops.object.bake(type="DIFFUSE")

    target(images["Roughness"])
    bpy.ops.object.bake(type="ROUGHNESS")

    # Metalness: route Metallic into Emission temporarily.
    saved = []
    for m in mats:
        nt = m.node_tree
        bsdf = nt.nodes.get("Principled BSDF")
        emit = nt.nodes.new("ShaderNodeEmission")
        val = nt.nodes.new("ShaderNodeValue")
        val.outputs[0].default_value = bsdf.inputs["Metallic"].default_value
        out = nt.nodes.get("Material Output")
        old = out.inputs["Surface"].links[0].from_socket if out.inputs["Surface"].links else None
        nt.links.new(val.outputs[0], emit.inputs["Color"])
        nt.links.new(emit.outputs[0], out.inputs["Surface"])
        saved.append((m, old, emit, val))
    target(images["Metalness"])
    bpy.ops.object.bake(type="EMIT")
    for m, old, emit, val in saved:
        out = m.node_tree.nodes.get("Material Output")
        if old:
            m.node_tree.links.new(old, out.inputs["Surface"])
        m.node_tree.nodes.remove(emit)
        m.node_tree.nodes.remove(val)

    os.makedirs(out_dir, exist_ok=True)
    paths = {}
    for kind, img in images.items():
        path = os.path.join(out_dir, f"{name}_{kind}.png")
        img.filepath_raw = path
        img.file_format = "PNG"
        img.save()
        paths[kind] = path

    # Replace procedural materials with one baked material (keeps lens glossy).
    baked = bpy.data.materials.new(f"{name}_Baked")
    baked.use_nodes = True
    nt = baked.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    for kind, socket in (("Color", "Base Color"), ("Roughness", "Roughness"), ("Metalness", "Metallic")):
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = images[kind]
        nt.links.new(tex.outputs["Color"], bsdf.inputs[socket])
    for o in objs:
        for i, slot in enumerate(o.material_slots):
            slot.material = baked
    return paths
