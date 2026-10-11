"""Batch runner: measure, rule-check and blueprint a list of items, then write one summary table (calibration and
library surveys). Paths in the item file may contain <name> placeholders filled from --root name=PATH, so the item file
holds no device paths of its own. Outputs refuse to land inside a git work tree.

    python survey.py ITEMS.json --root library_root=PATH [--root mpfb=PATH ...] --out DIR [--only id1,id2]
                     [--profile profiles/<p>.json] [--renders] [--blender EXE]

Item: {"id": "S07", "path": "<library_root>/<folder>/model.glb", "kind": "body", "face_source": "ogt",
       "select": null, "exclude": null, "group": null, "collection": null, "up": null, "rot": [90, 0, 0],
       "joints_from_groups": null, "skeleton": "auto", "inputs": {"declared_openings": 0, "declared_caps": 1},
       "recorded_defects": ["M2"], "role": "calibration|reference|control|own|vanilla"}
The item file may be {"exclude": REGEX, "items": [...]}: the top-level exclude applies to every item (e.g. the
registry's excluded assets) on top of an item's own. Writes DIR/<id>/{report.json, rules.json, blueprint.json[, *.png]}
and DIR/summary.json + summary.csv.
"""
import argparse
import csv
import json
import os
import sys
import time
import traceback

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import toplib as TL  # noqa: E402
import tl_io  # noqa: E402
import rules as RU  # noqa: E402
import blueprint as BP  # noqa: E402

COLS = ['id', 'role', 'kind', 'face_source', 'faces', 'quads', 'tris', 'ngons', 'quad_share', 'tri_equivalent', 'v3', 'v5',
        'v6plus', 'p6_share_inner', 'pole_share', 'nonmanifold', 'bowties', 'boundary_loops', 'concave', 'planar_over_30',
        'aspect_p99', 'aspect_max', 'mincorner_p1', 'mincorner_min', 'nbr_p99', 'nbr_max', 'partner_share',
        'centre_inexact', 'eye_rings', 'mouth_rings', 'mask', 'head_share', 'gate', 'grade', 'must_fail', 'should_fail',
        'unexpected_fail', 'hash', 'seconds']


def fill(path, roots):
    for k, v in roots.items():
        path = path.replace('<%s>' % k, v)
    return path


def row(it, rep, res, bp, dt):
    fk, pc, m, q, sy = rep['face_kinds'], rep['poles'], rep['manifold'], rep['quality'], rep.get('symmetry') or {}
    f = rep.get('face') or {}
    g = lambda d, *ks: _get(d, ks)
    return dict(id=it['id'], role=it.get('role', 'reference'), kind=rep['kind'], face_source=rep['face_source'],
                faces=fk['faces'], quads=fk['quads'], tris=fk['tris'], ngons=fk['ngons'], quad_share=fk['quad_share'],
                tri_equivalent=fk['tri_equivalent'], v3=pc['v3'], v5=pc['v5'], v6plus=pc['v6plus'],
                p6_share_inner=pc['p6_share_of_inner'], pole_share=pc['pole_share'], nonmanifold=m['nonmanifold_edges'],
                bowties=m['bowtie_verts'], boundary_loops=m['boundary_loops'], concave=q.get('concave_quads'),
                planar_over_30=q.get('planar_share_over_30'), aspect_p99=g(q, 'aspect', 'p99'), aspect_max=g(q, 'aspect', 'max'),
                mincorner_p1=g(q, 'min_corner_deg', 'p1'), mincorner_min=g(q, 'min_corner_deg', 'p0'),
                nbr_p99=g(q, 'neighbour_area_ratio', 'p99'), nbr_max=g(q, 'neighbour_area_ratio', 'max'),
                partner_share=sy.get('partner_share'), centre_inexact=sy.get('centre_inexact'),
                eye_rings=f.get('eye_rings'), mouth_rings=f.get('mouth_rings'), mask=f.get('mask_loops'),
                head_share=rep['regions']['head_with_neck_share'], gate=res['gate'], grade=res['grade'],
                must_fail=res['must_fail'], should_fail=res['should_fail'], unexpected_fail=res['unexpected_fail'],
                hash=bp['hash'][:16], seconds=round(dt, 1))


def _get(d, ks):
    for k in ks:
        if not isinstance(d, dict) or k not in d:
            return None
        d = d[k]
    return d


def _excl(a, b):
    xs = [x for x in (a, b) if x]
    return '|'.join('(?:%s)' % x for x in xs) if xs else None


def run_item(it, roots, out, profile, renders, blender, log, exclude=None):
    t0 = time.time()
    path = fill(it['path'], roots)
    fs = it.get('face_source', 'native')
    inputs = it.get('inputs', {})
    loaded = tl_io.load(path, select=it.get('select'), group=it.get('group'), up=it.get('up'), rot=it.get('rot'),
                        joints_from_groups=it.get('joints_from_groups'), collection=it.get('collection'),
                        via=it.get('via'), blender=blender, need_t2q=(fs == 't2q'), log=log,
                        exclude=_excl(exclude, it.get('exclude')))
    rep = TL.analyse(loaded, kind=it.get('kind', 'body'), skeleton=fill(it.get('skeleton', 'auto'), roots), face_source=fs,
                     declared_caps=inputs.get('declared_caps'))
    prof = RU.load_profile(fill(it['profile'], roots) if it.get('profile') else profile)
    cin = dict(inputs)
    cin.setdefault('subject', 'reference' if it.get('role', 'reference') in ('calibration', 'reference') else 'build')
    cin.setdefault('recorded_defects', it.get('recorded_defects', []))
    res = RU.check(rep, prof, cin)
    bp = BP.build(rep)
    d = os.path.join(out, it['id'])
    os.makedirs(d, exist_ok=True)
    rep_pub = TL.public(rep)
    rep_pub['source']['path'] = os.path.basename(path)
    for name, obj in (('report.json', rep_pub), ('rules.json', res), ('blueprint.json', bp)):
        with open(os.path.join(d, name), 'w') as fh:
            json.dump(obj, fh, indent=1, default=TL._json_default)
    pics = []
    if renders:
        import render_topology as RT
        views = it.get('views') or ([('front', None), ('34', 'head')] if rep['kind'] == 'body' else [('front', None), ('34', None)])
        for view, zoom in views:
            fn = os.path.join(d, '%s_%s%s.png' % (it['id'], view, ('_' + zoom) if zoom else ''))
            RT.render(rep, fn, view=view, zoom=zoom, title='%s (%s, %s)' % (it['id'], rep['kind'], fs))
            pics.append(os.path.abspath(fn))
    rw = row(it, rep, res, bp, time.time() - t0)
    rw['recorded_defects'] = it.get('recorded_defects', [])
    rw['pictures'] = pics
    return rw


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('items')
    ap.add_argument('--root', action='append', default=[], help='name=PATH for <name> placeholders')
    ap.add_argument('--out', required=True)
    ap.add_argument('--only')
    ap.add_argument('--profile')
    ap.add_argument('--renders', action='store_true')
    ap.add_argument('--blender')
    a = ap.parse_args(argv)
    try:
        import blender_env as BE
        refusal = BE.refuse_in_worktree(a.out, 'survey output')
    except ImportError:
        refusal = None
    if refusal:
        print('SETUP ERROR: ' + refusal, file=sys.stderr)
        return 2
    roots = dict(x.split('=', 1) for x in a.root)
    items = json.load(open(a.items, encoding='utf-8-sig'))
    exclude = None
    if isinstance(items, dict):
        exclude = items.get('exclude')
        items = items['items']
    only = set(a.only.split(',')) if a.only else None
    os.makedirs(a.out, exist_ok=True)
    log = os.path.join(a.out, 'survey.log')
    summ_path = os.path.join(a.out, 'summary.json')
    rows = json.load(open(summ_path)) if (only and os.path.exists(summ_path)) else []
    rows = [r for r in rows if not only or r['id'] not in only]
    for it in items:
        if only and it['id'] not in only:
            continue
        try:
            rw = run_item(it, roots, a.out, a.profile, a.renders, a.blender, log, exclude=exclude)
            print('SURVEY %-26s %-11s %s faces %s 6+ %s gate %s grade %s must %s should %s unexpected %s (%.0fs)' % (
                it['id'], it.get('role', ''), rw['kind'], rw['faces'], rw['v6plus'], rw['gate'], rw['grade'],
                rw['must_fail'], rw['should_fail'], rw['unexpected_fail'], rw['seconds']), flush=True)
        except Exception as exc:
            traceback.print_exc()
            rw = dict(id=it['id'], role=it.get('role'), error=repr(exc)[:400])
            print('SURVEY %-28s ERROR %s' % (it['id'], rw['error']), flush=True)
        rows.append(rw)
        with open(summ_path, 'w') as fh:
            json.dump(rows, fh, indent=1, default=TL._json_default)
    order = {it['id']: k for k, it in enumerate(items)}
    rows.sort(key=lambda r: order.get(r['id'], 1e9))
    with open(summ_path, 'w') as fh:
        json.dump(rows, fh, indent=1, default=TL._json_default)
    with open(os.path.join(a.out, 'summary.csv'), 'w', newline='') as fh:
        w = csv.DictWriter(fh, fieldnames=COLS + ['recorded_defects', 'error'], extrasaction='ignore')
        w.writeheader()
        for r in rows:
            w.writerow({k: (json.dumps(v) if isinstance(v, (list, dict)) else v) for k, v in r.items()})
    print('SURVEY DONE', summ_path, len(rows))
    return 0


if __name__ == '__main__':
    sys.exit(main())
