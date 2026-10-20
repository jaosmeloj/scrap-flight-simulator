"""Blender headless: scenery for the 5 zones of Scrap Flight Simulator, in ONE FBX (one Import 3D in Studio).

Meshes are named "<Asset>__<Group>" at the world origin (origin = centre of the base, on the ground; Blender Z up,
-Y = Roblox front). Groups get a Roblox Material + Color from src/shared/Config/SceneryLooks.luau.
build/scenery.luau scatters them along the flight path.

Usage: blender -b -P scenery_kit.py -- <out_dir> [--preview]
"""

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit_lib import G  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
OUT = os.path.abspath(argv[0] if argv else "out_scenery")
PREVIEW = "--preview" in argv
os.makedirs(OUT, exist_ok=True)
rng = random.Random(3)

COL = {
    "Wall": (0.85, 0.75, 0.55), "Wall2": (0.55, 0.75, 0.85), "Roof": (0.5, 0.12, 0.08), "Roof2": (0.12, 0.25, 0.5),
    "Window": (0.4, 0.7, 1.0), "Door": (0.35, 0.18, 0.07), "Trunk": (0.3, 0.17, 0.07), "Leaf": (0.12, 0.45, 0.1),
    "Leaf2": (0.3, 0.6, 0.12), "Metal": (0.45, 0.47, 0.5), "Dark": (0.05, 0.05, 0.06), "Sign": (0.8, 0.05, 0.05),
    "SignText": (1, 1, 1), "Barn": (0.55, 0.06, 0.04), "White": (0.95, 0.95, 0.93), "Hay": (0.85, 0.65, 0.2),
    "Silo": (0.6, 0.62, 0.65), "Spot": (0.05, 0.05, 0.05), "Pink": (0.95, 0.55, 0.6), "Corn": (0.55, 0.75, 0.15),
    "Cactus": (0.15, 0.5, 0.15), "Rock": (0.65, 0.35, 0.2), "RockDark": (0.45, 0.22, 0.12), "Sand": (0.9, 0.78, 0.5),
    "Bone": (0.95, 0.92, 0.82), "Palm": (0.2, 0.6, 0.15), "Red": (0.8, 0.08, 0.06), "Boat": (0.95, 0.95, 0.95),
    "Wood": (0.45, 0.28, 0.12), "Cloud": (1, 1, 1), "Grass": (0.25, 0.65, 0.15), "Castle": (0.8, 0.8, 0.85),
    "Gold": (1.0, 0.75, 0.15), "R1": (0.9, 0.1, 0.1), "R2": (1.0, 0.5, 0.05), "R3": (1.0, 0.9, 0.1),
    "R4": (0.15, 0.75, 0.2), "R5": (0.15, 0.4, 0.95), "R6": (0.5, 0.15, 0.8), "Car": (0.1, 0.3, 0.8),
    "Car2": (0.85, 0.75, 0.1), "Lamp": (1, 0.9, 0.6),
}

ASSETS = {}


def asset(name):
    groups = {}
    ASSETS[name] = groups

    def g(group):
        if group not in groups:
            groups[group] = G()
        return groups[group]

    return g


def roof(g, group, w, d, h, z, overhang=0.8):
    """Gable roof (ridge along Y) on a box w x d whose top is at z."""
    tmp = bmesh.new()
    x, y = w / 2 + overhang, d / 2 + overhang
    v = [tmp.verts.new(p) for p in [(-x, -y, z), (x, -y, z), (x, y, z), (-x, y, z), (0, -y, z + h), (0, y, z + h)]]
    for f in [(0, 1, 4), (3, 5, 2), (0, 4, 5, 3), (1, 2, 5, 4), (0, 3, 2, 1)]:
        tmp.faces.new([v[i] for i in f])
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
    g(group).add_bm(tmp)


def windows(g, w, d, z, rows=1, per=2, gap=4.5):
    for r in range(rows):
        for k in range(per):
            x = -w / 2 + (k + 0.5) * w / per
            g("Window").box((x, -d / 2 - 0.05, z + r * gap), (1.8, 0.2, 1.8))
            g("Window").box((x, d / 2 + 0.05, z + r * gap), (1.8, 0.2, 1.8))


def tree_round(g, h=12, r=5):
    g("Trunk").cyl((0, 0, 0), (0, 0, h * 0.55), 0.6, sides=8)
    g("Leaf").sphere((0, 0, h * 0.7), r, scale=(1, 1, 0.9), sub=2)
    g("Leaf2").sphere((r * 0.4, -r * 0.3, h * 0.85), r * 0.6, sub=1)


# ---- Town -----------------------------------------------------------------------------------------------------
def town():
    g = asset("House1")
    g("Wall").box((0, 0, 4.5), (14, 12, 9))
    roof(g, "Roof", 14, 12, 5, 9)
    windows(g, 14, 12, 5)
    g("Door").box((0, -6.1, 2.5), (2.4, 0.3, 5))
    g("Dark").box((4, 2, 14), (1.4, 1.4, 4))  # chimney
    g = asset("House2")  # two floors
    g("Wall2").box((0, 0, 7), (12, 12, 14))
    roof(g, "Roof2", 12, 12, 4.5, 14)
    windows(g, 12, 12, 4, rows=2, gap=6)
    g("Door").box((0, -6.1, 2.5), (2.4, 0.3, 5))
    g = asset("Supermarket")  # where the carts come from
    g("White").box((0, 0, 7), (60, 30, 14))
    g("Sign").box((0, -15.3, 15), (34, 0.8, 6))
    for k in range(5):
        g("SignText").box((-12 + k * 6, -15.8, 15), (3.6, 0.2, 3.4))  # placeholder letters
    g("Window").box((0, -15.1, 4), (44, 0.3, 6))
    g("Dark").box((0, -15.2, 3), (6, 0.4, 6))  # door
    g("Metal").box((0, 0, 14.5), (56, 26, 1))
    g = asset("StreetLamp")
    g("Metal").cyl((0, 0, 0), (0, 0, 9), 0.25, sides=8)
    g("Metal").box((0, -1, 9), (0.3, 2.2, 0.3))
    g("Lamp").box((0, -2.1, 8.6), (0.9, 0.9, 0.6))
    g = asset("TreeTown")
    tree_round(g)
    for name, col in (("CarBlue", "Car"), ("CarYellow", "Car2")):
        g = asset(name)
        g(col).box((0, 0, 1.4), (4.2, 9, 2))
        g(col).box((0, 0.6, 3.0), (3.8, 5, 1.6))
        g("Window").box((0, -1.95, 3.0), (3.4, 0.2, 1.2))
        for x in (-2.05, 2.05):
            for y in (-2.8, 2.8):
                g("Dark").cyl((x - 0.3, y, 0.9), (x + 0.3, y, 0.9), 0.9, sides=12)


# ---- Farm -----------------------------------------------------------------------------------------------------
def farm():
    g = asset("Barn")
    g("Barn").box((0, 0, 7), (20, 26, 14))
    roof(g, "Roof", 20, 26, 8, 14, overhang=1)
    g("White").box((0, -13.1, 5), (9, 0.3, 10))
    g("Barn").box((0, -13.2, 5), (7.6, 0.3, 8.6))
    for a in (45, -45):
        g("White").box((0, -13.3, 5), (0.5, 0.3, 11), rot=(0, a, 0))
    g = asset("Silo")
    g("Silo").cyl((0, 0, 0), (0, 0, 24), 4, sides=18)
    g("Silo").sphere((0, 0, 24), 4, scale=(1, 1, 0.6), sub=2)
    for z in (6, 12, 18):
        g("Metal").cyl((0, 0, z - 0.2), (0, 0, z + 0.2), 4.1, sides=18)
    g = asset("HayBale")
    g("Hay").cyl((-1.4, 0, 1.3), (1.4, 0, 1.3), 1.3, sides=14)
    g = asset("Windmill")
    g("Wall").cyl((0, 0, 0), (0, 0, 18), 3.2, sides=10, r2=2.2)
    g("Roof").cyl((0, 0, 18), (0, 0, 22), 2.6, sides=10, r2=0.2)
    for a in (0, 90, 180, 270):
        g("Wood").box((0, -2.8, 17), (1.6, 0.3, 12), rot=(0, a + 20, 0))
    g = asset("FarmFence")
    for x in (-5, 0, 5):
        g("Wood").box((x, 0, 1.2), (0.4, 0.4, 2.4))
    for z in (0.9, 1.9):
        g("Wood").box((0, 0, z), (10.4, 0.25, 0.35))
    g = asset("Cow")
    g("White").box((0, 0, 2.6), (2.2, 4.4, 2.2))
    g("White").box((0, -2.8, 3.2), (1.4, 1.6, 1.4))
    g("Pink").box((0, -3.6, 2.9), (1.0, 0.3, 0.6))
    for x, y in ((-0.7, -1.5), (0.7, -1.5), (-0.7, 1.5), (0.7, 1.5)):
        g("White").box((x, y, 0.8), (0.5, 0.5, 1.6))
    g("Spot").box((1.12, 0.5, 2.8), (0.05, 1.6, 1.2))
    g("Spot").box((-1.12, -0.6, 2.4), (0.05, 1.2, 1.0))
    g = asset("CornField")
    for r in range(4):
        for k in range(6):
            x, y = -7.5 + r * 5, -12.5 + k * 5
            g("Corn").cyl((x, y, 0), (x, y, 3.2 + rng.uniform(-0.4, 0.4)), 0.25, sides=5)
            g("Leaf2").box((x, y, 2.4), (1.6, 0.15, 0.4), rot=(0, 30, rng.uniform(0, 180)))
    g = asset("TreeFarm")
    tree_round(g, h=14, r=6)


# ---- Desert ---------------------------------------------------------------------------------------------------
def desert():
    for name, arms in (("Cactus1", [(1, 3.5, 2.0)]), ("Cactus2", [(-1, 4.5, 2.4), (1, 3.0, 1.8)])):
        g = asset(name)
        g("Cactus").cyl((0, 0, 0), (0, 0, 8), 0.9, sides=10)
        g("Cactus").sphere((0, 0, 8), 0.9, sub=1)
        for side, z, length in arms:
            g("Cactus").cyl((0, 0, z), (side * 2.0, 0, z), 0.55, sides=8)
            g("Cactus").cyl((side * 2.0, 0, z), (side * 2.0, 0, z + length), 0.55, sides=8)
            g("Cactus").sphere((side * 2.0, 0, z + length), 0.55, sub=1)
    g = asset("RockArch")
    for x in (-8, 8):
        g("Rock").box((x, 0, 6), (4, 5, 12), rot=(0, x * 0.4, 0))
    g("Rock").box((0, 0, 13), (21, 5, 4))
    g("RockDark").box((0, 0, 15.2), (18, 4.6, 1))
    g = asset("Mesa")
    g("Rock").cyl((0, 0, 0), (0, 0, 18), 22, sides=9, r2=17)
    g("RockDark").cyl((0, 0, 18), (0, 0, 19), 17.2, sides=9)
    for z in (5, 11):
        g("RockDark").cyl((0, 0, z), (0, 0, z + 0.6), 22 - z * 0.27, sides=9)
    g = asset("Rocks")
    for k in range(4):
        g("Rock" if k % 2 else "RockDark").sphere((rng.uniform(-3, 3), rng.uniform(-3, 3), 1), rng.uniform(1.2, 2.6), scale=(1, 0.9, 0.7), sub=1)
    g = asset("Skull")
    g("Bone").sphere((0, 0, 2.2), 2.2, scale=(1.4, 1, 1), sub=2)
    g("Bone").box((0, -2.4, 1.2), (1.8, 1.4, 1.6))
    for x in (-1.6, 1.6):
        g("Bone").cyl((x, 0, 2.6), (x * 2.4, 0.6, 3.8), 0.35, sides=8, r2=0.1)  # horns
        g("Dark").sphere((x * 0.45, -1.6, 2.4), 0.45, sub=1)
    g = asset("OilPump")
    g("Dark").box((0, 0, 0.5), (3, 9, 1))
    g("Metal").box((0, 1.5, 4), (0.8, 0.8, 7))
    g("Red").box((0, 0, 7.5), (1, 11, 1.2), rot=(12, 0, 0))
    g("Red").box((0, -5.6, 6.4), (1.2, 1.2, 3))
    g("Metal").cyl((0, -5.6, 1), (0, -5.6, 5), 0.15, sides=6)


# ---- Sea ------------------------------------------------------------------------------------------------------
def palm(g, x, y, z, h=9):
    pts = [Vector((x, y, z)), Vector((x + 0.6, y, z + h * 0.5)), Vector((x + 1.4, y, z + h))]
    g("Trunk").cyl(pts[0], pts[1], 0.45, sides=7, r2=0.4)
    g("Trunk").cyl(pts[1], pts[2], 0.4, sides=7, r2=0.35)
    for k in range(6):
        a = k * 60
        g("Palm").box((x + 1.4, y, z + h), (5.5, 1.2, 0.15), rot=(0, -20, a))
    g("Trunk").sphere((x + 1.4, y, z + h - 0.4), 0.5, sub=1)


def sea():
    g = asset("Island")
    g("Sand").cyl((0, 0, -4), (0, 0, 2), 16, sides=14, r2=13)
    g("Grass").cyl((0, 0, 2), (0, 0, 2.6), 9, sides=12, r2=8)
    palm(g, -3, 1, 2.6)
    palm(g, 4, -2, 2.6, h=7)
    g("Rock").sphere((9, 5, 2), 2.2, scale=(1, 1, 0.6), sub=1)
    g = asset("Lighthouse")
    g("Rock").cyl((0, 0, -4), (0, 0, 2), 9, sides=10, r2=7)
    g("White").cyl((0, 0, 2), (0, 0, 30), 3.6, sides=14, r2=2.6)
    for z in (8, 16, 24):
        g("Red").cyl((0, 0, z), (0, 0, z + 3), 3.4 - z * 0.035, sides=14)
    g("Lamp").cyl((0, 0, 30), (0, 0, 33), 2.4, sides=12)
    g("Red").cyl((0, 0, 33), (0, 0, 35.5), 2.8, sides=12, r2=0.3)
    g = asset("Buoy")
    g("Red").cyl((0, 0, -1), (0, 0, 1.5), 1.2, sides=12, r2=0.9)
    g("White").cyl((0, 0, 1.5), (0, 0, 2), 0.9, sides=12)
    g("Metal").cyl((0, 0, 2), (0, 0, 4), 0.1, sides=6)
    g("Lamp").sphere((0, 0, 4.1), 0.3, sub=1)
    g = asset("Boat")
    g("Boat").box((0, 0, 1.2), (5, 14, 2.4))
    g("Boat").cyl((0, -7, 1.2), (0, -9.5, 1.2), 2.4, sides=4, r2=0.2)
    g("Wood").box((0, 0, 2.5), (4.4, 13, 0.3))
    g("Wood").cyl((0, 1, 2.5), (0, 1, 13), 0.2, sides=6)
    g("White").box((0, 2.5, 7.5), (0.1, 5, 9), rot=(0, 0, 0))
    g("Red").box((0, 0, 0.3), (5.1, 14.1, 0.6))
    g = asset("SeaRocks")
    for k in range(3):
        g("RockDark").sphere((rng.uniform(-4, 4), rng.uniform(-4, 4), 0), rng.uniform(2, 3.5), scale=(1, 1, 0.8), sub=1)


# ---- Clouds ---------------------------------------------------------------------------------------------------
def clouds():
    g = asset("CloudPuff")
    for k in range(6):
        g("Cloud").sphere((rng.uniform(-8, 8), rng.uniform(-4, 4), rng.uniform(0, 3)), rng.uniform(4, 6.5), scale=(1.2, 1, 0.8), sub=2)
    g = asset("FloatingIsland")
    g("Grass").cyl((0, 0, 0), (0, 0, 1.5), 12, sides=12)
    g("Rock").cyl((0, 0, -10), (0, 0, 0), 2, sides=12, r2=11.5)
    tree_round(g, h=11, r=4)
    g("Cloud").sphere((8, 6, -2), 3, scale=(1.5, 1, 0.7), sub=2)
    g = asset("Rainbow")
    bands = ["R1", "R2", "R3", "R4", "R5", "R6"]
    for i, band in enumerate(bands):
        r = 40 - i * 2
        for k in range(18):
            a0, a1 = math.pi * k / 18, math.pi * (k + 1) / 18
            g(band).cyl((math.cos(a0) * r, 0, math.sin(a0) * r), (math.cos(a1) * r, 0, math.sin(a1) * r), 1.05, sides=4)
    g("Cloud").sphere((-38, 0, 0), 7, scale=(1.3, 1, 0.8), sub=2)
    g("Cloud").sphere((38, 0, 0), 7, scale=(1.3, 1, 0.8), sub=2)
    g = asset("CloudCastle")
    g("Cloud").sphere((0, 0, 0), 30, scale=(1.4, 1.2, 0.35), sub=3)
    g("Castle").box((0, 0, 14), (30, 24, 20))
    for x in (-15, 15):
        for y in (-12, 12):
            g("Castle").cyl((x, y, 4), (x, y, 34), 4, sides=12)
            g("Roof2").cyl((x, y, 34), (x, y, 44), 5, sides=12, r2=0)
            g("Gold").sphere((x, y, 44.5), 0.8, sub=1)
    g("Castle").cyl((0, 0, 24), (0, 0, 48), 6, sides=14)
    g("Roof2").cyl((0, 0, 48), (0, 0, 62), 7.5, sides=14, r2=0)
    g("Gold").box((0, -12.2, 10), (6, 0.4, 10))
    g("Red").box((0, 0, 66), (0.2, 4, 2.4))


# ---- build / export / preview ---------------------------------------------------------------------------------
def material(name):
    mat = bpy.data.materials.get("M_" + name)
    if mat:
        return mat
    mat = bpy.data.materials.new("M_" + name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*COL.get(name, (0.5, 0.5, 0.5)), 1)
    bsdf.inputs["Roughness"].default_value = 0.7
    return mat


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    town()
    farm()
    desert()
    sea()
    clouds()
    objs = {}
    for name, groups in ASSETS.items():
        objs[name] = []
        for group, gb in groups.items():
            bmesh.ops.remove_doubles(gb.bm, verts=gb.bm.verts, dist=0.0005)
            me = bpy.data.meshes.new(f"{name}__{group}")
            gb.bm.to_mesh(me)
            gb.bm.free()
            o = bpy.data.objects.new(f"{name}__{group}", me)
            bpy.context.collection.objects.link(o)
            me.materials.append(material(group))
            objs[name].append(o)
        tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs[name])
        print(f"[scenery] {name}: {len(groups)} groups, {tris} tris", flush=True)
    every = [o for lst in objs.values() for o in lst]
    bpy.ops.object.select_all(action="DESELECT")
    for o in every:
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
    try:
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))
    except Exception as err:
        print("[scenery] smooth by angle unavailable:", err)
    if PREVIEW:
        scene = bpy.context.scene
        engines = bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items.keys()
        scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
        scene.render.resolution_x = scene.render.resolution_y = 300
        scene.render.film_transparent = True
        scene.view_settings.view_transform = "Standard"
        scene.world = bpy.data.worlds.new("w")
        scene.world.use_nodes = True
        next(n for n in scene.world.node_tree.nodes if n.type == "BACKGROUND").inputs["Strength"].default_value = 0.6
        sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
        sun.data.energy = 4
        sun.rotation_euler = (math.radians(50), 0, math.radians(-40))
        scene.collection.objects.link(sun)
        cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
        scene.collection.objects.link(cam)
        scene.camera = cam
        os.makedirs(os.path.join(OUT, "preview"), exist_ok=True)
        for name, lst in objs.items():
            for o in every:
                o.hide_render = o not in lst
            pts = [o.matrix_world @ Vector(c) for o in lst for c in o.bound_box]
            lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
            hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
            centre, radius = (lo + hi) / 2, (hi - lo).length / 2
            cam.location = centre + Vector((0.55, -0.75, 0.4)).normalized() * radius * 3
            cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
            scene.render.filepath = os.path.join(OUT, "preview", name + ".png")
            bpy.ops.render.render(write_still=True)
        for o in every:
            o.hide_render = False
    bpy.ops.object.select_all(action="DESELECT")
    for o in every:
        o.select_set(True)
    path = os.path.join(OUT, "SceneryKit.fbx")
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"MESH"}, use_triangles=True,
                             global_scale=0.01, apply_unit_scale=True, path_mode="STRIP")
    print("[scenery] saved", path, flush=True)


main()
