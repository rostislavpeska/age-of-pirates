"""UV logic audit: catch illogical unwraps BEFORE texturing (Korean Dock 2026-10-10: a plaster wall bay built as 7-11
separate panel objects got 7-10 UV charts and texel sharing between pieces up to 1.8 m apart; world-space weathering then
showed duplicated, cut-off and repeated patterns - owner: "now we're paying the tax for shitty UV unwrap ... detect this
illogical unwrap upfront").

Checks (per page, visible faces of the given paint subtypes):
  FRAGMENTATION  coplanar, edge-or-vertex-connected faces of one material across objects = one planar region; it should be
                 ONE owner chart (a ring around an opening is still one chart). Reports owner charts per region and
                 charts per m2; FAIL when a region of >= --min-area m2 has > --max-charts owner charts.
  CONTEXT        every sharing member (share_role 2) is compared with the owner it reads (the owner face whose UV polygon
                 contains the member's UV centroid): 3D distance, height difference, normal agreement. World-space paint
                 (height bands, distance below the eave, edge wear, AO) is only valid on shared texels when the contexts
                 match; FAIL when |dz| > --max-dz or the normals differ, WARN when the 3D distance > --max-d3.
    blender -b UV.blend --python uv_logic_audit.py -- --collection "Dock | LOW geometry" --uv UV_Provisional_r2
        --subtypes 0,1 --page 1 --report AUDIT.json [--min-area .3 --max-charts 1 --max-dz .05 --max-d3 .5]
Exit code 2 on FAIL. Attribute names follow the Korean Dock UV r2 contract (paint_subtype_r2, uv_resource_r2, uv_chart_r2,
share_role_r2); pass others with --attr-* if a project names them differently.
"""
import bpy, sys, json, argparse
import numpy as np
from collections import defaultdict

ap = argparse.ArgumentParser()
ap.add_argument('--collection', required=True); ap.add_argument('--uv', required=True); ap.add_argument('--report', required=True)
ap.add_argument('--subtypes', required=True, help='comma list of paint subtype indices (e.g. plaster, plaster_player)')
ap.add_argument('--page', type=int, required=True); ap.add_argument('--min-area', type=float, default=.3); ap.add_argument('--max-charts', type=int, default=1)
ap.add_argument('--max-dz', type=float, default=.05); ap.add_argument('--max-d3', type=float, default=.5)
ap.add_argument('--attr-subtype', default='paint_subtype_r2'); ap.add_argument('--attr-page', default='uv_resource_r2')
ap.add_argument('--attr-chart', default='uv_chart_r2'); ap.add_argument('--attr-role', default='share_role_r2')
ap.add_argument('--intentional-splits', help='JSON with "placed": [{"objects": [...]}, ...]: charts deliberately split from one planar region (listed, e.g. at window jambs because a wall did not fit the atlas)')
a = ap.parse_args(sys.argv[sys.argv.index('--') + 1:])
SUBS = {int(x) for x in a.subtypes.split(',')}
SPLITS = json.load(open(a.intentional_splits))['placed'] if a.intentional_splits else []
faces = []
for o in bpy.data.collections[a.collection].all_objects:
    if o.type != 'MESH' or a.attr_subtype not in o.data.attributes or a.uv not in o.data.uv_layers:
        continue
    me = o.data; A = me.attributes; mw = o.matrix_world; ul = me.uv_layers[a.uv].data
    for p in me.polygons:
        if A[a.attr_subtype].data[p.index].value not in SUBS or A[a.attr_page].data[p.index].value != a.page:
            continue
        n = np.array((mw.to_3x3() @ p.normal).normalized()); c = np.array(mw @ p.center)
        faces.append({'o': o.name, 'f': p.index, 'n': n, 'c': c, 'd': float(n @ c), 'area': p.area * abs(mw.to_3x3().determinant()) ** (2 / 3),
                      'vs': [tuple(np.round(np.array(mw @ me.vertices[v].co), 3)) for v in p.vertices], 'uv': [tuple(ul[l].uv) for l in p.loop_indices],
                      'role': A[a.attr_role].data[p.index].value, 'chart': (o.name, A[a.attr_chart].data[p.index].value)})
# ---------------------------------------------------------------- UV islands (real charts): faces touching in 3D AND in UV, across objects
cp = list(range(len(faces)))
def cf(i):
    while cp[i] != i:
        cp[i] = cp[cp[i]]; i = cp[i]
    return i
uvkey = defaultdict(list)
for i, f in enumerate(faces):
    for v, uv in zip(f['vs'], f['uv']):
        uvkey[(v, round(uv[0], 5), round(uv[1], 5))].append(i)
for ids in uvkey.values():
    for j in ids[1:]:
        cp[cf(j)] = cf(ids[0])
for i, f in enumerate(faces):
    f['chart'] = cf(i)
# ---------------------------------------------------------------- FRAGMENTATION
par = list(range(len(faces)))
def fd(i):
    while par[i] != i:
        par[i] = par[par[i]]; i = par[i]
    return i
key = defaultdict(list)
for i, f in enumerate(faces):
    for v in f['vs']:
        key[(tuple(np.round(f['n'], 2)), round(f['d'], 2), v)].append(i)
for ids in key.values():
    for j in ids[1:]:
        par[fd(j)] = fd(ids[0])
regions = defaultdict(list)
for i, f in enumerate(faces):
    regions[fd(i)].append(f)
frag = []
for fs in regions.values():
    area = sum(f['area'] for f in fs)
    if area < a.min_area:
        continue
    charts = {f['chart'] for f in fs if f['role'] != 2}
    objs_r = {f['o'] for f in fs}; allowed = max(1, sum(1 for e in SPLITS if set(e['objects']) & objs_r)) if SPLITS else a.max_charts
    frag.append({'region': sorted({f['o'] for f in fs})[0], 'objects': len({f['o'] for f in fs}), 'area_m2': round(area, 3), 'owner_charts': len(charts),
                 'charts_per_m2': round(len(charts) / area, 2), 'members': sum(f['role'] == 2 for f in fs), 'allowed_charts': allowed, 'fail': len(charts) > max(a.max_charts, allowed)})
# ---------------------------------------------------------------- CONTEXT (member vs the owner it reads)
def inside(pt, poly):
    x, y = pt; ins = False; n = len(poly)
    for i in range(n):
        x1, y1 = poly[i]; x2, y2 = poly[(i + 1) % n]
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1 + 1e-12) + x1:
            ins = not ins
    return ins
owners = [f for f in faces if f['role'] != 2]
ctx = []
for m in (f for f in faces if f['role'] == 2):
    uc = tuple(np.mean(m['uv'], 0)); hit = next((o for o in owners if inside(uc, o['uv'])), None)
    if hit is None:
        ctx.append({'member': f"{m['o']}:{m['f']}", 'owner': None, 'fail': True, 'why': 'reads no owner polygon on this page'}); continue
    dz = float(m['c'][2] - hit['c'][2]); d3 = float(np.linalg.norm(m['c'] - hit['c'])); same_n = bool(abs(m['n'][2] - hit['n'][2]) < .2)   # tilt only: mirrored opposite walls are valid
    ctx.append({'member': f"{m['o']}:{m['f']}", 'owner': f"{hit['o']}:{hit['f']}", 'dz_m': round(dz, 3), 'd3_m': round(d3, 3), 'same_normal': same_n,
                'fail': abs(dz) > a.max_dz or not same_n, 'warn': d3 > a.max_d3})
rep = {'faces': len(faces), 'regions': len(frag), 'fragmentation_fail': sum(r['fail'] for r in frag), 'owner_charts_total': sum(r['owner_charts'] for r in frag),
       'members': len(ctx), 'context_fail': sum(c['fail'] for c in ctx), 'context_warn': sum(c.get('warn', False) for c in ctx),
       'limits': {'max_charts': a.max_charts, 'max_dz': a.max_dz, 'max_d3': a.max_d3, 'min_area': a.min_area},
       'worst_regions': sorted(frag, key=lambda r: -r['owner_charts'])[:20], 'context': sorted(ctx, key=lambda c: -abs(c.get('dz_m', 9)))[:40]}
json.dump(rep, open(a.report, 'w'), indent=1)
verdict = 'FAIL' if rep['fragmentation_fail'] or rep['context_fail'] else 'PASS'
print('UV_LOGIC_AUDIT', verdict, json.dumps({k: rep[k] for k in ('faces', 'regions', 'fragmentation_fail', 'owner_charts_total', 'members', 'context_fail', 'context_warn')}))
sys.exit(2 if verdict == 'FAIL' else 0)
