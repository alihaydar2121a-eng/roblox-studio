"""Render helpers for quality-control images (neutral studio, Cycles CPU)."""
import math
import os

import bpy
from mathutils import Euler, Vector


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "NONE"
    return scene


def setup(scene, res=(1200, 700), samples=32, floor_z=None, floor_rgb=(0.23, 0.24, 0.23)):
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y = res
    scene.view_settings.view_transform = "AgX"
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.42, 0.45, 0.5, 1)
    bg.inputs[1].default_value = 0.55
    scene.world = world
    def light(name, kind, energy, loc, rot, size=None):
        data = bpy.data.lights.new(name, kind)
        data.energy = energy
        if size:
            data.size = size
        obj = bpy.data.objects.new(name, data)
        obj.location = loc
        obj.rotation_euler = Euler([math.radians(a) for a in rot])
        scene.collection.objects.link(obj)
    light("Key", "AREA", 900, (4, -4, 6), (45, 0, 45), 4)
    light("Fill", "AREA", 350, (-5, -2, 3), (65, 0, -70), 6)
    light("Rim", "AREA", 700, (0, 6, 4), (-50, 0, 180), 4)
    if floor_z is not None:
        bpy.ops.mesh.primitive_plane_add(size=60, location=(0, 0, floor_z))
        floor = bpy.context.active_object
        mat = bpy.data.materials.new("Floor")
        mat.use_nodes = True
        mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*floor_rgb, 1)
        mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.8
        floor.data.materials.append(mat)


def camera(scene, loc, target, lens=50, ortho=None):
    data = bpy.data.cameras.new("Cam")
    data.lens = lens
    if ortho:
        data.type = "ORTHO"
        data.ortho_scale = ortho
    cam = bpy.data.objects.new("Cam", data)
    cam.location = loc
    cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(cam)
    scene.camera = cam
    return cam


def render(scene, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
