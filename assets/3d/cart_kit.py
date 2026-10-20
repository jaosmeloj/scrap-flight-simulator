"""Blender headless: the whole Scrap Flight Simulator kit in ONE FBX (one Import 3D in Studio).

Every mesh is named "<Asset>__<Group>" and sits at the world origin with its geometry in the asset's own frame,
so after the import each MeshPart's origin (Position + PivotOffset) is the asset's mount point:
  Cart_<Id>   cart bodies (origin = centre of the invisible Root slider, bottom at z = -0.5)
  Engine1..5  (origin = mount at the back of the basket, model extends to +Y = the back)
  Wings1..5   (origin = mount at the middle of the basket, spans along X)
  Rocket1..5  (origin = mount under the back; a "Nozzle" group marks each exhaust)
  Wheels0..4  (origin = Root centre; four wheels)
  Tank1..5    (origin = mount under the nose of the basket, the tank hangs in front: -Y)
  Tail1..5    (origin = mount behind the handle; shown with the matching Wings tier)
  Icon_<Name> flat cards with the shop icon texture (embedded) -> TextureID gives the image id after the import
Groups get a Roblox Material + Color from src/shared/Config/CartLooks.luau (the preview colours below only mimic it).

Units: studs. Blender -Y = Roblox front (-Z). Z up.

Usage:
  blender -b -P cart_kit.py -- <out_dir> [--preview] [--icons]
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
OUT = os.path.abspath(argv[0] if argv else "out")
PREVIEW = "--preview" in argv
ICONS = "--icons" in argv
os.makedirs(OUT, exist_ok=True)

# preview colours per group (Roblox look comes from Config/CartLooks)
COL = {
    "Frame": (0.45, 0.47, 0.52),
    "Wire": (0.55, 0.57, 0.62),
    "Accent": (0.75, 0.03, 0.02),
    "Grip": (0.75, 0.03, 0.02),
    "Rubber": (0.03, 0.03, 0.035),
    "Hub": (0.6, 0.6, 0.62),
    "Body": (0.12, 0.13, 0.17),
    "Metal": (0.25, 0.26, 0.3),
    "Dark": (0.04, 0.04, 0.05),
    "Blade": (0.35, 0.18, 0.06),
    "Panel": (0.04, 0.4, 0.1),
    "Gold": (1.0, 0.55, 0.05),
    "Gem": (0.05, 0.3, 1.0),
    "Cardboard": (0.5, 0.3, 0.12),
    "Tape": (0.75, 0.7, 0.5),
    "Wood": (0.4, 0.2, 0.07),
    "Fabric": (0.9, 0.85, 0.7),
    "Nozzle": (0.03, 0.03, 0.03),
    "Glass": (0.3, 0.6, 1.0),
    "TankRed": (0.7, 0.04, 0.02),
    "TankBlue": (0.03, 0.15, 0.6),
    "Lamp": (1.0, 0.85, 0.4),
    "Horn": (0.85, 0.8, 0.65),
    "SirenRed": (1.0, 0.05, 0.05),
    "SirenBlue": (0.05, 0.2, 1.0),
}


# --------------------------------------------------------------------------------------------- geometry helpers


class G:
    """One mesh group being built."""

    def __init__(self):
        self.bm = bmesh.new()

    def add_bm(self, tmp, matrix=None):
        if matrix is not None:
            bmesh.ops.transform(tmp, matrix=matrix, verts=tmp.verts)
        me = bpy.data.meshes.new("tmp")
        tmp.to_mesh(me)
        tmp.free()
        self.bm.from_mesh(me)
        bpy.data.meshes.remove(me)

    def box(self, center, size, rot=(0, 0, 0)):
        tmp = bmesh.new()
        bmesh.ops.create_cube(tmp, size=1)
        m = (
            Matrix.Translation(Vector(center))
            @ Matrix.Rotation(math.radians(rot[2]), 4, "Z")
            @ Matrix.Rotation(math.radians(rot[1]), 4, "Y")
            @ Matrix.Rotation(math.radians(rot[0]), 4, "X")
            @ Matrix.Diagonal((*size, 1))
        )
        self.add_bm(tmp, m)

    def cyl(self, a, b, r, sides=12, r2=None, cap=True):
        """Cylinder (or cone with r2) from point a to point b."""
        a, b = Vector(a), Vector(b)
        d = b - a
        tmp = bmesh.new()
        bmesh.ops.create_cone(
            tmp, cap_ends=cap, cap_tris=False, segments=sides, radius1=r, radius2=r if r2 is None else r2, depth=d.length
        )
        rot = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix().to_4x4()
        self.add_bm(tmp, Matrix.Translation((a + b) / 2) @ rot)

    def bar(self, a, b, w):
        """Thin square bar (wire) from a to b."""
        self.cyl(a, b, w, sides=4)

    def sphere(self, c, r, scale=(1, 1, 1), sub=2):
        tmp = bmesh.new()
        bmesh.ops.create_icosphere(tmp, subdivisions=sub, radius=r)
        self.add_bm(tmp, Matrix.Translation(Vector(c)) @ Matrix.Diagonal((*scale, 1)))

    def torus(self, c, axis, R, r, seg=20, sides=8):
        """Ring around `axis` ('x' or 'y' or 'z')."""
        tmp = bmesh.new()
        verts = []
        for i in range(seg):
            a = 2 * math.pi * i / seg
            ring = []
            for k in range(sides):
                b = 2 * math.pi * k / sides
                x = (R + r * math.cos(b)) * math.cos(a)
                y = (R + r * math.cos(b)) * math.sin(a)
                z = r * math.sin(b)
                ring.append(tmp.verts.new((x, y, z)))
            verts.append(ring)
        for i in range(seg):
            for k in range(sides):
                i2, k2 = (i + 1) % seg, (k + 1) % sides
                tmp.faces.new((verts[i][k], verts[i2][k], verts[i2][k2], verts[i][k2]))
        rot = {"z": Matrix.Identity(4), "x": Matrix.Rotation(math.pi / 2, 4, "Y"), "y": Matrix.Rotation(math.pi / 2, 4, "X")}[axis]
        self.add_bm(tmp, Matrix.Translation(Vector(c)) @ rot)

    def prism(self, outline, y0, y1):
        """Extrude a convex XZ outline between y0 and y1."""
        tmp = bmesh.new()
        f = [tmp.verts.new((x, y0, z)) for x, z in outline]
        b = [tmp.verts.new((x, y1, z)) for x, z in outline]
        n = len(outline)
        tmp.faces.new(f)
        tmp.faces.new(list(reversed(b)))
        for i in range(n):
            j = (i + 1) % n
            tmp.faces.new((f[i], b[i], b[j], f[j]))
        bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
        self.add_bm(tmp)

    def wing(self, root_x, tip_x, chord_root, chord_tip, sweep, thick, z, dihedral=0.0, y=0.0):
        """Flat wing panel from x=root_x to tip_x (sign gives the side); sweep moves the tip back (+Y)."""
        side = 1 if tip_x > root_x else -1
        span = abs(tip_x - root_x)
        dz = math.tan(math.radians(dihedral)) * span
        pts = [
            (root_x, y - chord_root / 2, z),
            (root_x, y + chord_root / 2, z),
            (tip_x, y + sweep + chord_tip / 2, z + dz),
            (tip_x, y + sweep - chord_tip / 2, z + dz),
        ]
        tmp = bmesh.new()
        top = [tmp.verts.new((px, py, pz + thick / 2)) for px, py, pz in pts]
        bot = [tmp.verts.new((px, py, pz - thick / 2)) for px, py, pz in pts]
        tmp.faces.new(top if side > 0 else list(reversed(top)))
        tmp.faces.new(list(reversed(bot)) if side > 0 else bot)
        for i in range(4):
            j = (i + 1) % 4
            tmp.faces.new((top[i], bot[i], bot[j], top[j]))
        bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
        self.add_bm(tmp)


ASSETS = {}  # asset name -> {group: G}


def asset(name):
    groups = {}
    ASSETS[name] = groups

    def g(group):
        if group not in groups:
            groups[group] = G()
        return groups[group]

    return g


# --------------------------------------------------------------------------------------------- cart bodies
# Root: 4.6 wide (X), 6.4 long (Y), 1 tall, centre at origin. Basket floor at z = 1.1, rim at z = 4.


def wire_basket(g, wire, rim, x_bot, x_top, y_front_bot, y_front_top, y_back, z_bot, z_top, step=0.45, w=0.035):
    """Classic cart basket: tapered, wire grid on 4 sides + floor, tube rim."""

    def lerp(a, b, t):
        return a + (b - a) * t

    # rim and bottom frame
    top = [(-x_top, y_front_top), (x_top, y_front_top), (x_top, y_back), (-x_top, y_back)]
    bot = [(-x_bot, y_front_bot), (x_bot, y_front_bot), (x_bot, y_back), (-x_bot, y_back)]
    for i in range(4):
        j = (i + 1) % 4
        g(rim).cyl((top[i][0], top[i][1], z_top), (top[j][0], top[j][1], z_top), 0.09, sides=8)
        g(rim).cyl((bot[i][0], bot[i][1], z_bot), (bot[j][0], bot[j][1], z_bot), 0.07, sides=8)
        g(rim).cyl((bot[i][0], bot[i][1], z_bot), (top[i][0], top[i][1], z_top), 0.07, sides=8)
    # vertical wires on each side
    for i in range(4):
        j = (i + 1) % 4
        length = math.dist(top[i], top[j])
        n = max(2, int(length / step))
        for k in range(1, n):
            t = k / n
            a = (lerp(bot[i][0], bot[j][0], t), lerp(bot[i][1], bot[j][1], t), z_bot)
            b = (lerp(top[i][0], top[j][0], t), lerp(top[i][1], top[j][1], t), z_top)
            g(wire).bar(a, b, w)
    # horizontal wires
    levels = max(2, int((z_top - z_bot) / step))
    for k in range(1, levels):
        t = k / levels
        z = lerp(z_bot, z_top, t)
        ring = [(lerp(bot[i][0], top[i][0], t), lerp(bot[i][1], top[i][1], t)) for i in range(4)]
        for i in range(4):
            j = (i + 1) % 4
            g(wire).bar((ring[i][0], ring[i][1], z), (ring[j][0], ring[j][1], z), w)
    # floor grid
    n = int((y_back - y_front_bot) / step)
    for k in range(n + 1):
        y = lerp(y_front_bot, y_back, k / n)
        g(wire).bar((-x_bot, y, z_bot), (x_bot, y, z_bot), w)
    for k in range(int(2 * x_bot / step) + 1):
        x = -x_bot + k * step
        g(wire).bar((x, y_front_bot, z_bot), (x, y_back, z_bot), w)


def chassis(g, frame, tube=0.12):
    for x in (-1.9, 1.9):
        g(frame).cyl((x, -3.0, 0.15), (x, 3.0, 0.15), tube, sides=8)
    for y in (-3.0, 3.0):
        g(frame).cyl((-1.9, y, 0.15), (1.9, y, 0.15), tube, sides=8)
    # legs from chassis up to the basket
    for x in (-1.7, 1.7):
        for y in (-2.4, 2.6):
            g(frame).cyl((x, y, 0.15), (x * 0.95, y, 1.1), tube * 0.8, sides=8)


def handle(g, frame, grip, z=4.9, y=3.75, width=2.1):
    for x in (-1.95, 1.95):
        g(frame).cyl((x, 3.15, 3.9), (x, y, z), 0.09, sides=8)
    g(grip).cyl((-width, y, z), (width, y, z), 0.17, sides=12)


def cart_basic():
    g = asset("Cart_Basic")
    chassis(g, "Frame")
    wire_basket(g, "Wire", "Frame", 1.95, 2.3, -2.4, -3.1, 3.15, 1.1, 4.0)
    handle(g, "Frame", "Grip")
    # plastic corner bumpers + front badge
    for x in (-2.3, 2.3):
        g("Accent").box((x, -3.1, 4.0), (0.3, 0.3, 0.3))
    g("Accent").box((0, -3.12, 3.2), (1.4, 0.08, 0.7), rot=(-14, 0, 0))
    # child seat flap
    g("Accent").box((0, 2.75, 3.3), (2.4, 0.1, 1.2), rot=(18, 0, 0))


def cart_market():
    g = asset("Cart_Market")
    chassis(g, "Frame")
    # solid plastic tub with slots
    def panel(outline_pts, y0, y1):
        g("Panel").prism(outline_pts, y0, y1)

    g("Panel").box((0, 0.2, 1.1), (4.0, 5.6, 0.2))
    for x in (-2.15, 2.15):
        g("Panel").box((x, 0.1, 2.6), (0.18, 6.2, 3.0), rot=(0, x * -2.5, 0))
        for k in range(4):
            g("Dark").box((x * 1.03, -2.0 + k * 1.3, 2.9), (0.08, 0.9, 1.6))
    g("Panel").box((0, -3.0, 2.6), (4.4, 0.18, 3.0), rot=(-10, 0, 0))
    g("Panel").box((0, 3.1, 2.6), (4.4, 0.18, 3.0))
    for k in range(3):
        g("Dark").box((-1.3 + k * 1.3, -3.12, 2.8), (0.9, 0.08, 1.6), rot=(-10, 0, 0))
    g("Frame").cyl((-2.3, -3.25, 4.1), (2.3, -3.25, 4.1), 0.12, sides=8)
    g("Frame").cyl((-2.3, 3.15, 4.1), (2.3, 3.15, 4.1), 0.12, sides=8)
    handle(g, "Frame", "Grip")
    g("Accent").box((0, -3.3, 3.3), (1.6, 0.1, 0.8), rot=(-10, 0, 0))


def cart_industrial():
    g = asset("Cart_Industrial")
    chassis(g, "Frame", tube=0.18)
    g("Panel").box((0, 0.1, 1.15), (4.5, 6.3, 0.3))  # steel deck
    # heavy cage
    for x in (-2.15, 2.15):
        for y in (-2.9, 0.1, 3.0):
            g("Frame").cyl((x, y, 1.3), (x, y, 4.3), 0.16, sides=8)
        for z in (2.3, 3.3, 4.3):
            g("Frame").cyl((x, -2.9, z), (x, 3.0, z), 0.12, sides=8)
    for y in (-2.9, 3.0):
        for z in (2.3, 3.3, 4.3):
            g("Frame").cyl((-2.15, y, z), (2.15, y, z), 0.12, sides=8)
    for x in (-1.4, -0.7, 0, 0.7, 1.4):
        g("Wire").bar((x, -2.9, 1.3), (x, -2.9, 4.3), 0.06)
    # yellow/black hazard plates
    for k in range(5):
        g("Accent" if k % 2 == 0 else "Dark").box((-1.8 + k * 0.9, -3.15, 1.05), (0.9, 0.12, 0.5))
    handle(g, "Frame", "Grip", z=5.0)


def cart_racing():
    g = asset("Cart_Racing")
    chassis(g, "Frame")
    wire_basket(g, "Wire", "Frame", 1.95, 2.15, -2.2, -2.6, 3.15, 1.1, 3.3, step=0.55)
    # nose fairing
    g("Accent").sphere((0, -3.3, 1.7), 1.0, scale=(2.0, 1.3, 0.75), sub=2)
    # side pods with stripes
    for x in (-2.45, 2.45):
        g("Accent").box((x, 0.2, 1.7), (0.5, 5.4, 1.2))
        g("Panel").box((x * 1.06, 0.2, 1.9), (0.08, 5.0, 0.25))
    # spoiler
    for x in (-1.3, 1.3):
        g("Frame").cyl((x, 3.3, 3.3), (x, 3.7, 5.3), 0.1, sides=8)
    g("Accent").box((0, 3.8, 5.4), (4.6, 1.2, 0.15), rot=(-8, 0, 0))
    for x in (-2.35, 2.35):
        g("Dark").box((x, 3.8, 5.2), (0.12, 1.3, 0.8))
    handle(g, "Frame", "Grip", z=4.6)
    g("Glass").box((0, -2.9, 3.55), (2.6, 0.1, 0.8), rot=(-35, 0, 0))


def cart_golden():
    g = asset("Cart_Golden")
    chassis(g, "Gold")
    wire_basket(g, "Gold", "Gold", 1.95, 2.35, -2.4, -3.15, 3.15, 1.1, 4.0, step=0.4, w=0.045)
    handle(g, "Gold", "Accent")
    # crown spikes on the corners, gem on the front
    for x, y in ((-2.35, -3.15), (2.35, -3.15), (-2.35, 3.15), (2.35, 3.15)):
        g("Gold").cyl((x, y, 4.0), (x, y, 4.8), 0.18, sides=8, r2=0.0)
        g("Gem").sphere((x, y, 4.85), 0.14, sub=1)
    g("Gem").sphere((0, -3.2, 3.0), 0.45, scale=(1, 0.5, 1.2), sub=1)
    g("Gold").torus((0, -3.15, 3.0), "y", 0.6, 0.08)


# --------------------------------------------------------------------------------------------- parts


def engines():
    # 1: fan motor with cooling fins, wooden prop and a round guard
    g = asset("Engine1")
    g("Metal").box((0, 0.15, -0.1), (0.9, 0.5, 0.35))  # bracket
    g("Body").cyl((0, 0.3, 0.35), (0, 1.3, 0.35), 0.55, sides=16)
    for k in range(5):
        g("Metal").cyl((0, 0.45 + k * 0.18, 0.35), (0, 0.52 + k * 0.18, 0.35), 0.65, sides=16)
    g("Dark").cyl((0, 1.3, 0.35), (0, 1.75, 0.35), 0.1, sides=8)
    for a_ in (0, 180):
        g("Blade").box((0, 1.75, 0.35), (2.4, 0.1, 0.36), rot=(0, a_ + 20, 0))
    g("Accent").sphere((0, 1.82, 0.35), 0.18, sub=1)
    g("Metal").torus((0, 1.75, 0.35), "y", 1.35, 0.05, seg=28, sides=6)
    for a_ in (45, 135):
        g("Metal").box((0, 1.75, 0.35), (2.7, 0.05, 0.05), rot=(0, a_, 0))
    # 2: turbofan in a nacelle
    g = asset("Engine3")
    g("Metal").box((0, 0.15, -0.2), (0.6, 0.5, 0.5))
    g("Body").cyl((0, 0.4, 0.3), (0, 2.8, 0.3), 0.85, sides=20, cap=False)
    g("Body").cyl((0, 0.4, 0.3), (0, 2.8, 0.3), 0.75, sides=20, cap=False)
    g("Metal").torus((0, 0.4, 0.3), "y", 0.8, 0.1, seg=24)
    for k in range(10):
        a = k / 10 * 360
        g("Blade").box((0, 0.7, 0.3), (0.12, 0.08, 1.4), rot=(0, a, 0))
    g("Accent").cyl((0, 0.6, 0.3), (0, 0.4, 0.3), 0.25, sides=12, r2=0.05)
    g("Dark").cyl((0, 2.8, 0.3), (0, 3.3, 0.3), 0.7, sides=16, r2=0.45, cap=False)
    g("Accent").cyl((0, 1.6, 0.3), (0, 1.9, 0.3), 0.87, sides=20)
    # 3: jet with intake spike and afterburner
    g = asset("Engine5")
    g("Metal").box((0, 0.3, -0.25), (0.7, 0.8, 0.6))
    g("Body").cyl((0, 0.2, 0.45), (0, 3.6, 0.45), 1.05, sides=24, r2=0.95)
    g("Accent").cyl((0, 1.2, 0.45), (0, 1.5, 0.45), 1.07, sides=24)
    g("Accent").cyl((0, 2.4, 0.45), (0, 2.6, 0.45), 1.02, sides=24)
    g("Metal").cyl((0, -0.4, 0.45), (0, 0.2, 0.45), 0.35, sides=16, r2=0.7)  # intake spike
    g("Metal").cyl((0, -0.9, 0.45), (0, -0.4, 0.45), 0.02, sides=16, r2=0.35)
    g("Dark").cyl((0, 3.6, 0.45), (0, 4.4, 0.45), 0.95, sides=24, r2=0.8, cap=False)
    g("Nozzle").torus((0, 4.4, 0.45), "y", 0.8, 0.12, seg=24)


def wings():
    # base span per side; the game scales the model with the level inside each tier
    # 1: cardboard wings taped on
    g = asset("Wings1")
    for s in (-1, 1):
        g("Cardboard").wing(s * 2.2, s * 5.6, 2.6, 2.0, 0.3, 0.16, 0.0)
        for k in range(3):
            g("Tape").box((s * (2.6 + k * 1.2), 0.0, 0.09), (0.25, 2.5, 0.03))
    # 2: wooden glider wings with fabric and struts
    g = asset("Wings3")
    for s in (-1, 1):
        g("Fabric").wing(s * 2.2, s * 6.6, 2.8, 1.8, 0.6, 0.12, 0.2, dihedral=6)
        g("Wood").cyl((s * 2.2, -1.0, 0.25), (s * 6.6, -0.6, 0.2 + math.tan(math.radians(6)) * 4.4 + 0.05), 0.09, sides=6)
        for k in range(5):
            x = s * (2.6 + k * 0.95)
            zz = 0.2 + math.tan(math.radians(6)) * abs(x - s * 2.2)
            g("Wood").box((x, 0.1, zz + 0.07), (0.08, 2.6 - k * 0.18, 0.06))
        g("Wood").cyl((s * 2.3, 0, -1.2), (s * 4.8, 0.2, 0.45), 0.07, sides=6)  # strut
    # 3: swept jet wings with winglets
    g = asset("Wings5")
    for s in (-1, 1):
        g("Body").wing(s * 2.2, s * 7.4, 3.4, 1.2, 2.2, 0.22, 0.0)
        g("Accent").wing(s * 5.8, s * 7.4, 0.5, 0.4, 0.8, 0.24, 0.0, y=1.6)
        g("Accent").box((s * 7.4, 2.4, 0.7), (0.12, 1.2, 1.4), rot=(15, 0, 0))
        g("Dark").cyl((s * 4.5, 1.6, -0.25), (s * 4.5, 2.6, -0.25), 0.18, sides=8)


def rockets():
    # 1: firework
    g = asset("Rocket1")
    g("Accent").cyl((0, -0.6, 0), (0, 1.6, 0), 0.38, sides=14)
    g("Tape").cyl((0, 0.2, 0), (0, 0.5, 0), 0.4, sides=14)
    g("Gold").cyl((0, -1.3, 0), (0, -0.6, 0), 0.0, sides=14, r2=0.38)
    g("Wood").cyl((0.45, -0.2, 0), (0.45, 2.6, 0), 0.05, sides=6)
    g("Nozzle").cyl((0, 1.6, 0), (0, 1.75, 0), 0.25, sides=10)
    # 2: steel rocket with fins
    g = asset("Rocket3")
    g("Body").cyl((0, -0.4, 0), (0, 2.4, 0), 0.55, sides=18)
    g("Accent").cyl((0, -1.3, 0), (0, -0.4, 0), 0.0, sides=18, r2=0.55)
    for k in range(4):
        a = k * 90 + 45
        g("Accent").box((0, 2.0, 0), (0.08, 0.9, 1.9), rot=(0, a, 0))
    g("Dark").cyl((0, 2.4, 0), (0, 2.9, 0), 0.35, sides=16, r2=0.5, cap=False)
    g("Nozzle").torus((0, 2.9, 0), "y", 0.45, 0.06, seg=16)
    # 3: twin boosters
    g = asset("Rocket5")
    for x in (-0.75, 0.75):
        g("Body").cyl((x, -0.6, 0), (x, 3.0, 0), 0.62, sides=18)
        g("Accent").cyl((x, -1.6, 0), (x, -0.6, 0), 0.0, sides=18, r2=0.62)
        g("Accent").cyl((x, 1.0, 0), (x, 1.3, 0), 0.64, sides=18)
        g("Dark").cyl((x, 3.0, 0), (x, 3.7, 0), 0.4, sides=16, r2=0.6, cap=False)
        g("Nozzle").torus((x, 3.7, 0), "y", 0.55, 0.07, seg=16)
        g("Accent").box((x * 1.8, 2.6, 0), (0.6, 1.0, 0.08))
    g("Metal").box((0, 1.2, 0.2), (1.0, 2.0, 0.5))


def wheels():
    spots = [(x, y) for x in (-1.8, 1.8) for y in (-2.6, 2.6)]

    def wheel(g, x, y, r, w, hub_r, rim=False, knobs=False, fork=True):
        cz = -0.5 + r
        g("Rubber").cyl((x - w / 2, y, cz), (x + w / 2, y, cz), r, sides=18)
        g("Hub").cyl((x - w / 2 - 0.02, y, cz), (x + w / 2 + 0.02, y, cz), hub_r, sides=14)
        if rim:
            for k in range(5):
                a = k / 5 * 360
                g("Hub").box((x, y, cz), (w * 0.9, 0.08, r * 1.5), rot=(a, 0, 0))
        if knobs:
            for k in range(14):
                a = 2 * math.pi * k / 14
                g("Rubber").box((x, y + math.cos(a) * r, cz + math.sin(a) * r), (w * 1.05, 0.18, 0.18), rot=(math.degrees(a), 0, 0))
        if fork:
            for s in (-1, 1):
                g("Frame").box((x + s * (w / 2 + 0.08), y, (cz + 0.15) / 2 + 0.05), (0.06, 0.2, max(0.25, 0.15 - cz + 0.1)))
            g("Frame").box((x, y, 0.15), (w + 0.3, 0.25, 0.08))

    g = asset("Wheels0")  # supermarket casters
    for x, y in spots:
        wheel(g, x, y, 0.42, 0.28, 0.16)
    g = asset("Wheels1")  # chunky rubber
    for x, y in spots:
        wheel(g, x, y, 0.58, 0.5, 0.26)
    g = asset("Wheels2")  # off-road knobbies
    for x, y in spots:
        wheel(g, x, y, 0.66, 0.6, 0.3, knobs=True)
    g = asset("Wheels3")  # monster truck: big, wide, knobby
    for x, y in spots:
        wheel(g, x, y, 0.85, 0.8, 0.34, knobs=True, fork=False)
        g("Frame").box((x, y, 0.35), (0.9, 0.35, 0.14))
    g = asset("Wheels4")  # racing rims
    for x, y in spots:
        wheel(g, x, y, 0.62, 0.55, 0.42, rim=True, fork=False)
        g("Frame").box((x, y, 0.15), (0.6, 0.3, 0.12))


def tanks():
    # 1: red jerry can
    g = asset("Tank1")
    g("TankRed").box((0, -0.45, 0), (1.1, 0.55, 1.35))
    for z in (-0.35, 0.0, 0.35):
        g("TankRed").box((0, -0.74, z), (0.9, 0.06, 0.12))  # pressed ribs
    g("TankRed").box((0, -0.45, 0.82), (0.7, 0.18, 0.12))  # handle bar
    for x in (-0.3, 0.3):
        g("TankRed").box((x, -0.45, 0.74), (0.12, 0.18, 0.2))
    g("Metal").cyl((0.42, -0.45, 0.62), (0.55, -0.45, 0.98), 0.1, sides=10)  # spout
    g("Dark").cyl((0.55, -0.45, 0.98), (0.58, -0.45, 1.05), 0.12, sides=10)
    g("Metal").box((0, -0.1, 0), (0.5, 0.25, 0.25))  # bracket
    # 2: two gas bottles with valves
    g = asset("Tank3")
    for x in (-0.55, 0.55):
        g("TankBlue").cyl((x, -0.5, -0.65), (x, -0.5, 0.55), 0.45, sides=18)
        g("TankBlue").sphere((x, -0.5, 0.55), 0.45, scale=(1, 1, 0.55), sub=2)
        g("TankBlue").sphere((x, -0.5, -0.65), 0.45, scale=(1, 1, 0.45), sub=2)
        g("Metal").cyl((x, -0.5, 0.75), (x, -0.5, 0.98), 0.12, sides=10)
        g("Dark").box((x, -0.5, 1.0), (0.32, 0.08, 0.08))
        g("Metal").cyl((x, -0.5, 0.1), (x, -0.5, 0.25), 0.47, sides=18)  # strap
    g("Metal").box((0, -0.12, 0), (1.6, 0.25, 0.3))
    g("Dark").cyl((-0.55, -0.5, 0.98), (0.55, -0.5, 0.98), 0.05, sides=6)  # pipe joining the valves
    # 3: big steel drum across the nose, with hoses
    g = asset("Tank5")
    g("Metal").cyl((-1.6, -0.75, 0), (1.6, -0.75, 0), 0.75, sides=24)
    for x in (-1.0, 0.0, 1.0):
        g("Accent").cyl((x - 0.08, -0.75, 0), (x + 0.08, -0.75, 0), 0.78, sides=24)
    for x in (-1.6, 1.6):
        g("Dark").cyl((x, -0.75, 0), (x * 1.04, -0.75, 0), 0.6, sides=20)
    g("Dark").cyl((0.6, -0.75, 0.72), (0.6, -0.75, 0.95), 0.14, sides=10)
    g("Dark").cyl((0.6, -0.75, 0.95), (0.6, 0.2, 1.2), 0.07, sides=8)  # hose to the engine
    g("Metal").box((0, -0.15, 0), (2.6, 0.3, 0.35))


def more_parts():
    """Second wave of tiers: Engine2/4, Wings2/4, Rocket2/4, Tank2/4 and the tails (Tail1..5 match Wings1..5)."""
    # Engine2: lawnmower motor with a pull cord and a 3-blade prop
    g = asset("Engine2")
    g("Metal").box((0, 0.15, -0.15), (0.9, 0.5, 0.35))
    g("Body").box((0, 0.75, 0.3), (1.3, 1.0, 1.0))
    g("Accent").cyl((0.35, 0.6, 0.8), (0.35, 0.6, 0.95), 0.18, sides=12)  # fuel cap
    g("Dark").cyl((-0.66, 0.6, 0.4), (-0.95, 0.6, 0.4), 0.2, sides=12)  # pull-cord housing
    g("Dark").box((-1.0, 0.6, 0.4), (0.08, 0.5, 0.12))  # handle
    for k in range(6):
        g("Metal").box((0, 0.45 + k * 0.12, 0.82), (1.1, 0.04, 0.05))  # cooling fins
    g("Dark").cyl((0, 1.25, 0.3), (0, 1.6, 0.3), 0.1, sides=8)
    for a in (0, 120, 240):
        g("Blade").box((0, 1.65, 0.3), (2.2, 0.08, 0.3), rot=(0, a + 10, 0))
    g("Accent").sphere((0, 1.72, 0.3), 0.16, sub=1)

    # Engine4: V8 with chrome blower, side exhausts and a big 4-blade prop
    g = asset("Engine4")
    g("Metal").box((0, 0.2, -0.2), (1.0, 0.6, 0.5))
    g("Body").box((0, 1.1, 0.25), (1.2, 1.9, 0.9))  # block
    for side in (-1, 1):
        g("Body").box((side * 0.55, 1.1, 0.85), (0.6, 1.8, 0.6), rot=(0, side * 25, 0))  # cylinder banks
        for k in range(4):
            y = 0.5 + k * 0.42
            g("Dark").cyl((side * 0.9, y, 0.85), (side * 1.45, y, 0.7), 0.08, sides=8)  # headers
        g("Dark").cyl((side * 1.45, 0.4, 0.7), (side * 1.45, 2.4, 0.7), 0.13, sides=10)  # exhaust pipe
    g("Metal").box((0, 1.1, 1.45), (0.8, 1.2, 0.5))  # blower
    g("Accent").box((0, 0.7, 1.8), (0.5, 0.3, 0.3))  # scoop
    g("Dark").cyl((0, 2.05, 0.4), (0, 2.45, 0.4), 0.14, sides=10)
    for a in (0, 90, 180, 270):
        g("Blade").box((0, 2.5, 0.4), (2.9, 0.08, 0.34), rot=(0, a + 15, 0))
    g("Accent").sphere((0, 2.58, 0.4), 0.22, sub=1)

    # Wings2: two wooden doors bolted on as wings
    g = asset("Wings2")
    for s_ in (-1, 1):
        g("Wood").box((s_ * 3.9, 0, 0.0), (3.4, 2.4, 0.18), rot=(0, s_ * -4, 0))
        for k in (-0.55, 0.55):
            g("Dark").box((s_ * 3.9, k, 0.1), (3.0, 0.9, 0.02), rot=(0, s_ * -4, 0))  # panels
        g("Gold").sphere((s_ * 5.2, -0.9, 0.18), 0.1, sub=1)  # door knob
        g("Metal").box((s_ * 2.3, 0, 0.0), (0.3, 1.6, 0.25))  # hinge plate

    # Wings4: biplane, two stacked wings with struts and wires
    g = asset("Wings4")
    for s_ in (-1, 1):
        g("Fabric").wing(s_ * 2.2, s_ * 6.4, 2.6, 2.2, 0.3, 0.14, -0.3)
        g("Fabric").wing(s_ * 2.2, s_ * 6.4, 2.6, 2.2, 0.3, 0.14, 1.5)
        for x in (3.6, 5.6):
            g("Wood").cyl((s_ * x, -0.6, -0.3), (s_ * x, -0.5, 1.5), 0.07, sides=6)
            g("Wood").cyl((s_ * x, 0.7, -0.3), (s_ * x, 0.8, 1.5), 0.07, sides=6)
        g("Dark").cyl((s_ * 3.6, -0.6, -0.3), (s_ * 5.6, -0.5, 1.5), 0.02, sides=4)  # bracing wire
        g("Accent").wing(s_ * 5.6, s_ * 6.4, 2.25, 2.2, 0.3, 0.16, 1.5)  # coloured tips

    # Tails (mount behind the handle; the fin rises from the origin toward +Z, extends back to +Y)
    g = asset("Tail1")  # cardboard fin, taped
    g("Cardboard").prism([(-0.06, 0), (0.06, 0), (0.06, 1.8), (-0.06, 1.8)], 0, 1.6)
    g("Tape").box((0, 0.8, 0.9), (0.14, 1.7, 0.2))
    g = asset("Tail2")  # plank fin + a small plank stabilizer
    g("Wood").box((0, 0.9, 1.0), (0.14, 1.8, 2.0))
    g("Wood").box((0, 1.0, 0.15), (2.6, 1.4, 0.12))
    g("Metal").box((0, 0.3, 0.2), (0.3, 0.6, 0.4))
    g = asset("Tail3")  # glider: fabric fin and stabilizer on a wooden frame
    g("Fabric").wing(0, 1.6, 1.4, 0.8, 0.5, 0.1, 0.1, y=1.1)
    g("Fabric").wing(0, -1.6, 1.4, 0.8, 0.5, 0.1, 0.1, y=1.1)
    g("Fabric").prism([(-0.05, 0.1), (0.05, 0.1), (0.05, 2.0), (-0.05, 2.0)], 0.4, 1.8)
    g("Wood").cyl((0, 0.0, 0.1), (0, 2.0, 0.1), 0.08, sides=6)
    g("Wood").cyl((0, 0.5, 0.1), (0, 1.6, 2.0), 0.06, sides=6)
    g = asset("Tail4")  # biplane tail: striped fin, wide stabilizer
    g("Body").prism([(-0.08, 0.1), (0.08, 0.1), (0.08, 2.2), (-0.08, 2.2)], 0.3, 2.0)
    for z in (0.7, 1.3, 1.9):
        g("Accent").box((0, 1.15, z), (0.18, 1.7, 0.22))
    g("Fabric").wing(0, 2.0, 1.6, 1.0, 0.4, 0.12, 0.2, y=1.1)
    g("Fabric").wing(0, -2.0, 1.6, 1.0, 0.4, 0.12, 0.2, y=1.1)
    g = asset("Tail5")  # jet: twin canted fins and a swept stabilizer
    for s_ in (-1, 1):
        g("Body").box((s_ * 0.9, 1.2, 1.1), (0.14, 1.6, 2.0), rot=(0, s_ * 18, 0))
        g("Accent").box((s_ * 1.2, 1.5, 2.0), (0.16, 0.9, 0.3), rot=(0, s_ * 18, 0))
        g("Body").wing(s_ * 0.6, s_ * 2.6, 1.8, 0.8, 0.9, 0.14, 0.2, y=1.0)

    # Rocket2: two soda bottles strapped together
    g = asset("Rocket2")
    for x in (-0.5, 0.5):
        g("Glass").cyl((x, -0.3, 0), (x, 1.6, 0), 0.38, sides=16)
        g("Glass").cyl((x, -0.9, 0), (x, -0.3, 0), 0.12, sides=12, r2=0.38)
        g("Accent").cyl((x, -1.05, 0), (x, -0.9, 0), 0.14, sides=12)  # cap
        g("Accent").cyl((x, 0.4, 0), (x, 0.9, 0), 0.4, sides=16)  # label
        g("Nozzle").torus((x, 1.65, 0), "y", 0.25, 0.05, seg=14)
    g("Tape").box((0, 0.65, 0), (1.9, 0.25, 0.85))
    # Rocket4: three rockets in a frame
    g = asset("Rocket4")
    for x, z in ((-0.7, -0.1), (0.7, -0.1), (0, 0.55)):
        g("Body").cyl((x, -0.4, z), (x, 2.2, z), 0.36, sides=14)
        g("Accent").cyl((x, -1.1, z), (x, -0.4, z), 0.0, sides=14, r2=0.36)
        g("Dark").cyl((x, 2.2, z), (x, 2.6, z), 0.24, sides=12, r2=0.32, cap=False)
        g("Nozzle").torus((x, 2.6, z), "y", 0.28, 0.05, seg=14)
    for y in (0.2, 1.6):
        g("Metal").box((0, y, 0.15), (2.0, 0.15, 1.3))
    for x in (-0.95, 0.95):
        g("Accent").box((x * 1.15, 2.0, -0.1), (0.5, 0.8, 0.06))

    # Tank2: water cooler bottle
    g = asset("Tank2")
    g("Glass").cyl((0, -0.55, -0.6), (0, -0.55, 0.55), 0.55, sides=20)
    g("Glass").cyl((0, -0.55, 0.55), (0, -0.55, 0.85), 0.55, sides=20, r2=0.18)
    g("Glass").cyl((0, -0.55, 0.85), (0, -0.55, 1.05), 0.16, sides=12)
    g("Accent").cyl((0, -0.55, 1.05), (0, -0.55, 1.15), 0.2, sides=12)
    for z in (-0.3, 0.2):
        g("Glass").cyl((0, -0.55, z), (0, -0.55, z + 0.08), 0.58, sides=20)  # ridges
    g("Metal").box((0, -0.05, 0), (0.6, 0.3, 0.3))
    # Tank4: oil barrel with hazard band
    g = asset("Tank4")
    g("TankBlue").cyl((0, -0.7, -0.75), (0, -0.7, 0.75), 0.65, sides=20)
    for z in (-0.35, 0.35):
        g("Dark").cyl((0, -0.7, z - 0.04), (0, -0.7, z + 0.04), 0.68, sides=20)
    g("Accent").cyl((0, -0.7, -0.12), (0, -0.7, 0.12), 0.67, sides=20)
    g("Metal").cyl((0.3, -0.7, 0.75), (0.3, -0.7, 0.82), 0.1, sides=10)
    g("Metal").box((0, -0.05, 0), (0.6, 0.3, 0.3))


def accessories():
    """Garage accessories (Config/Customize.Accessories): origin = the mount point on the cart."""
    g = asset("AccAntenna")
    g("Dark").box((0, 0, 0.1), (0.3, 0.3, 0.2))
    g("Metal").cyl((0, 0, 0.1), (0, 0, 3.2), 0.04, sides=6)
    g("Accent").sphere((0, 0, 3.3), 0.25, sub=2)
    g = asset("AccFlag")
    g("Wood").cyl((0, 0, 0), (0, 0, 3.6), 0.07, sides=8)
    g("Gold").sphere((0, 0, 3.7), 0.15, sub=1)
    for k in range(6):  # waving cloth in strips
        y0 = 0.05 + k * 0.35
        g("Accent").box((0.0, y0 + 0.17, 3.0 + math.sin(k * 0.9) * 0.08), (0.04, 0.36, 1.1))
    g = asset("AccHeadlights")
    for x in (-1.3, 1.3):
        g("Dark").cyl((x, 0.2, 0), (x, -0.25, 0), 0.38, sides=16)
        g("Lamp").cyl((x, -0.25, 0), (x, -0.32, 0), 0.32, sides=16)
        g("Metal").box((x, 0.25, -0.35), (0.2, 0.2, 0.5))
    g("Metal").cyl((-1.3, 0.25, -0.5), (1.3, 0.25, -0.5), 0.05, sides=6)
    g = asset("AccHorns")
    g("Dark").box((0, 0, 0.1), (1.4, 0.4, 0.3))
    for s_ in (-1, 1):
        pts = [Vector((s_ * 0.6, 0, 0.2)), Vector((s_ * 1.5, -0.2, 0.5)), Vector((s_ * 2.1, -0.4, 1.2)), Vector((s_ * 2.0, -0.6, 1.9))]
        radii = [0.24, 0.18, 0.11, 0.02]
        for i in range(3):
            g("Horn").cyl(pts[i], pts[i + 1], radii[i], sides=10, r2=radii[i + 1])
    g = asset("AccSiren")
    g("Dark").box((0, 0, 0.1), (1.9, 0.6, 0.2))
    g("SirenRed").cyl((-0.5, 0, 0.2), (-0.5, 0, 0.75), 0.3, sides=14)
    g("SirenBlue").cyl((0.5, 0, 0.2), (0.5, 0, 0.75), 0.3, sides=14)
    g("Metal").box((0, 0, 0.5), (0.3, 0.3, 0.6))


def icon_models():
    """Icon-only models (not exported): one big wheel, one wing."""
    g = asset("IconWheel")
    g("Rubber").cyl((-0.45, 0, 0), (0.45, 0, 0), 1.2, sides=28)
    g("Hub").cyl((-0.5, 0, 0), (0.5, 0, 0), 0.6, sides=20)
    g("Accent").cyl((-0.55, 0, 0), (0.55, 0, 0), 0.22, sides=12)
    for k in range(16):
        a = 2 * math.pi * k / 16
        g("Rubber").box((0, math.cos(a) * 1.2, math.sin(a) * 1.2), (0.95, 0.28, 0.28), rot=(math.degrees(a), 0, 0))
    g = asset("IconWings")
    g("Fabric").wing(0, 4.6, 2.8, 1.6, 0.9, 0.16, 0, dihedral=8)
    g("Fabric").wing(0, -4.6, 2.8, 1.6, 0.9, 0.16, 0, dihedral=8)
    for s_ in (-1, 1):
        for k in range(5):
            x = s_ * (0.4 + k * 0.95)
            zz = math.tan(math.radians(8)) * abs(x)
            g("Wood").box((x, 0.15, zz + 0.09), (0.09, 2.7 - k * 0.22, 0.07))
    g("Accent").box((0, 0.2, 0.1), (0.6, 3.0, 0.3))


# --------------------------------------------------------------------------------------------- build / export


def material(name):
    mat = bpy.data.materials.get("M_" + name)
    if mat:
        return mat
    mat = bpy.data.materials.new("M_" + name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*COL.get(name, (0.5, 0.5, 0.5)), 1)
    metallic = name in ("Frame", "Wire", "Metal", "Gold", "Hub")
    bsdf.inputs["Metallic"].default_value = 0.85 if metallic else 0.0
    bsdf.inputs["Roughness"].default_value = 0.35 if metallic else 0.6
    return mat


def make_objects():
    objs = {}
    for asset_name, groups in ASSETS.items():
        objs[asset_name] = []
        for group, gb in groups.items():
            bmesh.ops.remove_doubles(gb.bm, verts=gb.bm.verts, dist=0.0005)
            me = bpy.data.meshes.new(f"{asset_name}__{group}")
            gb.bm.to_mesh(me)
            gb.bm.free()
            obj = bpy.data.objects.new(f"{asset_name}__{group}", me)
            bpy.context.collection.objects.link(obj)
            me.materials.append(material(group))
            objs[asset_name].append(obj)
    return objs


def smooth(objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
    try:
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))
    except Exception as err:
        print("[kit] smooth by angle unavailable:", err)


def render_setup(res):
    scene = bpy.context.scene
    engines_ = bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items.keys()
    scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines_ else "BLENDER_EEVEE"
    scene.render.resolution_x = scene.render.resolution_y = res
    scene.render.film_transparent = True
    scene.view_settings.view_transform = "Standard"
    if scene.world is None:
        scene.world = bpy.data.worlds.new("w")
        scene.world.use_nodes = True
        bg = next(n for n in scene.world.node_tree.nodes if n.type == "BACKGROUND")
        bg.inputs["Color"].default_value = (0.75, 0.8, 0.9, 1)
        bg.inputs["Strength"].default_value = 0.55
        sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
        sun.data.energy = 5
        sun.rotation_euler = (math.radians(50), 0, math.radians(-40))
        scene.collection.objects.link(sun)
        cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
        scene.collection.objects.link(cam)
        scene.camera = cam
    return scene


def frame_render(objs, path, res=420, angle=(-38, 22)):
    """Render only `objs` (others hidden), camera framing their bounds from front-left above."""
    scene = render_setup(res)
    for o in bpy.data.objects:
        if o.type == "MESH":
            o.hide_render = o not in objs
    pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    center = (lo + hi) / 2
    radius = (hi - lo).length / 2
    yaw, pitch = math.radians(angle[0]), math.radians(angle[1])
    d = Vector((math.sin(yaw) * math.cos(pitch), -math.cos(yaw) * math.cos(pitch), math.sin(pitch)))
    cam = scene.camera
    cam.data.lens = 50
    cam.location = center + d * radius * 3.1
    cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


ICON_SETS = {
    # icon name -> assets shown together
    "Engine": ["Engine3"],
    "Wings": ["IconWings"],
    "Rocket": ["Rocket3"],
    "Wheels": ["IconWheel"],
    "FuelTank": ["Tank1"],
    "Cart_Basic": ["Cart_Basic", "Wheels0"],
    "Cart_Market": ["Cart_Market", "Wheels0"],
    "Cart_Industrial": ["Cart_Industrial", "Wheels1"],
    "Cart_Racing": ["Cart_Racing", "Wheels4"],
    "Cart_Golden": ["Cart_Golden", "Wheels4"],
}


def recolor_for(icon, objs):
    """Icon previews: carts take their own accent colour (Config/CartLooks mirrors these)."""
    accents = {
        "Cart_Basic": (0.75, 0.03, 0.02),
        "Cart_Market": (0.04, 0.4, 0.1),
        "Cart_Industrial": (0.9, 0.5, 0.02),
        "Cart_Racing": (0.75, 0.02, 0.02),
        "Cart_Golden": (0.3, 0.03, 0.5),
    }
    color = accents.get(icon)
    for o in objs:
        group = o.name.split("__")[1]
        if color and group in ("Accent", "Grip", "Panel"):
            if icon == "Cart_Market" and group == "Panel":
                c = color
            elif group == "Panel":
                c = (0.1, 0.11, 0.14) if icon != "Cart_Racing" else (1, 1, 1)
            else:
                c = color
            mat = bpy.data.materials.new(f"I_{icon}_{group}")
            mat.use_nodes = True
            next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (*c, 1)
            o.data.materials.clear()
            o.data.materials.append(mat)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    cart_basic()
    cart_market()
    cart_industrial()
    cart_racing()
    cart_golden()
    engines()
    wings()
    rockets()
    wheels()
    tanks()
    more_parts()
    accessories()
    icon_models()
    objs = make_objects()
    every = [o for lst in objs.values() for o in lst]
    smooth(every)
    for name, lst in objs.items():
        tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in lst)
        print(f"[kit] {name}: {len(lst)} groups, {tris} tris", flush=True)

    if PREVIEW or ICONS:
        os.makedirs(os.path.join(OUT, "preview"), exist_ok=True)
        for name, lst in objs.items():
            if PREVIEW:
                frame_render(lst, os.path.join(OUT, "preview", f"{name}.png"))
    icon_cards = []
    if ICONS:
        os.makedirs(os.path.join(OUT, "icons_raw"), exist_ok=True)
        saved = {o: list(o.data.materials) for o in every}
        for icon, names in ICON_SETS.items():
            lst = [o for n in names for o in objs[n]]
            recolor_for(icon, lst)
            angle = (-25, 58) if icon == "Wings" else (-38, 22)
            frame_render(lst, os.path.join(OUT, "icons_raw", f"{icon}.png"), res=512, angle=angle)
            for o in lst:
                o.data.materials.clear()
                for m in saved[o]:
                    o.data.materials.append(m)

    # sticker images (make_stickers.py) as textured cards too: Sticker_<Id>
    stickers_dir = os.path.join(OUT, "stickers")
    if os.path.isdir(stickers_dir):
        for png_name in sorted(os.listdir(stickers_dir)):
            sticker = os.path.splitext(png_name)[0]
            me = bpy.data.meshes.new(f"Sticker_{sticker}")
            me.from_pydata([(-1, 0, -1), (1, 0, -1), (1, 0, 1), (-1, 0, 1)], [], [(0, 1, 2, 3)])
            uv = me.uv_layers.new(name="UVMap")
            for loop, co in zip(me.loops, [(0, 0), (1, 0), (1, 1), (0, 1)]):
                uv.data[loop.index].uv = co
            obj = bpy.data.objects.new(f"Sticker_{sticker}", me)
            bpy.context.collection.objects.link(obj)
            mat = bpy.data.materials.new(f"Sticker_{sticker}")
            mat.use_nodes = True
            bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
            tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
            tex.image = bpy.data.images.load(os.path.join(stickers_dir, png_name))
            mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
            me.materials.append(mat)
            icon_cards.append(obj)

    # export the kit (icons are added as textured cards by add_icon_cards, after the outline pass)
    icons_dir = os.path.join(OUT, "icons")
    if os.path.isdir(icons_dir):
        for i, icon in enumerate(ICON_SETS):
            png = os.path.join(icons_dir, f"{icon}.png")
            if not os.path.exists(png):
                continue
            me = bpy.data.meshes.new(f"Icon_{icon}")
            s = 1.0
            me.from_pydata([(-s, 0, -s), (s, 0, -s), (s, 0, s), (-s, 0, s)], [], [(0, 1, 2, 3)])
            uv = me.uv_layers.new(name="UVMap")
            for loop, co in zip(me.loops, [(0, 0), (1, 0), (1, 1), (0, 1)]):
                uv.data[loop.index].uv = co
            obj = bpy.data.objects.new(f"Icon_{icon}", me)
            bpy.context.collection.objects.link(obj)
            mat = bpy.data.materials.new(f"Icon_{icon}")
            mat.use_nodes = True
            bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
            tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
            tex.image = bpy.data.images.load(png)
            mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
            me.materials.append(mat)
            icon_cards.append(obj)

    for o in bpy.data.objects:
        o.hide_render = False
    bpy.ops.object.select_all(action="DESELECT")
    for o in every + icon_cards:
        if not o.name.startswith("IconW"):
            o.select_set(True)
    bpy.context.view_layer.objects.active = every[0]
    path = os.path.join(OUT, "CartKit.fbx")
    bpy.ops.export_scene.fbx(
        filepath=path, use_selection=True, object_types={"MESH"}, use_triangles=True, global_scale=0.01,
        apply_unit_scale=True, path_mode="COPY", embed_textures=True,
    )
    print(f"[kit] saved {path} ({len(icon_cards)} icon cards)", flush=True)


main()
