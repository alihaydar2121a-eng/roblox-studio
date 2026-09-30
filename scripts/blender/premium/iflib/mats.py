"""Procedural PBR looks for the premium assets.

Every material exposes its final channels through named reroute nodes
(OUT_color, OUT_rough, OUT_metal) and feeds a Principled BSDF whose Normal input
carries the micro-surface (stipple, ripstop, webbing, grain...). bake.py rewires
those channels into an emission shader to bake the Roblox texture atlas, so the
shipped SurfaceAppearance maps are exactly what the renders show.

Colours are given in sRGB 0-255 and converted to scene-linear.
"""
import bpy


def lin(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def rgba(rgb):
    return (lin(rgb[0]), lin(rgb[1]), lin(rgb[2]), 1.0)


class NB:
    def __init__(self, mat):
        self.mat = mat
        self.nt = mat.node_tree
        self.x = -1400

    def n(self, kind, label=None, **props):
        node = self.nt.nodes.new(kind)
        node.location = (self.x, len(self.nt.nodes) * -40)
        if label:
            node.label = label
            node.name = label
        for k, v in props.items():
            if k.startswith("in_"):
                key = k[3:]
                sock = node.inputs[int(key)] if key.isdigit() else node.inputs[key.replace("_", " ")]
                sock.default_value = v
            else:
                setattr(node, k, v)
        return node

    def link(self, out, inp):
        self.nt.links.new(out, inp)

    def math(self, op, a, b=None, clamp=False):
        node = self.n("ShaderNodeMath", operation=op, use_clamp=clamp)
        self._feed(node.inputs[0], a)
        if b is not None:
            self._feed(node.inputs[1], b)
        return node.outputs[0]

    def _feed(self, sock, v):
        if isinstance(v, (int, float)):
            sock.default_value = v
        else:
            self.link(v, sock)

    def maprange(self, v, a, b, c=0.0, d=1.0, clamp=True):
        node = self.n("ShaderNodeMapRange", clamp=clamp)
        self._feed(node.inputs["Value"], v)
        node.inputs["From Min"].default_value = a
        node.inputs["From Max"].default_value = b
        node.inputs["To Min"].default_value = c
        node.inputs["To Max"].default_value = d
        return node.outputs[0]

    def mix_rgb(self, fac, a, b, blend="MIX"):
        node = self.n("ShaderNodeMix", data_type="RGBA", blend_type=blend, clamp_result=True)
        self._feed(node.inputs[0], fac)
        for sock, v in ((node.inputs[6], a), (node.inputs[7], b)):
            if isinstance(v, tuple):
                sock.default_value = v
            else:
                self.link(v, sock)
        return node.outputs[2]

    def mix_f(self, fac, a, b):
        node = self.n("ShaderNodeMix", data_type="FLOAT", clamp_result=True)
        self._feed(node.inputs[0], fac)
        self._feed(node.inputs[2], a)
        self._feed(node.inputs[3], b)
        return node.outputs[0]

    def reroute(self, name, sock):
        r = self.n("NodeReroute", label=name)
        self.link(sock, r.inputs[0])
        return r.outputs[0]


def _coords(nb, scale=1.0):
    tc = nb.n("ShaderNodeTexCoord")
    if scale == 1.0:
        return tc.outputs["Object"]
    m = nb.n("ShaderNodeVectorMath", operation="SCALE")
    nb.link(tc.outputs["Object"], m.inputs[0])
    m.inputs["Scale"].default_value = scale
    return m.outputs[0]


def _noise(nb, co, scale, detail=4.0, rough=0.5, dist=0.0, w=None):
    node = nb.n("ShaderNodeTexNoise", noise_dimensions="4D" if w is not None else "3D")
    nb.link(co, node.inputs["Vector"])
    node.inputs["Scale"].default_value = scale
    node.inputs["Detail"].default_value = detail
    node.inputs["Roughness"].default_value = rough
    node.inputs["Distortion"].default_value = dist
    if w is not None:
        node.inputs["W"].default_value = w
    return node


def _edge_mask(nb, radius):
    """1 on convex edges/bevels, 0 on flat areas (Cycles Bevel-node trick)."""
    bev = nb.n("ShaderNodeBevel", samples=8)
    bev.inputs["Radius"].default_value = radius
    geo = nb.n("ShaderNodeNewGeometry")
    dot = nb.n("ShaderNodeVectorMath", operation="DOT_PRODUCT")
    nb.link(bev.outputs[0], dot.inputs[0])
    nb.link(geo.outputs["Normal"], dot.inputs[1])
    return nb.maprange(dot.outputs["Value"], 0.995, 0.90)


def _bump_height(nb, co, spec):
    """Returns a height socket for the requested micro-surface, or None."""
    kind = spec.get("kind")
    if not kind:
        return None
    s = spec.get("scale", 1.0)
    if kind == "peel":  # cerakote / coated metal orange-peel
        return _noise(nb, co, 180 * s, 3, 0.5).outputs["Fac"]
    if kind == "grain":  # moulded polymer grain
        return _noise(nb, co, 420 * s, 2, 0.6).outputs["Fac"]
    if kind == "stipple":  # hot-iron stippling on grips
        vor = nb.n("ShaderNodeTexVoronoi", feature="F1", distance="EUCLIDEAN")
        nb.link(co, vor.inputs["Vector"])
        vor.inputs["Scale"].default_value = 260 * s
        vor.inputs["Randomness"].default_value = 0.9
        return nb.math("POWER", vor.outputs["Distance"], 0.6)
    if kind in ("ripstop", "weave", "webbing"):
        # woven cloth: two sets of bands + a ripstop grid for "ripstop"
        def wave(direction, scale, prof="SIN"):
            w = nb.n("ShaderNodeTexWave", wave_type="BANDS", bands_direction=direction, wave_profile=prof)
            nb.link(co, w.inputs["Vector"])
            w.inputs["Scale"].default_value = scale
            w.inputs["Distortion"].default_value = 0.6
            w.inputs["Detail"].default_value = 0.5
            return w.outputs["Fac"]
        if kind == "webbing":
            a = wave(spec.get("dir", "Z"), 110 * s)
            b = wave("X", 38 * s)
            return nb.math("ADD", nb.math("MULTIPLY", a, 0.8), nb.math("MULTIPLY", b, 0.2))
        a = wave("X", 150 * s)
        b = wave("Z", 150 * s)
        h = nb.math("MULTIPLY", nb.math("ADD", a, b), 0.5)
        if kind == "ripstop":
            ga = wave("X", 12 * s, "SAW")
            gb = wave("Z", 12 * s, "SAW")
            grid = nb.math("MAXIMUM", nb.maprange(ga, 0.9, 1.0), nb.maprange(gb, 0.9, 1.0))
            h = nb.math("ADD", h, nb.math("MULTIPLY", grid, 0.9))
        wr = _noise(nb, co, 9 * s, 3, 0.55)
        return nb.math("ADD", h, nb.math("MULTIPLY", wr.outputs["Fac"], 1.6))
    if kind == "leather":
        n1 = _noise(nb, co, 90 * s, 6, 0.65).outputs["Fac"]
        vor = nb.n("ShaderNodeTexVoronoi", feature="DISTANCE_TO_EDGE")
        nb.link(co, vor.inputs["Vector"])
        vor.inputs["Scale"].default_value = 60 * s
        edges = nb.maprange(vor.outputs["Distance"], 0.0, 0.06, 0.0, 1.0)
        return nb.math("ADD", n1, nb.math("MULTIPLY", edges, 0.4))
    if kind == "rubber":
        return _noise(nb, co, 300 * s, 2, 0.5).outputs["Fac"]
    if kind == "knurl":
        w1 = nb.n("ShaderNodeTexWave", wave_type="BANDS", bands_direction="DIAGONAL", wave_profile="TRI")
        nb.link(co, w1.inputs["Vector"])
        w1.inputs["Scale"].default_value = 120 * s
        return w1.outputs["Fac"]
    return None


def build(name, spec):
    """spec keys:
      color, color2 (large-scale variation), var (0..1 amount)
      rough, rough_var, metal
      wear (0..1), wear_color, wear_rough, wear_metal, wear_radius
      camo: list of (rgb, threshold) blotch layers, camo_scale
      bump: {kind, scale, strength}
      glass: True for transparent lenses (not baked)
      emit: rgb for glowing reticles/lights
    """
    mat = bpy.data.materials.get(name)
    if mat:
        return mat
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    nb = NB(mat)
    out = nb.n("ShaderNodeOutputMaterial", label="Output")
    out.location = (600, 0)
    bsdf = nb.n("ShaderNodeBsdfPrincipled", label="BSDF")
    bsdf.location = (300, 0)
    nb.link(bsdf.outputs[0], out.inputs["Surface"])
    mat["iron_spec"] = str(spec)

    if spec.get("glass"):
        bsdf.inputs["Base Color"].default_value = rgba(spec.get("color", (60, 90, 80)))
        bsdf.inputs["Roughness"].default_value = spec.get("rough", 0.05)
        bsdf.inputs["Transmission Weight"].default_value = 1.0
        bsdf.inputs["IOR"].default_value = 1.5
        bsdf.inputs["Coat Weight"].default_value = 0.4
        mat.blend_method = "BLEND" if hasattr(mat, "blend_method") else None
        mat["iron_glass"] = True
        # keep channels for completeness
        c = nb.n("ShaderNodeRGB", label="c")
        c.outputs[0].default_value = rgba(spec.get("color", (60, 90, 80)))
        nb.reroute("OUT_color", c.outputs[0])
        v = nb.n("ShaderNodeValue")
        v.outputs[0].default_value = spec.get("rough", 0.05)
        nb.reroute("OUT_rough", v.outputs[0])
        z = nb.n("ShaderNodeValue")
        z.outputs[0].default_value = 0.0
        nb.reroute("OUT_metal", z.outputs[0])
        return mat

    co = _coords(nb)

    # ---- base colour with large-scale variation
    base = nb.n("ShaderNodeRGB", label="base")
    base.outputs[0].default_value = rgba(spec["color"])
    color = base.outputs[0]
    if spec.get("camo"):
        cs = spec.get("camo_scale", 1.0)
        for i, (rgb, thr) in enumerate(spec["camo"]):
            nz = _noise(nb, co, 2.2 * cs * (1 + 0.35 * i), 5.0, 0.55, dist=0.35, w=1.7 * i + 0.3)
            m = nb.maprange(nz.outputs["Fac"], thr, thr + 0.012)
            color = nb.mix_rgb(m, color, rgba(rgb))
    if spec.get("color2"):
        nz = _noise(nb, co, 3.5, 3, 0.5)
        f = nb.math("MULTIPLY", nb.maprange(nz.outputs["Fac"], 0.35, 0.7), spec.get("var", 0.5))
        color = nb.mix_rgb(f, color, rgba(spec["color2"]))
    # fine mottling so large faces are never perfectly flat
    mot = _noise(nb, co, 40, 4, 0.6)
    mf = nb.math("MULTIPLY", nb.maprange(mot.outputs["Fac"], 0.3, 0.7), spec.get("mottle", 0.10))
    darker = nb.mix_rgb(1.0, color, (0.55, 0.55, 0.55, 1.0), "MULTIPLY")
    color = nb.mix_rgb(mf, color, darker)

    rough = spec.get("rough", 0.5)
    rough_node = nb.n("ShaderNodeValue")
    rough_node.outputs[0].default_value = rough
    rough_s = rough_node.outputs[0]
    if spec.get("rough_var", 0.0) > 0:
        rn = _noise(nb, co, 18, 4, 0.6)
        rv = nb.maprange(rn.outputs["Fac"], 0.3, 0.7, -spec["rough_var"], spec["rough_var"])
        rough_s = nb.math("ADD", rough_s, rv, clamp=True)
    metal_node = nb.n("ShaderNodeValue")
    metal_node.outputs[0].default_value = spec.get("metal", 0.0)
    metal_s = metal_node.outputs[0]

    # ---- edge wear
    wear = spec.get("wear", 0.0)
    if wear > 0:
        edge = _edge_mask(nb, spec.get("wear_radius", 0.006))
        wn = _noise(nb, co, 55, 8, 0.7)
        brk = nb.maprange(wn.outputs["Fac"], 0.42, 0.62)
        m = nb.math("MULTIPLY", nb.math("MULTIPLY", edge, brk), wear * 2.5, clamp=True)
        m = nb.maprange(m, 0.25, 0.6)
        color = nb.mix_rgb(m, color, rgba(spec.get("wear_color", (150, 150, 150))))
        rough_s = nb.mix_f(m, rough_s, spec.get("wear_rough", 0.3))
        metal_s = nb.mix_f(m, metal_s, spec.get("wear_metal", spec.get("metal", 0.0)))

    color = nb.reroute("OUT_color", color)
    rough_s = nb.reroute("OUT_rough", rough_s)
    metal_s = nb.reroute("OUT_metal", metal_s)
    nb.link(color, bsdf.inputs["Base Color"])
    nb.link(rough_s, bsdf.inputs["Roughness"])
    nb.link(metal_s, bsdf.inputs["Metallic"])

    if spec.get("emit"):
        bsdf.inputs["Emission Color"].default_value = rgba(spec["emit"])
        bsdf.inputs["Emission Strength"].default_value = spec.get("emit_strength", 3.0)

    # ---- micro-surface
    b = spec.get("bump")
    if b:
        h = _bump_height(nb, co, b)
        if h is not None:
            bump = nb.n("ShaderNodeBump", label="Bump")
            bump.inputs["Strength"].default_value = b.get("strength", 0.2)
            bump.inputs["Distance"].default_value = b.get("distance", 0.002)
            nb.link(h, bump.inputs["Height"])
            nb.link(bump.outputs[0], bsdf.inputs["Normal"])
    return mat


def channel(mat, name):
    for n in mat.node_tree.nodes:
        if n.bl_idname == "NodeReroute" and n.label == name:
            return n.outputs[0]
    return None


def flat(name, rgb, rough=0.6, metal=0.0, emit=None, strength=1.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = rgba(rgb)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if emit:
        bsdf.inputs["Emission Color"].default_value = rgba(emit)
        bsdf.inputs["Emission Strength"].default_value = strength
    return mat
