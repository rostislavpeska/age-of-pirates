"""Gate an arranged (and settled) prop layout: static stability per prop + organic-ness metrics per model (Blender, read-only).

  blender -b <settled.blend> --factory-startup --python refresh_view_layers.py --python prop_metrics.py -- \
      --model <M> --spec ARRANGE_SPEC.json --arrange-report ARRANGE_REPORT.json --out METRICS.json

Per prop (catalog root empty + parented parts, world geometry):
  centre of mass  = volume centroid of the convex hull of all parts (uniform density - the same proxy settle_props.py uses);
  support points  = a 1-2 cm plan grid under the prop: underside point (ray from below) within --contact-tol of the
                    surface under it (ground plane z = 0, the model's LOW parts, other props); support polygon = their hull;
  side contacts   = vertices higher than the support band within --side-tol of a LOW part or another prop.
Gates (thresholds in prop_layout_metrics.THRESHOLDS, never loosened per run):
  upright / stack : centre of mass inside the support polygon by max(2 cm, 10 % of its smallest width);
  stack           : rests on its declared base (support points on that prop);
  lean            : ground + upper contact, mu_req = d(ground contact -> COM) / h(upper contact) <= 0.4;
  tipped          : resting on its side is neutral on level ground: reported (roll stops), not gated;
  small props     : < 0.20 m only on a prop host;
  model           : no interpenetrating or nested prop pair (BVH crossing or ray-parity containment),
                    aligned share of asymmetric props <= 0.35, 0 axis rows (declared rows exempt),
                    contact share >= 0.30, isolated share <= 0.20.
Advisory (reported, never gating): Clark-Evans R per zone (Donnelly edge correction), nearest-neighbour CV,
orientation entropy, parallel-neighbour share. sd(R) is ~0.2 at our counts (see the docstring of clark_evans)."""
import argparse, json, math, sys
from pathlib import Path
import bmesh
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0, str(Path(__file__).resolve().parent))
import prop_layout_metrics as M  # noqa: E402

ap = argparse.ArgumentParser()
ap.add_argument('--model', required=True); ap.add_argument('--out', required=True)
ap.add_argument('--spec'); ap.add_argument('--arrange-report')
ap.add_argument('--props-collection', default='{model} | PROPS'); ap.add_argument('--low-collection', default='{model} | LOW geometry')
ap.add_argument('--contact-tol', type=float, default=.006, help='support contact (m); covers the 4 mm rigid-body margin')
ap.add_argument('--side-tol', type=float, default=.01)
ap.add_argument('--round', default='PowderKeg,YugiBasin,YugiBowl,OnggiDok,OnggiHangari,Sokuri',
                help='catalog props with no readable plan direction when upright (excluded from the alignment metrics)')
a = ap.parse_args(sys.argv[sys.argv.index('--') + 1:])
TH = M.THRESHOLDS; ROUND = set(a.round.split(','))
for sc in bpy.data.scenes:
    for vl in sc.view_layers:
        vl.update()
dg = bpy.context.evaluated_depsgraph_get()
SPEC = json.load(open(a.spec, encoding='utf-8'))['models'][a.model] if a.spec else {}
POSE, DECL_ROWS = {}, set(SPEC.get('declared_rows', []))
if a.arrange_report:
    for r in json.load(open(a.arrange_report))['models'][a.model]['rows']:
        if 'FAILED' not in r:
            POSE[r['id']] = r
pc = bpy.data.collections[a.props_collection.format(model=a.model)]
roots = [o for o in pc.objects if o.parent is None]


def geom(objs):
    V, T = [], []
    for o in objs:
        oe = o.evaluated_get(dg); me = oe.to_mesh(); me.calc_loop_triangles(); b = len(V)
        V += [o.matrix_world @ v.co for v in me.vertices]; T += [[b + i for i in t.vertices] for t in me.loop_triangles]; oe.to_mesh_clear()
    return V, T


def hull_com(V):
    bm = bmesh.new()
    for p in V:
        bm.verts.new(p)
    bmesh.ops.convex_hull(bm, input=bm.verts[:]); bm.faces.ensure_lookup_table()
    o = sum(V, Vector()) / len(V); vol = 0.0; c = Vector()
    for f in bm.faces:
        p0 = f.verts[0].co
        for i in range(1, len(f.verts) - 1):
            p1, p2 = f.verts[i].co, f.verts[i + 1].co; v = (p0 - o).dot((p1 - o).cross(p2 - o)) / 6
            vol += v; c += v * (o + p0 + p1 + p2) / 4
    bm.free()
    return (c / vol if abs(vol) > 1e-12 else o), abs(vol)


P = {}
for r in roots:
    parts = [c for c in pc.objects if c.parent == r and c.type == 'MESH']; V, T = geom(parts)
    com, vol = hull_com(V); lo = Vector([min(p[j] for p in V) for j in range(3)]); hi = Vector([max(p[j] for p in V) for j in range(3)])
    mid = r.name.split('.', 3)[3]; kind = r.name.split('.')[2]
    P[mid] = {'root': r, 'kind': kind, 'V': V, 'bvh': BVHTree.FromPolygons(V, T, all_triangles=True), 'com': com, 'vol': vol,
              'lo': lo, 'hi': hi, 'size': max(hi - lo), 'pose': POSE.get(mid, {}).get('pose', 'upright'), 'on': None}
spec_members = {m.get('id'): m for c in SPEC.get('clusters', []) for m in c['members']}
for mid, p in P.items():
    p['on'] = spec_members.get(mid, {}).get('on')
low = [o for o in bpy.data.collections[a.low_collection.format(model=a.model)].all_objects if o.type == 'MESH']
allp = [q for p in P.values() for q in p['V']]; cx = sum(q.x for q in allp) / len(allp); cy = sum(q.y for q in allp) / len(allp)
near = []
for o in low:                                                  # LOW parts near the props only
    V = [o.matrix_world @ v.co for v in o.data.vertices]
    if V and min(math.hypot(q.x - cx, q.y - cy) for q in V[::max(1, len(V) // 50)]) < 15:
        near.append(o)
LV, LT = geom(near); LOW = BVHTree.FromPolygons(LV, LT, all_triangles=True)


def dist(bvh, q, lim):
    h = bvh.find_nearest(q, lim)
    return h[3] if h[0] is not None else None


def inside_mesh(b, q, eps=1e-4):
    votes = 0
    for d in (Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))):
        o, n = q.copy(), 0
        for _ in range(64):
            h = b.ray_cast(o, d, 50.)
            if h[0] is None:
                break
            n += 1; o = h[0] + d * eps
        votes += n % 2
    return votes >= 2


PEN = []                                               # interpenetrating / nested pairs (surfaces crossing, or a part inside)
keys = list(P)
for i, k1 in enumerate(keys):
    for k2 in keys[i + 1:]:
        p1, p2 = P[k1], P[k2]
        if not all(p1['lo'][j] < p2['hi'][j] - .002 and p1['hi'][j] > p2['lo'][j] + .002 for j in range(3)):
            continue
        cross = len(p1['bvh'].overlap(p2['bvh']))
        nest = inside_mesh(p2['bvh'], p1['com']) or inside_mesh(p1['bvh'], p2['com'])
        if cross or nest:
            PEN.append({'pair': [k1, k2], 'crossing_triangle_pairs': cross, 'nested': nest})
rows = []
for mid, p in P.items():
    others = {k: q for k, q in P.items() if k != mid and all(q['lo'][j] - .03 < p['hi'][j] and q['hi'][j] + .03 > p['lo'][j] for j in range(3))}
    sup, sup_by, side, side_by = [], set(), [], set()
    # support: a plan grid under the prop; at each point the underside (first hit from below) and the surface under it
    # (ground plane z = 0, LOW, other props); contact where the gap <= contact_tol. Vertex tests miss band / lid contacts.
    st = max(.01, min(.02, p['size'] / 25)); nx_ = int((p['hi'].x - p['lo'].x) / st) + 1; ny_ = int((p['hi'].y - p['lo'].y) / st) + 1
    for i in range(nx_ + 1):
        for j in range(ny_ + 1):
            x, y = p['lo'].x + i * st, p['lo'].y + j * st
            h = p['bvh'].ray_cast(Vector((x, y, p['lo'].z - .05)), Vector((0, 0, 1)), p['hi'].z - p['lo'].z + .1)
            if h[0] is None or h[0].z > p['com'].z - .02:
                continue
            zb = h[0].z; below = [(0.0, 'ground')]
            for nm, b in [('LOW', LOW)] + [(k, q['bvh']) for k, q in others.items()]:
                hh = b.ray_cast(Vector((x, y, zb + 1e-4)), Vector((0, 0, -1)), a.contact_tol + .05)
                if hh[0] is not None:
                    below.append((hh[0].z, nm))
            zs, nm = max(below)
            if zb - zs <= a.contact_tol:
                sup.append((x, y)); sup_by.add(nm)
    for v in p['V']:                                     # side contacts: vertices above the support band
        if v.z < p['lo'].z + max(.02, .1 * (p['hi'].z - p['lo'].z)):
            continue
        hit = (['LOW'] if dist(LOW, v, a.side_tol) is not None else []) + [k for k, q in others.items() if dist(q['bvh'], v, a.side_tol) is not None]
        if hit:
            side.append(v); side_by.update(hit)
    p.update(sup=sup, sup_by=sorted(sup_by), side_by=sorted(side_by))
    row = {'id': mid, 'prop': p['kind'], 'pose': p['pose'], 'size_m': round(p['size'], 3), 'com': [round(x, 3) for x in p['com']],
           'support_on': sorted(sup_by), 'side_contacts': sorted(side_by), 'checks': {}}
    ck = row['checks']
    if p['pose'] in ('upright', 'stack'):
        ok, m_, need = M.stability_ok((p['com'].x, p['com'].y), sup, TH); ck['com_in_support'] = {'ok': ok, 'margin_m': m_, 'need_m': need}
    if p['pose'] == 'stack':
        ck['on_declared_base'] = {'ok': p['on'] in sup_by, 'base': p['on']}
        if p['on'] in P:
            ck['heavier_below'] = {'ok': P[p['on']]['vol'] >= .8 * p['vol'], 'note': 'hull volume ratio base/top',
                                   'ratio': round(P[p['on']]['vol'] / max(p['vol'], 1e-9), 2)}
    if p['pose'] == 'lean':
        g = [v for v in p['V'] if v.z < p['lo'].z + a.contact_tol]; up = [v for v in side if v.z > p['lo'].z + .1]
        if g and up:
            gc = sum(g, Vector()) / len(g); u = max(up, key=lambda v: v.z)
            mu = M.lean_mu_required(math.hypot(p['com'].x - gc.x, p['com'].y - gc.y), u.z - gc.z)
            ck['lean_friction'] = {'ok': mu <= TH['lean_mu_max'], 'mu_required': round(mu, 3), 'upper_contact_z': round(u.z, 3)}
        else:
            ck['lean_friction'] = {'ok': False, 'note': 'no ground + upper contact pair'}
    if p['pose'] == 'tipped':
        ck['roll_stops'] = {'ok': True, 'gated': False, 'side_contacts': sorted(side_by),
                            'note': 'neutral equilibrium on level ground; settled at rest by rigid-body physics'}
    if p['size'] < TH['small_prop_m']:
        ck['small_on_host'] = {'ok': any(k in P for k in sup_by), 'support_on': sorted(sup_by)}
    row['ok'] = all(c['ok'] for c in ck.values()); rows.append(row)


def plan_yaw(p):
    R = p['root'].matrix_world.to_3x3()
    ax = R @ Vector((0, 0, 1)) if p['pose'] == 'tipped' else R @ Vector((1, 0, 0))
    return math.degrees(math.atan2(ax.y, ax.x))


asym = {k: p for k, p in P.items() if p['kind'] not in ROUND or p['pose'] in ('tipped', 'lean')}
yaws = {k: plan_yaw(p) for k, p in asym.items()}
ground = {k: p for k, p in P.items() if p['pose'] != 'stack'}
cent = {k: ((p['lo'].x + p['hi'].x) / 2, (p['lo'].y + p['hi'].y) / 2) for k, p in P.items()}
rows_found = [(ax_, [list(ground)[i] for i in g]) for ax_, g in M.axis_rows([cent[k] for k in ground], TH['row_tol_m'])]
rows_found = [r_ for r_ in rows_found if not set(r_[1]) <= DECL_ROWS]
based = {p['on'] for p in P.values() if p['pose'] == 'stack'}
contact = {k for k, p in P.items() if any(s in P or s == 'LOW' for s in p['side_by']) or any(s in P for s in p['sup_by']) or k in based}


def gap(p, q):
    return math.sqrt(sum(max(q['lo'][j] - p['hi'][j], p['lo'][j] - q['hi'][j], 0) ** 2 for j in (0, 1)))


isolated = [k for k, p in P.items() if all(gap(p, q) > TH['isolated_radius_m'] for j, q in P.items() if j != k)]
zones = {}
for zn, poly in SPEC.get('zones', {}).items():
    pts = [cent[k] for k in ground if M.point_in_polygon(poly, *cent[k])]; A, Pm = M.polygon_area_perimeter(poly)
    R = M.clark_evans(pts, A, Pm)
    zones[zn] = {'n': len(pts), 'clark_evans_R': round(R, 3) if R else None, 'nn_cv': round(M.nn_cv(pts), 3) if len(pts) > 2 else None}
model = {
    'aligned_share': {'value': round(M.alignment_share(list(yaws.values()), 0, TH['aligned_tol_deg']), 3), 'max': TH['aligned_share_max'],
                      'n_asymmetric': len(yaws)},
    'axis_rows': {'value': len(rows_found), 'max': TH['axis_rows_max'], 'rows': rows_found},
    'contact_share': {'value': round(len(contact) / len(P), 3), 'min': TH['contact_share_min'], 'not_in_contact': sorted(set(P) - contact)},
    'isolated_share': {'value': round(len(isolated) / len(P), 3), 'max': TH['isolated_share_max'], 'isolated': isolated},
    'stability': {'value': sum(r['ok'] for r in rows), 'of': len(rows), 'failed': [r['id'] for r in rows if not r['ok']]},
    'interpenetration': {'value': len(PEN), 'max': 0, 'pairs': PEN}}
gates = {'aligned_share': model['aligned_share']['value'] <= TH['aligned_share_max'], 'axis_rows': model['axis_rows']['value'] <= TH['axis_rows_max'],
         'contact_share': model['contact_share']['value'] >= TH['contact_share_min'], 'isolated_share': model['isolated_share']['value'] <= TH['isolated_share_max'],
         'stability': not model['stability']['failed'], 'interpenetration': not PEN}
ent = M.orientation_entropy(list(yaws.values())) if len(yaws) >= 6 else None
advisory = {'zones': zones, 'orientation_entropy': round(ent, 3) if ent is not None else None,
            'parallel_share': round(M.parallel_share([cent[k] for k in yaws], list(yaws.values())), 3),
            'note': 'Clark-Evans R (Donnelly) and NN CV per zone; sd(R) ~0.17-0.27 at n 5-12: read, do not gate'}
rep = {'model': a.model, 'file': bpy.data.filepath, 'gate': 'PASS' if all(gates.values()) else 'FAIL', 'gates': gates,
       'metrics': model, 'advisory': advisory, 'thresholds': TH, 'props': rows}
Path(a.out).write_text(json.dumps(rep, indent=1))
print('PROP_METRICS', a.model, rep['gate'], json.dumps({k: v['value'] for k, v in model.items()}), json.dumps(gates))
