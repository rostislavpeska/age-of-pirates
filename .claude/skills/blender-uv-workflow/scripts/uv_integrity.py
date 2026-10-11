"""UV integrity gate: fail-closed checks to run after EVERY step that changes UVs (unwrap, share/conjoin copy, AO
variant split, pack, page move), never only once at the start. Each check is a defect class that once passed every
other gate silently:

  W winding  every face has a positive signed UV area; a mirrored copy or flipped chart is negative (shared members
             copied by a reflection that matched the same vertex SET: 2,010 faces in one checkpoint)
  S stacking every member face of a family reproduces one of its owner's UV polygons exactly (same cyclic order), on
             the owner's page; a member never owns texels of its own
  R regions  faces on a shared-atlas page stay inside one declared real region (cell) of that atlas (a pack moved
             hidden atlas faces after a selection flush; density looked fine)
  B bounds   UVs are finite, inside [0, 1] on ordinary pages, and no face is collapsed
  F frozen   faces outside a step's target set did not move (compare a snapshot taken before the step)
  C coherence (when faces carry 'chart' + 'verts'; config "surface_patch_deg" or "chart_attr", + "material_attr"):
             one continuous surface = one texture unit. The unit is a SMOOTH PATCH computed from the mesh (faces of one
             part and material joined across edges bending less than surface_patch_deg: a roof slope between its hips, a
             wall panel, one post side), so no earlier UV decision defines it; or an explicit chart attribute. Its faces
             stay ONE UV island (joined through
             UV-continuous shared edges; a ring such as a post keeps its single cut), lie on ONE page, and are either all
             members or have no member. Face-by-face symmetric stacking had
             cut every Market roof slope into owner halves, member halves and unique patches while all other checks
             passed (owner 2026-10-11: the roof has many incoherencies, a problem for baking). Shared-atlas pages
             (atlases) are exempt: their cells are swatches, not continuous surfaces.
  O folds    (config "page_px": {"<page>": px}): no pixel centre of an owned page is covered by two OWNER faces (members
             stack by design and are skipped). Island-vs-island overlap was checked elsewhere; a ring patch re-unwrapped
             without a cut folded onto itself INSIDE one island (Market crown boss, 131 px) and only this catches it.

Pure Python core (`audit`, `snapshot`, `moved`), unit-tested without Blender. Inside Blender:
  blender -b file.blend --python uv_integrity.py -- --config gate.json --out report.json
config = {"objects": ["Obj", ...] | "collections": ["Col", ...], "uv_layer": "UVMap",
          "page_attr": "uv_resource" (optional), "family_attr": "share_family" (optional), "role_attr": "share_role",
          "chart_attr": "uv_chart" (optional: enables C; the clean-stage chart id per face, -1 = none),
          "material_attr": "paint_subtype" (optional: C units are chart x material),
          "surface_patch_deg": 25 (optional, preferred: C units are smooth patches; faces under 1e-6 m2 are exempt),
          "page_px": {"0": 2048, "5": 1024} (optional: enables O on those pages),
          "atlases": {"<page value>": {"size": 1024, "regions": [[x0, y0, x1, y1], ...]}},   # pixels, top-left origin
          "allow_outside_unit": ["<page value>", ...]}                                        # optional
Exit 0 = PASS, 1 = FAIL (every failure counted, examples named), 2 = bad config.
"""
import json
import math
import sys

ROUND = 5          # UV decimals compared for stacking (1e-5 of a page = 0.02 px at 2048)
MIN_AREA = 1e-12   # |signed area| below this (in UV units^2) is a collapsed face


def signed_area(uv):
    return sum(uv[i][0] * uv[(i + 1) % len(uv)][1] - uv[(i + 1) % len(uv)][0] * uv[i][1] for i in range(len(uv))) / 2


def poly_key(uv):
    """rotation-normalised, orientation-PRESERVING key of a UV polygon: a reversed (mirrored) copy never matches"""
    pts = [(round(u, ROUND) + 0.0, round(v, ROUND) + 0.0) for u, v in uv]
    k = min(range(len(pts)), key=lambda i: pts[i])
    return tuple(pts[k:] + pts[:k])


def _finite(uv):
    return all(math.isfinite(c) for p in uv for c in p)


def fold_pixels(faces, page_px):
    """{page: (pixels covered by 2+ owner faces, example ids)}: owner faces (role != 2) rasterised at pixel centres"""
    import numpy as np
    out = {}
    for page, n in page_px.items():
        cnt = np.zeros((n, n), np.uint8); hit = {}
        for f in faces:
            if str(f.get('page')) != str(page) or f.get('role') == 2 or len(f['uv']) < 3 or not _finite(f['uv']):
                continue
            P = np.array(f['uv'], float) * n
            x0, y0 = np.maximum(np.floor(P.min(0)).astype(int), 0); x1, y1 = np.minimum(np.ceil(P.max(0)).astype(int) + 1, n)
            if x1 <= x0 or y1 <= y0:
                continue
            X, Y = np.meshgrid(np.arange(x0, x1) + .5, np.arange(y0, y1) + .5); ins = np.zeros(X.shape, bool)
            for i in range(len(P)):
                (xa, ya), (xb, yb) = P[i], P[(i + 1) % len(P)]
                ins ^= ((ya > Y) != (yb > Y)) & (X < (xb - xa) * (Y - ya) / np.where(yb - ya == 0, 1e-12, yb - ya) + xa)
            sub = cnt[y0:y1, x0:x1]
            if (sub[ins] > 0).any():
                hit[f['id']] = int((sub[ins] > 0).sum())
            sub[ins] = np.minimum(sub[ins] + 1, 2)
        out[str(page)] = (int((cnt > 1).sum()), sorted(hit, key=lambda k: -hit[k])[:12])
    return out


def audit(faces, atlases=None, allow_outside_unit=(), frozen=None, page_px=None, unit='chart'):
    """faces: [{'id', 'page', 'uv': [[u, v], ...], 'family': int (-1 none), 'role': 0 unique | 1 owner | 2 member}]
    atlases: {page: {'size': px, 'regions': [[x0, y0, x1, y1], ...]}}; frozen: {'before': snapshot, 'targets': ids}"""
    atlases = {str(k): v for k, v in (atlases or {}).items()}
    allow = {str(p) for p in allow_outside_unit} | set(atlases)
    fails, ex = {}, {}

    def fail(code, fid):
        fails[code] = fails.get(code, 0) + 1
        if len(ex.setdefault(code, [])) < 12:
            ex[code].append(fid)
    ids = [f['id'] for f in faces]
    if len(ids) != len(set(ids)):
        raise ValueError('duplicate face ids')
    owners = {}
    for f in faces:
        if f.get('role') == 1 and f.get('family', -1) >= 0:
            o = owners.setdefault(f['family'], {'page': str(f.get('page')), 'keys': set(), 'pages': set()})
            o['keys'].add(poly_key(f['uv'])); o['pages'].add(str(f.get('page')))
    for fam, o in owners.items():
        if len(o['pages']) > 1:
            fail('S_owner_split_over_pages', f'family {fam}')
    for f in faces:
        uv, page = f['uv'], str(f.get('page'))
        if len(uv) < 3 or not _finite(uv):
            fail('B_nonfinite_or_degenerate', f['id']); continue
        a = signed_area(uv)
        if abs(a) <= MIN_AREA:
            fail('B_collapsed', f['id'])
        elif a < 0:
            fail('W_negative_winding', f['id'])
        if page not in allow and any(c < -1e-6 or c > 1 + 1e-6 for p in uv for c in p):
            fail('B_outside_unit', f['id'])
        if page in atlases:
            s = atlases[page]['size']; xs = [p[0] * s for p in uv]; ys = [(1 - p[1]) * s for p in uv]
            if not any(x0 - .5 <= min(xs) and max(xs) <= x1 + .5 and y0 - .5 <= min(ys) and max(ys) <= y1 + .5
                       for x0, y0, x1, y1 in atlases[page]['regions']):
                fail('R_outside_atlas_region', f['id'])
        if f.get('role') == 2 and f.get('family', -1) >= 0:
            o = owners.get(f['family'])
            if o is None:
                fail('S_member_without_owner', f['id'])
            else:
                if page != o['page']:
                    fail('S_member_on_other_page', f['id'])
                if poly_key(uv) not in o['keys']:
                    fail('S_member_not_stacked_on_owner', f['id'])
    coherence = any('chart' in f for f in faces)
    charts = {}
    if coherence:
        for f in faces:
            if f.get('chart') is None or str(f.get('page')) in atlases:
                continue
            c = charts.setdefault(f['chart'], {'pages': set(), 'member': 0, 'other': 0, 'edges': {}, 'faces': []})
            c['pages'].add(str(f.get('page'))); c['member' if f.get('role') == 2 else 'other'] += 1
            k = len(c['faces']); c['faces'].append(k)
            vs, uv = f.get('verts') or [], f['uv']
            for i in range(len(vs)):
                a_, b_ = vs[i], vs[(i + 1) % len(vs)]
                ends = {a_: tuple(round(x, ROUND) + 0.0 for x in uv[i]), b_: tuple(round(x, ROUND) + 0.0 for x in uv[(i + 1) % len(vs)])}
                c['edges'].setdefault(frozenset((a_, b_)), []).append((k, ends))
        for cid, c in sorted(charts.items(), key=lambda kv: str(kv[0])):
            par = list(range(len(c['faces'])))

            def find(x):
                while par[x] != x:
                    par[x] = par[par[x]]; x = par[x]
                return x
            for side in c['edges'].values():
                for k2, e2 in side[1:]:
                    if e2 == side[0][1]:                    # UV-continuous across this mesh edge
                        par[find(k2)] = find(side[0][0])
            if len(c['pages']) > 1:
                fail('C_chart_split_over_pages', cid)
            if c['member'] and c['other']:
                fail('C_partial_stack_in_chart', cid)
            if len({find(k) for k in c['faces']}) > 1:
                fail('C_chart_broken_into_islands', cid)
    folds = fold_pixels(faces, page_px) if page_px else {}
    for page, (px_, ids) in folds.items():
        if px_:
            fails['O_owner_faces_overlap'] = fails.get('O_owner_faces_overlap', 0) + px_
            ex.setdefault('O_owner_faces_overlap', []).extend(ids[:12])
    if frozen:
        mv = moved(frozen['before'], snapshot(faces), frozen.get('targets', ()))
        for fid in mv:
            fail('F_non_target_moved', fid)
    census = None
    if coherence or page_px:                                  # the checkpoint's `coherence` report metrics, verbatim
        census = {'unit': unit, 'units': len(charts), 'broken_into_islands': fails.get('C_chart_broken_into_islands', 0),
                  'partial_stacks': fails.get('C_partial_stack_in_chart', 0), 'split_over_pages': fails.get('C_chart_split_over_pages', 0),
                  'fold_pixels': fails.get('O_owner_faces_overlap', 0)}
    return {'status': 'FAIL' if fails else 'PASS', 'faces': len(faces), 'families': len(owners), 'failures': fails, 'coherence': census,
            'examples': ex, 'checks': ['W winding', 'S stacking', 'R atlas regions', 'B bounds/collapse'] +
            (['C chart coherence'] if coherence else []) + (['O folds (owner faces overlap, pixels)'] if page_px else []) +
            (['F frozen non-targets'] if frozen else [])}


def snapshot(faces):
    return {f['id']: tuple((round(u, 7), round(v, 7)) for u, v in f['uv']) for f in faces}


def moved(before, after, targets=()):
    """ids outside `targets` whose UVs differ between two snapshots (or vanished)"""
    t = set(targets)
    return sorted(i for i, uv in before.items() if i not in t and after.get(i) != uv)


# ------------------------------------------------------------------------------------------------ Blender wrapper
def surface_patches(me, material, max_deg, min_area=1e-6):
    """smooth patch id per face: faces of one material joined across manifold edges whose normals differ by less than
    max_deg; degenerate faces (area < min_area) get -1 (exempt)"""
    cos_lim = math.cos(math.radians(max_deg)); n = len(me.polygons); par = list(range(n))

    def find(x):
        while par[x] != x:
            par[x] = par[par[x]]; x = par[x]
        return x
    ok = [p.area >= min_area for p in me.polygons]
    e2f = {}
    for p in me.polygons:
        for ek in p.edge_keys:
            e2f.setdefault(ek, []).append(p.index)
    for fs in e2f.values():
        if len(fs) != 2:
            continue
        a_, b_ = fs
        if ok[a_] and ok[b_] and material[a_] == material[b_] and me.polygons[a_].normal.dot(me.polygons[b_].normal) >= cos_lim:
            par[find(a_)] = find(b_)
    return [find(i) if ok[i] else -1 for i in range(n)]


def extract_blender(cfg):
    import bpy
    objs = [bpy.data.objects[n] for n in cfg.get('objects', [])]
    for cn in cfg.get('collections', []):
        objs += [o for o in bpy.data.collections[cn].all_objects if o.type == 'MESH' and o not in objs]
    out = []
    for o in objs:
        me = o.data; ul = me.uv_layers[cfg['uv_layer']].data

        def attr(name, default):
            if not name or name not in me.attributes:
                return [default] * len(me.polygons)
            return [d.value for d in me.attributes[name].data]
        pg, fa, ro = attr(cfg.get('page_attr'), 0), attr(cfg.get('family_attr'), -1), attr(cfg.get('role_attr'), 0)
        ch = None; mt = attr(cfg.get('material_attr'), 0)
        if cfg.get('surface_patch_deg'):
            ch = surface_patches(me, mt, cfg['surface_patch_deg'])
        elif cfg.get('chart_attr'):
            if cfg['chart_attr'] not in me.attributes:
                raise KeyError(f"chart_attr {cfg['chart_attr']} missing on {o.name}")
            ch = attr(cfg['chart_attr'], -1)
        for p in me.polygons:
            f = {'id': f'{o.name}#{p.index}', 'page': str(pg[p.index]), 'family': int(fa[p.index]),
                 'role': int(ro[p.index]), 'uv': [[ul[l].uv.x, ul[l].uv.y] for l in p.loop_indices]}
            if ch is not None:
                f['chart'] = f'{o.name}:{ch[p.index]}:{mt[p.index]}' if ch[p.index] >= 0 else None
                f['verts'] = [f'{o.name}:{v}' for v in p.vertices]
            out.append(f)
    return out


def main_blender():
    import argparse
    ap = argparse.ArgumentParser(); ap.add_argument('--config', required=True); ap.add_argument('--out', required=True)
    a = ap.parse_args(sys.argv[sys.argv.index('--') + 1:])
    try:
        cfg = json.load(open(a.config, encoding='utf-8'))
        faces = extract_blender(cfg)
    except (KeyError, ValueError, OSError) as e:
        print('UV_INTEGRITY bad config:', e); sys.exit(2)
    rep = audit(faces, cfg.get('atlases'), cfg.get('allow_outside_unit', ()), page_px={k: int(v) for k, v in (cfg.get('page_px') or {}).items()},
                unit='smooth_patch' if cfg.get('surface_patch_deg') else 'chart')
    json.dump(rep, open(a.out, 'w', encoding='utf-8'), indent=1)
    print('UV_INTEGRITY', rep['status'], json.dumps(rep['failures']))
    sys.exit(0 if rep['status'] == 'PASS' else 1)


if __name__ == '__main__' and '--' in sys.argv:
    main_blender()
