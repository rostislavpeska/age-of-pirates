"""Inside-out shell and broken n-gon check: every closed shell (edge-connected faces with no boundary edge) of an export mesh must
enclose positive signed volume with the world transform applied. An inside-out shell passes UV integrity, density
and distant review renders, but in game (back faces culled) the camera looks through its outer faces at the recessed
inner ones, which an AO bake has already darkened (2026-10-10: a Korean dock's gable boards read as black holes).

Second check, same report: every n-gon must be a simple polygon in its own plane. A self-intersecting outline (e.g. a
gable board whose sloped edge ends below the end of its curved bottom edge) triangulates with flipped triangles in
Blender and in the game export: inverted baked normals, black AO, culled slits (same 2026-10-10 boards, 34 % of each
face). Blender: loop triangles whose normal opposes their polygon's normal are listed as `flipped_triangles`.

Pure functions (no bpy) for tests; run inside Blender for a report:

    blender -b FILE.blend --python shell_orientation.py -- --out REPORT.json [--collection NAME ...] [--names-from LIST.json] [--strict]

--names-from takes a JSON list of object names (or {"objects": [...]}) - pass the export set, so blockout leftovers in
the same file do not count. --strict exits 1 on any inside-out shell. Open shells are listed, never judged (their
orientation is a modelling convention, not a volume).
"""
import json, sys


def shells(faces):
    """faces: list of vertex-index tuples. Returns lists of face indices, edge-connected."""
    edge_faces = {}
    for fi, f in enumerate(faces):
        for i in range(len(f)):
            edge_faces.setdefault(frozenset((f[i], f[(i + 1) % len(f)])), []).append(fi)
    parent = list(range(len(faces)))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i
    for fs in edge_faces.values():
        for g in fs[1:]:
            parent[find(g)] = find(fs[0])
    out = {}
    for fi in range(len(faces)):
        out.setdefault(find(fi), []).append(fi)
    return list(out.values()), edge_faces


def signed_volume(verts, faces, idx):
    v = 0.0
    for fi in idx:
        f = faces[fi]
        a = verts[f[0]]
        for i in range(1, len(f) - 1):
            b, c = verts[f[i]], verts[f[i + 1]]
            v += (a[0] * (b[1] * c[2] - b[2] * c[1]) - a[1] * (b[0] * c[2] - b[2] * c[0]) + a[2] * (b[0] * c[1] - b[1] * c[0])) / 6.0
    return v


def check_mesh(verts, faces, eps=1e-9):
    """verts in world space (apply the matrix first: a negative-determinant transform flips the result)."""
    groups, edge_faces = shells(faces)
    res = []
    for idx in groups:
        s = set(idx)
        boundary = sum(1 for fs in edge_faces.values() if len([f for f in fs if f in s]) == 1 and fs[0] in s)
        closed = boundary == 0
        vol = signed_volume(verts, faces, idx)
        res.append({'faces': len(idx), 'first_face': min(idx), 'closed': closed, 'volume': vol,
                    'status': ('INSIDE_OUT' if vol < -eps else 'OK') if closed else 'OPEN'})
    return res


def self_intersecting(pts2):
    """True when a closed 2D outline (list of (x, y)) crosses itself (non-adjacent edges intersect)."""
    def cross(o, a_, b_):
        return (a_[0] - o[0]) * (b_[1] - o[1]) - (a_[1] - o[1]) * (b_[0] - o[0])

    def hit(p1, p2, q1, q2):
        d1, d2, d3, d4 = cross(q1, q2, p1), cross(q1, q2, p2), cross(p1, p2, q1), cross(p1, p2, q2)
        return d1 * d2 < 0 and d3 * d4 < 0
    k = len(pts2)
    for i in range(k):
        for j in range(i + 2, k):
            if i == 0 and j == k - 1:
                continue
            if hit(pts2[i], pts2[(i + 1) % k], pts2[j], pts2[(j + 1) % k]):
                return True
    return False


def main():
    import argparse
    import bpy
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', required=True); ap.add_argument('--collection', action='append', default=[])
    ap.add_argument('--names-from'); ap.add_argument('--strict', action='store_true')
    a = ap.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
    objs = [o for o in bpy.data.objects if o.type == 'MESH']
    if a.collection:
        objs = [o for o in objs if any(c.name in a.collection for c in o.users_collection)]
    if a.names_from:
        names = json.load(open(a.names_from))
        names = set(names['objects'] if isinstance(names, dict) else names)
        objs = [o for o in objs if o.name in names]
    rep = {'objects': len(objs), 'inside_out': [], 'open_shells': 0, 'closed_shells': 0}
    for o in sorted(objs, key=lambda o: o.name):
        mw = o.matrix_world; me = o.data
        verts = [tuple(mw @ v.co) for v in me.vertices]
        for r in check_mesh(verts, [tuple(p.vertices) for p in me.polygons]):
            rep['open_shells' if r['status'] == 'OPEN' else 'closed_shells'] += 1
            if r['status'] == 'INSIDE_OUT':
                rep['inside_out'].append({'object': o.name, **r})
        me.calc_loop_triangles(); flips = {}
        for t in me.loop_triangles:
            if t.area > 1e-10 and t.normal.dot(me.polygons[t.polygon_index].normal) < 0:
                flips[t.polygon_index] = flips.get(t.polygon_index, 0) + 1
        for pi, k in flips.items():
            rep.setdefault('flipped_triangles', []).append({'object': o.name, 'face': pi, 'verts': len(me.polygons[pi].vertices), 'flipped': k})
    rep['status'] = 'FAIL' if rep['inside_out'] or rep.get('flipped_triangles') else 'PASS'
    json.dump(rep, open(a.out, 'w'), indent=1)
    print('SHELL_ORIENTATION', rep['status'], len(rep['inside_out']), 'inside-out of', rep['closed_shells'], 'closed shells,', len(rep.get('flipped_triangles', [])),
          'faces with flipped triangles,', rep['objects'], 'objects')
    if a.strict and rep['status'] == 'FAIL':
        sys.exit(1)


if __name__ == '__main__':
    main()
