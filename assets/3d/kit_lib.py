"""Shared mesh helpers for the Blender kits (cart_kit.py keeps its own copy; scenery_kit.py imports this)."""

import math

import bmesh
import bpy
from mathutils import Matrix, Vector


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


