"""Synthetic test meshes for the organic UV tools (pure Python + numpy; also imported by the Blender fixture).

tube_body(): a mirror-exact ring-built "body" in Blender's frame (x across, character left = +x, front = -Y, z up):
  torso   8-gon tube, rings 0-4 at z 0..1 (slot 0 at the front, x = 0), coat on rings 0-2, guard on rings 2-4, closed
          by a pole at the top (part guard); open at the bottom
  arms    8-gon tubes along +-x (rings 10-13, slot 0 on the underside), sleeve on rings 10-12, hand on 12-13 plus a
          pole cap at the tip; open at the shoulder end
  legs    8-gon tubes along -z at x = +-0.2 (rings 20-23, slot 0 at the front), trousers, open at both ends
  weights Bip01_Spine (coat), Bip01_Head (guard), Bip01_L/R_UpperArm (sleeve), Bip01_L/R_Hand (hand), Bip01_L/R_Thigh
Every -X vertex is the mirror of a +X vertex and keeps its ring and slot ids. dump() returns the mesh_dump.py format.

flat_body(): planar quad islands facing -Y with a ready-made raw unwrap, for layout tests without Blender: a centre
torso plane (x -0.3..0.3, z 0..0.6, Bip01_Spine), a centre head plane (z 0.7..1.0, Bip01_Head), a +X arm plane and its
mirror (Bip01_L/R_UpperArm). The raw UVs are scaled, rotated and offset per island (the -X arm reflected), as a solver
would return them.
"""
import math

import numpy as np

N = 8


def _ring(centre, axis, r, phase_deg, n=N):
    """n points around `axis` through `centre`; slot 0 at phase_deg in the plane basis below."""
    c = np.asarray(centre, float)
    a = np.asarray(axis, float) / np.linalg.norm(axis)
    if abs(a[2]) > 0.9:            # vertical tube: basis (x, y)
        u, v = np.array([1.0, 0, 0]), np.array([0, 1.0, 0])
    else:                          # tube along x: basis (y, z)
        u, v = np.array([0, 1.0, 0]), np.array([0, 0, 1.0])
    pts = []
    for j in range(n):
        th = math.radians(phase_deg + 360.0 * j / n)
        pts.append(c + r * (math.cos(th) * u + math.sin(th) * v))
    return pts


class Builder:
    def __init__(self):
        self.co, self.polys, self.parts, self.ring, self.slot, self.w = [], [], [], [], [], []

    def vert(self, p, ring, slot, bone):
        self.co.append([float(x) for x in p])
        self.ring.append(ring)
        self.slot.append(slot)
        self.w.append([[bone, 1.0]])
        return len(self.co) - 1

    def tube(self, rings, ring_ids, slot_of, bones, parts, outward_sign=1):
        """rings: list of point lists; faces between consecutive rings, wound so the normal points out."""
        ids = []
        for k, (pts, rid) in enumerate(zip(rings, ring_ids)):
            ids.append([self.vert(p, rid, slot_of(j), bones[k]) for j, p in enumerate(pts)])
        for k in range(len(rings) - 1):
            for j in range(N):
                j2 = (j + 1) % N
                q = [ids[k][j], ids[k][j2], ids[k + 1][j2], ids[k + 1][j]]
                self.polys.append(q if outward_sign > 0 else q[::-1])
                self.parts.append(parts[k])
        return ids

    def cap(self, ring_ids, apex, ring, bone, part, outward_sign=1):
        a = self.vert(apex, ring, -1, bone)
        for j in range(N):
            j2 = (j + 1) % N
            t = [ring_ids[j], ring_ids[j2], a]
            self.polys.append(t if outward_sign > 0 else t[::-1])
            self.parts.append(part)
        return a


def _fix_outward(co, polys, centre_of):
    """flip polygons whose Newell normal points towards the part centre."""
    P = np.asarray(co)
    out = []
    for f, c in zip(polys, centre_of):
        Q = P[f]
        n = np.zeros(3)
        for k in range(len(f)):
            n += np.cross(Q[k], Q[(k + 1) % len(f)])
        out.append(f if n @ (Q.mean(0) - c) >= 0 else f[::-1])
    return out


def tube_body():
    b = Builder()
    centres = []
    # torso
    tz = [0.0, 0.25, 0.5, 0.75, 1.0]
    rings = [_ring((0, 0, z), (0, 0, 1), 0.25, -90.0) for z in tz]
    bones = ['Bip01_Spine'] * 3 + ['Bip01_Head'] * 2
    ids = b.tube(rings, [0, 1, 2, 3, 4], lambda j: j, bones, ['coat', 'coat', 'guard', 'guard'])
    centres += [np.array([0, 0, 0.5])] * (4 * N)
    b.cap(ids[-1], (0, 0, 1.2), 5, 'Bip01_Head', 'guard')
    centres += [np.array([0, 0, 0.5])] * N
    # arms (+x then -x)
    for s, side in ((1, 'L'), (-1, 'R')):
        ax = [0.3, 0.55, 0.8, 0.95]
        rings = [_ring((s * x, 0, 0.8), (1, 0, 0), 0.08, -90.0) for x in ax]
        if s < 0:
            rings = [[np.array([-p[0], p[1], p[2]]) for p in _ring((x, 0, 0.8), (1, 0, 0), 0.08, -90.0)] for x in ax]
        bones = ['Bip01_%s_UpperArm' % side] * 3 + ['Bip01_%s_Hand' % side]
        ids = b.tube(rings, [10, 11, 12, 13], lambda j: j, bones, ['sleeve', 'sleeve', 'hand'])
        centres += [np.array([s * 0.6, 0, 0.8])] * (3 * N)
        b.cap(ids[-1], (s * 1.05, 0, 0.8), 14, 'Bip01_%s_Hand' % side, 'hand')
        centres += [np.array([s * 0.6, 0, 0.8])] * N
    # legs
    for s, side in ((1, 'L'), (-1, 'R')):
        lz = [-0.05, -0.4, -0.75, -1.1]
        rings = [_ring((0.2, 0, z), (0, 0, 1), 0.09, -90.0) for z in lz]
        if s < 0:
            rings = [[np.array([-p[0], p[1], p[2]]) for p in r] for r in rings]
        b.tube(rings, [20, 21, 22, 23], lambda j: j, ['Bip01_%s_Thigh' % side] * 4,
               ['trousers', 'trousers', 'trousers'])
        centres += [np.array([s * 0.2, 0, -0.6])] * (3 * N)
    b.polys = _fix_outward(b.co, b.polys, centres)
    return b


def mirror_map(co, tol=1e-6):
    P = np.asarray(co, float)
    Q = P * np.array([-1.0, 1, 1])
    d = ((Q[:, None, :] - P[None, :, :]) ** 2).sum(-1)
    j = d.argmin(1)
    ok = np.sqrt(d[np.arange(len(P)), j]) <= tol
    return [int(x) if o else -1 for x, o in zip(j, ok)]


def edges_of(polys):
    es = set()
    for f in polys:
        for k in range(len(f)):
            a, b = f[k], f[(k + 1) % len(f)]
            es.add((min(a, b), max(a, b)))
    return sorted(es)


def dump(b, name='Body'):
    mm = mirror_map(b.co)
    return {'schema': 'blender-organic-uv/mesh-dump/1', 'blend': '(synthetic)', 'objects': {name: {
        'verts': len(b.co), 'polys_count': len(b.polys), 'co': b.co,
        'matrix_world': [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]],
        'polys': b.polys, 'edges': [list(e) for e in edges_of(b.polys)], 'parts': b.parts,
        'part_source': 'synthetic', 'vattrs': {'ring': b.ring, 'slot': b.slot}, 'weights': b.w,
        'vertex_groups': sorted(set(w[0][0] for w in b.w)), 'mirror_map': mm,
        'mirror_unmatched': sum(1 for x in mm if x < 0), 'mirror_worst': 0.0,
        'centre_verts': sum(1 for p in b.co if abs(p[0]) < 1e-9), 'uv_layers': [], 'materials': [],
        'marked_seams': []}}}


BODY_RULES = {
    'schema': 'blender-organic-uv/seam-rules/1',
    'objects': {'Body': {
        'mirror': True, 'back': [0, 1, 0], 'hide': [0, 1, 0],
        'rules': [
            {'id': 'neck', 'kind': 'border', 'a': ['coat'], 'b': ['guard']},
            {'id': 'wrist', 'kind': 'border', 'a': ['sleeve'], 'b': ['hand']},
            {'id': 'back', 'kind': 'centre', 'parts': ['coat', 'guard'], 'side': 'back'},
            {'id': 'arm_under', 'kind': 'slot_line', 'parts': ['sleeve'], 'slot': 0, 'rings': [10, 12]},
            {'id': 'palm', 'kind': 'path', 'parts': ['hand'], 'from': {'border': [['sleeve'], ['hand']]},
             'to': {'farthest_from': 'from'}, 'hide': [0, 0, -1]},
            {'id': 'inseam', 'kind': 'path', 'parts': ['trousers'], 'from': {'ring': 20},
             'to': {'ring': 23}, 'hide': [-1, 0, 0]},
        ]}}}


# ---------------------------------------------------------------- flat body for the layout
def _plane(b, x0, x1, z0, z1, nx, nz, bone, part):
    ids = {}
    for i in range(nx + 1):
        for k in range(nz + 1):
            ids[(i, k)] = b.vert((x0 + (x1 - x0) * i / nx, 0.0, z0 + (z1 - z0) * k / nz), -1, -1, bone)
    fs = []
    for i in range(nx):
        for k in range(nz):
            # counter-clockwise seen from -Y (front): (x, z) order
            fs.append([ids[(i, k)], ids[(i + 1, k)], ids[(i + 1, k + 1)], ids[(i, k + 1)]])
    for f in fs:
        b.polys.append(f)
        b.parts.append(part)
    return fs


def flat_body():
    """(dump, raw unwrap) of the flat body."""
    b = Builder()
    pieces = [((-0.3, 0.3, 0.0, 0.6), (4, 3), 'Bip01_Spine', 'coat', dict(scale=0.7, angle=30, off=(0.1, 0.1))),
              ((-0.15, 0.15, 0.7, 1.0), (2, 2), 'Bip01_Head', 'face', dict(scale=1.3, angle=-60, off=(2.0, 0.3))),
              ((0.45, 0.85, 0.5, 0.65), (4, 1), 'Bip01_L_UpperArm', 'sleeve', dict(scale=0.9, angle=95, off=(4, 1))),
              ((-0.85, -0.45, 0.5, 0.65), (4, 1), 'Bip01_R_UpperArm', 'sleeve', dict(scale=0.9, angle=95, off=(6, 1),
                                                                                   mirror=True))]
    raw_polys = []
    for (x0, x1, z0, z1), (nx, nz), bone, part, tf in pieces:
        fs = _plane(b, x0, x1, z0, z1, nx, nz, bone, part)
        th = math.radians(tf['angle'])
        R = np.array([[math.cos(th), -math.sin(th)], [math.sin(th), math.cos(th)]])
        for f in fs:
            uv = []
            for v in f:
                x, _, z = b.co[v]
                p = np.array([x, z])
                if tf.get('mirror'):
                    p = np.array([-x, z])               # the solver returns the -X arm as the mirror image
                q = R @ (p * tf['scale']) + np.array(tf['off'])
                if tf.get('mirror'):
                    q[0] = -q[0]
                uv.append([float(q[0]), float(q[1])])
            raw_polys.append({'v': list(f), 'uv': uv})
    d = dump(b)
    return d, {'schema': 'blender-organic-uv/raw-unwrap/1', 'objects': {'Body': {'method': 'synthetic',
                                                                            'polys': raw_polys}}}
