#!/usr/bin/env python
"""Unit model census (read-only): the columns of vanilla-unit-measurements.md "Full table" and "Mesh-level detail".

    python measure_units.py --archive Art/units/asians/chinese/iron_flail/iron_rider_0.gr2 [...] [--material]
    python measure_units.py FILE.gr2 [...] [--json OUT.json] [--summary] [--mesh]

Per file: GPU vertices (as shipped), welded vertices (distinct position + every component but Tangent), unique
positions (rounded 1e-5, summed per mesh), triangles, meshes, material slots (topology groups), skeleton bones,
weighted bones, influences max / mean and the 1/2/3/4 histogram (rigid meshes count 1). --material adds the texture
pages of the `.material` with the same stem (next to the file, or from the archive), sizes from the archive's DDT
headers. --summary prints min / median / mean / max over the files. The JSON goes to --json or a temp folder.
Unreadable (Oodle-compressed) files are listed, never skipped silently.
"""
import argparse
import json
import statistics
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import unit_gr2 as U  # noqa: E402


def measure(m):
    hist = {1: 0, 2: 0, 3: 0, 4: 0}
    meshes, weighted, nz, nv = [], set(), 0, 0
    for me in m.meshes:
        infl = me.influences()
        for k, v in zip(*np.unique(infl, return_counts=True)):
            hist[int(k)] = hist.get(int(k), 0) + int(v)
        nz += int(infl.sum()); nv += me.n
        wb = me.weighted_bones(); weighted.update(wb)
        meshes.append(dict(name=me.name, verts=me.n, tris=len(me.tris), welded=me.welded_count(),
                           unique_positions=me.unique_positions(), kind='skinned' if me.skinned else
                           ('indexed' if 'BoneIndices' in me.comps else 'rigid'),
                           max_infl=int(infl.max()) if me.n else 0, mean_infl=round(float(infl.mean()), 3) if me.n else 0,
                           hist={int(k): int(v) for k, v in zip(*np.unique(infl, return_counts=True))},
                           materials=me.materials, groups=me.groups, bound=len(me.bones), weighted_bones=wb,
                           stride=me.stride))
    return dict(name=m.name, file=str(m.path), crc_ok=m.crc_ok, gpu_verts=nv,
                welded=sum(x['welded'] for x in meshes), unique_positions=sum(x['unique_positions'] for x in meshes),
                tris=sum(x['tris'] for x in meshes), meshes=meshes, mat_slots=sum(len(x['groups']) for x in meshes),
                skeleton_bones=len(m.skeleton), weighted_bones=sorted(weighted),
                max_infl=max((x['max_infl'] for x in meshes), default=0),
                mean_infl=round(nz / nv, 3) if nv else 0, hist=hist)


def material_text(gr2_path, archive_rel=None, extract_root=None):
    """'mata 4 @1024 (default); ...' from the .material with the same stem, or None."""
    import gr2_lint
    base = Path(gr2_path).with_suffix('.material')
    cands = [base] + [base.with_name(base.name + x) for x in ('.xmb', '.XMB')]    # vanilla ships .material.XMB
    mp = next((c for c in cands if c.is_file()), None)
    if mp is None and archive_rel:
        rel = str(Path(archive_rel).with_suffix('.material'))
        for r in (rel, rel + '.xmb'):
            try:
                mp = U.fetch([r], extract_root)[0]
                break
            except FileNotFoundError:
                continue
    if mp is None:
        return None
    parts = []
    for s in gr2_lint.read_material(mp):
        sizes = []
        for v in s['textures'].values():
            t = gr2_lint.vanilla_texture(v.replace(chr(92), '/'))
            sizes.append(t['W'] if t else None)
        sz = '/'.join(str(x) for x in sorted({x for x in sizes if x})) or '?'
        parts.append('%s %d @%s (%s)' % (s['name'], len(s['textures']), sz, s['shader']))
    return '; '.join(parts)


def row(r):
    if 'unreadable' in r:
        return '| %s | UNREADABLE (%s) |' % (r['name'], r['unreadable'])
    h = r['hist']
    return '| %s | %d | %d | %d | %d | %d | %d | %d | %d | %d / %s | %d/%d/%d/%d | %s |' % (
        r['name'], r['gpu_verts'], r['welded'], r['unique_positions'], r['tris'], len(r['meshes']), r['mat_slots'],
        r['skeleton_bones'], len(r['weighted_bones']), r['max_infl'], r['mean_infl'], h.get(1, 0), h.get(2, 0),
        h.get(3, 0), h.get(4, 0), r.get('textures') or '')


def summary(rows):
    ok = [r for r in rows if 'unreadable' not in r]
    out = {}
    for k in ('tris', 'welded', 'unique_positions', 'gpu_verts'):
        v = [r[k] for r in ok]
        if v:
            lo, hi = min(v), max(v)
            out[k] = dict(min=lo, min_file=[r['name'] for r in ok if r[k] == lo][0], median=statistics.median(v),
                          mean=round(statistics.mean(v)), max=hi, max_file=[r['name'] for r in ok if r[k] == hi][0])
    return out


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    U.add_input_args(ap)
    ap.add_argument('--json', help='write the full records here (default: a temp folder)')
    ap.add_argument('--material', action='store_true', help='add the .material texture pages')
    ap.add_argument('--summary', action='store_true')
    ap.add_argument('--mesh', action='store_true', help='print one line per mesh')
    a = ap.parse_args(argv)
    paths = U.resolve_inputs(a)
    rel_of = dict(zip(paths[len(a.files):], a.archive))
    rows = []
    for p, m, why in U.models(paths):
        if m is None:
            rows.append(dict(name=Path(p).stem, file=str(p), unreadable=why))
            continue
        r = measure(m)
        if a.material:
            r['textures'] = material_text(p, rel_of.get(p), a.extract_to) or 'no .material'
        rows.append(r)
    print('| Model | GPU verts | welded | unique pos | tris | meshes | mat slots | skel | weighted | infl max / mean |'
          ' 1/2/3/4 | textures |')
    print('| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- | --- |')
    for r in rows:
        print(row(r))
    if a.mesh:
        for r in rows:
            for x in r.get('meshes', []):
                print('   %s / %s: %d GPU verts, %d welded, %d tris, %s, infl %d / %s %s, bound %d -> weighted %d, '
                      'materials %s, groups %s, stride %d' % (
                          r['name'], x['name'], x['verts'], x['welded'], x['tris'], x['kind'], x['max_infl'],
                          x['mean_infl'], x['hist'], x['bound'], len(x['weighted_bones']), x['materials'],
                          x['groups'], x['stride']))
    if a.summary:
        for k, s in summary(rows).items():
            print('SUMMARY %s: min %s (%s) median %s mean %s max %s (%s)' % (
                k, s['min'], s['min_file'], s['median'], s['mean'], s['max'], s['max_file']))
    out = Path(a.json) if a.json else U.temp_dir('reports') / 'measure_units.json'
    out.write_text(json.dumps(rows, indent=1, default=str))
    print('JSON', out)
    return rows


if __name__ == '__main__':
    main()
