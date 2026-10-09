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

Pure Python core (`audit`, `snapshot`, `moved`), unit-tested without Blender. Inside Blender:
  blender -b file.blend --python uv_integrity.py -- --config gate.json --out report.json
config = {"objects": ["Obj", ...] | "collections": ["Col", ...], "uv_layer": "UVMap",
          "page_attr": "uv_resource" (optional), "family_attr": "share_family" (optional), "role_attr": "share_role",
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


def audit(faces, atlases=None, allow_outside_unit=(), frozen=None):
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
    if frozen:
        mv = moved(frozen['before'], snapshot(faces), frozen.get('targets', ()))
        for fid in mv:
            fail('F_non_target_moved', fid)
    return {'status': 'FAIL' if fails else 'PASS', 'faces': len(faces), 'families': len(owners), 'failures': fails,
            'examples': ex, 'checks': ['W winding', 'S stacking', 'R atlas regions', 'B bounds/collapse'] +
            (['F frozen non-targets'] if frozen else [])}


def snapshot(faces):
    return {f['id']: tuple((round(u, 7), round(v, 7)) for u, v in f['uv']) for f in faces}


def moved(before, after, targets=()):
    """ids outside `targets` whose UVs differ between two snapshots (or vanished)"""
    t = set(targets)
    return sorted(i for i, uv in before.items() if i not in t and after.get(i) != uv)


# ------------------------------------------------------------------------------------------------ Blender wrapper
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
        for p in me.polygons:
            out.append({'id': f'{o.name}#{p.index}', 'page': str(pg[p.index]), 'family': int(fa[p.index]),
                        'role': int(ro[p.index]), 'uv': [[ul[l].uv.x, ul[l].uv.y] for l in p.loop_indices]})
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
    rep = audit(faces, cfg.get('atlases'), cfg.get('allow_outside_unit', ()))
    json.dump(rep, open(a.out, 'w', encoding='utf-8'), indent=1)
    print('UV_INTEGRITY', rep['status'], json.dumps(rep['failures']))
    sys.exit(0 if rep['status'] == 'PASS' else 1)


if __name__ == '__main__' and '--' in sys.argv:
    main_blender()
